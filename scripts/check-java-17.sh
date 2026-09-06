#!/usr/bin/env bash
set -uo pipefail

PROJECT_NAME="Java 17 (Maven)"
PROJECT_ID="java-17"
PROJECT_DIR="java-17-maven"
REPORTS_DIR="${1:-reports}"

# Source shared cross-platform utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

resolve_mvn
resolve_trivy

mkdir -p "${REPORTS_DIR}"

echo "============================================================"
echo " Starting SSDLC Audit for [${PROJECT_NAME}] (${PROJECT_DIR})"
echo "============================================================"

# ------------------------------------------------------------
# GATE 1: Unused Dependencies Detection (maven-dependency-plugin)
# ------------------------------------------------------------
echo "[Gate 1] Analyzing dependency usage (analyze-only)..."
GATE1_REPORT="${REPORTS_DIR}/${PROJECT_ID}-unused.md"

RAW_UNUSED=$("$MVN_CMD" compile dependency:analyze-only -f "${PROJECT_DIR}/pom.xml" -DfailOnWarning=false 2>/dev/null || true)

cat <<'EOF' > "${GATE1_REPORT}"
# Java 17 (Maven) - Unused Dependencies Report

> **SSDLC Gate 1:** Attack Surface Reduction (Audit Only)

## Unused Declared Dependencies

| Group ID | Artifact ID | Type | Version | Scope |
| :--- | :--- | :--- | :--- | :--- |
EOF

echo "$RAW_UNUSED" | awk '
BEGIN { capturing = 0; count = 0 }
/Unused declared dependencies found:/ { capturing = 1; next }
capturing && /:jar:/ {
    line = $0
    sub(/^.*\[(WARNING|INFO)\][ \t]*/, "", line)
    n = split(line, a, ":")
    if (n >= 5) {
        printf("| `%s` | `%s` | %s | `%s` | %s |\n", a[1], a[2], a[3], a[4], a[5])
        count++
    }
}
capturing && (/BUILD SUCCESS/ || /---/ || /Used undeclared/) { capturing = 0 }
' >> "${GATE1_REPORT}"

echo "  -> Gate 1 report written to ${GATE1_REPORT}"

# ------------------------------------------------------------
# GATE 2: EOL & Outdated Dependency Updates (versions-maven-plugin)
# ------------------------------------------------------------
echo "[Gate 2] Checking outdated dependencies (versions:display-dependency-updates)..."
GATE2_REPORT="${REPORTS_DIR}/${PROJECT_ID}-outdated.md"

RAW_OUTDATED=$("$MVN_CMD" versions:display-dependency-updates -DprocessDependencyManagement=false -f "${PROJECT_DIR}/pom.xml" 2>/dev/null || true)

cat <<'EOF' > "${GATE2_REPORT}"
# Java 17 (Maven) - Outdated Dependencies Report

> **SSDLC Gate 2:** EOL, Deprecated & Outdated Dependencies (Audit Only)

## Dependency Updates Available

| Dependency | Current Version | Available Update | Status |
| :--- | :--- | :--- | :--- |
EOF

echo "$RAW_OUTDATED" | awk '
BEGIN { capturing = 0 }
/The following dependencies in Dependencies have newer versions:/ { capturing = 1; next }
capturing && /->/ {
    line = $0
    sub(/^.*\[(WARNING|INFO)\][ \t]*/, "", line)
    split(line, parts, "->")
    latest = parts[2]
    gsub(/^[ \t]+|[ \t]+$/, "", latest)
    left = parts[1]
    sub(/[ \t]*\.\..*$/, "", left)
    ga = left
    gsub(/^[ \t]+|[ \t]+$/, "", ga)
    orig = parts[1]
    sub(/[ \t]+$/, "", orig)
    n = split(orig, w, /[ \t]+/)
    curr = w[n]
    printf("| `%s` | `%s` | `%s` | Update Available |\n", ga, curr, latest)
}
capturing && (/BUILD SUCCESS/ || /---/ || /No dependencies have newer versions/) { capturing = 0 }
' >> "${GATE2_REPORT}"

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
