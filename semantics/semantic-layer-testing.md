# Automated Data Testing with the Snowflake Semantic Layer

This document explains the end-to-end example built in this session: a semantic view on TPC-H sample data with verified queries used as automated test assertions, scheduled to run daily.

## Overview

The semantic layer in Snowflake (via **Semantic Views**) provides a business-friendly abstraction over raw tables. **Verified Queries (VQRs)** are known-good SQL paired with natural language questions that guide Cortex Analyst. This example repurposes VQRs as regression tests — if the underlying data changes shape, the tests catch it.

## What Was Created

All objects live in `SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS`.

| Object | Type | Purpose |
|--------|------|---------|
| `TPCH_REVENUE_SV` | Semantic View | Business model over TPC-H data |
| `TEST_SEMANTIC_LAYER()` | Procedure | Runs 6 automated tests, returns pass/fail table |
| `RUN_AND_LOG_TESTS()` | Procedure | Wrapper that logs results to history |
| `TEST_HISTORY` | Table | Persists all test runs for trending |
| `DAILY_SEMANTIC_TESTS` | Task | Runs tests daily at 6 AM ET |

## The Semantic View

Built on `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1` with:

- **5 tables**: REGION, NATION, CUSTOMER, ORDERS, LINEITEM
- **4 relationships**: region -> nation -> customer -> orders -> lineitem
- **4 facts**: order_total, extended_price, discount, quantity
- **7 dimensions**: region_name, nation_name, customer_name, market_segment, order_date, order_status, ship_date
- **3 metrics**: total_revenue, order_count, avg_order_value
- **3 verified queries** (see below)

## Verified Queries as Test Assertions

Each VQR pairs a question with its expected SQL:

| VQR Name | Question | Assertion |
|----------|----------|-----------|
| `revenue_by_region` | "What is the total revenue by region?" | Returns exactly 5 rows |
| `top_customers_by_spend` | "Who are the top 10 customers by total spend?" | Returns exactly 10 rows |
| `avg_order_by_segment` | "What is the average order value by market segment?" | Returns exactly 5 rows |

## The 6 Automated Tests

```
TEST_NAME                  | What It Checks
---------------------------|------------------------------------------------
semantic_view_exists       | The semantic view is deployed and accessible
vqr_revenue_by_region      | VQR SQL runs and returns 5 regions
vqr_top_customers          | VQR SQL runs and returns 10 customers
vqr_avg_order_by_segment   | VQR SQL runs and returns 5 segments
source_data_present        | Underlying LINEITEM table has rows
metric_revenue_positive    | Revenue metric is positive for all regions
```

## How to Run

```sql
-- Run tests interactively (returns a table)
CALL SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TEST_SEMANTIC_LAYER();

-- Run and persist results to history
CALL SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.RUN_AND_LOG_TESTS();

-- View historical results
SELECT run_at, test_name, status, details
FROM SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TEST_HISTORY
ORDER BY run_at DESC, test_name;

-- Check task status
SHOW TASKS IN SCHEMA SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS;
```

## Architecture

```
+---------------------+       +------------------------+
|  TPCH_REVENUE_SV    |       |  TEST_SEMANTIC_LAYER() |
|  (Semantic View)    |       |  (Test Procedure)      |
|                     |       |                        |
|  - Tables           |       |  - Existence check     |
|  - Relationships    |<------+  - VQR SQL execution   |
|  - Metrics          |       |  - Data freshness      |
|  - Verified Queries |       |  - Metric sanity       |
+---------------------+       +------------------------+
                                        |
                                        v
                              +------------------------+
                              |  RUN_AND_LOG_TESTS()   |
                              |  (Logging Wrapper)     |
                              +------------------------+
                                        |
                                        v
+---------------------+       +------------------------+
|  TEST_HISTORY       |<------|  DAILY_SEMANTIC_TESTS  |
|  (Results Table)    |       |  (Scheduled Task)      |
|                     |       |  Cron: 0 6 * * *       |
+---------------------+       +------------------------+
```

## Key Design Decisions

1. **VQRs serve dual purpose** — They guide Cortex Analyst for user queries AND act as regression tests. One artifact, two benefits.

2. **Tests are idempotent** — Each test is a SELECT that checks row counts or value constraints. No side effects on source data.

3. **History enables trending** — The `TEST_HISTORY` table lets you detect when a test started failing and correlate with upstream changes.

4. **Procedure returns a table** — `TEST_SEMANTIC_LAYER()` returns structured results, so it can be consumed by dashboards or alerting.

## Extending This Pattern

- **Add more VQRs**: Each new verified query is both a Cortex Analyst hint and a new test case.
- **Add value assertions**: Check that `total_revenue` for EUROPE is within an expected range (not just positive).
- **Use `EXECUTE_AI_EVALUATION`**: Run Cortex Analyst evaluations to test whether the AI *generates* correct SQL from natural language, not just that the VQR SQL compiles.
- **Add alerting**: Create an Alert that fires when any test returns FAIL status.
- **Cross-environment testing**: Run the same tests against dev/staging/prod semantic views to catch drift.

## Cleanup

To remove everything:

```sql
ALTER TASK SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.DAILY_SEMANTIC_TESTS SUSPEND;
DROP SCHEMA SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS CASCADE;
```
