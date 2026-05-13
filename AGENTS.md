# Agent Instructions — Asset Manager

This repo is the **starting state** of a Microsoft workshop that teaches users to migrate a Java app to Azure using the [GitHub Copilot app modernization](https://marketplace.visualstudio.com/items?itemName=vscjava.migrate-java-to-azure) extension. The full workshop walkthrough lives in [README.md](README.md); the prompts originally used to author the sample are in [PROMPTS.md](PROMPTS.md).

## ⚠️ Critical context before editing

- **This codebase is intentionally outdated** (Java 8, Spring Boot 2.7.18, AWS S3, RabbitMQ, password-based auth). It is the "before" snapshot students migrate *from*. **Do not** opportunistically upgrade Java, Spring Boot, swap S3 → Azure Blob, RabbitMQ → Service Bus, etc. unless the user explicitly requests it.
- The post-migration reference states live on separate branches: `workshop/java-upgrade`, `workshop/expected`, `workshop/deployment-expected`. Do not try to merge those into `main`.
- The empty top-level `asset-manager/` directory is vestigial; the real modules are [web/](web/) and [worker/](worker/).

## Architecture

Multi-module Maven build rooted at [pom.xml](pom.xml) with two Spring Boot apps:

- **[web/](web/)** — Thymeleaf UI (`S3Controller`, templates in [web/src/main/resources/templates/](web/src/main/resources/templates/)) that uploads images, persists metadata to PostgreSQL via Spring Data JPA, and publishes an `ImageProcessingMessage` to RabbitMQ.
- **[worker/](worker/)** — Headless consumer that downloads the original, generates a thumbnail (pure-Java `ImageIO`, max 600px, aspect-preserving), and uploads `<name>_thumbnail.<ext>` back to the same storage.

Key pattern — **storage backend is selected by Spring profile, not by config**:

| Profile | Web impl | Worker impl |
|---|---|---|
| default (prod) | `AwsS3Service` | `S3FileProcessingService` |
| `dev` | `LocalFileStorageService` | `LocalFileProcessingService` |

Both modules share a `storageType` string (`"s3"` or `"local"`) inside `ImageProcessingMessage`. Each worker impl checks the field in [`AbstractFileProcessingService.processImage`](worker/src/main/java/com/microsoft/migration/assets/worker/service/AbstractFileProcessingService.java) and acks (without doing work) when the message is not for its backend — so both impls can coexist on the queue. When adding a new backend, follow this same pattern: add a profile-gated `@Service`, set a unique `storageType`, and let the abstract listener filter.

RabbitMQ topology lives in both [`web/.../RabbitConfig`](web/src/main/java/com/microsoft/migration/assets/config/RabbitConfig.java) and [`worker/.../RabbitConfig`](worker/src/main/java/com/microsoft/migration/assets/worker/config/RabbitConfig.java). Both declare the same durable `image-processing` queue and use `AcknowledgeMode.MANUAL`. The listener uses `basicNack(requeue=false)` on failure expecting a dead-letter → `image-processing.retry` (TTL 1 min) → main queue retry loop — **but the DLX/retry-queue bindings are not actually wired in the starting-state code** (see the README architecture diagram for the intended target). This is one of the things students wire up during migration; preserve the `basicNack(requeue=false)` contract and the manual ack mode when editing.

## Build, run, stop

Use the **Maven wrapper at the repo root** ([mvnw](mvnw) / [mvnw.cmd](mvnw.cmd)) — child modules invoke it via absolute path, so don't add per-module wrappers.

```bash
./mvnw -pl web,worker -am clean package    # build both modules
./mvnw -pl worker test                     # run worker tests
```

Local end-to-end run (spins up Postgres + RabbitMQ in Docker, launches both apps with `-Dspring-boot.run.profiles=dev`, writes PIDs to `pids/`, logs to `logs/`):

```bash
scripts/startapp.sh        # scripts/startapp.cmd on Windows
scripts/stopapp.sh         # reads pids/*.pid to kill processes
```

Default ports: web at `http://localhost:8080`, RabbitMQ mgmt at `http://localhost:15672` (guest/guest). The Windows `.cmd` scripts were hand-written (Copilot struggled with batch quoting — see [PROMPTS.md](PROMPTS.md)); keep `.sh` and `.cmd` flows symmetric when editing.

## Conventions

- **Lombok everywhere** — `@RequiredArgsConstructor`, `@Slf4j`, `@Data`. Don't replace with hand-written boilerplate.
- Configuration in [`application.properties`](web/src/main/resources/application.properties) uses **plaintext credentials** by design (workshop starting point). Don't introduce Key Vault / managed identity here.
- Storage abstraction is the `StorageService` interface (web) and `FileProcessor` interface (worker). Always add new behavior through these interfaces, not by branching on profile inside controllers.
- Image keys: thumbnails are derived by `getThumbnailKey()` — preserve the `_thumbnail` suffix-before-extension convention; downstream code (and `BackupMessageProcessor`) depends on it.
- The Spring Boot parent in the root [pom.xml](pom.xml) supplies all plugin versions. **Don't** add explicit versions to `spring-boot-maven-plugin` in child poms (a previous attempt is documented in [PROMPTS.md](PROMPTS.md)).

## Dev environment

[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) is the recommended setup for running this workshop. It is **multi-architecture** (amd64 + arm64) and **cross-host** (Windows + Docker Desktop/WSL2, macOS Intel and Apple Silicon, Linux) — every layer (base image, Java/Azure CLI/azd/docker-outside-of-docker/kubectl/github-cli features) ships both arm64 and amd64 manifests, and the dev container engine picks the right one for the host. One constraint from `docker-outside-of-docker`: the container and host must share the same chip architecture (no x86-on-arm emulation); the multi-arch base image satisfies this automatically.

It provides:

- **JDK 8 (Temurin)** via the `java` feature — default `JAVA_HOME` in the shell, matches the starting state's `<java.version>8</java.version>`.
- **JDK 21 (Microsoft OpenJDK)** pre-installed at `/usr/lib/jvm/msopenjdk-current` — used after the workshop's Java upgrade step. Both runtimes are registered in `java.configuration.runtimes` so the Java extension auto-selects per project.
- **Docker** via `docker-outside-of-docker` (re-uses the host socket) for `scripts/startapp.sh` and the Containerize Applications step.
- **Azure CLI** (with `containerapp`, `rdbms-connect`, `serviceconnector-passwordless` extensions), **azd**, **kubectl/helm**, **gh** — covers both the Container Apps and AKS deployment paths in the README.
- Pre-installed VS Code extensions: `vscjava.migrate-java-to-azure` (the workshop driver), GitHub Copilot + Chat, the Java extension pack, Spring Boot tooling, and the Azure/container extensions.
- `chat.extensionTools.enabled: true` set as a workspace setting (required by the workshop prereqs).
- Forwarded ports: 8080 (web), 15672 (RabbitMQ mgmt), 5432 (Postgres), 5672 (AMQP).

When editing outside the workshop's Java-upgrade step, build with `./mvnw` from the repo root — it will use the default `JAVA_HOME` (JDK 8) which matches the parent pom. To switch the shell to JDK 21 manually: `sdk use java <21-version>`.
