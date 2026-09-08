# Snowflake Scala jobs

Read this playbook when a repository contains Scala code that produces or executes
Snowflake work. Keep its language, build tool, job entrypoint, and deployment model.
Apply the main skill's experiment loop; do not substitute a new benchmark or weaken
the repository's deterministic gate.

Contents: runtime detection; repository recovery; build and gate workflow; action
inventory; Scala transformations and DAG stages; final writes; concurrency; Spark,
JDBC, and in-database handlers; records and completion.

## Detect the actual execution runtime

Inspect imports, resolved dependencies, entrypoints, and submitted jobs together.
A `.scala` file or `DataFrame` type alone does not identify the execution engine.
Mixed repositories can require different treatment in different modules.

| Repository evidence | Runtime to investigate | Performance boundary |
|---|---|---|
| `com.snowflake.snowpark` imports and Snowpark Scala dependency | Native Snowpark Scala client | Scala constructs relational plans; actions submit Snowflake work. Profile client construction and generated server SQL separately. |
| `org.apache.spark.sql` plus `net.snowflake.spark.snowflake`, `spark-snowflake`, or Snowflake datasource configuration | Spark with the Snowflake connector | Some operations run in Snowflake and others in Spark. Include connector transfer/staging and Spark execution. |
| `java.sql`, `SnowflakeDriver`, `jdbc:snowflake:`, generated SQL templates | Scala/JDBC job | Inspect emitted statements, binds, round trips, transactions, and result fetching. Snowpark APIs may not exist. |
| `CREATE PROCEDURE` / `CREATE FUNCTION` with `LANGUAGE SCALA`, staged JARs, handler declarations, or Snowpark registration | In-database Scala handler | Separate parent CALL, child SQL, handler computation, and UDF execution. A handler is not necessarily an external client. |

Useful discovery commands from the repository root; narrow paths once the relevant
module is known:

```bash
rg --files -g '*.scala' -g '*.sbt' -g 'pom.xml' -g 'build.sc' -g 'build.mill' -g '*gradle*' -g '*build.properties' -g 'Makefile' -g '*.sh' -g '.github/workflows/*'
rg -l 'com\.snowflake\.snowpark|net\.snowflake\.spark\.snowflake|jdbc:snowflake:|SnowflakeDriver|(?i:language[[:space:]]+scala)' -g '*.scala' -g '*.sql' -g '*.sbt' -g 'pom.xml' .
```

