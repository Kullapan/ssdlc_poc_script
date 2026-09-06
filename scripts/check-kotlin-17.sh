#!/usr/bin/env bash
set -uo pipefail

# Source shared cross-platform utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

resolve_target_dir "Kotlin 2.0 (JVM 17)" "kotlin-17" "kotlin-17-gradle" "${1:-}" "${2:-}"
resolve_trivy

ensure_gradle_wrapper "${PROJECT_DIR}"
trap 'cleanup_all_gradle_temp "${PROJECT_DIR}"' EXIT INT TERM

echo "============================================================"
echo " Starting SSDLC Audit for [${PROJECT_NAME}] (${PROJECT_DIR})"
echo "============================================================"

# ------------------------------------------------------------
# GATE 1: Unused Dependencies Detection (buildHealth)
# ------------------------------------------------------------
echo "[Gate 1] Analyzing unused dependencies via dependency-analysis plugin..."
GATE1_REPORT="${REPORTS_DIR}/${PROJECT_ID}-unused.md"

ensure_gradle_dependency_analysis "${PROJECT_DIR}"

echo "  [CMD] cd ${PROJECT_DIR} && ./gradlew buildHealth --no-daemon"

(cd "${PROJECT_DIR}" && (if [ -f "./gradlew" ]; then ./gradlew buildHealth --no-daemon 2>/dev/null; elif command -v gradle >/dev/null 2>&1; then gradle buildHealth --no-daemon 2>/dev/null; fi || true))

cleanup_gradle_dependency_analysis "${PROJECT_DIR}"

cat <<'EOF' > "${GATE1_REPORT}"
# Kotlin 2.0 (JVM 17) - Unused Dependencies Report

> **SSDLC Gate 1:** Attack Surface Reduction (Audit Only)

## Unused Declared Dependencies

EOF

