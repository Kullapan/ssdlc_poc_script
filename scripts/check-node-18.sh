#!/usr/bin/env bash
set -uo pipefail

PROJECT_NAME="Node.js 18"
PROJECT_ID="node-18"
PROJECT_DIR="nodejs-18-npm"
REPORTS_DIR="${1:-reports}"

# Source shared cross-platform utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

resolve_node
resolve_npm
resolve_npx
resolve_trivy

mkdir -p "${REPORTS_DIR}"

echo "============================================================"
echo " Starting SSDLC Audit for [${PROJECT_NAME}] (${PROJECT_DIR})"
echo "============================================================"

# Ensure npm dependencies are installed for accurate analysis
if [ ! -d "${PROJECT_DIR}/node_modules" ]; then
    echo "[INFO] Installing npm dependencies for ${PROJECT_DIR}..."
    (cd "${PROJECT_DIR}" && "$NPM_CMD" install --prefer-offline --no-audit --silent 2>/dev/null || "$NPM_CMD" install --no-audit --silent 2>/dev/null || true)
fi

# ------------------------------------------------------------
# GATE 1: Unused Dependencies Detection (depcheck)
# ------------------------------------------------------------
echo "[Gate 1] Checking unused dependencies via depcheck..."
GATE1_REPORT="${REPORTS_DIR}/${PROJECT_ID}-unused.md"

RAW_DEPCHECK=$(cd "${PROJECT_DIR}" && "$NPX_CMD" --yes depcheck --json 2>/dev/null || true)

"$NODE_CMD" -e '
const raw = process.argv[1];
const reportPath = process.argv[2];
const projectName = process.argv[3];
const fs = require("fs");

let data = { dependencies: [], devDependencies: [] };
try {
    if (raw && raw.trim().startsWith("{")) {
        data = JSON.parse(raw);
    }
} catch (e) {}

let content = "# " + projectName + " - Unused Dependencies Report\n\n";
content += "> **SSDLC Gate 1:** Attack Surface Reduction (Audit Only)\n\n";
content += "## Summary\n";
content += "- **Unused Dependencies Count:** " + (data.dependencies ? data.dependencies.length : 0) + "\n";
content += "- **Unused DevDependencies Count:** " + (data.devDependencies ? data.devDependencies.length : 0) + "\n\n";

content += "## Unused Dependencies\n\n";
if (data.dependencies && data.dependencies.length > 0) {
    content += "| Type | Package Name | Status |\n";
    content += "| :--- | :--- | :--- |\n";
    for (const dep of data.dependencies) {
        content += "| Dependency | `" + dep + "` | Declared in package.json but not imported |\n";
    }
} else {
    content += "*No unused production dependencies detected.*\n";
}

content += "\n## Unused DevDependencies\n\n";
if (data.devDependencies && data.devDependencies.length > 0) {
    content += "| Type | Package Name | Status |\n";
    content += "| :--- | :--- | :--- |\n";
    for (const dev of data.devDependencies) {
        content += "| DevDependency | `" + dev + "` | Declared in devDependencies but not referenced |\n";
    }
} else {
    content += "*No unused development dependencies detected.*\n";
}

fs.writeFileSync(reportPath, content, "utf8");
' "$RAW_DEPCHECK" "$GATE1_REPORT" "$PROJECT_NAME"

echo "  -> Gate 1 report written to ${GATE1_REPORT}"

# ------------------------------------------------------------
# GATE 2: EOL, Deprecated & Outdated Checks (npm outdated & view)
# ------------------------------------------------------------
echo "[Gate 2] Checking library health, outdated & deprecated status..."
GATE2_REPORT="${REPORTS_DIR}/${PROJECT_ID}-health.md"

RAW_OUTDATED=$(cd "${PROJECT_DIR}" && "$NPM_CMD" outdated --json 2>/dev/null || true)

"$NODE_CMD" -e '
const fs = require("fs");
const { execSync } = require("child_process");

const projectDir = process.argv[1];
const rawOutdated = process.argv[2];
const reportPath = process.argv[3];
const projectName = process.argv[4];

let outdatedMap = {};
try {
    if (rawOutdated && rawOutdated.trim().startsWith("{")) {
        outdatedMap = JSON.parse(rawOutdated);
    }
} catch (e) {}

let pkgJson = {};
try {
    pkgJson = JSON.parse(fs.readFileSync(projectDir + "/package.json", "utf8"));
} catch (e) {}

const declaredDeps = Object.keys(pkgJson.dependencies || {});
const declaredDevs = Object.keys(pkgJson.devDependencies || {});
const allDeps = [...declaredDeps, ...declaredDevs];

let rows = [];

for (const pkg of allDeps) {
    const current = (outdatedMap[pkg] && outdatedMap[pkg].current) || (pkgJson.dependencies && pkgJson.dependencies[pkg]) || (pkgJson.devDependencies && pkgJson.devDependencies[pkg]) || "N/A";
    const wanted = (outdatedMap[pkg] && outdatedMap[pkg].wanted) || current;
    const latest = (outdatedMap[pkg] && outdatedMap[pkg].latest) || current;

    // Check Major Lag (>1)
    let majorLag = "No";
    const currClean = current.replace(/[\^~]/g, "");
    const currMajor = parseInt(currClean.split(".")[0], 10);
    const latestMajor = parseInt(latest.split(".")[0], 10);
    if (!isNaN(currMajor) && !isNaN(latestMajor) && (latestMajor - currMajor) > 1) {
        majorLag = "**Yes (Lag: " + (latestMajor - currMajor) + ")**";
    } else if (!isNaN(currMajor) && !isNaN(latestMajor) && (latestMajor - currMajor) === 1) {
        majorLag = "1 Major behind";
    }

    // Check Deprecated status
    let deprecatedReason = "-";
    try {
        const depMsg = execSync("npm view " + pkg + " deprecated --json", { timeout: 8000, stdio: ["pipe", "pipe", "ignore"] }).toString().trim();
        if (depMsg && depMsg !== "null" && depMsg !== "\"\"" && depMsg.length > 0) {
            deprecatedReason = depMsg.replace(/^\"|\"$/g, "");
        }
    } catch (e) {}

    rows.push({
        name: pkg,
        current: current,
        wanted: wanted,
        latest: latest,
        majorLag: majorLag,
        deprecated: deprecatedReason
    });
}

let content = "# " + projectName + " - Library Lifecycle & Health Report\n\n";
content += "> **SSDLC Gate 2:** EOL, Deprecated & Outdated Dependencies (Audit Only)\n\n";
content += "| Package | Current | Wanted | Latest | Major Lag (>1) | Deprecated Reason |\n";
content += "| :--- | :--- | :--- | :--- | :--- | :--- |\n";

for (const r of rows) {
    content += "| `" + r.name + "` | `" + r.current + "` | `" + r.wanted + "` | `" + r.latest + "` | " + r.majorLag + " | " + (r.deprecated !== "-" ? "**" + r.deprecated + "**" : "-") + " |\n";
}

fs.writeFileSync(reportPath, content, "utf8");
' "$PROJECT_DIR" "$RAW_OUTDATED" "$GATE2_REPORT" "$PROJECT_NAME"

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
