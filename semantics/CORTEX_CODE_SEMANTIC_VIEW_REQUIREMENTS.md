# Information Required to Generate `Semantic_2026-08-04-0011.csv`

## Objective

Generate a Snowflake Semantic View CSV instance equivalent to, or exactly reproducible as:

`Semantic_2026-08-04-0011.csv`

The following two files are available as initial input:

- `semantic-layer-testing.md`
- `SNOWFLAKE_SAMPLE_DATA_DDL.md`

Those files describe much of the intended model, but they do not contain all the information needed to reproduce the CSV exactly. Supply or explicitly approve every item below.

## 1. Output Contract

- Confirm that the requested artifact is a Snowflake Semantic View CSV metadata file.
- Specify the exact CSV schema and column order:

  ```text
  object_kind,object_name,parent_entity,property,property_value
  ```

- Specify the supported `object_kind` and `property` values.
- Specify CSV quoting and escaping rules, especially for SQL, comments containing commas, and JSON-like arrays.
- Specify object ordering and property ordering.
- State whether identifiers must be upper case, lower case, or preserved as supplied.
- State whether the output must be byte-for-byte identical or only semantically equivalent.
- State whether empty values should be emitted as empty fields, omitted, or represented as `NULL`.

## 2. Semantic View Identity

- Database: `SNOWFLAKE_LEARNING_DB`
- Schema: `SEMANTIC_TESTS`
- Semantic View name: `TPCH_REVENUE_SV`
- Semantic View comment: `TPC-H revenue analysis semantic view for automated testing`
- Confirm whether the database, schema, and view name belong inside the CSV or are supplied separately during import.
- Specify owner, role, and grants if they are part of creation or deployment.

## 3. Base Tables

Confirm these five logical-to-physical table mappings:

| Logical table | Physical table | Semantic comment |
|---|---|---|
| `REGION` | `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION` | `Geographic regions` |
| `NATION` | `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION` | `Nations/countries` |
| `CUSTOMER` | `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER` | `Customer accounts` |
| `ORDERS` | `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS` | `Customer orders` |
| `LINEITEM` | `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM` | `Order line items with pricing` |

Also supply:

- Whether the logical table names must exactly match the physical names.
- Whether fully qualified physical names are mandatory.
- Whether tables or columns not represented in the semantic model should be ignored.

## 4. Primary Keys

The supplied DDL declares columns `NOT NULL` but does not declare primary-key constraints. Confirm these semantic primary keys explicitly:

| Table | Primary key |
|---|---|
| `REGION` | `R_REGIONKEY` |
| `NATION` | `N_NATIONKEY` |
| `CUSTOMER` | `C_CUSTKEY` |
| `ORDERS` | `O_ORDERKEY` |
| `LINEITEM` | `L_ORDERKEY`, `L_LINENUMBER` |

Specify the required array serialization, for example:

```text
["C_CUSTKEY"]
["L_ORDERKEY","L_LINENUMBER"]
```

## 5. Relationships

Confirm the relationship direction and exact key mapping:

| From table | Foreign key | Referenced table | Referenced key |
|---|---|---|---|
| `NATION` | `N_REGIONKEY` | `REGION` | `R_REGIONKEY` |
| `CUSTOMER` | `C_NATIONKEY` | `NATION` | `N_NATIONKEY` |
| `ORDERS` | `O_CUSTKEY` | `CUSTOMER` | `C_CUSTKEY` |
| `LINEITEM` | `L_ORDERKEY` | `ORDERS` | `O_ORDERKEY` |

Also supply:

- Relationship cardinality, such as many-to-one.
- Whether joins are inner, left, or determined automatically.
- Whether relationships are mandatory or optional.
- The relationship naming policy.
- For an exact reproduction, the four relationship identifiers/UUIDs:

  ```text
  SYS_RELATIONSHIP_caad8995-75f1-476a-86ba-155aad73a517
  SYS_RELATIONSHIP_06cc3885-57f9-48ff-bb93-e10ed0d9096a
  SYS_RELATIONSHIP_47a1d91a-315f-4e06-8d04-722967af8be5
  SYS_RELATIONSHIP_113e06f0-9611-4298-9ceb-962ff21a149f
  ```

- If exact identifiers are not required, specify whether new UUIDs should be generated and by which deterministic or random method.

## 6. Dimensions

