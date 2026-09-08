# SPLIT, execution DAGs, and partitioning

Use this reference when generated SQL becomes expensive to compile or execute,
shared work repeats, or a candidate proposes dividing execution into stages or batches.
Treat each boundary or partitioning change as an isolated, measurable hypothesis.

Contents: SPLIT decisions; node/edge contracts; scheduling and snapshots;
Snowpark cache lifecycle; partition meanings; logical batch correctness.

## SPLIT: introduce a measured execution DAG

Here, **SPLIT** means decomposing a large relational plan into a directed acyclic
graph (DAG) of queries with selected materialized intermediates. It does not mean
Snowflake's string `SPLIT` function. Splitting Scala methods, adding aliases, or
introducing CTEs alone does not establish a durable materialization boundary.

Start by drawing the current logical graph and marking actual submitted statements.
Distinguish repeated expressions in generated SQL from repeated physical work in
query profiles. Snowflake may optimize a logical shape differently than expected.

```text
Pinned inputs -> Narrow/filter -> Shared aggregate -> Branch A --+
                                               \-> Branch B --+-> Final CTAS
```

Annotate each node with input/output grain, row counts, columns, query ID,
compilation/execution time, spill, bytes written, and consumer count. Mark the
critical path and the expensive fan-out/fan-in points. This identifies candidate
boundaries; it is not an instruction to materialize every box.

| Evidence | Candidate | Cost or correctness question |
| --- | --- | --- |
| Large compilation cost or unwieldy generated plan | Split at a compact, stable relation | Does added write/read cost outweigh compilation or execution savings? |
| Several consumers repeat an expensive reduction | Materialize the shared reduction once | Do consumers actually reuse it, or still reference the original lineage? |
| One consumer reads a large intermediate once | Fuse producer and consumer | Will compilation, repeated work, or spill become worse? |
| Different consumers need small, disjoint source slices | Keep branch-specific filtering | Would a shared materialization write far more data than each branch needs? |
| Long restart after late failures | Add a reusable checkpoint | Can its inputs and transformation version be verified on resume? |
| Expansion feeds costly windows | Reduce at the original grain first | Are any calculations dependent on the expanded dimension? |

Measure the entire candidate DAG, including orchestration gaps, intermediate
creation, scans, final writes, and required cleanup. Summed query durations are
not elapsed job time when queries overlap. Record both critical-path duration and
aggregate resource consumption. A cheaper single node does not prove a cheaper job.

## Node and edge contracts

Before introducing a boundary, state the invariants its consumers rely on:

- **Grain and keys:** one row per which entity/event/period; expected multiplicity;
  join keys and whether uniqueness has been demonstrated.
- **Schema:** explicit column names and order where positional operations exist;
  numeric precision/scale, nullability behavior, timestamps/time zones, and collations.
- **Coverage:** input snapshot, business filters, date bounds, deleted records,
  late-arriving data, and ownership of null keys.
- **Semantics:** duplicate preservation, outer-join behavior, window frames/ties,
  and any nondeterministic expressions evaluated at that boundary.
- **Lifecycle:** producer, consumers, object scope, completion evidence,
  retry behavior, and cleanup owner.

Check row counts and key multiplicities around the boundary using existing cheap
diagnostics. These checks help localize errors; they do not replace the authoritative
deterministic gate. Preserve exact numeric semantics when changing aggregation
order, especially for floating-point calculations.

Shared work must have identical inputs and semantics. Two expressions that look
similar can differ in filters, snapshots, role-dependent policies, session settings,
or duplicate handling. Freeze run-wide values such as an as-of timestamp when the
original contract requires one value; do not independently reevaluate them in each
node. Materializing nondeterministic expressions changes evaluation frequency and
therefore needs explicit semantic review.

## Scheduling, snapshots, and recovery

Schedule independent ready nodes with bounded concurrency only after establishing
dependencies. Increase concurrency separately from introducing boundaries so its
effect remains attributable. Watch queueing, memory pressure, spill, and the final
fan-in: overlapping branches can compete for the same warehouse resources.

