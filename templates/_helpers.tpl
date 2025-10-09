{{- define "htpg.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "htpg.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s" (include "htpg.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "htpg.labels" -}}
app.kubernetes.io/name: {{ include "htpg.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "htpg.selectorLabels" -}}
app.kubernetes.io/name: {{ include "htpg.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "htpg.initdbScriptsChecksum" -}}
{{- if .Values.initdbScripts }}
{{- toYaml .Values.initdbScripts | sha256sum -}}
{{- else -}}
""
{{- end -}}
{{- end -}}