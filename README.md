# Intel Helm Charts

## Usage

[Helm](https://helm.sh) must be installed to use the charts.
Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

Once Helm is set up properly, add the repo as follows:

```console
helm repo add intel https://intel.github.io/helm-charts
```

You can then run `helm search repo intel` to see the charts.


If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
intel` to see the charts.

To install the <chart-name> chart:

    helm install my-<chart-name> intel/<chart-name>

To uninstall the chart:

    helm delete my-<chart-name>