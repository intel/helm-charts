# Dynamic Resource Allocation (DRA) Intel QAT Driver Helm Chart

## The chart installs QAT resource driver:

- [QAT](https://github.com/intel/intel-resource-drivers-for-kubernetes/tree/main/doc/qat/README.md)

More info: [Intel Resource Drivers for Kubernetes](https://github.com/intel/intel-resource-drivers-for-kubernetes/tree/main)


## Get Helm Repository Info
```
helm repo add intel https://intel.github.io/helm-charts/
helm repo update
```

You can execute `helm search repo intel` command to see pulled charts [optional].

## Install Helm Chart
CRDs of the qat driver are installed as part of the chart first.

```
helm install intel-qat-resource-driver intel/intel-qat-resource-driver
```
## Upgrade Chart
```
helm upgrade intel-qat-resource-driver intel/intel-qat-resource-driver [flags]
```

## Uninstall Chart
```
helm uninstall intel-qat-resource-driver --namespace intel-qat-resource-driver
```

## Configuration
See [Customizing the Chart Before Installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with detailed comments:

```console
helm show values intel/intel-qat-resource-driver
```

You may also run `helm show values` on this chart's dependencies for additional options.

| Key | Type | Default |
|-----|------|---------|
| image.repository | string | `intel` |
| image.name | string | `"intel-qat-resource-driver"` |
| image.pullPolicy | string | `"IfNotPresent"` |
| image.tag | string | `"v0.1.0"` |

If you change the image tag to be used in Helm chart deployment, ensure that the version of the container image is consistent with CRDs and deployment YAMLs - they might change between releases.

> [!Note]
> When upgrading, CRDs from previous version need to be removed manually because Helm supports neither upgrading nor deleting CRDs, see: https://github.com/helm/community/blob/main/hips/hip-0011.md
