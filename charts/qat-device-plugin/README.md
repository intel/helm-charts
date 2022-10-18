# Intel QAT Device Plugin Helm Chart

## Get Helm Repository Info
```
helm repo add intel https://intel.github.io/helm-charts/
helm repo update
```

You can execute `helm search repo intel` command to see pulled charts [optional].

## Install Helm Chart
```
helm install qat-device-plugin intel/qat-device-plugin [flags]
```

## Upgrade Chart
```
helm upgrade qat-device-plugin intel/qat-device-plugin [flags]
```

## Uninstall Chart
```
helm uninstall qat-device-plugin
```

## Configuration
See [Customizing the Chart Before Installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with detailed comments:

```console
helm show values intel/qat-device-plugin
```

You may also run `helm show values` on this chart's dependencies for additional options.

|parameter| value |
|---------|-----------|
| `image` | `intel/intel-qat-plugin:0.24.1` |
| `initImage` | `intel/intel-qat-initcontainer:0.24.1` |
| `dpdkDriver` | `vfio-pci` |
| `kernelVfDrivers` | `c6xxvf`, `4xxxvf` |
| `maxNumDevices` | `128` |
| `logLevel` | `4` |

