#!/usr/bin/env bash
# =============================================================================
# common.sh — Shared cross-platform utilities for SSDLC check scripts
# Source this file: SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#                   source "${SCRIPT_DIR}/common.sh"
# =============================================================================

# Detect OS: Darwin = macOS, MINGW*/MSYS*/CYGWIN* = Windows Git Bash/MSYS2
OS_TYPE="$(uname -s)"

# Capture caller directory and repo root
_CALLER_DIR="$(pwd)"
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_COMMON_DIR}/.." && pwd)"

_is_windows() {
    case "$OS_TYPE" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
        *) return 1 ;;
    esac
}

# -----------------------------------------------------------------------------
# resolve_target_dir
#   Dynamically determines PROJECT_DIR and REPORTS_DIR.
#   Supports:
#     - Explicit target directory ($1)
#     - Running from inside an external project's own directory
#     - Defaulting to this monorepo's sub-project
# -----------------------------------------------------------------------------
resolve_target_dir() {
    local def_name="$1"
    local def_id="$2"
    local def_dir="$3"
    local arg1="${4:-}"
    local arg2="${5:-}"

    # 1. Explicit directory passed in arg1
    if [ -n "$arg1" ] && [ -d "$arg1" ] && [ "$arg1" != "reports" ]; then
        PROJECT_DIR="$(cd "$arg1" && pwd)"
        PROJECT_ID="$(basename "$PROJECT_DIR")"
        PROJECT_NAME="$PROJECT_ID"
        local rep="${arg2:-reports}"
        if [[ "$rep" = /* ]] || [[ "$rep" =~ ^[A-Za-z]: ]]; then
            REPORTS_DIR="$rep"
        else
            REPORTS_DIR="${PROJECT_DIR}/${rep}"
        fi
    # 2. Called from inside a project directory (has pom.xml/build.gradle*/package.json)
    elif [ -f "${_CALLER_DIR}/pom.xml" ] || [ -f "${_CALLER_DIR}/build.gradle.kts" ] || [ -f "${_CALLER_DIR}/build.gradle" ] || [ -f "${_CALLER_DIR}/package.json" ]; then
        PROJECT_DIR="${_CALLER_DIR}"
        PROJECT_ID="$(basename "$PROJECT_DIR")"
        PROJECT_NAME="$PROJECT_ID"
        local rep="${arg1:-reports}"
        if [[ "$rep" = /* ]] || [[ "$rep" =~ ^[A-Za-z]: ]]; then
            REPORTS_DIR="$rep"
        else
            REPORTS_DIR="${PROJECT_DIR}/${rep}"
        fi
    # 3. Parent directory of scripts/ is itself a standalone project (e.g. sample-java-mvn/pom.xml exists)
    #    and the monorepo subfolder ($def_dir) does not exist here
    elif ([ -f "${REPO_ROOT}/pom.xml" ] || [ -f "${REPO_ROOT}/build.gradle.kts" ] || [ -f "${REPO_ROOT}/build.gradle" ] || [ -f "${REPO_ROOT}/package.json" ]) && [ ! -d "${REPO_ROOT}/${def_dir}" ]; then
        PROJECT_DIR="${REPO_ROOT}"
        PROJECT_ID="$(basename "$PROJECT_DIR")"
        PROJECT_NAME="$PROJECT_ID"
        local rep="${arg1:-reports}"
        if [[ "$rep" = /* ]] || [[ "$rep" =~ ^[A-Za-z]: ]]; then
            REPORTS_DIR="$rep"
        else
            REPORTS_DIR="${REPO_ROOT}/${rep}"
        fi
    # 4. Default fallback to monorepo internal project
    else
        PROJECT_DIR="${REPO_ROOT}/${def_dir}"
        PROJECT_ID="$def_id"
        PROJECT_NAME="$def_name"
        local rep="${arg1:-reports}"
        if [[ "$rep" = /* ]] || [[ "$rep" =~ ^[A-Za-z]: ]]; then
            REPORTS_DIR="$rep"
        else
            REPORTS_DIR="${REPO_ROOT}/${rep}"
        fi
    fi

    mkdir -p "${REPORTS_DIR}"
}

# -----------------------------------------------------------------------------
# resolve_trivy
#   Sets TRIVY_CMD to the first usable Trivy binary found.
#   Search order: PATH (trivy) -> PATH (trivy.exe, Win) ->
#                 WinGet package dir (Win) -> Homebrew paths (macOS)
# -----------------------------------------------------------------------------
resolve_trivy() {
    TRIVY_CMD="trivy"
    if command -v trivy >/dev/null 2>&1; then
        return 0
    fi

    if _is_windows; then
        # Try trivy.exe in PATH
        if command -v trivy.exe >/dev/null 2>&1; then
            TRIVY_CMD="trivy.exe"
            return 0
        fi
        # Scan WinGet install directories (glob expansion)
        for CANDIDATE in \
            /c/Users/*/AppData/Local/Microsoft/WinGet/Packages/AquaSecurity.Trivy_*/trivy.exe \
            /c/Users/*/AppData/Local/Microsoft/WinGet/Links/trivy.exe; do
            if [ -f "$CANDIDATE" ]; then
                TRIVY_CMD="$CANDIDATE"
                return 0
            fi
        done
    else
        # macOS: Homebrew standard install locations
        for CANDIDATE in /usr/local/bin/trivy /opt/homebrew/bin/trivy; do
            if [ -f "$CANDIDATE" ]; then
                TRIVY_CMD="$CANDIDATE"
                return 0
            fi
        done
    fi

    # Not found -- TRIVY_CMD stays as "trivy" (will fail the -f check later)
    return 1
}

# -----------------------------------------------------------------------------
# resolve_mvn
#   Sets MVN_CMD to mvn or mvn.cmd (Windows fallback).
# -----------------------------------------------------------------------------
resolve_mvn() {
    MVN_CMD="mvn"
    if command -v mvn >/dev/null 2>&1; then
        return 0
    fi
    if _is_windows && command -v mvn.cmd >/dev/null 2>&1; then
        MVN_CMD="mvn.cmd"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# resolve_node / resolve_npm / resolve_npx
#   Sets NODE_CMD / NPM_CMD / NPX_CMD, preferring non-.exe names on macOS.
# -----------------------------------------------------------------------------
resolve_node() {
    NODE_CMD="node"
    if command -v node >/dev/null 2>&1; then return 0; fi
    if _is_windows && command -v node.exe >/dev/null 2>&1; then
        NODE_CMD="node.exe"
        return 0
    fi
}

resolve_npm() {
    NPM_CMD="npm"
    if command -v npm >/dev/null 2>&1; then return 0; fi
    if _is_windows && command -v npm.cmd >/dev/null 2>&1; then
        NPM_CMD="npm.cmd"
        return 0
    fi
}

resolve_npx() {
    NPX_CMD="npx"
    if command -v npx >/dev/null 2>&1; then return 0; fi
    if _is_windows && command -v npx.cmd >/dev/null 2>&1; then
        NPX_CMD="npx.cmd"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# trivy_install_hint
#   Echoes a cross-platform Trivy installation hint for Markdown reports.
# -----------------------------------------------------------------------------
trivy_install_hint() {
    if _is_windows; then
        printf '> [!WARNING]\n'
        printf '> **Aqua Security Trivy CLI is not installed on this workstation.**\n'
        printf '>\n'
        printf '> To run Gate 3 locally:\n'
        printf '> - **Windows Winget (Recommended):** `winget install AquaSecurity.Trivy`\n'
        printf '> - **Manual Binary:** Download from [Aqua Security Trivy Releases](https://github.com/aquasecurity/trivy/releases) and add `trivy.exe` to your `PATH`.\n'
    else
        printf '> [!WARNING]\n'
        printf '> **Aqua Security Trivy CLI is not installed on this workstation.**\n'
        printf '>\n'
        printf '> To run Gate 3 locally:\n'
        printf '> - **macOS Homebrew (Recommended):** `brew install aquasecurity/trivy/trivy`\n'
        printf '> - **Manual Binary:** Download from [Aqua Security Trivy Releases](https://github.com/aquasecurity/trivy/releases) and add `trivy` to your `PATH`.\n'
    fi
}

# -----------------------------------------------------------------------------
# ensure_gradle_lockfile / cleanup_gradle_lockfile
#   Auto-generates a temporary gradle.lockfile for Kotlin/Gradle projects
#   when missing, enabling Trivy to scan dependencies, and cleans up after.
# -----------------------------------------------------------------------------
_TEMP_LOCKFILE_CREATED=0

ensure_gradle_lockfile() {
    local pdir="$1"
    _TEMP_LOCKFILE_CREATED=0

    # If gradle.lockfile already exists, keep user file intact
    if [ -f "${pdir}/gradle.lockfile" ]; then
        return 0
    fi

    # Find build file (build.gradle.kts or build.gradle)
    local build_file=""
    if [ -f "${pdir}/build.gradle.kts" ]; then
        build_file="${pdir}/build.gradle.kts"
    elif [ -f "${pdir}/build.gradle" ]; then
        build_file="${pdir}/build.gradle"
    fi

    [ -z "$build_file" ] && return 0

    local lockfile="${pdir}/gradle.lockfile"
    echo "  [INFO] Generating temporary gradle.lockfile for Trivy scan..."

    # Extract Spring Boot version if present
    local boot_ver
    boot_ver=$(grep -E 'org\.springframework\.boot' "$build_file" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(\.[A-Za-z0-9_-]+)?' | head -n 1)

    # Extract Kotlin version if present
    local kotlin_ver
    kotlin_ver=$(grep -E 'kotlin\(' "$build_file" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)

    cat <<'EOF_LOCK' > "$lockfile"
# Temporary Gradle lockfile generated by SSDLC audit for Trivy scanning
# Automatically removed after scan completes
EOF_LOCK

    # Parse declared dependencies
    grep -E '^[[:space:]]*(implementation|api|compileOnly|runtimeOnly)[[:space:]]*[\(]' "$build_file" 2>/dev/null | while IFS= read -r line; do
        local dep
        dep=$(echo "$line" | sed -n 's/.*["'"'"']\([^"'"'"']*\)["'"'"'].*/\1/p')
        [ -z "$dep" ] && continue

        local colons
        colons=$(echo "$dep" | tr -cd ':' | wc -c)

        if [ "$colons" -ge 2 ]; then
            echo "${dep}=compileClasspath,runtimeClasspath" >> "$lockfile"
        elif [ "$colons" -eq 1 ]; then
            if echo "$dep" | grep -q 'springframework' && [ -n "$boot_ver" ]; then
                echo "${dep}:${boot_ver}=compileClasspath,runtimeClasspath" >> "$lockfile"
            elif echo "$dep" | grep -q 'kotlin' && [ -n "$kotlin_ver" ]; then
                echo "${dep}:${kotlin_ver}=compileClasspath,runtimeClasspath" >> "$lockfile"
            elif [ -n "$boot_ver" ]; then
                echo "${dep}:${boot_ver}=compileClasspath,runtimeClasspath" >> "$lockfile"
            fi
        fi
    done

    if [ -f "$lockfile" ] && [ "$(wc -l < "$lockfile")" -gt 2 ]; then
        echo "empty=" >> "$lockfile"
        _TEMP_LOCKFILE_CREATED=1
    else
        rm -f "$lockfile"
    fi
}

cleanup_gradle_lockfile() {
    local pdir="$1"
    if [ "${_TEMP_LOCKFILE_CREATED:-0}" = "1" ]; then
        rm -f "${pdir}/gradle.lockfile"
        echo "  [INFO] Removed temporary gradle.lockfile (project untouched)"
        _TEMP_LOCKFILE_CREATED=0
    fi
}

# -----------------------------------------------------------------------------
# ensure_gradle_wrapper / cleanup_gradle_wrapper
#   Supplies temporary gradle-wrapper.jar if missing in the target repo
#   so gradlew runs the project's declared Gradle distribution correctly.
# -----------------------------------------------------------------------------
_TEMP_WRAPPER_CREATED=0

ensure_gradle_wrapper() {
    local pdir="$1"
    _TEMP_WRAPPER_CREATED=0

    # Only act if gradlew exists and gradle-wrapper.properties exists
    if [ -f "${pdir}/gradlew" ] && [ -f "${pdir}/gradle/wrapper/gradle-wrapper.properties" ]; then
        if [ ! -f "${pdir}/gradle/wrapper/gradle-wrapper.jar" ]; then
            local src_jar=""
            if [ -f "${_COMMON_DIR}/gradle-wrapper.jar" ]; then
                src_jar="${_COMMON_DIR}/gradle-wrapper.jar"
            elif [ -f "${REPO_ROOT}/kotlin-17-gradle/gradle/wrapper/gradle-wrapper.jar" ]; then
                src_jar="${REPO_ROOT}/kotlin-17-gradle/gradle/wrapper/gradle-wrapper.jar"
            fi

            if [ -n "$src_jar" ]; then
                mkdir -p "${pdir}/gradle/wrapper"
                cp "$src_jar" "${pdir}/gradle/wrapper/gradle-wrapper.jar"
                _TEMP_WRAPPER_CREATED=1
                echo "  [INFO] Supplied temporary gradle-wrapper.jar for wrapper compatibility..."
            fi
        fi
    fi
}

cleanup_gradle_wrapper() {
    local pdir="$1"
    if [ "${_TEMP_WRAPPER_CREATED:-0}" = "1" ]; then
        rm -f "${pdir}/gradle/wrapper/gradle-wrapper.jar"
        echo "  [INFO] Removed temporary gradle-wrapper.jar (project untouched)"
        _TEMP_WRAPPER_CREATED=0
    fi
}

# -----------------------------------------------------------------------------
# ensure_gradle_dependency_analysis / cleanup_gradle_dependency_analysis
#   Temporarily injects dependency-analysis plugin for Gate 1 if missing,
#   and cleanly restores the original build script right after Gate 1.
# -----------------------------------------------------------------------------
_TEMP_BUILD_FILE_BACKED_UP=0

ensure_gradle_dependency_analysis() {
    local pdir="$1"
    _TEMP_BUILD_FILE_BACKED_UP=0

    local bfile=""
    if [ -f "${pdir}/build.gradle.kts" ]; then
        bfile="${pdir}/build.gradle.kts"
    elif [ -f "${pdir}/build.gradle" ]; then
        bfile="${pdir}/build.gradle"
    fi

    [ -z "$bfile" ] && return 0

    if grep -q 'com\.autonomousapps\.dependency-analysis' "$bfile"; then
        return 0
    fi

    echo "  [INFO] Auto-injecting dependency-analysis plugin for Gate 1..."
    cp "$bfile" "${bfile}.ssdlc.bak"
    _TEMP_BUILD_FILE_BACKED_UP=1

    if [ -f "${pdir}/build.gradle.kts" ]; then
        awk '
        /plugins[[:space:]]*\{/ {
            print $0
            print "    id(\"com.autonomousapps.dependency-analysis\") version \"1.31.0\""
            next
        }
        { print }
        ' "${bfile}.ssdlc.bak" > "$bfile"
    elif [ -f "${pdir}/build.gradle" ]; then
        awk '
        /plugins[[:space:]]*\{/ {
            print $0
            print "    id \"com.autonomousapps.dependency-analysis\" version \"1.31.0\""
            next
        }
        { print }
        ' "${bfile}.ssdlc.bak" > "$bfile"
    fi
}

cleanup_gradle_dependency_analysis() {
    local pdir="$1"
    if [ "${_TEMP_BUILD_FILE_BACKED_UP:-0}" = "1" ]; then
        local bfile=""
        [ -f "${pdir}/build.gradle.kts.ssdlc.bak" ] && bfile="${pdir}/build.gradle.kts"
        [ -f "${pdir}/build.gradle.ssdlc.bak" ] && bfile="${pdir}/build.gradle"

        if [ -n "$bfile" ] && [ -f "${bfile}.ssdlc.bak" ]; then
            mv -f "${bfile}.ssdlc.bak" "$bfile"
            echo "  [INFO] Restored build file (project untouched)"
        fi
        _TEMP_BUILD_FILE_BACKED_UP=0
    fi
}

cleanup_all_gradle_temp() {
    local pdir="${1:-${PROJECT_DIR:-}}"
    if [ -n "$pdir" ]; then
        cleanup_gradle_dependency_analysis "$pdir"
        cleanup_gradle_lockfile "$pdir"
        cleanup_gradle_wrapper "$pdir"
    fi
}
