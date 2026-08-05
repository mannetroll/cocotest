# CREATE SEMANTIC VIEW

- [](/user-guide/views-semantic/overview)
- [](/user-guide/views-semantic/sql)
- [](/user-guide/views-semantic/validation-rules)

Creates a new [semantic view](/user-guide/views-semantic/overview) in the current/specified schema.

The semantic view must comply with [these validation rules](/user-guide/views-semantic/validation-rules).

This command supports the following variants:

- [CREATE OR ALTER SEMANTIC VIEW](#label-create-or-alter-semantic-view-syntax): Creates a semantic view if it doesn't exist or alters an existing semantic view.

<dl className="field-list">
<dt>See also<span className="colon">:</span></dt>
<dd>

[](/sql-reference/sql/alter-semantic-view) , [](/sql-reference/sql/desc-semantic-view) , [](/sql-reference/sql/drop-semantic-view) , [](/sql-reference/sql/show-semantic-views) , [](/sql-reference/sql/show-semantic-dimensions) , [](/sql-reference/sql/show-semantic-dimensions-for-metric) , [](/sql-reference/sql/show-semantic-facts) , [](/sql-reference/sql/show-semantic-metrics) , [](/sql-reference/stored-procedures/system_create_semantic_view_from_yaml)

[](/sql-reference/sql/create-or-alter)

</dd>
</dl>

<a id="label-create-semantic-view-syntax"></a>

## Syntax

```sqlsyntax
CREATE [ OR REPLACE ] SEMANTIC VIEW [ IF NOT EXISTS ] <name>
  TABLES ( logicalTable [ , ... ] )
  [ RELATIONSHIPS ( relationshipDef [ , ... ] ) ]
  [ FACTS ( factExpression [ , ... ] ) ]
  [ DIMENSIONS ( dimensionExpression [ , ... ] ) ]
  [ METRICS ( { metricExpression | windowFunctionMetricExpression } [ , ... ] ) ]
  [ COMMENT = '<comment_about_semantic_view>' ]
  [ MAX_STALENESS = <integer> ]
  [ AI_SQL_GENERATION '<instructions_for_sql_generation>' ]
  [ AI_QUESTION_CATEGORIZATION '<instructions_for_question_categorization>' ]
  [ AI_VERIFIED_QUERIES ( verifiedQuery [ , ... ] ) ]
  [ [ WITH ] TAG ( <tag_name> = '<tag_value>' [ , <tag_name> = '<tag_value>' , ... ] ) ]
  [ COPY GRANTS ]
```

where:

- The [parameters for logical tables](#label-create-semantic-view-tables) are:

  <a id="label-create-semantic-view-syntax-logical-table"></a>

  ```sqlsyntax
  logicalTable ::=
    [ <table_alias> AS ] <table_name>
    [ PRIMARY KEY ( <primary_key_column_name> [ , ... ] ) ]
    [
   UNIQUE ( <unique_column_name> [ , ... ] )
   [ ... ]
    ]
    [
   CONSTRAINT [ <constraint_name> ]
     DISTINCT RANGE BETWEEN <start_column> AND <end_column> EXCLUSIVE
    ]
    [ WITH SYNONYMS [ = ] ( '<synonym>' [ , ... ] ) ]
    [ COMMENT = '<comment_about_table>' ]
    [ [ WITH ] TAG ( <tag_name> = '<tag_value>' [ , <tag_name> = '<tag_value>' , ... ] ) ]
  ```

- The [parameters for relationships](#label-create-semantic-view-relationships) are:

  <a id="label-create-semantic-view-syntax-relationship"></a>

  ```sqlsyntax
  relationshipDef ::=
    [ <relationship_identifier> AS ]
    <table_alias> ( <column_name> [ , ... ] )
    REFERENCES
    <ref_table_alias> [ (
   [ ASOF ] <ref_column_name> [ , ... ] |
   BETWEEN <start_column> AND <end_column> EXCLUSIVE
    ) ]
  ```

- The [parameters for expressions in the definitions of facts](#label-create-semantic-view-expressions) are:

  <a id="label-create-semantic-view-syntax-fact-expression"></a>

  ```sqlsyntax
  factExpression ::=
    [ { PRIVATE | PUBLIC } ] <table_alias>.<fact>
   [ LABELS = ( FILTER ) ]
   AS <sql_expr>
    [ WITH SYNONYMS [ = ] ( '<synonym>' [ , ... ] ) ]
    [ [ WITH ] TAG ( <tag_name> = '<tag_value>' [ , <tag_name> = '<tag_value>' , ... ] ) ]
    [ COMMENT = '<comment_about_the_fact>' ]
  ```

- The [parameters for expressions in the definitions of dimensions](#label-create-semantic-view-expressions) are:

  <a id="label-create-semantic-view-syntax-dimension-expression"></a>

  ```sqlsyntax
  dimensionExpression ::=
    [ PUBLIC ] <table_alias>.<dimension>
   [ LABELS = ( FILTER ) ]
   AS <sql_expr>
    [ WITH SYNONYMS [ = ] ( '<synonym>' [ , ... ] ) ]
    [ [ WITH ] TAG ( <tag_name> = '<tag_value>' [ , <tag_name> = '<tag_value>' , ... ] ) ]
    [ COMMENT = '<comment_about_the_dimension>' ]
    [ WITH CORTEX SEARCH SERVICE <search_service_name> [ USING <search_service_column_name> ] ]
  ```

- The [parameters for expressions in the definitions of metrics](#label-create-semantic-view-expressions) are:

  <a id="label-create-semantic-view-syntax-metric-expression"></a>

  ```sqlsyntax
  metricExpression ::=
    [ { PRIVATE | PUBLIC } ] <table_alias>.<metric>
   [ USING ( <relationship_name> [ , ... ] ) ]
   [
     NON ADDITIVE BY (
       <dimension> [ { ASC | DESC } ] [ NULLS { FIRST | LAST } ]
       [ , ... ]
     )
   ]
   AS <sql_expr>
    [ WITH SYNONYMS [ = ] ( '<synonym>' [ , ... ] ) ]
    [ [ WITH ] TAG ( <tag_name> = '<tag_value>' [ , <tag_name> = '<tag_value>' , ... ] ) ]
    [ COMMENT = '<comment_about_the_metric>' ]
  ```

<a id="label-create-semantic-view-window-function-syntax"></a>

- You can define a metric that uses a window function (a *window function metric*) by using the following syntax:

  ```sqlsyntax
  windowFunctionMetricExpression ::=
    [ { PRIVATE | PUBLIC } ] <table_alias>.<metric> AS
   <window_function>( <metric> ) OVER (
     [ PARTITION BY { <exprs_using_dimensions_or_metrics> | EXCLUDING <dimensions> } ]
     [ ORDER BY <exprs_using_dimensions_or_metrics> [ ASC | DESC ] [ NULLS { FIRST | LAST } ] [, ...] ]
     [ <windowFrameClause> ]
   )
  ```

  For information about this syntax, see [](#label-create-semantic-view-window-function).

<a id="label-create-semantic-view-verified-queries-syntax"></a>

- The [parameters for verified queries](#label-create-semantic-view-verified-queries) are:
  ```sqlsyntax
  verifiedQuery ::=
    <verified_query_name> AS (
   QUESTION '<question>'
   [ VERIFIED_AT <timestamp> ]
   [ ONBOARDING_QUESTION <boolean> ]
   [ VERIFIED_BY '( <purpose> = <contact> )' ]
   SQL '<verified_query>'
    )
  ```

The order of the clauses is important. For example, you must specify the FACTS clause before the DIMENSIONS clause.

You can refer to semantic expressions that are defined in later clauses. For example, even if `fact_2` is defined after
`fact_1`, you can still use `fact_2` in the definition of `fact_1`.

## Required parameters

<dl>
<dt><code className="samp"><em>name</em></code></dt>
<dd>

Specifies the name of the semantic view; the name must be unique for the schema in which the table is created.

In addition, the identifier must start with an alphabetic character and cannot contain spaces or special characters unless the
entire identifier string is enclosed in double quotes (for example, `"My object"`). Identifiers enclosed in double quotes are also
case-sensitive.

For more information, see [Identifier requirements](/sql-reference/identifiers-syntax).

</dd>
</dl>

## Optional parameters

<dl>
<dt><code className="samp">COMMENT = '<em>comment_about_semantic_view</em>'</code></dt>
<dd>

Specifies a comment about the semantic view.

</dd>
<dt><code className="samp">MAX_STALENESS = <em>integer</em></code></dt>
<dd>

Sets the maximum number of seconds that a [materialization](/user-guide/views-semantic/materializations) can be stale
before Snowflake automatically suspends it. Required before you can add materializations to the semantic view.
Minimum value: `120` (2 minutes). Can't be unset while materializations exist on the semantic view.

</dd>
<dt><code className="samp">AI_SQL_GENERATION '<em>instructions_for_sql_generation</em>'</code></dt>
<dd>

Specifies [instructions for Cortex Analyst](/user-guide/snowflake-cortex/cortex-analyst/custom-instructions) that explain
how to generate the SQL statement.

For more information, see [](#label-semantic-views-custom-instructions).

</dd>
<dt><code className="samp">AI_QUESTION_CATEGORIZATION '<em>instructions_for_question_categorization</em>'</code></dt>
<dd>

Specifies [instructions for Cortex Analyst](/user-guide/snowflake-cortex/cortex-analyst/custom-instructions) that explain
how to classify questions.

For more information, see [](#label-semantic-views-custom-instructions).

</dd>
</dl>

<dl>
<dt>`TAG ( tag_name = 'tag_value' [ , tag_name = 'tag_value' , ... ] )`</dt>
<dd>

Specifies the [tag](/user-guide/object-tagging/introduction) name and the tag string value.

The tag value is always a string, and the maximum number of characters for the tag value is 256.

For information about specifying tags in a statement, see [](#label-object-tagging-quota).

</dd>
</dl>

<dl>
<dt>`COPY GRANTS`</dt>
<dd>

When you specify OR REPLACE to replace an existing semantic view with a new semantic view, you can set this parameter to copy
any privileges granted on the existing semantic view to the new semantic view.

The command copies all privilege grants <span className="emph">except</span> OWNERSHIP from the existing semantic view to the new semantic view. The
role that executes the CREATE SEMANTIC VIEW statement owns the new view.

The new semantic view does <span className="emph">not</span> inherit any future grants defined for the object type in the schema.

The operation to copy grants occurs atomically with the CREATE SEMANTIC VIEW statement (in other words, within the same
transaction).

If you omit COPY GRANTS, the new semantic view does <span className="emph">not</span> inherit any explicit access privileges granted on the existing
semantic view but does inherit any future grants defined for the object type in the schema.

</dd>
</dl>

<a id="label-create-semantic-view-tables"></a>

## Parameters for logical tables

These parameters are part of the [syntax for logical tables](#label-create-semantic-view-syntax-logical-table):

<dl>
<dt><code className="samp"><em>table_alias</em> AS</code></dt>
<dd>

Specifies an optional alias for the logical table.

- If you specify an alias, you must use this alias when referring to the logical table in relationships, facts, dimensions,
  and metrics.
- If you do not specify an alias, you use the unqualified logical table name to refer to the table.

</dd>
<dt><code className="samp"><em>table_name</em></code></dt>
<dd>

Specifies the name of the logical table.

</dd>
<dt><code className="samp">PRIMARY KEY ( <em>primary_key_column_name</em> [ , ... ] )</code></dt>
<dd>

Specifies the names of one or more columns in the logical table that serve as the primary key of the table.

</dd>
<dt><code className="samp">UNIQUE ( <em>unique_column_name</em> [ , ... ] )</code></dt>
<dd>

Specifies the name of a column containing a unique value or the names of columns that contain unique combinations of values.

For example, if the column `service_id` contains unique values, specify:

```sql
TABLES(
  ...
  product_table UNIQUE (service_id)
```

If the combination of values in the `product_area_id` and `product_id` columns is unique, specify:

```sql
TABLES(
  ...
  product_table UNIQUE (product_area_id, product_id)
  ...
```

You can identify multiple columns and multiple combinations of columns as unique in a given logical table:

```sql
TABLES(
  ...
  product_table UNIQUE (product_area_id, product_id) UNIQUE (service_id)
  ...
```

If you already identified a column as a primary key column (by using PRIMARY KEY), do not add the UNIQUE clause for that
column.

</dd>
</dl>

<a id="label-create-semantic-view-tables-constraint"></a>

<code className="samp">CONSTRAINT [ <em>constraint_name</em> ]</code> <br /> <code className="samp">DISTINCT RANGE BETWEEN <em>start_column</em> AND <em>end_column</em> EXCLUSIVE</code>

<blockquote>

<div className="previewfeat sidebar">

<div className="sidebar-title">

%logo-snowflake-black% [Preview Feature](/release-notes/preview-features) — Open

</div>

Available to all accounts.

</div>

Specifies a constraint for a [range join](#label-semantic-views-custom-range-joins).

<dl>
<dt><code className="samp"><em>constraint_name</em></code></dt>
<dd>

Specifies an optional name for the constraint.

If you omit this name, the command uses a system-generated name for the constraint.

</dd>
</dl>

<code className="samp">DISTINCT RANGE BETWEEN <em>start_column</em> AND <em>end_column</em> EXCLUSIVE</code> specifies that in each row, the range
between <code className="samp"><em>start_column</em></code> and <code className="samp"><em>end_column</em></code> is a distinct range:

- The range is a [half-open interval](https://en.wikipedia.org/wiki/Interval_(mathematics)#Definitions_and_terminology),
  where the range is closed on the left side (<code className="samp"><em>start_column</em></code>) and open on the right
  (<code className="samp"><em>end_column</em></code>).

  In other words, the time on the left is included in the range, but the time on the right is excluded from the range.

  For example, for a row in this table, if the value in <code className="samp"><em>start_column</em></code> is `2024-01-15 00:00:00.000` and the value
  in <code className="samp"><em>end_column</em></code> is `2024-02-01 00:00:00.000`, the range is:

  <code className="samp">2024-01-15 00:00:00.000 &lt;= <em>timestamp_from_other_table</em> &lt; 2024-02-01 00:00:00.000</code>

  The timestamp `2024-01-15 00:00:00.000` is included in this range, but the timestamp `2024-02-01 00:00:00.000` is not.

- <code className="samp"><em>start_column</em></code> and <code className="samp"><em>end_column</em></code> must be physical columns from the same table or facts or dimensions from
  the same table.

</blockquote>

<dl>
<dt><code className="samp">WITH SYNONYMS [ = ] ( '<em>synonym</em>' [ , ... ] )</code></dt>
<dd>

Specifies one or more synonyms for the logical table. Unlike aliases, synonyms are used for informational purposes only. You do
not use synonyms to refer to the logical table in relationships, dimensions, metrics, and facts.

</dd>
<dt><code className="samp">COMMENT = '<em>comment_about_table</em>'</code></dt>
<dd>

Specifies a comment about the logical table.

</dd>
</dl>

<dl>
<dt>`TAG ( tag_name = 'tag_value' [ , tag_name = 'tag_value' , ... ] )`</dt>
<dd>

Specifies the [tag](/user-guide/object-tagging/introduction) name and the tag string value.

The tag value is always a string, and the maximum number of characters for the tag value is 256.

For information about specifying tags in a statement, see [](#label-object-tagging-quota).

</dd>
</dl>

<a id="label-create-semantic-view-relationships"></a>

## Parameters for relationships

These parameters are part of the [syntax for relationships](#label-create-semantic-view-syntax-relationship):

<dl>
<dt><code className="samp"><em>relationship_identifier</em> AS</code></dt>
<dd>

Specifies an optional identifier for the relationship.

</dd>
<dt><code className="samp"><em>table_alias</em> ( <em>column_name</em> [ , ... ] )</code></dt>
<dd>

Specifies one of the logical tables and one or more of its columns that refers to columns in another logical table.

</dd>
<dt><code className="samp"><em>ref_table_alias</em> [ ( ... ) ]</code></dt>
<dd>

Specifies the other logical table referred to by the first logical table.

You can specify one of the following in parentheses, depending on how you want to join the tables:

<dl>
<dt><code className="samp"><em>ref_column_name</em> [ , ... ]</code></dt>
<dd>

Specifies a column identified with the PRIMARY KEY or UNIQUE constraint in the
[logical table definition](#label-create-semantic-view-tables).

</dd>
<dt><code className="samp">ASOF <em>ref_column_name</em> [ , ... ] )</code></dt>
<dd>

For an [ASOF join](#label-semantic-views-create-relationships-asof), specifies a column of one of
[the supported types](#label-asof-join-data-types).

You can specify at most one ASOF keyword in the definition of a given relationship. You can specify this keyword before any
column in the list.

</dd>
</dl>

<code className="samp">BETWEEN <em>start_column</em> AND <em>end_column</em> EXCLUSIVE</code>

<blockquote>

<div className="previewfeat sidebar">

<div className="sidebar-title">

%logo-snowflake-black% [Preview Feature](/release-notes/preview-features) — Open

</div>

Available to all accounts.

</div>

For a [range join](#label-semantic-views-custom-range-joins), specifies the range of possible values in the first table.

<dl>
<dt><code className="samp"><em>start_column</em></code> <br /> <code className="samp"><em>end_column</em></code></dt>
<dd>

Specifies the columns that define the start and end of the range.

- You must [define a constraint for these columns](#label-create-semantic-view-tables-constraint).
- You cannot use the same column for both <code className="samp"><em>start_column</em></code> and <code className="samp"><em>end_column</em></code>.

  If you want to use the same column, use an [ASOF relationship](#label-semantic-views-create-relationships-asof).

<code className="samp"><em>column_name</em></code> must have a data type that can be [coerced](/sql-reference/data-type-conversion) to the
data types for <code className="samp"><em>start_column</em></code> and <code className="samp"><em>end_column</em></code>.

</dd>
</dl>

</blockquote>

</dd>
</dl>

<a id="label-create-semantic-view-expressions"></a>

## Parameters for facts, dimensions, and metrics

In a semantic view, you must define at least one dimension or metric, which means that you must specify at least the DIMENSIONS
clause or the METRICS clause.

These parameters are part of the syntax for defining a [fact](#label-create-semantic-view-syntax-fact-expression),
[dimension](#label-create-semantic-view-syntax-dimension-expression), or
[metric](#label-create-semantic-view-syntax-metric-expression):

<dl>
<dt>`{ PRIVATE | PUBLIC }`</dt>
<dd>

Specifies whether a fact or metric is [private](#label-semantic-views-private) or public. Facts and metrics that are
marked as private cannot be queried or used in a query condition.

You cannot mark a dimension as private. Dimensions are always public. For a dimension, the effect is the same whether you
specify or omit PUBLIC.

If you omit PRIVATE and PUBLIC, the dimension, fact, or metric is public by default.

</dd>
<dt><code className="samp"><em>table_alias</em>.<em>semantic_expression_name</em></code></dt>
<dd>

Specifies a name for a dimension, fact, or metric.

</dd>
</dl>

<code className="samp">USING <em>relationship_name</em> [ , ... ]</code>

<blockquote>

<div className="previewfeat sidebar">

<div className="sidebar-title">

%logo-snowflake-black% [Preview Feature](/release-notes/preview-features) — Open

</div>

Available to all accounts.

</div>

For metric definitions, specifies the relationship that should be used to join the tables and calculate the metric, when
[multiple relationship paths exist between two logical tables](#label-semantic-views-create-logical-tables-relations).

To define a [derived metric](#label-semantic-views-create-derived-metrics) (a metric that combines multiple metrics from
different logical tables), omit <code className="samp"><em>table_alias</em>.</code> from the name.

See [](/user-guide/views-semantic/validation-rules) for the rules for defining a valid semantic view.

</blockquote>

<dl>
<dt><code className="samp">NON ADDITIVE BY ( <em>dimension</em> [ &#123; ASC | DESC &#125; ] [ NULLS &#123; FIRST | LAST &#125; ] [ , ... ] )</code></dt>
<dd>

Specifies a list of dimensions that should not be used when summing the metric.

Instead, during query processing, the rows are sorted by the non-additive dimensions, and the values from the last rows (the
*latest snapshots of values*) are aggregated to compute the metric.

<dl>
<dt>`{ ASC | DESC }`</dt>
<dd>

Optionally sorts the values of the non-additive dimensions in ascending (lowest to highest) or descending (highest to lowest)
order, which determines what the last snapshot is.

Default: ASC

</dd>
<dt>`NULLS { FIRST | LAST }`</dt>
<dd>

Optionally specifies whether NULL values are sorted before/after non-NULL values, based on the sort order (ASC or DESC). The
sort order determines what the last snapshot is.

Default: Depends on the sort order (ASC or DESC); see
[the usage notes in the ORDER BY documentation](#label-order-by-nulls).

</dd>
</dl>

Specifying the NON ADDITIVE BY clause makes the metric a *semi-additive* metric.

For information, see [](#label-semantic-views-metrics-semi-additive).

</dd>
<dt>`LABELS = ( FILTER )`</dt>
<dd>

Specifies that the fact or dimension can also be used as a filter in the WHERE clause of a query. The SQL expression for the
fact or dimension must resolve to a BOOLEAN value.

You can only specify this parameter for facts and dimensions (not for metrics).

For more information, see [](#label-semantic-view-filter-defining).

</dd>
<dt><code className="samp">AS <em>sql_expr</em></code></dt>
<dd>

Specifies the SQL expression for computing the dimension, fact, or metric.

See [](#label-semantic-views-create-facts-dimensions-metrics). For the validation rules for these expressions, see
[](/user-guide/views-semantic/validation-rules).

</dd>
<dt><code className="samp">WITH SYNONYMS [ = ] ( '<em>synonym</em>' [ , ... ] )</code></dt>
<dd>

Specifies one or more optional synonyms for the dimension, fact, or metric. Note that synonyms are used for informational
purposes only. You cannot use a synonym to refer to a dimension, fact, or metric in another dimension, fact, or metric.

</dd>
</dl>

<dl>
<dt>`TAG ( tag_name = 'tag_value' [ , tag_name = 'tag_value' , ... ] )`</dt>
<dd>

Specifies the [tag](/user-guide/object-tagging/introduction) name and the tag string value.

The tag value is always a string, and the maximum number of characters for the tag value is 256.

For information about specifying tags in a statement, see [](#label-object-tagging-quota).

</dd>
</dl>

<dl>
<dt><code className="samp">COMMENT = '<em>comment_about_dim_fact_or_metric</em>'</code></dt>
<dd>

Specifies an optional comment about the dimension, fact, or metric.

</dd>
<dt><code className="samp">WITH CORTEX SEARCH SERVICE <em>search_service_name</em> [ USING <em>search_service_column_name</em> ]</code></dt>
<dd>

Specifies the
[Cortex Search Service to use for this dimension](#label-semantic-views-create-cortex-search-service-dimension).

You can only specify this parameter for dimensions (and not for facts or metrics).

If the Cortex Search Service is in a different database or schema,
[qualify the name of the service](/sql-reference/name-resolution) (for example, `my_db.my_schema.my_service`).

You can set the optional USING clause to the name of the column in the Cortex Search Service.

</dd>
</dl>

<a id="label-create-semantic-view-window-function"></a>

## Parameters for window function metrics

These parameters are part of the
[syntax for defining window function metrics](#label-create-semantic-view-window-function-syntax):

<dl>
<dt><code className="samp"><em>metric</em></code></dt>
<dd>

Specifies a metric expression for this window function. You can specify a metric or any valid metric expression that you can use
to define a metric in this entity.

</dd>
<dt>`PARTITION BY ...`</dt>
<dd>

Groups rows into partitions. You can either partition by a specified set of expressions or by all dimensions (except selected
dimensions) specified in the query:

<dl>
<dt><code className="samp">PARTITION BY <em>exprs_using_dimensions_or_metrics</em></code></dt>
<dd>

Groups rows into partitions by SQL expressions. In the SQL expression:

- Any dimensions in the expression must be accessible from the same entity that defines the window function metric.
- Any metrics must belong to the same table where this metric is being defined.
- You cannot specify aggregates, window functions, or subqueries.

</dd>
<dt><code className="samp">PARTITION BY EXCLUDING <em>dimensions</em></code></dt>
<dd>

Groups rows into partitions by all of the dimensions specified in the [](/sql-reference/constructs/semantic_view) clause of
the query, except for the dimensions specified by <code className="samp"><em>dimensions</em></code>.

<code className="samp"><em>dimensions</em></code> must only refer to dimensions that are accessible from the entity that defines the window function
metric.

For example, suppose that you exclude the dimension `table_1.dimension_1` from partitioning:

```sql
CREATE SEMANTIC VIEW sv
  ...
  METRICS (
    table_1.metric_2 AS SUM(table_1.metric_1) OVER
      (PARTITION BY EXCLUDING table_l.dimension_1 ORDER BY table_1.dimension_2)
  )
  ...
```

Suppose that you run a query that specifies the dimension `table_1.dimension_1`:

```sql
SELECT * FROM SEMANTIC VIEW(
  sv
  METRICS (
    table_1.metric_2
  )
  DIMENSIONS (
    table_1.dimension_1,
    table_1.dimension_2,
    table_1.dimension_3
  );
```

In the query, the metric `table_1.metric_2` is evaluated as:

```sql
SUM(table_1.metric_1) OVER (
  PARTITION BY table_1.dimension_2, table_1.dimension_3
  ORDER BY table_1.dimension_2
)
```

Note how `table_1.dimension_1` is excluded from the PARTITION BY clause.

You cannot use EXCLUDING outside of metric definitions in semantic views. EXCLUDING is not supported in window function
calls in any other context.

</dd>
</dl>

</dd>
<dt><code className="samp">ORDER BY <em>exprs_using_dimensions_or_metrics</em>  [ ASC | DESC ] [ NULLS &#123; FIRST | LAST &#125; ] [, ... ]</code></dt>
<dd>

Orders rows within each partition. In the SQL expression:

- Any dimensions in the expression must be accessible from the same entity that defines the window function metric.
- Any metrics must belong to the same table where this metric is being defined.
- You cannot specify aggregates, window functions, or subqueries.

</dd>
<dt><code className="samp"><em>windowFrameClause</em></code></dt>
<dd>

See [](/sql-reference/functions-window-syntax).

</dd>
</dl>

For additional information about the parameters for window functions and examples, see
[](#label-semantic-views-querying-window).

<a id="label-create-semantic-view-verified-queries"></a>

## Parameters for verified queries

<dl>
<dt><code className="samp"><em>verified_query_name</em></code></dt>
<dd>

Specifies an identifier for the verified query.

</dd>
<dt><code className="samp">QUESTION '<em>question</em>'</code></dt>
<dd>

Specifies the natural language question that the query answers.

The question doesn't need to be a complete sentence or in the form of a question. However, the question should reflect something
that a user might ask.

</dd>
<dt><code className="samp">VERIFIED_AT <em>timestamp</em></code></dt>
<dd>

Specifies the date and time when the query was verified. For *:samp:`\{timestamp\}*, specify the number of seconds since the
beginning of the [Unix epoch](https://en.wikipedia.org/wiki/Unix_time) (midnight on January 1, 1970).

</dd>
<dt><code className="samp">ONBOARDING_QUESTION <em>boolean</em></code></dt>
<dd>

If TRUE, specifies that this question will be used as an
[onboarding question](/user-guide/snowflake-cortex/cortex-analyst/suggested-questions-feature) to help users get started.

Default: FALSE

</dd>
<dt><code className="samp">VERIFIED_BY '( <em>purpose</em> = <em>contact</em> )'</code></dt>
<dd>

Specifies the [contact](/user-guide/contacts-using) who verified the query. For <code className="samp"><em>purpose</em></code>, specify one of the
[predefined purposes](#label-contacts-associate-purposes).

</dd>
<dt><code className="samp">SQL '<em>verified_query</em>'</code></dt>
<dd>

Specifies the SQL query that returns the answer for the question.

</dd>
</dl>

## Access control requirements

A [role](#label-access-control-overview-roles) used to execute this operation must have the following
[privileges](#label-access-control-overview-privileges) at a minimum:

<div className="colwidths-auto">

| Privilege            | Object        | Notes                                                                          |
| -------------------- | ------------- | ------------------------------------------------------------------------------ |
| CREATE SEMANTIC VIEW | Schema        | Required to create a new semantic view.                                        |
| OWNERSHIP            | Semantic view | Required to execute a CREATE OR ALTER statement for an existing semantic view. |
| SELECT               | Table, view   | Required on any tables and/or views used in the semantic view definition.      |

</div>

Operating on an object in a schema requires at least one privilege on the parent database and at least one privilege on the parent schema.

For instructions on creating a custom role with a specified set of privileges, see [](#label-security-custom-role).

For general information about roles and privilege grants for performing SQL actions on
[securable objects](#label-access-control-securable-objects), see [Overview of Access Control](/user-guide/security-access-control-overview).

## Usage notes

- The semantic view must be valid and must follow the rules described in
  [](/user-guide/views-semantic/validation-rules).
- Regarding metadata:

  

  

Customers should ensure that no personal data (other than for a User object), sensitive data, export-controlled data, or other regulated data is entered as metadata when using the Snowflake service. For more information, see [Metadata fields in Snowflake](/sql-reference/metadata).

  

- 

CREATE OR REPLACE *&lt;object&gt;* statements are atomic. That is, when an object is replaced, the old object is deleted and the new object is created in a single transaction.

## Variant syntax

<a id="label-create-or-alter-semantic-view-syntax"></a>

### CREATE OR ALTER SEMANTIC VIEW

Creates a semantic view if it doesn't already exist, or alters an existing semantic view to match the definition in the statement.

The following modifications are supported:

- Adding, removing, or modifying tables, relationships, facts, dimensions, and metrics.
- Adding, overwriting, or removing the comment for the semantic view.
- Modifying the AI_SQL_GENERATION and AI_QUESTION_CATEGORIZATION instructions.
- Adding, removing, or modifying verified queries.

For more information, see [](#label-create-or-alter-semantic-view-usage-notes) and [](/sql-reference/sql/create-or-alter).

```sqlsyntax
CREATE OR ALTER SEMANTIC VIEW <name>
  TABLES ( logicalTable [ , ... ] )
  [ RELATIONSHIPS ( relationshipDef [ , ... ] ) ]
  [ FACTS ( factExpression [ , ... ] ) ]
  [ DIMENSIONS ( dimensionExpression [ , ... ] ) ]
  [ METRICS ( { metricExpression | windowFunctionMetricExpression } [ , ... ] ) ]
  [ COMMENT = '<comment_about_semantic_view>' ]
  [ MAX_STALENESS = <integer> ]
  [ AI_SQL_GENERATION '<instructions_for_sql_generation>' ]
  [ AI_QUESTION_CATEGORIZATION '<instructions_for_question_categorization>' ]
  [ AI_VERIFIED_QUERIES ( verifiedQuery [ , ... ] ) ]
```

For the definitions of `logicalTable`, `relationshipDef`, `factExpression`, `dimensionExpression`,
`metricExpression`, `windowFunctionMetricExpression`, and `verifiedQuery`, see the
[syntax](#label-create-semantic-view-syntax) for the CREATE SEMANTIC VIEW command.

<a id="label-create-or-alter-semantic-view-usage-notes"></a>

## CREATE OR ALTER SEMANTIC VIEW usage notes

- All [general usage notes](#label-create-or-alter-usage-notes) for the CREATE OR ALTER command apply.
- This command doesn't support adding or changing tags on the semantic view or on tables, facts, dimensions, or metrics within
  the semantic view. Any existing tags are preserved.

- If a previously set property (for example, COMMENT) is absent in the CREATE OR ALTER SEMANTIC VIEW statement, the property
  is unset.
- To execute a CREATE OR ALTER SEMANTIC VIEW statement for an existing semantic view, a role must have the OWNERSHIP privilege
  on the semantic view.

## Examples

See [](#label-semantic-views-create).