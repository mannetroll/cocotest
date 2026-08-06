You are initializing a persistent AI knowledge base for a long-running Snowflake Scala job optimization project.

The objective is not to summarize the current conversation. The objective is to create a structured, durable project memory that allows another AI system or another account to continue the work with minimal loss of context.

The project may be worked on for months by multiple humans and multiple AI systems, including Codex, GitHub Copilot, Claude, GPT, and similar coding agents.

Create the following repository structure:

/docs
    ARCHITECTURE.md
    BUSINESS_RULES.md
    PERFORMANCE.md
/.ai
    AI_CONTEXT.md
    NEXT_SESSION.md
    DECISIONS.md
    SESSION_LOG.md
    MAINTAIN_AI_MEMORY.md

General requirements

* Inspect the repository, relevant source files, SQL, configuration, tests, documentation, Git history, and available performance evidence before writing the files.
* Do not invent missing information.
* Clearly distinguish facts, measurements, assumptions, hypotheses, unresolved questions, and recommendations.
* Preserve all repository names exactly, including:
    * filenames
    * paths
    * Scala packages
    * classes
    * objects
    * methods
    * variables
    * Snowflake databases
    * schemas
    * tables
    * views
    * stages
    * procedures
    * functions
    * query IDs
* Prefer concise technical bullet points over long prose.
* Include exact measurements and evidence whenever available.
* Do not duplicate the same information across several files.
* Cross-reference related files when appropriate.
* Mark unknown information explicitly as Unknown.
* Mark unverified interpretations explicitly as Hypothesis.
* Do not alter application code as part of this initialization unless explicitly instructed.
* Do not remove or rewrite existing project documentation.
* If any target file already exists, merge useful content instead of overwriting it blindly.

⸻

/docs/ARCHITECTURE.md

Purpose: stable long-term technical memory.

Document the current architecture of the Snowflake Scala job.

Use this structure:

# Architecture
## Project Overview
## Repository Structure
## Runtime Environment
## Scala Job Architecture
## Snowflake Architecture
## End-to-End Data Flow
## Processing Stages
## Important Packages
## Important Classes and Objects
## Important Methods
## SQL Generation and Execution
## Data Model
### Databases and Schemas
### Tables and Views
### Keys
### Relationships
### Cardinalities
## External Systems and Dependencies
## Configuration
## Error Handling and Recovery
## Testing Architecture
## Deployment and Scheduling
## Observability
## Coding Conventions
## Known Architectural Constraints
## Unknowns

Include only architecture that is supported by repository evidence.

This document should contain stable information and should change infrequently.

⸻

/docs/BUSINESS_RULES.md

Purpose: stable long-term business and domain memory.

Describe business intent rather than implementation details.

Use this structure:

# Business Rules
## Business Purpose
## Domain Concepts
## Input Data Meaning
## Output Data Meaning
## Customer Rules
## Date and Time Rules
## Selection Rules
## Filtering Rules
## Join Semantics
## Aggregation Rules
## Historical and Snapshot Rules
## Validation Rules
## Exceptional Cases
## Invariants
## Rules That Must Not Change
## Confirmed Assumptions
## Unverified Assumptions
## Open Business Questions

For every rule, include its source where possible:

* filename and method
* SQL fragment
* test
* documentation
* user-provided requirement

Do not infer business meaning solely from implementation unless clearly marked as a hypothesis.

⸻

/docs/PERFORMANCE.md

Purpose: accumulated medium-term performance memory.

Use this structure:

# Performance
## Performance Objective
## Baseline Environment
## Runtime History
## Warehouse History
## Dataset Sizes
## Current Bottlenecks
## Query Profile Findings
## Scala-Side Findings
## Snowflake-Side Findings
## Cartesian Products and Cross Joins
## Exploding Joins
## Window Functions
## Partitioning and Shuffles
## Cache and Materialization Boundaries
## Memory Pressure
## Data Skew
## Warehouse Utilization
## Optimizations Already Performed
## Before-and-After Measurements
## Rejected Optimizations
## Active Performance Hypotheses
## Measurement Gaps
## Recommended Experiments

For every bottleneck include:

* description
* location
* evidence
* input row count
* output row count
* amplification factor
* runtime contribution
* memory or spill observations
* likely root cause
* confidence level
* recommended validation

For every completed optimization include:

* date
* code or SQL changed
* reason
* expected improvement
* actual measurement
* comparison method
* risks
* status

Never fabricate measurements.

⸻

/.ai/AI_CONTEXT.md

