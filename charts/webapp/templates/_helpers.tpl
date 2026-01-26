{{/*
Expand the name of the chart.
*/}}
{{- define "WebApp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "WebApp.fullname" -}}
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
{{- define "WebApp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Version label for main application
*/}}
{{- define "WebApp.versionLabel" -}}
{{- if .Values.image.tag -}}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- else if .Chart.AppVersion -}}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}
{{- end -}}

{{/*
Version label for migrations
*/}}
{{- define "WebAppMigrations.versionLabel" -}}
{{- if .Values.migrationJob.image.tag -}}
app.kubernetes.io/version: {{ .Values.migrationJob.image.tag | quote }}
{{- else if .Chart.AppVersion -}}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "WebApp.labels" -}}
helm.sh/chart: {{ include "WebApp.chart" . }}
{{ include "WebApp.selectorLabels" . }}
{{ include "WebApp.versionLabel" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Migration labels
*/}}
{{- define "WebAppMigrations.labels" -}}
helm.sh/chart: {{ include "WebApp.chart" . }}
{{ include "WebAppMigrations.selectorLabels" . }}
{{ include "WebAppMigrations.versionLabel" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "WebApp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "WebApp.fullname" . | lower }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Migration selector labels
*/}}
{{- define "WebAppMigrations.selectorLabels" -}}
app.kubernetes.io/name: {{ include "WebApp.fullname" . | lower }}-migrations
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "WebApp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "WebApp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Migrations Job Name with image hash
*/}}
{{- define "WebApp.migrationJobName"}}
{{- $hash := printf "%s:%s" .Values.migrationJob.image.repository (.Values.migrationJob.image.tag | default .Chart.AppVersion) | sha256sum | trunc 10 }}
{{- $name := printf "%s-migrations-%s" (include "WebApp.fullname" .) $hash | trunc 63 | trimSuffix "-" | lower }}
{{- printf "%s" $name }}
{{- end }}
