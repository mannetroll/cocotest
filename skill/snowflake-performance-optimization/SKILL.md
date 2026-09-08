---
name: snowflake-performance-optimization
description: Optimize Snowflake SQL and data pipelines, including Scala/Snowpark-generated queries, through profiling, isolated experiments, and deterministic correctness checks. Use for slow or costly jobs, materialized DAG splits, final-table design, partitioning or clustering, and CTAS write bottlenecks.
---

# Snowflake Performance Optimization

Reduce end-to-end job runtime and measurable Snowflake cost while preserving the existing output contract. Optimize the SQL and physical execution produced by the application. For Scala/Snowpark jobs, inspect generated SQL and actions before changing Scala abstractions.

When repository evidence identifies a Snowflake Scala job, read [the Scala-job playbook](references/scala-jobs.md) before choosing candidates. Distinguish native Snowpark Scala, Spark with the Snowflake connector, Scala/JDBC, and in-database Scala handlers; preserve the repository's build, execution, and validation workflow.

## Scope and operating mode

- For an optimization campaign, continue through successive experiments until a stop condition below applies. A passing gate or a single improvement does not finish a campaign.
- For a review, diagnosis, or one requested change, complete that scope. Do not turn it into an unrequested campaign or launch paid workloads merely to answer a design question.
- Use the user's runtime, credit, and execution budget and existing authorization. Proceed between ordinary authorized experiments without repeated permission requests. If a required boundary prevents execution, complete the available analysis and record the exact missing access or decision.
- Default priorities are wall-clock runtime, compute cost, then unnecessary data movement. Treat correctness as a constraint. Explicit user priorities override this ordering; expose runtime/cost tradeoffs before promoting a result that violates the agreed objective.

## Use sources when needed

The bundled playbooks contain the workflow and technical guidance. External links provide provenance and support targeted verification; opening them is not a prerequisite for loading the skill or starting repository analysis. Do not visit every citation by default.

Use repository code, pinned dependencies, generated SQL, query profiles, and existing validation evidence to establish the relevant behavior. Consult authoritative external sources when a concrete question about versions, API behavior, feature support, or correctness needs verification. A citation's presence or historical check date does not prove that it applies to the current environment.

If a source is unavailable, use available local documentation, pinned implementation code, or an appropriate isolated check within the authorized scope. Continue work that does not depend on the unresolved detail. If that detail is essential to a candidate's correctness or execution, leave that candidate unverified and record the missing evidence. Unavailable documentation does not waive correctness gates or measurement requirements.

## Recover the current state

Before implementing a candidate, inspect the relevant repository instructions, implementation, generated SQL, configuration, git state/history, gate and benchmark scripts, and any `OPTIMIZATION_HANDOFF.md`, `OPTIMIZATION_LOG.md`, or `CURRENT_BASELINE.md`.

Identify the current best **verified** implementation and a restorable commit or patch. A commit alone does not establish correctness or performance. Preserve unrelated uncommitted work. Previous conclusions are evidence about a particular version and dataset; check whether they still apply.

Record or recover:

- Code revision and working-tree differences; job/client/Snowpark version when relevant.
- Deterministic input snapshot, run parameters, session settings, output contract, and authoritative gate command.
- Warehouse type/size, concurrency, cache conditions, elapsed job time, relevant query IDs, and available cost.
- Compilation, execution, queue time, scans, rows, local/remote spill, important joins/windows/materializations, and final-write cost.

Reuse trustworthy measurements from an identical environment. Measure missing evidence instead of reflexively rerunning a multi-hour baseline. Read [measurement-and-records.md](references/measurement-and-records.md) for comparison design, profiling SQL, cost attribution, and persistent records.

If no authoritative correctness gate exists, surface that gap and establish the output contract and a candidate-independent validation approach before claiming a verified improvement. A missing gate is not a passing gate.

## Understand the execution and output contracts

Map sources, filters, joins, expansions, aggregations, windows, shared branches, materializations, and the final write as a DAG. Label important edges with grain, keys, row count, width, and reuse. Distinguish observed operator statistics from inferred behavior.

For each FINAL output, classify business grain, schema, multiplicity, retention, consumer access patterns, and refresh mode. In this skill, **SPLIT** means decomposing work into justified execution stages; **FINAL** means the published output relation. Neither is a special Snowflake SQL keyword for these strategies.

Read only the relevant detailed playbooks:

