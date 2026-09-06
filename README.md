# SSDLC Local POC - Audit & Visibility Gates

A local Proof of Concept (POC) demonstrating three Secure Software Development Life Cycle (SSDLC) validation checks directly on a developer workstation across **Java (11, 17, 21)**, **Kotlin 2.0 (JVM 11, 17, 21)**, and **Node.js (18, 20, 22)**.

> **Platform support:** All scripts run on **Windows (Git Bash)** and **macOS (bash/zsh)** with no additional configuration.

---

## 1. Core Principles

- **"Report First / Audit Only":**
  - Validation checks never break local developer workflow or fail builds (`exit 0` is guaranteed).
- **100% Free & Open-Source Tooling:**
  - Zero SaaS dependencies, zero commercial licensing.
- **Pure Markdown Output:**
  - Reports are generated strictly as Markdown (`.md`) files inside the `./reports/` directory.
- **Per-Project Isolation:**
  - Each service has its own dedicated check script and isolated markdown reports for Gates 1, 2, and 3.
- **Console Executive Summary:**
  - Consolidated status table displayed directly in the terminal upon completion.
- **Cross-Platform:**
  - A shared `scripts/common.sh` utility handles OS detection and tool resolution transparently.

---

## 2. Directory Structure

```text
ssdlc-poc/
├── java-11-maven/               # Java 11, Apache Maven
├── java-17-maven/               # Java 17, Apache Maven
├── java-21-maven/               # Java 21, Apache Maven
├── kotlin-11-gradle/            # Kotlin 2.0, Gradle 8.5 (JVM 11)
├── kotlin-17-gradle/            # Kotlin 2.0, Gradle 8.5 (JVM 17)
├── kotlin-21-gradle/            # Kotlin 2.0, Gradle 8.5 (JVM 21)
├── nodejs-18-npm/               # Node.js 18 LTS baseline, npm
├── nodejs-20-npm/               # Node.js 20 LTS baseline, npm
├── nodejs-22-npm/               # Node.js 22 LTS baseline, npm
├── scripts/
│   ├── common.sh                # Shared cross-platform utilities (OS detection, dynamic resolution, lockfile/wrapper lifecycle)
│   ├── markdown.tpl             # Go template for Trivy to generate clean Markdown tables with clickable links
│   ├── init-versions.gradle     # Dynamic Gradle init-script for zero-impact outdated dependency scanning
│   ├── gradle-wrapper.jar       # Compatibility wrapper jar for external repos missing wrapper binary
│   ├── check-java-11.sh         # All 3 gates for java-11-maven
│   ├── check-java-17.sh         # All 3 gates for java-17-maven
│   ├── check-java-21.sh         # All 3 gates for java-21-maven
│   ├── check-kotlin-11.sh       # All 3 gates for kotlin-11-gradle
│   ├── check-kotlin-17.sh       # All 3 gates for kotlin-17-gradle
│   ├── check-kotlin-21.sh       # All 3 gates for kotlin-21-gradle
│   ├── check-node-18.sh         # All 3 gates for nodejs-18-npm
│   ├── check-node-20.sh         # All 3 gates for nodejs-20-npm
│   ├── check-node-22.sh         # All 3 gates for nodejs-22-npm
│   └── summarize-reports.sh     # Executive Summary banner generator
├── reports/                     # Auto-created Markdown reports (27 files)
│   ├── <project>-unused.md      # Gate 1: Unused dependencies
│   ├── <project>-outdated.md    # Gate 2: EOL & Outdated dependencies (Java/Kotlin)
│   ├── <project>-health.md      # Gate 2: Deprecated & Outdated dependencies (Node)
│   └── <project>-cve.md         # Gate 3: High & Critical CVEs (Trivy)
├── run-checks.sh                # Main non-blocking orchestration script
└── README.md                    # Setup & user guide
```

---

## 3. SSDLC Validation Gates

| Gate | Focus | Tooling | Deliverable |
| :--- | :--- | :--- | :--- |
| **Gate 1** | Unused Dependencies (Attack Surface Reduction) | Maven Dependency Plugin, AutonomousApps Dependency Analysis, Depcheck | `reports/<project>-unused.md` |
| **Gate 2** | Lifecycle, EOL, Deprecated & Outdated Checks | Versions Maven Plugin, Ben-Manes Versions Plugin, npm outdated & view | `reports/<project>-outdated.md` or `reports/<project>-health.md` |
| **Gate 3** | Direct Visible CVE Scanning | Aqua Security Trivy CLI (Filesystem mode) | `reports/<project>-cve.md` |

