---
description: "Verify the asset-manager runs end-to-end locally on this machine using the dev profile (Postgres + RabbitMQ in Docker, web + worker via mvnw)."
argument-hint: "Optional: image path to upload for the smoke test"
agent: "agent"
---
# Verify Local Run

Run a self-contained smoke test of the asset-manager **starting-state** app. This validates the developer environment (devcontainer or local) before the user begins the [workshop](../../README.md). It does not modify source files.

## Steps

1. **Pre-flight**
   - Confirm `docker info` succeeds (Docker socket reachable from this terminal — inside the devcontainer this proves `docker-outside-of-docker` is wired up correctly).
   - Confirm `./mvnw -v` reports the JDK declared in the root [`pom.xml`](../../pom.xml) (`<java.version>8</java.version>`). If it reports a different major version, stop and ask the user which JDK to use rather than guessing.
   - Confirm ports 8080, 5432, 5672, and 15672 are free.

2. **Launch infra + apps**
   - Run [`scripts/startapp.sh`](../../scripts/startapp.sh) from the repo root.
   - Tail `logs/web.log` and `logs/worker.log` until both report `Started AssetsManagerApplication`/`Started WorkerApplication`. Time out after 3 minutes and surface the last 50 lines of either log if startup hasn't completed.

3. **Smoke test**
   - Upload a small image (use `$ARGUMENTS` if provided, otherwise `curl -o /tmp/cat.jpg https://placecats.com/300/200`) via:
     ```bash
     curl -i -F "file=@/tmp/cat.jpg" http://localhost:8080/s3/upload
     ```
   - GET `http://localhost:8080/s3` and confirm an HTML response listing the uploaded key.
   - Wait up to 30 seconds, then re-list and confirm a sibling `*_thumbnail.jpg` appears (proves the RabbitMQ round-trip + `LocalFileProcessingService` thumbnail generation worked).
   - In the **worker log**, confirm a line like `Successfully processed image: <key>`. In the **web log**, no stack traces.

4. **Tear down**
   - Run [`scripts/stopapp.sh`](../../scripts/stopapp.sh). Confirm the `assets-postgres` and `assets-rabbitmq` containers are gone (`docker ps -a | grep assets-`).

## Rules

- **Do not edit source files.** This is a verification flow, not a fix flow. If a step fails, surface the failing log line and stop — let the user decide whether to debug.
- **Use the `dev` profile only.** Don't override storage backend, RabbitMQ host, or DB credentials; this proves the out-of-the-box workshop bootstrap works.
- **Respect the workshop branch.** This is the "before" state — do not migrate to Azure services as part of verification.

## Output

End with a concise table:

| Check | Result |
|---|---|
| Docker reachable | ✅ / ❌ + diagnostic |
| Build (`./mvnw … package`) | ✅ / ❌ |
| Web + worker started | ✅ / ❌ |
| Upload → list → thumbnail | ✅ / ❌ |
| Teardown clean | ✅ / ❌ |
