-- Read-only metadata and profiling worksheet for designing a semantic view from
-- SNOWFLAKE_SAMPLE_DATA.TPCH_SF1 without using an existing semantic-view CSV.
--
-- Run each result-producing statement in Snowsight. Save the results as CSV,
-- JSON, or Markdown and give those results to Codex together with the completed
-- business-decision checklist in TPCH_SEMANTIC_VIEW_FROM_SCRATCH.md.

-- ---------------------------------------------------------------------------
-- 1. Table inventory and table comments
-- ---------------------------------------------------------------------------

SELECT
  table_catalog,
  table_schema,
  table_name,
  table_type,
  row_count,
  bytes,
  comment
FROM SNOWFLAKE_SAMPLE_DATA.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'TPCH_SF1'
ORDER BY table_name;

-- ---------------------------------------------------------------------------
-- 2. Columns, types, nullability, defaults, and comments
-- ---------------------------------------------------------------------------

SELECT
  table_catalog,
  table_schema,
  table_name,
  ordinal_position,
  column_name,
  data_type,
  numeric_precision,
  numeric_scale,
  character_maximum_length,
  is_nullable,
  column_default,
  comment
FROM SNOWFLAKE_SAMPLE_DATA.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'TPCH_SF1'
ORDER BY table_name, ordinal_position;

-- ---------------------------------------------------------------------------
-- 3. Declared constraints, if the shared database exposes them
--    An empty result does not prove that the data has no logical keys.
-- ---------------------------------------------------------------------------

SELECT
  tc.table_name,
  tc.constraint_name,
  tc.constraint_type,
  kcu.column_name,
  kcu.ordinal_position,
  tc.enforced,
  tc.rely
FROM SNOWFLAKE_SAMPLE_DATA.INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS kcu
  ON tc.constraint_catalog = kcu.constraint_catalog
 AND tc.constraint_schema = kcu.constraint_schema
 AND tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'TPCH_SF1'
ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position;

-- Optional alternative primary-key metadata command. Run it separately because
-- a SHOW command produces its own result set. Unique and foreign keys are
-- already covered by TABLE_CONSTRAINTS above.
SHOW PRIMARY KEYS IN SCHEMA SNOWFLAKE_SAMPLE_DATA.TPCH_SF1;

-- ---------------------------------------------------------------------------
-- 4. Canonical table DDL for the candidate revenue scope, if GET_DDL is
--    permitted on the shared database. Add other tables after reviewing the
--    complete inventory above and confirming they belong in business scope.
-- ---------------------------------------------------------------------------

SELECT 'REGION' AS object_name,
       GET_DDL('TABLE', 'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION') AS ddl
UNION ALL
SELECT 'NATION',
       GET_DDL('TABLE', 'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION')
UNION ALL
SELECT 'CUSTOMER',
       GET_DDL('TABLE', 'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER')
UNION ALL
SELECT 'ORDERS',
       GET_DDL('TABLE', 'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS')
UNION ALL
SELECT 'LINEITEM',
       GET_DDL('TABLE', 'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM')
ORDER BY object_name;

-- ---------------------------------------------------------------------------
-- 5. Candidate grain and primary-key checks
--    A semantic primary key must be unique and non-null at the table's grain.
-- ---------------------------------------------------------------------------

