# Upgrade guide: v1 to v2

## Overview

OpenCTI Helm Chart v2 introduces clustering capabilities while maintaining full backward compatibility with v1 deployments. This comprehensive guide provides detailed instructions for upgrading from single-node deployments to the new [clustering architecture](https://docs.opencti.io/latest/deployment/clustering/)

## What's new in v2

### Clustering architecture

v2 introduces the ability to separate OpenCTI into two specialized clusters based on [clustering architecture](https://docs.opencti.io/latest/deployment/clustering/):

* `Frontend cluster`: handles UI, API, GraphQL endpoints and user interactions
* `Ingestion cluster`: processes data ingestion, background tasks and worker operations

### Backward compatibility

> [!IMPORTANT]
> v2 maintains complete backward compatibility. Existing v1 deployments will continue working without any configuration changes. The default behavior (`clustering.enabled: false`) preserves all existing functionality.

### Component routing changes

In **clustering mode**, components connect differently:

* Workers: connect to ingestion cluster for data processing tasks
* Connectors: connect to frontend cluster for API access
* Users: access frontend cluster via ingress for UI and API

## Prerequisites

Ensure you have the following before starting:

* Helm 3.x installed and configured
* Kubernetes cluster access with appropriate permissions
* Current OpenCTI deployment running on v1
* Backup strategy in place for critical data

## Upgrade strategies

### Strategy 1: in-place upgrade to single mode

This approach upgrades to v2 while maintaining single-node architecture.

#### Step 1: Upgrade to v2 (Single Mode)

```bash
# Add the updated Helm repository
helm repo add opencti https://devops-ia.github.io/helm-opencti
helm repo update

# Upgrade to v2 without enabling clustering
helm upgrade your-release-name opencti/opencti \
  --version 2.x.x                              \
  -f your-existing-values.yaml                 \
  --wait                                       \
  --timeout 600s
```

#### Step 2: Verification

```bash
# Verify all pods are running
kubectl get pods -l app.kubernetes.io/name=opencti

# Check services are accessible
kubectl get svc -l app.kubernetes.io/name=opencti

# Test application accessibility
kubectl port-forward svc/your-release-name-server 8080:80 &
curl -f http://localhost:8080/health
```

### Strategy 2: Migration to clustering mode

After successfully upgrading to v2, migrate to clustering architecture.

#### Step 1: Prepare clustering configuration

Create a comprehensive clustering values file:

```yaml
# clustering-migration-values.yaml

# Enable clustering mode
clustering:
  enabled: true

  # Frontend cluster configuration
  frontend:
    enabled: true
    replicaCount: 2

    # Frontend-specific environment variables
    env:
      # Disable background services that should run on ingestion
      NOTIFICATION_MANAGER__ENABLED: false
      RULE_ENGINE__ENABLED: false
      TASK_SCHEDULER__ENABLED: false
      HISTORY_MANAGER__ENABLED: false
      SYNC_MANAGER__ENABLED: false

    # Service configuration for frontend
    service:
      type: ClusterIP
      port: 80
      targetPort: 4000
      protocol: TCP
      portName: http
      appProtocol: HTTP
      labels:
        component: frontend
      extraPorts:
        - name: grpc
          port: 9000
          targetPort: 9000
          protocol: TCP
          appProtocol: GRPC

    # Ingress configuration (migrate from root level)
    ingress:
      enabled: true
      className: "nginx"  # Adjust based on your ingress controller
      annotations:
        nginx.ingress.kubernetes.io/proxy-connect-timeout: "600"
        nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
        nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
        nginx.ingress.kubernetes.io/client-max-body-size: "50m"
      hosts:
        - host: your-opencti-domain.com  # Replace with your domain
          paths:
            - path: /
              pathType: ImplementationSpecific
      tls:
        - secretName: opencti-tls
          hosts:
            - your-opencti-domain.com

    # Frontend resource allocation
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1000m"

    # Frontend autoscaling
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 8
      targetCPUUtilizationPercentage: 70
      targetMemoryUtilizationPercentage: 80

    # Frontend high availability
    podDisruptionBudget:
      enabled: true
      maxUnavailable: 1

    # Frontend monitoring
    serviceMonitor:
      enabled: true
      interval: 30s
      scrapeTimeout: 10s
      metricRelabelings: []
      relabelings: []

    # Frontend network policies
    networkPolicy:
      enabled: true
      ingress:
        - from: []  # Allow from anywhere for public access
          ports:
            - protocol: TCP
              port: 4000
        - from:
            - podSelector:
                matchLabels:
                  opencti.component: connector
          ports:
            - protocol: TCP
              port: 4000

    # Frontend topology spread
    topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: opencti
            opencti.component: frontend

    # Frontend affinity rules
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
              - key: opencti.component
                operator: In
                values:
                - frontend
            topologyKey: kubernetes.io/hostname

  # Ingestion cluster configuration
  ingestion:
    enabled: true
    replicaCount: 3

    # Ingestion service configuration
    service:
      type: ClusterIP
      port: 80
      targetPort: 4000
      protocol: TCP
      portName: http
      appProtocol: HTTP
      labels:
        component: ingestion

    # Ingestion resource allocation (typically higher than frontend)
    resources:
      requests:
        memory: "2Gi"
        cpu: "1000m"
      limits:
        memory: "4Gi"
        cpu: "2000m"

    # Ingestion autoscaling
    autoscaling:
      enabled: true
      minReplicas: 3
      maxReplicas: 15
      targetCPUUtilizationPercentage: 80
      targetMemoryUtilizationPercentage: 85

    # Ingestion high availability
    podDisruptionBudget:
      enabled: true
      maxUnavailable: 2

    # Ingestion monitoring
    serviceMonitor:
      enabled: true
      interval: 30s
      scrapeTimeout: 10s
      metricRelabelings: []
      relabelings: []

    # Ingestion network policies
    networkPolicy:
      enabled: true
      ingress:
        - from:
            - podSelector:
                matchLabels:
                  opencti.component: worker
          ports:
            - protocol: TCP
              port: 4000
        - from:
            - podSelector:
                matchLabels:
                  opencti.component: frontend
          ports:
            - protocol: TCP
              port: 4000

    # Ingestion topology spread
    topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: opencti
            opencti.component: ingestion

    # Ingestion affinity rules
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
              - key: opencti.component
                operator: In
                values:
                - ingestion
            topologyKey: kubernetes.io/hostname

# Base configuration (shared between clusters)
env:
  APP__ADMIN__EMAIL: admin@opencti.io
  APP__BASE_PATH: "/"
  APP__TELEMETRY__METRICS__ENABLED: true
  APP__GRAPHQL__PLAYGROUND__ENABLED: false
  APP__GRAPHQL__PLAYGROUND__FORCE_DISABLED_INTROSPECTION: true

  # OpenSearch configuration
  ELASTICSEARCH__ENGINE_SELECTOR: opensearch
  ELASTICSEARCH__URL: http://your-release-name-opensearch:9200

  # MinIO configuration
  MINIO__ENDPOINT: your-release-name-minio

  # RabbitMQ configuration
  RABBITMQ__HOSTNAME: your-release-name-rabbitmq
  RABBITMQ__PORT_MANAGEMENT: 15672
  RABBITMQ__PORT: 5672
  RABBITMQ__USERNAME: user

  # Redis configuration
  REDIS__HOSTNAME: your-release-name-redis
  REDIS__MODE: single
  REDIS__PORT: 6379

# Environment variables from secrets
envFromSecrets:
  APP__ADMIN__PASSWORD:
    name: your-release-name-credentials
    key: APP__ADMIN__PASSWORD
  APP__ADMIN__TOKEN:
    name: your-release-name-credentials
    key: APP__ADMIN__TOKEN
  APP__HEALTH_ACCESS_KEY:
    name: your-release-name-credentials
    key: APP__HEALTH_ACCESS_KEY
  MINIO__ACCESS_KEY:
    name: your-release-name-minio
    key: rootUser
  MINIO__SECRET_KEY:
    name: your-release-name-minio
    key: rootPassword
  RABBITMQ__PASSWORD:
    name: your-release-name-rabbitmq
    key: rabbitmq-password

# Worker configuration (connects to ingestion)
worker:
  enabled: true
  replicaCount: 2

  readyChecker:
    enabled: true
    retries: 30
    timeout: 5

  resources:
    requests:
      memory: 1Gi
      cpu: 500m
    limits:
      memory: 2Gi
      cpu: 1000m

  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 75
    targetMemoryUtilizationPercentage: 80

  lifecycle:
    preStop:
      exec:
        command: ["sh", "-c", "sleep 10"]

  terminationGracePeriodSeconds: 30

  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: opencti
          opencti.component: worker

# Connector configuration (connects to frontend)
connectorsGlobal:
  env:
    CONNECTOR_EXPOSE_METRICS: true

connectors:
  - name: opencti
    enabled: true
    replicas: 1

    image:
      repository: opencti/connector-opencti
      pullPolicy: IfNotPresent

    readyChecker:
      enabled: true
      retries: 30
      timeout: 5

    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 512Mi
        cpu: 250m

    env:
      CONNECTOR_ID: "your-connector-id"  # Generate a unique UUID
      CONNECTOR_NAME: "OpenCTI-Cluster"
      CONNECTOR_SCOPE: "marking-definition,identity,location"
      CONNECTOR_TYPE: EXTERNAL_IMPORT
      CONNECTOR_LOG_LEVEL: info

    lifecycle:
      preStop:
        exec:
          command: ["sh", "-c", "sleep 5"]

    terminationGracePeriodSeconds: 20

# Dependency configurations (adjust based on your current setup)
opensearch:
  enabled: true
  fullnameOverride: your-release-name-opensearch

  opensearchJavaOpts: "-Xmx2G -Xms2G"
  singleNode: true

  config:
    opensearch.yml: |
      plugins.security.disabled: true
      cluster.routing.allocation.disk.threshold_enabled: false

  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "4Gi"
      cpu: "2000m"

  persistence:
    enabled: true
    size: 50Gi

minio:
  enabled: true
  fullnameOverride: your-release-name-minio

  mode: standalone
  rootUser: minio
  rootPassword: your-secure-password

  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 1Gi
      cpu: 500m

  persistence:
    enabled: true
    size: 100Gi

rabbitmq:
  enabled: true
  fullnameOverride: your-release-name-rabbitmq

  auth:
    username: user
    password: your-secure-password
    erlangCookie: your-erlang-cookie

  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 1Gi
      cpu: 500m

  persistence:
    enabled: true
    size: 10Gi

redis:
  enabled: true
  fullnameOverride: your-release-name-redis

  resources:
    requests:
      memory: 512Mi
      cpu: 100m
    limits:
      memory: 1Gi
      cpu: 250m

  persistence:
    enabled: true
    size: 10Gi
```

#### Step 2: Deploy clustering configuration

```bash
# Perform the clustering migration
helm upgrade your-release-name opencti/opencti \
  --version 2.x.x                              \
  -f clustering-migration-values.yaml          \
  --wait                                       \
  --timeout 900s

# Monitor the deployment
watch kubectl get pods -l app.kubernetes.io/name=opencti
```

#### Step 3: Comprehensive verification

```bash
# Verify all cluster components
kubectl get pods -l app.kubernetes.io/name=opencti -o wide

# Check frontend cluster
kubectl get pods -l opencti.component=frontend
kubectl get svc -l opencti.component=frontend

# Check ingestion cluster
kubectl get pods -l opencti.component=ingestion
kubectl get svc -l opencti.component=ingestion

# Verify workers are connecting to ingestion
kubectl logs -f -l opencti.component=worker

# Verify connectors are connecting to frontend
kubectl logs -f -l opencti.component=connector

# Check ingress configuration
kubectl get ingress
kubectl describe ingress your-release-name-frontend

# Test frontend accessibility
kubectl port-forward svc/your-release-name-frontend 8080:80 &
curl -f http://localhost:8080/health

# Test ingestion accessibility (internal)
kubectl port-forward svc/your-release-name-ingestion 8081:80 &
curl -f http://localhost:8081/health
```

## Configuration migration details

### Service name changes

| v1 Service | v2 Single Mode | v2 Clustering Mode |
|------------|----------------|-------------------|
| `{release}-server` | `{release}-server` | `{release}-frontend`<br>`{release}-ingestion` |

### Component connectivity matrix

| Component | v1 Target | v2 Single Mode | v2 Clustering Mode |
|-----------|-----------|----------------|-------------------|
| Users (Ingress) | `{release}-server` | `{release}-server` | `{release}-frontend` |
| Workers | `{release}-server` | `{release}-server` | `{release}-ingestion` |
| Connectors | `{release}-server` | `{release}-server` | `{release}-frontend` |

### Environment

#### Frontend variables

```yaml
clustering:
  frontend:
    env:
      # Disable background services on frontend
      NOTIFICATION_MANAGER__ENABLED: false
      RULE_ENGINE__ENABLED: false
      TASK_SCHEDULER__ENABLED: false
      HISTORY_MANAGER__ENABLED: false
      SYNC_MANAGER__ENABLED: false
```

#### Ingestion variables

```yaml
clustering:
  ingestion:
    env:
      ...
```

### Monitoring and observability

#### Metrics configuration

```yaml
# Global metrics configuration
env:
  APP__TELEMETRY__METRICS__ENABLED: true
  APP__TELEMETRY__METRICS__EXPORTER_PROMETHEUS: 14269

# Frontend metrics
clustering:
  frontend:
    serviceMonitor:
      enabled: true
      interval: 30s
      path: /metrics
      scrapeTimeout: 10s
      metricRelabelings:
        - sourceLabels: [__name__]
          regex: 'opencti_frontend_(.+)'
          targetLabel: 'frontend_metric'
      relabelings:
        - sourceLabels: [__meta_kubernetes_pod_name]
          targetLabel: 'pod'

# Ingestion metrics
clustering:
  ingestion:
    serviceMonitor:
      enabled: true
      interval: 30s
      path: /metrics
      scrapeTimeout: 10s
      metricRelabelings:
        - sourceLabels: [__name__]
          regex: 'opencti_ingestion_(.+)'
          targetLabel: 'ingestion_metric'
```

#### Health check endpoints

| Component | Health Check URL | Purpose |
|-----------|------------------|---------|
| Frontend | `http://{frontend-svc}/health` | UI/API availability |
| Ingestion | `http://{ingestion-svc}/health` | Processing capability |
| Workers | Pod logs | Connection status |
| Connectors | Pod logs | API connectivity |

## Migration validation

### Functional testing

#### User interface testing

```bash
# Test web interface access
kubectl port-forward svc/your-release-name-frontend 8080:80 &

# Open browser and verify:
# * Login functionality
# * Dashboard loading
# * Data visualization
# * User management
# * Configuration access
```

#### Connector testing

```bash
# Check connector logs for successful connection
kubectl logs -f -l opencti.component=connector

# Verify connector registration in UI
# Navigate to Settings -> Connectors
# Confirm all connectors are listed and active
```

#### Worker testing

```bash
# Check worker logs for ingestion connection
kubectl logs -f -l opencti.component=worker

# Test job processing
# Create a test import job in the UI
# Monitor worker logs for job pickup and processing
```

#### Capacity testing

```yaml
# Stress test configuration
clustering:
  frontend:
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 10
      targetCPUUtilizationPercentage: 50  # Lower threshold for testing

  ingestion:
    autoscaling:
      enabled: true
      minReplicas: 3
      maxReplicas: 15
      targetCPUUtilizationPercentage: 50  # Lower threshold for testing
```

## Rollback

### Rollback to v1

```bash
# Quick rollback to previous version
helm rollback your-release-name

# Verify rollback
helm history your-release-name
kubectl get pods -l app.kubernetes.io/name=opencti
```

### Disable clustering (stay on v2)

```yaml
# clustering-disabled-values.yaml
clustering:
  enabled: false

# Restore original ingress to root level
ingress:
  enabled: true
  hosts:
    - host: your-opencti-domain.com
      paths:
        - path: /
          pathType: ImplementationSpecific

# Keep all other v2 features
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 5
```

```bash
# Apply rollback to single mode
helm upgrade your-release-name opencti/opencti \
  --version 2.x.x                              \
  -f clustering-disabled-values.yaml           \
  --wait
```

### Partial rollback scenarios

#### Disable frontend (cluster only)

```yaml
clustering:
  enabled: true
  frontend:
    enabled: false  # disable frontend cluster
  ingestion:
    enabled: true   # keep ingestion cluster

# Workers and connectors will connect to ingestion
```

#### Disable ingestion (cluster only)

```yaml
clustering:
  enabled: true
  frontend:
    enabled: true   # keep frontend cluster
  ingestion:
    enabled: false  # disable ingestion cluster

# Workers and connectors will connect to frontend
```