> **Actionable Developer Guidance:** Every report includes an explicit **Recommended Action** column specifying whether to remove unused dependencies, upgrade to a newer version (with breaking change warnings for major versions), or migrate away from deprecated libraries.

---

## 4. Libraries & Tools Per Project Type

---

### Java Projects (`java-11-maven`, `java-17-maven`, `java-21-maven`)

#### Runtime — Must be pre-installed

| Tool | Min Version | Purpose | Verify |
| :--- | :--- | :--- | :--- |
| **Java JDK** | 11 / 17 / 21 | Compile & run source | `java -version` |
| **Apache Maven** | 3.9+ | Build tool & plugin runner | `mvn -version` |
| **Aqua Security Trivy** | Any recent | Gate 3 CVE scan | `trivy --version` |

> **Note:** A single JDK 21 install is sufficient — Maven compiles each project against the target release flag (11/17/21) automatically.

#### Maven Plugins — Auto-downloaded by Maven on first run

| Plugin | Version | Gate |
| :--- | :--- | :--- |
| `org.apache.maven.plugins:maven-dependency-plugin` | `3.6.1` | Gate 1 |
| `org.codehaus.mojo:versions-maven-plugin` | `2.16.2` | Gate 2 |

#### Manual Commands — Run individually from the repo root

**Gate 1 — Unused dependency detection**
```bash
# Compile first (required for byte-code analysis), then check unused deps
mvn compile dependency:analyze-only \
  -f java-11-maven/pom.xml \
  -DfailOnWarning=false
```
> Replace `java-11-maven` with `java-17-maven` or `java-21-maven` as needed.

**Gate 2 — Outdated / newer versions available**
```bash
mvn versions:display-dependency-updates \
  -f java-11-maven/pom.xml \
  -DprocessDependencyManagement=false
```

**Gate 3 — CVE scan (Trivy)**
```bash
trivy fs --severity HIGH,CRITICAL --exit-code 0 --format table java-11-maven
```

#### Test Fixture Dependencies (`pom.xml`)

| Dependency | Version | Role |
| :--- | :--- | :--- |
| `org.slf4j:slf4j-api` | `2.0.12` | **Active** — used in `App.java` |
| `org.apache.commons:commons-lang3` | `3.14.0` | **Unused** — Gate 1 trigger |
| `com.google.guava:guava` | `30.0-jre` | **Outdated** — Gate 2 trigger |
| `ch.qos.logback:logback-core` | `1.2.3` | **CVE** — Gate 3 trigger (`CVE-2023-6378 HIGH`) |

---

### Kotlin Projects (`kotlin-11-gradle`, `kotlin-17-gradle`, `kotlin-21-gradle`)

#### Runtime — Must be pre-installed

| Tool | Min Version | Purpose | Verify |
| :--- | :--- | :--- | :--- |
| **Java JDK** | 21 | Hosts Gradle & Kotlin compiler | `java -version` |
| **Aqua Security Trivy** | Any recent | Gate 3 CVE scan | `trivy --version` |

> **Note:** Maven is **not** required. The `gradlew` wrapper is bundled in each project and auto-downloads Gradle 8.5 on first run (requires internet on first use only).

#### Gradle Plugins & Zero-Impact External Project Architecture

| Plugin / Tool | Version / Script | Gate | Role & Behavior |
| :--- | :--- | :--- | :--- |
| `org.jetbrains.kotlin.jvm` | `2.0.21` | Compilation | Language compiler |
| `com.autonomousapps.dependency-analysis` | `1.31.0` | Gate 1 | Unused declared dependency analysis (`buildHealth`). Automatically injected on the fly if missing, and original build file is restored immediately (`project untouched`). |
| `com.github.ben-manes.versions` | `scripts/init-versions.gradle` | Gate 2 | Injected dynamically on the fly via `--init-script`. External projects **never** need to modify their `build.gradle.kts`. |
| `Aqua Security Trivy` | `trivy` | Gate 3 | Direct CVE scanning. If `gradle.lockfile` is missing, the script auto-generates a temporary lockfile and deletes it post-scan (`project untouched`). |

#### Manual Commands — Run from inside the project directory

```bash
cd kotlin-11-gradle     # or kotlin-17-gradle / kotlin-21-gradle
```

**Gate 1 — Unused dependency detection**
```bash
./gradlew buildHealth --no-daemon
# Report written to: build/reports/dependency-analysis/build-health-report.txt
```

**Gate 2 — Outdated / newer versions available (via dynamic init-script)**
```bash
./gradlew --init-script ../scripts/init-versions.gradle dependencyUpdates --no-daemon
# Report written to: build/dependencyUpdates/report.txt
```

