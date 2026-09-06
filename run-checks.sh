#!/usr/bin/env bash
set -uo pipefail

REPORTS_DIR="reports"
mkdir -p "${REPORTS_DIR}"

echo "============================================================"
echo "          STARTING SSDLC LOCAL AUDIT ORCHESTRATION          "
echo "============================================================"

# 1. Java Services (Maven)
bash scripts/check-java-11.sh "${REPORTS_DIR}"
bash scripts/check-java-17.sh "${REPORTS_DIR}"
bash scripts/check-java-21.sh "${REPORTS_DIR}"

# 2. Kotlin Services (Gradle 8.5, Kotlin 2.0)
bash scripts/check-kotlin-11.sh "${REPORTS_DIR}"
bash scripts/check-kotlin-17.sh "${REPORTS_DIR}"
bash scripts/check-kotlin-21.sh "${REPORTS_DIR}"

# 3. Node.js Services (npm)
bash scripts/check-node-18.sh "${REPORTS_DIR}"
bash scripts/check-node-20.sh "${REPORTS_DIR}"
bash scripts/check-node-22.sh "${REPORTS_DIR}"

# 4. Display Executive Summary
bash scripts/summarize-reports.sh "${REPORTS_DIR}"

exit 0
