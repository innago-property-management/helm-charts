{{/*
Expand the name of the chart.
*/}}
{{- define "ValkeyCluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ValkeyCluster.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ValkeyCluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ValkeyCluster.labels" -}}
helm.sh/chart: {{ include "ValkeyCluster.chart" . }}
{{ include "ValkeyCluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ValkeyCluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ValkeyCluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ValkeyCluster.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ValkeyCluster.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the appropriate apiVersion for ServiceMonitor
*/}}
{{- define "ValkeyCluster.serviceMonitor.apiVersion" -}}
monitoring.coreos.com/v1
{{- end -}}

{{/*
Generate Valkey password secret name
*/}}
{{- define "ValkeyCluster.secretName" -}}
{{- if .Values.auth.existingSecret }}
{{- .Values.auth.existingSecret }}
{{- else }}
{{- include "ValkeyCluster.fullname" . }}-auth
{{- end }}
{{- end }}

{{/*
Generate Valkey password secret key
*/}}
{{- define "ValkeyCluster.secretPasswordKey" -}}
{{- if .Values.auth.existingSecretPasswordKey }}
{{- .Values.auth.existingSecretPasswordKey }}
{{- else }}
password
{{- end }}
{{- end }}

{{/*
Generate valkey-cli command with auth handling
Usage: {{ include "ValkeyCluster.cliCommand" (dict "context" . "command" "ping") }}
*/}}
{{- define "ValkeyCluster.cliCommand" -}}
{{- if .context.Values.auth.enabled }}
valkey-cli -a $VALKEY_PASSWORD {{ .command }}
{{- else }}
valkey-cli {{ .command }}
{{- end }}
{{- end }}
