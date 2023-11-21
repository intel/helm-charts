# Dynamic Resource Allocation (DRA) GPU Driver Helm Chart

## Get Helm Repository Info
```
helm repo add intel https://intel.github.io/helm-charts/
helm repo update
```

You can execute `helm search repo intel` command to see pulled charts [optional].

## Install Helm Chart
CRDs of the GPU driver are installed as part of the chart first.

```
helm install intel-gpu-resource-driver intel/intel-gpu-resource-driver \
--create-namespace --namespace intel-gpu-resource-driver
```
## Upgrade Chart
```
helm upgrade intel-gpu-resource-driver intel/intel-gpu-resource-driver [flags]
```

## Uninstall Chart
```
helm uninstall intel-gpu-resource-driver --namespace intel-gpu-resource-driver
```

## Configuration
See [Customizing the Chart Before Installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with detailed comments:

```console
helm show values intel/intel-gpu-resource-driver
```

You may also run `helm show values` on this chart's dependencies for additional options.

|parameter| value |
|---------|-----------|
| `image.repository` | `intel` |
| `image.tag` | `v0.2.0` |