**Gate 3 — CVE scan (Trivy)** *(run from repo root)*
```bash
trivy fs --severity HIGH,CRITICAL --exit-code 0 --format table kotlin-11-gradle
```

> **Zero-Impact Trivy Lockfile:** Trivy requires a `gradle.lockfile` for Gradle Kotlin DSL (`.kts`) projects. When running check scripts against external projects lacking a lockfile, the script automatically parses declared dependencies into a temporary `gradle.lockfile` and removes it immediately upon scan completion.

#### Test Fixture Dependencies (`build.gradle.kts`)

| Dependency | Version | Role |
| :--- | :--- | :--- |
| `org.slf4j:slf4j-api` | `2.0.12` | **Active** — used in `App.kt` |
| `com.google.code.gson:gson` | `2.10.1` | **Unused** — Gate 1 trigger |
| `com.fasterxml.jackson.core:jackson-databind` | `2.9.10` | **Outdated** — Gate 2 trigger |
| `ch.qos.logback:logback-core` | `1.2.3` | **CVE** — Gate 3 trigger (44 HIGH/CRITICAL CVEs) |

---

### Node.js Projects (`nodejs-18-npm`, `nodejs-20-npm`, `nodejs-22-npm`)

#### Runtime — Must be pre-installed

| Tool | Min Version | Purpose | Verify |
| :--- | :--- | :--- | :--- |
| **Node.js** | 18 / 20 / 22 | JavaScript runtime | `node --version` |
| **npm** | Bundled with Node.js | Package manager | `npm --version` |
| **npx** | Bundled with Node.js 5.2+ | Runs tools without global install | `npx --version` |
| **Aqua Security Trivy** | Any recent | Gate 3 CVE scan | `trivy --version` |

> **Note:** Any Node.js LTS (18, 20, or 22) works for all three projects. The `engines` field in `package.json` is informational only.

#### Manual Commands — Run from inside the project directory

```bash
cd nodejs-18-npm     # or nodejs-20-npm / nodejs-22-npm
```

**Setup — Install dependencies (required once)**
```bash
npm install --prefer-offline --no-audit
```

**Gate 1 — Unused dependency detection (`depcheck`)**
```bash
# depcheck is listed as a devDependency; npx runs it from node_modules or downloads it
npx depcheck --json
# Human-readable output (no --json):
npx depcheck
```

**Gate 2 — Outdated packages**
```bash
# List all outdated packages with current / wanted / latest versions:
npm outdated

# Check if a specific package is deprecated on the npm registry:
npm view lodash deprecated
npm view request deprecated
```

**Gate 3 — CVE scan (Trivy)** *(run from repo root)*
```bash
trivy fs --severity HIGH,CRITICAL --exit-code 0 --format table nodejs-18-npm
```

> Trivy reads `package-lock.json` to resolve the full dependency tree for CVE matching.

#### npm Packages — Gate 1

| Package | Version | Invocation |
| :--- | :--- | :--- |
| `depcheck` | `^1.4.7` (devDependency) | `npx --yes depcheck --json` |

#### Test Fixture Dependencies (`package.json`)

| Package | Version | Role |
| :--- | :--- | :--- |
| `dotenv` | `^16.4.5` | **Active** — used in `src/index.js` |
| `ms` | `^2.1.3` | **Unused** — Gate 1 trigger |
| `lodash` | `3.10.1` | **Outdated + CVE** — Gate 2 & Gate 3 trigger |
| `request` | `2.88.2` | **Deprecated** — Gate 2 trigger |

---

## 5. Prerequisites & Setup

### A. Windows (Git Bash)

