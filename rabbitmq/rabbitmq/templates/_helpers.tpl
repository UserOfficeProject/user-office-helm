{{/* Expand the chart name. */}}
{{- define "rabbitmq.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Create a release-scoped name. */}}
{{- define "rabbitmq.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Chart label. */}}
{{- define "rabbitmq.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Selector labels. */}}
{{- define "rabbitmq.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rabbitmq.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Common labels. */}}
{{- define "rabbitmq.labels" -}}
helm.sh/chart: {{ include "rabbitmq.chart" . }}
{{ include "rabbitmq.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Credential Secret name. */}}
{{- define "rabbitmq.secretName" -}}
{{- required "rabbitmq.auth.secretName is required" .Values.auth.secretName -}}
{{- end -}}

{{/* PersistentVolume name for static NFS mode. */}}
{{- define "rabbitmq.persistentVolumeName" -}}
{{- if .Values.persistence.static.persistentVolumeName -}}
{{- .Values.persistence.static.persistentVolumeName | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Namespace .Release.Name (include "rabbitmq.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* PersistentVolumeClaim name. */}}
{{- define "rabbitmq.persistentVolumeClaimName" -}}
{{- if eq .Values.persistence.mode "existing" -}}
{{- required "rabbitmq.persistence.existingClaim is required when persistence.mode=existing" .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-data" (include "rabbitmq.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}