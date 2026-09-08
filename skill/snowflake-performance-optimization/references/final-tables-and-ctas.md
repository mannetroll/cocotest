# FINAL table design and final CTAS writes

Use this playbook when the final relation, output schema, output write, or publication
dominates a job. `FINAL` means the job's delivered relation, not a special Snowflake
table type or SQL keyword. The categories below are an engineering classification.
Reclassifying a contract is not permission to change its semantics.

## Contents

- Categorize the FINAL relation
- Preserve the schema contract
- Choose persistence separately
- Measure the actual output write
- Choose a layout from consumer evidence
- Build, validate, and publish
- Compare refresh strategies
- Candidate records

## Categorize the FINAL relation

Before rewriting its producer, record:

| Dimension | Required evidence |
| --- | --- |
| Business grain | Complete sentence: one row per what, at which effective time? |
| Cardinality | Row count, distinct business keys, duplicates, NULL keys, skew, expected growth |
| Key contract | Natural/surrogate keys, uniqueness scope, join multiplicity, optional relationships |
| Time contract | Event time, processing time, as-of time, time zone, late corrections, retention |
| Consumer contract | Required columns/order/types, filters, joins, full scans, latency/freshness |
| Update model | Append, replace, upsert, mutable history, deletion propagation, retry semantics |
| Physical footprint | Actual projected width, large payloads, storage, write bytes, pruning |

Classify logical role independently from wide/narrow shape and persistence:

| Role | Typical grain | Hypotheses to test | Required semantic protection |
| --- | --- | --- | --- |
| Detail fact/event | One event, transaction, or line item | Prune unused columns early; defer descriptive joins; append only when immutable | Preserve every required event, duplicates, identifiers, event time |
| Current dimension | One current row per entity | Compute attributes once; narrow branch inputs; avoid repeated joins | Verify one current row and deterministic update precedence |
| History/SCD2 dimension | One entity version per validity interval | Rebuild affected entity histories; avoid all-history work per update | Preserve interval boundaries, overlap rules, deletion and late-arrival behavior |
| Aggregate | One row per declared grouping tuple | Aggregate before expansion or joins where equivalent | Preserve distinct-count scope, NULL groups, and non-additive measures |
| Periodic snapshot | One entity per required observation period | Generate only required periods; rebuild affected snapshots | Preserve required empty periods, as-of rules, restatements |
| Accumulating snapshot | One process instance with milestone columns | Update affected instances | Preserve milestone transitions and reopened cases |
| Bridge/relationship | One valid association, possibly time bounded | Deduplicate only true duplicate associations; filter before expansion | Preserve multiplicity, allocation weights, and relationship validity |
| Wide reporting/feature table | One consumer key with many attributes | Keep expensive branches narrow; assemble final attributes late | Prove every branch joins at its intended grain without fanout |
| Long/narrow metric table | One entity/time/metric tuple | Share common calculations before metric expansion | Preserve metric identity, units, duplicates, and value types |
| Semi-structured payload | One object/event plus typed access columns | Parse repeated hot fields once; defer large payloads | Preserve missing versus NULL, arrays, nested values, and payload fidelity |

Wide tables can reduce consumer joins but increase producer work and write volume.
Narrow intermediate branches can reduce work without changing the delivered schema.
Treat converting the delivered wide table into a long table, or replacing facts with
aggregates, as a contract change unless the existing interface and exact results are
preserved. A smaller table alone does not establish an improvement.

For each final column, label it as a key, predicate/join field, measure, descriptive
attribute, audit field, or opaque payload. Trace its last required producer and first
required consumer. Test deferring a wide attribute only after proving that its join
does not filter, multiply, or otherwise affect intermediate rows.

## Preserve the schema contract