TXT_HEALTH="${PROJECT_DIR}/build/reports/dependency-analysis/build-health-report.txt"
UNUSED_ROWS=""
if [ -f "$TXT_HEALTH" ]; then
    UNUSED_ROWS=$(awk '
    BEGIN { capturing = 0 }
    /Unused dependencies which should be removed:/ { capturing = 1; next }
    capturing == 1 && /implementation\(/ {
        line = $0
        sub(/.*implementation\("/, "", line)
        sub(/".*$/, "", line)
        if (line != "") {
            printf("| `implementation` | `%s` | Remove unused dependency |\n", line)
        }
    }
    /Dependencies which should be removed or changed to runtime-only:/ { capturing = 2; next }
    capturing == 2 && /runtimeOnly\(/ {
        line = $0
        sub(/.*runtimeOnly\("/, "", line)
        sub(/".*$/, "", line)
        if (line != "") {
            printf("| `implementation` | `%s` | Change to runtimeOnly |\n", line)
        }
    }
    (capturing == 1 || capturing == 2) && (/These transitive/ || /Advice for/ || /^---/) { capturing = 0 }
    ' "$TXT_HEALTH")
fi

if [ -n "$UNUSED_ROWS" ]; then
    cat <<'EOF' >> "${GATE1_REPORT}"
| Scope / Configuration | Dependency Coordinate | Recommended Action |
| :--- | :--- | :--- |
EOF
    echo "$UNUSED_ROWS" >> "${GATE1_REPORT}"
elif [ -f "$TXT_HEALTH" ]; then
    echo "*No unused declared dependencies detected.*" >> "${GATE1_REPORT}"
else
    cat <<'EOF' >> "${GATE1_REPORT}"
> [!NOTE]
> The `com.autonomousapps.dependency-analysis` plugin could not be evaluated for this project.
>
> To enable manual analysis, add to `build.gradle.kts`:
> ```kotlin
> plugins {
>     id("com.autonomousapps.dependency-analysis") version "1.31.0"
> }
> ```
EOF
fi

echo "  -> Gate 1 report written to ${GATE1_REPORT}"

# ------------------------------------------------------------
# GATE 2: EOL & Outdated Dependency Updates (dependencyUpdates)
# ------------------------------------------------------------
echo "[Gate 2] Checking outdated dependencies via ben-manes versions plugin..."
GATE2_REPORT="${REPORTS_DIR}/${PROJECT_ID}-outdated.md"

INIT_SCRIPT="${_COMMON_DIR}/init-versions.gradle"
INIT_FLAG=""
if [ -f "$INIT_SCRIPT" ]; then
    INIT_FLAG="--init-script ${INIT_SCRIPT}"
fi

echo "  [CMD] cd ${PROJECT_DIR} && ./gradlew ${INIT_FLAG} dependencyUpdates --no-daemon"

(cd "${PROJECT_DIR}" && (
    if [ -f "./gradlew" ]; then
        ./gradlew ${INIT_FLAG} dependencyUpdates --no-daemon 2>/dev/null
    elif command -v gradle >/dev/null 2>&1; then
        gradle ${INIT_FLAG} dependencyUpdates --no-daemon 2>/dev/null
    fi || true
))

cat <<'EOF' > "${GATE2_REPORT}"
# Kotlin 2.0 (JVM 17) - Outdated Dependencies Report

> **SSDLC Gate 2:** EOL, Deprecated & Outdated Dependencies (Audit Only)

## Dependency Updates

EOF

TXT_UPDATES="${PROJECT_DIR}/build/dependencyUpdates/report.txt"
OUTDATED_ROWS=""
if [ -f "$TXT_UPDATES" ]; then
    OUTDATED_ROWS=$(awk '
    BEGIN { capturing = 0 }
    /The following dependencies have later milestone versions:/ { capturing = 1; next }
    capturing && / - / && /->/ {
        line = $0
        sub(/^.* - /, "", line)
        split(line, a, "[")
        coord = a[1]
        gsub(/^[ \t]+|[ \t]+$/, "", coord)
        split(a[2], b, "]")
        split(b[1], vers, "->")
        curr = vers[1]
        latest = vers[2]
        gsub(/^[ \t]+|[ \t]+$/, "", curr)
        gsub(/^[ \t]+|[ \t]+$/, "", latest)
        printf("| `%s` | `%s` | `%s` | Update Available | Upgrade to `%s` |\n", coord, curr, latest, latest)
    }
    capturing && (/Gradle release-candidate/ || /^---/) { capturing = 0 }
    ' "$TXT_UPDATES")
fi

if [ -n "$OUTDATED_ROWS" ]; then
    cat <<'EOF' >> "${GATE2_REPORT}"
| Dependency Coordinate | Current Version | Available Update | Status | Recommended Action |
| :--- | :--- | :--- | :--- | :--- |
EOF
    echo "$OUTDATED_ROWS" >> "${GATE2_REPORT}"
elif [ -f "$TXT_UPDATES" ]; then
    echo "*All declared dependencies are up to date.*" >> "${GATE2_REPORT}"
else
    echo "*No outdated dependencies detected or dependencyUpdates report not generated.*" >> "${GATE2_REPORT}"
fi

echo "  -> Gate 2 report written to ${GATE2_REPORT}"

# ------------------------------------------------------------
# GATE 3: Direct Visible CVE Scan (Trivy)
# ------------------------------------------------------------
echo "[Gate 3] Checking vulnerabilities for ${PROJECT_NAME}..."
GATE3_REPORT="${REPORTS_DIR}/${PROJECT_ID}-cve.md"

ensure_gradle_lockfile "${PROJECT_DIR}"

if command -v "$TRIVY_CMD" >/dev/null 2>&1 || [ -f "$TRIVY_CMD" ]; then
    echo "  [CMD] $TRIVY_CMD fs --severity HIGH,CRITICAL --exit-code 0 --format table ${PROJECT_DIR}"
    echo "  -> Running Aqua Security Trivy scan ($TRIVY_CMD)..."
    "$TRIVY_CMD" fs --severity HIGH,CRITICAL --exit-code 0 --format table "${PROJECT_DIR}" || true
    
    MD_TABLE=$("$TRIVY_CMD" fs --severity HIGH,CRITICAL --exit-code 0 --format template --template "@${REPO_ROOT}/scripts/markdown.tpl" "${PROJECT_DIR}" 2>/dev/null || true)
    
    cat <<EOF > "${GATE3_REPORT}"
# ${PROJECT_NAME} - Vulnerability Findings Report

> **SSDLC Gate 3:** Direct Visible CVE Scanning (HIGH & CRITICAL)
> Target: \`${PROJECT_DIR}\`

## Detected Vulnerabilities

EOF

    if [ -n "$(echo "$MD_TABLE" | tr -d '[:space:]')" ]; then
        echo "$MD_TABLE" >> "${GATE3_REPORT}"
    else
        echo "*No HIGH or CRITICAL vulnerabilities detected.*" >> "${GATE3_REPORT}"
    fi
else
    echo "  -> [NOTICE] Trivy CLI is not installed in PATH. Generating advisory report..."
    cat <<EOF > "${GATE3_REPORT}"
# ${PROJECT_NAME} - Vulnerability Findings Report

> **SSDLC Gate 3:** Direct Visible CVE Scanning (HIGH & CRITICAL)
> Target: \`${PROJECT_DIR}\`

EOF
    trivy_install_hint >> "${GATE3_REPORT}"
fi

cleanup_all_gradle_temp "${PROJECT_DIR}"
trap - EXIT INT TERM

echo "  -> Gate 3 report written to ${GATE3_REPORT}"
echo "[DONE] Completed checks for ${PROJECT_NAME} (Exit: 0)"
exit 0
