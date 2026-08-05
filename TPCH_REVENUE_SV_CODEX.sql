-- TPCH_REVENUE_SV.sql
--
-- Generated without reading an existing Semantic View CSV.
-- Inputs:
--   1. TPCH_METADATA_DISCOVERY.sql and the supplied TPCH table DDL
--   2. TPCH_REVENUE_SV_DECISIONS.md
--   3. create-semantic-view.md
--
-- This file has been statically checked against the local syntax reference.
-- It has not been compiled or executed because this workspace has no Snowflake
-- connection. Run the discovery queries and review their results before
-- production deployment.
--
-- Required execution privileges:
--   * USAGE on source and target databases/schemas
--   * SELECT on the five source tables
--   * CREATE SEMANTIC VIEW on SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS
--
-- Plain CREATE is intentional: this file does not replace an existing object.

CREATE SEMANTIC VIEW SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TPCH_REVENUE_SV
  TABLES (
    region AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION
      PRIMARY KEY (R_REGIONKEY)
      COMMENT = 'One row per geographic region',

    nation AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION
      PRIMARY KEY (N_NATIONKEY)
      COMMENT = 'One row per nation',

    customer AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER
      PRIMARY KEY (C_CUSTKEY)
      COMMENT = 'One row per customer',

    orders AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
      PRIMARY KEY (O_ORDERKEY)
      COMMENT = 'One row per order',

    lineitem AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
      PRIMARY KEY (L_ORDERKEY, L_LINENUMBER)
      COMMENT = 'One row per order line item'
  )

  RELATIONSHIPS (
    nation_to_region AS
      nation (N_REGIONKEY) REFERENCES region (R_REGIONKEY),

    customer_to_nation AS
      customer (C_NATIONKEY) REFERENCES nation (N_NATIONKEY),

    orders_to_customer AS
      orders (O_CUSTKEY) REFERENCES customer (C_CUSTKEY),

    lineitem_to_orders AS
      lineitem (L_ORDERKEY) REFERENCES orders (O_ORDERKEY)
  )

  FACTS (
    PUBLIC lineitem.extended_price AS L_EXTENDEDPRICE
      COMMENT = 'Gross extended price before discount',

    PUBLIC lineitem.discount AS L_DISCOUNT
      COMMENT = 'Discount represented as a decimal fraction',

    PUBLIC lineitem.tax AS L_TAX
      COMMENT = 'Tax rate represented as a decimal fraction',

    PUBLIC lineitem.quantity AS L_QUANTITY
      COMMENT = 'Quantity ordered for the line item',

    PUBLIC lineitem.line_revenue AS
      L_EXTENDEDPRICE * (1 - L_DISCOUNT)
      COMMENT = 'Revenue after discount and before tax at line-item grain',

    PUBLIC orders.order_total_price AS O_TOTALPRICE
      COMMENT = 'Precomputed total price at order grain'
  )

  DIMENSIONS (
    PUBLIC region.region_name AS R_NAME
      WITH SYNONYMS = ('region')
      COMMENT = 'Geographic region name',

    PUBLIC nation.nation_name AS N_NAME
      WITH SYNONYMS = ('nation', 'country')
      COMMENT = 'Nation name',

    PUBLIC customer.market_segment AS C_MKTSEGMENT
      WITH SYNONYMS = ('segment')
      COMMENT = 'Customer market segment',

    PUBLIC orders.order_status AS O_ORDERSTATUS
      WITH SYNONYMS = ('status')
      COMMENT = 'Order status code; interpret codes according to approved business definitions',

    PUBLIC orders.order_date AS O_ORDERDATE
      WITH SYNONYMS = ('order date')
      COMMENT = 'Date the order was placed; primary time dimension',

    PUBLIC lineitem.ship_date AS L_SHIPDATE
      WITH SYNONYMS = ('shipping date')
      COMMENT = 'Date the line item was shipped',

    PUBLIC lineitem.return_flag AS L_RETURNFLAG
      COMMENT = 'Return-status code from the source data',

    PUBLIC lineitem.line_status AS L_LINESTATUS
      COMMENT = 'Line-status code from the source data',

    PUBLIC lineitem.ship_mode AS L_SHIPMODE
      WITH SYNONYMS = ('shipping method')
      COMMENT = 'Shipping mode'
  )

  METRICS (
    PUBLIC lineitem.total_revenue AS
      SUM(lineitem.L_EXTENDEDPRICE * (1 - lineitem.L_DISCOUNT))
      WITH SYNONYMS = ('revenue', 'net revenue', 'total sales')
      COMMENT = 'Total revenue after discount and before tax',

    PUBLIC orders.total_orders AS
      COUNT(DISTINCT orders.O_ORDERKEY)
      WITH SYNONYMS = ('order count', 'number of orders')
      COMMENT = 'Count of distinct orders',

    PUBLIC orders.avg_order_value AS
      AVG(orders.O_TOTALPRICE)
      WITH SYNONYMS = ('average order value', 'AOV')
      COMMENT = 'Average of the source order total price'
  )

  COMMENT = 'Revenue analysis across regions, nations, customers, and market segments. Revenue is extended price after discount and before tax.'

  AI_SQL_GENERATION
    'Revenue is L_EXTENDEDPRICE * (1 - L_DISCOUNT) and excludes tax. Include all line items unless the user explicitly requests a status or return filter. Use order_date as the primary time dimension. Use lineitem for revenue and orders for order count and average order value.'

  -- The decision input selects these query definitions but supplies neither a
  -- verifier identity nor a trustworthy execution timestamp. Optional
  -- VERIFIED_BY and VERIFIED_AT properties are therefore omitted.
  AI_VERIFIED_QUERIES (
    revenue_by_region AS (
      QUESTION 'What is the total revenue by region?'
      ONBOARDING_QUESTION TRUE
      SQL $$
        SELECT
          r.R_NAME AS region_name,
          SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS total_revenue
        FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM AS l
        JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS AS o
          ON l.L_ORDERKEY = o.O_ORDERKEY
        JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER AS c
          ON o.O_CUSTKEY = c.C_CUSTKEY
        JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION AS n
          ON c.C_NATIONKEY = n.N_NATIONKEY
        JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION AS r
          ON n.N_REGIONKEY = r.R_REGIONKEY
        GROUP BY r.R_NAME
        ORDER BY total_revenue DESC
      $$
    ),

    orders_by_segment AS (
      QUESTION 'How many orders were placed per market segment?'
      ONBOARDING_QUESTION TRUE
      SQL $$
        SELECT
          c.C_MKTSEGMENT AS market_segment,
          COUNT(DISTINCT o.O_ORDERKEY) AS total_orders
        FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS AS o
        JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER AS c
          ON o.O_CUSTKEY = c.C_CUSTKEY
        GROUP BY c.C_MKTSEGMENT
        ORDER BY total_orders DESC
      $$
    ),

    avg_order_value_by_nation AS (
      QUESTION 'What is the average order value by nation?'
      ONBOARDING_QUESTION TRUE
      SQL $$
        SELECT
          n.N_NAME AS nation_name,
          AVG(o.O_TOTALPRICE) AS avg_order_value
        FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS AS o
        JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER AS c
          ON o.O_CUSTKEY = c.C_CUSTKEY
        JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION AS n
          ON c.C_NATIONKEY = n.N_NATIONKEY
        GROUP BY n.N_NAME
        ORDER BY avg_order_value DESC
      $$
    )
  );

