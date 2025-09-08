# Clustering installation

See [Customizing the chart before installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with comments:

```console
helm show values opencti/opencti
```

You may also helm show values on this chart's dependencies for additional options.

## Architecture overview

In clustering mode, OpenCTI separates into two main components:

- `Frontend cluster`: Handles UI, API, GraphQL endpoints and user interactions
- `Ingestion cluster`: Processes data ingestion, background tasks and worker operations

This separation allows for independent scaling and improved performance under heavy loads.

## Enabling clustering

To enable clustering mode, set the following in your values:

```yaml
clustering:
  enabled: true
```

## Complete clustering configuration example

```yaml
fullnameOverride: opencti-cluster

# Enable clustering mode
clustering:
  enabled: true

  # Frontend cluster configuration
  frontend:
    enabled: true
    replicaCount: 2

    # Frontend-specific environment variables
    env:
      # Disable components that should only run on ingestion
      NOTIFICATION_MANAGER__ENABLED: false
      RULE_ENGINE__ENABLED: false
      TASK_SCHEDULER__ENABLED: false

    service:
      type: ClusterIP
      port: 80
      targetPort: 4000
      protocol: TCP
      portName: http
      appProtocol: HTTP

    # Public ingress for user access
    ingress:
      enabled: true
      className: "nginx"
      annotations:
        nginx.ingress.kubernetes.io/rewrite-target: /
      hosts:
        - host: opencti.example.com
          paths:
            - path: /
              pathType: ImplementationSpecific
      tls:
        - secretName: opencti-tls
          hosts:
            - opencti.example.com

    # Frontend resources
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

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

    # Frontend network security
    networkPolicy:
      enabled: true
      ingress:
        - from:
            - namespaceSelector:
                matchLabels:
                  name: opencti-frontend
          ports:
            - protocol: TCP
              port: 4000

  # Ingestion cluster configuration
  ingestion:
    enabled: true
    replicaCount: 3

    service:
      type: ClusterIP
      port: 80
      targetPort: 4000
      protocol: TCP
      portName: http
      appProtocol: HTTP

    # Ingestion resources
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1000m"

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

    # Ingestion network security
    networkPolicy:
      enabled: true
      ingress:
        - from:
            - namespaceSelector:
                matchLabels:
                  name: opencti-ingestion
          ports:
            - protocol: TCP
              port: 4000

# Base environment configuration
env:
  APP__ADMIN__EMAIL: admin@opencti.io
  APP__BASE_PATH: "/"
  APP__TELEMETRY__METRICS__ENABLED: true
  APP__GRAPHQL__PLAYGROUND__ENABLED: false

  ## OPENSEARCH
  ELASTICSEARCH__ENGINE_SELECTOR: opensearch
  ELASTICSEARCH__URL: http://opencti-cluster-opensearch:9200

  ## STORAGE
  MINIO__ENDPOINT: opencti-cluster-minio

  ## MESSAGE QUEUE
  RABBITMQ__HOSTNAME: opencti-cluster-rabbitmq
  RABBITMQ__PORT: 5672
  RABBITMQ__USERNAME: user

  ## CACHE
  REDIS__HOSTNAME: opencti-cluster-redis
  REDIS__PORT: 6379

# Credentials management
envFromSecrets:
  APP__ADMIN__PASSWORD:
    name: opencti-cluster-credentials
    key: APP__ADMIN__PASSWORD
  APP__ADMIN__TOKEN:
    name: opencti-cluster-credentials
    key: APP__ADMIN__TOKEN
  APP__HEALTH_ACCESS_KEY:
    name: opencti-cluster-credentials
    key: APP__HEALTH_ACCESS_KEY

secrets:
  - name: credentials
    data:
      APP__ADMIN__PASSWORD: your-secure-password
      APP__ADMIN__TOKEN: your-secure-token
      APP__HEALTH_ACCESS_KEY: your-health-key

# Worker configuration
worker:
  enabled: true
  replicaCount: 2

  resources:
    requests:
      memory: 512Mi
      cpu: 200m
    limits:
      memory: 1Gi
      cpu: 500m

  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 75

# Connector configuration
connectors:
  - name: opencti
    enabled: true
    replicas: 1

    env:
      CONNECTOR_ID: your-connector-id
      CONNECTOR_NAME: "OpenCTI-Cluster"
      CONNECTOR_SCOPE: "marking-definition,identity,location"
      CONNECTOR_TYPE: EXTERNAL_IMPORT

    resources:
      requests:
        memory: 128Mi
        cpu: 50m
      limits:
        memory: 256Mi
```

## Component connectivity

In clustering mode, components connect as follows:

- **Users** → Frontend cluster (via Ingress)
- **Workers** → Ingestion cluster (for data processing)
- **Connectors** → Frontend cluster (for API access)
- **Both clusters** → Shared dependencies (OpenSearch, MinIO, RabbitMQ, Redis)

## Scaling considerations

### Frontend cluster

Scale based on:

- Number of concurrent users
- API request volume
- UI responsiveness requirements

Typical scaling: 2-8 replicas depending on user load.

### Ingestion cluster

Scale based on:

- Data ingestion volume
- Background task queue size
- Processing complexity

Typical scaling: 3-15 replicas depending on data processing needs.

### Workers

Workers automatically connect to the ingestion cluster and scale based on:

- Queue depth
- Processing time per task
- Available cluster capacity

### Connectors

Connectors connect to the frontend cluster for API access and scale based on:

- Number of data sources
- Ingestion frequency
- Data volume per source

## Migration from single mode

To migrate from single mode to clustering:

1. **Enable clustering**:

   ```yaml
   clustering:
     enabled: true
   ```

2. **Configure frontend and ingestion**:

   ```yaml
   clustering:
     frontend:
       enabled: true
       replicaCount: 2
     ingestion:
       enabled: true
       replicaCount: 3
   ```

3. **Update ingress** (move from server to frontend):

   ```yaml
   clustering:
     frontend:
       ingress:
         enabled: true
         hosts:
           - host: your-opencti-domain.com
   ```

4. **Deploy and verify**:

   ```bash
   helm upgrade opencti . -f your-clustering-values.yaml
   ```

## Monitoring and observability

### Metrics

Both frontend and ingestion clusters expose metrics:

```yaml
clustering:
  frontend:
    serviceMonitor:
      enabled: true
  ingestion:
    serviceMonitor:
      enabled: true
```

### Health checks

Configure appropriate health checks for each component:

```yaml
livenessProbe:
  enabled: true
  initialDelaySeconds: 180
  periodSeconds: 30

readinessProbe:
  enabled: true
  initialDelaySeconds: 30
  periodSeconds: 10

startupProbe:
  enabled: true
  initialDelaySeconds: 180
  failureThreshold: 30
```

## High availability

### Pod disruption budgets

Configure PDBs for both clusters:

```yaml
clustering:
  frontend:
    podDisruptionBudget:
      enabled: true
      maxUnavailable: 1
  ingestion:
    podDisruptionBudget:
      enabled: true
      maxUnavailable: 2
```

### Topology spread constraints

Ensure pods are distributed across nodes:

```yaml
clustering:
  frontend:
    topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
  ingestion:
    topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
```

## Security considerations

### Network policies

Isolate traffic between components:

```yaml
clustering:
  frontend:
    networkPolicy:
      enabled: true
      ingress:
        - from:
            - namespaceSelector:
                matchLabels:
                  name: opencti-frontend
  ingestion:
    networkPolicy:
      enabled: true
      ingress:
        - from:
            - namespaceSelector:
                matchLabels:
                  name: opencti-ingestion
```
