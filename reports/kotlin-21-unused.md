# Kotlin 2.0 (JVM 21) - Unused Dependencies Report

> **SSDLC Gate 1:** Attack Surface Reduction (Audit Only)

## Unused Declared Dependencies

| Scope / Configuration | Dependency Coordinate | Recommended Action |
| :--- | :--- | :--- |
| `implementation` | `ch.qos.logback:logback-core:1.2.3` | Remove unused dependency |
| `implementation` | `com.google.code.gson:gson:2.10.1` | Remove unused dependency |
| `implementation` | `com.fasterxml.jackson.core:jackson-databind:2.9.10` | Change to runtimeOnly |
