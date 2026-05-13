---
name: diff-against-workshop-branch
description: 'Compare the current asset-manager workspace against one of the workshop reference branches (workshop/java-upgrade, workshop/expected, workshop/deployment-expected) so users can self-check migration progress. Use when the user asks "how far am I", "what should I have changed", "what does the expected state look like", or wants a checkpoint diff during the GitHub Copilot app modernization workshop.'
argument-hint: "Branch name (java-upgrade | expected | deployment-expected) and optional path filter"
---

# Diff Against Workshop Branch

Compare the user's current working tree to one of the canonical workshop branches and surface the meaningful migration deltas.

## When to use

- The user is partway through the [workshop](../../README.md) and wants to know how their code compares to the reference.
- The user got stuck on a migration step and asks what the expected outcome looks like.
- The user wants a focused diff (e.g., "just the pom files", "just the RabbitMQ config") against a checkpoint.

Do **not** use this skill to merge or cherry-pick the reference branch into the user's branch — its only purpose is read-only inspection.

## Reference branches

| Argument | Reference branch | What it represents |
|---|---|---|
| `java-upgrade` | `workshop/java-upgrade` | After "Upgrade Runtime & Frameworks" (Java 8 → 21, Spring Boot 2.7 → 3.x). |
| `expected` | `workshop/expected` | After all migration tasks (PostgreSQL, Blob, Service Bus, health endpoints). |
| `deployment-expected` | `workshop/deployment-expected` | After containerization + deployment (includes `.azure/`, Dockerfiles). |

All three live in [Azure-Samples/java-migration-copilot-samples](https://github.com/Azure-Samples/java-migration-copilot-samples). The local repo may not have them fetched yet — the helper script handles that.

## Procedure

1. **Parse arguments.** Required first argument: the branch nickname (`java-upgrade`, `expected`, `deployment-expected`). Optional second argument: a path filter (e.g. `web/`, `pom.xml`, `worker/src/main/java/**`). If the first argument is missing or not in the table above, ask the user — do not guess.

2. **Run the helper script.** Execute [scripts/diff.sh](./scripts/diff.sh) with the resolved branch and optional path filter:
   ```bash
   ./.github/skills/diff-against-workshop-branch/scripts/diff.sh <branch-nickname> [path-filter]
   ```
   The script:
   - Adds the upstream remote `workshop-upstream` (idempotent) pointing at `https://github.com/Azure-Samples/java-migration-copilot-samples.git` if not already present.
   - Fetches just the requested branch (shallow).
   - Runs `git diff --stat` followed by `git diff` between the current `HEAD` and `workshop-upstream/workshop/<branch>` for the optional path filter.
   - Skips any files under `.azure/`, `logs/`, `pids/`, and `target/` to keep output focused on source changes.

3. **Summarize the diff for the user.** Group changes by category:
   - **Build** (`pom.xml`, `mvnw*`, `application.properties`)
   - **Code** (java/kt source under `web/`, `worker/`)
   - **Infra/Deploy** (`Dockerfile*`, `.azure/`, `scripts/deploy-to-azure.*`)
   - **Docs / templates**

   For each category, list the top files changed and one-sentence summary of the migration intent (e.g. "RabbitMQ → Service Bus: removed `spring-boot-starter-amqp`, added `spring-cloud-azure-starter-servicebus-jms`"). Link each file with markdown links using the workspace-relative path so the user can open them in VS Code.

4. **Offer next actions.** Never apply changes automatically. Suggest options:
   - "Open file X side-by-side with the workshop version"
   - "Run the migration task that produces this delta via the **GitHub Copilot app modernization** extension (point to the matching README section)"
   - "Re-run with a narrower path filter"

## Constraints

- **Read-only.** Do not check out, merge, rebase onto, or cherry-pick from the reference branch. The script only fetches into a separate remote.
- **Don't pollute the user's git config.** The remote is named `workshop-upstream`; if it already exists with a different URL, surface that and ask the user before changing it.
- **Stay focused on source diffs.** Skip `target/`, `logs/`, `pids/`, IDE state files; these are workshop side effects, not migration changes.
