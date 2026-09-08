# Profile-driven Snowflake strategy catalog

Use this reference to turn profile evidence into one isolated candidate. These are hypotheses to test, not a checklist of changes to apply together. Runtime and cost improvements require the skill's deterministic gate and comparable end-to-end measurements.

For concrete patterns inspected in Snowflake and dbt repositories, read [additional GitHub strategies](github-strategies.md): MERGE target pruning, complete time-batch replay, stream guards, view/table staging, unchanged-row suppression, RELY join elimination, ASOF, multi-table INSERT, recurring query families, and Snowpark compiler controls. Each includes applicability limits and source links.

## Relational and cardinality strategies

| Profile observation | Candidate | Semantic proof or failure mode |
|---|---|---|
| Entity × period expansion feeds a large window/sort, then collapses | Calculate or aggregate at the original grain before expanding | Upstream results must not depend on generated periods, period-relative filters, or multiplicity. Preserve empty periods and default rows. |
| Join produces far more rows than either input | Repair unintended many-to-many keys, filter the build side, or preaggregate at the join grain | Verify functional dependencies on production data. Repeated keys may be legitimate facts or history. `DISTINCT` is not a generic repair. |
| Join followed by deduplication used only to test membership | Consider `EXISTS` or a semijoin | Preserve left-side duplicate multiplicity, NULL behavior, and correlated predicates. `NOT IN` and `NOT EXISTS` differ in the presence of NULLs. |
| Range/interval join creates huge candidate sets | Add coarse equality bins and retain the exact range predicate | Generate every bin an interval can touch; a start-time bin alone can drop matches. Preserve inclusive/exclusive boundaries and prevent duplicate interval/event pairs. |
| Repeated large scans/aggregates on the same source | Share a filtered, narrow computation or use conditional aggregation | Sharing can inhibit branch-specific pruning or add writes. Different filters, NULL/default handling, and output grains may prevent equivalence. |
| Wide rows enter a join, window, or materialization | Project required keys and measures early; attach attributes later | Retain all predicates, tie-break keys, and exact types. The later join must be lossless at the intended multiplicity. |
| Large sort/window follows a selective filter | Move a semantically independent filter before the expensive operator | Filtering before ranking, running totals, or an outer join can change surviving results. `QUALIFY` filters window results; moving it is not automatically safe. |
| Several windows sort the same logical data | Align truly equivalent partition/order specifications or reuse a reduced stage | Preserve frame type/bounds, tie handling, NULL ordering, and `IGNORE/RESPECT NULLS`. Adding an arbitrary tie-breaker changes semantics. |
| Expensive global ordering has no consumer | Remove unnecessary sorts in intermediates or final writes | Preserve order used by windows, LIMIT/top-N, ordered aggregates, or the output contract. A table itself does not promise retrieval order. |
| Duplicate elimination dominates UNION or DISTINCT | Use `UNION ALL` or omit a redundant DISTINCT when equivalence is proven | Show that the required multiset is unchanged. Disjoint branches alone do not prove each branch is internally unique. |
| Pivot/unpivot creates very wide or very tall intermediates | Keep a compact working grain and delay the shape transformation | Preserve the final columns, absent categories, NULLs, aggregation, and row multiplicity. See final-table categories. |

