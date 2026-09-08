# Measurement and experiment records

Use this reference when establishing a baseline, attributing a bottleneck, comparing candidates, or handing off an interrupted campaign. Snowflake documentation links were checked on 2026-09-08; verify current availability, permissions, and field definitions when using them.

Contents: measurement boundary; comparable runs; query/operator evidence; credit attribution; baseline, experiment, and handoff records.

## Define the measurement boundary

Time the job from agreed input readiness/start through the completed final output and required publication. Include generated-query compilation, intermediate creation/writes/scans, orchestration waits, final CTAS/INSERT/MERGE, and required cleanup on the critical path. Record validation/diagnostic cost separately from normal production execution, but include it in the experiment budget.

Measure application wall time directly. For a parallel DAG, adding statement durations overstates elapsed time; report critical-path elapsed time and total work separately. Similarly, parent procedure elapsed time can contain child query time. Do not add them as independent wall-clock durations.

Capture a manifest associating run, candidate, baseline revision, snapshot, DAG node, attempt, output object, and actual query ID. Query IDs returned by the client/executor are more dependable than assuming `LAST_QUERY_ID()` still refers to the workload after diagnostic queries run. Mark gate and profiling queries separately so they do not contaminate job measurements.

Use an existing query-tag convention or a dedicated benchmark-session tag such as `perf:orders:C023:r01`; apply it to every participating session and map nodes in the manifest. Preserve/restore prior session settings in reused connections. Tags identify measurements, not application behavior.

## Compare like with like