The filename search locates evidence without dumping connection configuration.
Use existing connection providers; keep credentials out of SQL/profile artifacts.
The runtime distinction follows the [Snowpark Scala model](https://docs.snowflake.com/en/developer-guide/snowpark/scala/working-with-dataframes)
and [Spark connector execution](https://docs.snowflake.com/en/user-guide/spark-connector-use).

## Recover the repository's executable baseline

Read `AGENTS.md`, existing optimization records, CI commands, launch scripts, build
definitions, test configuration, SQL resources, and the application main/handler.
Trace the path from run arguments and input snapshots through transformations to
the exact final writer and deterministic comparison.

Record these facts before changing a candidate:

- Relevant module, entrypoint, launch command, and required nonsecret arguments.
- Build tool/wrapper version, Scala binary version, JDK, and resolved Snowpark or
  Spark/connector/JDBC versions. Capture the deployed JAR identity or checksum when
  that is what actually runs; source revision alone does not establish its contents.
- Existing compile, focused-test, deterministic-gate, packaging, and benchmark
  commands, including whether tests connect to Snowflake or consume credits.
- Input/output object configuration, run-wide date/as-of values, timezone, role,
  warehouse, query-tag convention, publication path, and output schema contract.

Use the repository's pinned dependency and toolchain choices. Do not change Scala
binary versions, JDK, connector, packaging, or build tools as incidental cleanup.
A dependency upgrade is a separate candidate with its own compatibility and gate
evidence. Snowpark is distributed as a Maven dependency usable from Scala builds;
follow the installed release's compatibility requirements.
[Snowpark Scala setup](https://docs.snowflake.com/en/developer-guide/snowpark/scala/setup).

For sbt, inspect `build.sbt`, `project/build.properties`, plugins, and CI; compile the
affected project with its existing wrapper/command and select relevant tests. For
Maven, Gradle, Mill, or Scala CLI, use their existing module and test invocation.
These are alternatives, not instructions to try every build tool. Compile success
checks types; it does not prove generated Snowflake SQL is valid or equivalent.

Before an expensive run, use the existing cheap checks to reject invalid candidates.
Run the authoritative gate and representative final-write benchmark before KEEP.
If packaging or deployment affects which code runs, rebuild the required artifact
and verify that the measured job uses it. Keep build, JVM startup, validation, and
production-job timing distinct, including each only in the appropriate boundary.

## Inventory execution actions and hidden repeated work

Map source method and call site to DAG node, input/output grain, action, generated
statement/query IDs, and consumer count. In native Snowpark, a Scala helper returning
a DataFrame normally builds a plan. Reusing a variable or a `lazy val` does not itself
materialize that plan in Snowflake.

Inspect `collect`, `show`, `count`, `toLocalIterator`, `cacheResult`, writer calls,
raw SQL execution, and async actions. Look inside logging interpolation, constructors,
helper methods, retries, and loops: a debugging count before the final writer can
add another expensive action. Remove it only when it is not part of validation or
the production contract. Repeated actions need profile evidence; do not assume
identical source expressions always cause identical physical recomputation.

Time both plan construction and execution. Timing `val result = transform(input)`
does not time the eventual query. A `count()` can let the optimizer avoid expensive
projected expressions, so it is not an equivalent benchmark for the final CTAS.
An iterator reduces client buffering but still transfers data when consumed; it
does not turn local Scala processing into Snowflake computation.

When using `session.sql(...)`, ensure the intended action actually executes it.
Do not add a second action just to obtain a query ID. Keep diagnostics separate from
the measured workload and use the actual submitted statements as evidence.

Use `df.explain(): Unit` for the intended statement list and available plan. Capture
its output through the job's diagnostics. The inspected Scala API does not expose
Python's public `df.queries`; do not build tooling around package-private plans.
The DataFrame's explanation is not the final writer's observed execution profile.
[Scala DataFrame API](https://docs.snowflake.com/en/developer-guide/snowpark/reference/scala/2.12/com/snowflake/snowpark/DataFrame.html),
[Scala query troubleshooting](https://docs.snowflake.com/en/developer-guide/snowpark/scala/troubleshooting).

## Make Scala transformations preserve the relational contract

- Prefer explicit Snowpark column expressions and server-side relational operations
  for large datasets. Check whether a Scala expression is being evaluated locally
  or constructing a SQL expression. Do not `collect()` a large relation merely to
  apply collection `map`, `groupBy`, joins, or sorting in the JVM.
- Batch independent projections when they reduce generated plan depth. Preserve
  replacement dependencies: computing `b` from a newly replaced `a` may require
  another projection. The inspected Scala signature is
  `withColumns(colNames: Seq[String], values: Seq[Column]): DataFrame`; verify the
  installed version. Preserve explicit column order, aliases, types, and metadata.
- Keep transformation helpers free of implicit writes/caches when feasible within
  the candidate. Make the selected materialization boundary visible in the job
  orchestrator. Avoid broad refactoring merely to impose this style.
- At a SPLIT boundary, pass the returned cached DataFrame or reopen the explicit
  stage table for every consumer. If a downstream helper still receives the original
  DataFrame, the expensive lineage may still execute. Materializing one branch does
  not rewrite every reference to it.
- Build date/entity/hash batches from complete business scopes. Preserve lookback,
  late corrections, NULL handling, duplicates, joins, and final fan-in according to
  [DAG and partitioning contracts](dag-and-partitioning.md). Scala loops and Futures
  do not establish semantic independence.
- Preserve decimal precision and scale across literals, arithmetic, UDF arguments,
  and JDBC/Row conversions. Do not route exact decimals through `Double`. Preserve
  timestamp type/timezone, SQL NULL versus primitive defaults, and case-sensitive
  identifiers when simplifying encoders or row mapping.

Python controls such as `cte_optimization_enabled`, `large_query_breakdown_enabled`,
and `reduce_describe_query_enabled` are not established Scala settings. Do not copy
them into this job. Use the installed Scala API and measured explicit stages;
retain [GitHub compiler ideas](github-strategies.md) only where applicable.

## Execute and measure the actual final writer

First classify the FINAL relation and each column's role using
[final-table design](final-tables-and-ctas.md). Trace the explicit final projection
from its Scala producers; a wide output may justify narrow intermediate branches
and late assembly with proven join multiplicity. Preserve the delivered schema.

Make write mode explicit. The inspected Scala writer defaults to **Append**, and
append to an existing table defaults to positional matching (`columnOrder =
"index"`). Use an explicit projection aligned to the target or, where intended,
`.option("columnOrder", "name")`; still verify types and the complete schema.
`Ignore` or accidental append must not make a stale/duplicated candidate look like
a fast successful rebuild.
[Scala writer API](https://docs.snowflake.com/en/developer-guide/snowpark/reference/scala/2.12/com/snowflake/snowpark/DataFrameWriter.html).

Current planner source maps `SaveMode.Overwrite` to replacement CTAS; do not assume
it preserves table identity like a truncate-and-insert. It can affect grants,
metadata, and streams as described in the final-publication playbook. Append can
emit more than one statement when creating a missing target. Inspect the installed
version's actual DDL and capture every relevant query ID.
[Scala writer implementation](https://github.com/snowflakedb/snowpark-java-scala/blob/main/src/main/scala/com/snowflake/snowpark/internal/analyzer/SnowflakePlan.scala#L440-L479).

`saveAsTable` is already an action: do not precede it with `collect()` to force
execution. In contrast, constructing `session.sql(ctasText)` is lazy; execute it
once with an appropriate action such as `.collect()` or `.async.collect()`.
For CTAS this retrieves the statement result, not the new table's entire contents.
[Scala SQL execution](https://docs.snowflake.com/en/developer-guide/snowpark/scala/working-with-dataframes).

An async writer returns `TypedAsyncJob[Unit]`. Persist `getQueryId()` before waiting,
then call `getResult(...)` and propagate errors. `isDone()` alone also includes
failure and cancellation. Reattaching with `session.createAsyncJob(queryId)` returns
`AsyncJob`, which uses `getRows`/`getIterator`, not `getResult`; choose recovery APIs
for the recorded operation and verify its actual status.
[TypedAsyncJob](https://docs.snowflake.com/en/developer-guide/snowpark/reference/scala/2.12/com/snowflake/snowpark/TypedAsyncJob.html),
[async writer](https://docs.snowflake.com/developer-guide/snowpark/reference/scala/2.12/com/snowflake/snowpark/DataFrameWriterAsyncActor.html),
[AsyncJob](https://docs.snowflake.com/en/developer-guide/snowpark/reference/scala/2.12/com/snowflake/snowpark/AsyncJob.html).

Example instrumentation for a uniquely named, owned candidate destination. Supply
the job's approved wait budget and durable submission logger. Match the target's
table kind, schema, and properties through the existing writer or explicit DDL;
this example covers submission/timing, not the full publication contract.

```scala
import com.snowflake.snowpark.{DataFrame, SaveMode}

def writeCandidate(
    finalDf: DataFrame,
    destination: Seq[String],
    waitSeconds: Int,
    recordSubmitted: String => Unit
): (String, Double) = {
  val started = System.nanoTime()
  val job = finalDf.write.mode(SaveMode.ErrorIfExists)
    .async.saveAsTable(destination)
  val queryId = job.getQueryId()
  recordSubmitted(queryId)
  job.getResult(maxWaitTimeInSeconds = waitSeconds)
  val elapsedSeconds = (System.nanoTime() - started) / 1.0e9
  (queryId, elapsedSeconds)
}
```

This timer includes upstream lazy computation and confirmed write completion. Use
the profile to identify writer work; do not label all of it storage time. Run the
authoritative gate on the isolated output before promotion, and include the required
publication path in the end-to-end comparison. Do not replace the existing pipeline
with this helper merely to adopt the instrumentation.

## Coordinate sessions, asynchronous work, and recovery

Use the repository's executor/session model with bounded concurrency. Separate
sessions cannot share session-local temporary tables; use appropriately managed
cross-session stages when needed. For each handoff, follow the
[DAG commit and visibility protocol](dag-and-partitioning.md#scheduling-snapshots-and-recovery):
an already-open pooled consumer session is not guaranteed to see the producer's
latest commit under the default consistency mode. Do not close a session or clean
up an intermediate while any dependent action still runs.

Avoid per-stage `USE`, role, warehouse, timezone, or query-tag mutations racing on a
shared session. Prefer qualified names, stable session state, and supported execution
APIs. For independently executing threads, use an appropriate connection/session pool
with explicit ownership. Do not add `Future`, `.par`, Spark scheduling knobs, or
thread pools and assume warehouse speed will increase.
[Shared-connection considerations](https://docs.snowflake.com/en/developer-guide/driver-connections).

The inspected Scala Session API provides `setQueryTag`, `unsetQueryTag`, and
JSON-merging `updateQueryTag`. Use the repository's tag wrapper and installed API;
`setQueryTag` replaces previous state, while `unsetQueryTag` does not restore a
previous value. Avoid racing tag changes across active branches. Correlate using
action-specific query IDs, not a mutable session last-query value.
[Scala Session API](https://docs.snowflake.com/en/developer-guide/snowpark/reference/scala/2.12/com/snowflake/snowpark/Session.html).

Persist submitted query IDs immediately. Await completion and check failures before
validation, publication, or cleanup. A local wait timeout does not establish that
the server stopped; inspect the submitted query before retrying. Recover the active
run from its query/object manifest instead of launching another append or overwrite.
Tune DAG concurrency separately from the transformation or split candidate.

## Adjust the workflow for other Scala execution paths

### Spark with the Snowflake connector

Inspect both Spark's plan and the SQL the connector actually sends after the
relevant action. Confirm that intended filters, projections, joins, and aggregates
are pushed down. Unsupported operations can move computation and large transfers
to Spark; Spark UDFs cannot be pushed down through this connector. Verify Spark,
Scala, and connector compatibility and `autopushdown` configuration before blaming
the SQL. [Connector architecture](https://docs.snowflake.com/en/user-guide/spark-connector-overview).

`net.snowflake.spark.snowflake.Utils.getLastSelect()` can show emitted SELECT SQL
after data movement. Its last-query state is mutable, so use an isolated action
and correlate with query history when work overlaps. Check installed API support
before using `getLastSelectQueryId`. An explicit connector `query` SELECT can be a
candidate when it improves pushdown while preserving Spark-side semantics.
[Connector usage](https://docs.snowflake.com/en/user-guide/spark-connector-use),
[connector diagnostics implementation](https://github.com/snowflakedb/spark-snowflake/blob/master/src/main/scala/net/snowflake/spark/snowflake/Utils.scala).

Measure Spark stages, shuffle/spill, serialization/transfer, staged files, COPY,
and target publication as well as Snowflake SQL. The final writer may use COPY
rather than CTAS. Preserve existing `truncate_table` and `usestagingtable` behavior
unless changing them is the explicit candidate. Spark `repartition`, `coalesce`,
and broadcast settings apply only to the work actually executed by Spark; they are
not native Snowpark warehouse controls.

### Scala/JDBC SQL orchestration

Inspect complete generated SQL and parameters at each executor call. Capture
statement/result query IDs through the installed JDBC extensions, preserve bind
types and identifier handling, and measure connection setup, execution, fetching,
and local processing separately. Obtain IDs from the responsible statement/result
rather than a shared last-query variable. Do not add Snowpark APIs to a JDBC-only
job. [Snowflake JDBC extensions](https://docs.snowflake.com/en/developer-guide/jdbc/jdbc-using#snowflake-jdbc-api-extensions).

### Scala stored procedures and UDFs

For a procedure, use Snowflake's supplied Session rather than creating a new one.
Keep large relational processing in Snowpark and track child statements separately
from parent CALL elapsed time. Await asynchronous child work before returning;
unfinished child jobs are canceled. Verify the measured procedure actually uses
the rebuilt JAR, handler, imports, packages, and configured runtime.
[Scala procedure guidelines](https://docs.snowflake.com/en/developer-guide/stored-procedure/scala/procedure-scala-overview).

For a UDF, distinguish row-handler CPU and serialization from relational query
cost. Move expensive invariant initialization outside per-row work only when it
preserves correctness. Keep initialization and handlers thread-safe; multiple JVMs
and concurrent invocations mean singleton state is neither global warehouse state
nor a reliable ordered accumulator.
[Scala UDF execution and initialization](https://docs.snowflake.com/en/developer-guide/udf/scala/udf-scala-optimizing).

## Records and completion for Scala candidates

Add the following to the existing baseline/experiment records:

```text
Runtime: Snowpark Scala / Spark connector / JDBC / in-database Scala / mixed
Module + entrypoint + JAR identity:
Scala/JDK/build/client versions:
Compile/test/package/gate/benchmark commands and results:
Transformation method -> DAG node -> action -> query IDs:
Plan-construction and JVM/client overhead:
Generated SQL/profile artifact paths:
Intermediate ownership, session scope, reuse, and cleanup:
Final write mode, projection/schema, target identity, completion evidence:
Full job time/cost; KEEP / REVERT / INCONCLUSIVE:
```

Finish with the actual repository change and measured Snowflake effect, not a claim
that cleaner Scala is faster. Without code, a connection, or a runnable gate, provide
the available diagnosis and concrete next experiment; mark missing execution evidence
explicitly rather than inventing compile, gate, query, or speedup results.

API details were checked against official Snowpark Scala reference pages labelled
1.18.0 on 2026-09-08. Linked Scala 2.12 signatures are examples; select the matching
Scala binary-version and library-release documentation for the actual repository.
