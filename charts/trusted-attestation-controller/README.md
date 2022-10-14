# Trusted Attestation Controller Helm Chart

Trusted Attestation Controller (TAC) is a K8s controller for reconciling the [QuoteAttestation](https://github.com/intel/trusted-certificate-issuer/blob/main/api/v1alpha1/quoteattestation_types.go) requests initiated by the [Trusted Certificate Service (TCS)](https://github.com/intel/trusted-certificate-issuer). It is a proxy between the TCS and the key server(s) which supports attestation services. The key servers could plugin to the controller by implementing the API provided by the controller.

To learn more check the documentation [here](https://github.com/intel/trusted-attestation-controller).

## Prerequisites

Prerequisites for building and running Trusted Attestation Controller:

- Kubernetes cluster with running [Trusted Certificate Service](https://github.com/intel/trusted-certificate-issuer)
- Either KMRA or a KMIP-compliant key server exposed via iSecL's Key Broker Service

## Installing the Helm Chart

Use the following command to install TAC.

The Intel's Helm Chart repository:

```console
$ helm repo add intel https://intel.github.io/helm-charts
$ helm repo update
```

Install the chart:

```console
$ helm install tac intel/trusted-attestation-controller -n intel-system --create-namespace
```

Use the following command to verify the installation status.

```console
$ helm ls -n intel-system
```

## Uninstalling the Chart

In case you want to uninstall TAC, use the following command:

```console
$ helm delete tac -n intel-system
```

## Configuration

The following table lists the configurable parameters of the trusted-attestation-controller chart and their default values. You can change the default values either via `helm --set <parameter=value>` or editing the `values.yaml` and passing the file to helm via `helm install -f values.yaml ...` option.

| Parameter | Description | Default 
| --- | --- | --- |
| `image.hub`| Image repository | docker.io |
| `image.name`| Image name | intel/trusted-attestation-controller |
| `image.tag`| Image tag | Chart's appVersion |
| `image.pullPolicy`| Image pull policy | IfNotPresent |
| `plugin`| Name of the plugin to use with TAC | "" |
| `serviceAccountName`| Service account name | tac-svcact |
| `metricsPort`| Metrics port | 8443 |
| `replicas`| Replica count | 1 |
| `controller.image`| Controller image | .image |
| `controller.limits.cpu`| CPU limit | 200m |
| `controller.limits.memory`| Memory limit | 100Mi |
| `controller.requests.cpu`| CPU request | 100m |
| `controller.requests.memory`| Memory request | 20Mi |
| `nullPlugin.image`| Plugin image | .image |
| `nullPlugin.limits.cpu`| CPU limit | 500m |
| `nullPlugin.limits.memory`| Memory limit | 100Mi |
| `nullPlugin.requests.cpu`| CPU request | 100m |
| `nullPlugin.requests.memory`| Memory request | 20Mi |
| `kmraPlugin.image`| Plugin image | .image |
| `kmraPlugin.limits.cpu`| CPU limit | 500m |
| `kmraPlugin.limits.memory`| Memory limit | 100Mi |
| `kmraPlugin.requests.cpu`| CPU request | 100m |
| `kmraPlugin.requests.memory`| Memory request | 20Mi |
| `kmraPlugin.server.url`| Server URL | "" |
| `kmraPlugin.server.tls.caCrt`| caCrt | "" |
| `kmraPlugin.server.url.tls.clientCrt`| clientCrt | "" |
| `kmraPlugin.server.url.tls.clientKey`| clientKey | "" |
| `iseclPlugin.image`| Plugin image | .image |
| `iseclPlugin.limits.cpu`| CPU limit | 500m |
| `iseclPlugin.limits.memory`| Memory limit | 100Mi |
| `iseclPlugin.requests.cpu`| CPU request | 100m |
| `iseclPlugin.requests.memory`| Memory request | 20Mi |
| `iseclPlugin.kbs.host`| KBS server hostname | localhost |
| `iseclPlugin.kbs.port`| KBS server port number | 9443 |
| `iseclPlugin.kbs.tls.caCrt`| base64-encoded CA certificate | "" |
| `iseclPlugin.kbs.tls.clientKey`| base64-encoded client key | "" |
| `iseclPlugin.kbs.tls.clientCrt`| base64-encoded client certificate | "" |
| `iseclPlugin.kbs.token`| Bearer token to access KBS API | "" |
| `iseclPlugin.sqvs.host`| Host name | "" |
| `iseclPlugin.sqvs.port`| Port number | "" |
| `iseclPlugin.kmip.ip`| KMIP ip | "" |
| `iseclPlugin.kmip.hostname`| KMIP hostname | localhost |
| `iseclPlugin.kmip.port`| KMIP port number | 5696 |
| `iseclPlugin.kmip.username`| KMIP username | "" |
| `iseclPlugin.kmip.password`| KMIP password | "" |
| `iseclPlugin.kmip.tls.caCert`| base65-encoded CA certificate | "" |
| `iseclPlugin.kmip.tls.clientKey`| base64-encoded client key | "" |
| `iseclPlugin.kmip.tls.clientCert`| base64-encoded client certificate | "" |

## KMRA plugin configuration example

Add the configuration:

```console
export KEY_SERVER="hostname:port" # KMRA server url
export CA_CERT = "LS0tLS1CRUdJT...." # CA certificate (base64)
export CLIENT_KEY= "LS0tLS1CRUdJT..." # Client private key (base64)
export CLIENT_CERT= "LS0tLS1CRUdJ..." # Client certificate (base64)
```

Add values to values.yaml:

```yaml
# Example KMRA configuration:
cat << EOF > values.yaml
  plugin: "kmra"
  kmraPlugin:
    server:
      url: $KEY_SERVER
      tls:    
        caCrt: $CA_CERT
        clientKey: $CLIENT_KEY
        clientCert: $CLIENT_CERT
EOF
```

Install the chart with your new values:

```console
helm installl -f values.yaml tac intel/trusted-attestation-controller -n intel-system --create-namespace
```