Purpose: current task-level working memory.

This is the first file another AI should read.

Use this structure:

# AI Context
## Executive Summary
## Current Objective
## Current Scope
## Current Status
## Current Understanding
## Confirmed Facts
## Current Measurements
## Active Hypotheses
### Likely
### Possible
### Rejected
## Current Bottlenecks
## Important Files
## Important Methods
## Important SQL
## Current Data Flow
## Open Questions
## Current Risks
## Known Dead Ends
## Suggested Investigation Order
## Definition of Done

Requirements:

* Keep the executive summary to approximately one page.
* Focus on the current optimization problem.
* Explain why each important file, method, SQL fragment, and query profile matters.
* Record rejected hypotheses so another AI does not repeat them.
* Do not treat speculation as fact.

⸻

/.ai/NEXT_SESSION.md

Purpose: short-lived handover for the next work session.

Use this structure:

# Next Session
## Resume Here
## Immediate Goal
## Priority Tasks
## Files to Open First
## Methods to Inspect
## SQL to Inspect
## Query Profiles to Inspect
## Commands to Run
## Tests to Run
## Measurements to Capture
## Things Already Tried
## Things Not to Repeat
## Questions Requiring User Input
## Expected Completion Criteria

For each priority task include:

* objective
* reason
* expected benefit
* expected evidence
* dependencies
* estimated difficulty
* completion criterion

Keep this file operational and concise.

⸻

/.ai/DECISIONS.md

Purpose: durable chronological project decision memory.

Use this structure:

# Decisions
## Decision Template
### YYYY-MM-DD — Decision title
- Status:
- Context:
- Decision:
- Reason:
- Evidence:
- Alternatives considered:
- Trade-offs:
- Consequences:
- Follow-up:
- Supersedes:
- Superseded by:

Create entries for material decisions already evident from the repository or current session.

Valid statuses:

* Proposed
* Accepted
* Rejected
* Superseded
* Reversed

Do not create a decision entry for trivial implementation details.

Preserve rejected decisions because they prevent repeated work.

⸻

/.ai/SESSION_LOG.md

Purpose: chronological episodic memory.

Use this structure:

# Session Log
## YYYY-MM-DD — Initial knowledge-base creation
### Objective
### Repository State
### Files Inspected
### SQL Inspected
### Query Profiles Inspected
### Findings
### Measurements
### Hypotheses
### Decisions
### Changes Made
### Remaining Questions
### Recommended Next Focus

The initial entry must document what was actually inspected and created.

Do not claim to have inspected files or measurements that were not available.

⸻

/.ai/MAINTAIN_AI_MEMORY.md

Purpose: permanent instructions for future AI sessions.

Write a self-contained maintenance procedure with the following requirements:

1. Read all existing files under /docs and /.ai before updating project memory.
2. Inspect the work completed during the current session.
3. Update only documents affected by new evidence or decisions.
4. Preserve useful history.
5. Never overwrite historical measurements.
6. Append to DECISIONS.md only for material decisions.
7. Append one entry to SESSION_LOG.md per substantive work session.
8. Replace the operational content of NEXT_SESSION.md.
9. Refresh AI_CONTEXT.md so it reflects the current state.
10. Update PERFORMANCE.md when measurements, bottlenecks, or optimization results change.
11. Update ARCHITECTURE.md only when stable architecture changes or becomes newly understood.
12. Update BUSINESS_RULES.md only when business intent is confirmed, corrected, or clarified.
13. Remove obsolete working-memory statements only when they are explicitly resolved, rejected, or superseded.
14. Preserve exact identifiers.
15. Do not invent facts.
16. Run a consistency check across all memory files.
17. Report which files changed and why.

Include the complete end-of-session procedure inside this file so it can be reused without referring to this initialization prompt.

⸻

Final validation

Before finishing:

* Verify that every required file exists.
* Verify that Markdown headings are consistent.
* Verify that facts and hypotheses are separated.
* Verify that the same information is not unnecessarily duplicated.
* Verify that file paths and identifiers match the repository.
* Verify that no unsupported measurements were introduced.
* Verify that AI_CONTEXT.md and NEXT_SESSION.md describe the same current objective.
* Verify that historical information is retained in PERFORMANCE.md, DECISIONS.md, and SESSION_LOG.md.
* Verify that another AI could identify the next concrete task without reading the original chat.

At the end, report only:

# Initialization Result
## Files Created or Updated
## Repository Areas Inspected
## Key Findings Recorded
## Missing Information
## Recommended First Taskk