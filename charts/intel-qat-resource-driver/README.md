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
When installing, update the dependencies:
```
helm dependency update
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

If you change the image tag to be used in Helm chart deployment, ensure that the version of the container image is consistent with deployment YAMLs - they might change between releases.


## Troubleshooting read-only file system error for QAT

When the following error appears in the logs of the QAT Kubelet plugin:
```
kubectl logs -n intel-qat-resource-driver intel-qat-resource-driver-kubelet-plugin-ttcs6
DRA kubelet plugin
In-cluster config
Setting up CDI
failed to create kubelet plugin driver: cannot enable PF device '0000:6b:00.0': open /sysfs/bus/pci/devices/0000:6b:00.0/sriov_numvfs: read-only file system
```

Verify the QAT driver configuration by resetting it:
```
rmmod qat_4xxx
modprobe qat_4xxx
```
