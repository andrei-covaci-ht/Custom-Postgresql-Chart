# custom-postgresql-chart

Single‑pod PostgreSQL Helm chart for DEV environments. No operators, no CRDs, no cluster constructs — just a clean StatefulSet + Service, PVC, optional init scripts, optional metrics.

**made by andrei.kovaci@hellotickets.com**

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

## Quick start

### Helm
```bash
# default (neutral) install
helm upgrade --install pg ./ht-postgresql -n mock-t1

# install with your environment overrides
helm upgrade --install pg ./ht-postgresql -n mock-t1 -f values-dev.yaml
```
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
    CREATE DATABASE t1_curator;
    CREATE DATABASE t1_mailservice;
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
    CREATE DATABASE t1_curator;
    CREATE DATABASE t1_mailservice;
    CREATE DATABASE t1_pr_broadway;

metrics:
  enabled: true
  serviceMonitor:
    enabled: true

nodeSelector:
  node.ht-services.net/role: database

tolerations:
  - key: node.ht-services.net/role
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
helm uninstall pg -n mock-t1
```

---

## Notes / Upgrading
- This chart does **not** support opening an existing data directory from a different major PostgreSQL version. Use dump/restore or `pg_upgrade` for major upgrades.
- If you change init scripts after the first boot, data won’t be re‑initialized (by design of Docker entrypoint).

---