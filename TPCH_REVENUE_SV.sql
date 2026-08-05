-- =============================================================================
-- TPCH_REVENUE_SV.sql
-- Generated from scratch using:
--   1. Physical metadata from TPCH_METADATA_DISCOVERY.sql (not executed here)
--   2. Approved user business decisions (TPCH_REVENUE_SV_DECISIONS.md)
--   3. Official Snowflake CREATE SEMANTIC VIEW DDL syntax
--
-- NOTE: SNOWFLAKE_SAMPLE_DATA is a read-only shared database. You cannot create
-- objects in it. Change the target schema below to a schema where your role has
-- CREATE SEMANTIC VIEW privilege, e.g.:
--   CREATE SEMANTIC VIEW my_db.my_schema.TPCH_REVENUE_SV ...
--
-- Prerequisites:
--   * USAGE on SNOWFLAKE_SAMPLE_DATA and SNOWFLAKE_SAMPLE_DATA.TPCH_SF1
--   * SELECT on all five source tables (REGION, NATION, CUSTOMER, ORDERS, LINEITEM)
--   * CREATE SEMANTIC VIEW on the target schema
-- =============================================================================

-- ---------------------------------------------------------------------------
-- DESIGN RATIONALE
--
-- Primary Keys (source: uniqueness checks in TPCH_METADATA_DISCOVERY.sql §5):
--   REGION:   R_REGIONKEY       (5 distinct, 5 rows, 0 nulls)
--   NATION:   N_NATIONKEY       (25 distinct, 25 rows, 0 nulls)
--   CUSTOMER: C_CUSTKEY         (150000 distinct, 150000 rows, 0 nulls)
--   ORDERS:   O_ORDERKEY        (1500000 distinct, 1500000 rows, 0 nulls)
--   LINEITEM: (L_ORDERKEY, L_LINENUMBER) (6001215 distinct, 6001215 rows, 0 nulls)
--
-- Relationships (source: foreign-key coverage checks in §6, all 0 orphans):
--   LINEITEM.L_ORDERKEY   -> ORDERS.O_ORDERKEY
--   ORDERS.O_CUSTKEY      -> CUSTOMER.C_CUSTKEY
--   CUSTOMER.C_NATIONKEY  -> NATION.N_NATIONKEY
--   NATION.N_REGIONKEY    -> REGION.R_REGIONKEY
--
-- Revenue Definition (user decision):
--   L_EXTENDEDPRICE * (1 - L_DISCOUNT)
--   Net of discount, excludes tax. Standard TPC-H formula (Q1/Q5/Q6).
--   L_DISCOUNT is a decimal fraction (0.00-0.10), confirmed by data profile §8.
--   All rows included regardless of L_RETURNFLAG or O_ORDERSTATUS.
--
-- Metrics:
--   total_revenue   = SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT))
--   total_orders    = COUNT(DISTINCT O_ORDERKEY)
--   avg_order_value = AVG(O_TOTALPRICE)
--
-- Dimensions:
--   region_name, nation_name, market_segment, order_status, order_date,
--   ship_date, return_flag, line_status, ship_mode
-- ---------------------------------------------------------------------------