SELECT
  'REGION' AS table_name,
  COUNT(*) AS row_count,
  COUNT(DISTINCT R_REGIONKEY) AS distinct_key_count,
  COUNT_IF(R_REGIONKEY IS NULL) AS null_key_count
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION
UNION ALL
SELECT
  'NATION',
  COUNT(*),
  COUNT(DISTINCT N_NATIONKEY),
  COUNT_IF(N_NATIONKEY IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION
UNION ALL
SELECT
  'CUSTOMER',
  COUNT(*),
  COUNT(DISTINCT C_CUSTKEY),
  COUNT_IF(C_CUSTKEY IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER
UNION ALL
SELECT
  'ORDERS',
  COUNT(*),
  COUNT(DISTINCT O_ORDERKEY),
  COUNT_IF(O_ORDERKEY IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
UNION ALL
SELECT
  'LINEITEM',
  COUNT(*),
  COUNT(DISTINCT L_ORDERKEY, L_LINENUMBER),
  COUNT_IF(L_ORDERKEY IS NULL OR L_LINENUMBER IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
ORDER BY table_name;

-- ---------------------------------------------------------------------------
-- 6. Candidate foreign-key coverage
--    Orphan count should be zero for each proposed many-to-one relationship.
-- ---------------------------------------------------------------------------

SELECT
  'NATION.N_REGIONKEY -> REGION.R_REGIONKEY' AS relationship,
  COUNT(*) AS child_rows,
  COUNT_IF(r.R_REGIONKEY IS NULL) AS orphan_rows
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION AS n
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION AS r
  ON n.N_REGIONKEY = r.R_REGIONKEY
UNION ALL
SELECT
  'CUSTOMER.C_NATIONKEY -> NATION.N_NATIONKEY',
  COUNT(*),
  COUNT_IF(n.N_NATIONKEY IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER AS c
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION AS n
  ON c.C_NATIONKEY = n.N_NATIONKEY
UNION ALL
SELECT
  'ORDERS.O_CUSTKEY -> CUSTOMER.C_CUSTKEY',
  COUNT(*),
  COUNT_IF(c.C_CUSTKEY IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS AS o
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER AS c
  ON o.O_CUSTKEY = c.C_CUSTKEY
UNION ALL
SELECT
  'LINEITEM.L_ORDERKEY -> ORDERS.O_ORDERKEY',
  COUNT(*),
  COUNT_IF(o.O_ORDERKEY IS NULL)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM AS l
LEFT JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS AS o
  ON l.L_ORDERKEY = o.O_ORDERKEY
ORDER BY relationship;

-- ---------------------------------------------------------------------------
-- 7. Candidate categorical dimensions and their observed values
-- ---------------------------------------------------------------------------

SELECT 'REGION.R_NAME' AS candidate_dimension,
       R_NAME::VARCHAR AS value,
       COUNT(*) AS row_count
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION
GROUP BY R_NAME
UNION ALL
SELECT 'CUSTOMER.C_MKTSEGMENT', C_MKTSEGMENT, COUNT(*)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER
GROUP BY C_MKTSEGMENT
UNION ALL
SELECT 'ORDERS.O_ORDERSTATUS', O_ORDERSTATUS, COUNT(*)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
GROUP BY O_ORDERSTATUS
UNION ALL
SELECT 'LINEITEM.L_RETURNFLAG', L_RETURNFLAG, COUNT(*)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
GROUP BY L_RETURNFLAG
UNION ALL
SELECT 'LINEITEM.L_LINESTATUS', L_LINESTATUS, COUNT(*)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
GROUP BY L_LINESTATUS
UNION ALL
SELECT 'LINEITEM.L_SHIPMODE', L_SHIPMODE, COUNT(*)
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
GROUP BY L_SHIPMODE
ORDER BY candidate_dimension, value;

-- ---------------------------------------------------------------------------
-- 8. Measure and date profiles
-- ---------------------------------------------------------------------------

SELECT
  MIN(L_QUANTITY) AS min_quantity,
  MAX(L_QUANTITY) AS max_quantity,
  MIN(L_EXTENDEDPRICE) AS min_extended_price,
  MAX(L_EXTENDEDPRICE) AS max_extended_price,
  MIN(L_DISCOUNT) AS min_discount,
  MAX(L_DISCOUNT) AS max_discount,
  MIN(L_TAX) AS min_tax,
  MAX(L_TAX) AS max_tax,
  MIN(L_SHIPDATE) AS min_ship_date,
  MAX(L_SHIPDATE) AS max_ship_date,
  MIN(L_COMMITDATE) AS min_commit_date,
  MAX(L_COMMITDATE) AS max_commit_date,
  MIN(L_RECEIPTDATE) AS min_receipt_date,
  MAX(L_RECEIPTDATE) AS max_receipt_date
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;

SELECT
  MIN(O_TOTALPRICE) AS min_order_total,
  MAX(O_TOTALPRICE) AS max_order_total,
  AVG(O_TOTALPRICE) AS avg_order_total,
  MIN(O_ORDERDATE) AS min_order_date,
  MAX(O_ORDERDATE) AS max_order_date
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS;

-- ---------------------------------------------------------------------------
-- 9. Competing revenue definitions
--    Data can calculate each candidate, but a business owner must choose which
--    definition is authoritative.
-- ---------------------------------------------------------------------------

SELECT
  SUM(L_EXTENDEDPRICE) AS gross_extended_price,
  SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT)) AS revenue_after_discount,
  SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT) * (1 + L_TAX))
    AS revenue_after_discount_and_tax
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;

-- Compare O_TOTALPRICE with line-item calculations at order grain. This helps
-- detect whether the order total includes tax or differs for another reason.
WITH lineitem_by_order AS (
  SELECT
    L_ORDERKEY,
    SUM(L_EXTENDEDPRICE) AS gross_extended_price,
    SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT)) AS revenue_after_discount,
    SUM(L_EXTENDEDPRICE * (1 - L_DISCOUNT) * (1 + L_TAX))
      AS revenue_after_discount_and_tax
  FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
  GROUP BY L_ORDERKEY
)
SELECT
  COUNT(*) AS compared_orders,
  AVG(ABS(o.O_TOTALPRICE - l.gross_extended_price))
    AS avg_delta_from_gross,
  AVG(ABS(o.O_TOTALPRICE - l.revenue_after_discount))
    AS avg_delta_from_discounted,
  AVG(ABS(o.O_TOTALPRICE - l.revenue_after_discount_and_tax))
    AS avg_delta_from_discounted_with_tax
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS AS o
JOIN lineitem_by_order AS l
  ON o.O_ORDERKEY = l.L_ORDERKEY;

-- ---------------------------------------------------------------------------
-- 10. Candidate verified queries
--     These are discovery candidates, not verified queries until a responsible
--     person reviews their meaning and results.
-- ---------------------------------------------------------------------------

SELECT
  r.R_NAME AS region_name,
  SUM(l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT)) AS revenue_after_discount
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
ORDER BY revenue_after_discount DESC;

SELECT
  c.C_MKTSEGMENT AS market_segment,
  COUNT(DISTINCT o.O_ORDERKEY) AS order_count,
  AVG(o.O_TOTALPRICE) AS avg_order_value
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS AS o
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER AS c
  ON o.O_CUSTKEY = c.C_CUSTKEY
GROUP BY c.C_MKTSEGMENT
ORDER BY avg_order_value DESC;

-- ---------------------------------------------------------------------------
-- Optional: query-history context
-- ---------------------------------------------------------------------------
-- Snowflake's generator can use query history to learn common joins and usage.
-- Do not export work query text to an external tool unless company policy and
-- data governance explicitly permit it. The sample database alone is enough
-- for this exercise, so no query-history statement is included here.
