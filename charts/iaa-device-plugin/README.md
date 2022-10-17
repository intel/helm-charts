# Intel IAA Device Plugin Helm Chart

## Get Helm Repository Info
```
helm repo add intel https://intel.github.io/helm-charts/
helm repo update
```

You can execute `helm search repo intel` command to see pulled charts [optional].

## Install Helm Chart
```
helm install iaa-device-plugin intel/iaa-device-plugin [flags]
```
## Upgrade Chart
```
helm upgrade iaa-device-plugin intel/iaa-device-plugin [flags]
```

## Uninstall Chart
```
helm uninstall iaa-device-plugin
```

## Configuration
See [Customizing the Chart Before Installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with detailed comments:

```console
helm show values intel/iaa-device-plugin
```

You may also run `helm show values` on this chart's dependencies for additional options.

|parameter| value |
|---------|-----------|
| `hub` | `intel` |
| `tag` | `` |
| `sharedDevNum` | `10` |
| `logLevel` | `4` |