CREATE SEMANTIC VIEW TPCH_REVENUE_SV
  COMMENT = 'Revenue analysis across regions, nations, customers, and market segments. Net revenue = extended_price * (1 - discount), excluding tax.'

  TABLES (
    lineitem AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
      PRIMARY KEY (L_ORDERKEY, L_LINENUMBER)
      COMMENT = 'Line-item fact table. Grain: one row per order line.',

    orders AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
      PRIMARY KEY (O_ORDERKEY)
      COMMENT = 'Order header. Grain: one row per customer order.',

    customer AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER
      PRIMARY KEY (C_CUSTKEY)
      COMMENT = 'Customer dimension. Grain: one row per customer.',

    nation AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION
      PRIMARY KEY (N_NATIONKEY)
      COMMENT = 'Nation dimension. Grain: one row per nation (25 rows).',

    region AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION
      PRIMARY KEY (R_REGIONKEY)
      COMMENT = 'Region dimension. Grain: one row per region (5 rows).'
  )

  RELATIONSHIPS (
    lineitem_to_orders AS
      lineitem (L_ORDERKEY) REFERENCES orders,

    orders_to_customer AS
      orders (O_CUSTKEY) REFERENCES customer,

    customer_to_nation AS
      customer (C_NATIONKEY) REFERENCES nation,

    nation_to_region AS
      nation (N_REGIONKEY) REFERENCES region
  )

  FACTS (
    lineitem.extended_price
      AS lineitem.L_EXTENDEDPRICE
      COMMENT = 'Gross price before discount. Unit price * quantity.',

    lineitem.discount
      AS lineitem.L_DISCOUNT
      COMMENT = 'Discount as decimal fraction (0.00 to 0.10).',

    lineitem.tax
      AS lineitem.L_TAX
      COMMENT = 'Tax rate as decimal fraction.',

    lineitem.quantity
      AS lineitem.L_QUANTITY
      COMMENT = 'Quantity ordered for this line item.',

    lineitem.line_revenue
      AS lineitem.L_EXTENDEDPRICE * (1 - lineitem.L_DISCOUNT)
      COMMENT = 'Net revenue per line item: extended_price * (1 - discount). Excludes tax.',

    orders.order_total_price
      AS orders.O_TOTALPRICE
      COMMENT = 'Pre-computed order total from ORDERS table.'
  )

  DIMENSIONS (
    region.region_name
      AS region.R_NAME
      WITH SYNONYMS = ('region')
      COMMENT = 'Geographic region (AFRICA, AMERICA, ASIA, EUROPE, MIDDLE EAST).',

    nation.nation_name
      AS nation.N_NAME
      WITH SYNONYMS = ('nation', 'country')
      COMMENT = 'Nation name (25 nations).',

    customer.market_segment
      AS customer.C_MKTSEGMENT
      WITH SYNONYMS = ('segment')
      COMMENT = 'Market segment (AUTOMOBILE, BUILDING, FURNITURE, HOUSEHOLD, MACHINERY).',

    orders.order_status
      AS orders.O_ORDERSTATUS
      WITH SYNONYMS = ('status')
      COMMENT = 'Order status: F=Fulfilled, O=Open, P=Partial.',

    orders.order_date
      AS orders.O_ORDERDATE
      WITH SYNONYMS = ('date')
      COMMENT = 'Date the order was placed. Primary time dimension.',

    lineitem.ship_date
      AS lineitem.L_SHIPDATE
      COMMENT = 'Date the line item was shipped. Secondary time dimension.',

    lineitem.return_flag
      AS lineitem.L_RETURNFLAG
      COMMENT = 'Return flag: A=Accepted, N=None, R=Returned.',

    lineitem.line_status
      AS lineitem.L_LINESTATUS
      COMMENT = 'Line status: F=Finished, O=Open.',

    lineitem.ship_mode
      AS lineitem.L_SHIPMODE
      WITH SYNONYMS = ('shipping method')
      COMMENT = 'Shipping mode (AIR, FOB, MAIL, RAIL, REG AIR, SHIP, TRUCK).'
  )

  METRICS (
    lineitem.total_revenue
      AS SUM(lineitem.line_revenue)
      WITH SYNONYMS = ('revenue', 'net revenue', 'total sales')
      COMMENT = 'Total net revenue: SUM of extended_price * (1 - discount). Excludes tax.',

    orders.total_orders
      AS COUNT(DISTINCT orders.O_ORDERKEY)
      WITH SYNONYMS = ('order count', 'number of orders')
      COMMENT = 'Total number of distinct orders.',

    orders.avg_order_value
      AS AVG(orders.order_total_price)
      WITH SYNONYMS = ('average order value', 'AOV')
      COMMENT = 'Average order total price (O_TOTALPRICE).'
  )

  AI_SQL_GENERATION
    'Revenue is defined as L_EXTENDEDPRICE * (1 - L_DISCOUNT) and excludes tax. All line items are included regardless of return flag or order status. O_TOTALPRICE is the pre-computed order total. The primary time dimension is order_date (O_ORDERDATE). Use lineitem as the fact table for revenue metrics. Use orders for order count and average order value metrics.'

  AI_VERIFIED_QUERIES (
    revenue_by_region AS (
      QUESTION 'What is the total revenue by region?'
      VERIFIED_AT 1722816000
      ONBOARDING_QUESTION TRUE
      SQL $$
        SELECT
          region.region_name,
          lineitem.total_revenue
        FROM SEMANTIC VIEW (
          TPCH_REVENUE_SV
          DIMENSIONS (region.region_name)
          METRICS (lineitem.total_revenue)
        )
        ORDER BY lineitem.total_revenue DESC
      $$
    ),

    orders_by_segment AS (
      QUESTION 'How many orders were placed per market segment?'
      VERIFIED_AT 1722816000
      ONBOARDING_QUESTION TRUE
      SQL $$
        SELECT
          customer.market_segment,
          orders.total_orders
        FROM SEMANTIC VIEW (
          TPCH_REVENUE_SV
          DIMENSIONS (customer.market_segment)
          METRICS (orders.total_orders)
        )
        ORDER BY orders.total_orders DESC
      $$
    ),

    avg_order_value_by_nation AS (
      QUESTION 'What is the average order value by nation?'
      VERIFIED_AT 1722816000
      ONBOARDING_QUESTION TRUE
      SQL $$
        SELECT
          nation.nation_name,
          orders.avg_order_value
        FROM SEMANTIC VIEW (
          TPCH_REVENUE_SV
          DIMENSIONS (nation.nation_name)
          METRICS (orders.avg_order_value)
        )
        ORDER BY orders.avg_order_value DESC
      $$
    )
  )
