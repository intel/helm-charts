# Dynamic Resource Allocation (DRA) Intel Drivers Helm Chart

## The chart installs following resource drivers:

- [GPU](https://github.com/intel-innersource/containers.orchestrators.kubernetes.intel-resource-drivers-for-kubernetes/doc/gpu/README.md)
- [Gaudi](https://github.com/intel-innersource/containers.orchestrators.kubernetes.intel-resource-drivers-for-kubernetes/doc/gaudi/README.md)

More info: [Intel Resource Drivers for Kubernetes](https://github.com/intel-innersource/containers.orchestrators.kubernetes.intel-resource-drivers-for-kubernetes)

## Get Helm Repository Info
```
helm repo add intel https://intel.github.io/helm-charts/
helm repo update
```

You can execute `helm search repo intel` command to see pulled charts [optional].

## Install Helm Chart
```
helm install intel-resource-drivers intel/intel-resource-drivers --set gpu.enabled=true --set gaudi.enabled=true
```
## Upgrade Chart
```
helm upgrade intel-resource-drivers intel/intel-resource-drivers [flags]
```

## Uninstall Chart
```
helm uninstall intel-resource-drivers
```

## Configuration
See [Customizing the Chart Before Installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with detailed comments:

```console
helm show values intel/intel-resource-drivers
```

You may also run `helm show values` on this chart's dependencies for additional options.

| Key | Type | Default |
|-----|------|---------|
| gpu.image.repository | string | `intel` |
| gpu.image.name | string | `"intel-gpu-resource-driver"` |
| gpu.image.pullPolicy | string | `"IfNotPresent"` |
| gpu.image.tag | string | `"v0.5.1"` |
| gaudi.image.repository | string | `intel` |
| gaudi.image.name | string | `"intel-gaudi-resource-driver"` |
| gaudi.image.pullPolicy | string | `"IfNotPresent"` |
| gaudi.image.tag | string | `"v0.1.1"` |

If you change the image tag to be used in Helm chart deployment, ensure that the version of the container image is consistent with CRDs and deployment YAMLs - they might change between releases.

> [!Note]
> Helm does not support _upgrading_ (or deleting) CRDs to prevent data loss. Only installing CRDs is supported. Details: https://github.com/helm/community/blob/main/hips/hip-0011.md