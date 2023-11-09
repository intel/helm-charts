{{/*Expand the name of the chart.*/}}
{{- define "intel-gpu-resource-driver.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*Create a default fully qualified app name.*/}}
{{- define "intel-gpu-resource-driver.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*Create chart name and version as used by the chart label.*/}}
{{- define "intel-gpu-resource-driver.chart" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" $name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*Create the name of the service account to use*/}}
{{- define "intel-gpu-resource-driver.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "intel-gpu-resource-driver.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*Create the namespace*/}}
{{- define "intel-gpu-resource-driver.namespace" -}}
{{- if .Values.namespaceOverride }}
{{- .Values.namespaceOverride }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*Common labels*/}}
{{- define "intel-gpu-resource-driver.labels" -}}
helm.sh/chart: {{ include "intel-gpu-resource-driver.chart" . }}
{{ include "intel-gpu-resource-driver.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}


{{/*Template labels*/}}
{{- define "intel-gpu-resource-driver.templateLabels" -}}
app.kubernetes.io/name: {{ include "intel-gpu-resource-driver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Values.selectorLabelsOverride }}
{{ toYaml .Values.selectorLabelsOverride }}
{{- end }}
{{- end }}

{{/*Selector labels*/}}
{{- define "intel-gpu-resource-driver.selectorLabels" -}}
{{- if .Values.selectorLabelsOverride -}}
{{ toYaml .Values.selectorLabelsOverride }}
{{- else -}}
{{ include "intel-gpu-resource-driver.templateLabels" . }}
{{- end }}
{{- end }}

{{/*
Full image name with tag
*/}}
{{- define "intel-gpu-resource-driver.fullimage" -}}
{{- $tag := printf "v%s" .Chart.AppVersion }}
{{- .Values.image.repository -}}/{{- .Values.image.name -}}:{{- .Values.image.tag | default $tag -}}
{{- end }}