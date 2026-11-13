# Upgrade guide: v3 to v4

## Overview

OpenCTI Helm Chart v4 sets resource requests by default, requires Kubernetes 1.23 or later and ships a regenerated values schema. No data is migrated and no value is renamed, but an upgrade with your current values can leave pods `Pending` or be rejected by Helm. Check the three points below before running `helm upgrade`.

## What changes in v4

### Default resource requests

`resources` used to default to `{}`. The chart now requests the minimums from the [upstream documentation](https://docs.opencti.io/latest/deployment/overview/):

| Component | v3 default | v4 default |
|---|---|---|
| Server (`resources`) | none | requests: 2 CPU, 8Gi |
| Worker (`worker.resources`) | none | requests: 1 CPU, 128Mi per replica |

If your values already set `resources` for these components, nothing changes: your values replace the defaults.

If they do not, the pods ask for the new amounts after the upgrade. On a node without that much free capacity the new pod stays `Pending` and, with the default rolling update, the old pod keeps serving. Either give the cluster the capacity or keep a smaller footprint:

```yaml
resources:
  requests:
    cpu: 250m
    memory: 1Gi

worker:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
```

Requests also change the QoS class of these pods from `BestEffort` to `Burstable`, so the upgrade restarts them.

### Kubernetes 1.23 or later

`Chart.yaml` now declares `kubeVersion: ">=1.23.0-0"`. Helm refuses to install or upgrade on older clusters. The chart already used `autoscaling/v2`, so autoscaling did not work on those versions anyway.

### Values schema

`values.schema.json` is now generated from `values.yaml` and covers keys the previous schema ignored (`clustering`, `connectors`, `connectorsGlobal`, `gateway` and most of `worker`). Helm validates your values against it, so a value with the wrong type that used to pass can now fail, for example `replicaCount: "2"` instead of `replicaCount: 2`.

Free-form sections stay open: `env`, `resources`, the per-item lists and the subchart values accept any key. `podDisruptionBudget.maxUnavailable` accepts a number or a percentage string.

### Other changes

* In clustering mode the frontend and ingestion deployments keep `resources: {}`. Size them yourself under `clustering.frontend.resources` and `clustering.ingestion.resources`.

## Before upgrading

1. Check the cluster version:

   ```console
   kubectl version
   ```

2. Render the chart with your values. A schema error or a missing key shows up here, without touching the cluster:

   ```console
   helm template your-release-name opencti/opencti --version 4.0.0 --values your-values.yaml > /dev/null
   ```

3. If you do not set `resources`, check that a node has room for the new requests, or add the override above:

   ```console
   kubectl describe nodes | grep -A 8 "Allocated resources"
   ```

## Upgrade

```console
helm repo update
helm upgrade your-release-name opencti/opencti --version 4.0.0 --values your-values.yaml
```

## Validation

* `kubectl get pods -l app.kubernetes.io/name=opencti` shows every pod `Running` and none `Pending`
* `kubectl describe pod <server-pod>` lists the requests you expect
* The OpenCTI UI loads and you can log in

## Rollback

Nothing is migrated, so a rollback is safe:

```console
helm rollback your-release-name
helm history your-release-name
```
