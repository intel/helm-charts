# Intel SGX Device Plugin Helm Chart

## Get Helm Repository Info
```
helm repo add intel https://intel.github.io/helm-charts/
helm repo update
```

You can execute `helm search repo intel` command to see pulled charts [optional].

## Install Helm Chart
```
helm install sgx-device-plugin intel/sgx-device-plugin [flags]
```
## Upgrade Chart
```
helm upgrade sgx-device-plugin intel/sgx-device-plugin [flags]
```

## Uninstall Chart
```
helm uninstall sgx-device-plugin
```

## Configuration
See [Customizing the Chart Before Installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with detailed comments:

```console
helm show values intel/sgx-device-plugin
```

You may also run `helm show values` on this chart's dependencies for additional options.

|parameter| value |
|---------|-----------|
| `image` | `intel/intel-sgx-plugin:0.24.0` |
| `initImage` | `intel/intel-sgx-initcontainer:0.24.0` |
| `enclaveLimit` | `110` |
| `provisionLimit` | `110` |
| `logLevel` | `4` |