These relational equivalence checks apply to each affected operation, even when the deterministic test dataset happens not to contain the relevant edge case. Query-profile operator statistics support the row/scan diagnosis. [Operator statistics](https://docs.snowflake.com/en/sql-reference/functions/get_query_operator_stats).

If a candidate only changes CTE layout or Scala method boundaries, inspect the actual plan. Source reorganization does not establish a physical execution change. For explicit stage boundaries and reuse economics, read [DAG splitting](dag-and-partitioning.md).

## Reduce repeated expression and client work

- Inspect repeated parsing, casts, date arithmetic, regex, JSON extraction, UDF calls, and repeated FLATTEN. Compute once at the narrowest valid grain when profile evidence shows substantial work. A named SQL alias or CTE alone does not prove physical reuse.
- For semi-structured data, select required paths and filter before expansion when semantics allow. Do not interchange missing fields, JSON null, SQL NULL, empty arrays, or `FLATTEN` outer behavior. Persist frequently queried typed fields only when their ingestion/write cost is justified.
- Prefer equivalent native SQL expressions over scalar UDFs or remote calls when those operators dominate. Verify numeric overflow/rounding, string/collation, timestamps/timezones, error behavior, and NULL semantics. Do not replace exact computation with approximate functions under an exact gate.
- In Scala/Snowpark, find unintended repeated actions (`count`, `collect`, writes, debugging/show calls), client fetches, serial driver loops, and re-evaluated query branches. Retain actions required by validation or the job contract. Do not bring a large intermediate to the client to implement a transformation Snowflake can execute.
- Batch small operations or keep processing server-side when round trips dominate. Capture generated SQL and query IDs so an apparent client improvement is not merely deferred Snowflake work.
- Consider skew separately from total cardinality. A hot join key or enormous window partition can dominate. Handle hot keys separately only with a proof of complete, nonoverlapping coverage; arbitrary salting can break window, join, and aggregation semantics.

## Storage and services: match the workload

| Option | Evidence that makes it worth testing | Cost or scope limit |
|---|---|---|
| Natural pruning / clustering | Selective, recurring filters scan too many micro-partitions | Inspect per-table pruning first. Clustering adds maintenance and may not help broad full scans. See [partitioning](dag-and-partitioning.md). |
| Search Optimization Service | Repeated selective lookups, supported searches, or equality joins with few distinct build-side keys | Verify supported predicate/types, edition, build/maintenance/storage cost, and optimizer use. It is not a general full-scan accelerator. |
| Materialized view | An expensive supported transformation or aggregate is reused frequently enough to amortize maintenance | Verify definition restrictions and eligible query rewrite. A multi-table ETL DAG is not automatically a legal materialized view definition. |
| Dynamic tables | A recurring transformation can meet its output/freshness contract through managed refresh | Inspect supported refresh mode, change volume/locality, dependencies, refresh history, and ongoing credits. Incremental refresh can be slower than full refresh. |
| Query Acceleration Service | The measured queries have eligible scan/filter/aggregation work | Check eligibility and measured operator effect; include its separate credits. It does not fix incorrect joins or all compilation/sort bottlenecks. |

Snowflake distinguishes clustering, search optimization, materialized views, and query acceleration by query pattern and cost. Check current edition/account support before implementing a service-specific candidate. [Query optimization options](https://docs.snowflake.com/en/user-guide/performance-query-options).

For selective join acceleration, validate the build-side distinct-key count and the supported search condition against [search optimization for joins](https://docs.snowflake.com/en/user-guide/search-optimization/join-queries). For precomputed relations, check [materialized-view limitations](https://docs.snowflake.com/en/user-guide/views-materialized) rather than assuming arbitrary SQL is supported.

For dynamic tables, profile changed grouping/window keys and refresh work, not just a SELECT of the already refreshed output. Preserve the required global window semantics even if adding `PARTITION BY` would reduce refresh work. [Incremental refresh optimization](https://docs.snowflake.com/en/user-guide/dynamic-tables/refresh-optimization).

## Warehouse and concurrency strategies

First determine whether the dominant delay is compilation, queueing, memory pressure, scanning, or the final write. Test warehouse configuration separately from a SQL rewrite so the result remains attributable.

- **Memory/spill:** reducing rows/width or a semantically safe batch split can reduce memory demand. Test a larger warehouse when memory or execution capacity is the observed limit, and compare credits as well as elapsed time. A larger warehouse is not a guaranteed cost increase or decrease for the completed workload. [Memory spillage](https://docs.snowflake.com/en/user-guide/performance-query-warehouse-memory).
- **Queueing/concurrency:** control overlapping DAG work, isolate competing workloads when appropriate, or evaluate multi-cluster capacity. Multi-cluster warehouses primarily address concurrent queries; scaling cluster count is not a promise to accelerate one slow query. [Multi-cluster warehouses](https://docs.snowflake.com/en/user-guide/warehouses-multicluster).
- **Cache/resume behavior:** match auto-suspend to the actual workload and cost objective. Suspending drops warehouse cache; keeping it warm also costs idle credits. Measure the relevant repeated-job cadence. [Warehouse cache](https://docs.snowflake.com/en/user-guide/performance-query-warehouse-cache).
- **Compilation:** consider reducing generated query complexity or introducing a selective shared stage before increasing warehouse size. Establish whether compilation, execution, or client SQL generation actually dominates.
- **Parallelism:** parallelize independent DAG nodes only after dependencies and snapshot consistency are explicit. Compare critical-path improvement with queueing, spill, total credits, and recomputation. More simultaneous statements can make the whole job slower.

Use [measurement and records](measurement-and-records.md) to distinguish queue relief, real execution improvement, and cost moved to background services. Reprofile after each kept candidate instead of continuing to tune a bottleneck that no longer dominates.
