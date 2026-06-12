# Asset Manager Full Modernization Plan

**Project:** assets-manager-parent  
**Language:** Java 8 → Java 21  
**Frameworks:** Spring Boot, Spring AMQP, Spring Data JPA  
**Build Tool:** Maven  
**Assessment Report:** report-20260514153716  
**Created:** 2026-05-27

---

## Overview

This plan modernizes the Asset Manager application from its current Java 8 / Spring Boot 2.7 state to a cloud-native Azure-ready application. It covers Java runtime upgrades, cloud service migrations (messaging, storage, database), security credential management, and resolution of security vulnerabilities.

**Total tasks:** 11  
**Categories covered:** Java upgrade, Deprecated APIs, Messaging, Storage, Credentials, Region, Database, File System, Local Resources, CWE Security, CVE Security

---

## Tasks

### Task 001 — Upgrade Java Version

| Field | Value |
|---|---|
| Type | upgrade |
| Knowledge Base ID | `java-version-upgrade` |

**Issues addressed:**
- Legacy Java version (Java 8 detected)

**Description:**  
Upgrade from Java 8 to Java 21 LTS. Update build configuration, compiler settings, and resolve any compatibility issues introduced by the version upgrade.

**Success criteria:** Build passes · Unit tests pass

---

### Task 002 — Upgrade Deprecated APIs

| Field | Value |
|---|---|
| Type | upgrade |
| Knowledge Base ID | `deprecated-api-upgrade` |

**Issues addressed:**
- The java.annotation (Common Annotations) module has been removed from OpenJDK 11

**Description:**  
Update deprecated APIs including the `java.annotation` (Common Annotations) module which has been removed from OpenJDK 11. Replace `javax.annotation` imports and any other APIs deprecated or removed in newer Java versions.

**Success criteria:** Build passes · Unit tests pass

---

### Task 003 — Migrate from RabbitMQ(AMQP) to Azure Service Bus

| Field | Value |
|---|---|
| Type | transform |
| Knowledge Base ID | `amqp-rabbitmq-servicebus` |

**Issues addressed:**
- RabbitMQ connection string, username or password found in configuration file
- Spring RabbitMQ usage found in code
- Spring AMQP dependency found

**Description:**  
Replace Spring AMQP/RabbitMQ clients with Azure Service Bus SDK. Remove RabbitMQ connection strings, username, and password from configuration files. Use managed identity for authentication. Preserve manual acknowledgement semantics and retry/dead-letter queue behaviour.

**Success criteria:** Build passes · Unit tests pass

---

### Task 004 — Migrate from AWS S3 to Azure Blob Storage

| Field | Value |
|---|---|
| Type | transform |
| Knowledge Base ID | `s3-to-azure-blob-storage` |

**Issues addressed:**
- AWS S3 usage found

**Description:**  
Replace the AWS S3 SDK (`AwsS3Service`, `S3FileProcessingService`) with Azure Blob Storage SDK. Remove AWS credentials and region configuration. Use managed identity for authentication. Preserve existing `StorageService` and `FileProcessor` interface contracts.

**Success criteria:** Build passes · Unit tests pass

---

### Task 005 — Migrate from Plaintext Credentials to Azure Key Vault

| Field | Value |
|---|---|
| Type | transform |
| Knowledge Base ID | `plaintext-credential-to-azure-keyvault` |

**Issues addressed:**
- Password found in configuration file

**Description:**  
Remove all plaintext passwords from `application.properties` files. Store secrets in Azure Key Vault and reference them via managed identity. Covers database passwords, service credentials, and any other sensitive configuration values.

**Success criteria:** Build passes · Unit tests pass

---

### Task 006 — Migrate from AWS Region Configuration to Azure Region Configuration

| Field | Value |
|---|---|
| Type | transform |
| Knowledge Base ID | *(none)* |

**Issues addressed:**
- AWS region configuration

**Description:**  
Remove AWS region configuration properties and replace with appropriate Azure region configuration. Update any code or configuration that references AWS region identifiers.

**Success criteria:** Build passes · Unit tests pass

---

### Task 007 — Secure Azure Database for PostgreSQL with Managed Identity

| Field | Value |
|---|---|
| Type | transform |
| Knowledge Base ID | `mi-postgresql` |

**Issues addressed:**
- PostgreSQL database found

**Description:**  
Configure the application to connect to Azure Database for PostgreSQL using managed identity instead of password-based authentication. Update the PostgreSQL JDBC driver configuration and Spring Data JPA datasource settings.

