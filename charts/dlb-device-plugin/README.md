# Intel DLB Device Plugin Helm Chart

## Get Helm Repository Info
```
helm repo add intel https://intel.github.io/helm-charts/
helm repo update
```

You can execute `helm search repo intel` command to see pulled charts [optional].

## Install Helm Chart
```
helm install dlb-device-plugin intel/intel-device-plugins-dlb [flags]
```
## Upgrade Chart
```
helm upgrade dlb-device-plugin intel/intel-device-plugins-dlb [flags]
```

## Uninstall Chart
```
helm uninstall dlb-device-plugin
```

## Configuration
See [Customizing the Chart Before Installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with detailed comments:

```console
helm show values intel/intel-device-plugins-dlb
```

You may also run `helm show values` on this chart's dependencies for additional options.

|parameter| value |
|---------|-----------|
| `image.hub` | `intel` |
| `image.tag` | `` |
| `initImage.hub` | `intel` |
| `initImage.tag` | `` |
| `logLevel` | `4` |