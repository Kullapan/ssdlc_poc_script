#!/usr/bin/env bash
set -uo pipefail

# Source shared cross-platform utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

resolve_target_dir "Node.js 20" "node-20" "nodejs-20-npm" "${1:-}" "${2:-}"
resolve_node
resolve_npm
resolve_npx
resolve_trivy

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
echo "  [CMD] cd ${PROJECT_DIR} && $NPX_CMD --yes depcheck --json"

RAW_DEPCHECK=$(cd "${PROJECT_DIR}" && "$NPX_CMD" --yes depcheck --json 2>/dev/null || true)

"$NODE_CMD" -e '
const raw = process.argv[1];
const reportPath = process.argv[2];
const projectName = process.argv[3];
const projectDir = process.argv[4];
const fs = require("fs");

let data = { dependencies: [], devDependencies: [] };
try {
    if (raw && raw.trim().startsWith("{")) {
        data = JSON.parse(raw);
    }
} catch (e) {}

let pkgJson = {};
try {
    pkgJson = JSON.parse(fs.readFileSync(projectDir + "/package.json", "utf8"));
} catch (e) {}

function getInstalledVersion(pkg) {
    try {
        const p = JSON.parse(fs.readFileSync(projectDir + "/node_modules/" + pkg + "/package.json", "utf8"));
        return p.version || "N/A";
    } catch (e) {
        return "N/A";
    }
}

let content = "# " + projectName + " - Unused Dependencies Report\n\n";
content += "> **SSDLC Gate 1:** Attack Surface Reduction (Audit Only)\n\n";
content += "## Summary\n";
content += "- **Unused Production Dependencies:** " + (data.dependencies ? data.dependencies.length : 0) + "\n";
content += "- **Unused Development Dependencies:** " + (data.devDependencies ? data.devDependencies.length : 0) + "\n\n";

content += "## Unused Declared Dependencies\n\n";

const allUnused = [];
if (data.dependencies) {
    for (const dep of data.dependencies) {
        allUnused.push({
            name: dep,
            scope: "dependencies",
            declared: (pkgJson.dependencies && pkgJson.dependencies[dep]) || "N/A",
            installed: getInstalledVersion(dep),
            action: "Remove unused dependency"
        });
    }
}
if (data.devDependencies) {
    for (const dev of data.devDependencies) {
        allUnused.push({
            name: dev,
            scope: "devDependencies",
            declared: (pkgJson.devDependencies && pkgJson.devDependencies[dev]) || "N/A",
            installed: getInstalledVersion(dev),
            action: "Remove unused devDependency"
        });
    }
}

if (allUnused.length > 0) {
    content += "| Scope | Package Name | Declared Version | Installed Version | Recommended Action |\n";
    content += "| :--- | :--- | :--- | :--- | :--- |\n";
    for (const u of allUnused) {
        content += "| `" + u.scope + "` | `" + u.name + "` | `" + u.declared + "` | `" + u.installed + "` | " + u.action + " |\n";
    }
} else {
    content += "*No unused declared dependencies detected.*\n";
}

fs.writeFileSync(reportPath, content, "utf8");
' "$RAW_DEPCHECK" "$GATE1_REPORT" "$PROJECT_NAME" "$PROJECT_DIR"

echo "  -> Gate 1 report written to ${GATE1_REPORT}"

# ------------------------------------------------------------
# GATE 2: EOL, Deprecated & Outdated Checks (npm outdated & view)
# ------------------------------------------------------------
echo "[Gate 2] Checking library health, outdated & deprecated status..."
GATE2_REPORT="${REPORTS_DIR}/${PROJECT_ID}-health.md"
echo "  [CMD] cd ${PROJECT_DIR} && $NPM_CMD outdated --json"

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

function getInstalledVersion(pkg) {
    if (outdatedMap[pkg] && outdatedMap[pkg].current) {
        return outdatedMap[pkg].current;
    }
    try {
        const p = JSON.parse(fs.readFileSync(projectDir + "/node_modules/" + pkg + "/package.json", "utf8"));
        return p.version || "N/A";
    } catch (e) {
        return "N/A";
    }
}