**Success criteria:** Build passes · Unit tests pass

---

### Task 008 — Migrate to Azure Storage Account File Share Mounts

| Field | Value |
|---|---|
| Type | transform |
| Knowledge Base ID | `local-files-to-mounted-azure-storage` |

**Issues addressed:**
- File system - Java NIO

**Description:**  
Replace local file system access using Java NIO with Azure Storage Account File Share mounts. Update `LocalFileStorageService` and `LocalFileProcessingService` to use mounted Azure File Share paths.

**Success criteria:** Build passes · Unit tests pass

---

### Task 009 — Migrate the Local Resource to Azure

| Field | Value |
|---|---|
| Type | transform |
| Knowledge Base ID | *(none)* |

**Issues addressed:**
- Local JDBC Calls
- Localhost Usage

**Description:**  
Migrate local JDBC calls and localhost usage to Azure-hosted resources. Replace hardcoded localhost connection strings with environment-appropriate Azure service endpoints.

**Success criteria:** Build passes · Unit tests pass

---

### Task 010 — Scan and Resolve CWE Vulnerabilities

| Field | Value |
|---|---|
| Type | security |
| Knowledge Base ID | `scan-and-resolve-cwe-vulnerabilities` |

**Issues addressed:**
- CWE-665 · Improper Initialization
- CWE-682 · Incorrect Calculation
- CWE-772 · Missing Release of Resource after Effective Lifetime
- CWE-775 · Missing Release of File Descriptor or Handle after Effective Lifetime
- CWE-789 · Memory Allocation with Excessive Size Value
- CWE-259 · Use of Hard-coded Password
- CWE-778 · Insufficient Logging
- CWE-798 · Use of Hard-coded Credentials
- CWE-22 · Improper Limitation of a Pathname to a Restricted Directory (Path Traversal)
- CWE-23 · Relative Path Traversal
- CWE-36 · Absolute Path Traversal
- CWE-434 · Unrestricted Upload of File with Dangerous Type
- CWE-99 · Improper Control of Resource Identifiers (Resource Injection)

**Description:**  
Scan and resolve all identified CWE vulnerabilities across the codebase.

**Success criteria:** Build passes · Unit tests pass

---

### Task 011 — Resolve CVE Issues by Upgrading to Secure Versions

| Field | Value |
|---|---|
| Type | security |
| Knowledge Base ID | `scan-and-resolve-cve-vulnerabilities` |

**Issues addressed (selected):**
- CVE-2024-1597 · PostgreSQL JDBC SQL Injection
- CVE-2016-1000027 · Spring Framework unsafe deserialization
- CVE-2024-22243 / CVE-2024-22259 / CVE-2024-22262 · Spring Web Open Redirect / SSRF / URL parsing
- CVE-2024-38816 / CVE-2024-38819 · Spring Framework Path Traversal
- CVE-2023-6378 / CVE-2023-6481 · Logback serialization / DoS
- CVE-2024-34750 / CVE-2024-50379 / CVE-2024-56337 / CVE-2025-24813 and others · Apache Tomcat
- CVE-2026-40477 / CVE-2026-40478 / CVE-2026-41901 · Thymeleaf expression injection
- CVE-2022-25857 / CVE-2022-1471 · SnakeYAML deserialization / RCE
- CVE-2026-42583 and others · Netty resource exhaustion / request smuggling
- CVE-2026-0603 · Hibernate SQL Injection
- CVE-2025-52999 · Jackson Core StackOverflow
- CVE-2026-24400 · AssertJ XXE

**Description:**  
Resolve all identified high-severity CVEs by upgrading vulnerable dependencies. Affected libraries include Spring Boot DevTools, Spring Boot, Spring Framework, Spring Web, PostgreSQL JDBC driver (pgjdbc), Apache Tomcat, Thymeleaf, Netty, Logback, Hibernate, Jackson Core, SnakeYAML, and AssertJ.

**Success criteria:** Build passes · Unit tests pass

---

## Execution Order

The recommended execution order is:

```
001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010 → 011
```

- **001–002** (Java + API upgrades) must run first as they affect compilation across all subsequent tasks.
- **003–009** (cloud service migrations) can be sequenced in any order after the upgrade tasks.
- **010–011** (security) should run last to allow CVE dependency fixes to incorporate the upgraded library versions from earlier tasks.
