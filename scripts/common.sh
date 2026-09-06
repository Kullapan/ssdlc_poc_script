#!/usr/bin/env bash
# =============================================================================
# common.sh — Shared cross-platform utilities for SSDLC check scripts
# Source this file: SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#                   source "${SCRIPT_DIR}/common.sh"
# =============================================================================

# Detect OS: Darwin = macOS, MINGW*/MSYS*/CYGWIN* = Windows Git Bash/MSYS2
OS_TYPE="$(uname -s)"

# Ensure working directory is always repository root, regardless of where script is called from
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_COMMON_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

_is_windows() {
    case "$OS_TYPE" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
        *) return 1 ;;
    esac
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
