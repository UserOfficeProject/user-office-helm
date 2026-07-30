# User Office Helm chart

This chart installs the User Office applications and can optionally install a
minimal, single-node RabbitMQ server. It does not install or manage PostgreSQL.

The applications connect to any PostgreSQL-compatible deployment reachable from
the cluster, including a standalone server, an in-cluster deployment, a managed
service, or an operator-managed deployment such as CloudNativePG.

## Prerequisites

- Kubernetes
- Helm 3
- A PostgreSQL database and application user for the core applications
- A second database and application user when the scheduler is enabled
- An NFS StorageClass or export when RabbitMQ persistence is enabled

The core credentials are shared by `duo-backend` and `duo-factory`.
`duo-scheduler-backend` uses the scheduler credentials. The two databases may
be hosted on the same PostgreSQL server or on separate servers.

## PostgreSQL configuration

Create a protected values file outside the repository, for example
`database-values.yaml`:

```yaml
global:
  databases:
    core:
      secretName: duo-core-database
      host: postgresql.example.internal
      port: 5432
      database: duo
      username: duo-user
      password: <core-database-password>
      sslMode: require
    scheduler:
      secretName: duo-scheduler-database
      host: postgresql.example.internal
      port: 5432
      database: scheduler
      username: scheduler-user
      password: <scheduler-database-password>
      sslMode: require
```

Set `host` to a PostgreSQL hostname that application pods can resolve and
reach, such as a Kubernetes Service name or a managed database endpoint. With
CloudNativePG, this is normally the cluster's read/write Service, for example
`my-postgres-rw.database.svc.cluster.local`.

The chart creates application Secrets containing a PostgreSQL URI and separate
connection fields. Scheduler fields are required only when `scheduler.enabled`
is `true`. Set `sslMode` to an empty string if the server does not use SSL.

Helm stores supplied values in the release Secret. Use SOPS, a secrets manager,
or another encrypted values workflow for production credentials. Avoid passing
passwords through `--set`, which can also expose them in shell history.

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

The scheduler connects to the User Office core through RabbitMQ, so the
scheduler values enable the bundled RabbitMQ server. Scheduler deployments
without RabbitMQ are rejected during Helm rendering.

## RabbitMQ configuration

The bundled chart runs the official `rabbitmq:3.13.7-management` image as a
single StatefulSet replica. It creates the `duo-rabbitmq-svcbind` Secret used
by both backend applications and imports the required exchanges, queues, and
bindings after the broker starts.

Set credentials through a protected values file:

```yaml
rabbitmq:
  enabled: true
  auth:
    username: duo-user
    password: <rabbitmq-password>
    secretName: duo-rabbitmq-svcbind
```

### Dynamic NFS provisioning

Use this mode when the cluster has an NFS provisioner and StorageClass:

```yaml
rabbitmq:
  persistence:
    enabled: true
    mode: dynamic
    storageClass: nfs-storage
    size: 8Gi
    accessModes:
      - ReadWriteMany
```

### Static NFS storage

When no dynamic provisioner is available, the chart can create a statically
bound PV and PVC:

```yaml
rabbitmq:
  persistence:
    enabled: true
    mode: static
    size: 8Gi
    accessModes:
      - ReadWriteMany
    mountOptions:
      - nfsvers=4.1
    static:
      server: nfs.example.internal
      path: /exports/user-office/rabbitmq
```

The static PV and PVC use the `Retain` policy and Helm keep annotations. They
remain after uninstall and must be removed manually. The NFS export must
already be writable by UID and GID `999`; root-squashed permissions cannot be
repaired by the RabbitMQ pod.

### Existing PVC

To use storage managed outside this release:

```yaml
rabbitmq:
  persistence:
    enabled: true
    mode: existing
    existingClaim: rabbitmq-data
```

Set `rabbitmq.persistence.enabled` to `false` for disposable environments. The
broker then uses `emptyDir`, and all state is lost when its pod is replaced.

Within the namespace, the management API and UI are available on
`duo-rabbitmq:15672`, AMQP on `duo-rabbitmq:5672`, and Prometheus metrics on
`duo-rabbitmq:15692`. The Service is not exposed outside the cluster.

This chart deliberately deploys one RabbitMQ node. Persistent storage protects
against pod replacement but does not provide high availability.

## Configuration

| Parameter                                       | Description                              | Default                            |
| ----------------------------------------------- | ---------------------------------------- | ---------------------------------- |
| `global.databases.core.secretName`              | Generated core application Secret name   | `duo-core-database`                |
| `global.databases.core.host`                    | Resolvable PostgreSQL host               | Required                           |
| `global.databases.core.port`                    | PostgreSQL port                          | `5432`                             |
| `global.databases.core.database`                | Core database name                       | Required                           |
| `global.databases.core.username`                | Core database user                       | Required                           |
| `global.databases.core.password`                | Core database password                   | Required                           |
| `global.databases.core.sslMode`                 | Core PostgreSQL SSL mode                 | `require`                          |
| `global.databases.scheduler.secretName`         | Generated scheduler database Secret name | `duo-scheduler-database`           |
| `global.databases.scheduler.*`                  | Other scheduler connection settings      | Required when scheduler is enabled |
| `duo-frontend.ingress.host`                     | Frontend hostname                        | `localhost`                        |
| `duo-backend.ingress.host`                      | Backend hostname                         | `localhost`                        |
| `duo-backend.configmap.data.AUTH_CLIENT_ID`     | OpenID client ID                         | Empty                              |
| `duo-backend.configmap.data.AUTH_CLIENT_SECRET` | OpenID client secret                     | Empty                              |
| `duo-backend.configmap.data.AUTH_DISCOVERY_URL` | Full OpenID discovery endpoint           | Empty                              |
| `rabbitmq.enabled`                              | Install RabbitMQ for application events  | `false`                            |
| `rabbitmq.image.tag`                            | RabbitMQ image tag                       | `3.13.7-management`                |
| `rabbitmq.auth.username`                        | RabbitMQ application user                | Required when enabled              |
| `rabbitmq.auth.password`                        | RabbitMQ application password            | Required when enabled              |
| `rabbitmq.auth.secretName`                      | Application connection Secret            | `duo-rabbitmq-svcbind`             |
| `rabbitmq.persistence.enabled`                  | Persist RabbitMQ data                    | `false`                            |
| `rabbitmq.persistence.mode`                     | `dynamic`, `static`, or `existing`       | `dynamic`                          |
| `rabbitmq.persistence.storageClass`             | Dynamic PVC StorageClass                 | `nfs-storage`                      |
| `rabbitmq.persistence.size`                     | Requested storage capacity               | `8Gi`                              |
| `rabbitmq.persistence.existingClaim`            | Existing-mode PVC name                   | Empty                              |
| `rabbitmq.persistence.static.server`            | Static-mode NFS server                   | Required for static mode           |
| `rabbitmq.persistence.static.path`              | Static-mode NFS export path              | Required for static mode           |

## Uninstalling the chart

```console
helm uninstall user-office-app
```

This removes resources managed by the Helm release. It does not remove or
modify the PostgreSQL server, databases, or users. Static RabbitMQ PV/PVC
resources are retained, and an existing PVC is never managed or deleted by this
chart.
