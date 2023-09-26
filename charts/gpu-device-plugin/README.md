# Intel GPU Device Plugin Helm Chart

## Get Helm Repository Info
```
helm repo add intel https://intel.github.io/helm-charts/
helm repo update
```

You can execute `helm search repo intel` command to see pulled charts [optional].

## Install Helm Chart
```
helm install gpu-device-plugin intel/intel-device-plugins-gpu [flags]
```
## Upgrade Chart
```
helm upgrade gpu-device-plugin intel/intel-device-plugins-gpu [flags]
```

## Uninstall Chart
```
helm uninstall gpu-device-plugin
```

## Configuration
See [Customizing the Chart Before Installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with detailed comments:

```console
helm show values intel/intel-device-plugins-gpu
```

You may also run `helm show values` on this chart's dependencies for additional options.

|parameter| value |
|---------|-----------|
| `image.hub` | `intel` |
| `image.tag` | `` |
| `initImage.enable` | `false` |
| `initImage.hub` | `intel` |
| `initImage.tag` | `` |
| `sharedDevNum` | `1` |
| `resourceManager` | `false` |
| `enableMonitoring` | `true` |
| `allocationPolicy` | `none` |
| `logLevel` | `2` |
