# Additional strategies found in GitHub implementations

Use this reference for candidates beyond the general [strategy catalog](strategy-catalog.md).
Repositories and official documentation were inspected on 2026-09-08. Examples show
implementation patterns, not evidence of a speedup for the current job. Keep the
skill's unchanged correctness gate, isolated experiments, and full-job measurement.

Prefer the existing SQL/Scala implementation when transferring a pattern. A dbt
macro or Python API does not require adopting that framework. Check the installed
runtime and release: code present on GitHub `main` is not proof of released support.
Do not execute repository setup scripts or install packages merely to use an idea.

Contents: RELY join elimination; native ASOF; multi-table INSERT; recurring query
families; MERGE target pruning; complete time-batch replacement; stream guards;
view versus table staging; selective/no-op updates; Snowpark compiler controls.

## Eliminate redundant joins using validated RELY constraints

**Candidate:** a common reporting query joins a dimension whose attributes are not
needed, or repeats a self-join that a proven key makes redundant. Test explicit join
removal or the optimizer's elimination using appropriate `RELY` constraints.

Snowflake's SQLAlchemy repository exposes `snowflake_rely=True` for key constraints;
the transferable mechanism is Snowflake constraint metadata, not SQLAlchemy itself.
[GitHub implementation guide](https://github.com/snowflakedb/snowflake-sqlalchemy/blob/main/README.md#rely-constraint-property).

For standard tables, verify and continuously preserve the relevant uniqueness,
referential integrity, and NULL assumptions before using `RELY`. Do not infer these
from a declared key or a clean sample. False promises can change query results.
Check the actual profile for a removed scan/join and retain full correctness checks.
[Snowflake join elimination](https://docs.snowflake.com/en/user-guide/join-elimination).

## Replace nearest-event join expansion with native ASOF JOIN

**Candidate:** a range join creates many matches and then selects the closest prior
or next event per left row. Test the native ASOF operator when that single-match
contract is exact.

The inspected community generator uses `UNION ALL` plus windowed `LAG ... IGNORE
NULLS` to avoid range-join expansion. It illustrates the problem and an older
solution; do not copy it blindly. Carrying nullable payload columns independently
can assemble values from different historical rows, and equal timestamps need a
defined rule. [GitHub AsOfJoin generator](https://github.com/GregPavlik/AsOfJoin/blob/main/StoredProcedure.sql).

Native ASOF returns at most one right match per left row and null-pads unmatched
left rows. Preserve entity keys, comparison direction, strict/inclusive bounds,
timestamp types, and original unmatched-row behavior. Right-side timestamp ties
can be nondeterministic; resolve them only using an existing business rule. ASOF is
not equivalent to an interval join that needs every matching interval. Preserve
additional validity conditions and determine whether they apply before nearest-row
selection. [Snowflake ASOF semantics](https://docs.snowflake.com/en/sql-reference/constructs/asof-join).

## Feed multiple outputs with one multi-table INSERT

**Candidate:** several output statements repeat the same expensive source query,
and their differences are projections or row-routing predicates. Compare an
`INSERT ALL` or conditional multi-table INSERT against separate statements or a
shared materialized stage. Inspect physical reuse; one SQL statement alone does
not prove one physical scan.

The official SQLAlchemy repository implements `InsertMulti` from one source SELECT
with multiple target mappings. SQL/Scala jobs can emit the equivalent Snowflake SQL
directly. [GitHub multi-table INSERT examples](https://github.com/snowflakedb/snowflake-sqlalchemy/blob/main/README.md#multi-table-insert-insert-all--insert-first).

Unconditional `ALL` routes every source row to every target; conditional `ALL`
executes every matching branch; `FIRST` executes only the first matching branch.
Prove those multiplicities match the existing outputs. Use explicit target columns,
preserve defaults versus NULLs, and account for all writers and retry/publication
semantics. `OVERWRITE` replaces each target's full contents; it is not partial
partition replacement. [Snowflake multi-table INSERT](https://docs.snowflake.com/en/sql-reference/sql/insert-multi-table).

`WHEN` may not filter a row before target-type compatibility is checked. Prepare
per-target projections that are type compatible for every source row, including
rows routed elsewhere. Preserve the existing conversion and error behavior; do
not blanket-substitute `TRY_*` conversions. Keep separate target writes, using a
shared stage if useful, when safe equivalent projections are unavailable.
[Type compatibility and evaluation order](https://docs.snowflake.com/en/sql-reference/sql/insert-multi-table#usage-notes).

## Prioritize recurring query families by total workload impact

**Candidate:** moderately slow statements execute so often that they consume more
daily time or credits than the single slowest query. Rank improvements by frequency
and total attributable cost, while preserving any separate latency objective.

Snowflake's sample SQL groups similar statements and reports frequency, elapsed
time, queueing, and blocking. Its older text-prefix grouping is an example, not a
reliable general fingerprint. [GitHub recurring-workload analysis](https://github.com/Snowflake-Labs/sf-samples/blob/767d5a89ba36e6eb9b0689cc51198d6aa67ba3d4/samples/workload-optimization-queries/AccountUsage/Performance/PERF-AU-52-duration-similar-requests.sql).

Use `QUERY_PARAMETERIZED_HASH` plus its hash-version field where appropriate, then
stratify by job, input volume/selectivity, warehouse, cache, and concurrency. The
same query family can have very different parameter-driven workloads. A changed
hash is not a regression signal on its own. Sum per-query credits once and report
overlapping durations as aggregate work, not wall time.
[Snowflake query hashes](https://docs.snowflake.com/en/user-guide/query-hash),
[cost measurement](measurement-and-records.md).

## Prune MERGE targets independently of incoming sources

**Candidate:** a small incoming batch still scans a large fraction of FINAL during
MERGE. Inspect the target scan separately from the source and test a provably
complete target predicate aligned with useful pruning.

dbt's merge macro appends `incremental_predicates` to key matching in the `ON`
condition. Filtering incoming rows alone does not restrict every possible target
scan. [GitHub merge implementation](https://github.com/dbt-labs/dbt-adapters/blob/2d5a9cef960651178bb66bb068eb0efaca8c7c59/dbt-adapters/src/dbt/include/global_project/macros/materializations/models/incremental/merge.sql#L15),
[dbt incremental predicates](https://docs.getdbt.com/docs/build/incremental-strategy#about-incremental_predicates).

The predicate must include every existing row that can match the incoming keys,
including late corrections and the old location of records whose date changed.
For example, a seven-day target predicate can hide an older existing key and turn
its correction into an unmatched insert. This failure follows from the generated
ON clause and MERGE semantics; it is not a safe default window. Measure target
partitions scanned, total writes, and full-job time. [Snowflake MERGE](https://docs.snowflake.com/en/sql-reference/sql/merge).

## Replace complete event-time batches and replay affected history

**Candidate:** recurring work repeatedly transforms all history although only a
bounded set of time intervals changes. The inspected Snowflake microbatch macro
deletes the owned half-open event-time interval and inserts its complete result.
The transferable idea is transactional scope replacement, not physical table
partitioning or a per-row upsert. [GitHub Snowflake microbatch macro](https://github.com/dbt-labs/dbt-adapters/blob/2d5a9cef960651178bb66bb068eb0efaca8c7c59/dbt-snowflake/src/dbt/include/snowflake/macros/materializations/incremental/merge.sql),
[adapter time-boundary tests](https://github.com/dbt-labs/dbt-adapters/blob/2d5a9cef960651178bb66bb068eb0efaca8c7c59/dbt-snowflake/tests/functional/adapter/test_incremental_microbatch.py).

Configure or implement event-time filtering on every relevant large upstream
relation; otherwise each batch can rescan all history. Derive lookback from actual
lateness and correction rules, and provide explicit replay for older changes.
Dates moving between intervals require rebuilding both old and new scopes. Keep
window/history context separate from owned output and handle deleted and NULL-date
records. Verify that delete and insert commit together and that retries cannot
expose an incomplete batch. [dbt microbatch](https://docs.getdbt.com/docs/build/incremental-microbatch),
[lookback](https://docs.getdbt.com/reference/resource-configs/lookback),
[batch correctness](dag-and-partitioning.md).

## Avoid empty runs with stream guards or triggered tasks

**Candidate:** scheduled jobs repeatedly resume compute when no relevant input has
changed. A Snowflake-Labs notebook uses `WHEN SYSTEM$STREAM_HAS_DATA(...)` before
its task and consumes the stream in an INSERT. Apply the guard to existing
schedules or evaluate a schedule-free triggered task when arrival-driven execution
meets freshness requirements. [GitHub guarded pipeline](https://github.com/Snowflake-Labs/snowflake-demo-notebooks/blob/765c9b49563940ab45cd9cd9215864857c66671c/Image_Processing_Pipeline_Stream_Task_Cortex_Complete/Image_Processing_Pipeline.ipynb),
[Snowflake triggered tasks](https://docs.snowflake.com/en/user-guide/tasks-triggered).

Track all inputs that can invalidate output, including changing reference tables;
an empty fact stream does not imply the result is unchanged. The guard can return
false positives. Consume its offset through successful transactional DML even when
the resulting change set is empty; a SELECT alone does not consume a stream.
Preserve independent consumer offsets, staleness handling, and required heartbeats
or time-driven snapshots. Measure compute avoided and condition-evaluation costs;
do not claim that polling is universally free. [Stream-guard behavior](https://docs.snowflake.com/en/sql-reference/functions/system_stream_has_data),
[task condition costs](https://docs.snowflake.com/en/sql-reference/sql/create-task).

## Select view or table staging from actual consumer statements

**Candidate:** an incremental job writes and reads an intermediate that is consumed
only once. The inspected dbt Snowflake adapter favors view staging for some
single-statement SQL paths and table staging where stable multi-statement input is
required. This is a concrete fusion candidate. [GitHub staging selection](https://github.com/dbt-labs/dbt-adapters/blob/2d5a9cef960651178bb66bb068eb0efaca8c7c59/dbt-snowflake/src/dbt/include/snowflake/macros/materializations/incremental.sql#L1).

Count generated statements rather than trusting a materialization name or comment.
In particular, inspect actual DELETE/INSERT microbatch output before treating it
as a single statement. A view can reevaluate its producer. Successive statements
inside one READ COMMITTED transaction can observe different source data, so retain
a pinned snapshot or stable materialized input where required. Compare saved
writes against recomputation, compilation, and pruning effects.
[Snowflake isolation](https://docs.snowflake.com/en/sql-reference/transactions#read-committed-isolation-level).

## Distinguish selective updates from skipping unchanged rows

**Candidate:** MERGE computes or writes values for many matched rows that are
unchanged. dbt provides `merge_update_columns` and `merge_exclude_columns` to
control the SET list. They do not, by themselves, skip matched rows.
[GitHub column-selection implementation](https://github.com/dbt-labs/dbt-adapters/blob/2d5a9cef960651178bb66bb068eb0efaca8c7c59/dbt-adapters/src/dbt/include/global_project/macros/materializations/models/incremental/merge.sql#L18),
[dbt merge options](https://docs.getdbt.com/docs/build/incremental-strategy#strategy-specific-configs).

As a separate extension, test `WHEN MATCHED AND <actual-change condition> THEN
UPDATE` using exact, NULL-safe comparisons for relevant fields. Preserve creation
and update audit rules, defaults, and CDC event requirements; suppressing an update
can change downstream streams even when table values would be identical. Do not
use a collision-prone row hash as an exact equality proof. Measure rows updated,
writer work, and total credits; fewer SET columns do not guarantee proportionally
fewer physical bytes written. This no-op suppression is a candidate derived from
the pattern, not functionality demonstrated by the inspected dbt macro.
[Conditional MERGE](https://docs.snowflake.com/en/sql-reference/sql/merge).

## Reduce generated-plan and metadata overhead in Snowpark

Profile client plan construction and metadata requests as well as server
compilation. The controls below were inspected in **Snowpark Python**. For Scala,
transfer equivalent SQL/projection ideas only after verifying its installed API.
Do not set Python session properties on Scala or migrate languages for a tuning
experiment. Read current values before testing one setting at a time.

For a Scala repository, use [the Scala-job playbook](scala-jobs.md) to identify the
runtime, validate the actual APIs, and trace builds, actions, and final writes.

| Candidate | When it may help | Constraints and measurement |
|---|---|---|
| Batch independent `with_column` expressions into `with_columns` or a projection | Long chains generate nested SELECT layers or expensive client plans | Preserve dependencies between replacements, types, and output column order. Measure generated SQL and compile time; do not assume every source simplification changes execution. |
| `session.cte_optimization_enabled` | Repeated subtrees inflate generated SQL | Extracting CTEs does not create a temporary table or guarantee physical reuse. Check branch-specific pruning and nondeterministic-expression evaluation. |
| `session.large_query_breakdown_enabled` | Very large generated plans justify selected materialization boundaries | Experimental in the inspected implementation. It can skip active transactions, missing database/schema context, and view/dynamic-table creation. Confirm emitted CTAS statements and measure all writes, scans, cleanup, and snapshot effects. |
| `session.reduce_describe_query_enabled` | Repeated schema discovery adds substantial request latency | Experimental in the inspected implementation. Validate inferred schemas and count avoided requests; it does not fix expensive server operators. |

Inspected source: [projection batching style guide](https://github.com/snowflakedb/snowpark-python/blob/dd0de61edde30ad54b2a7466e7982f2a5c643b68/snowpark_style_guide.md#L109-L130),
[session controls](https://github.com/snowflakedb/snowpark-python/blob/dd0de61edde30ad54b2a7466e7982f2a5c643b68/src/snowflake/snowpark/session.py),
[automatic breakdown exclusions](https://github.com/snowflakedb/snowpark-python/blob/dd0de61edde30ad54b2a7466e7982f2a5c643b68/src/snowflake/snowpark/_internal/compiler/large_query_breakdown.py#L180-L242).
Official API: [Session](https://docs.snowflake.com/en/developer-guide/snowpark/reference/python/1.53.0/snowpark/api/snowflake.snowpark.Session),
[with_columns replacement and order semantics](https://docs.snowflake.com/en/developer-guide/snowpark/reference/python/1.53.0/snowpark/api/snowflake.snowpark.DataFrame.with_columns).

Release history matters: the inspected changelog records CTE nondeterministic
deduplication fixes in 1.50.0 and self-join deduplication changes in 1.52.0. Check the
actual installed patch level and relevant fixes before testing; newer versions
still need the same correctness gate. [Snowpark changelog](https://github.com/snowflakedb/snowpark-python/blob/dd0de61edde30ad54b2a7466e7982f2a5c643b68/CHANGELOG.md).

## Evidence and applicability

The dbt examples above are pinned implementations from the v1-adapter repository;
the adapter's current development location and installed release can differ.
Inspect the actual compiled SQL before relying on a setting's effect; use the
pinned example as a supporting source reference when needed.
The Snowpark examples are Python-specific; the SQLAlchemy examples demonstrate
native SQL mechanisms. None establishes frequency of adoption or a guaranteed
runtime improvement. Treat reported speedups in external examples as properties
of those workloads, never as the expected result of the current experiment.
