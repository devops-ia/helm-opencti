# opencti

A Helm chart to deploy Open Cyber Threat Intelligence platform

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| ialejandro | <hello@ialejandro.rocks> | <https://ialejandro.rocks> |

## Prerequisites

* Helm 3+

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://opensearch-project.github.io/helm-charts/ | opensearch | 2.22.1 |
| oci://registry-1.docker.io/bitnamicharts | elasticsearch | 21.3.8 |
| oci://registry-1.docker.io/bitnamicharts | minio | 14.7.1 |
| oci://registry-1.docker.io/bitnamicharts | rabbitmq | 14.6.6 |
| oci://registry-1.docker.io/bitnamicharts | redis | 19.6.4 |

## Add repository

```console
helm repo add opencti https://devops-ia.github.io/helm-opencti
helm repo update
```

## Install Helm chart (repository mode)

```console
helm install [RELEASE_NAME] opencti/opencti
```

This install all the Kubernetes components associated with the chart and creates the release.

_See [helm install](https://helm.sh/docs/helm/helm_install/) for command documentation._

## Install Helm chart (OCI mode)

Charts are also available in OCI format. The list of available charts can be found [here](https://github.com/devops-ia/helm-opencti/pkgs/container/helm-opencti%2Fopencti).

```console
helm install [RELEASE_NAME] oci://ghcr.io/devops-ia/helm-opencti/opencti --version=[version]
```

## Uninstall Helm chart

```console
helm uninstall [RELEASE_NAME]
```

This removes all the Kubernetes components associated with the chart and deletes the release.

_See [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) for command documentation._

## OpenCTI

* [Environment configuration](https://docs.opencti.io/latest/deployment/configuration/#platform)
* [Connectors](https://github.com/OpenCTI-Platform/connectors/tree/master). Review `docker-compose.yaml` with the properly config
* Check connectors samples on `connector-examples` folder

## Basic installation and examples

See [basic installation](docs/configuration.md) and [examples](docs/examples.md).

## Configuration

See [Customizing the chart before installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with comments:

```console
helm show values opencti/opencti
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity for pod assignment |
| autoscaling | object | `{"enabled":false,"maxReplicas":100,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | Autoscaling with CPU or memory utilization percentage |
| connectors | list | `[]` | Connectors Ref: https://github.com/OpenCTI-Platform/connectors/tree/master |
| connectorsGlobalEnv | string | `nil` | Connector Global environment |
| elasticsearch | object | `{"clusterName":"elastic","coordinating":{"replicaCount":0},"data":{"persistence":{"enabled":false},"replicaCount":1},"enabled":true,"extraEnvVars":[{"name":"ES_JAVA_OPTS","value":"-Xms512M -Xmx512M"}],"ingest":{"enabled":false},"master":{"masterOnly":true,"persistence":{"enabled":false},"replicaCount":1},"sysctlImage":{"enabled":false}}` | ElasticSearch subchart deployment Ref: https://github.com/bitnami/charts/blob/main/bitnami/elasticsearch/values.yaml |
| elasticsearch.clusterName | string | `"elastic"` | Elasticsearch cluster name |
| elasticsearch.coordinating | object | `{"replicaCount":0}` | Coordinating-only nodes parameters |
| elasticsearch.coordinating.replicaCount | int | `0` | Number of coordinating-only replicas to deploy |
| elasticsearch.data | object | `{"persistence":{"enabled":false},"replicaCount":1}` | Data-only nodes parameters |
| elasticsearch.data.persistence | object | `{"enabled":false}` | Enable persistence using Persistent Volume Claims Ref: https://kubernetes.io/docs/user-guide/persistent-volumes/ |
| elasticsearch.data.persistence.enabled | bool | `false` | Enable persistence using a `PersistentVolumeClaim` |
| elasticsearch.data.replicaCount | int | `1` | Number of data-only replicas to deploy |
| elasticsearch.enabled | bool | `true` | Enable or disable ElasticSearch subchart |
| elasticsearch.ingest | object | `{"enabled":false}` | Ingest-only nodes parameters |
| elasticsearch.ingest.enabled | bool | `false` | Enable ingest nodes |
| elasticsearch.master.masterOnly | bool | `true` | Deploy the Elasticsearch master-eligible nodes as master-only nodes. Recommended for high-demand deployments. |
| elasticsearch.master.persistence | object | `{"enabled":false}` | Enable persistence using Persistent Volume Claims Ref: https://kubernetes.io/docs/user-guide/persistent-volumes/ |
| elasticsearch.master.persistence.enabled | bool | `false` | Enable persistence using a `PersistentVolumeClaim` |
| elasticsearch.master.replicaCount | int | `1` | Number of master-eligible replicas to deploy |
| env | object | `{"APP__ADMIN__EMAIL":"admin@opencti.io","APP__ADMIN__PASSWORD":"ChangeMe","APP__ADMIN__TOKEN":"ChangeMe","APP__BASE_PATH":"/","APP__GRAPHQL__PLAYGROUND__ENABLED":false,"APP__GRAPHQL__PLAYGROUND__FORCE_DISABLED_INTROSPECTION":false,"APP__HEALTH_ACCESS_KEY":"ChangeMe","APP__TELEMETRY__METRICS__ENABLED":true,"ELASTICSEARCH__URL":"http://release-name-elasticsearch:9200","MINIO__ENDPOINT":"release-name-minio:9000","RABBITMQ__HOSTNAME":"release-name-rabbitmq","RABBITMQ__PASSWORD":"ChangeMe","RABBITMQ__PORT":5672,"RABBITMQ__PORT_MANAGEMENT":15672,"RABBITMQ__USERNAME":"user","REDIS__HOSTNAME":"release-name-redis-master","REDIS__MODE":"single","REDIS__PORT":6379}` | Environment variables to configure application Ref: https://docs.opencti.io/latest/deployment/configuration/#platform |
| envFromSecrets | object | `{}` | Secrets from variables |
| fullnameOverride | string | `""` | String to fully override opencti.fullname template |
| global | object | `{"imagePullSecrets":[],"imageRegistry":""}` | Global configuration |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"opencti/platform","tag":""}` | Image registry |
| imagePullSecrets | list | `[]` | Global Docker registry secret names as an array |
| ingress | object | `{"annotations":{},"className":"","enabled":false,"hosts":[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}],"tls":[]}` | Ingress configuration to expose app |
| livenessProbe | object | `{"enabled":true,"failureThreshold":3,"initialDelaySeconds":180,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5}` | Configure liveness checker Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-startup-probes |
| livenessProbeCustom | object | `{}` | Custom livenessProbe |
| minio | object | `{"auth":{"rootPassword":"ChangeMe","rootUser":"ChangeMe"},"enabled":true,"mode":"standalone","persistence":{"enabled":false}}` | MinIO subchart deployment Ref: https://github.com/bitnami/charts/blob/main/bitnami/minio/values.yaml  |
| minio.auth.rootPassword | string | `"ChangeMe"` | Password for Minio root user |
| minio.auth.rootUser | string | `"ChangeMe"` | Minio root username |
| minio.enabled | bool | `true` | Enable or disable MinIO subchart |
| minio.mode | string | `"standalone"` | mode Minio server mode (`standalone` or `distributed`) Ref: https://docs.minio.io/docs/distributed-minio-quickstart-guide |
| minio.persistence | object | `{"enabled":false}` | Enable persistence using Persistent Volume Claims Ref: https://kubernetes.io/docs/user-guide/persistent-volumes/ |
| minio.persistence.enabled | bool | `false` | Enable MinIO data persistence using PVC. If false, use emptyDir |
| nameOverride | string | `""` | String to partially override opencti.fullname template (will maintain the release name) |
| nodeSelector | object | `{}` | Node labels for pod assignment |
| opensearch | object | `{"enabled":false,"opensearchJavaOpts":"-Xmx512M -Xms512M","persistence":{"enabled":false},"singleNode":true}` | OpenSearch subchart deployment Ref: https://github.com/opensearch-project/helm-charts/blob/opensearch-2.16.1/charts/opensearch/values.yaml |
| opensearch.enabled | bool | `false` | Enable or disable OpenSearch subchart |
| opensearch.opensearchJavaOpts | string | `"-Xmx512M -Xms512M"` | OpenSearch Java options |
| opensearch.persistence | object | `{"enabled":false}` | Enable persistence using Persistent Volume Claims Ref: https://kubernetes.io/docs/user-guide/persistent-volumes/ |
| opensearch.singleNode | bool | `true` | If discovery.type in the opensearch configuration is set to "single-node", this should be set to "true" If "true", replicas will be forced to 1 |
| rabbitmq | object | `{"auth":{"erlangCookie":"ChangeMe","password":"ChangeMe","username":"user"},"clustering":{"enabled":false},"enabled":true,"persistence":{"enabled":false},"replicaCount":1}` | RabbitMQ subchart deployment Ref: https://github.com/bitnami/charts/blob/main/bitnami/rabbitmq/values.yaml |
| rabbitmq.auth | object | `{"erlangCookie":"ChangeMe","password":"ChangeMe","username":"user"}` | RabbitMQ Authentication parameters |
| rabbitmq.auth.password | string | `"ChangeMe"` | RabbitMQ application password Ref: https://github.com/bitnami/containers/tree/main/bitnami/rabbitmq#environment-variables |
| rabbitmq.auth.username | string | `"user"` | RabbitMQ application username Ref: https://github.com/bitnami/containers/tree/main/bitnami/rabbitmq#environment-variables |
| rabbitmq.clustering | object | `{"enabled":false}` | Clustering settings |
| rabbitmq.clustering.enabled | bool | `false` | Enable RabbitMQ clustering |
| rabbitmq.enabled | bool | `true` | Enable or disable RabbitMQ subchart |
| rabbitmq.persistence | object | `{"enabled":false}` | Persistence parameters |
| rabbitmq.persistence.enabled | bool | `false` | Enable RabbitMQ data persistence using PVC |
| rabbitmq.replicaCount | int | `1` | Number of RabbitMQ replicas to deploy |
| readinessProbe | object | `{"enabled":true,"failureThreshold":3,"initialDelaySeconds":10,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":1}` | Configure readinessProbe checker Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-startup-probes |
| readinessProbeCustom | object | `{}` | Custom readinessProbe |
| readyChecker | object | `{"enabled":true,"retries":30,"services":[{"name":"elasticsearch","port":9200},{"name":"minio","port":9000},{"name":"rabbitmq","port":5672},{"name":"redis-master","port":6379}],"timeout":5}` | Enable or disable ready-checker |
| readyChecker.retries | int | `30` | Number of retries before giving up |
| readyChecker.services | list | `[{"name":"elasticsearch","port":9200},{"name":"minio","port":9000},{"name":"rabbitmq","port":5672},{"name":"redis-master","port":6379}]` | List services |
| readyChecker.timeout | int | `5` | Timeout for each check |
| redis | object | `{"architecture":"standalone","auth":{"enabled":false},"enabled":true,"master":{"count":1,"persistence":{"enabled":false}},"replica":{"persistence":{"enabled":false},"replicaCount":1}}` | Redis subchart deployment Ref: https://github.com/bitnami/charts/blob/main/bitnami/redis/values.yaml |
| redis.architecture | string | `"standalone"` | Redis architecture. Allowed values: `standalone` or `replication` |
| redis.auth | object | `{"enabled":false}` | Redis Authentication parameters Ref: https://github.com/bitnami/containers/tree/main/bitnami/redis#setting-the-server-password-on-first-run |
| redis.auth.enabled | bool | `false` | Enable password authentication |
| redis.enabled | bool | `true` | Enable or disable Redis subchart |
| redis.master | object | `{"count":1,"persistence":{"enabled":false}}` | Redis master configuration parameters |
| redis.master.count | int | `1` | Number of Redis master instances to deploy (experimental, requires additional configuration) |
| redis.master.persistence | object | `{"enabled":false}` | Persistence parameters Ref: https://kubernetes.io/docs/user-guide/persistent-volumes/ |
| redis.master.persistence.enabled | bool | `false` | Enable persistence on Redis master nodes using Persistent Volume Claims |
| redis.replica | object | `{"persistence":{"enabled":false},"replicaCount":1}` | Redis replicas configuration parameters |
| redis.replica.persistence | object | `{"enabled":false}` | Persistence parameters Ref: https://kubernetes.io/docs/user-guide/persistent-volumes/ |
| redis.replica.persistence.enabled | bool | `false` | Enable persistence on Redis master nodes using Persistent Volume Claims |
| redis.replica.replicaCount | int | `1` | Number of Redis replicas to deploy |
| replicaCount | int | `1` | Number of replicas |
| resources | object | `{}` | The resources limits and requested |
| secrets | object | `{}` | Secrets values to create credentials and reference by envFromSecrets |
| service | object | `{"port":80,"targetPort":4000,"type":"ClusterIP"}` | Kubernetes service to expose Pod |
| service.port | int | `80` | Kubernetes Service port |
| service.targetPort | int | `4000` | Pod expose port |
| service.type | string | `"ClusterIP"` | Kubernetes Service type. Allowed values: NodePort, LoadBalancer or ClusterIP |
| serviceAccount | object | `{"annotations":{},"automountServiceAccountToken":false,"create":true,"name":""}` | Enable creation of ServiceAccount |
| serviceMonitor | object | `{"enabled":false,"interval":"30s","metricRelabelings":[],"relabelings":[],"scrapeTimeout":"10s"}` | Enable ServiceMonitor to get metrics Ref: https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#servicemonitor |
| serviceMonitor.enabled | bool | `false` | Enable or disable |
| startupProbe | object | `{"enabled":true,"failureThreshold":30,"initialDelaySeconds":180,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5}` | Configure startupProbe checker Ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-startup-probes |
| startupProbeCustom | object | `{}` | Custom startupProbe |
| testConnection | bool | `false` | Enable or disable test connection |
| tolerations | list | `[]` | Tolerations for pod assignment |
| worker | object | `{"affinity":{},"autoscaling":{"enabled":false,"maxReplicas":100,"minReplicas":1,"targetCPUUtilizationPercentage":80},"enabled":true,"env":{"WORKER_LOG_LEVEL":"info","WORKER_TELEMETRY_ENABLED":true},"envFromSecrets":{},"image":{"pullPolicy":"IfNotPresent","repository":"opencti/worker","tag":""},"nodeSelector":{},"readyChecker":{"enabled":true,"retries":30,"timeout":5},"replicaCount":1,"resources":{},"serviceMonitor":{"enabled":false,"interval":"30s","metricRelabelings":[],"relabelings":[],"scrapeTimeout":"10s"},"tolerations":[]}` | OpenCTI worker deployment configuration |
| worker.affinity | object | `{}` | Affinity for pod assignment |
| worker.autoscaling | object | `{"enabled":false,"maxReplicas":100,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | Autoscaling with CPU or memory utilization percentage |
| worker.env | object | `{"WORKER_LOG_LEVEL":"info","WORKER_TELEMETRY_ENABLED":true}` | Environment variables to configure application Ref: https://docs.opencti.io/latest/deployment/configuration/#platform |
| worker.envFromSecrets | object | `{}` | Secrets from variables |
| worker.image | object | `{"pullPolicy":"IfNotPresent","repository":"opencti/worker","tag":""}` | Image registry |
| worker.nodeSelector | object | `{}` | Node labels for pod assignment |
| worker.readyChecker | object | `{"enabled":true,"retries":30,"timeout":5}` | Enable or disable ready-checker waiting server is ready |
| worker.readyChecker.retries | int | `30` | Number of retries before giving up |
| worker.readyChecker.timeout | int | `5` | Timeout for each check |
| worker.replicaCount | int | `1` | Number of replicas |
| worker.resources | object | `{}` | The resources limits and requested |
| worker.serviceMonitor | object | `{"enabled":false,"interval":"30s","metricRelabelings":[],"relabelings":[],"scrapeTimeout":"10s"}` | Enable ServiceMonitor to get metrics Ref: https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#servicemonitor |
| worker.serviceMonitor.enabled | bool | `false` | Enable or disable |
| worker.tolerations | list | `[]` | Tolerations for pod assignment |