| Evidence or requested work | Reference |
|---|---|
| Scala repository detection, builds/gates, action tracing, generated SQL, session lifecycle, or Scala final writes | [Snowflake Scala jobs](references/scala-jobs.md) |
| Giant generated SQL, compilation overhead, shared branches, `cacheResult`, adding/removing stage boundaries, parallel work | [DAG splitting and partitioning](references/dag-and-partitioning.md) |
| Micro-partition pruning, clustering, window partitions, date/entity/hash work batches | [DAG splitting and partitioning](references/dag-and-partitioning.md) |
| FINAL table categories, schema/width, table lifecycle, CTAS, incremental output, publication | [Final tables and CTAS](references/final-tables-and-ctas.md) |
| Join explosions, repeated scans, windows/sorts, filter pushdown, UDFs, warehouse or service choices | [Strategy catalog](references/strategy-catalog.md) |
| MERGE target pruning, microbatch replay, empty runs, RELY, ASOF, multi-table writes, or Snowpark compiler controls | [Additional GitHub strategies](references/github-strategies.md) |
| Baselines, query profiles, timing, credits, experiment logs, restart handoff | [Measurement and records](references/measurement-and-records.md) |

## Run controlled experiments

1. **Observe and rank.** Build a short queue from the current profile. Rank roughly by expected total-job impact × confidence × likelihood of correctness ÷ experiment cost. Prefer structural/cardinality changes when evidence supports them; the measured bottleneck overrides a generic priority list.
2. **State one hypothesis.** Record candidate ID, baseline, observation, evidence, proposed isolated change, expected plan and metric change, correctness risk, estimated experiment cost, and confidence before editing. One hypothesis may require coordinated edits; do not mix unrelated tuning changes.
3. **Implement reversibly.** Preserve the restorable baseline. Use isolated candidate outputs and object names as appropriate. Keep unrelated formatting and refactoring out of the experiment.
4. **Reject cheaply.** Compile affected code; run existing local/small deterministic checks and inspect generated SQL/plans where useful. Use reduced or medium-scale runs only when they can falsify the hypothesis economically.
5. **Validate completely.** Pass the existing authoritative deterministic gate before promotion. Do not edit, weaken, mock, bypass, special-case, or change expected results in that gate to make a candidate pass. Preserve duplicates, NULL behavior, ordering where contractual, numeric semantics, and all schema requirements. Diagnostic checks supplement the gate.
6. **Measure the passing candidate.** Use comparable inputs and warehouse/cache conditions. Include staging, scans, final CTAS/write, and required publication work in the job boundary. Record gate overhead separately. Reduced-data timings and an isolated fast SELECT do not prove production improvement.
7. **Decide and persist.** Apply the decision table, record evidence and lessons, and restore or preserve the actual code state. Revert only candidate changes, including candidate-specific settings/objects where applicable; do not discard unrelated work.
8. **After every KEEP, profile again.** Establish the new verified baseline, identify where the bottleneck moved, re-rank the queue, and continue within the requested scope. After several structural changes, reconsider the current job independently of its optimization history.

| Decision | Required evidence and action |
|---|---|
| KEEP | Authoritative gate passes and full job performance meaningfully improves the agreed objective. Make this the new verified baseline. |
| REVERT — Incorrect | Gate fails. Diagnose the false assumption; allow a narrow repair within the same hypothesis, otherwise restore the baseline. |
| REVERT — Regression | Gate passes but the agreed objective worsens. Restore the baseline and record why. |
| REVERT — Neutral | Gate passes but the benefit is negligible. Normally restore; retain an enabling change only with a documented, separately justified reason and no claim of speedup. |
| INCONCLUSIVE | Measurement noise, missing validation, or infrastructure prevents a defensible conclusion. Preserve evidence, leave the baseline unchanged, and bound retries by information value and budget. |

Never promote an unmeasured or incorrect candidate. Do not accumulate failed candidate code. Do not change business semantics, use approximate algorithms, exploit accidental gate ordering, or hard-code benchmark dates/entities to manufacture an improvement.

## Persistence and interruption recovery

Use existing repository conventions; otherwise maintain `CURRENT_BASELINE.md` for the current best state and ranked queue, and append completed experiments to `OPTIMIZATION_LOG.md`. Record the original campaign baseline separately so total improvement remains calculable.

After each experiment, persist its result, measurements, decision, current baseline, queue, and next action. Before yielding during a long run, record run/query IDs, snapshot, output objects, command, and status so a fresh session can inspect the existing run instead of launching it twice. Use [the record formats](references/measurement-and-records.md) when the repository has none.

## Campaign stop conditions and report

Stop when the user-defined scope/target is complete, a repository-defined stop condition applies, the execution/time/token/credit budget is exhausted, necessary access/information/infrastructure is unavailable, or remaining plausible gains are negligible relative to experiment cost. Another valid campaign stop is five consecutive well-founded candidates without improvement **and** a fresh profile showing no substantial new bottleneck. Do not run filler candidates just to reach five.

Report the actual stop condition; original versus final verified runtime/cost; speedup and runtime reduction; correctness status and code revision; kept and rejected experiments with evidence; current bottlenecks; and up to three next experiments worth pursuing. Label unmeasured cost and inferred explanations explicitly. For scoped work, scale the report to the request.
