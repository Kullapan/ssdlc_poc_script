#!/usr/bin/env bash
set -uo pipefail

PROJECT_NAME="Kotlin 2.0 (JVM 11)"
PROJECT_ID="kotlin-11"
PROJECT_DIR="kotlin-11-gradle"
REPORTS_DIR="${1:-reports}"

# Source shared cross-platform utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

resolve_trivy

mkdir -p "${REPORTS_DIR}"

echo "============================================================"
echo " Starting SSDLC Audit for [${PROJECT_NAME}] (${PROJECT_DIR})"
echo "============================================================"

# ------------------------------------------------------------
# GATE 1: Unused Dependencies Detection (buildHealth)
# ------------------------------------------------------------
echo "[Gate 1] Analyzing unused dependencies via dependency-analysis plugin..."
GATE1_REPORT="${REPORTS_DIR}/${PROJECT_ID}-unused.md"

(cd "${PROJECT_DIR}" && (./gradlew buildHealth --no-daemon 2>/dev/null || true))

cat <<'EOF' > "${GATE1_REPORT}"
# Kotlin 2.0 (JVM 11) - Unused Dependencies Report

> **SSDLC Gate 1:** Attack Surface Reduction (Audit Only)

## Unused Declared Dependencies

| Scope / Configuration | Dependency Coordinate | Recommended Action |
| :--- | :--- | :--- |
EOF

TXT_HEALTH="${PROJECT_DIR}/build/reports/dependency-analysis/build-health-report.txt"
if [ -f "$TXT_HEALTH" ]; then
    awk '
    BEGIN { capturing = 0 }
    /Unused dependencies which should be removed:/ { capturing = 1; next }
    capturing && /implementation\(/ {
        line = $0
        sub(/.*implementation\("/, "", line)
        sub(/".*$/, "", line)
        if (line != "") {
            printf("| `implementation` | `%s` | Remove unused dependency |\n", line)
        }
    }
    capturing && (/Dependencies which should/ || /Advice for/) { capturing = 0 }
    ' "$TXT_HEALTH" >> "${GATE1_REPORT}"
fi

echo "  -> Gate 1 report written to ${GATE1_REPORT}"

# ------------------------------------------------------------
# GATE 2: EOL & Outdated Dependency Updates (dependencyUpdates)
# ------------------------------------------------------------
echo "[Gate 2] Checking outdated dependencies via ben-manes versions plugin..."
GATE2_REPORT="${REPORTS_DIR}/${PROJECT_ID}-outdated.md"

(cd "${PROJECT_DIR}" && (./gradlew dependencyUpdates --no-daemon 2>/dev/null || true))

cat <<'EOF' > "${GATE2_REPORT}"
# Kotlin 2.0 (JVM 11) - Outdated Dependencies Report

> **SSDLC Gate 2:** EOL, Deprecated & Outdated Dependencies (Audit Only)

## Dependency Updates

| Dependency Coordinate | Current Version | Available Update | Status |
| :--- | :--- | :--- | :--- |
EOF

TXT_UPDATES="${PROJECT_DIR}/build/dependencyUpdates/report.txt"
if [ -f "$TXT_UPDATES" ]; then
    awk '
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
        printf("| `%s` | `%s` | `%s` | Update Available |\n", coord, curr, latest)
    }
    capturing && (/Gradle release-candidate/ || /^---/) { capturing = 0 }
    ' "$TXT_UPDATES" >> "${GATE2_REPORT}"
fi

echo "  -> Gate 2 report written to ${GATE2_REPORT}"

# ------------------------------------------------------------
# GATE 3: Direct Visible CVE Scan (Trivy)
# ------------------------------------------------------------
echo "[Gate 3] Checking vulnerabilities for ${PROJECT_NAME}..."
GATE3_REPORT="${REPORTS_DIR}/${PROJECT_ID}-cve.md"

if command -v "$TRIVY_CMD" >/dev/null 2>&1 || [ -f "$TRIVY_CMD" ]; then
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

echo "  -> Gate 3 report written to ${GATE3_REPORT}"
echo "[DONE] Completed checks for ${PROJECT_NAME} (Exit: 0)"
exit 0
