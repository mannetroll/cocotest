# Snowflake Performance Optimization

Use this skill with GitHub Copilot CLI to profile and optimize Snowflake SQL and Scala jobs. It covers DAG splitting, partitioning and clustering, FINAL table design, CTAS writes, and a measured optimization loop that preserves correctness. The instructions are in [SKILL.md](SKILL.md), with additional strategies in [references/](references/).

## Install in a job repository

Put the skill under `.github/skills/snowflake-performance-optimization/` in the repository containing the job. This is a supported project skill location for [Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills).

From that repository's root, run the following in Bash or Zsh. Set `skill_source` to the directory containing this README and `SKILL.md`; the example uses the existing Codex installation.

```bash
skill_source="$HOME/.codex/skills/snowflake-performance-optimization"
skill_target=".github/skills/snowflake-performance-optimization"
mkdir -p "$skill_target/references"
cp "$skill_source/SKILL.md" "$skill_source/README.md" "$skill_target/"
cp -R "$skill_source/references/." "$skill_target/references/"
```

If using a downloaded copy, replace the first line with its path, for example `skill_source="/path/to/snowflake-performance-optimization"`.

The result is:

```text
your-job-repo/
└── .github/
    └── skills/
        └── snowflake-performance-optimization/
            ├── README.md
            ├── SKILL.md
            └── references/
                ├── dag-and-partitioning.md
                ├── final-tables-and-ctas.md
                ├── github-strategies.md
                ├── measurement-and-records.md
                ├── scala-jobs.md
                └── strategy-catalog.md
```

Commit this directory to share the skill with teammates. Keep all six reference files with `SKILL.md`. The original `Scala Performance Optimization.md` and Codex's `agents/openai.yaml` are unnecessary for Copilot.

## Start Copilot CLI and verify discovery

With [Copilot CLI installed and signed in](https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/overview), start it from the job repository's root:

```bash
copilot
```

Inside the interactive Copilot session, enter these commands individually:

```text
/skills reload
/skills list
/skills info snowflake-performance-optimization
```

Check that the reported location is your repository's `.github/skills/snowflake-performance-optimization/`. Reloading picks up skills added during an existing session. See GitHub's [CLI skill commands](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills#skills-commands-in-the-cli).

## Use the skill

Enter a prompt inside Copilot CLI. For a review:

```text
/snowflake-performance-optimization Review this Scala Snowflake job. Identify its execution framework, map the DAG and final writes, and rank optimization opportunities. Do not modify code or launch Snowflake workloads yet.
```

For an optimization campaign, replace the placeholders with the job's actual details:

```text
/snowflake-performance-optimization Optimize <job or entrypoint>. Use <correctness gate command> and <benchmark command> with <fixed input snapshot>. Run isolated experiments on <development warehouse> within <time or credit budget>. Keep verified improvements, revert regressions, and record the baseline and experiment results.
```

To continue an interrupted campaign:

```text
/snowflake-performance-optimization Resume this job's optimization campaign from CURRENT_BASELINE.md, OPTIMIZATION_LOG.md, and OPTIMIZATION_HANDOFF.md if present. Check any recorded active queries before starting another run.
```

Copilot can also select the skill automatically for matching requests. Explicit `/snowflake-performance-optimization` invocation makes your intent clear. [CLI invocation reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#skills-reference).

## Provide the job's execution context

Keep build, correctness-gate, and benchmark commands in the repository's normal documentation or instructions. Supply the input snapshot, target warehouse and output schema, and experiment budget when running a campaign. Execution requires the repository's working Snowflake connection and credentials; installing the skill supplies the workflow, not that connection.

For Scala jobs, the skill distinguishes native Snowpark Scala, Spark with the Snowflake connector, Scala/JDBC, and in-database Scala handlers. It follows the repository's actual build and validation workflow. See the [Scala playbook](references/scala-jobs.md).

The [measurement guide](references/measurement-and-records.md) describes baseline, experiment-log, and handoff records. Existing repository conventions take precedence over the example filenames above.

## Documentation links

The workflow and playbooks are bundled with the skill. External links provide sources and help verify relevant technical details; you do not need to open every link to use it. README links are optional setup help.

If a documentation site is unavailable, Copilot can continue using repository evidence and the local playbooks. Any candidate that depends on an unresolved correctness or compatibility detail remains unverified. See [source-use guidance](SKILL.md#use-sources-when-needed).

## Optional: install for your user account

For local use across repositories, run the same copy commands with `skill_target="$HOME/.copilot/skills/snowflake-performance-optimization"`. Then start Copilot in the job repository. This personal copy is local to your machine; commit a project copy when the repository should carry the skill. [Supported locations](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills#creating-and-adding-a-skill).

## Troubleshooting

- **Skill missing:** check the exact path and uppercase `SKILL.md` filename, then run `/skills reload` and `/skills list`. Use `/skills` to check whether it is enabled.
- **Unexpected copy loaded:** inspect `/skills info snowflake-performance-optimization`. Project skills take precedence over personal skills with the same name. [Discovery order](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#skill-locations).
- **References cannot be opened:** copy the complete `references/` directory alongside `SKILL.md`, preserving the directory structure.
- **Commands unavailable:** update Copilot CLI and check its current [command reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference).

CLI instructions checked against GitHub documentation on 2026-09-08.
