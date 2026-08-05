# Generate `TPCH_REVENUE_SV.sql` From Scratch

## Short Answer

The sample database can provide the physical structure and observable data characteristics. It cannot provide authoritative business meaning. A reliable Semantic View therefore needs two input packages:

1. Snowflake metadata and read-only data profiles.
2. Human-approved semantic decisions.

An existing Semantic View CSV is neither necessary nor desirable as an input when testing true from-scratch generation.

## Step 1: Collect Technical Metadata

Run `TPCH_METADATA_DISCOVERY.sql` in a Snowsight worksheet. It collects:

- Tables, columns, types, nullability, and comments.
- Declared primary, unique, and foreign keys, if available.
- Candidate-key uniqueness and null checks.
- Foreign-key orphan checks.
- Observed categorical values.
- Numeric and date ranges.
- Competing revenue calculations.
- Candidate queries for human review.

Save the result sets in files that Codex is allowed to read. Do not include an existing Semantic View CSV or `DESCRIBE SEMANTIC VIEW` result.

## Step 2: Supply the Business Metadata Snowflake Cannot Infer

Complete this checklist before asking Codex to generate production SQL.

### Scope and Audience

- Semantic View purpose:
- Intended users:
- Business questions it must answer:
- Questions it must not answer:
- Target database, schema, and view name:

### Table Grain and Relationships

- Grain of each logical table:
- Approved primary or unique keys:
- Approved many-to-one relationships:
- Whether unmatched child rows are permitted:
- Any role-playing or alternative relationship paths:

### Measures, Facts, and Metrics

- Authoritative definition of revenue:
- Whether revenue includes tax:
- Whether discounts are already percentages or decimal fractions:
- Treatment of returns, cancellations, and open orders:
- Authoritative definition of order value:
- Whether order count is distinct by order key:
- Required aggregation grain and non-additive dimensions:
- Null and divide-by-zero behavior:
- Currency and unit conventions:

### Dimensions

- Dimensions users need:
- Business names and synonyms:
- Status-code definitions:
- Date to use for each business question:
- Fiscal calendar rules, if any:
- Time-zone rules, if any:
- Sensitive dimensions that must be private or omitted:

### Verified Queries

For each candidate verified query:

- Natural-language question:
- Reviewed SQL:
- Expected result shape or invariant:
- Reviewer/steward identity:
- Verification timestamp:
- Whether it should be an onboarding question:

Do not label generated SQL as verified until a responsible person has reviewed and executed it.

### Governance and Deployment

- Public/private access for facts and metrics:
- Object owner and execution role:
- Required grants:
- Whether creation may replace an existing object:
- Approved test assertions:
- Required descriptions, tags, and contacts:

## What Can Be Inferred Safely

From the TPC-H table and column metadata plus profiles, Codex can propose:

- Logical table mappings.
- Direct-column dimensions and facts.
- Candidate table grains.
- Candidate relationships and their join columns.
- Candidate categorical dimensions.
- Data types.
- Candidate metrics based on names and observed data.

These remain proposals until reviewed. A unique column is evidence for a key, but not proof that it is the intended business key. A numerically plausible expression is not proof that it is the business definition of revenue.

## What Cannot Be Recovered From the Sample Database Alone

- Why the view exists and who should use it.
- Which subset of tables and columns belongs in scope.
- The authoritative revenue formula.
- Whether tax, returns, discounts, or order status affect revenue.
- Preferred business terminology and synonyms.
- Verified-query questions, ownership, and verification timestamps.
- Access-control choices.
- Exact comments and custom instructions.
- Exact relationship UUIDs or serialization order from an earlier instance.

## Prompt for Codex

```text
Create TPCH_REVENUE_SV.sql from scratch.

Inputs:
- The result files produced by TPCH_METADATA_DISCOVERY.sql
- This completed business-decision checklist
- Current official Snowflake CREATE SEMANTIC VIEW syntax

Constraints:
1. Do not search for, read, or use any existing semantic-view CSV, DESCRIBE
   SEMANTIC VIEW output, previously generated TPCH_REVENUE_SV.sql, or target
   answer.
2. Treat physical metadata and observed data profiles as evidence, not as
   authoritative business definitions.
3. List every proposed primary key, relationship, fact, dimension, metric, and
   verified query with its source or rationale.
4. Stop and report any missing business decision that could change metric
   meaning, aggregation grain, joins, filtering, privacy, or verification.
5. Generate CREATE SEMANTIC VIEW SQL only after those decisions are approved.
6. Do not connect to Snowflake or deploy anything.
7. Add read-only validation SQL for key uniqueness, relationship coverage,
   metric sanity, and representative Semantic View queries.
8. Do not use CREATE OR REPLACE unless explicitly authorized.
9. Clearly distinguish syntax validation, which requires Snowflake, from local
   static review.
```

## Deployment Without Cortex CLI

1. Review the generated SQL and its assumptions.
2. Open a Snowsight SQL worksheet.
3. Use a role with `CREATE SEMANTIC VIEW` on the target schema, `USAGE` on the relevant database and schemas, and `SELECT` on the source tables.
4. Execute the `CREATE SEMANTIC VIEW` statement.
5. Run the generated validation queries.
6. Run `DESCRIBE SEMANTIC VIEW <fully-qualified-name>` and review the resulting metadata.
7. Test representative natural-language questions in Cortex Analyst, if available.

Codex can generate and review the SQL without a Snowflake connection. Snowflake is still required to compile, validate, create, and query the native schema object.
