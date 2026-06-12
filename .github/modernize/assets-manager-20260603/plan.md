# Asset Manager Azure Modernization Plan

**Project:** assets-manager-parent
**Language:** Java 8 → Java 21
**Framework:** Spring Boot 2.7.18
**Assessment Report:** report-20260603121457
**Created:** 2026-06-03

---

## Overview

This plan modernizes the Asset Manager application for Azure deployment. It covers Java version upgrade, deprecated API remediation, cloud service migrations (messaging, storage, database), credential management hardening, and security vulnerability fixes.

**Total Tasks:** 12
**Estimated Categories:** Upgrade (2), Transform (6), Security (4)

---

## Task Execution Order

### Phase 1: Platform Upgrade

| # | Task | Type | KB Reference |
|---|------|------|-------------|
| 001 | Upgrade Java Version (8 → 21) | upgrade | java-version-upgrade |
| 002 | Upgrade Deprecated APIs | upgrade | deprecated-api-upgrade |

### Phase 2: Cloud Service Migrations

| # | Task | Type | KB Reference |
|---|------|------|-------------|
| 003 | Migrate RabbitMQ(AMQP) → Azure Service Bus | transform | amqp-rabbitmq-servicebus |
| 004 | Migrate AWS S3 → Azure Blob Storage | transform | s3-to-azure-blob-storage |
| 005 | Migrate Plaintext Credentials → Azure Key Vault | transform | plaintext-credential-to-azure-keyvault |
| 006 | Migrate AWS Region Config → Azure Region Config | transform | — |
| 007 | Secure PostgreSQL with Managed Identity | transform | mi-postgresql |
| 008 | Remove Hardcoded Credentials | security | — |
| 009 | Migrate Local Resources → Azure | transform | — |
| 010 | Migrate Local File System → Azure Storage File Share | transform | local-files-to-mounted-azure-storage |

### Phase 3: Security Hardening

| # | Task | Type | KB Reference |
|---|------|------|-------------|
| 011 | Scan and resolve CWE vulnerabilities | security | scan-and-resolve-cwe-vulnerabilities |
| 012 | Scan and resolve CVE vulnerabilities | security | scan-and-resolve-cve-vulnerabilities |

---

## Task Details

### 001 — Upgrade Java Version

- **Type:** upgrade
- **Description:** Upgrade from Java 8 to Java 21 LTS
- **Requirements:** Update pom.xml `java.version` property, compiler settings, and resolve compatibility issues
- **Success Criteria:** Build passes, unit tests pass

### 002 — Upgrade Deprecated APIs

- **Type:** upgrade
- **Description:** Replace deprecated/removed APIs (javax.annotation module removed in OpenJDK 11)
- **Requirements:** Replace javax.annotation imports with jakarta.annotation or add explicit dependencies
- **Success Criteria:** Build passes, unit tests pass

### 003 — Migrate RabbitMQ to Azure Service Bus

- **Type:** transform
- **Description:** Replace Spring AMQP/RabbitMQ with Azure Service Bus SDK
- **Requirements:** Remove RabbitMQ connection strings and credentials; use managed identity; preserve manual ack semantics and retry/DLQ behavior
- **Affected Files:** web/worker RabbitConfig, AbstractFileProcessingService, BackupMessageProcessor, application.properties
- **Success Criteria:** Build passes, unit tests pass

### 004 — Migrate AWS S3 to Azure Blob Storage

- **Type:** transform
- **Description:** Replace AWS S3 SDK with Azure Blob Storage SDK
- **Requirements:** Remove AWS credentials/region config; use managed identity; preserve StorageService and FileProcessor interfaces
- **Affected Files:** AwsS3Config, AwsS3Service, S3FileProcessingService, application.properties
- **Success Criteria:** Build passes, unit tests pass

### 005 — Migrate Plaintext Credentials to Azure Key Vault

- **Type:** transform
- **Description:** Remove plaintext passwords from configuration files, use Azure Key Vault
- **Requirements:** Store secrets in Key Vault; reference via managed identity
- **Affected Files:** web/worker application.properties
- **Success Criteria:** Build passes, unit tests pass

### 006 — Migrate AWS Region Configuration

- **Type:** transform
- **Description:** Remove AWS region configuration, replace with Azure region config
- **Requirements:** Remove cloud.aws.region.static, cloud.aws.stack.auto properties; remove AwsS3Config classes
- **Affected Files:** AwsS3Config (web/worker), application.properties (web/worker)
- **Success Criteria:** Build passes, unit tests pass

### 007 — Secure PostgreSQL with Managed Identity

- **Type:** transform
- **Description:** Connect to Azure Database for PostgreSQL using managed identity
- **Requirements:** Update JDBC driver config and Spring Data JPA datasource settings; remove password-based auth
- **Affected Files:** web/worker application.properties
- **Success Criteria:** Build passes, unit tests pass

### 008 — Remove Hardcoded Credentials

- **Type:** security
- **Description:** Remove default/well-known passwords from configuration files
- **Requirements:** Replace with externalized configuration (env vars or Key Vault references)
- **Affected Files:** web/worker application.properties
- **Success Criteria:** Build passes, unit tests pass

### 009 — Migrate Local Resources to Azure

- **Type:** transform
- **Description:** Replace localhost JDBC/RabbitMQ connections with Azure service endpoints
- **Requirements:** Remove hardcoded localhost:5432 and localhost:5672 references; use Azure service endpoints
- **Affected Files:** web/worker application.properties
- **Success Criteria:** Build passes, unit tests pass

### 010 — Migrate Local File System to Azure Storage File Share

- **Type:** transform
- **Description:** Replace Java NIO local file operations with Azure Storage File Share mounts
- **Requirements:** Update LocalFileStorageService and LocalFileProcessingService to use mounted file share paths
- **Affected Files:** LocalFileStorageService, LocalFileProcessingService, AbstractFileProcessingService
- **Success Criteria:** Build passes, unit tests pass

### 011 — Scan and Resolve CWE Vulnerabilities

- **Type:** security
- **Description:** Scan and fix CWE security issues
- **CWE IDs:** CWE-665, CWE-681, CWE-772, CWE-775, CWE-789, CWE-1057, CWE-259, CWE-732, CWE-778, CWE-798, CWE-22, CWE-23, CWE-36, CWE-434, CWE-99
- **Success Criteria:** Build passes, unit tests pass

### 012 — Scan and Resolve CVE Vulnerabilities

- **Type:** security
- **Description:** Upgrade vulnerable dependencies to secure versions
- **Requirements:** Scan for high-severity CVEs in Spring Boot, Spring Framework, PostgreSQL JDBC, Tomcat, Thymeleaf, Netty, Logback, Hibernate, Jackson, SnakeYAML
- **Success Criteria:** Build passes, unit tests pass

---

## Notes

- Tasks in Phase 1 should be executed first as they establish the Java 21 baseline
- Phase 2 tasks (003–010) can be executed in any order after Phase 1 completes
- Phase 3 security tasks should be run last to validate the final state
- Tasks 005, 007, 008 have overlapping scope (credentials); execute 008 first, then 005 and 007
- Task 006 (AWS region config) will be largely resolved by task 004 (S3 migration) but captures remaining region references
