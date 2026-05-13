---
description: "Use when editing files under scripts/ (startapp / stopapp / deploy-to-azure / cleanup-azure-resources). Covers the .sh ↔ .cmd parity rule, absolute mvnw invocation, and PID/log conventions."
applyTo: "scripts/**"
---
# Workshop Scripts

The `scripts/` folder ships **paired** `.sh` (Linux/macOS/devcontainer) and `.cmd` (Windows) entry points. They drive the local end-to-end demo of the asset-manager workshop and the Azure deployment helpers referenced from [README.md](../../README.md).

## Hard rules

1. **Always edit `.sh` and `.cmd` together.** The two flows must remain functionally identical. The Windows `.cmd` scripts were hand-written (Copilot historically struggled with batch quoting — see [PROMPTS.md](../../PROMPTS.md)); do not regenerate them from `.sh` without manually verifying quoting, `%~dp0` paths, and `start /B cmd /c` semantics.
2. **Invoke `mvnw` with an absolute path.** Child modules cd into `web/` or `worker/` before running the wrapper, so a bare `mvnw` is not on `PATH`. Use `"$PROJECT_ROOT/mvnw"` (sh) or `"%PROJECT_ROOT%\mvnw.cmd"` (cmd) — the leading absolute prefix is mandatory.
3. **Respect the PID/log convention.** Web and worker each pass `-Dspring.pid.file=$PROJECT_ROOT/pids/<module>.pid` to Spring Boot via `ApplicationPidFileWriter`. `stopapp.{sh,cmd}` reads those PID files to kill processes — do not switch to `pkill` / `taskkill /FI` filters that scan for `java.exe`.
4. **Use `dev` profile for local runs.** Both apps must launch with `-Dspring-boot.run.profiles=dev` so they pick up `LocalFileStorageService` / `LocalFileProcessingService`. Don't add an extra prod-style profile here — the workshop's migration tasks introduce that.

## Local infra (startapp / stopapp)

[`startapp.sh`](../../scripts/startapp.sh) and [`startapp.cmd`](../../scripts/startapp.cmd):
- Start two Docker containers named **exactly** `assets-postgres` (image `postgres:latest`, port 5432, db `assets_manager`, user/pwd `postgres`/`postgres`) and `assets-rabbitmq` (image `rabbitmq:management`, ports 5672 + 15672).
- Sleep ~10s for the services to be ready, then launch web + worker in the background, redirecting stdout/stderr to `logs/web.log` and `logs/worker.log`.
- Container names are referenced by [`stopapp.sh`](../../scripts/stopapp.sh) / [`stopapp.cmd`](../../scripts/stopapp.cmd) with `docker stop … && docker rm …`. If you rename them, update both stop scripts.

## Azure helpers (deploy / cleanup)

[`deploy-to-azure.sh`](../../scripts/deploy-to-azure.sh) / `.cmd` and [`cleanup-azure-resources.sh`](../../scripts/cleanup-azure-resources.sh) / `.cmd` exist as **starting-state stubs** — the workshop's Deployment Tasks (the GitHub Copilot app modernization "Provision Infrastructure and Deploy to Azure" task) generate the actual deployment under `.azure/` on a separate branch. Don't preemptively fill these in; the reference is `workshop/deployment-expected`.

## Devcontainer interplay

The [devcontainer](../../.devcontainer/devcontainer.json) `postCreateCommand` runs `chmod +x scripts/*.sh` so the scripts work after a Windows-host clone (which strips the executable bit). When adding a new `.sh` script, no extra chmod is needed — just keep them under `scripts/`.