Snowflake task graphs provide dependency scheduling and retry facilities when they
fit the existing deployment model. A DAG can also remain in the current Scala/job
orchestrator. Do not introduce a new scheduling platform simply to split one query.
[Snowflake task graphs](https://docs.snowflake.com/en/user-guide/tasks-graphs)

Splitting one statement into several changes the consistency problem. Snowflake
uses READ COMMITTED isolation: successive statements can observe different committed
data, including within one transaction. DDL statements run in separate transactions
and commit an active transaction first. A `BEGIN` around a series of CTAS statements
does not make the DAG one atomic snapshot or rollback unit.
[Transactions](https://docs.snowflake.com/en/sql-reference/transactions)

Use the job's existing immutable input snapshot where available. Otherwise choose
a documented consistency mechanism suitable for the objects: fixed Time Travel
timestamps on all relevant source reads, a clone from a common supported snapshot,
or controlled immutable staging. Pin one absolute timestamp; independently evaluated
relative offsets move as each node starts. Check retention, object creation time,
schema changes, privileges, and supported object types before relying on Time Travel.
[AT / BEFORE](https://docs.snowflake.com/en/sql-reference/constructs/at-before),
[Cloning with Time Travel](https://docs.snowflake.com/en/sql-reference/sql/create-clone)

For restartable stages, use run-unique object names and a manifest containing input
snapshot, transformation version, parameters, stage name, query ID, and completion
status. A table's existence alone is insufficient proof that it is reusable. On
uncertain outcomes, inspect query completion and output identity before retrying.
Invalidate downstream stages when any upstream contract or input changes.

Prefer building each retry into an isolated stage object, then marking that attempt
complete after validation. Repeated appends require a proven deduplication or atomic
replacement protocol. Never publish a subset of successful batches as the complete
result. Keep final publication and its recovery logic in the final-write design.

Temporary tables belong to their creating session and disappear when that session
ends. They cannot serve as cross-session handoffs or durable restart checkpoints.
Use suitably scoped transient or permanent tables when those properties are needed,
and account for their storage and retention behavior. Give cleanup an explicit owner
and avoid temporary names that shadow existing production objects.
[Temporary and transient tables](https://docs.snowflake.com/en/user-guide/tables-temp-transient)

For every cross-session DAG edge, establish both **producer commit and consumer
visibility**. Under the default `READ_CONSISTENCY_MODE='SESSION'`, an already-open
consumer session can miss another session's recently committed DDL or DML. Producer
completion and a persistent stage table alone do not establish readiness. Prefer
running dependent statements in the same session. If a separate session is needed,
start a new Snowflake consumer session after the producer commits; checking out an
existing pooled session does not provide that guarantee. An established account
policy using `READ_CONSISTENCY_MODE='GLOBAL'` can instead provide cross-session
consistency. Changing that account-wide setting is a separate administrative
decision, not an automatic step in a stage rewrite. Source snapshot pinning and
intermediate-stage visibility are separate requirements; satisfy both.
[Read consistency across sessions](https://docs.snowflake.com/en/sql-reference/transactions#read-consistency-across-sessions)

## Snowpark cacheResult lifecycle

For repository builds, Scala action/query-ID APIs, and final writers, first identify
the execution runtime with [the Scala-job playbook](scala-jobs.md).

Scala `DataFrame.cacheResult()` executes the query immediately, stores its result in
a temporary table, and returns `HasCachedResult`. Subsequent consumers must use that
returned object; the original DataFrame still references its original computation.
An extra `collect()` before caching is unnecessary and can add substantial work.
A view declaration alone does not evaluate and freeze its underlying DataFrame.
[Scala DataFrame execution and caching](https://docs.snowflake.com/en/developer-guide/snowpark/scala/working-with-dataframes)

Keep the cached relation alive until every consumer action has completed, including
asynchronous actions. Measure its creation and subsequent scans as separate costs.
Do not assume Python cleanup methods exist in Scala: check the installed library's
API. If precise early cleanup, stable names, or cross-session reuse are required,
prefer explicitly managed CTAS/table stages with a known lifecycle. Do not assume
garbage collection immediately releases Snowflake storage.
[Scala HasCachedResult API](https://docs.snowflake.com/en/developer-guide/snowpark/reference/scala/2.12/com/snowflake/snowpark/HasCachedResult.html)

## Identify which meaning of partition applies

| Meaning | What it changes | What it does not establish |
| --- | --- | --- |
| Snowflake micro-partitions and clustering | Physical storage organization and opportunities to prune scans | Independent application batches or window groups |
| SQL `OVER (PARTITION BY ...)` | The rows participating together in a window calculation | Table storage partitions or worker counts |
| Date/entity/hash work splitting | Which rows each submitted query owns | Semantic independence or automatic scan pruning |
| Spark `repartition` / `coalesce` | Spark execution or connector-specific behavior | Direct control over native Snowflake query parallelism |

Standard Snowflake tables are micro-partitioned automatically. Evaluate pruning by
comparing partitions scanned with total partitions and inspecting bytes scanned for
representative predicates. Do not copy a conventional database's static
`PARTITION BY` table design into native Snowflake DDL.
[Micro-partitions and pruning](https://docs.snowflake.com/en/user-guide/tables-clustering-micropartitions)

When pruning is poor, inspect filter expressions and implicit casts on the scanned
columns. Test equivalent typed range predicates aligned with the business timezone
and date boundaries. Functions on columns are not universally unprunable; the actual
scan profile determines whether a rewrite helps. Do not remove a necessary cast by
changing comparison semantics.

Test clustering only when observed scan patterns and table scale justify it. Choose
keys or order-preserving expressions aligned with selective access patterns; compare
query savings with initial and ongoing clustering cost. Arbitrary hashes can scatter
range values and undermine date-range pruning. Short-lived, single-use intermediates
may not live long enough to repay clustering work.
[Clustering key selection and costs](https://docs.snowflake.com/en/user-guide/tables-clustering-keys)

Window `PARTITION BY` defines semantic groups. Its `ORDER BY` orders within those
groups and does not guarantee final output ordering. Preserve `ROWS` versus `RANGE`,
frame bounds, null placement, and tie behavior. Never add partition keys merely to
make a global calculation cheaper. Functions differ in their default frames and in
which explicit frames they support.
[Window syntax and semantics](https://docs.snowflake.com/en/sql-reference/functions-window-syntax)

Native Snowpark and Spark are different execution APIs. In Snowpark Connect for
Spark, `repartition` does not control warehouse query parallelism, although it can
affect results/output layout; connector-specific file writes can honor requested
file counts. Verify the runtime and version before translating a Spark tuning knob.
[Snowpark Connect execution](https://docs.snowflake.com/en/developer-guide/snowpark-connect/snowpark-connect-optimization),
[File output controls](https://docs.snowflake.com/en/developer-guide/snowpark-connect/snowpark-connect-file-io)

## Logical date, entity, or hash batches

Introduce batches when evidence points to bounded-memory execution, skew isolation,
restart cost, or useful independent work. Do not assume more batches reduce credits:
each can repeat scans, compilation, joins, and writes. Tune batch count and concurrency
separately, after a correct serial decomposition is established.

| Split | Useful when | Required correctness argument |
| --- | --- | --- |
| Half-open date ranges `[start, end)` | Work and pruning follow time slices | Boundary rows, null dates, time zones, and cross-boundary history are covered |
| Complete entities | Joins/windows are entity-local | Every row for an entity stays together, including history and null-key rules |
| Deterministic hash buckets | Independent entities are unevenly distributed | Stable typed keys, fixed bucket rule/count, and exhaustive bucket ownership |
| Explicit heavy-key batches | A few entities dominate runtime | Heavy and ordinary sets are disjoint and cover the full domain |

Prove both **coverage** and **disjoint output ownership**. Prefer half-open ranges to
avoid double-counting shared endpoints. Define handling of nulls rather than letting
filters silently exclude them. Hash collisions can share a bucket but must never
replace the original business key in joins or equality checks. A hash predicate may
still scan the full source in every batch; verify pruning before scaling out.

For entity-based windows, hash the complete window entity so all its rows reach the
same batch. For time-window batches, include the exact required preceding/following
context, compute with that context, then emit only the owned output interval. A fixed
date overlap is not generally sufficient for a `ROWS` frame or unbounded history.

For joins, preserve all matching pairs. Splitting both sides by the same date is
incorrect when records can match across dates. Inner equijoins can be divided by a
consistent function of the full join key if equal keys always share a batch; preserve
type coercion, collation, and null-safe equality semantics. Outer, anti, range, and
as-of joins require their own proof, including where unmatched rows are emitted.

Global ranking, global deduplication, percentiles, distinct counts, and windows
without a semantic partition generally require a final reconciliation stage. Do not
concatenate local results and call them global. Mergeable aggregates can sometimes
use partial states: for example, combine sums and counts for an average instead of
averaging batch averages, preserving the original numeric and null semantics.

Combine disjoint outputs with explicit aligned projections and `UNION ALL` when the
original duplicates must survive. `UNION` is a semantic deduplication, not a generic
repair for overlapping batches. Run the complete deterministic gate after assembly,
and measure the final CTAS/write: the last stage may become the new bottleneck.
