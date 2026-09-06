{{- range . }}
  {{- if .Vulnerabilities }}
### Target: `{{ .Target }}` ({{ .Type }})

| Severity | CVE ID | Package | Installed Version | Fixed Version | Title |
| :--- | :--- | :--- | :--- | :--- | :--- |
    {{- range .Vulnerabilities }}
| **{{ .Severity }}** | [{{ .VulnerabilityID }}]({{ .PrimaryURL }}) | `{{ .PkgName }}` | `{{ .InstalledVersion }}` | `{{ .FixedVersion }}` | {{ .Title }} |
    {{- end }}

  {{- end }}
{{- end }}
