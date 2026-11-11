# Asset Manager Assessment Migration Plan

- Source: [report-20261111082414](../assessment/reports/report-20261111082414/report.json)
- Created: 2026-11-11
- Status: proposed; no migration, security remediation, provisioning, or deployment executed.
- Target: Linux, Azure Container Apps, Java 25 LTS (`openjdk25`), as specified by the assessment.
- Modules: [web](../../../web/) and [worker](../../../worker/).
- Task manifest: [tasks.json](tasks.json); 11 tasks covering the five selected categories and all 19 selected CWEs.

## Scope and safeguards

The assessment records six cloud/Java issue types and 22 incidents. Its security
section separately supplies findings for all 19 requested CWEs. These are source
assessment findings, not proof of deployed exploitation. Revalidate each before
implementation; overlapping CWE labels should share a root-cause fix and tests.

Only the selected work is included. Do not copy the older Java 21 plans, merge
reference branches, replace AWS S3 with Azure Blob Storage, replace RabbitMQ with
Service Bus, or add a general CVE remediation campaign. Retain the current S3
backend. Address localhost RabbitMQ by moving compatible RabbitMQ hosting to
Azure, not by changing messaging protocols.

Preserve the storage interfaces, profile-selected implementations, matching
`storageType` contracts, thumbnail suffix-before-extension naming, and manual
acknowledgment / `basicNack(requeue=false)` behavior. The starting state does not
wire the intended dead-letter retry loop; do not claim that it already exists.
Changes required by a confirmed selected CWE may intentionally tighten upload,
path, credential, or error behavior and must be documented.

Preserve unrelated worktree edits. Use the root Maven wrapper and inherited
plugin versions. Read the script-specific instructions before editing scripts;
keep shell and Windows batch behavior aligned.

## Execution gates

1. Approve this plan before executing tasks. The automatic Java upgrade planner
   could not open because its configured model was unavailable; this saved plan
   has not been registered or confirmed through that workflow.
2. Before Task 001, resolve the supported Spring Boot, Maven, Lombok, and Java 25
   compatibility matrix. Spring Boot 2.7.18 cannot simply be assumed compatible.
   Propose any necessary framework upgrade and obtain approval before expanding
   scope. Java 25 is the report target, not a silently substituted Java 21 target.
3. Before Azure configuration/provisioning, confirm subscription, resource group,
   region, existing resources, PostgreSQL and RabbitMQ hosting, network/TLS
   requirements, and authentication. Do not invent endpoints or credentials.
4. Choose the Azure Files runtime profile explicitly. The current default uses
   S3 and `dev` uses local files. Both cloud apps must activate the intended
   mounted-file implementations with compatible message routing; mounting a
   directory alone does not switch the backend.
5. Credential remediation is explicitly selected, but no particular secret-store
   migration is selected. Externalize secrets through environment/Container Apps
   secret references; do not add Key Vault or managed identity architecture
   without approval. Document externally required credential rotation.

## Tasks and dependencies

### 001 - Upgrade Java Version

- Category: Java Version Upgrade; KB: `java-version-upgrade`.
- Update the parent Java target from 8 to 25, compiler/tooling configuration, and
  only dependencies necessary for the approved compatibility path.
- Capture a baseline build/test result first. Keep child plugin versions inherited.
- Acceptance: both executable JARs build and existing tests pass under JDK 25;
  document baseline failures separately from regressions.

### 002 - Upgrade Deprecated APIs

- Category: Deprecated APIs; KB: `deprecated-api-upgrade`; depends on 001.
- Resolve the two Common Annotations incidents in the local storage classes.
  Supply a compatible annotation API or migrate namespaces only as required by
  the approved framework version. Do not blindly replace all `javax` imports.
- Acceptance: annotations resolve and lifecycle behavior is preserved on JDK 25;
  no removed-module runtime dependency remains.

### 003 - Migrate Local Resources to Azure

- Category: Local Resource Access (Localhost); depends on 002.
- Cover both Local JDBC Calls and Localhost Usage in both application property
  files: Azure Database for PostgreSQL and Azure-hosted compatible RabbitMQ.
- Externalize cloud endpoints, authentication, and TLS configuration. Preserve
  usable local development configuration without hard-coded credential defaults.
  Plan database schema/data transfer and verification before any cutover.
- Acceptance: both apps reach the configured cloud database/broker without
  application-container localhost dependencies; data and queue contracts remain
  compatible. Actual cloud connectivity is blocked until resources are supplied.

### 004 - Migrate Local Files to Azure Files Mounts

- Category: File System Management; KB: `local-files-to-mounted-azure-storage`;
  depends on 002.
- Review all 14 Java NIO incidents, distinguishing durable shared assets from
  disposable worker scratch files. Keep Java NIO for mounted filesystem access;
  do not replace it wholesale with an unrelated storage SDK.
- Configure the same Azure Files share and absolute asset root in both apps.
  Preserve profile/backend selection explicitly. Keep temporary processing files
  isolated, bounded, and cleaned up rather than sharing a predictable scratch
  filename across workers.
- Acceptance: web uploads are visible to worker, thumbnails survive app restart
  and replica replacement, and existing image naming/read/delete behavior holds.
  Verify permissions and cross-replica publication semantics on the actual mount.

### 005 - Containerize Java Application for Container Readiness

- Category: Containerization; KB: `containerization-copilot-agent`;
  depends on 003, 004, and 006-011.
- Add one Dockerfile per executable module and an appropriate build-context
  ignore file, using root-reactor build inputs and approved JDK/JRE 25 images.