Confirm each dimension, including its parent table, expression, output type, comment, and access modifier:

| Dimension | Parent | Expression | Type | Comment |
|---|---|---|---|---|
| `REGION_NAME` | `REGION` | `R_NAME` | `VARCHAR(25)` | `Region name: AFRICA, AMERICA, ASIA, EUROPE, MIDDLE EAST` |
| `NATION_NAME` | `NATION` | `N_NAME` | `VARCHAR(25)` | `Nation name` |
| `CUSTOMER_NAME` | `CUSTOMER` | `C_NAME` | `VARCHAR(25)` | `Customer name` |
| `MARKET_SEGMENT` | `CUSTOMER` | `C_MKTSEGMENT` | `VARCHAR(10)` | `Market segment: AUTOMOBILE, BUILDING, FURNITURE, HOUSEHOLD, MACHINERY` |
| `ORDER_DATE` | `ORDERS` | `O_ORDERDATE` | `DATE` | `Date the order was placed` |
| `ORDER_STATUS` | `ORDERS` | `O_ORDERSTATUS` | `VARCHAR(1)` | `Order status: F=fulfilled, O=open, P=pending` |
| `SHIP_DATE` | `LINEITEM` | `L_SHIPDATE` | `DATE` | `Date the line item shipped` |

Specify whether all dimensions use `ACCESS_MODIFIER = PUBLIC`.

Verify the enumerated values and their descriptions against authoritative source data. They are not defined by the supplied DDL.

## 7. Facts

Confirm each fact, including its parent table, expression, output type, comment, and access modifier:

| Fact | Parent | Expression | Type | Comment |
|---|---|---|---|---|
| `ORDER_TOTAL` | `ORDERS` | `O_TOTALPRICE` | `NUMBER(12,2)` | `Total price of the order` |
| `EXTENDED_PRICE` | `LINEITEM` | `L_EXTENDEDPRICE` | `NUMBER(12,2)` | `Extended price before discount` |
| `DISCOUNT` | `LINEITEM` | `L_DISCOUNT` | `NUMBER(12,2)` | `Discount percentage (0 to 0.10)` |
| `QUANTITY` | `LINEITEM` | `L_QUANTITY` | `NUMBER(12,2)` | `Quantity ordered` |

Specify whether all facts use `ACCESS_MODIFIER = PUBLIC`.

Verify the discount range against authoritative source data because it is not defined by the supplied DDL.

## 8. Metrics

Confirm the exact metric semantics. The metric names alone do not uniquely determine these expressions.

| Metric | Parent | Exact expression | Output type | Comment |
|---|---|---|---|---|
| `TOTAL_REVENUE` | `LINEITEM` | `SUM(lineitem.L_EXTENDEDPRICE * (1 - lineitem.L_DISCOUNT))` | `NUMBER(37,4)` | `Total revenue after discount` |
| `ORDER_COUNT` | `ORDERS` | `COUNT(DISTINCT orders.O_ORDERKEY)` | `NUMBER(18,0)` | `Count of distinct orders` |
| `AVG_ORDER_VALUE` | `ORDERS` | `AVG(orders.O_TOTALPRICE)` | `NUMBER(30,8)` | `Average order total price` |

Also supply:

- Required table-alias qualification inside metric expressions.
- Whether `TOTAL_REVENUE` excludes tax, returns, and cancelled orders.
- Null-handling behavior.
- Whether metric output types are declared or inferred by Snowflake.
- Whether all metrics use `ACCESS_MODIFIER = PUBLIC`.

## 9. Verified Queries

For each verified query, supply the exact question, SQL, onboarding flag, verification timestamp, and verifier identity.

### `REVENUE_BY_REGION`

- Question: `What is the total revenue by region?`
- Expected assertion: exactly five rows.
- Onboarding question: `TRUE`
- Verified at: `1722700000`
- Verified by: `(STEWARD = data_team)`
- Confirm exact SQL, including:
  - Fully qualified table names
  - Table aliases
  - Join order and join type
  - Revenue formula
  - Output aliases
  - Grouping
  - Descending result order

### `TOP_CUSTOMERS_BY_SPEND`

- Question: `Who are the top 10 customers by total spend?`
- Expected assertion: exactly ten rows.
- Onboarding question: `TRUE`
- Verified at: `1722700000`
- Verified by: `(STEWARD = data_team)`
- Confirm exact SQL, including:
  - Whether customers are grouped only by name or by a stable customer identifier as well
  - Inclusion of market segment
  - Revenue/spend formula
  - Descending result order
  - `LIMIT 10`

