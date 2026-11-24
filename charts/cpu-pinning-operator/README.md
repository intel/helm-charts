<!--
Copyright (C) 2026 Intel Corporation
SPDX-License-Identifier: Apache-2.0
-->

# CPU Pinning Operator Helm Chart

This chart deploys the `cpu-pinning-operator`: a Kubernetes operator that pins
CPU cores for AI inference workloads (KServe, vLLM) onto dedicated, NUMA-aware
cpusets using **NRI balloons** as the pinning surface. It provisions a
per-node `BalloonsPolicy` CR and runs a mutating webhook that stamps model
pods with the balloon-selection annotation and injects the
`wait-for-balloons` init container.

## Prerequisites

- Kubernetes 1.29+ with a container runtime that has **NRI** (Node Resource
  Interface) **enabled**. containerd 2.x enables it by default; otherwise set
  `disable = false` under `[plugins."io.containerd.nri.v1.nri"]` and restart
  containerd. Tested and untested runtime versions are in the
  [compatibility table](https://github.com/intel/cpu-pinning-operator/blob/main/docs/upgrade.md#compatibility).
- Kubelet CPU Manager policy `none` on every pinning node. The `static` policy
  allocates the same CPUs as the balloons plugin. Check a node with
  `kubectl get --raw /api/v1/nodes/<node>/proxy/configz | jq -r .kubeletconfig.cpuManagerPolicy`.
- Helm 3.14+.
- **cert-manager** — the webhook needs TLS certificates. cert-manager is an
  **external prerequisite** you must install **before** this chart. Install it
  first from its own Helm chart, which provisions its CRDs (step 1 of
  [Installing the Chart](#installing-the-chart)). An opt-in escape hatch (`--set cert-manager.enabled=true`) bundles
  cert-manager as a subchart for dev/test convenience, but it is **not reliably
  single-step** on a bare cluster (see the cert-manager CRD ordering note below).

The **NRI balloons plugin** (`nri-resource-policy-balloons`) is bundled: the
subchart is on by default (`nri-resource-policy-balloons.enabled: true`), installs the
`balloonspolicies.config.nri` and `NodeResourceTopology` CRDs, and runs the DaemonSet
in the release namespace. To use a plugin you installed yourself, set
`nri-resource-policy-balloons.enabled=false`; the operator then looks for it in
`kube-system`, or in `initContainer.balloons.namespace` when set.

## Installing the Chart

Installation is a **two-step process**: install cert-manager first (see
[Prerequisites](#prerequisites)), then install this chart.

No chart repository is published: run these commands from a checkout of the
release tag (`git clone https://github.com/intel/cpu-pinning-operator`, then
`git checkout v1.0.0`).

**Step 1: Install cert-manager** (if not already present; v1.20.3 is the tested version):

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --version v1.20.3 \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true --wait
```

**Step 2: Install the operator chart** with the release name `cpu-pinning-operator`:

```bash
helm install cpu-pinning-operator deploy/cpu-pinning-operator -n cpu-pinning-operator-system --create-namespace \
  --set 'balloonPinningPolicy.match.byContainerName={vllm}' \
  --set 'balloonPinningPolicy.namespaces={inference}'
```

The chart ships no default target. With `balloonPinningPolicy.create=true` (the
default) the install fails until you set which pods to match and which namespaces to
watch; see [Pick the pods to pin](#pick-the-pods-to-pin). Set
`balloonPinningPolicy.create=false` to manage policies yourself.

It pulls the image `docker.io/intel/cpu-pinning-operator` at the chart's
`appVersion`, published with each release tag and built for linux/amd64 only. A mirrored or air-gapped cluster overrides `image.repository` with its
mirror (and `image.digest` to pin an exact build) — see
[Supplying the operator image](#supplying-the-operator-image).

The chart's `crds/` directory installs the `BalloonPinningPolicy` and
`BalloonsClusterConfig` CRDs before any templates are applied. It ships **no
cert-manager CRDs** — those come from cert-manager's own chart in step 1 (see the
cert-manager CRD ordering note below).

> **Upgrades:** Helm only installs CRDs from `crds/` on first install — it does
> **not** update them on `helm upgrade`. Apply the new chart's CRDs **before**
> `helm upgrade`, so the chart's objects are written against the new schema:
> ```bash
> kubectl apply -f deploy/cpu-pinning-operator/crds/
> ```
> The full upgrade order, including what a `helm rollback` leaves behind, is in
> [docs/upgrade.md](https://github.com/intel/cpu-pinning-operator/blob/main/docs/upgrade.md).

### Installing on OpenShift / OKD

OpenShift enforces SecurityContextConstraints (SCC) on every pod, and a clean
install of this chart fails on OpenShift without extra SCC grants (verified on
OCP 4.22, restricted SCC). Install with the shipped `values-openshift.yaml`
overlay — **no** out-of-band `oc adm policy add-scc-to-user` / `kubectl patch` is
needed:

```bash
helm install cpu-pinning-operator deploy/cpu-pinning-operator \
  -n cpu-pinning-operator-system --create-namespace \
  -f deploy/cpu-pinning-operator/values-openshift.yaml \
  --set 'balloonPinningPolicy.match.byContainerName={vllm}' \
  --set 'balloonPinningPolicy.namespaces={inference}'
```

The overlay sets two coupled toggles (Helm resolves subchart values before the
parent chart renders, so both are set in the overlay, not derived):

- `openShift.enabled=true` — renders the operator's topology-probe SCC + SA + RBAC.
- `nri-resource-policy-balloons.openshift.grant-scc=true` — makes the balloons
  subchart render its **own** least-privilege SCC and request
  `seLinuxOptions.type: spc_t` on its DaemonSet so the plugin can write its hostPath
  cache dir `/var/lib/nri-resource-policy` under SELinux enforcing (validated on
  OCP 4.22.4, CRI-O 1.35, SELinux enforcing). The subchart owns the balloons
  plugin's OpenShift admission for both the non-privileged default and the
  privileged (Priority Core Turbo) configuration; set the plugin's privilege level
  with the subchart's own values (e.g. `nri-resource-policy-balloons.allowPCT`).

#### What `openShift.enabled=true` renders

`openShift.enabled` (default `false` — vanilla clusters render no SCC resources
and no probe SA) renders exactly one SCC, the topology-probe
SCC:

- A **custom least-privilege SCC for the topology probe** (`security.openshift.io/v1`)
  that permits exactly the probe's securityContext — fixed non-root uid 1000 and the
  `RuntimeDefault` seccomp profile — with **no** privilege and **no** hostPath. No
  built-in OCP SCC allows that uid+seccomp combination (`restricted-v2` forces a uid
  from the namespace range; `anyuid`/`hostmount-anyuid` forbid the seccomp profile),
  and the probe is part of this operator, so this chart ships its SCC. It is bound (RBAC
  `use` grant) to a dedicated probe ServiceAccount, so the grant is scoped to a
  named SA and never the namespace `default` SA.

The balloons plugin's OpenShift admission comes from the subchart's
`nri-resource-policy-balloons.openshift.grant-scc` value. The manager pods pass
`restricted-v2` unchanged, so the manager SA gets no extra grant.

> **cert-manager CRD ordering.** The operator ships its own `Certificate`/`Issuer`
> (`cert-manager.io/v1`), which Helm must be able to resolve against a registered
> kind before it applies them. cert-manager ships its CRDs as chart *templates*
> (not in a `crds/` directory), so bundling it as a subchart would render those
> CRDs in the same phase as the operator's `Certificate`/`Issuer` — and on a bare
> cluster Helm would validate the operator's resources before the CRDs are
> registered, failing with `no matches for kind "Certificate"`. **Therefore
> cert-manager is an external prerequisite you install first** (step 1 above): its
> chart installs the CRDs, then this chart's templates resolve against them. This
> chart ships **no cert-manager CRDs** — they come from cert-manager's own chart.
> An opt-in escape hatch (`--set cert-manager.enabled=true`) bundles cert-manager
> as a subchart for dev/test convenience, but that configuration is **not reliably
> single-step** on a bare cluster (the CRD ordering race still applies). Prefer the
> two-step prerequisite install.

## Uninstalling the Chart

```bash
helm uninstall cpu-pinning-operator -n cpu-pinning-operator-system
```

Helm does not remove CRDs installed via `crds/` on uninstall. To remove both
operator CRDs, and with them every `BalloonPinningPolicy` and `BalloonsClusterConfig`:

```bash
kubectl delete crd balloonpinningpolicies.cpu-pinning-operator.intel.com \
  balloonsclusterconfigs.cpu-pinning-operator.intel.com
```

The bundled plugin's `balloonspolicies.config.nri` and `noderesourcetopologies` CRDs
also stay. They are shared with any other NRI plugin install, so delete them only when
no other plugin uses them.

## Configuration

### Values schema

`values.schema.json` is a hand-written JSON schema Helm applies to the coalesced
values on `helm template`, `helm install` and `helm upgrade`. A wrong value is
reported before anything is rendered, instead of reaching the API server or the
manager's flag parsing:

```console
$ helm template cpu-pinning-operator ./deploy/cpu-pinning-operator \
    --set webhook.mutatingWebhookConfiguration.failurePolicy=ignore
Error: values don't meet the specifications of the schema(s) in the following chart(s):
cpu-pinning-operator:
- webhook.mutatingWebhookConfiguration.failurePolicy: webhook.mutatingWebhookConfiguration.failurePolicy must be one of the following: "Ignore", "Fail"
```

The exact wording of these errors varies with the Helm version.

It covers the settings where a wrong value renders successfully but installs
something other than what was asked for:

| Covered | Examples |
|---------|----------|
| Enum values | `image.pullPolicy`, `log.level` (in any case, or a positive integer verbosity), `webhook.*.failurePolicy`, `podSecurityStandards.level`, `balloonsClusterConfig.balloon.cpuAllocation` / `htSiblingPolicy` / `packing`, `balloonPinningPolicy.capacityCheck.mode` / `driftPolicy` / `match.containerSelection` / `intent.coLocate` / `scheduling.nodeFeatures` values, `certManager.certificate.privateKey.algorithm` |
| Booleans gating whole templates | `metrics.enabled`, `networkPolicy.enabled`, `openShift.enabled`, `rbac.create`, `preDeleteHook.enabled`, `grafanaDashboard.enabled`, `balloonsClusterConfig.create`, `balloonPinningPolicy.create` |
| Integers with real bounds | every port (1–65535), `webhook.*.timeoutSeconds` 1–30, `balloonsClusterConfig.balloon.reserved.percent` 0–100, `.measured.headroomPercent` 0–1000, and no negative `replicaCount`, `podDisruptionBudget.minAvailable` or `initContainer.balloons.waitTimeout` |
| The image reference | `image.repository` must be non-empty; `image.tag` and `image.digest` must be strings, so an unquoted numeric tag is rejected instead of being read as a number (YAML turns `1.10` into `1.1`, which names a different image) |

`metrics.serviceMonitor.enabled` and `metrics.prometheusRule.enabled` are
nullable by default, so the schema accepts `true`, `false`, the string spelling
of either (in any case, which is how `--set-string` and Terraform's
`helm_release` pass a boolean), the empty string, and null — and rejects a word
that spells no boolean:

```console
$ helm template cpu-pinning-operator ./deploy/cpu-pinning-operator \
    --set-string metrics.serviceMonitor.enabled=maybe
Error: values don't meet the specifications of the schema(s) in the following chart(s):
cpu-pinning-operator:
- metrics.serviceMonitor.enabled: Does not match pattern '^([Tt][Rr][Uu][Ee]|[Ff][Aa][Ll][Ss][Ee])?$'
```

What it does not cover:

* **Misspelled keys.** Unknown keys are accepted at every level, because the
  subchart blocks (`cert-manager`, `nri-resource-policy-balloons`) carry their
  own value trees and several documented knobs ship commented out in
  `values.yaml`. `metrics.enabledd: true` therefore renders, with the intended
  setting left at its default.
* **`image.digest` and `webhook.service.sessionAffinity` formats.** Both are
  checked while rendering, by `_helpers.tpl` and `webhook-service.yaml`, so the
  error names the bad value rather than a schema pattern. For `image.digest` only
  the `<algorithm>:` prefix is checked, not the hex that follows it.
* **Free-form blocks.** `resources`, `probe.resources`, `securityContext`,
  `podSecurityContext`, `podAnnotations`, `nodeSelector`, `tolerations`,
  `affinity` and every label selector are typed as object or array only.
  Kubernetes validates their contents at apply time.
* **Values the manager or the API server normalises.** `initContainer.balloons.waitTimeout`
  takes a bare number of seconds or a Go duration, and `driftEviction.interval`
  and `webhook.reservationTTL` are Go durations, so they are typed but their
  format is not; an unparseable duration stops the manager at startup.
* **Cross-value rules.** Combinations such as "at most one of
  `reserved.cpus` / `percent` / `measured`" are enforced by the CRD's own
  validation, and the serving-cert requirement for a secure `ServiceMonitor`
  fails during rendering.

A test ties the schema to `values.yaml`'s top-level keys, so a new value block
cannot arrive unvalidated, and asserts both directions of the contract — the
invalid values above are rejected, and every value set the repo renders
(defaults, `values-openshift.yaml`, the chart tests' overlays) is accepted.

The following table lists the most-used parameters of the cpu-pinning-operator chart
and their default values. `values.yaml` documents every key.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of operator (manager) replicas. Defaults to 2 for HA — the manager serves an admission webhook, so a node drain or pod crash shouldn't take admission down. Leader election still elects a single active manager; the extra replicas are hot standbys that also serve the webhook. Set to `min(nodes, 3)`; the operator does not self-scale | `2` |
| `podDisruptionBudget.enabled` | Ship a `PodDisruptionBudget` for the manager so a voluntary disruption (node drain, upgrade) can't evict every replica at once. Only rendered when `replicaCount > 1` — a `minAvailable: 1` PDB on a single replica would block node drains, so it is gated off automatically | `true` |
| `podDisruptionBudget.minAvailable` | Minimum manager pods that must stay available during a voluntary disruption | `1` |
| `affinity` | Pod affinity for the manager. Empty (`{}`) applies a soft HA default: `podAntiAffinity` spreading replicas across nodes (`kubernetes.io/hostname`) plus a soft `nodeAffinity` preference toward control-plane nodes. Both soft, so a single-node cluster still schedules every replica. Set your own affinity to replace the default wholesale | `{}` |
| `image.repository` | Operator image repository. Defaults to the published Docker Hub image; override it with your mirror for a mirrored or air-gapped install — see [Supplying the operator image](#supplying-the-operator-image) | `docker.io/intel/cpu-pinning-operator` |
| `image.pullPolicy` | Image pull policy. `IfNotPresent` is correct for both reference forms the chart builds, since neither changes meaning once published | `IfNotPresent` |
| `image.tag` | Operator image tag. Empty follows the chart's `appVersion`, so the chart and the binary it asks for move together. The chart never substitutes a floating tag | `""` (→ `appVersion`) |
| `image.digest` | Digest pinning one exact operator image (`sha256:<hex>`; the algorithm prefix is required). Takes precedence over `image.tag` when both are set, and is the only reference a registry cannot move under a running Deployment. A digest without its prefix fails the render | `""` |
| `namespace.create` | Render a Namespace template for the release namespace | `false` |
| `openShift.enabled` | Render the OpenShift/OKD topology-probe SecurityContextConstraints (SCC) resources a clean install needs on OpenShift (verified failing without them on OCP 4.22): a custom least-privilege SCC for the topology probe (fixed uid 1000 + `RuntimeDefault` seccomp, no privilege/hostPath) bound to a dedicated probe SA. The balloons plugin's OpenShift admission comes from the subchart's `nri-resource-policy-balloons.openshift.grant-scc` (set in `values-openshift.yaml`). `false` renders no SCC and no probe SA, so vanilla Kubernetes is unaffected | `false` |
| `openShift.probeSCCName` | Name of the custom probe SCC. SCCs are cluster-scoped, so empty derives a per-release name from the chart fullname (`<release-fullname>-probe`) to avoid cross-release collisions; set a value to pin an explicit name | `""` (→ `<release-fullname>-probe`) |
| `openShift.probeServiceAccountName` | Dedicated ServiceAccount the probe pod runs as (created and bound to the probe SCC; wired into the manager as `PROBE_SERVICE_ACCOUNT`). Empty derives `<release-fullname>-probe`, in step with `probeSCCName`. Only used when `openShift.enabled` | `""` (→ `<release-fullname>-probe`) |
| `nri-resource-policy-balloons.openshift.grant-scc` | Balloons subchart value: render the plugin's own least-privilege OpenShift SCC and request `seLinuxOptions.type: spc_t` on its DaemonSet. Set in `values-openshift.yaml`. Provides the balloons plugin's OpenShift admission for both privileged (PCT) and non-privileged configurations | `false` |
| `serviceAccount.create` | Create service account | `true` |
| `serviceAccount.name` | Service account name | `""` (auto-generated) |
| `rbac.create` | Create RBAC resources | `true` |
| `preDeleteHook.enabled` | Run the two `helm uninstall` cleanup hook Jobs (this one flag gates both): a `pre-delete` hook that deletes the guard webhook's `ValidatingWebhookConfiguration` so `helm uninstall` exits 0 on the first try without hitting the failed-closed policy guard, and a `post-delete` hook that strips the operator-managed node labels after the manager Deployment is gone (running it earlier lets the live reconciler re-label the nodes). Each uses its own narrowly-scoped hook-only ServiceAccount + ClusterRole that are removed after the run | `true` |
| `leaderElection.enabled` | Enable leader election. The lease name is derived from the release fullname (`--leader-election-id`). Install one release per cluster: the `cluster` config, the policies and the node labels are cluster-wide | `true` |
| `driftEviction.interval` | Steady-state pace of drift-driven pod evictions (Go duration, e.g. `1m`): one eviction token replenished per interval, so a fleet-wide re-pin after a config edit rolls out at 1/interval. Widen it on a large fleet to keep the rollout gentle; tighten it on a small fleet for faster convergence. Empty uses the manager default (10s = 6/min). Threaded to `--drift-eviction-interval`. See [values.yaml](values.yaml) | *(empty → 10s)* |
| `driftEviction.burst` | Token-bucket burst size for drift-driven evictions: how many may fire back-to-back before the `interval` pace applies. `0` uses the manager default (2). Threaded to `--drift-eviction-burst` | `0` (→ 2) |
| `metrics.enabled` | Enable metrics endpoint | `true` |
| `metrics.port` | Metrics port | `8080` |
| `metrics.secure` | Serve the metrics endpoint over HTTPS using the cert-manager serving cert (the same one the webhook uses); renders the `ServiceMonitor` with `scheme: https` + CA-verifying `tlsConfig`. Set `false` only to fall back to plaintext HTTP. The server presents a certificate and does not ask for a client one — the client is identified by a bearer token instead (`metrics.requireAuth`) | `true` |
| `metrics.requireAuth` | Require every metrics client to authenticate: the manager resolves the request's bearer token with a `TokenReview` and authorizes that user for `get` on the non-resource URL `/metrics` with a `SubjectAccessReview`, so an anonymous scrape gets `401` and an unauthorized one `403`. **Bind your scraper's ServiceAccount via `metrics.readers`** or the scrape is refused. Needs `metrics.secure` (a token must not travel in the clear); set `false` only for a scraper that cannot present one, which keeps TLS and leaves `networkPolicy.metrics.from` as the only control | `true` |
| `metrics.readers` | ServiceAccounts bound to the rendered `<fullname>-metrics-reader` ClusterRole (`/metrics`, verb `get`, no API objects), as a list of `{name, namespace}`. Empty renders no binding: the chart cannot know which ServiceAccount your Prometheus runs as, and guessing would be a grant nobody asked for. Only rendered with `metrics.enabled`, `metrics.secure` and `metrics.requireAuth` | `[]` |
| `networkPolicy.enabled` | Ship a default-deny `NetworkPolicy` for the manager pod (allows only webhook, metrics, health-probe, and balloons-readiness ingress and API-server/DNS egress) | `true` |
| `networkPolicy.webhook.from` | `from` peers allowed to reach the webhook port, normally `ipBlock`s naming the control-plane addresses the API server dials from (empty = any source, which lets any pod in the cluster post a crafted `AdmissionReview` at the webhook). No pod/namespace selector can match a host-networked API server, so the CIDRs are site-specific — see [docs/secure-configuration.md](https://github.com/intel/cpu-pinning-operator/blob/main/docs/secure-configuration.md) for how to find them | `[]` |
| `networkPolicy.metrics.from` | `from` peers allowed to scrape the metrics port (empty = any source); only applied when `metrics.enabled` | `[]` |
| `networkPolicy.egress.apiServerPorts` | TCP ports outbound traffic is allowed on (any destination — the API endpoint's IPs vary per cluster, so the rule restricts ports only, not destination); empty list renders no API-server egress rule | `[443, 6443]` |
| `networkPolicy.egress.dns` | Allow outbound cluster DNS (UDP/TCP 53) | `true` |
| `healthProbe.port` | Health probe port | `8081` |
| `balloonsReady.port` | Port the manager serves the per-node balloons-readiness endpoint on (`/balloons/ready?node=`); the injected `wait-for-balloons` init container polls it | `8082` |
| `balloonsReady.secure` | Serve the readiness endpoint over HTTPS with the serving cert. The operator copies `ca.crt` into a `<fullname>-readiness-ca` ConfigMap in each namespace the webhook targets, and the init container mounts it to verify the endpoint. Needs `certManager.enabled` or `balloonsReady.allowExternalServingCert`, else the render fails. Set `false` only to fall back to plaintext HTTP | `true` |
| `balloonsReady.allowExternalServingCert` | Assert that a serving-cert secret you provision yourself (`certManager.enabled: false`) carries `ca.crt` and the `<fullname>-balloons-ready.<ns>.svc` SAN, so `balloonsReady.secure` can render | `false` |
| `webhook.caBundle` | Base64 PEM CA (`base64 -w0 ca.crt`) that signed your own serving cert, for `certManager.enabled: false`. Rendered as both webhooks' `caBundle`; the guard then keeps its configured `failurePolicy`. Empty renders the `Cg==` placeholder. Ignored with cert-manager. When the CA changes, upgrade with the new bundle | `""` |
| `webhook.port` | Port the webhook server listens on and the webhook Service targets | `9443` |
| `webhook.certDir` | Path the webhook serving cert is mounted at | `/tmp/k8s-webhook-server/serving-certs` |
| `webhook.reservationTTL` | Lifetime of the webhook's in-process admission reservation for a steered pod (Go duration, e.g. `3m`). Must outlive the NRI balloons plugin's NRT publish latency so a burst of admissions subtracts each other's not-yet-published demand. Empty uses the manager default (90s); raise it on clusters whose plugin publishes slower. Threaded to the `--reservation-ttl` flag. See [values.yaml](values.yaml) | *(empty → 90s)* |
| `webhook.reserveAuthority.enabled` | Forward only the reserve step to the leader-election lease holder, so the fleet accounts headroom against ONE store instead of one per replica. On by default because `replicaCount` is 2, and two independent stores can reserve the same per-NUMA headroom twice. Renders only when this, `replicaCount > 1`, `leaderElection.enabled` and a vouched serving cert all hold, so a single-replica install opens no listener and pays nothing. Under `capacityCheck.mode: enforce` a commit the authority cannot take DENIES the pod; `warn` (the mode default) and `off` fall back to the replica's own store | `true` |
| `webhook.reserveAuthority.port` | Port the internal mTLS reserve endpoint listens on and followers dial | `9444` |
| `webhook.reserveAuthority.allowExternalServingCert` | Assert that a serving-cert secret you provision yourself (`certManager.enabled: false`) contains `ca.crt` and a leaf with a DNS SAN. The manager exits at startup without both, so the reserve authority does not render for an out-of-band cert until you set this | `false` |
| `webhook.service.port` | Port the webhook Service exposes, which the API server calls | `443` |
| `webhook.service.sessionAffinity` | Opt-in HA bounding lever for the cross-replica reservation window. `ClientIP` pins a client (apiserver source IP) to one webhook replica so a burst from one source lands on a single in-memory reservation store instead of spreading across replicas. Empty (default) leaves it unset (`None`) | `""` |
| `webhook.mutatingWebhookConfiguration.failurePolicy` | Webhook failure policy at render time (`Ignore` fails open, `Fail` fails closed). The operator then enforces `balloonsClusterConfig.webhook.failurePolicy`, so set both | `Ignore` |
| `webhook.mutatingWebhookConfiguration.timeoutSeconds` | Webhook timeout | `10` |
| `webhook.validatingWebhookConfiguration.failurePolicy` | Failure policy for the validating guard on `BalloonPinningPolicy` delete/narrowing. Defaults to `Fail` so the safety guard can't be silently bypassed while it is down; scoped to the operator's own CRD, so an outage only delays editing a policy and never affects pod admission. Set `Ignore` to prefer availability of policy edits. Only applies with a real CA (`certManager.enabled=true` or `webhook.caBundle`): otherwise the `caBundle` is a placeholder the API server can't call, so the template forces `Ignore` regardless of this value (a `Fail` would fail-closed every policy edit) | `Fail` |
| `webhook.validatingWebhookConfiguration.timeoutSeconds` | Validating-webhook timeout | `10` |
| `webhook.targetNamespaces` | Namespaces the webhook targets at bootstrap (exact names, via `kubernetes.io/metadata.name`). Empty takes the exact names in `balloonPinningPolicy.namespaces` | `[]` |
| `webhook.namespaceSelector` | Opt-in: bootstrap the webhook's `namespaceSelector` with a label selector instead of exact names (only scopes the window before the policy reconciler takes over) | *(unset)* |
| `certManager.enabled` | Enable cert-manager integration | `true` |
| `certManager.ca.duration` | Lifetime of the chart CA that signs the serving cert, so `ca.crt` stays the same across serving-cert renewals | `8760h` |
| `certManager.certificate.secretName` | TLS certificate secret name (mounted into the manager Deployment) | `webhook-server-cert` |
| `balloonsClusterConfig.create` | Ship the singleton `BalloonsClusterConfig` CR (set `false` to manage out-of-band) | `true` |
| `balloonsClusterConfig.balloon.cpuAllocation` | `physical-cores` or `hyperthreads` (node-global) | `physical-cores` |
| `balloonsClusterConfig.balloon.reserved.cpus` | Reserved-pool size in logical CPUs (mutually exclusive with `percent` and `measured`) | `12` |
| `balloonsClusterConfig.balloon.reserved.percent` | Reserved-pool size as a percentage of physical cores (mutually exclusive with `cpus` and `measured`) | *(unset)* |
| `balloonsClusterConfig.balloon.reserved.measured.headroomPercent` | Measured-sizing mode: slack added above observed reserved-pool demand, as a percentage (0–1000). 50 = reserve 1.5× usage (mutually exclusive with `cpus` and `percent`) | *(unset; default 50 when measured is set)* |
| `balloonsClusterConfig.balloon.reserved.measured.min` | Measured-sizing mode: floor for the result and cold-start value before any usage is observed, in logical CPUs (mutually exclusive with `cpus` and `percent`) | *(unset; default 4 when measured is set)* |
| `balloonsClusterConfig.nodeConfigOverrides` | Ordered list of per-node balloon overrides for mixed-CPU fleets. Each entry is `{nodeSelector, balloon}` where `nodeSelector` (required; must be non-empty) selects a node set and `balloon` sets `cpuAllocation` and/or `reserved` (all three sizing modes — cpus/percent/measured — available). First-match-wins ordering: the first override whose selector matches a node wins, and its fields are layered per-field onto the cluster default `spec.balloon` (an unset field inherits from the default). A node matching no override keeps the cluster default. Cluster-global knobs (`webhook.failurePolicy`, `excludeNodeSelector`) are NOT overridable and stay at the top level | `[]` |
| `balloonsClusterConfig.webhook.failurePolicy` | Webhook failure policy driven from the cluster config (`Ignore`/`Fail`) | `Ignore` |
| `balloonPinningPolicy.create` | Ship a `BalloonPinningPolicy` CR. When `true`, a `match` and a namespace target are required (set `false` to manage out-of-band) | `true` |
| `balloonPinningPolicy.match.byContainerName` | Container names (or globs) the policy pins, e.g. `{vllm}`; `kserve-container` is the KServe `InferenceService` predictor. This or `byPodLabels` is required | *(unset)* |
| `balloonPinningPolicy.namespaces` | Namespaces the policy matches (exact names and/or globs). This or `namespaceSelector` is required | `[]` |
| `balloonPinningPolicy.namespaceSelector` | Opt-in: also match namespaces by label selector (unioned with `namespaces`); unset keeps exact-name mode | *(unset)* |
| `balloonPinningPolicy.guardActivePods` | Opt-in: block deleting or narrowing this policy while pods still depend on it (the validating guard rejects the change; set it to `false` to release it, which is always allowed) | *(unset, off)* |
| `securityContext` | Manager container `securityContext`. Defaults to the hardened set required by a `restricted` PSA namespace / OpenShift `restricted-v2` SCC: `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`, `seccompProfile.type: RuntimeDefault`, `allowPrivilegeEscalation: false`, `runAsNonRoot: true`, `runAsGroup: 65532`. `runAsUser` is deliberately absent: an SCC assigns the uid from the namespace range, but has no `runAsGroup` strategy, so pinning the gid (the one the image already declares) costs nothing while pinning the uid would need its own SCC. The chart mounts an `emptyDir` at `/tmp` for scratch writes (Go's `os.TempDir()`) so the manager still starts read-only-rootfs; the cert secret is mounted separately at `webhook.certDir`, and with the default `webhook.certDir` (under `/tmp`) that path is covered too. If you set `webhook.certDir` outside `/tmp` with `readOnlyRootFilesystem: true`, add a writable volume/mount for it (or relax `readOnlyRootFilesystem`). Override any key to relax it | *(hardened; see `values.yaml`)* |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `log.level` | Manager log verbosity — `debug`, `info`, `error` or `panic`, matched case-insensitively, or an integer `> 0` for finer debug levels (wired to the manager's `--zap-log-level`) | `info` |
| `log.development` | Development-mode logging: console encoder, debug level, stack traces from warn (wired to `--zap-devel`). Leave `false` in production for JSON logs | `false` |
| `probe.image` | Topology-probe container image (wired to the manager as `PROBE_IMAGE`). Empty follows the operator image (`image.repository` with `image.digest` or `image.tag`), which is what the probe needs: it runs the operator binary's `topology-probe` subcommand, so an air-gapped install mirrors only the operator image. The probe pod pulls it with the release's `imagePullSecrets` (wired to the manager as `PROBE_IMAGE_PULL_SECRETS`, JSON-encoded), so a private registry needs nothing extra. Set this only to name another mirror of that same image, e.g. `registry.example.com/cpu-pinning-operator@sha256:<digest>` | `""` (the operator image) |
| `probe.resources` | Requests and limits for the topology-probe container (wired to the manager as `PROBE_RESOURCES`, JSON-encoded). Requests are required in a namespace carrying a `LimitRange` or a requests-enforcing `ResourceQuota` — without them the probe pod is rejected and the node is never discovered. Raise a limit and its request together: a request above its own limit is refused and the built-in pair used instead | `requests: 10m/32Mi`, `limits: 100m/128Mi` |
| `probe.tolerations` | Tolerations for the topology-probe pod (wired to the manager as `PROBE_TOLERATIONS`, JSON-encoded) so it schedules on tainted nodes. Default tolerates every taint | `[{operator: Exists}]` |
| `grafanaDashboard.enabled` | Ship the Grafana dashboards: one per-machine dashboard per node (the per-core CPU map plus that machine's own metric panels, topology-sized and written by the operator) and the static cluster dashboard, all labeled for the Grafana sidecar | `false` |
| `grafanaDashboard.datasourceUid` | UID both the per-machine dashboards and the static cluster dashboard bind their `datasource` variable to. Empty (the default) leaves the variable unset so Grafana auto-selects the default Prometheus-typed data source at import — portable across clusters whose data source uid is not literally `prometheus` (e.g. OpenShift UWM/Thanos, `openshift-thanos`). Set it explicitly to pin a specific uid when auto-select is ambiguous | `""` |
| `grafanaDashboard.fleetOverview.enabled` | Ship the static cluster dashboard (cluster-wide tiles plus a table of every managed machine, each linking into its own dashboard; requires `grafanaDashboard.enabled`) | `true` |
| `grafanaDashboard.lokiLogs.enabled` | Render the operator-logs section (two template variables and a logs panel) on the cluster dashboard. Off by default and omitted from the dashboard JSON entirely when off, because a Loki datasource variable on a cluster without Loki has nothing to resolve to and Grafana then reports `Datasource was not found` on it and on the `namespace` variable bound to it. Turn it on when a Loki data source and a shipper for the operator's stdout both exist | `false` |
| `grafanaDashboard.lokiDatasourceUid` | UID of the Loki data source the operator-logs panel binds to. Empty lets the `loki` variable auto-select the single provisioned Loki data source on import (its uid is auto-assigned when Loki is provisioned without one, so it cannot be bound by name); set it explicitly if the logs panel renders empty because auto-select picked the wrong source. A non-empty value also renders the logs section on its own, without `lokiLogs.enabled` | `""` |
| `grafanaDashboard.lokiLabels.namespace` | Loki stream label the logs panel and the `namespace` variable's `label_values()` query filter on for namespace. Defaults to the OTLP/k8sattributes label (OpenTelemetry Collector → Loki `/otlp`); set to `namespace` on a promtail/loki-native cluster | `k8s_namespace_name` |
| `grafanaDashboard.lokiLabels.workload` | Loki stream label the logs panel filters on to select the operator's own logs. Defaults to the OTLP `k8s_deployment_name`; on a promtail/loki-native cluster set `app` (promtail's copy of the pod's app label, an exact match) or `pod` (matched by name prefix) | `k8s_deployment_name` |
| `grafanaDashboard.lokiLabels.node` | Loki stream label carrying the machine a line came from. Used by the per-machine page's log panel, which reads the balloons plugin's log for that machine. Defaults to the OTLP `k8s_node_name`; promtail names it `node_name` | `k8s_node_name` |
| `grafanaDashboard.lokiLabels.pluginWorkload` | Loki stream label carrying the balloons plugin's workload name. It is a DaemonSet, so under OTLP it is `k8s_daemonset_name` rather than the `k8s_deployment_name` the operator uses; promtail names it `app` | `k8s_daemonset_name` |
| `grafanaDashboard.lokiPluginName` | The balloons plugin's workload name as the log shipper labels it, matching the DaemonSet the `nri-resource-policy-balloons` subchart deploys | `nri-resource-policy-balloons` |

## Example Values

### Supplying the operator image

`image.repository` defaults to the published image
`docker.io/intel/cpu-pinning-operator`, tagged with the chart's `appVersion`. A
mirrored or air-gapped cluster mirrors that image and points `image.repository` at
the mirror, adding `imagePullSecrets` if it is private:

```yaml
image:
  repository: registry.example.com/cpu-pinning-operator
  # tag empty → the chart's appVersion
imagePullSecrets:
  - name: my-registry-pull-secret
```

The chart does **not** fall back to a floating tag such as `latest`. An install
that cannot reach its image has to fail visibly instead of pulling whatever
`latest` points at on the day: under a moving tag,
two replicas admitted minutes apart can run different binaries, and there is no
version to roll back to.

For an install that must not move at all, pin a digest. It wins over `tag` when
both are set, so an overlay can add one without first clearing the tag:

```yaml
image:
  repository: registry.example.com/cpu-pinning-operator
  digest: sha256:0000000000000000000000000000000000000000000000000000000000000000
```

`imagePullSecrets` reaches the manager, the probe and the hook Jobs only. The injected
`wait-for-balloons` init container runs in each workload's pod, which pulls with that
pod's own credentials: with a private mirror, create a pull secret in every target
namespace and add it to the workload or its ServiceAccount.

Every container that runs the operator binary — the manager, the injected
`wait-for-balloons` init container, the topology probe and the uninstall hook Jobs —
uses the reference built from these values by default. `initContainer.image` and
`probe.image` override it for the init container and the probe; an override must run
the same operator version.

### Pick the pods to pin

The KServe predictor in `inference`
([`docs/examples/values/kserve.yaml`](https://github.com/intel/cpu-pinning-operator/blob/main/docs/examples/values/kserve.yaml)):

```yaml
balloonPinningPolicy:
  match:
    byContainerName:
      - kserve-container   # KServe predictor; use vllm for a bare vLLM Deployment
  namespaces:
    - inference
```

The webhook bootstraps on the exact names in `namespaces`. Set
`webhook.targetNamespaces` only to bootstrap a different list.

### Default-deny NetworkPolicy

On by default. A `NetworkPolicy` selects the manager pod and switches it to
default-deny, re-allowing only the flows the operator needs: inbound webhook,
metrics scrape, health probes, and balloons-readiness; and outbound traffic on
the API-server ports (any destination) and cluster DNS. The webhook,
health-probe, and balloons-readiness ports are allowed from any source by default
(the API server and kubelet connect from host-networked IPs that cannot be
label-selected), so this policy's protection is mainly closing every other
port. `networkPolicy.webhook.from` narrows the webhook port to the peers your API
server dials from: `ipBlock`s naming the control-plane addresses when it is
host-networked, or a `namespaceSelector`+`podSelector` when a tunnelled control
plane proxies admission through an in-cluster agent pod. See
[docs/secure-configuration.md](https://github.com/intel/cpu-pinning-operator/blob/main/docs/secure-configuration.md#restricting-the-webhook-port),
which covers identifying the right peer for your cluster.
Set `networkPolicy.enabled: false` to turn it off. Requires a CNI that
enforces `NetworkPolicy` (Calico, Cilium, ...).

```yaml
networkPolicy:
  enabled: true
  # Optionally restrict metrics scraping to your Prometheus namespace:
  metrics:
    from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: monitoring
  # ... and admission traffic to the control-plane addresses. A wrong CIDR stops
  # admission: verify right after upgrading.
  webhook:
    from:
      - ipBlock:
          cidr: 10.0.0.0/28
```

If your API server is fronted on a non-standard port, add it under
`networkPolicy.egress.apiServerPorts` — otherwise the operator's watches and
leader election will be dropped by its own egress rule.

### Target namespaces by label instead of by name

Opt into label-selector mode so onboarding a new inference namespace is a
label, not a policy edit. The operator resolves the selector to concrete
namespace names and keeps the webhook `namespaceSelector` and the request-time
match filter in sync. An empty selector (`{}`) matches every namespace, so
scope it.

```yaml
balloonPinningPolicy:
  namespaceSelector:
    matchLabels:
      cpu-pinning-operator.intel.com/pinning: enabled
# Optional: bootstrap the webhook config with the same selector so the brief
# pre-reconcile window also targets by label.
webhook:
  namespaceSelector:
    matchLabels:
      cpu-pinning-operator.intel.com/pinning: enabled
```

### Relax the hardened container securityContext

The manager container defaults to a `securityContext` that meets the `restricted` Pod Security Standard
(read-only root filesystem, all capabilities dropped, `RuntimeDefault` seccomp).
Override individual keys to relax it — e.g. on a cluster where a sidecar needs a
writable root filesystem:

```yaml
securityContext:
  readOnlyRootFilesystem: false
```

### Fail-closed webhook (blocks pod admission if the operator is unreachable)

```yaml
webhook:
  mutatingWebhookConfiguration:
    failurePolicy: Fail
balloonsClusterConfig:
  webhook:
    failurePolicy: Fail   # the singleton reconciler otherwise resets it to Ignore
```

### Node Selector / Tolerations (e.g. pin to the control-plane node on a single-node cluster)

```yaml
nodeSelector:
  kubernetes.io/os: linux

tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"
```

### High availability (default) and single-replica installs

The manager runs 2 replicas with a `PodDisruptionBudget` by default so the
admission webhook survives a node drain or a single pod crash. Leader election
(on by default) keeps exactly one replica active; the other is a hot standby
that still serves the webhook.

**Replica spreading.** A soft `podAntiAffinity` (weight 100,
`topologyKey: kubernetes.io/hostname`) steers the replicas onto distinct nodes
so a single node loss can't take out every manager, and a soft `nodeAffinity`
preference favors control-plane nodes. Both are *soft* (preferred, not
required) so a single-node cluster still schedules every replica instead of
leaving one `Pending`. Override `affinity` to replace this wholesale — for
example, to make the anti-affinity `required` on a guaranteed-multi-node
cluster. If your control-plane nodes are tainted `NoSchedule`, add a matching
`tolerations` entry (not shipped by default).

**Replica count.** Set `replicaCount` to `min(nodes, 3)`: more replicas than
nodes buys no extra availability (the surplus co-locate and share a node's
fate) while still costing their resources, and 3 is plenty for webhook HA. The
operator does **not** self-scale — keeping the count operator-set avoids
granting the manager `apps/deployments` write RBAC. Have your deploy tooling
pass `--set replicaCount=<min(nodes,3)>` if you want it to track the node count;
adding a node later re-scales on the next deploy.

For a minimal / single-node install, drop to one replica. The PDB is gated off
automatically at `replicaCount: 1` (so it won't block drains) — no need to also
disable it:

```yaml
replicaCount: 1
```

To run more replicas, raise `minAvailable` accordingly:

```yaml
replicaCount: 3
podDisruptionBudget:
  enabled: true
  minAvailable: 2
```

### Verbose / development logging

Raise the manager's log verbosity and switch to human-readable console output
(useful when debugging placement decisions):

```yaml
log:
  level: debug
  development: true
```

`log.level` also accepts `error` (quieter) or an integer `> 0` for progressively
finer debug levels. These map to the manager's `--zap-log-level` / `--zap-devel`
flags; changing them rolls the Deployment.

## Upgrading

```bash
kubectl apply -f deploy/cpu-pinning-operator/crds/
helm upgrade cpu-pinning-operator ./deploy/cpu-pinning-operator -n cpu-pinning-operator-system
```

CRDs are **not** updated by `helm upgrade`, hence the `kubectl apply` first, and a rollback does not undo the node
labels or the rendered NRI policies. Follow
[docs/upgrade.md](https://github.com/intel/cpu-pinning-operator/blob/main/docs/upgrade.md) instead of this one-liner.

## Troubleshooting

### Check operator logs

```bash
kubectl logs -n cpu-pinning-operator-system -l app.kubernetes.io/name=cpu-pinning-operator -f
```

### Verify webhook configuration

```bash
kubectl get mutatingwebhookconfigurations | grep cpu-pinning-operator
kubectl describe mutatingwebhookconfiguration <name>
```

### Check certificates

```bash
kubectl get certificate -n cpu-pinning-operator-system
kubectl get secret webhook-server-cert -n cpu-pinning-operator-system
kubectl describe certificate -n cpu-pinning-operator-system
```

### Check node provisioning

```bash
# the release namespace for the bundled plugin; kube-system for an external one
kubectl get balloonspolicies -n cpu-pinning-operator-system
kubectl get nodes -L cpu-pinning-operator.intel.com/balloons-enabled,cpu-pinning-operator.intel.com/max-span
```

Intel, the Intel logo, Xeon and other Intel marks are trademarks of Intel Corporation or its
subsidiaries. *Other names and brands may be claimed as the property of others.
