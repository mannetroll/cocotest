-- Creates the native Snowflake Semantic View represented by TPCH_REVENUE_SV.csv.
-- Run this file in a Snowsight SQL worksheet with a role that has:
--   * USAGE on the source and target databases/schemas
--   * SELECT on the five SNOWFLAKE_SAMPLE_DATA.TPCH_SF1 source tables
--   * CREATE SEMANTIC VIEW on SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS
--
-- This statement intentionally does not use OR REPLACE. If the object already
-- exists, review it before deciding whether replacement is appropriate.

CREATE SEMANTIC VIEW SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TPCH_REVENUE_SV
  TABLES (
    customer AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER
      PRIMARY KEY (C_CUSTKEY)
      COMMENT = 'Customer accounts',

    lineitem AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
      PRIMARY KEY (L_ORDERKEY, L_LINENUMBER)
      COMMENT = 'Order line items with pricing',

    nation AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION
      PRIMARY KEY (N_NATIONKEY)
      COMMENT = 'Nations/countries',

    orders AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
      PRIMARY KEY (O_ORDERKEY)
      COMMENT = 'Customer orders',

    region AS SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION
      PRIMARY KEY (R_REGIONKEY)
      COMMENT = 'Geographic regions'
  )

  -- Relationship names are deliberately omitted so Snowflake assigns its
  -- SYS_RELATIONSHIP_<uuid> identifiers, as seen in DESCRIBE output.
  RELATIONSHIPS (
    customer (C_NATIONKEY) REFERENCES nation (N_NATIONKEY),
    lineitem (L_ORDERKEY) REFERENCES orders (O_ORDERKEY),
    nation (N_REGIONKEY) REFERENCES region (R_REGIONKEY),
    orders (O_CUSTKEY) REFERENCES customer (C_CUSTKEY)
  )

  FACTS (
    PUBLIC lineitem.discount AS L_DISCOUNT
      COMMENT = 'Discount percentage (0 to 0.10)',

    PUBLIC lineitem.extended_price AS L_EXTENDEDPRICE
      COMMENT = 'Extended price before discount',

    PUBLIC lineitem.quantity AS L_QUANTITY
      COMMENT = 'Quantity ordered',

    PUBLIC orders.order_total AS O_TOTALPRICE
      COMMENT = 'Total price of the order'
  )

  DIMENSIONS (
    PUBLIC customer.customer_name AS C_NAME
      COMMENT = 'Customer name',

    PUBLIC customer.market_segment AS C_MKTSEGMENT
      COMMENT = 'Market segment: AUTOMOBILE, BUILDING, FURNITURE, HOUSEHOLD, MACHINERY',

    PUBLIC lineitem.ship_date AS L_SHIPDATE
      COMMENT = 'Date the line item shipped',

    PUBLIC nation.nation_name AS N_NAME
      COMMENT = 'Nation name',

    PUBLIC orders.order_date AS O_ORDERDATE
      COMMENT = 'Date the order was placed',

    PUBLIC orders.order_status AS O_ORDERSTATUS
      COMMENT = 'Order status: F=fulfilled, O=open, P=pending',

    PUBLIC region.region_name AS R_NAME
      COMMENT = 'Region name: AFRICA, AMERICA, ASIA, EUROPE, MIDDLE EAST'
  )

  METRICS (
    PUBLIC lineitem.total_revenue AS
      SUM(lineitem.L_EXTENDEDPRICE * (1 - lineitem.L_DISCOUNT))
      COMMENT = 'Total revenue after discount',

    PUBLIC orders.avg_order_value AS AVG(orders.O_TOTALPRICE)
      COMMENT = 'Average order total price',

    PUBLIC orders.order_count AS COUNT(DISTINCT orders.O_ORDERKEY)
      COMMENT = 'Count of distinct orders'
  )

  COMMENT = 'TPC-H revenue analysis semantic view for automated testing'

  AI_VERIFIED_QUERIES (
    revenue_by_region AS (
      QUESTION 'What is the total revenue by region?'
      VERIFIED_AT 1722700000
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = data_team)'
      SQL 'SELECT region.R_NAME AS region_name, SUM(lineitem.L_EXTENDEDPRICE * (1 - lineitem.L_DISCOUNT)) AS total_revenue FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM lineitem JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS orders ON lineitem.L_ORDERKEY = orders.O_ORDERKEY JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER customer ON orders.O_CUSTKEY = customer.C_CUSTKEY JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION nation ON customer.C_NATIONKEY = nation.N_NATIONKEY JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION region ON nation.N_REGIONKEY = region.R_REGIONKEY GROUP BY region.R_NAME ORDER BY total_revenue DESC'
    ),

    top_customers_by_spend AS (
      QUESTION 'Who are the top 10 customers by total spend?'
      VERIFIED_AT 1722700000
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = data_team)'
      SQL 'SELECT customer.C_NAME AS customer_name, customer.C_MKTSEGMENT AS market_segment, SUM(lineitem.L_EXTENDEDPRICE * (1 - lineitem.L_DISCOUNT)) AS total_spend FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM lineitem JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS orders ON lineitem.L_ORDERKEY = orders.O_ORDERKEY JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER customer ON orders.O_CUSTKEY = customer.C_CUSTKEY GROUP BY customer.C_NAME, customer.C_MKTSEGMENT ORDER BY total_spend DESC LIMIT 10'
    ),

    avg_order_by_segment AS (
      QUESTION 'What is the average order value by market segment?'
      VERIFIED_AT 1722700000
      ONBOARDING_QUESTION FALSE
      VERIFIED_BY '(STEWARD = data_team)'
      SQL 'SELECT customer.C_MKTSEGMENT AS market_segment, AVG(orders.O_TOTALPRICE) AS avg_order_value FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS orders JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER customer ON orders.O_CUSTKEY = customer.C_CUSTKEY GROUP BY customer.C_MKTSEGMENT ORDER BY avg_order_value DESC'
    )
  );

-- Inspect the native object. Downloading this result as CSV produces the same
-- five-column *kind of artifact* as TPCH_REVENUE_SV.csv. Snowflake will assign
-- fresh SYS_RELATIONSHIP UUIDs, so a new instance will not be byte-identical.
DESCRIBE SEMANTIC VIEW SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TPCH_REVENUE_SV;

-- Retrieve Snowflake's canonical creation statement after deployment.
SELECT GET_DDL(
  'SEMANTIC_VIEW',
  'SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TPCH_REVENUE_SV'
);

-- Smoke test the governed revenue metric by region.
SELECT region_name, total_revenue
FROM SEMANTIC_VIEW(
  SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TPCH_REVENUE_SV
  METRICS lineitem.total_revenue
  DIMENSIONS region.region_name
)
ORDER BY total_revenue DESC;
