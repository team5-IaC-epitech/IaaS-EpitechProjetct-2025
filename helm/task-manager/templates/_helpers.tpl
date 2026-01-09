{{- define "task-manager.name" -}}
task-manager
{{- end -}}

{{- define "task-manager.fullname" -}}
{{ include "task-manager.name" . }}
{{- end -}}

{{- define "task-manager.labels" -}}
app.kubernetes.io/name: {{ include "task-manager.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}