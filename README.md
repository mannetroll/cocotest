# TPCH Revenue Semantic View — Learning Project

This project demonstrates how to create a Snowflake Semantic View from scratch
using a repeatable, auditable process.

## The Problem

A Semantic View defines business meaning on top of physical tables. Snowflake
can tell you what columns exist and what data looks like, but it cannot tell you
what "revenue" means to your business, which tables belong in scope, or which
questions users should be able to ask. Those decisions must come from a human.

## The Three Inputs

Generating a correct Semantic View requires exactly three inputs:

```
+-------------------------------+
|  TPCH_METADATA_DISCOVERY.sql  |  What exists (physical evidence)
+-------------------------------+
                |
                v
+-------------------------------+
|  TPCH_REVENUE_SV_DECISIONS.md |  What it should mean (business intent)
+-------------------------------+
                |
                v
+-------------------------------+
|  create-semantic-view.md      |  How to express it (DDL syntax reference)
+-------------------------------+
                |
                v
+-------------------------------+
|  TPCH_REVENUE_SV.sql          |  The output (deployable SQL)
+-------------------------------+
```

### 1. TPCH_METADATA_DISCOVERY.sql — Physical Evidence

Source: Snowflake DDL / INFORMATION_SCHEMA queries.

A read-only worksheet that collects table inventory, column types, candidate
keys, foreign-key coverage, categorical value distributions, numeric/date
ranges, and competing metric calculations. It produces raw facts about the data
but makes no business claims.

Run this in Snowsight and save the results. These results are evidence for
proposing keys, relationships, and metrics — but they are not authoritative
until a human approves them.

### 2. TPCH_REVENUE_SV_DECISIONS.md — Business Decisions

Source: A human (the data owner, analyst, or steward).

Documents every decision that cannot be inferred from physical metadata alone:

- Scope and audience (why does this view exist?)
- Primary keys and relationships (what is the grain?)
- Revenue definition (which formula is authoritative?)
- Dimension selection (what can users group/filter by?)
- Verified queries (what questions should Cortex Analyst answer correctly?)
- Governance (who owns it, what access model?)

Without this file, generation is guesswork. With it, generation is deterministic.

### 3. create-semantic-view.md — Syntax Reference

Source: Snowflake documentation (fetched from docs.snowflake.com).

The official CREATE SEMANTIC VIEW DDL reference. Defines valid clause ordering,
relationship syntax, fact/dimension/metric expressions, verified query format,
and optional properties like AI_SQL_GENERATION and synonyms.

This is not project-specific — it's the language specification that ensures the
output is syntactically valid.

## The Output

### TPCH_REVENUE_SV.sql

The generated file contains:

- Design rationale tracing each element to its source
- The CREATE SEMANTIC VIEW statement
- Validation queries (key uniqueness, FK coverage, metric sanity)
- A static review checklist

## Process

```
1. Run TPCH_METADATA_DISCOVERY.sql in Snowsight
2. Review results and fill in TPCH_REVENUE_SV_DECISIONS.md
3. Generate TPCH_REVENUE_SV.sql using the three inputs above
4. Deploy to a writable schema (not SNOWFLAKE_SAMPLE_DATA)
5. Run validation queries
6. Test with Cortex Analyst
```

## Key Principle

Physical metadata tells you what the data *is*.
Business decisions tell you what the data *means*.
Syntax tells you how to *express* it.

All three are necessary. None is sufficient alone.

## Automated Testing with the Semantic View

Once deployed, the Semantic View serves as the foundation for automated SQL
generation testing. Verified queries (VQRs) embedded in the view double as
regression test assertions — if the underlying data changes shape or the
semantic model drifts, the tests catch it.

The test framework validates:

- **Semantic view existence** — is the object deployed and accessible?
- **VQR execution** — does each verified query still run and return the expected
  row count?
- **Source data presence** — do the underlying tables still have data?
- **Metric sanity** — are computed metrics (e.g. revenue) positive and
  reasonable?

These tests can be scheduled via a Snowflake Task to run daily, with results
logged to a history table for trend analysis.

For the full testing framework, procedures, task scheduling, and examples see:
[semantics/semantic-layer-testing.md](semantics/semantic-layer-testing.md)

## Other Files

| File | Purpose |
|------|---------|
| `TPCH_REVENUE_SV_OLD.sql` | Previous version generated from another session (for comparison) |
| `TPCH_SEMANTIC_VIEW_FROM_SCRATCH.md` | Original task specification and blank checklist template |
| `semantics/TPCH_REVENUE_SV.csv` | Existing semantic view export (not used as input per constraints) |
