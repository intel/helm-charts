# Copyright (C) 2026 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

{{/*
Expand the name of the chart.
*/}}
{{- define "cpu-pinning-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cpu-pinning-operator.fullname" -}}
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
{{- define "cpu-pinning-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Reference for the operator's own image. image.digest wins when set and joins with
`@`; otherwise image.tag joins with `:`, and an empty tag follows the chart's
appVersion. A digest that does not carry its algorithm prefix fails the render
instead of producing a reference no registry can resolve.

Takes the root context (a template inside a `range` must pass `$`). Every place
that runs the operator binary — the manager container, the injected
wait-for-balloons init container, and the hook Jobs — goes through this, so all of
them ask for the same image.
*/}}
{{- define "cpu-pinning-operator.image" -}}
{{- $digest := .Values.image.digest | default "" -}}
{{- if $digest -}}
{{- if not (contains ":" $digest) -}}
{{- fail "image.digest must carry its algorithm prefix, for example sha256:<hex>" -}}
{{- end -}}
{{- printf "%s@%s" .Values.image.repository $digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cpu-pinning-operator.labels" -}}
helm.sh/chart: {{ include "cpu-pinning-operator.chart" . }}
{{ include "cpu-pinning-operator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cpu-pinning-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cpu-pinning-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
control-plane: controller-manager
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cpu-pinning-operator.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cpu-pinning-operator.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the topology-probe SCC. SCCs are cluster-scoped, so the default derives
from the release fullname to let multiple releases coexist without colliding on a
fixed cluster-wide name. Override with openShift.probeSCCName.
*/}}
{{- define "cpu-pinning-operator.probeSCCName" -}}
{{- default (printf "%s-probe" (include "cpu-pinning-operator.fullname" .)) .Values.openShift.probeSCCName }}
{{- end }}

{{/*
Name of the topology-probe ServiceAccount. Namespaced, but defaulted off the
release fullname for consistency with the SCC name. Override with
openShift.probeServiceAccountName.
*/}}
{{- define "cpu-pinning-operator.probeServiceAccountName" -}}
{{- default (printf "%s-probe" (include "cpu-pinning-operator.fullname" .)) .Values.openShift.probeServiceAccountName }}
{{- end }}

{{/*
caBundle for both webhook configurations without cert-manager: webhook.caBundle,
checked to decode to a PEM certificate, or the Cg== placeholder when unset.
Whitespace is stripped first: a line-wrapped bundle (plain base64, a YAML block
scalar, --set-file) decodes fine but would otherwise break the one-line caBundle.
*/}}
{{- define "cpu-pinning-operator.webhookCABundle" -}}
{{- with nospace (.Values.webhook.caBundle | default "") }}
{{- if not (contains "BEGIN CERTIFICATE" (b64dec .)) }}
{{- fail "webhook.caBundle must be a base64-encoded PEM CA certificate (base64 -w0 ca.crt)" }}
{{- end }}
{{- . }}
{{- else -}}
Cg==
{{- end }}
{{- end }}

{{/*
Bootstrap namespaceSelector for the mutating webhook. Empty targetNamespaces falls
back to the exact names of the chart's policy, globs dropped: a label value cannot
hold one. No names renders the closed gate the reconciler writes
(namespaceNameSelector), not an empty In, which the API server rejects.
*/}}
{{- define "cpu-pinning-operator.webhookNamespaceSelector" -}}
{{- $names := .Values.webhook.targetNamespaces }}
{{- if and (not $names) .Values.balloonPinningPolicy.create }}
{{- $names = list }}
{{- range .Values.balloonPinningPolicy.namespaces }}
{{- if not (regexMatch `[*?\[]` .) }}{{ $names = append $names . }}{{ end }}
{{- end }}
{{- end }}
{{- if hasKey .Values.webhook "namespaceSelector" }}
{{- toYaml .Values.webhook.namespaceSelector }}
{{- else if $names }}
matchExpressions:
  - key: kubernetes.io/metadata.name
    operator: In
    values:
      {{- toYaml $names | nindent 6 }}
{{- else }}
matchExpressions:
  - key: kubernetes.io/metadata.name
    operator: DoesNotExist
{{- end }}
{{- end }}

{{/*
Whether to render the leader-authoritative reserve. Non-empty means yes.

Four conditions, and every one of them is a reason the endpoint could not work
rather than a preference: the value itself, a peer to forward to, a lease to elect
the authority by, and a serving cert the manager can verify a peer against. The
manager EXITS at startup if that cert has no ca.crt or no DNS SAN, so an install
supplying its own must assert it has both via
webhook.reserveAuthority.allowExternalServingCert — otherwise the reserve stays off
and each replica keeps its own reservation store.

Kept here because the deployment and networkpolicy templates each gate twice on it,
and a copy that drifted would open a port with no rule to reach it, or the reverse.
*/}}
{{- define "cpu-pinning-operator.reserveAuthorityEnabled" -}}
{{- if and .Values.webhook.reserveAuthority.enabled
          (gt (int .Values.replicaCount) 1)
          .Values.leaderElection.enabled
          (or .Values.certManager.enabled .Values.webhook.reserveAuthority.allowExternalServingCert) -}}
yes
{{- end }}
{{- end }}

{{/*
Whether the balloons-readiness endpoint serves TLS (balloonsReady.secure). The
init container must verify it, so TLS needs a ca.crt and the balloons-ready SAN:
cert-manager provides both, and an out-of-band serving cert must assert them via
balloonsReady.allowExternalServingCert, the opt-in the reserve authority and the
ServiceMonitor use. Without either the render fails rather than ship an endpoint
nothing can verify. Read by the configmap and deployment templates.
*/}}
{{- define "cpu-pinning-operator.balloonsReadySecure" -}}
{{- if .Values.balloonsReady.secure -}}
{{- if not (or .Values.certManager.enabled .Values.balloonsReady.allowExternalServingCert) -}}
{{- fail "balloonsReady.secure=true requires a serving cert whose ca.crt and balloons-ready Service SANs the init container can verify. The chart-managed cert-manager Issuer/Certificate provides this — enable it with certManager.enabled=true. If you provision the serving-cert secret out-of-band (with ca.crt and the <fullname>-balloons-ready.<ns>.svc SAN), set balloonsReady.allowExternalServingCert=true. Or set balloonsReady.secure=false for a plaintext endpoint." -}}
{{- end -}}
yes
{{- end }}
{{- end }}

{{/*
Namespace the NRI balloons plugin's DaemonSet runs in. An explicit
initContainer.balloons.namespace always wins. Left empty, it follows where the
DaemonSet actually lands: the release namespace when this chart self-installs the
nri-resource-policy-balloons subchart, kube-system otherwise (balloons
pre-installed cluster-wide). Both the readiness check's BALLOONS_NAMESPACE and the
dashboards' log selectors read it, so they cannot disagree about where to look.
*/}}
{{- define "cpu-pinning-operator.balloonsNamespace" -}}
{{- if .Values.initContainer.balloons.namespace -}}
{{- .Values.initContainer.balloons.namespace -}}
{{- else -}}
{{- ternary .Release.Namespace "kube-system" ((index .Values "nri-resource-policy-balloons" "enabled") | default false) -}}
{{- end -}}
{{- end }}