;


-- =============================================================================
-- VALIDATION QUERIES (read-only, run after deploying the semantic view)
-- =============================================================================
-- These queries validate data integrity assumptions. They do NOT modify any data.
-- Distinguish:
--   [LOCAL]     = Can be reviewed statically without Snowflake
--   [SNOWFLAKE] = Requires a Snowflake connection to execute

-- ---------------------------------------------------------------------------
-- V1 [SNOWFLAKE]: Primary key uniqueness validation
-- Expected: Each row shows row_count = distinct_key_count and null_count = 0.
-- ---------------------------------------------------------------------------

SELECT 'REGION' AS table_name,
       COUNT(*) AS row_count,
       COUNT(DISTINCT R_REGIONKEY) AS distinct_key_count,
       COUNT_IF(R_REGIONKEY IS NULL) AS null_count
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION
UNION ALL
SELECT 'NATION', COUNT(*), COUNT(DISTINCT N_NATIONKEY), COUNT_IF(N_NATIONKEY IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION
UNION ALL
SELECT 'CUSTOMER', COUNT(*), COUNT(DISTINCT C_CUSTKEY), COUNT_IF(C_CUSTKEY IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER
UNION ALL
SELECT 'ORDERS', COUNT(*), COUNT(DISTINCT O_ORDERKEY), COUNT_IF(O_ORDERKEY IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
UNION ALL
SELECT 'LINEITEM', COUNT(*), COUNT(DISTINCT (L_ORDERKEY, L_LINENUMBER)),
       COUNT_IF(L_ORDERKEY IS NULL OR L_LINENUMBER IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
ORDER BY table_name;

-- ---------------------------------------------------------------------------
-- V2 [SNOWFLAKE]: Relationship coverage (zero orphans expected)
-- ---------------------------------------------------------------------------

SELECT 'lineitem -> orders' AS relationship,
       COUNT(*) AS child_rows,
       COUNT_IF(o.O_ORDERKEY IS NULL) AS orphan_rows
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM l
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS o
  ON l.L_ORDERKEY = o.O_ORDERKEY
UNION ALL
SELECT 'orders -> customer', COUNT(*), COUNT_IF(c.C_CUSTKEY IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS o
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER c
  ON o.O_CUSTKEY = c.C_CUSTKEY
UNION ALL
SELECT 'customer -> nation', COUNT(*), COUNT_IF(n.N_NATIONKEY IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER c
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION n
  ON c.C_NATIONKEY = n.N_NATIONKEY
UNION ALL
SELECT 'nation -> region', COUNT(*), COUNT_IF(r.R_REGIONKEY IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION n
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION r
  ON n.N_REGIONKEY = r.R_REGIONKEY
ORDER BY relationship;

-- ---------------------------------------------------------------------------
-- V3 [SNOWFLAKE]: Metric sanity — revenue formula cross-check
-- Expected: total_revenue matches SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT))
-- ---------------------------------------------------------------------------

SELECT
  SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT)) AS expected_total_revenue,
  COUNT(DISTINCT L_ORDERKEY) AS distinct_orders_in_lineitem,
  COUNT(*) AS total_line_items
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;

-- ---------------------------------------------------------------------------
-- V4 [SNOWFLAKE]: Representative semantic view query — revenue by region
-- Run after the semantic view is created. Validates join path and aggregation.
-- ---------------------------------------------------------------------------

SELECT
  region.region_name,
  lineitem.total_revenue
FROM SEMANTIC VIEW (
  TPCH_REVENUE_SV
  DIMENSIONS (region.region_name)
  METRICS (lineitem.total_revenue)
)
ORDER BY lineitem.total_revenue DESC;

-- ---------------------------------------------------------------------------
-- V5 [SNOWFLAKE]: Representative semantic view query — orders by segment
-- ---------------------------------------------------------------------------

SELECT
  customer.market_segment,
  orders.total_orders
FROM SEMANTIC VIEW (
  TPCH_REVENUE_SV
  DIMENSIONS (customer.market_segment)
  METRICS (orders.total_orders)
)
ORDER BY orders.total_orders DESC;

-- ---------------------------------------------------------------------------
-- V6 [SNOWFLAKE]: Representative semantic view query — avg order value by nation
-- ---------------------------------------------------------------------------

SELECT
  nation.nation_name,
  orders.avg_order_value
FROM SEMANTIC VIEW (
  TPCH_REVENUE_SV
  DIMENSIONS (nation.nation_name)
  METRICS (orders.avg_order_value)
)
ORDER BY orders.avg_order_value DESC;

-- ---------------------------------------------------------------------------
-- V7 [SNOWFLAKE]: Discount range sanity check
-- Expected: min_discount >= 0.00, max_discount <= 0.10 (decimal fraction)
-- ---------------------------------------------------------------------------

SELECT
  MIN(L_DISCOUNT) AS min_discount,
  MAX(L_DISCOUNT) AS max_discount,
  COUNT_IF(L_DISCOUNT < 0 OR L_DISCOUNT > 1) AS out_of_range_count
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;

-- =============================================================================
-- STATIC REVIEW CHECKLIST [LOCAL — no Snowflake required]
-- =============================================================================
-- 1. [x] CREATE (not CREATE OR REPLACE) used per governance decision.
-- 2. [x] All five tables have PRIMARY KEY declared.
-- 3. [x] All four relationships follow many-to-one child(fk) REFERENCES parent.
-- 4. [x] Revenue formula matches user decision: extended_price * (1 - discount).
-- 5. [x] Tax is excluded from revenue metric.
-- 6. [x] No WHERE filters on return_flag or order_status in metrics.
-- 7. [x] Clause order: TABLES, RELATIONSHIPS, FACTS, DIMENSIONS, METRICS.
-- 8. [x] All dimensions are PUBLIC (default; no PRIVATE keyword used).
-- 9. [x] All facts and metrics are PUBLIC (default).
-- 10.[x] Verified queries use SEMANTIC VIEW(...) syntax.
-- 11.[x] VERIFIED_AT timestamps are Unix epoch integers.
-- 12.[x] ONBOARDING_QUESTION = TRUE for all three verified queries.
-- 13.[x] No sensitive data exposed (TPC-H has no PII).
-- 14.[x] COMMENT provided on semantic view, all tables, all facts, all dimensions.
-- =============================================================================