-- ---------------------------------------------------------------------------
-- Post-deployment validation
-- ---------------------------------------------------------------------------

-- Inspect Snowflake's normalized metadata.
DESCRIBE SEMANTIC VIEW
  SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TPCH_REVENUE_SV;

-- Inspect Snowflake's canonical creation statement.
SELECT GET_DDL(
  'SEMANTIC_VIEW',
  'SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TPCH_REVENUE_SV'
);

-- Validate the candidate composite key. Expected: row_count equals
-- distinct_key_count and null_key_count is zero.
SELECT
  COUNT(*) AS row_count,
  COUNT(DISTINCT L_ORDERKEY, L_LINENUMBER) AS distinct_key_count,
  COUNT_IF(L_ORDERKEY IS NULL OR L_LINENUMBER IS NULL) AS null_key_count
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;

-- Validate the full relationship path. Expected: orphan_rows is zero.
SELECT COUNT_IF(
         o.O_ORDERKEY IS NULL
         OR c.C_CUSTKEY IS NULL
         OR n.N_NATIONKEY IS NULL
         OR r.R_REGIONKEY IS NULL
       ) AS orphan_rows
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM AS l
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS AS o
  ON l.L_ORDERKEY = o.O_ORDERKEY
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER AS c
  ON o.O_CUSTKEY = c.C_CUSTKEY
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION AS n
  ON c.C_NATIONKEY = n.N_NATIONKEY
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION AS r
  ON n.N_REGIONKEY = r.R_REGIONKEY;

-- Query the governed metric by region. SEMANTIC_VIEW uses an underscore;
-- DIMENSIONS and METRICS do not wrap their expression lists in parentheses.
SELECT *
FROM SEMANTIC_VIEW(
  SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TPCH_REVENUE_SV
  DIMENSIONS region.region_name
  METRICS lineitem.total_revenue
)
ORDER BY total_revenue DESC;

-- Query order count by market segment.
SELECT *
FROM SEMANTIC_VIEW(
  SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TPCH_REVENUE_SV
  DIMENSIONS customer.market_segment
  METRICS orders.total_orders
)
ORDER BY total_orders DESC;

-- Query average order value by nation.
SELECT *
FROM SEMANTIC_VIEW(
  SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TPCH_REVENUE_SV
  DIMENSIONS nation.nation_name
  METRICS orders.avg_order_value
)
ORDER BY avg_order_value DESC;