- Keep inputs, snapshot, parameters, output contract, role/policies, timezone, warehouse type/size, and competing workload comparable. Record planned differences, such as warehouse resizing, as the candidate variable.
- Distinguish compilation, queue/provisioning, execution, and client orchestration bottlenecks. A query can execute faster yet leave total runtime unchanged.
- Use a consistent cache policy. For recomputation benchmarks, disable persisted result reuse in the benchmark session with `ALTER SESSION SET USE_CACHED_RESULT = FALSE`, then restore the previous setting. This does not clear the warehouse data cache. For recurring production workloads, also evaluate the relevant warm-cache behavior. [Persisted query results](https://docs.snowflake.com/en/user-guide/querying-persisted-results), [warehouse cache](https://docs.snowflake.com/en/user-guide/performance-query-warehouse-cache).
- Do not suspend shared warehouses merely to simulate a cold run. Record cache conditions and repeat comparable runs when their information value warrants the credits. Alternating baseline/candidate runs helps expose time-dependent drift.
- For small differences, report repetitions, median/range or another agreed variability measure, and corresponding operator changes. Do not choose only the best candidate run. Large reductions in rows, scans, or spill strengthen a timing claim but do not replace timing.
- Include production-scale distribution and skew. A small sample may miss the largest entity/window partition, range-join overlap, or remote-spill threshold.

Useful formulas, with the same workload and units:

```text
speedup = baseline_wall_time / candidate_wall_time
runtime_reduction_pct = 100 * (baseline_wall_time - candidate_wall_time) / baseline_wall_time
credit_reduction_pct = 100 * (baseline_credits - candidate_credits) / baseline_credits
```

Do not compute a percentage from a zero baseline or missing cost. If only a fraction `f` of baseline time can be removed, even eliminating that fraction entirely caps speedup at `1 / (1 - f)`. Use that bound to avoid expensive work on a negligible stage.

## Query and operator evidence

Export the relevant query profile or operator statistics while available. Query History exposes compilation/execution/queue times in milliseconds, bytes scanned/written, scan-cache fraction, partitions, and spills. Its `percentage_scanned_from_cache` is a fraction from 0 to 1. Use DML row counts or measured output counts; `rows_written_to_result` for CTAS is the statement result row, not the table's row count. Account Usage can lag; inspect the client, Snowsight, or Information Schema for recent execution status. [QUERY_HISTORY](https://docs.snowflake.com/en/sql-reference/account-usage/query_history).

Example history extraction, adapted to the run tag and time window; this reads history and does not execute the job:

```sql
SELECT
    query_id, query_type, execution_status, query_tag,
    warehouse_name, warehouse_type, warehouse_size,
    start_time, end_time,
    total_elapsed_time / 1000.0 AS elapsed_s,
    compilation_time / 1000.0 AS compilation_s,
    execution_time / 1000.0 AS execution_s,
    queued_provisioning_time / 1000.0 AS provisioning_s,
    queued_overload_time / 1000.0 AS overload_s,
    transaction_blocked_time / 1000.0 AS blocked_s,
    bytes_scanned, bytes_written, rows_inserted,
    partitions_scanned, partitions_total,
    percentage_scanned_from_cache,
    bytes_spilled_to_local_storage,
    bytes_spilled_to_remote_storage
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_tag = 'perf:orders:C023:r01'
  AND start_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
ORDER BY start_time, query_id;
```

For each dominant query, inspect scans/pruning, join input/output cardinalities, filter placement, sort/window input width and rows, spills, and writes. Treat query-wide partition totals as a summary; inspect individual table scans to locate poor pruning. Missing operator attributes are unknown, not zero.

The operator function returns completed-query profiles for the past 14 days and requires warehouse MONITOR or OPERATE privileges. Preserve the raw VARIANT fields because their keys depend on operator type. Percentages describe execution breakdown; do not blindly sum them into an additive job timeline. [GET_QUERY_OPERATOR_STATS](https://docs.snowflake.com/en/sql-reference/functions/get_query_operator_stats).

```sql
-- Replace with the query ID captured for the measured statement.
SET perf_query_id = 'replace-with-recorded-query-id';

SELECT
    step_id, operator_id, parent_operators, operator_type,
    operator_statistics, execution_time_breakdown, operator_attributes
FROM TABLE(GET_QUERY_OPERATOR_STATS($perf_query_id))
ORDER BY step_id, operator_id;
```

Large remote spills warrant investigation, but QAS can itself generate small remote-storage writes. Correlate magnitude with the operator profile before concluding that memory exhaustion is the cause. [Memory spillage](https://docs.snowflake.com/en/user-guide/performance-query-warehouse-memory).

## Cost evidence and its limits

For standard warehouses, join captured query IDs to `QUERY_ATTRIBUTION_HISTORY`. `CREDITS_ATTRIBUTED_COMPUTE` accounts for concurrent resource use but excludes idle time, storage, data transfer, cloud services, and other serverless costs. Add QAS credits separately. This view can lag by up to eight hours and omit very short queries; missing records mean unavailable evidence, not zero cost. For procedures, collect root/child IDs and sum each attributed query record once. [QUERY_ATTRIBUTION_HISTORY](https://docs.snowflake.com/en/sql-reference/account-usage/query_attribution_history).

```sql
SELECT
    query_id,
    credits_attributed_compute,
    credits_used_query_acceleration,
    credits_attributed_compute
      + COALESCE(credits_used_query_acceleration, 0) AS compute_plus_qas_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY
WHERE query_tag = 'perf:orders:C023:r01'
  AND start_time >= DATEADD('day', -1, CURRENT_TIMESTAMP());
```

Check coverage against the run manifest before aggregating. Adaptive Warehouses use a different cost surface: inspect the current [QUERY_METERING_HISTORY](https://docs.snowflake.com/en/sql-reference/account-usage/query_metering_history) schema instead of treating absent attribution rows as free execution.

Use warehouse metering over a controlled workload interval when total warehouse cost matters, and account for idle time and overlapping work. Do not attribute every warehouse credit in a shared interval to one job. Storage services, reclustering, search optimization, materialized-view maintenance, and refresh jobs can move cost outside the measured query. Report their amortized cost for recurring workloads. [Cost attribution](https://docs.snowflake.com/en/user-guide/cost-attributing), [storage optimization costs](https://docs.snowflake.com/en/user-guide/performance-query-storage).

If direct cost is unavailable, report runtime and warehouse configuration as evidence. Any credits/hour × elapsed-time estimate must be labelled an estimate, with concurrency and billing assumptions; elapsed query seconds alone are not billed credits.

## Persistent record formats

Prefer existing repository formats. These minimal structures preserve the decision evidence without making each experiment a long report.

`CURRENT_BASELINE.md` contains the current best state, not the diary:

```text
Verified baseline: revision + any preserved patch; verified at timestamp
Original campaign baseline: revision + comparable runtime/cost evidence
Input snapshot and run parameters:
Output contract/schema and target lifecycle:
Gate command and last passing run/evidence:
Benchmark command, measurement boundary, cache policy:
Warehouse/type/size/concurrency and relevant session settings:
Wall time and variability; attributed credits/coverage or unavailable:
Query IDs / manifest / profile artifact paths:
Stage metrics, final-write time, and current dominant operators:
Ranked queue: candidate, hypothesis, impact, confidence, cost, risk
Next intended experiment:
```

Append each completed candidate to `OPTIMIZATION_LOG.md`:

```text
Candidate ID and baseline revision:
Observation and evidence [observed/measured/inferred]:
Hypothesis and proposed isolated change:
Expected plan/metric change:
Correctness risk, experiment cost, confidence:
Implementation revision/patch and generated SQL artifact:
Gate command/result/evidence:
Measurement conditions and run/query IDs:
Wall time before -> after; variability; credits and coverage:
Relevant rows/bytes/spill/compilation/final-write changes:
Decision: KEEP / REVERT-Incorrect / REVERT-Regression / REVERT-Neutral / INCONCLUSIVE
Reason and lesson; when this hypothesis could become relevant again:
Restored or promoted baseline:
```

For interruption recovery, use `OPTIMIZATION_HANDOFF.md` or the repository equivalent:

```text
Current candidate and verified baseline:
Active command/process/job/task/run/query IDs and start time:
Input snapshot, session, warehouse, stage objects, completed stages:
Known state: running / passed / failed / not yet inspected
Where logs/results live and how to inspect the existing run:
Outstanding validation, measurements, and next action:
Remaining budget; cleanup scope; relevant authorization constraints:
```

Never mark an active or uninspected run as passing. Persist failures too; avoiding an expensive repeated dead end is part of optimization.