- Run as non-root; never bake credentials into images. Expose only web's HTTP
  port; worker is headless. Configure writable bounded scratch space, shared
  asset mounts, resource limits, graceful shutdown, and appropriate health checks.
- Acceptance: both images build and start with external configuration; web is
  responsive, worker consumes jobs, and Azure Container Apps mount/secret
  configuration is documented. Provisioning/deployment requires separate approval.

### 006 - Resolve Obsolete APIs (CWE-477)

- Depends on 002. Revalidate `WebMvcConfig` adapter usage and replace obsolete
  adapters with supported interfaces while preserving interception and logging.
- Acceptance: obsolete adapter use is removed; MVC routes and interceptors retain
  their intended behavior.

### 007 - Resolve Image Calculation and Resource Safety

- CWEs: CWE-681, CWE-682, CWE-772, CWE-775, CWE-789; depends on 002.
- Fix the shared fractional-dimension truncation root cause in thumbnail sizing:
  retain aspect ratio, avoid upscaling, and ensure positive bounded dimensions.
- Bound decoded dimensions/pixel count with overflow-safe arithmetic before
  raster allocation; compressed upload size alone is not a decoded-memory limit.
  Select and document explicit limits before implementation.
- Ensure streams, image writers, graphics resources, and temporary files are
  released on success and all failure paths without preventing queue settlement.
- Acceptance: 1x601 and 601x1 images yield nonzero dimensions with longest side at
  most 600; small images are not enlarged. Test exact and over-limit inputs,
  malformed images, arithmetic overflow, and injected encoding/I/O failure.

### 008 - Resolve Synchronization Gaps

- CWEs: CWE-662, CWE-820; depends on 003 and 004.
- Revalidate the S3 publish-before-metadata-save race. Ensure metadata is committed
  before a worker can consume its job; method-call ordering alone is insufficient
  if a transaction has not committed. Keep messaging changes minimal.
- Prevent partially published shared-file reads and conflicting same-key writes.
  Validate the chosen strategy across replicas and Azure Files; a JVM-only lock
  does not synchronize multiple apps. Do not assume atomic moves are supported
  on the mounted filesystem or silently fall back to unsafe publication.
- Acceptance: deterministic fast-consumer and overlapping read/write tests pass;
  thumbnail metadata is retained and readers never see incomplete content.

### 009 - Resolve Credentials and Logging Findings

- CWEs: CWE-259, CWE-778, CWE-798; depends on 003.
- Remove confirmed hard-coded authentication values from application configuration
  and dependent startup helpers; use required external secret inputs and explicit
  missing-configuration errors. Do not reproduce credential values in output.
- Log deletion failures and security-relevant rejection outcomes with useful
  context, excluding secrets and unsafe raw input; retain user-visible errors.
- Acceptance: credential scan shows no selected embedded authentication values;
  startup fails clearly without required secrets; tests verify failure logging
  without credential disclosure. Existing exposed credentials require rotation
  by their owner; deleting literals does not revoke them.

### 010 - Resolve File/Path and Upload Findings

- CWEs: CWE-22, CWE-23, CWE-36, CWE-434, CWE-99; depends on 004.
- Validate untrusted upload names, HTTP object keys, and worker message keys
  before read/write/delete or thumbnail derivation. Enforce canonical root
  containment, including absolute paths, traversal, separators, and symlinks.
- Apply server-side allowed image format, signature/decode, and size validation
  before persistence/queue publication; do not trust browser hints or MIME alone.
  Reuse decoded-image limits from 007 rather than duplicating inconsistent policy.
- Acceptance: valid images round-trip; adversarial names/keys, symlink escapes,
  unsupported/disguised types, malformed images, and oversized inputs are rejected
  without out-of-root writes or queued invalid work. Temporary test directories
  must be isolated from real assets.

### 011 - Resolve Command and Argument Injection

- CWEs: CWE-77, CWE-78, CWE-88; independent of Java/cloud task execution.
- Revalidate the cleanup batch script's resource-group argument flow. Validate
  external resource identifiers and preserve argument boundaries; avoid dynamic
  shell re-evaluation. Keep matching shell/batch behavior and deletion safeguards.
- Acceptance: safe stubbed CLI tests reject metacharacter and injected-option
  input, preserve legitimate identifiers, and invoke no unintended command.
  Never test against real resource deletion. Run Windows-specific tests on
  Windows; Linux source inspection alone cannot establish batch runtime safety.

## Validation and completion

After each implementation unit, run the smallest applicable existing tests and
add focused regressions for changed behavior. At integration completion:

1. Under JDK 25, run `./mvnw -pl web,worker -am clean package`.
2. Re-scan all 19 selected CWEs, recording each as fixed, not reproducible with
   evidence, or blocked. Require zero unresolved confirmed selected findings;
   never treat a skipped scan as passing.
3. Re-run the selected cloud-readiness/Java checks and reconcile all 22 original
   incidents. Distinguish legitimate mounted NIO and local-dev endpoints from
   unresolved cloud runtime dependencies using explicit evidence.
4. Build and smoke-test both containers. Verify upload, listing, retrieval,
   asynchronous thumbnail generation, restart persistence, and deletion, including
   secret/TLS/mount configuration and queue failure settlement.
5. Run multi-replica Azure Files tests and Windows injection regressions in their
   actual target environments; report unavailable environments as blocked.
6. Update directly affected setup/configuration documentation and symmetric
   startup scripts. Record intentional behavior changes, remaining risks,
   rollback steps, and verification evidence. Retain the original report.

Rollback must retain database backups and original asset copies, permit restoring
the previous container revisions/configuration, and avoid deleting shared files
or cloud resources. No broad cleanup or deployment command is part of plan creation.
