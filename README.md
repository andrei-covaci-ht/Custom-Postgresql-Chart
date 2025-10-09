# custom-postgresql-chart

Single‑pod PostgreSQL Helm chart for DEV environments. No operators, no CRDs, no cluster constructs — just a clean StatefulSet + Service, PVC, optional init scripts, optional metrics.

**made by Andrei Kovaci**

---

## What this chart provides
- **Single pod PostgreSQL** on the official `postgres` image.
- **PVC via `volumeClaimTemplates`** (new volume per release). No re‑use of existing PVCs.
- **Init scripts** via `initdbScripts` (mounted to `/docker-entrypoint-initdb.d`).
- **Secrets re‑use** using `auth.existingSecret` and mappable secret keys for user/password/db.
- **Readiness & liveness probes** powered by `pg_isready`.
- **Optional metrics** using `prometheuscommunity/postgres-exporter` + optional **ServiceMonitor**.
- **Scheduling & security** knobs: `nodeSelector`, `tolerations`, `resources`, `securityContext`/`podSecurityContext`.
- **Argo CD–friendly** templates and checksum reload on init scripts.

> Note: The chart **always creates** a PVC via `volumeClaimTemplates`. The (legacy) `storage.existingClaim` value is **ignored**.

---

## Prerequisites
- Kubernetes **>= 1.22** (see `Chart.yaml` `kubeVersion`).
- Helm **v3**.
- For ServiceMonitor: the **Prometheus Operator** CRDs installed (e.g., via kube‑prometheus‑stack).

---

## Configuration
Below is a concise overview of frequently used values. See `values.yaml` for the full list.

### Image
```yaml
image:
  repository: postgres
  tag: "15.5"
  pullPolicy: IfNotPresent
```

### Authentication & secrets
You can re‑use an existing Secret and map non‑standard key names.
```yaml
auth:
  existingSecret: "postgresql"        # name of existing secret (optional)
  superuser:
    value: "postgres"                 # fallback if not taken from secret
    secretKey: ""                     # key in existingSecret for username (optional)
  superuserPassword:
    value: ""                         # only used if you generate a new secret
    secretKey: "postgres-password"    # key in existingSecret for password
  database:
    value: "postgres"
    secretKey: ""                     # key in existingSecret for database name (optional)
```
Expected default keys (if you generate the secret via chart): `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`.

### Init scripts
Provide SQL (or shell) files executed on first run. Files are projected to `/docker-entrypoint-initdb.d`.
```yaml
initdbScripts:
  01-init.sql: |
    CREATE DATABASE curdb;
    CREATE DATABASE mailservice;
    # ... add your DB list here ...
```
You may also mount an extra ConfigMap with scripts:
```yaml
extraScriptsConfigMap: ""
```

### Storage (PVC)
A new PVC is created via `volumeClaimTemplates` and mounted to `storage.dataMountPath`.
```yaml
storage:
  requestedSize: 10Gi
  className: ""         # e.g. standard
  accessModes: ["ReadWriteOnce"]
  annotations: {}
  labels: {}
  dataMountPath: "/var/lib/postgresql/data"   # PGDATA is set to <dataMountPath>/data
```
> Re‑using an existing PVC is NOT supported by this chart by design.

### Service
```yaml
service:
  type: ClusterIP
  port: 5432
```

### Metrics & monitoring
Enable the exporter and (optionally) a ServiceMonitor.
```yaml
metrics:
  enabled: false
  image:
    registry: quay.io
    repository: prometheuscommunity/postgres-exporter
    tag: v0.15.0
    pullPolicy: IfNotPresent
  datasource:
    dsn: ""            # or use secret below
    secret:
      name: ""
      key: ""
  service:
    port: 9187
    annotations: {}
    labels: {}
  serviceMonitor:
    enabled: false
    namespace: ""
    interval: 30s
    scrapeTimeout: 10s
    labels: {}
```

### Probes
Probes use `pg_isready` against localhost:5432.
```yaml
probes:
  readiness:
    enabled: true
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 6
  liveness:
    enabled: true
    initialDelaySeconds: 30
    periodSeconds: 15
    timeoutSeconds: 5
    failureThreshold: 6
```

### Scheduling & security
```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi

nodeSelector: {}
tolerations: []
affinity: {}

podSecurityContext:
  fsGroup: 999
  supplementalGroups: [999]

securityContext:
  allowPrivilegeEscalation: false
  privileged: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 999
  runAsGroup: 999
  capabilities:
    drop: ["ALL"]
```

### Names
```yaml
nameOverride: ""
fullnameOverride: ""
```

---