Capture the baseline DDL and compare names, ordinal positions, types, precision,
scale, nullability, defaults, constraints, collations, policies, tags, and comments.
Use explicit projections; never rely on `SELECT *` for a durable output contract.
CTAS infers omitted column definitions from its query, so inspect the produced DDL.
[CTAS reference](https://docs.snowflake.com/en/sql-reference/sql/create-table#variant-syntax)

Do not let a successful value comparison conceal changed metadata. Clients may
bind by position, infer decimals differently, or depend on nullable metadata.
If explicit CTAS definitions cannot represent the required contract, compare an
explicitly defined target plus `INSERT ... SELECT`; account for its entire cost.

| Area | Checks before changing it |
| --- | --- |
| Fixed-point numbers | Preserve the required `NUMBER(p,s)` range and scale; test rounding, division, negative values, and overflow |
| Floating-point numbers | Do not replace exact decimals with `FLOAT` for speed; preserve the existing gate and exceptional-value behavior |
| Timestamp values | Preserve explicit NTZ/LTZ/TZ type, fractional precision, conversion rules, and session settings |
| NULLs | Preserve SQL NULL versus missing/JSON null and NULL-versus-zero semantics; do not add blanket `COALESCE` |
| Strings | Preserve case, collation, empty strings, identifiers, and required lengths |
| Keys | Validate uniqueness and relationships using data; do not assume declarations enforce them |
| Ordered output | Require consumers to specify their own `ORDER BY` when order is part of the interface |

Reducing NUMBER precision alone does not reduce storage for identical values;
scale can affect storage and processing. FLOAT conversion can lose precision.
[Numeric types](https://docs.snowflake.com/en/sql-reference/data-types-numeric)

NTZ represents wall-clock time; LTZ uses UTC storage with session-time-zone
operations; TZ retains an offset rather than a named time zone. Bare TIMESTAMP
depends on `TIMESTAMP_TYPE_MAPPING`. Explicitly test daylight-saving transitions
and date extraction when changing temporal expressions.
[Date and time types](https://docs.snowflake.com/en/sql-reference/data-types-datetime)

On standard tables, primary/foreign keys are informational; NOT NULL and CHECK are
enforced. Verify the current constraint rules for the actual table kind. Smaller
declared VARCHAR lengths are not a general Snowflake query-performance improvement.
Use native temporal types when that matches the contract.
[Table design considerations](https://docs.snowflake.com/en/user-guide/table-considerations)

## Choose persistence separately

| Persistence | Appropriate purpose | Consequence to account for |
| --- | --- | --- |
| Temporary | Work confined to one session | Other sessions cannot consume it; session termination removes it |
| Transient | Reconstructible work shared across sessions or restartable DAG stages | Persists until dropped; no Fail-safe; limited Time Travel |
| Permanent | Durable delivery with required recovery guarantees | Retention and Fail-safe contribute to lifecycle storage costs |

Temporary and transient tables still incur storage costs. A temporary table can
shadow a same-named permanent/transient table in its session; use qualified,
run-specific names. Do not use TEMP as a cross-session handoff. A transient table
cannot be converted in place to another type. Choose final durability explicitly;
changing names does not upgrade durability.
[Temporary and transient tables](https://docs.snowflake.com/en/user-guide/tables-temp-transient)

Changing permanence is a recovery-policy decision, not a demonstrated speedup.
Keep the production persistence contract unless the task authorizes changing it.

## Measure the actual output write

Define the finish line as the validated output being available through its promised
interface. Record upstream preparation, final statement, validation, and publication
as separate intervals, plus the complete job interval. For parallel work, use actual
elapsed time and dependency timing instead of adding overlapping stage runtimes.

Record the final CTAS query ID and profile separately even when it includes all
upstream relational computation. Its statement duration is not a pure storage-write
measurement: report source scans, joins, sorts, spill, and writer activity together.
Do not label CTAS duration minus a separately run SELECT duration as measured write
time; those statements can execute different plans under different conditions.

Capture `TOTAL_ELAPSED_TIME`, `COMPILATION_TIME`, `EXECUTION_TIME`, queue/blocking
times, `BYTES_SCANNED`, `BYTES_WRITTEN`, `ROWS_INSERTED`, and local/remote spill where
available. Do not use `ROWS_PRODUCED` as a substitute for inserted-row count.
Record absent metrics as unavailable.
[QUERY_HISTORY columns](https://docs.snowflake.com/en/sql-reference/account-usage/query_history)

Compare the baseline and candidate with the same output shape, snapshot, warehouse,
policies, persistence, consumer finish line, and cache/concurrency conditions.
Account for staging writes, readbacks, retries, and any recurring maintenance.
Distinguish runtime available to consumers from the experiment's validation cost,
but report both and never remove required production validation from the benchmark.

Rank final-write candidates from current evidence:

1. Remove a redundant write-and-copy when a direct final CTAS preserves publication.
2. Reduce rows entering the final stage without changing the final relation.
3. Reduce intermediate width while restoring the exact output projection.
4. Remove a final sort or DISTINCT only when its semantic purpose is disproven.
5. Compare natural load order, intentional ordering, and clustering independently.
6. Test a different refresh method only when its change semantics are equivalent.

A faster SELECT, compile, or upstream branch is insufficient if CTAS, validation,
or publication becomes slower. Keep improvements based on the complete objective.

## Choose a layout from consumer evidence

CTAS `CLUSTER BY` adds a sort and normally enables Automatic Clustering. Explicit
column definitions are required. CTAS `ORDER BY` can create initially sorted data.
[CTAS usage notes](https://docs.snowflake.com/en/sql-reference/sql/create-table#usage-notes)

Treat these as distinct experiments: no explicit layout, one-time load ordering,
and a maintained clustering key. Evaluate build cost plus representative consumer
queries over the table's expected lifetime. Clustering trades initial and recurring
credits for potential pruning/compression benefits; favor evidence from selective
filters and observed micro-partition overlap, not a key's business importance.
[Clustering considerations](https://docs.snowflake.com/en/user-guide/tables-clustering-keys)

Persisted layout does not replace consumer `ORDER BY`. Preserve deterministic tie
handling wherever ordering controls a result such as top-N or row numbering.
[ORDER BY](https://docs.snowflake.com/en/sql-reference/constructs/order-by)

## Build, validate, and publish

Use the existing release mechanism when it satisfies the contract. Otherwise first
design and verify a concrete publication procedure in an isolated environment:

1. Snapshot the target's contract, owner, grants, policies, dependencies, streams,
   persistence, and retention; identify concurrent readers and writers.
2. Build an immutable candidate under a qualified, unique run name using the same
   source snapshot as the baseline. Never overwrite the verified target to test.
3. Run the unchanged authoritative gate on the candidate. Add separate schema and
   consumer checks as needed. Counts and hashes are supplementary diagnostics.
4. Prepare the intended ownership, grants, policies, and tags on the candidate.
   Verify access using the actual consumer role and interface.
5. Publish with the tested mechanism within the existing authorization. Ensure a
   newer production write cannot be silently lost during the cutover.
6. Verify the public interface, record published object/query IDs, retain the prior
   version for the agreed rollback period, and clean up only owned run artifacts.

Publication options have different semantics:

| Method | What must be established first |
| --- | --- |
| Rename a candidate to an unused name | No existing-name collision; reader/dependency plan; correct persistence |
| SWAP candidate with target | Compatible table kinds, OWNERSHIP on both, and metadata/dependency checks; streams become stale, so require a tested stream migration |
| INSERT OVERWRITE into existing target | Same schema, complete replacement semantics, explicit columns, acceptable change-feed volume |
| Transactional incremental DML | Complete change set, deterministic key matching, deletion handling, replay/concurrency behavior |
| Versioned table behind a consumer view | Consumers accept this interface; switching preserves access and all dependent objects |

`SWAP WITH` renames two tables atomically, but cannot swap a temporary table with a
permanent/transient table. A permanent/transient exchange must not accidentally
change final durability. A rename requires an unused destination and relevant
privileges. Do not substitute several renames and describe them as one atomic swap.
[ALTER TABLE](https://docs.snowflake.com/en/sql-reference/sql/alter-table)

DDL, including CTAS, executes in its own transaction and commits an active
transaction. `BEGIN` around create/validate/rename statements does not make that
sequence atomically reversible. Failure recovery needs an explicit publication plan.
[Transactions](https://docs.snowflake.com/en/sql-reference/transactions)

`OR REPLACE` is atomic replacement, not validation. CTAS `COPY GRANTS` requires
`OR REPLACE`, copies replaced-target grants rather than SELECT-source grants, and
excludes OWNERSHIP. Recreating **or swapping** a table drops change data and makes
streams on it, or dependent views, stale. Do not advertise either as stream-safe.
[CREATE TABLE behavior](https://docs.snowflake.com/en/sql-reference/sql/create-table#usage-notes)

Inventory dependencies by name and object ID; views, streams, and materialized
views do not all bind identically. Validate downstream objects and reconcile grants
after publication rather than assuming the old name guarantees continuity.
[Object dependencies](https://docs.snowflake.com/en/user-guide/object-dependencies)

## Compare refresh strategies

| Strategy | Candidate when | Reject or extend when |
| --- | --- | --- |
| Full CTAS | Most data changes; global computation; full output required | Write/publication dominates and a complete incremental alternative exists |
| Explicit target plus INSERT SELECT | Stable schema or controlled existing-object semantics matter | An extra materialization/write adds cost without a measured benefit |
| INSERT OVERWRITE | Full replacement into an existing schema/interface is required | Replacement change volume, consumer behavior, or locking is unacceptable |
| Append INSERT | New data is immutable and retries cannot duplicate it | Updates/deletes/late corrections affect prior output |
| MERGE | A bounded, complete changed-key set exists | Key matching is ambiguous or target scans/rewrite volume outweigh savings |
| Transactional delete-and-insert for affected scope | A complete entity/date scope can be recomputed | Scope omits window context, late data, or cross-boundary effects |

`INSERT OVERWRITE` operates inside a transaction, leaves access privileges intact,
and requires DELETE privilege. Explicit target-column lists prevent positional
mistakes. Treat change-feed behavior as part of validation.
[INSERT](https://docs.snowflake.com/en/sql-reference/sql/insert)

For MERGE, keep `ERROR_ON_NONDETERMINISTIC_MERGE=TRUE`. Prove source matching is
unambiguous; a deduplication rule must come from business semantics. Duplicate
unmatched source rows can still be inserted, so that parameter alone does not
establish uniqueness. Include missing-source deletions explicitly when required.
[MERGE duplicate behavior](https://docs.snowflake.com/en/sql-reference/sql/merge#duplicate-join-behavior)

Incremental output is a separate semantic hypothesis: specify watermarks, change
capture, invalidation of old aggregates/windows, deletes, retries, backfills, and
reconciliation against full recomputation. Compare equal freshness and equivalent
results; skipped corrections or deferred work are not performance improvements.

## Candidate records

Add to the experiment record: FINAL category and grain; unchanged contract;
baseline/candidate refresh and publication methods; final statement query IDs;
upstream/final-write/validation/publication/job times; write and spill metrics;
consumer impact; maintenance cost; gate result; and KEEP/REVERT/INCONCLUSIVE decision.
After every KEEP, profile the new final stage before choosing the next candidate.

Technical references checked against official Snowflake documentation on 2026-09-08.
Recheck relevant command restrictions when implementing against another release,
table kind, or account configuration.
