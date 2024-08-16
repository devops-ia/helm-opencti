# Examples

## Global: create secrets

Use `secrets` to create secrets to reference with `envFromSecrets`. By default the secret is created in the same namespace of the release.

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

## Server: health checks

Enable `testConnection` to check if the service is reachable.

```yaml
testConnection: true
```

Or check each service using `readyChecker` to check if the services which depends to run OpenCTI are ready.

> [!IMPORTANT]
> Only works with servies which are deployed like deps in this chart.

```yaml
readyChecker:
  enabled: true
  # -- Number of retries before giving up
  retries: 30
  # -- Timeout for each check
  timeout: 5
  # -- List services
  services:
  - name: elasticsearch
    port: 9200
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
      {{- range $service := .Values.readyChecker.services }}
      - name: ready-checker-{{ $service.name }}
        image: busybox
        command:
          - 'sh'
          - '-c'
          - 'RETRY=0; until [ $RETRY -eq {{ $.Values.readyChecker.retries }} ]; do nc -zv {{ $.Values.fullnameOverride | default $.Release.Name }}-{{ $service.name }} {{ $service.port }} && break; echo "[$RETRY/{{ $.Values.readyChecker.retries }}] waiting service {{ $.Values.fullnameOverride | default $.Release.Name }}-{{ $service.name }}:{{ $service.port }} is ready"; sleep {{ $.Values.readyChecker.timeout }}; RETRY=$(($RETRY + 1)); done'
      {{- end }}
```

Output:

```yaml
...
      initContainers:
      - name: ready-checker-elasticsearch
        image: busybox
        command:
          - 'sh'
          - '-c'
          - 'RETRY=0; until [ $RETRY -eq 30 ]; do nc -zv opencti-ci-elasticsearch 9200 && break; echo "[$RETRY/30] waiting service opencti-ci-elasticsearch:9200 is ready"; sleep 5; RETRY=$(($RETRY + 1)); done'
      - name: ready-checker-minio
        image: busybox
        command:
          - 'sh'
          - '-c'
          - 'RETRY=0; until [ $RETRY -eq 30 ]; do nc -zv opencti-ci-minio 9000 && break; echo "[$RETRY/30] waiting service opencti-ci-minio:9000 is ready"; sleep 5; RETRY=$(($RETRY + 1)); done'
      - name: ready-checker-rabbitmq
        image: busybox
        command:
          - 'sh'
          - '-c'
          - 'RETRY=0; until [ $RETRY -eq 30 ]; do nc -zv opencti-ci-rabbitmq 5672 && break; echo "[$RETRY/30] waiting service opencti-ci-rabbitmq:5672 is ready"; sleep 5; RETRY=$(($RETRY + 1)); done'
      - name: ready-checker-redis-master
        image: busybox
        command:
          - 'sh'
          - '-c'
          - 'RETRY=0; until [ $RETRY -eq 30 ]; do nc -zv opencti-ci-redis-master 6379 && break; echo "[$RETRY/30] waiting service opencti-ci-redis-master:6379 is ready"; sleep 5; RETRY=$(($RETRY + 1)); done'
```

## Server: configure OpenID

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

## Connector: sample complete

```yaml
connectors:
# https://github.com/OpenCTI-Platform/connectors/tree/master/external-import/misp
- name: sample-misp
  enabled: true
  replicas: 1
  image:
    repository: opencti/connector-misp
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

You can config which node to run the connector using nodeSelector and tolerations.

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
