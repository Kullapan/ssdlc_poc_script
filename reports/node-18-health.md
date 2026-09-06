# Node.js 18 - Library Lifecycle & Health Report

> **SSDLC Gate 2:** EOL, Deprecated & Outdated Dependencies (Audit Only)

## Dependency Version & Lifecycle Status

| Package | Scope | Declared | Installed | Wanted | Latest | Update Status | Deprecation Status | Recommended Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `dotenv` | `dependencies` | `^16.4.5` | `16.6.1` | `16.6.1` | `17.4.2` | ⚠️ **Major update available** (v17.4.2, +1 major) | Healthy | Upgrade `package.json` to `^17.4.2` (test for breaking changes) |
| `ms` | `dependencies` | `^2.1.3` | `2.1.3` | `2.1.3` | `2.1.3` | ✅ Up to date | Healthy | No action needed (up to date) |
| `lodash` | `dependencies` | `3.10.1` | `3.10.1` | `3.10.1` | `4.18.1` | ⚠️ **Major update available** (v4.18.1, +1 major) | Healthy | Upgrade `package.json` to `^4.18.1` (test for breaking changes) |
| `request` | `dependencies` | `2.88.2` | `2.88.2` | `2.88.2` | `2.88.2` | ✅ Up to date | ⚠️ **Deprecated**: request has been deprecated, see https://github.com/request/request/issues/3142 | ⚠️ Migrate to an active alternative (deprecated) |
| `depcheck` | `devDependencies` | `^1.4.7` | `1.4.7` | `1.4.7` | `1.4.7` | ✅ Up to date | Healthy | No action needed (up to date) |