### `AVG_ORDER_BY_SEGMENT`

- Question: `What is the average order value by market segment?`
- Expected assertion: exactly five rows.
- Onboarding question: `FALSE`
- Verified at: `1722700000`
- Verified by: `(STEWARD = data_team)`
- Confirm exact SQL, including:
  - Join between `ORDERS` and `CUSTOMER`
  - Average of `O_TOTALPRICE`
  - Grouping by market segment
  - Descending result order

## 10. Verification Metadata

Resolve these points before generation:

- Is `1722700000` intentionally the verification timestamp for all three queries?
- Which timestamp unit is required: Unix seconds, milliseconds, or another representation?
- Should a newly generated artifact use the current generation time instead?
- Is `data_team` the required steward identity?
- Is `(STEWARD = data_team)` the exact required serialization?
- Who is authorized to mark SQL as verified?
- What evidence or execution results are required before assigning verified status?

## 11. Comments and Business Definitions

Confirm that the exact comments shown above are authoritative. If exact reproduction is required, comments must not be paraphrased.

Provide authoritative definitions for:

- Revenue
- Customer spend
- Average order value
- Order count
- Market segment values
- Region values
- Order-status codes
- Discount representation and valid range

## 12. Validation Requirements

Specify which checks Cortex Code must perform:

- Validate every referenced table and column against the supplied DDL.
- Reject expressions that reference unavailable columns.
- Check that all five tables appear exactly once.
- Check that the relationship graph connects all five tables without ambiguity.
- Check that the CSV contains exactly four relationships, four facts, seven dimensions, three metrics, and three verified queries.
- Parse and compile each verified-query SQL statement.
- Confirm the verified-query result counts: 5, 10, and 5.
- Confirm that source `LINEITEM` data exists.
- Confirm that revenue is positive for every returned region.
- Validate primary-key uniqueness and foreign-key coverage if Snowflake access is available.
- Validate inferred metric result types against Snowflake.
- Round-trip the CSV through the intended Snowflake import/export mechanism if one exists.
- Compare against the target file byte-for-byte when exact reproduction is required.

## 13. Environment and Execution Information

If Cortex Code is expected to create or deploy the Semantic View rather than only generate the CSV, also provide:

- Snowflake account and connection method.
- Warehouse name.
- Execution role.
- Required privileges on the source and target databases/schemas.
- Whether `SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS` already exists.
- Whether an existing `TPCH_REVENUE_SV` may be replaced.
- Target environment: development, staging, or production.
- Whether external documentation or Snowflake metadata queries are permitted.
- Whether source-data profiling is permitted.

## 14. Determinism Policy

For an exactly reproducible artifact, define:

- Fixed relationship identifiers.
- Fixed verification timestamps.
- Fixed verifier identity.
- Fixed row and property ordering.
- Fixed identifier casing.
- Fixed SQL formatting.
- Fixed comment text.
- Fixed CSV quoting and line-ending rules.
- Fixed generated filename.
- Character encoding, preferably UTF-8.

Without these rules, two valid generators can produce semantically equivalent but textually different CSV files.

## Prompt to Give Cortex Code

```text
Using semantic-layer-testing.md and SNOWFLAKE_SAMPLE_DATA_DDL.md as source material,
generate a Snowflake Semantic View CSV for
SNOWFLAKE_LEARNING_DB.SEMANTIC_TESTS.TPCH_REVENUE_SV.

Before generating the artifact:

1. Read CORTEX_CODE_SEMANTIC_VIEW_REQUIREMENTS.md completely.
2. Classify every required value as:
   - explicitly supplied,
   - safely derived,
   - assumed/defaulted, or
   - missing and blocking exact reproduction.
3. Do not silently invent primary keys, relationship identifiers, timestamps,
   verifier identities, onboarding flags, comments, enum values, formulas, result
   types, access modifiers, or CSV serialization rules.
4. Ask for any missing choice that affects the semantic meaning or exact output.
5. Validate all table and column references against the supplied DDL.
6. Generate the CSV only after documenting all approved assumptions.
7. Report whether the result is byte-for-byte reproducible or only semantically
   equivalent to Semantic_2026-08-04-0011.csv.
```