const prodDeps = Object.keys(pkgJson.dependencies || {});
const devDeps = Object.keys(pkgJson.devDependencies || {});

let rows = [];

function processDeps(list, scope) {
    for (const pkg of list) {
        const declared = (pkgJson[scope] && pkgJson[scope][pkg]) || "N/A";
        const installed = getInstalledVersion(pkg);
        const isOutdated = !!outdatedMap[pkg];
        const wanted = isOutdated ? outdatedMap[pkg].wanted : installed;
        const latest = isOutdated ? outdatedMap[pkg].latest : installed;

        let updateStatus = "✅ Up to date";
        if (isOutdated) {
            const instClean = installed.replace(/[\^~]/g, "");
            const instMajor = parseInt(instClean.split(".")[0], 10);
            const latestMajor = parseInt(latest.split(".")[0], 10);

            if (!isNaN(instMajor) && !isNaN(latestMajor) && latestMajor > instMajor) {
                const lag = latestMajor - instMajor;
                updateStatus = "⚠️ **Major update available** (v" + latest + ", +" + lag + " major)";
            } else if (!isNaN(instMajor) && !isNaN(latestMajor) && latest !== installed) {
                updateStatus = "⚡ Update available (v" + latest + ")";
            } else {
                updateStatus = "Update available (v" + latest + ")";
            }
        }

        let deprecatedReason = "Healthy";
        try {
            const depMsg = execSync("npm view " + pkg + " deprecated --json", { timeout: 8000, stdio: ["pipe", "pipe", "ignore"] }).toString().trim();
            if (depMsg && depMsg !== "null" && depMsg !== "\"\"" && depMsg.length > 0) {
                deprecatedReason = "⚠️ **Deprecated**: " + depMsg.replace(/^\"|\"$/g, "");
            }
        } catch (e) {}

        let recommendedAction = "No action needed (up to date)";
        if (deprecatedReason !== "Healthy") {
            recommendedAction = "⚠️ Migrate to an active alternative (deprecated)";
        } else if (isOutdated) {
            const instClean = installed.replace(/[\^~]/g, "");
            const instMajor = parseInt(instClean.split(".")[0], 10);
            const latestMajor = parseInt(latest.split(".")[0], 10);

            if (!isNaN(instMajor) && !isNaN(latestMajor) && latestMajor > instMajor) {
                recommendedAction = "Upgrade `package.json` to `^" + latest + "` (test for breaking changes)";
            } else {
                recommendedAction = "Upgrade `package.json` to `^" + latest + "`";
            }
        } else {
            const declClean = declared.replace(/[\^~]/g, "");
            if (declClean !== installed && installed !== "N/A") {
                recommendedAction = "Optional: bump `package.json` to `^" + installed + "` to reflect installed baseline";
            } else {
                recommendedAction = "No action needed (up to date)";
            }
        }

        rows.push({
            name: pkg,
            scope: scope,
            declared: declared,
            installed: installed,
            wanted: wanted,
            latest: latest,
            status: updateStatus,
            deprecated: deprecatedReason,
            action: recommendedAction
        });
    }
}

processDeps(prodDeps, "dependencies");
processDeps(devDeps, "devDependencies");

let content = "# " + projectName + " - Library Lifecycle & Health Report\n\n";
content += "> **SSDLC Gate 2:** EOL, Deprecated & Outdated Dependencies (Audit Only)\n\n";
content += "## Dependency Version & Lifecycle Status\n\n";
content += "| Package | Scope | Declared | Installed | Wanted | Latest | Update Status | Deprecation Status | Recommended Action |\n";
content += "| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n";

for (const r of rows) {
    content += "| `" + r.name + "` | `" + r.scope + "` | `" + r.declared + "` | `" + r.installed + "` | `" + r.wanted + "` | `" + r.latest + "` | " + r.status + " | " + r.deprecated + " | " + r.action + " |\n";
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

echo "  -> Gate 3 report written to ${GATE3_REPORT}"
echo "[DONE] Completed checks for ${PROJECT_NAME} (Exit: 0)"
exit 0
