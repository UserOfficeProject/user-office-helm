# User Office Helm chart

This chart installs the User Office applications and can optionally install a
minimal, single-node RabbitMQ server. It does not install or manage PostgreSQL.

The applications connect to any PostgreSQL-compatible deployment reachable from
the cluster, including a standalone server, an in-cluster deployment, a managed
service, or an operator-managed deployment such as CloudNativePG.

## Prerequisites

- Kubernetes
- Helm 3
- Vault Secrets Operator, with credentials stored in Vault (see below)
- A PostgreSQL database and application user for the core applications
- A second database and application user when the scheduler is enabled
- An NFS StorageClass or export when RabbitMQ persistence is enabled

The core credentials are shared by `duo-backend` and `duo-factory`.
`duo-scheduler-backend` uses the scheduler credentials. The two databases may
be hosted on the same PostgreSQL server or on separate servers.

## Secrets (Vault)

The chart does not create Kubernetes Secrets. Credentials live in Vault and
are synced by the [Vault Secrets Operator](https://developer.hashicorp.com/vault/docs/platform/k8s/vso)
(VSO): the chart renders one `VaultStaticSecret` per entry in `vault.secrets`,
and VSO writes a Secret of the same name, adopting an existing one if present.

Prerequisites:

- VSO installed, with a default `VaultConnection` and `VaultAuth` (or set
  `vault.authRef` to a `VaultAuth` the release namespace may use)
- A Vault role that lets that `VaultAuth` read the secrets below

Each Secret is read from `<vault.mount>/<vault.pathPrefix>/<name>`, for example
`static/user-office/dev/duo-core-database`:

```yaml
vault:
  mount: static
  type: kv-v2
  pathPrefix: user-office/dev
```

| Secret | Required keys | Rendered when |
|---|---|---|
| `duo-core-database` | `host`, `port`, `username`, `password`, `database`, `dbname`, `uri` | always |
| `duo-scheduler-database` | same as core | `scheduler.enabled` |
| `duo-rabbitmq-svcbind` | `host`, `port`, `username`, `password` | `rabbitmq.enabled` |
| `duo-backend-secret` | backend environment variables, e.g. `EAM_AUTH_USER` | always |

`uri` is a PostgreSQL connection string,
`postgresql://<user>:<password>@<host>:<port>/<database>[?sslmode=...]`. Set
`host` to a hostname application pods can reach; with CloudNativePG this is
normally the cluster's read/write Service, for example
`my-postgres-rw.database.svc.cluster.local`. The core database is shared by
`duo-backend` and `duo-factory`.

When a value changes in Vault, VSO updates the Secret within
`vault.refreshAfter` and restarts the workloads listed in that entry's
`rolloutRestartTargets`.

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
  --set-string duo-backend.configmap.data.AUTH_CLIENT_ID=<AUTH_CLIENT_ID> \
  --set-string duo-backend.configmap.data.AUTH_CLIENT_SECRET=<AUTH_CLIENT_SECRET> \
  --set-string duo-backend.configmap.data.AUTH_DISCOVERY_URL=<OIDC_DISCOVERY_URL>
```

To enable the scheduler, include its values file:

```console
helm upgrade --install user-office-app ./user-office-app \
  -f ./user-office-app/values.yaml \
  -f ./user-office-app/values.scheduler.yaml
```

The scheduler connects to the User Office core through RabbitMQ, so the
scheduler values enable the bundled RabbitMQ server. Scheduler deployments
without RabbitMQ are rejected during Helm rendering.

## RabbitMQ configuration

The bundled chart runs the official `rabbitmq:3.13.7-management` image as a
single StatefulSet replica. It reads its credentials from the
`duo-rabbitmq-svcbind` Secret (synced from Vault, see above), which both backend
applications also use, and imports the required exchanges, queues, and
bindings after the broker starts.

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
| `global.databases.core.secretName`              | Core database Secret name (from Vault)   | `duo-core-database`                |
| `global.databases.scheduler.secretName`         | Scheduler database Secret name           | `duo-scheduler-database`           |
| `vault.mount`                                   | Vault KV mount                           | `static`                           |
| `vault.type`                                    | `kv-v2` or `kv-v1`                       | `kv-v2`                            |
| `vault.pathPrefix`                              | Path prefix under the mount              | Required                           |
| `vault.refreshAfter`                            | How often VSO re-reads Vault             | `60s`                              |
| `vault.authRef`                                 | VaultAuth to use                         | Operator default                   |
| `vault.secrets`                                 | Secrets synced from Vault                | See `values.yaml`                  |
| `duo-frontend.ingress.host`                     | Frontend hostname                        | `localhost`                        |
| `duo-backend.ingress.host`                      | Backend hostname                         | `localhost`                        |
| `duo-backend.configmap.data.AUTH_CLIENT_ID`     | OpenID client ID                         | Empty                              |
| `duo-backend.configmap.data.AUTH_CLIENT_SECRET` | OpenID client secret                     | Empty                              |
| `duo-backend.configmap.data.AUTH_DISCOVERY_URL` | Full OpenID discovery endpoint           | Empty                              |
| `rabbitmq.enabled`                              | Install RabbitMQ for application events  | `false`                            |
| `rabbitmq.image.tag`                            | RabbitMQ image tag                       | `3.13.7-management`                |
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
