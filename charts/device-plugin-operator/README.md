# Intel Device Plugins Operator Helm Chart

## Prerequisites
- cert-manager
- NFD charts [optional]

## Get Helm Repository Info
```
helm repo add intel https://intel.github.io/helm-charts/
helm repo update
```

You can execute `helm search repo intel` command to see pulled charts [optional].

## Install Helm Chart
CRDs of the device plugin operator are installed as part of the chart. 

```
helm install device-plugin-operator intel/device-plugin-operator [flags] 
```

## Upgrade Chart
```
helm upgrade device-plugin-operator intel/device-plugin-operator [flags]
```

## Uninstall Chart
```
helm uninstall device-plugin-operator
```
CRDs are not uninstalled.

## Configuration
See [Customizing the Chart Before Installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with detailed comments:

```console
helm show values intel/device-plugin-operator
```

You may also run `helm show values` on this chart's dependencies for additional options.

|parameter| value |
|---------|-----------|
| `hub` | `intel` |
| `tag` | `0.24.0` |
| `pullPolicy` | `IfNotPresent` |
