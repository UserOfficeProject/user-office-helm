# User Office helm chart

This helm chart will install the entire user office platform including the PostgreSQL database. 

## Prerequisites

- Kubernetes 

## Installing the Chart

To install the chart with the release name `my-release`:

```console
$  helm install -f values.dev.yaml my-release ./user-office-app    
```


## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```console
$ helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the user-office helm chart and their default values.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `duo-frontend.ingress.host` | URL for frontend | `localhost` |
| `duo-backend.ingress.host` | URL for backend | `localhost` |
| `duo-backend.configmap.data.AUTH_CLIENT_ID` | OpenID Client ID | `` |
| `duo-backend.configmap.data.AUTH_CLIENT_SECRET` | OpenID Client Secret | `` |
| `duo-backend.configmap.data.AUTH_DISCOVERY_URL` | OpenID well-known endpoint, include entire path | `` |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,
