# User Office helm chart

This helm chart will install the entire user office platform including the PostgreSQL database.

## Prerequisites

- Kubernetes

## Installing the Chart

The user office requires OpenID Connect (OIDC) for authentication. the redirect URL to be used when setting up you OIDC provider is <HOSTNAME>/external-auth.

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

| Parameter                                       | Description                                                                    | Default     |
| ----------------------------------------------- | ------------------------------------------------------------------------------ | ----------- |
| `duo-frontend.ingress.host`                     | URL for frontend                                                               | `localhost` |
| `duo-backend.ingress.host`                      | URL for backend                                                                | `localhost` |
| `duo-backend.configmap.data.AUTH_CLIENT_ID`     | OpenID Client ID                                                               | ``          |
| `duo-backend.configmap.data.AUTH_CLIENT_SECRET` | OpenID Client Secret                                                           | ``          |
| `duo-backend.configmap.data.AUTH_DISCOVERY_URL` | OpenID well-known endpoint, include entire path                                | ``          |
| `duo-backend.configmap.data.DEPENDENCY_CONFIG`  | Sets the dependency config, see section dependency config for more information | ``          |
| `rabbitmq.enabled`                              | RabbitMQ container used by the User Office for sending events                  | `false`     |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

## Scheduler

There is the possibility to also install the scheduler module, to do this exchange the values.yaml file for values.scheduler.yaml. The scheduler will connect to the User Office core via RabbitMQ. 

## Dependency config

In order to handle the complexity of facilities having different IT-landscapes the User Office software utilizes dependency injection. For a new facility to be able to configure the usage of email services and RabbitMQ it is needed to add a new dependency file in the backend.

## RabbitMQ

The User Office software supports sending out events via RabbitMQ for third-party services to consume. To enable this feature set `rabbitmq.enabled` to true and change the dependency config.

To configure the backend the following is needed in configmap; RABBITMQ_HOSTNAME, RABBITMQ_USERNAME, RABBITMQ_CORE_EXCHANGE_NAME and in secrets; RABBITMQ_PASSWORD

## Email Services

The User Office software supports sending out emails, currently it supports SMTP and Sparkpost. To configure this look at the Dependency config section.