| Requirement | Notes |
| :--- | :--- |
| **Java JDK 21** | Must be on system `PATH` |
| **Apache Maven 3.9+** | Must be on system `PATH` |
| **Node.js LTS (18+) & npm** | Must be on system `PATH` |
| **Git Bash** | Required to run `.sh` scripts — PowerShell is not used |
| **Aqua Security Trivy** | Required for Gate 3 — see [Installing Trivy](#6-installing-trivy-gate-3) below |

### B. macOS

| Requirement | Notes |
| :--- | :--- |
| **Java JDK 21** | Install via [Adoptium](https://adoptium.net/) or `brew install --cask temurin` |
| **Apache Maven 3.9+** | `brew install maven` |
| **Node.js LTS (18+) & npm** | `brew install node` or via [nvm](https://github.com/nvm-sh/nvm) |
| **bash 3.2+** | Pre-installed on macOS; scripts use `#!/usr/bin/env bash` |
| **Aqua Security Trivy** | Required for Gate 3 — see [Installing Trivy](#6-installing-trivy-gate-3) below |

---

## 6. Installing Trivy (Gate 3)

Aqua Security Trivy is a single-binary vulnerability scanner used for Gate 3 CVE scanning.

### Windows — Winget (Recommended)
```cmd
winget install AquaSecurity.Trivy
```
Restart your terminal after installation, then verify:
```bash
trivy --version
```

### Windows — Manual Download
1. Go to [Aqua Security Trivy Releases](https://github.com/aquasecurity/trivy/releases).
2. Download `trivy_<version>_windows-64bit.zip`.
3. Extract and add the directory containing `trivy.exe` to your `PATH`.

### macOS — Homebrew (Recommended)
```bash
brew install aquasecurity/trivy/trivy
```

### macOS — Manual Download
1. Go to [Aqua Security Trivy Releases](https://github.com/aquasecurity/trivy/releases).
2. Download `trivy_<version>_macOS-64bit.tar.gz` (or `ARM64` for Apple Silicon).
3. Extract and move `trivy` to `/usr/local/bin/`.

> *Note:* If Trivy is not installed, Gate 3 automatically outputs a platform-appropriate installation advisory in `reports/<project>-cve.md` without breaking script execution.

---

## 7. How to Run

### Run Full Orchestration (All Projects & Gates)

**Windows — Git Bash:**
```bash
bash run-checks.sh
```

**macOS — Terminal:**
```bash
bash run-checks.sh
# or simply
./run-checks.sh
```

### Run Individual Project Audit
Each project check script is self-contained and accepts optional arguments:
`bash scripts/check-<type>.sh [TARGET_DIR] [REPORTS_DIR]`

```bash
# Audit a single Java service in the monorepo:
bash scripts/check-java-17.sh

# Audit a single Kotlin service:
bash scripts/check-kotlin-11.sh

# Audit a single Node.js service:
bash scripts/check-node-22.sh
```

### Run on Any External Project

You can run these check scripts against **any external repository or project** on your workstation without modifying their build files:

#### Java Projects (Maven)
```bash
# Point to external project path:
bash scripts/check-java-11.sh /path/to/external-java-service

# Or cd into the project and run:
cd /path/to/external-java-service
bash /path/to/SSDLC_POC/scripts/check-java-11.sh
# -> Automatically detects pom.xml in current directory!
# -> Reports written to: /path/to/external-java-service/reports/
```

> **Zero POM Changes Needed:** The scripts invoke fully-qualified Maven plugin coordinates (`maven-dependency-plugin:3.6.1` and `versions-maven-plugin:2.16.2`) on the fly. External projects do **not** need these plugins declared in their `pom.xml`.

#### Kotlin / Android Projects (Gradle)
```bash
# Point to external Kotlin project:
bash scripts/check-kotlin-17.sh /path/to/external-kotlin-service

# Or cd into the external project and run:
cd /path/to/external-kotlin-service
bash /path/to/SSDLC_POC/scripts/check-kotlin-17.sh
```
> **Zero Build File Changes Needed:**
> - **Gate 1 (Unused):** Auto-injects `dependency-analysis` into `build.gradle.kts` temporarily if missing, runs `buildHealth`, and immediately restores the original file (`project untouched`).
> - **Gate 2 (Outdated):** Injects `ben-manes.versions` on the fly using `--init-script scripts/init-versions.gradle` without modifying `build.gradle.kts`.
> - **Gate 3 (CVEs):** Auto-generates a temporary `gradle.lockfile` from declared dependencies so Trivy can scan, then immediately deletes it upon completion (`project untouched`).
> - **Wrapper Compatibility:** Automatically supplies a temporary `gradle-wrapper.jar` if omitted in the external repository and cleans it up post-run.

#### Node.js / Frontend Projects (npm)
```bash
# Point to external Node.js project:
bash scripts/check-node-18.sh /path/to/external-node-service
```
> Automatically runs `npm install` if `node_modules/` is not present, then runs `depcheck`, `npm outdated`, and Trivy CVE scanning.

#### Custom Output Directory (Any language)
```bash
# Syntax: bash scripts/check-<type>.sh [TARGET_DIR] [REPORTS_DIR]
bash scripts/check-java-17.sh /path/to/my-service ./custom-audit-reports
```

---

## 8. Generated Reports & Actionable Schemas

After running the checks, all reports are populated under `./reports/`:

- **Java Reports:**
  - `reports/java-11-unused.md`, `reports/java-11-outdated.md`, `reports/java-11-cve.md`
  - `reports/java-17-unused.md`, `reports/java-17-outdated.md`, `reports/java-17-cve.md`
  - `reports/java-21-unused.md`, `reports/java-21-outdated.md`, `reports/java-21-cve.md`
- **Kotlin Reports:**
  - `reports/kotlin-11-unused.md`, `reports/kotlin-11-outdated.md`, `reports/kotlin-11-cve.md`
  - `reports/kotlin-17-unused.md`, `reports/kotlin-17-outdated.md`, `reports/kotlin-17-cve.md`
  - `reports/kotlin-21-unused.md`, `reports/kotlin-21-outdated.md`, `reports/kotlin-21-cve.md`
- **Node.js Reports:**
  - `reports/node-18-unused.md`, `reports/node-18-health.md`, `reports/node-18-cve.md`
  - `reports/node-20-unused.md`, `reports/node-20-health.md`, `reports/node-20-cve.md`
  - `reports/node-22-unused.md`, `reports/node-22-health.md`, `reports/node-22-cve.md`

---

### Report Schemas & Actionable Guidance

Each report delivers structured, actionable tables designed to instruct developers directly:

#### Gate 1: Unused Dependencies Report (`*-unused.md`)
Identifies declared dependencies that have no references in source code to minimize the attack surface.

| Ecosystem | Columns | Actionable Guidance |
| :--- | :--- | :--- |
| **Node.js** | `\| Scope \| Package Name \| Declared Version \| Installed Version \| Recommended Action \|` | `Remove unused dependency` |
| **Java** | `\| Dependency Coordinate \| Scope \| Recommended Action \|` | `Remove unused dependency` |
| **Kotlin** | `\| Dependency Coordinate \| Scope \| Recommended Action \|` | `Remove unused dependency` |

#### Gate 2: Library Health & Outdated Report (`*-health.md` / `*-outdated.md`)
Inspects lifecycle, deprecations, and available updates:

- **Node.js Schema (`*-health.md`):**
  ```text
  | Package | Scope | Declared | Installed | Wanted | Latest | Update Status | Deprecation Status | Recommended Action |
  ```
- **Java & Kotlin Schema (`*-outdated.md`):**
  ```text
  | Dependency Coordinate | Current Version | Available Update | Status | Recommended Action |
  ```

**Recommended Action Decision Logic:**
- **Deprecated / EOL Package:** `⚠️ Migrate to an active alternative (deprecated)`
- **Major Update Available:** `Upgrade package.json to ^<latest> (test for breaking changes)`
- **Minor / Patch Update Available:** `Upgrade package.json to ^<latest>` or `Upgrade to <latest>`
- **Baseline Alignment:** `Optional: bump package.json to ^<installed> to reflect installed baseline` *(when declared range has older lower bound than what was resolved and installed)*
- **Up to Date:** `No action needed (up to date)`

#### Gate 3: Direct Visible CVE Scan (`*-cve.md`)
Extracts and filters HIGH and CRITICAL CVE findings:

```text
| Severity | CVE ID | Package | Installed Version | Fixed Version | Title |
```
- Includes direct clickable links to Aqua Vulnerability Database (AVD) / NVD.
- Highlights fixed versions for fast remediation.


---

## 9. Cross-Platform Architecture

All 9 check scripts source `scripts/common.sh` at startup. This shared utility handles:

| Function | Windows resolution | macOS resolution |
| :--- | :--- | :--- |
| `resolve_target_dir` | Dynamically resolves target project path and reports folder (supports external repos) | Same |
| `resolve_trivy` | `trivy` in PATH → `trivy.exe` → WinGet packages glob | `trivy` in PATH → `/usr/local/bin/trivy` → `/opt/homebrew/bin/trivy` |
| `resolve_mvn` | `mvn` → `mvn.cmd` fallback | `mvn` |
| `resolve_node` | `node` → `node.exe` fallback | `node` |
| `resolve_npm` | `npm` → `npm.cmd` fallback | `npm` |
| `resolve_npx` | `npx` → `npx.cmd` fallback | `npx` |
| `ensure_gradle_lockfile` | Auto-generates temporary `gradle.lockfile` for Trivy if missing | Same |
| `cleanup_gradle_lockfile` | Removes temporary lockfile, preserving user files | Same |
| `ensure_gradle_wrapper` | Supplies temporary `gradle-wrapper.jar` if omitted in target | Same |
| `cleanup_gradle_wrapper` | Removes temporary wrapper jar post-run | Same |
| `cleanup_all_gradle_temp`| Traps and removes all temporary Gradle artifacts | Same |
| `trivy_install_hint` | Shows `winget install` instruction | Shows `brew install` instruction |

OS detection uses `uname -s`: `Darwin` = macOS, `MINGW*`/`MSYS*`/`CYGWIN*` = Windows Git Bash.
