{{/* Define common helpers for both GPU and Gaudi */}}
{{- define "resource-drivers.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* GPU specific helpers */}}
{{- define "intel-gpu-resource-driver.name" -}}
{{- default .Chart.Name .Values.gpu.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "intel-gpu-resource-driver.fullname" -}}
{{- printf "%s-gpu" (include "intel-gpu-resource-driver.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "intel-gpu-resource-driver.namespace" -}}
{{- default .Release.Namespace .Values.gpu.namespaceOverride }}
{{- end }}

{{- define "intel-gpu-resource-driver.labels" -}}
app.kubernetes.io/name: {{ include "intel-gpu-resource-driver.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ include "resource-drivers.chart" . }}
{{- end }}

{{- define "intel-gpu-resource-driver.templateLabels" -}}
app.kubernetes.io/name: {{ include "intel-gpu-resource-driver.name" . }}
{{- end }}

{{- define "intel-gpu-resource-driver.selectorLabels" -}}
app.kubernetes.io/name: {{ include "intel-gpu-resource-driver.name" . }}
{{- end }}

{{- define "intel-gpu-resource-driver.serviceAccountName" -}}
{{- if .Values.gpu.serviceAccount.create -}}
{{- default "intel-gpu-sa" .Values.gpu.serviceAccount.name -}}
{{- end -}}
{{- end }}

{{/* Define full image name for GPU */}}
{{- define "intel-gpu-resource-driver.fullimage" -}}
{{- printf "%s/%s:%s" .Values.gpu.image.repository .Values.gpu.image.name .Values.gpu.image.tag -}}
{{- end }}

{{/* Gaudi specific helpers */}}
{{- define "intel-gaudi-resource-driver.name" -}}
{{- default .Chart.Name .Values.gaudi.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "intel-gaudi-resource-driver.fullname" -}}
{{- printf "%s-gaudi" (include "intel-gaudi-resource-driver.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "intel-gaudi-resource-driver.namespace" -}}
{{- default .Release.Namespace .Values.gaudi.namespaceOverride }}
{{- end }}

{{- define "intel-gaudi-resource-driver.labels" -}}
app.kubernetes.io/name: {{ include "intel-gaudi-resource-driver.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ include "resource-drivers.chart" . }}
{{- end }}

{{- define "intel-gaudi-resource-driver.templateLabels" -}}
app.kubernetes.io/name: {{ include "intel-gaudi-resource-driver.name" . }}
{{- end }}

{{- define "intel-gaudi-resource-driver.selectorLabels" -}}
app.kubernetes.io/name: {{ include "intel-gaudi-resource-driver.name" . }}
{{- end }}

{{- define "intel-gaudi-resource-driver.serviceAccountName" -}}
{{- if .Values.gaudi.serviceAccount.create -}}
{{- default "intel-gaudi-sa" .Values.gaudi.serviceAccount.name -}}
{{- end -}}
{{- end }}

{{- define "intel-gaudi-resource-driver.fullimage" -}}
{{- printf "%s/%s:%s" .Values.gaudi.image.repository .Values.gaudi.image.name (default "latest" .Values.gaudi.image.tag) -}}
{{- end }}
