# Examples

## Global

### Manage secrets

Use `secrets` to create secrets to reference with `envFromSecrets`. By default the secret is created in the same namespace of the release. This `secrets` have preference over `env`.

> [!IMPORTANT]
> Secrets are encoded with base64.

Name template `{{ include "opencti.fullname" . }}-credentials`. For example if release name is `opencti-ci` the secret name will be `opencti-ci-credentials`.

```yaml
kind: Secret
type: Opaque
metadata:
  name: opencti-ci-credentials
  labels:
    ...
data:
  my_secret: dGVzdA==
```

Can reference the secret using `envFromSecrets` in any (is the same `Secret` for each component):

* server
* worker
* connector

> [!NOTE]
> A suggestion to facilitate the management of secrets is to use prefixes. For example, for connector secrets save `CONNECTOR_MISP_MY_SECRET` to reference `MISP` connector.

#### Sample

> [!NOTE]
> Follow [`ci-common-values.yaml`](../ci/ci-common-values.yaml) to see the complete example.

Following `secrets` should be cipher with external tool such as [SOPS](https://github.com/getsops/sops):

```yaml
secrets:
  APP__ADMIN__TOKEN: "b1976749-8a53-4f49-bf04-cafa2a3458c1"
  RABBITMQ__PASSWORD: ChangeMe
```

Reference with `envFromSecrets`:

```yaml
envFromSecrets:
  APP__ADMIN__TOKEN:
    name: opencti-ci-credentials
    key: APP__ADMIN__TOKEN
  OPENCTI_TOKEN:
    name: opencti-ci-credentials
    key: APP__ADMIN__TOKEN
  RABBITMQ__PASSWORD:
    name: opencti-ci-credentials
    key: RABBITMQ__PASSWORD
```

So, the `Secret` should be:

```yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: opencti-ci-credentials
  ...
data:
  APP__ADMIN__TOKEN: YjE5NzY3NDktOGE1My00ZjQ5LWJmMDQtY2FmYTJhMzQ1OGMx
  RABBITMQ__PASSWORD: Q2hhbmdlTWU=
```

And you can reference the secret in any component, for example `RabbitMQ`:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opencti-ci-rabbitmq
  namespace: "default"
  ...
    env:
    ...
      - name: RABBITMQ_PASSWORD
        valueFrom:
          secretKeyRef:
            name: opencti-ci-credentials
            key: RABBITMQ__PASSWORD
```

## Server

### Enable health checks

Enable `testConnection` to check if the service is reachable.

```yaml
testConnection: true
```

Or check each service using `readyChecker` to check if the services which depends to run OpenCTI are ready.

```yaml
readyChecker:
  # -- Enable or disable ready-checker
  enabled: true
  # -- Repository of the image
  repository: busybox
  # -- Pull policy for the image
  pullPolicy: IfNotPresent
  # -- Overrides the image tag
  tag: latest
  # -- Number of retries before giving up
  retries: 30
  # -- Timeout for each check
  timeout: 5
  # -- List services
  services:
  # - name: service_name
  #   port: service_port
  #   address: service_address  # (Optional) This parameter is optional. If
  #   not specified, the address for the check will be automatically
  #   determined assuming the service was installed using a subchart. It is
  #   useful to specify it when the service is provisioned differently (e.g.,
  #   an S3 bucket created in the Cloud or an Elasticsearch instance outside
  #   the Kubernetes cluster). The address can be an IP address or a DNS name.
  - name: elasticsearch
    port: 9200
    address: 172.0.0.1
  - name: minio
    port: 9000
  - name: rabbitmq
    port: 5672
  - name: redis-master
    port: 6379
```

In deep this config are deployed as a initial container which check the services (review [deployment.yaml](../templates/server/deployment.yaml)):

```yaml
      initContainers:
      {{- if .Values.readyChecker.enabled }}
        {{- range $service := .Values.readyChecker.services }}
        - name: ready-checker-{{ $service.name }}
          {{- if $.Values.global.imageRegistry }}
          image: "{{ $.Values.global.imageRegistry }}/{{ $.Values.readyChecker.repository }}:{{ $.Values.readyChecker.tag }}"
          {{- else }}
          image: {{ $.Values.readyChecker.repository }}:{{ $.Values.readyChecker.tag }}
          {{- end }}
          imagePullPolicy: {{ $.Values.readyChecker.pullPolicy }}
          command:
            - 'sh'
            - '-c'
            - |
              RETRY=0;
              until [ $RETRY -eq {{ $.Values.readyChecker.retries }} ];
              do
                ADDRESS="{{ if $service.address }}{{ $service.address }}{{ else }}{{ $.Values.fullnameOverride | default $.Release.Name }}-{{ $service.name }}{{ end }}";
                if nc -zv $ADDRESS {{ $service.port }}; then
                  echo "Service {{ $service.name }} with address $ADDRESS:{{ $service.port }} is ready";
                  exit 0;
                fi;
                echo "[$RETRY/{{ $.Values.readyChecker.retries }}] waiting for service {{ $service.name }} with address $ADDRESS:{{ $service.port }} to become ready";
                sleep {{ $.Values.readyChecker.timeout }};
                RETRY=$(($RETRY + 1));
                if [ $RETRY -eq {{ $.Values.readyChecker.retries }} ]; then
                  echo "Service {{ $service.name }} with address $ADDRESS:{{ $service.port }} is not ready";
                  exit 1;
                fi;
              done
          {{- end }}
        {{- end }}
        {{- with .Values.initContainers }}
          {{- toYaml . | nindent 8 }}
        {{- end }}
```

Output:

```yaml
...
      initContainers:
        - name: ready-checker-elasticsearch
          image: busybox:latest
          imagePullPolicy: IfNotPresent
          command:
            - 'sh'
            - '-c'
            - |
              RETRY=0;
              until [ $RETRY -eq 30 ];
              do
                ADDRESS="172.0.0.1";
                if nc -zv $ADDRESS 9200; then
                  echo "Service elasticsearch with address $ADDRESS:9200 is ready";
                  exit 0;
                fi;
                echo "[$RETRY/30] waiting for service elasticsearch with address $ADDRESS:9200 to become ready";
                sleep 5;
                RETRY=$(($RETRY + 1));
                if [ $RETRY -eq 30 ]; then
                  echo "Service elasticsearch with address $ADDRESS:9200 is not ready";
                  exit 1;
                fi;
              done
        - name: ready-checker-minio
          image: busybox:latest
          imagePullPolicy: IfNotPresent
          command:
            - 'sh'
            - '-c'
            - |
              RETRY=0;
              until [ $RETRY -eq 30 ];
              do
                ADDRESS="opencti-ci-minio";
                if nc -zv $ADDRESS 9000; then
                  echo "Service minio with address $ADDRESS:9000 is ready";
                  exit 0;
                fi;
                echo "[$RETRY/30] waiting for service minio with address $ADDRESS:9000 to become ready";
                sleep 5;
                RETRY=$(($RETRY + 1));
                if [ $RETRY -eq 30 ]; then
                  echo "Service minio with address $ADDRESS:9000 is not ready";
                  exit 1;
                fi;
              done
        - name: ready-checker-rabbitmq
          image: busybox:latest
          imagePullPolicy: IfNotPresent
          command:
            - 'sh'
            - '-c'
            - |
              RETRY=0;
              until [ $RETRY -eq 30 ];
              do
                ADDRESS="opencti-ci-rabbitmq";
                if nc -zv $ADDRESS 5672; then
                  echo "Service rabbitmq with address $ADDRESS:5672 is ready";
                  exit 0;
                fi;
                echo "[$RETRY/30] waiting for service rabbitmq with address $ADDRESS:5672 to become ready";
                sleep 5;
                RETRY=$(($RETRY + 1));
                if [ $RETRY -eq 30 ]; then
                  echo "Service rabbitmq with address $ADDRESS:5672 is not ready";
                  exit 1;
                fi;
              done
        - name: ready-checker-redis-master
          image: busybox:latest
          imagePullPolicy: IfNotPresent
          command:
            - 'sh'
            - '-c'
            - |
              RETRY=0;
              until [ $RETRY -eq 30 ];
              do
                ADDRESS="opencti-ci-redis-master";
                if nc -zv $ADDRESS 6379; then
                  echo "Service redis-master with address $ADDRESS:6379 is ready";
                  exit 0;
                fi;
                echo "[$RETRY/30] waiting for service redis-master with address $ADDRESS:6379 to become ready";
                sleep 5;
                RETRY=$(($RETRY + 1));
                if [ $RETRY -eq 30 ]; then
                  echo "Service redis-master with address $ADDRESS:6379 is not ready";
                  exit 1;
                fi;
              done
...
```

### Configure OpenID

```yaml
env:
...
  PROVIDERS__OPENID__CONFIG__DEFAULT_SCOPES: "[\"group\",\"email\"]"
  PROVIDERS__OPENID__CONFIG__GROUPS_MANAGEMENT__GROUPS_MAPPING: "[\"DEMO1:ADMIN\",\"DEMO2:USER\"]"
  PROVIDERS__OPENID__CONFIG__GROUPS_MANAGEMENT__GROUPS_PATH: "[\"roles\"]"
  PROVIDERS__OPENID__CONFIG__GROUPS_MANAGEMENT__GROUPS_SCOPE: "email"
  PROVIDERS__OPENID__CONFIG__GROUPS_MANAGEMENT__TOKEN_REFERENCE: "token_oidc"
  PROVIDERS__OPENID__CONFIG__ISSUER: "https://demo.mydomain.com/oidc/.well-known/config"
  PROVIDERS__OPENID__CONFIG__LABEL: "Demo Login"
  PROVIDERS__OPENID__CONFIG__ORGANIZATIONS_MANAGEMENT__ORGANIZATIONS_MAPPING: "[\"DEMO1:ORG1\",\"DEMO2:ORG2\"]"
  PROVIDERS__OPENID__CONFIG__ORGANIZATIONS_MANAGEMENT__ORGANIZATIONS_PATH: "[\"roles\"]"
  PROVIDERS__OPENID__CONFIG__ORGANIZATIONS_MANAGEMENT__ORGANIZATIONS_SCOPE: "email"
  PROVIDERS__OPENID__CONFIG__ORGANIZATIONS_MANAGEMENT__TOKEN_REFERENCE: "token_oidc"
  PROVIDERS__OPENID__CONFIG__REDIRECT_URIS: "[\"https://demo.mydomain.com/auth/oic/callback\"]"
  PROVIDERS__OPENID__STRATEGY: "OpenIDConnectStrategy"
```

## Connector

### Sample complete

```yaml
connectors:
# https://github.com/OpenCTI-Platform/connectors/tree/master/external-import/misp
- name: sample-misp
  enabled: true
  replicas: 1
  image:
    repository: opencti/connector-misp
  serviceAccount:
    create: true
  readyChecker:
    enabled: true
    retries: 30
    timeout: 10
  env:
    CONNECTOR_CONFIDENCE_LEVEL: "XXXX"
    CONNECTOR_ID: "XXXX"
    CONNECTOR_LOG_LEVEL: "XXXX"
    CONNECTOR_NAME: "XXXX"
    CONNECTOR_SCOPE: "XXXX"
    CONNECTOR_TYPE: "XXXX"
    CONNECTOR_UPDATE_EXISTING_DATA: "XXXX"
    MISP_CREATE_INDICATORS: "XXXX"
    MISP_CREATE_OBJECT_OBSERVABLES: "XXXX"
    MISP_CREATE_OBSERVABLES: "XXXX"
    MISP_CREATE_REPORTS: "XXXX"
    MISP_CREATE_TAGS_AS_LABELS: "XXXX"
    MISP_DATETIME_ATTRIBUTE: "XXXX"
    MISP_ENFORCE_WARNING_LIST: "XXXX"
    MISP_INTERVAL: "XXXX"
    MISP_REFERENCE_URL: "XXXX"
    MISP_REPORT_TYPE: "XXXX"
    MISP_SSL_VERIFY: "XXXX"
    MISP_URL: "XXXX"
  envFromSecrets:
    MISP_KEY:
      name:  my-secret-credentials
      key: MISP_KEY
  resources:
    requests:
      memory: 128Mi
      cpu: 100m
    limits:
      memory: 128Mi
```

You can config which node to run the connector using `nodeSelector` and `tolerations`.

```yaml
connector:
- name: sample-misp
  ...
  nodeSelector:
    project: "opencti"
  tolerations:
    - key: "project"
      operator: "Equal"
      value: "opencti"
      effect: "NoSchedule"
```

Or you can use affinity to run the connector in different node if you increase replicas.

```yaml
- name: sample-misp
  ...
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: opencti.connector
                operator: In
                values:
                  - sample-misp
          topologyKey: kubernetes.io/hostname
```

### Configure image

You can configure default `image` to run the connector or use default `image`.

If you don't set `image` block, by default use `opencti/<name-connector>:<Chart.AppVersion>`.

```yaml
connectors:
- name: sample-misp
  enabled: true
  replicas: 1
  ...
```

This config use default image: `opencti/sample-misp:6.2.18`

You can configure `repository` and `tag` to use a custom image.

```yaml
connectors:
- name: sample-misp
  enabled: true
  replicas: 1
  image:
    repository: my-private-repo/connector-misp-sample
    tag: "6.2.15"
  ...
```

Now, this config set an image: `my-private-repo/connector-misp-sample:6.2.15`

### Configure serviceAccount

You can configure default `serviceAccount` to run the connector or use a custom `serviceAccount`. Following code, create a `serviceAccount` named `test` to run the connector.

```yaml
...
connectors:
- name: sample-misp
  enabled: true
  replicas: 1
  serviceAccount:
    create: true
    name: test
    automountServiceAccountToken: true # false by default
```

Result:

```yaml
# Source: opencti/templates/connector/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: test
  labels:
    opencti.connector: sample-misp
    ...
automountServiceAccountToken: true
--
# Source: opencti/templates/connector/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-misp-connector-opencti
  ...
spec:
  ...
  template:
    ...
    spec:
      serviceAccountName: test
```

If you want use default `name` (`<name-connector>-connector-<release-name>`) you can use `create: true` only.

```yaml
...
connectors:
- name: sample-misp
  enabled: true
  replicas: 1
  serviceAccount:
    create: true
```

Result:

```yaml
# Source: opencti/templates/connector/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sample-misp-connector-opencti
  labels:
    opencti.connector: sample-misp
    ...
automountServiceAccountToken: true
--
# Source: opencti/templates/connector/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-misp-connector-opencti
  ...
spec:
  ...
  template:
    ...
    spec:
      serviceAccountName: sample-misp-connector-opencti
```

### Configure metrics

You can enable Prometheus metric scraping with a serviceMonitor object
```yaml
connectors:
- name: sample-misp
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    scrapeTimeout: 10s
  env:
    ...
    CONNECTOR_EXPOSE_METRICS: true
    ...
```

The `interval` and `scrapeTimeout` are optional and can be omitted in order to use the defaults. Make sure to set the enviroment variable `CONNECTOR_EXPOSE_METRICS` to `true`.
