# User Office helm chart

This helm chart will install the entire user office platform including the PostgreSQL database. 

## Prerequisites

- Kubernetes 

## Installing the Chart

To install the chart with the release name `user-office-app`:

```console
$  helm install -f values.yaml user-office-app \
  --set duo-backend.configmap.data.AUTH_CLIENT_ID=<AUTH_CLIENT_ID> \
  --set duo-backend.configmap.data.AUTH_CLIENT_SECRET=<AUTH_CLIENT_SECRET> \
  --set duo-backend.configmap.data.AUTH_DISCOVERY_URL=<AUTH_CLIENT_SECRET> \
  ./user-office-app    
```

This will launch the application with the hostname localhost.

## Uninstalling the Chart

To uninstall/delete the `user-office-app` deployment:

```console
$ helm delete user-office-app
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
