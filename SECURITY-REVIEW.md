# Security assessment

Date: 2026-11-11

## Scope and method

Assessment followed
[the security assessment plan](.github/modernize/assessment/engines/security/security-assessment-plan.md),
using the application modernization CWE and CVE assessment tools.
All 59 configured CWE rules were assessed: 19 FOUND and 40 NOT_FOUND.
The 19 matches are grouped into 12 findings below to avoid counting overlapping
CWE classifications as separate defects.

This repository is intentionally the outdated starting state of a migration
workshop. No application changes or dependency upgrades were made. Credential
values are omitted. Findings are based on static inspection, not exploitation;
NOT_FOUND does not establish that a weakness is absent.

## Dependency assessment limitation

`./mvnw dependency:list -DoutputAbsoluteArtifactId=true` failed before Maven
started (exit 127: wrapper could not execute). As required by the plan, the
assessment fell back to static dependency declarations without looking up managed
versions.

Of 18 direct declarations, 16 had no locally explicit version and were excluded.
The remaining two declarations referenced one unique coordinate:
`software.amazon.awssdk:s3:2.25.13`, at [web/pom.xml](web/pom.xml#L33) and
[worker/pom.xml](worker/pom.xml#L29). The CVE tool returned no known vulnerabilities
for this coordinate and persisted an empty result array.

**Dependency coverage is incomplete.** Unversioned declarations and all transitive
dependencies remain unassessed. The empty CVE report is not a clean bill of health.
A complete follow-up requires successful dependency resolution and another CVE
assessment.

## Findings

Confidence scores express confidence in the static finding, not deployed
exploitability. Severity is conditional on the prerequisites described below.

| # | Severity | File | Lines | Vulnerability | Confidence |
|---|----------|------|-------|---------------|------------|
| 1 | HIGH | [LocalFileStorageService.java](web/src/main/java/com/microsoft/migration/assets/service/LocalFileStorageService.java#L89) | 89-95 | Absolute upload filenames escape the storage directory | 9/10 |
| 2 | HIGH | [LocalFileProcessingService.java](worker/src/main/java/com/microsoft/migration/assets/worker/service/LocalFileProcessingService.java#L38) | 38-49 | Queue-supplied paths escape the storage directory | 9/10 |
| 3 | HIGH | [LocalFileStorageService.java](web/src/main/java/com/microsoft/migration/assets/service/LocalFileStorageService.java#L84) | 84-105 | Unrestricted file types compound arbitrary-file writes | 9/10 |
| 4 | HIGH | [AbstractFileProcessingService.java](worker/src/main/java/com/microsoft/migration/assets/worker/service/AbstractFileProcessingService.java#L99) | 99-105 | Unbounded image decoding can exhaust worker memory | 9/10 |
| 5 | HIGH | [application.properties](web/src/main/resources/application.properties#L17) | 17 | Hard-coded RabbitMQ password | 9/10 |
| 6 | MEDIUM | [cleanup-azure-resources.cmd](scripts/cleanup-azure-resources.cmd#L14) | 14, 42, 50 | Command and argument injection through script arguments | 8/10 |
| 7 | MEDIUM | [AbstractFileProcessingService.java](worker/src/main/java/com/microsoft/migration/assets/worker/service/AbstractFileProcessingService.java#L141) | 141-153 | JPEG exception paths bypass resource cleanup | 9/10 |
| 8 | MEDIUM | [AwsS3Service.java](web/src/main/java/com/microsoft/migration/assets/service/AwsS3Service.java#L85) | 85-96 | Publish-before-persist race loses thumbnail metadata updates | 9/10 |
| 9 | MEDIUM | [LocalFileStorageService.java](web/src/main/java/com/microsoft/migration/assets/service/LocalFileStorageService.java#L89) | 89-114 | Concurrent replacement and reads can expose incomplete files | 8/10 |
| 10 | MEDIUM | [S3Controller.java](web/src/main/java/com/microsoft/migration/assets/controller/S3Controller.java#L97) | 97-104 | Caught deletion failures omit failure details from audit logs | 9/10 |
| 11 | LOW | [AbstractFileProcessingService.java](worker/src/main/java/com/microsoft/migration/assets/worker/service/AbstractFileProcessingService.java#L112) | 112-119 | Extreme aspect ratios produce zero-sized thumbnails | 9/10 |
| 12 | LOW | [WebMvcConfig.java](web/src/main/java/com/microsoft/migration/assets/config/WebMvcConfig.java#L17) | 17, 49 | Deprecated APIs; maintenance observation only | 9/10 |

### 1. Absolute upload path traversal

CWE-22, CWE-36, CWE-99. In the `dev` profile, the original multipart filename
passes through `cleanPath` and a check for `..`. Absolute paths pass this check;
resolving them against the storage root does not confine them to that root.
`Files.copy` with `REPLACE_EXISTING` can overwrite an outside target when its
parent exists and the process has permission. The upload entry point is
[S3Controller.uploadObject](web/src/main/java/com/microsoft/migration/assets/controller/S3Controller.java#L41).
This does not assert equivalent local-path behavior in the S3 backend.

### 2. Queue-driven relative path traversal

CWE-23. In the `dev` profile, the worker resolves an unvalidated message key
against its storage root. A relative traversal key can read an outside image and
write its derived thumbnail outside storage. Exploitation requires permission to
publish a matching local-storage message and suitable worker filesystem access.
External broker exposure is not assumed.

### 3. Unrestricted upload types

CWE-434. Upload handling rejects empty files but does not restrict extensions,
media types, or signatures before persistence. Combined with finding 1, arbitrary
file types can be placed outside storage wherever the process can write.
Asynchronous decoding failure does not reject or remove the original upload.
Automatic script execution or an executable webroot was not established.
This finding shares the arbitrary-write impact of finding 1.

### 4. Excessive image allocation

CWE-789. Uploaded images reach `ImageIO.read` before decoded dimensions are
checked. A compressed image can require a large raster allocation and exhaust
worker heap. The 600-pixel thumbnail limit is applied after full decoding and
does not bound this initial allocation. Both storage backends queue processing.

### 5. Hard-coded broker credential

CWE-259, CWE-798. The application configuration embeds an outbound RabbitMQ
password rather than obtaining it externally. This is intentional workshop
starting-state configuration. The value is redacted; deployed validity or
compromise was not established.

### 6. Windows cleanup script injection

CWE-77, CWE-78, CWE-88. The resource-group argument is assigned without quoting
and expanded into shell commands without argument quoting. Attacker-controlled
metacharacters or additional options can alter shell execution or CLI arguments
under the invoking user's privileges. This requires an operator or upstream
caller to supply an attacker-controlled value; no remote application entry point
was established. Windows execution was not performed because a Windows command
interpreter was unavailable.

### 7. JPEG resource leak

CWE-772, CWE-775. JPEG writer disposal and output-stream closure occur after
encoding without exception-safe cleanup. An encoding exception bypasses both
releases. The outer cleanup deletes paths but does not close these resources.
Repeated failures can retain resources; exhaustion was not runtime-reproduced.

### 8. Metadata publication race

CWE-662. The S3 upload path publishes the processing message before saving image
metadata. A fast worker can query before the record exists, skip its update, and
acknowledge success. The later insert does not trigger a retry. The worker's
conditional update is in
[S3FileProcessingService](worker/src/main/java/com/microsoft/migration/assets/worker/service/S3FileProcessingService.java#L55).
This timing-dependent integrity defect was not runtime-reproduced.

### 9. Unsynchronized local replacement

CWE-820. In the `dev` profile, uploads replace a live shared path while downloads
can stream the same path. There is no per-file synchronization or atomic
publication. Overlapping reads and writes can expose incomplete content, and
same-name uploads can interfere. This was not runtime-reproduced; S3 partial-write
behavior is not assumed.

### 10. Missing deletion-failure audit details

CWE-778. The controller catches deletion exceptions and reports them only through
a user-facing flash attribute. The logging interceptor receives no propagated
exception and records a generic completion rather than failure details:
[WebMvcConfig.afterCompletion](web/src/main/java/com/microsoft/migration/assets/config/WebMvcConfig.java#L64).

### 11. Zero-sized thumbnail calculation

CWE-681, CWE-682. Integer truncation can turn a positive scaled dimension into
zero. The calculation for a valid 1-by-601 image produces a 0-by-600 target;
`BufferedImage` rejects that size and processing fails. The dimension calculation
was checked locally. This is a processing-availability defect, not evidence of
native memory corruption.

### 12. Deprecated configuration APIs

CWE-477. `WebMvcConfigurerAdapter` and `HandlerInterceptorAdapter` are deprecated,
and warnings are suppressed. This is a maintenance observation, not an
independently exploitable vulnerability. No opportunistic framework upgrade is
recommended as part of this assessment-only task.

## Persisted results and verification

- [CVE tool result](.github/modernize/assessment/engines/security/cve_assessment_result.json):
  valid JSON, empty array, subject to the coverage limitation above.
- [CWE checklists](.github/modernize/assessment/engines/security/cweChecklist):
  six category files, all 59 statuses FOUND or NOT_FOUND, with structured evidence.
- Category counts: code quality 6/16 FOUND; concurrency 2/6; credentials 3/5;
  file/path security 4/5; injection 4/12; memory safety 0/15.
- No application remediation, destructive tests, or runtime exploit attempts
  were performed. Unrelated existing worktree changes were left untouched.
