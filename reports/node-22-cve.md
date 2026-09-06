# Node.js 22 - Vulnerability Findings Report

> **SSDLC Gate 3:** Direct Visible CVE Scanning (HIGH & CRITICAL)
> Target: `/c/KK/Workspace/AntigravityProject/SSDLC_POC/nodejs-22-npm`

## Detected Vulnerabilities


### Target: `package-lock.json` (npm)

| Severity | CVE ID | Package | Installed Version | Fixed Version | Title |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **CRITICAL** | [CVE-2025-7783](https://avd.aquasec.com/nvd/cve-2025-7783) | `form-data` | `2.3.3` | `2.5.4, 3.0.4, 4.0.4` | form-data: Unsafe random function in form-data |
| **HIGH** | [CVE-2026-12143](https://avd.aquasec.com/nvd/cve-2026-12143) | `form-data` | `2.3.3` | `2.5.6, 3.0.5, 4.0.6` | form-data: form-data: Form field override via CRLF injection |
| **CRITICAL** | [CVE-2019-10744](https://avd.aquasec.com/nvd/cve-2019-10744) | `lodash` | `3.10.1` | `4.17.12` | nodejs-lodash: prototype pollution in defaultsDeep function leading to modifying properties |
| **HIGH** | [CVE-2018-16487](https://avd.aquasec.com/nvd/cve-2018-16487) | `lodash` | `3.10.1` | `>=4.17.11` | lodash: Prototype pollution in utilities function |
| **HIGH** | [CVE-2020-8203](https://avd.aquasec.com/nvd/cve-2020-8203) | `lodash` | `3.10.1` | `4.17.19` | nodejs-lodash: prototype pollution in zipObjectDeep function |
| **HIGH** | [CVE-2021-23337](https://avd.aquasec.com/nvd/cve-2021-23337) | `lodash` | `3.10.1` | `4.17.21` | nodejs-lodash: command injection via template |
