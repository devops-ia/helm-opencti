# Basic installation

See [Customizing the chart before installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with comments:

```console
helm show values opencti/opencti
```

You may also helm show values on this chart's dependencies for additional options.

## Components

Basic installation will deploy the following components:

* OpenCTI server
* OpenCTI worker
* OpenCTI connectors
* ElasticSearch / OpenSearch
* MinIO
* RabbitMQ
* Redis

## Complete Configuration Example

Here's a complete configuration example based on the CI environment:

```yaml
replicaCount: 1
fullnameOverride: <release-name>

strategy:
  type: Recreate

# OpenCTI Server Configuration
env:
  APP__ADMIN__EMAIL: admin@opencti.io
  APP__BASE_PATH: "/"
  APP__HEALTH_ACCESS_KEY: f93747ff-2ea1-4717-900c-9df20b8e4429
  APP__TELEMETRY__METRICS__ENABLED: false
  APP__GRAPHQL__PLAYGROUND__ENABLED: false
  APP__GRAPHQL__PLAYGROUND__FORCE_DISABLED_INTROSPECTION: true

  ## OPENSEARCH
  ELASTICSEARCH__ENGINE_SELECTOR: opensearch
  ELASTICSEARCH__URL: http://<release-name>-opensearch:9200

  ## STORAGE
  MINIO__ENDPOINT: <release-name>-minio

  ## MESSAGE QUEUE
  RABBITMQ__HOSTNAME: <release-name>-rabbitmq
  RABBITMQ__PORT_MANAGEMENT: 15672
  RABBITMQ__PORT: 5672
  RABBITMQ__USERNAME: user

  ## CACHE
  REDIS__HOSTNAME: <release-name>-redis
  REDIS__MODE: single
  REDIS__PORT: 6379

envFromSecrets:
  APP__ADMIN__PASSWORD:
    name: <release-name>-credentials
    key: APP__ADMIN__PASSWORD
  APP__ADMIN__TOKEN:
    name: <release-name>-credentials
    key: APP__ADMIN__TOKEN
  MINIO__ACCESS_KEY:
    name: opencti-<release-name>-minio
    key: rootUser
  MINIO__SECRET_KEY:
    name: opencti-<release-name>-minio
    key: rootPassword
  RABBITMQ__PASSWORD:
    name: opencti-<release-name>-rabbitmq
    key: rabbitmq-password

secrets:
  - name: credentials
    data:
      APP__ADMIN__PASSWORD: iraLehfJu1NRnQgwIBeH
      APP__ADMIN__TOKEN: b1976749-8a53-4f49-bf04-cafa2a3458c1


testConnection: true

readyChecker:
  enabled: true
  retries: 30
  timeout: 5
  services:
  - name: opensearch
    port: 9200
  - name: minio
    port: 9000
  - name: rabbitmq
    port: 5672
  - name: redis
    port: 6379

# Probes Configuration
livenessProbe:
  enabled: false

readinessProbe:
  enabled: false

startupProbe:
  enabled: false

lifecycle:
  preStop:
    exec:
      command: ["sh", "-c", "sleep 5"]

terminationGracePeriodSeconds: 20

# Service Configuration
service:
  type: ClusterIP
  port: 80
  targetPort: 4000
  protocol: TCP
  portName: http
  appProtocol: HTTP
  externalTrafficPolicy: Local
  internalTrafficPolicy: Local
  publishNotReadyAddresses: false
  sessionAffinity: None
  ipFamilies:
    - IPv4
  ipFamilyPolicy: SingleStack
  trafficDistribution: PreferClose
  labels:
    environment: production
  extraPorts:
    - name: grpc
      port: 9000
      targetPort: 9000
      protocol: TCP
      appProtocol: GRPC

# Resource Management
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"

# Autoscaling
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# Topology Spread Constraints
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/os
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: opencti

# OpenCTI Worker Configuration
worker:
  enabled: true

  readyChecker:
    enabled: true
    retries: 30
    timeout: 5

  lifecycle:
    preStop:
      exec:
        command: ["sh", "-c", "sleep 5"]

  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi

  strategy:
    type: Recreate

  terminationGracePeriodSeconds: 20

  networkPolicy:
    enabled: true
    ingress:
      - from:
          - namespaceSelector:
              matchLabels:
                name: opencti
        ports:
          - protocol: TCP
            port: 4000

  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 3
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80

  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/os
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app.kubernetes.io/name: opencti
          app.kubernetes.io/component: worker

  dnsConfig:
    nameservers:
      - 1.1.1.1
      - 8.8.8.8
    searches: []
    options:
      - name: ndots
        value: "2"

  dnsPolicy: ClusterFirst

# OpenCTI Connectors Configuration
connectorsGlobal:
  env:
    CONNECTOR_EXPOSE_METRICS: true

connectors:
  - name: opencti
    enabled: true
    replicas: 1

    resources:
      requests:
        memory: 128Mi
        cpu: 50m
      limits:
        memory: 256Mi

    serviceMonitor:
      enabled: false
      interval: 30s
      scrapeTimeout: 10s

    image:
      repository: opencti/connector-opencti
      pullPolicy: IfNotPresent

    readyChecker:
      enabled: true
      retries: 30
      timeout: 5

    lifecycle:
      preStop:
        exec:
          command: ["sh", "-c", "sleep 5"]

    terminationGracePeriodSeconds: 20

    deploymentAnnotations:
      prometheus.io/scrape: "true"
    podAnnotations:
      prometheus.io/scrape: "true"
    podLabels:
      app.kubernetes.io/component: connector

    env:
      CONNECTOR_ID: 399e6354-cc2c-4fe1-bb85-145a5bb043a9
      CONNECTOR_NAME: "OpenCTI"
      CONNECTOR_SCOPE: "marking-definition,identity,location"
      CONNECTOR_TYPE: EXTERNAL_IMPORT

    envFromFiles:
      - secretRef:
          name: opencti-<release-name>-credentials

    topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/os
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: opencti
            app.kubernetes.io/component: connector

    dnsConfig:
      nameservers:
        - 1.1.1.1
        - 8.8.8.8
      searches: []
      options:
        - name: ndots
          value: "2"

    dnsPolicy: ClusterFirst
    strategy:
      type: Recreate

# OpenSearch Configuration
opensearch:
  enabled: true
  fullnameOverride: opencti-<release-name>-opensearch

  nodeGroup: ""
  opensearchJavaOpts: "-Xmx512M -Xms512M"
  singleNode: true

  config:
    opensearch.yml: |
      plugins.security.disabled: true

  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"

  persistence:
    enabled: false

# MinIO Configuration
minio:
  fullnameOverride: opencti-<release-name>-minio

  rootUser: minio
  rootPassword: uxLSbJGZzzhZxXUFgdAl

  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi

  persistence:
    enabled: false

# RabbitMQ Configuration
rabbitmq:
  fullnameOverride: opencti-<release-name>-rabbitmq

  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi

  auth:
    password: K4we4CUebaRpISxWnMJn
    erlangCookie: b25c953e-2193-4b8e-9f3b-9a3a5ba76d75

  clustering:
    enabled: false

  networkPolicy:
    enabled: false

  persistence:
    enabled: false

# Redis Configuration
redis:
  fullnameOverride: opencti-<release-name>-redis

  resources:
    requests:
      memory: 256Mi
      cpu: 50m
    limits:
      memory: 256Mi

  extraArgs:
    - --maxmemory=256mb
    - --proactor_threads=1
    - --num_shards=1
```

### OpenCTI server

Basic config server block to configure:

```yaml
env:
  APP__ADMIN__EMAIL: admin@opencti.io
  APP__ADMIN__PASSWORD: test
  APP__ADMIN__TOKEN: b1976749-8a53-4f49-bf04-cafa2a3458c1
  APP__BASE_PATH: "/"
  APP__SESSION_COOKIE: "true"
  APP__HEALTH_ACCESS_KEY: f93747ff-2ea1-4717-900c-9df20b8e4429
  APP__TELEMETRY__METRICS__ENABLED: false
  APP__GRAPHQL__PLAYGROUND__ENABLED: false
  APP__GRAPHQL__PLAYGROUND__FORCE_DISABLED_INTROSPECTION: true
  ...
```

Expose service:

```yaml
ingress:
  enabled: true
  hosts:
    - host: demo.mydomain.com
      paths:
        - path: /
          pathType: Prefix
```

### OpenCTI Worker

The OpenCTI worker processes background tasks and jobs. Basic configuration:

```yaml
worker:
  enabled: true

  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi

  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 3
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80

  readyChecker:
    enabled: true
    retries: 30
    timeout: 5
```

### OpenCTI Connectors

Connectors allow OpenCTI to import data from external sources. Basic configuration:

```yaml
connectorsGlobal:
  env:
    CONNECTOR_EXPOSE_METRICS: true

connectors:
  - name: opencti
    enabled: true
    replicas: 1

    resources:
      requests:
        memory: 128Mi
        cpu: 50m
      limits:
        memory: 256Mi

    env:
      CONNECTOR_ID: 399e6354-cc2c-4fe1-bb85-145a5bb043a9
      CONNECTOR_NAME: "OpenCTI"
      CONNECTOR_SCOPE: "marking-definition,identity,location"
      CONNECTOR_TYPE: EXTERNAL_IMPORT

    image:
      repository: opencti/connector-opencti
      pullPolicy: IfNotPresent
```

### ElasticSearch

> [!IMPORTANT]
> Only you can configure `ElasticSearch` or `OpenSearch` on OpenCTI config.

> [!NOTE]
> To deploy ElasticSearch, you need to deploy the [Elastic Cloud on Kubernetes with ECK OpenSearch](https://github.com/elastic/cloud-on-k8s/tree/main/deploy) chart.

Server block to configure ElasticSearch:

```yaml
env:
...
  ELASTICSEARCH__ENGINE_SELECTOR: elk
  ELASTICSEARCH__URL: http://<release-name>-elasticsearch-es-default:9200
  ELASTICSEARCH__USERNAME: elastic

envFromSecrets:
...
  ELASTICSEARCH__PASSWORD:
    name: <release-name>-elasticsearch-es-elastic-user
    key: elastic
```

Basic config:

```yaml
eck-stack:
  enabled: true

  eck-elasticsearch:
    fullnameOverride: <release-name>-elasticsearch
    http:
      tls:
        selfSignedCertificate:
          disabled: true
    nodeSets:
      - name: default
        count: 1
        config:
          node.roles: ["master", "data", "ingest"]
          node.store.allow_mmap: false
        podTemplate:
          spec:
            containers:
              - name: elasticsearch
                resources:
                  requests:
                    cpu: "500m"
                    memory: "2Gi"
                  limits:
                    memory: "2Gi"
            volumes:
              - name: elasticsearch-data
                emptyDir: {}
```

More info. [chart values](https://github.com/elastic/cloud-on-k8s/blob/main/deploy/eck-stack/values.yaml)

### OpenSearch

> [!IMPORTANT]
> Only you can configure `ElasticSearch` or `OpenSearch` on OpenCTI config.

Server block to configure OpenSearch:

```yaml
env:
...
  ELASTICSEARCH__ENGINE_SELECTOR: opensearch
  ELASTICSEARCH__URL: http://<release-name>-opensearch:9200
```

Basic config:

```yaml
opensearch:
  enabled: true
  fullnameOverride: <release-name>-opensearch

  opensearchJavaOpts: "-Xmx512M -Xms512M"
  singleNode: true

  config:
    opensearch.yml: |
      plugins.security.disabled: true

  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"

  persistence:
    enabled: false
```

For production with security enabled:

```yaml
opensearch:
  enabled: true
  fullnameOverride: <release-name>-opensearch

  opensearchJavaOpts: "-Xmx512M -Xms512M"
  singleNode: true

  securityConfig:
    config:
      data:
        internal_users.yml: |-
          admin:
            hash: "$2a$12$VcCDgh2NDk07JGN0rjGbM.Ad41qVR/YFJcgHp0UGns5JDymv..TOG"
            reserved: true
            backend_roles:
            - "admin"
            description: "Demo admin user"

  persistence:
    enabled: false
```

Move `opensearch.securityConfig.config.data.internal_users.yml` to `secrets` block for `auth`:

```yaml
secrets:
  - name: credentials
    data:
      ELASTICSEARCH__USERNAME: admin
      ELASTICSEARCH__PASSWORD: admin
```

Configure `envFromSecrets` for server block:

```yaml
envFromSecrets:
  ELASTICSEARCH__USERNAME:
    name: <release-name>-credentials
    key: ELASTICSEARCH__USERNAME
  ELASTICSEARCH__PASSWORD:
    name: <release-name>-credentials
    key: ELASTICSEARCH__PASSWORD
```

Configure OpenSearch `opensearch.securityConfig.config.data.internal_users.yml` with existing secret:

```yaml
opensearch.securityConfig.internalUsersSecret: <release-name>-credentials
```

More info. [chart values](https://github.com/opensearch-project/helm-charts/blob/main/charts/opensearch/values.yaml)

### MinIO

Server block to configure MinIO:

```yaml
env:
...
  MINIO__ENDPOINT: <release-name>-minio
```

Basic config:

```yaml
minio:
  enabled: true
  fullnameOverride: <release-name>-minio

  rootUser: minio
  rootPassword: uxLSbJGZzzhZxXUFgdAl

  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi

  persistence:
    enabled: false
```

Move `minio.rootUser` and `minio.rootPassword` to `secrets` block for `auth`:

```yaml
secrets:
  - name: credentials
    data:
      root-user: MySecretPassword
      root-password: MySecretPassword
```

Configure `envFromSecrets` for server block:

```yaml
envFromSecrets:
  MINIO__ACCESS_KEY:
    name: <release-name>-credentials
    key: root-user
  MINIO__SECRET_KEY:
    name: <release-name>-credentials
    key: root-password
```

Configure Minio `minio.auth` with existing secret:

```yaml
minio.auth.existingSecret: <release-name>-credentials
```

More info. [chart values](https://github.com/minio/minio/blob/main/helm/minio/values.yaml)

### RabbitMQ

Server block to configure RabbitMQ:

```yaml
env:
...
  RABBITMQ__HOSTNAME: <release-name>-rabbitmq
  RABBITMQ__PORT_MANAGEMENT: 15672
  RABBITMQ__PORT: 5672
  RABBITMQ__USERNAME: user
  RABBITMQ__PASSWORD: ChangeMe
```

Basic config:

```yaml
rabbitmq:
  enabled: true
  fullnameOverride: <release-name>-rabbitmq

  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi

  auth:
    username: user
    password: K4we4CUebaRpISxWnMJn
    erlangCookie: b25c953e-2193-4b8e-9f3b-9a3a5ba76d75

  clustering:
    enabled: false

  networkPolicy:
    enabled: false

  persistence:
    enabled: false
```

Move `rabbitmq.auth.password` and `rabbitmq.auth.erlangCookie` to `secrets` block for `auth`:

```yaml
secrets:
  - name: credentials
    data:
      rabbitmq-password: MySecretPassword
      rabbitmq-erlang-cookie: MySecretErlangCookie
```

Configure `envFromSecrets` for server block:

```yaml
envFromSecrets:
  RABBITMQ__PASSWORD:
    name: <release-name>-credentials
    key: rabbitmq-password
  RABBITMQ__ERLANGCOOKIE:
    name: <release-name>-credentials
    key: rabbitmq-erlang-cookie
```

Configure RabbitMQ `rabbitmq.auth` with existing secret:

```yaml
rabbitmq.auth.existingPasswordSecret: <release-name>-credentials
rabbitmq.auth.existingErlangSecret: <release-name>-credentials
```

More info. [chart values](https://github.com/bitnami/charts/blob/main/bitnami/rabbitmq/values.yaml)

### Redis

Server block to configure Redis:

```yaml
env:
...
  REDIS__HOSTNAME: <release-name>-redis
  REDIS__PORT: 6379
  REDIS__MODE: single
```

Basic config:

```yaml
redis:
  enabled: true
  fullnameOverride: <release-name>-redis

  resources:
    requests:
      memory: 256Mi
      cpu: 50m
    limits:
      memory: 256Mi

  extraArgs:
    - --maxmemory=256mb
    - --proactor_threads=1
    - --num_shards=1
```

More info. [chart values](https://github.com/dragonflydb/dragonfly/blob/main/contrib/charts/dragonfly/values.yaml)

## Health checks

### Ready checker

Configure health checks for all dependencies:

```yaml
readyChecker:
  enabled: true
  retries: 30
  timeout: 5
  services:
  - name: opensearch
    port: 9200
  - name: minio
    port: 9000
  - name: rabbitmq
    port: 5672
  - name: redis
    port: 6379
```

### Probes

Configure Kubernetes probes for better health monitoring:

```yaml
livenessProbe:
  enabled: true
  httpGet:
    path: /health
    port: 4000
  initialDelaySeconds: 60
  periodSeconds: 30

readinessProbe:
  enabled: true
  httpGet:
    path: /health
    port: 4000
  initialDelaySeconds: 30
  periodSeconds: 10

startupProbe:
  enabled: true
  httpGet:
    path: /health
    port: 4000
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 30
```

## Resources

### Limits

Configure appropriate resource limits for all components:

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

### Autoscaling

Enable horizontal pod autoscaling:

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

## Security

### Secrets management

Store sensitive data in Kubernetes secrets:

```yaml
secrets:
  - name: credentials
    data:
      APP__ADMIN__PASSWORD: iraLehfJu1NRnQgwIBeH
      APP__ADMIN__TOKEN: b1976749-8a53-4f49-bf04-cafa2a3458c1
```

### Network policies

Configure network policies for security:

```yaml
networkPolicy:
  enabled: true
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: opencti
      ports:
        - protocol: TCP
          port: 4000
```

## DNS Configuration

Configure DNS settings for better network connectivity:

```yaml
dnsConfig:
  nameservers:
    - 1.1.1.1
    - 8.8.8.8
  searches: []
  options:
    - name: ndots
      value: "2"

dnsPolicy: ClusterFirst
```

## Lifecycle

### Graceful shutdown

Configure graceful shutdown behavior:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["sh", "-c", "sleep 5"]

terminationGracePeriodSeconds: 20
```

### Deployment Strategy

Configure deployment strategy:

```yaml
strategy:
  type: Recreate
```