## Example: `values-dev.yaml`
```yaml
nameOverride: postgresql
fullnameOverride: postgresql

auth:
  existingSecret: postgresql
  superuserPassword:
    secretKey: postgres-password
  database:
    value: postgres

initdbScripts:
  01-init.sql: |
    CREATE DATABASE curdb;
    CREATE DATABASE mailservice;
    CREATE DATABASE wayforpay;

metrics:
  enabled: true
  serviceMonitor:
    enabled: true

nodeSelector:
  node.demo.net/role: database

tolerations:
  - key: node.demo.net/role
    operator: Equal
    value: database
    effect: NoSchedule

storage:
  requestedSize: 50Gi
  className: standard
```

---

## Uninstall
```bash
helm uninstall pg -n namespace-1
```

---

## Notes / Upgrading
- This chart does **not** support opening an existing data directory from a different major PostgreSQL version. Use dump/restore or `pg_upgrade` for major upgrades.
- If you change init scripts after the first boot, data won’t be re‑initialized (by design of Docker entrypoint).

---
# Custom PostgreSQL Helm Chart

Single‑pod PostgreSQL Helm chart for DEV/test environments. No operators, no CRDs, no clustering — just a clean StatefulSet + Service + PVC with optional init scripts and metrics.

**Made by Andrei Covaci**

---

## What’s included
- **Single container PostgreSQL** based on the official `postgres` image.
- **Persistent data** via `volumeClaimTemplates` (one PVC per StatefulSet replica).
- **Init scripts** (SQL/shell) mounted into `/docker-entrypoint-initdb.d` and executed on first boot.
- **Secrets re‑use** with mappable key names (username/password/database keys can be custom).
- **Readiness & liveness probes** using `pg_isready`.
- **Optional metrics** via `prometheuscommunity/postgres-exporter` and optional **ServiceMonitor**.
- **Scheduling & security knobs**: resources, node selectors/tolerations, pod & container security contexts.
- **Argo CD–friendly** templating and checksum reload on init scripts.

> Note: this chart **always creates** a PVC from `volumeClaimTemplates`. Re‑using an existing PVC is **not supported** by design.

---

## Requirements
- Kubernetes **>= 1.22**
- Helm **v3**
- (Optional) Prometheus Operator CRDs if you enable `metrics.serviceMonitor`

---

## Configuration overview (keys)
Top‑level values you’ll typically use:

- **image**: `repository`, `tag`, `pullPolicy`.
- **auth**:
  - `existingSecret`: name of a pre‑created Secret (optional).
  - `superuser.value` / `superuser.secretKey`: fallback username or key name in `existingSecret`.
  - `superuserPassword.value` / `superuserPassword.secretKey`: password value or key name in `existingSecret`.
  - `database.value` / `database.secretKey`: initial database name or key name in `existingSecret`.
- **initdbScripts**: map of filename → content to run on first initialization.
- **storage**:
  - `requestedSize`, `className`, `accessModes`, `annotations`, `labels`.
  - `dataMountPath` (PGDATA is set to `<dataMountPath>/data`).
  - PVC resizing is done by patching the PVC (if the StorageClass allows expansion), not by changing values alone.
- **service**: type/port.
- **metrics**:
  - `enabled`: enable exporter sidecar.
  - `datasource.dsn` or `datasource.secret.{name,key}`.
  - `serviceMonitor.enabled` plus optional scrape params.
- **probes**: readiness/liveness timings for `pg_isready`.
- **resources** / **nodeSelector** / **tolerations** / **affinity**.
- **security**: `podSecurityContext` and container `securityContext` (non‑root defaults).
- **nameOverride** / **fullnameOverride**.

---

## Minimal Terraform example (Argo CD Application via values)
This mirrors a common setup where Terraform renders an Argo CD chart that defines applications. Adjust names and namespaces as needed.

```hcl
# Snippet of a values file rendered by Terraform for an Argo CD "applications" chart
applications = [
  {
    name       = "postgresql-sls"
    destination = {
      namespace = "your-namespace"
    }
    source = {
      repoURL        = "https://github.com/andrei-covaci-ht/Custom-Postgresql-Chart.git"
      path           = "."
      targetRevision = "main"
      helm = {
        values = <<-EOT
          nameOverride: postgresql-sls
          fullnameOverride: postgresql-sls
          auth:
            existingSecret: postgresql
            superuserPassword:
              secretKey: postgres-password
            database:
              value: postgres
          metrics:
            enabled: true
            serviceMonitor:
              enabled: true
          storage:
            requestedSize: 50Gi
            className: standard
            accessModes: ["ReadWriteOnce"]
            dataMountPath: "/var/lib/postgresql/data"
        EOT
      }
    }
  }
]
```

---

## Notes & upgrading
- Major PostgreSQL upgrades require dump/restore or `pg_upgrade`. Do **not** point the container at an existing data directory from a different **major** version.
- Changing `initdbScripts` after the first boot does not re‑initialize data (standard Docker entrypoint behavior).

---