# TPCH Revenue Semantic View — User Business Decisions

These are the working business decisions used to generate
`TPCH_REVENUE_SV.sql`. A data owner or steward must review them before the SQL
is deployed in a production environment. They override inference from physical
metadata or data profiles after that review.

---

## Scope and Audience

| Decision | Value |
|----------|-------|
| Purpose | Revenue analysis across regions, nations, customers, and market segments |
| Intended users | Business analysts, data analysts |
| Must answer | Revenue by region/nation/segment, order counts, average order value, revenue trends by date |
| Must NOT answer | Supply-side metrics (SUPPLIER, PARTSUPP, PART tables are excluded from scope) |
| Target name | `SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TPCH_REVENUE_SV` |

`SNOWFLAKE_SAMPLE_DATA` is a shared, read-only source database and is not the
deployment target. The target database and schema must already exist and the
execution role must be allowed to create a Semantic View there.

---

## Table Grain and Primary Keys

| Table | Primary Key | Grain |
|-------|-------------|-------|
| REGION | R_REGIONKEY | One row per region |
| NATION | N_NATIONKEY | One row per nation |
| CUSTOMER | C_CUSTKEY | One row per customer |
| ORDERS | O_ORDERKEY | One row per order |
| LINEITEM | (L_ORDERKEY, L_LINENUMBER) | One row per line item |

---

## Relationships

| Relationship | Direction | Orphans Allowed? |
|--------------|-----------|-----------------|
| LINEITEM.L_ORDERKEY -> ORDERS.O_ORDERKEY | many-to-one | No |
| ORDERS.O_CUSTKEY -> CUSTOMER.C_CUSTKEY | many-to-one | No |
| CUSTOMER.C_NATIONKEY -> NATION.N_NATIONKEY | many-to-one | No |
| NATION.N_REGIONKEY -> REGION.R_REGIONKEY | many-to-one | No |

- No role-playing or alternative relationship paths.

---

## Measures, Facts, and Metrics

### Core Decisions

| Decision | Value | Rationale |
|----------|-------|-----------|
| Revenue definition | `L_EXTENDEDPRICE * (1 - L_DISCOUNT)` | Standard TPC-H net revenue (discount applied, tax excluded) |
| Includes tax? | No | Tax is a separate concern; TPC-H benchmark treats it separately |
| Discount representation | Decimal fraction (expected 0.00-0.10) | Must be confirmed by the discovery query results |
| Returns/cancellations | Include all rows regardless of L_RETURNFLAG or O_ORDERSTATUS | No implicit filtering; users filter via dimensions |
| Order value | `O_TOTALPRICE` (pre-computed on ORDERS table) | Matches order grain |
| Order count | `COUNT(DISTINCT O_ORDERKEY)` | Distinct orders, not line items |
| Aggregation grain | Line item for revenue; order for order count and average order value | Revenue and count aggregate at their declared grains; averages must be recomputed, not summed |
| Null handling | Standard SQL (nulls propagate) | Key columns are non-null; no special treatment needed |
| Currency | Unitless (TPC-H defines no currency column) | No conversion needed |

### Approved Metrics

| Metric Name | Expression | Description |
|-------------|------------|-------------|
| total_revenue | `SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT))` | Total revenue net of discount |
| total_orders | `COUNT(DISTINCT O_ORDERKEY)` | Total number of distinct orders |
| avg_order_value | `AVG(O_TOTALPRICE)` | Average order total price |

---

## Dimensions

| Column | Source Table | Business Name | Synonyms | Notes |
|--------|-------------|---------------|----------|-------|
| R_NAME | REGION | region_name | region | |
| N_NAME | NATION | nation_name | nation, country | |
| C_MKTSEGMENT | CUSTOMER | market_segment | segment | |
| O_ORDERSTATUS | ORDERS | order_status | status | Preserve source codes; business meanings require confirmation |
| O_ORDERDATE | ORDERS | order_date | | Primary time dimension |
| L_SHIPDATE | LINEITEM | ship_date | | Secondary time dimension |
| L_RETURNFLAG | LINEITEM | return_flag | | Preserve source codes; business meanings require confirmation |
| L_LINESTATUS | LINEITEM | line_status | | Preserve source codes; business meanings require confirmation |
| L_SHIPMODE | LINEITEM | ship_mode | shipping method | |

- Primary time dimension: **O_ORDERDATE**
- No fiscal calendar or time-zone rules.
- No sensitive dimensions to omit.

---

## Verified Queries

The following are selected candidate verified queries for the semantic view.
Their SQL must be executed and reviewed in Snowflake before production use:

| # | Natural-Language Question | Description |
|---|--------------------------|-------------|
| 1 | What is the total revenue by region? | SUM of net revenue grouped by R_NAME |
| 2 | How many orders were placed per market segment? | COUNT DISTINCT O_ORDERKEY grouped by C_MKTSEGMENT |
| 3 | What is the average order value by nation? | AVG of O_TOTALPRICE grouped by N_NAME |

No reviewer identity or verification timestamp has been supplied. The generated
SQL therefore does not invent `VERIFIED_BY` or `VERIFIED_AT` values.

---

## Governance and Deployment

| Decision | Value |
|----------|-------|
| Access | All facts, metrics, and dimensions are public |
| CREATE OR REPLACE | Not authorized (use plain CREATE) |
| Owner/role | Not specified (user's current role at execution time) |
| Required grants | Not specified |
| Tags/contacts | None |
| Test assertions | Validation SQL included in the output file |
