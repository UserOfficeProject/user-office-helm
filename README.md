# User Office Helm chart

This chart installs the User Office applications. It does not install or
manage PostgreSQL.

The applications can connect to any PostgreSQL-compatible deployment that is
reachable from the Kubernetes cluster, including:

- a standalone PostgreSQL server;
- PostgreSQL running elsewhere in the Kubernetes cluster;
- a managed external PostgreSQL service; or
- an operator-managed deployment such as CloudNativePG.

## Prerequisites

- Kubernetes
- Helm 3
- A PostgreSQL server with a database and application user for the core
  applications
- A second database and application user when the scheduler is enabled

The core credentials are shared by `duo-backend` and `duo-factory`.
`duo-scheduler-backend` uses the scheduler credentials. The two logical
databases may be hosted on the same PostgreSQL server or on separate servers.

## PostgreSQL configuration

Create a protected values file outside the repository, for example
`database-values.yaml`:

```yaml
global:
  databases:
    core:
      secretName: duo-database
      host: postgresql.example.internal
      port: 5432
      database: duo
      username: duo-user
      password: <core-database-password>
      sslMode: require
    scheduler:
      secretName: scheduler-database
      host: postgresql.example.internal
      port: 5432
      database: scheduler
      username: scheduler-user
      password: <scheduler-database-password>
      sslMode: require
```

Set `host` to the PostgreSQL hostname that application pods can resolve and
reach. Examples include a Kubernetes Service name, a standalone server DNS
name, or a managed database endpoint. With CloudNativePG, this is normally the
cluster's read/write Service, such as
`my-postgres-rw.database.svc.cluster.local`.

The chart creates application Secrets containing both a PostgreSQL URI and
separate connection fields. Scheduler database fields are required only when
`scheduler.enabled` is `true`. Set `sslMode` to an empty string if the target
server does not use PostgreSQL SSL.

Helm stores supplied values in the release Secret. Use SOPS, a secrets manager,
or another encrypted values workflow for production credentials. Avoid passing
passwords through `--set`, because they can also be exposed in shell history.

## Installing the chart

The User Office requires OpenID Connect (OIDC). Configure its redirect URL as
`<HOSTNAME>/external-auth`.

Build the chart dependencies:

```console
helm dependency build ./user-office-app
```

Install or upgrade the release:

```console
helm upgrade --install user-office-app ./user-office-app \
  -f ./user-office-app/values.yaml \
  -f ./database-values.yaml \
  --set-string duo-backend.configmap.data.AUTH_CLIENT_ID=<AUTH_CLIENT_ID> \
  --set-string duo-backend.configmap.data.AUTH_CLIENT_SECRET=<AUTH_CLIENT_SECRET> \
  --set-string duo-backend.configmap.data.AUTH_DISCOVERY_URL=<OIDC_DISCOVERY_URL>
```

To enable the scheduler, include its values file:

```console
helm upgrade --install user-office-app ./user-office-app \
  -f ./user-office-app/values.yaml \
  -f ./user-office-app/values.scheduler.yaml \
  -f ./database-values.yaml
```

The scheduler connects to the User Office core through RabbitMQ.

## Configuration

| Parameter                                       | Description                              | Default                            |
| ----------------------------------------------- | ---------------------------------------- | ---------------------------------- |
| `global.databases.core.secretName`              | Generated core application Secret name   | `duo-database`                     |
| `global.databases.core.host`                    | Resolvable PostgreSQL host               | Required                           |
| `global.databases.core.port`                    | PostgreSQL port                          | `5432`                             |
| `global.databases.core.database`                | Core database name                       | Required                           |
| `global.databases.core.username`                | Core database user                       | Required                           |
| `global.databases.core.password`                | Core database password                   | Required                           |
| `global.databases.core.sslMode`                 | Core PostgreSQL SSL mode                 | `require`                          |
| `global.databases.scheduler.*`                  | Equivalent scheduler connection settings | Required when scheduler is enabled |
| `duo-frontend.ingress.host`                     | Frontend hostname                        | `localhost`                        |
| `duo-backend.ingress.host`                      | Backend hostname                         | `localhost`                        |
| `duo-backend.configmap.data.AUTH_CLIENT_ID`     | OpenID client ID                         | Empty                              |
| `duo-backend.configmap.data.AUTH_CLIENT_SECRET` | OpenID client secret                     | Empty                              |
| `duo-backend.configmap.data.AUTH_DISCOVERY_URL` | Full OpenID discovery endpoint           | Empty                              |
| `rabbitmq.enabled`                              | Install RabbitMQ for application events  | `false`                            |

## Uninstalling the chart

```console
helm uninstall user-office-app
```

This removes resources managed by the Helm release. It does not remove or
modify the PostgreSQL server, databases, or users.
