{{- define "opencti.deploymentTemplate" -}}
{{- $serverType := .serverType -}}
{{- $healthKey := "" }}
{{- range .Values.secrets }}
  {{- if and (eq $healthKey "") (hasKey .data "APP__HEALTH_ACCESS_KEY") }}
    {{- $healthKey = index .data "APP__HEALTH_ACCESS_KEY" }}
  {{- end }}
{{- end }}
{{- if eq $healthKey "" }}
  {{- $healthKey = .Values.env.APP__HEALTH_ACCESS_KEY | default "" }}
{{- end }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "opencti.fullname" . }}-{{ $serverType }}
  labels:
    {{- if .Values.clustering.enabled }}
    {{- if eq $serverType "frontend" }}
    {{- include "opencti.frontendLabels" . | nindent 4 }}
    {{- else if eq $serverType "ingestion" }}
    {{- include "opencti.ingestionLabels" . | nindent 4 }}
    {{- end }}
    {{- else }}
    {{- include "opencti.serverLabels" . | nindent 4 }}
    {{- end }}
spec:
  {{- if not .Values.clustering.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- else if eq $serverType "frontend" }}
  replicas: {{ .Values.clustering.frontend.replicaCount | default 1 }}
  {{- else if eq $serverType "ingestion" }}
  replicas: {{ .Values.clustering.ingestion.replicaCount | default 1 }}
  {{- end }}
  {{- with .Values.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- if .Values.clustering.enabled }}
      {{- if eq $serverType "frontend" }}
      {{- include "opencti.selectorFrontendLabels" . | nindent 6 }}
      {{- else if eq $serverType "ingestion" }}
      {{- include "opencti.selectorIngestionLabels" . | nindent 6 }}
      {{- end }}
      {{- else }}
      {{- include "opencti.selectorServerLabels" . | nindent 6 }}
      {{- end }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- if .Values.clustering.enabled }}
        {{- if eq $serverType "frontend" }}
        {{- include "opencti.selectorFrontendLabels" . | nindent 8 }}
        {{- else if eq $serverType "ingestion" }}
        {{- include "opencti.selectorIngestionLabels" . | nindent 8 }}
        {{- end }}
        {{- else }}
        {{- include "opencti.selectorServerLabels" . | nindent 8 }}
        {{- end }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- if .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml .Values.imagePullSecrets | nindent 8 }}
      {{- else if .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml .Values.global.imagePullSecrets | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "opencti.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      initContainers:
      {{- if .Values.readyChecker.enabled }}
        {{- range $service := .Values.readyChecker.services }}
        - name: ready-checker-{{ $service.name }}
          securityContext:
            {{- toYaml $.Values.securityContext | nindent 12 }}
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
      containers:
        - name: {{ .Chart.Name }}-{{ $serverType }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          {{- if .Values.global.imageRegistry }}
          image: "{{ .Values.global.imageRegistry }}/{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          {{- else }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          {{- end }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          {{- with .Values.command }}
          command: {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.args }}
          args: {{- toYaml . | nindent 12 }}
          {{- end }}
          ports:
            - name: http
              {{- if .Values.clustering.enabled }}
              {{- if eq $serverType "frontend" }}
              containerPort: {{ .Values.clustering.frontend.service.targetPort | default .Values.service.targetPort | default .Values.service.port }}
              {{- else if eq $serverType "ingestion" }}
              containerPort: {{ .Values.clustering.ingestion.service.targetPort | default .Values.service.targetPort | default .Values.service.port }}
              {{- end }}
              {{- else }}
              containerPort: {{ .Values.service.targetPort | default .Values.service.port }}
              {{- end }}
              protocol: TCP
            {{- if .Values.clustering.enabled }}
            {{- if eq $serverType "frontend" }}
            {{- range $port := .Values.clustering.frontend.service.extraPorts }}
            - name: {{ $port.name }}
              containerPort: {{ $port.targetPort }}
              protocol: TCP
            {{- end }}
            {{- else if eq $serverType "ingestion" }}
            {{- range $port := .Values.clustering.ingestion.service.extraPorts }}
            - name: {{ $port.name }}
              containerPort: {{ $port.targetPort }}
              protocol: TCP
            {{- end }}
            {{- end }}
            {{- else }}
            {{- range $port := .Values.service.extraPorts }}
            - name: {{ $port.name }}
              containerPort: {{ $port.targetPort }}
              protocol: TCP
            {{- end }}
            {{- end }}
            {{- if .Values.serviceMonitor.enabled }}
            - name: metrics
              containerPort: {{ .Values.env.APP__TELEMETRY__METRICS__EXPORTER_PROMETHEUS | default 14269 }}
              protocol: TCP
            {{- end }}
          lifecycle:
            {{- with .Values.lifecycle }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- if .Values.livenessProbe.enabled }}
          livenessProbe:
            {{- if .Values.livenessProbeCustom }}
            {{- toYaml .Values.livenessProbeCustom | nindent 12 }}
            {{- else }}
            httpGet:
              path: {{ .Values.service.healthPath | default (printf "/health?health_access_key=%s" $healthKey) | quote }}
              {{- if .Values.clustering.enabled }}
              {{- if eq $serverType "frontend" }}
              port: {{ .Values.clustering.frontend.service.targetPort | default .Values.service.targetPort | default .Values.service.port }}
              {{- else if eq $serverType "ingestion" }}
              port: {{ .Values.clustering.ingestion.service.targetPort | default .Values.service.targetPort | default .Values.service.port }}
              {{- end }}
              {{- else }}
              port: {{ .Values.service.targetPort | default .Values.service.port }}
              {{- end }}
            failureThreshold: {{ .Values.livenessProbe.failureThreshold }}
            initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
            successThreshold: {{ .Values.livenessProbe.successThreshold }}
            timeoutSeconds: {{ .Values.livenessProbe.timeoutSeconds }}
            {{- end }}
          {{- end }}
          {{- if .Values.readinessProbe.enabled }}
          readinessProbe:
            {{- if .Values.readinessProbeCustom }}
            {{- toYaml .Values.readinessProbeCustom | nindent 12 }}
            {{- else }}
            httpGet:
              path: {{ .Values.service.healthPath | default (printf "/health?health_access_key=%s" $healthKey) | quote }}
              {{- if .Values.clustering.enabled }}
              {{- if eq $serverType "frontend" }}
              port: {{ .Values.clustering.frontend.service.targetPort | default .Values.service.targetPort | default .Values.service.port }}
              {{- else if eq $serverType "ingestion" }}
              port: {{ .Values.clustering.ingestion.service.targetPort | default .Values.service.targetPort | default .Values.service.port }}
              {{- end }}
              {{- else }}
              port: {{ .Values.service.targetPort | default .Values.service.port }}
              {{- end }}
            failureThreshold: {{ .Values.readinessProbe.failureThreshold }}
            initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.readinessProbe.periodSeconds }}
            successThreshold: {{ .Values.readinessProbe.successThreshold }}
            timeoutSeconds: {{ .Values.readinessProbe.timeoutSeconds }}
            {{- end }}
          {{- end }}
          {{- if .Values.startupProbe.enabled }}
          startupProbe:
            {{- if .Values.startupProbeCustom }}
            {{- toYaml .Values.startupProbeCustom | nindent 12 }}
            {{- else }}
            httpGet:
              path: {{ .Values.service.healthPath | default (printf "/health?health_access_key=%s" $healthKey) | quote }}
              {{- if .Values.clustering.enabled }}
              {{- if eq $serverType "frontend" }}
              port: {{ .Values.clustering.frontend.service.targetPort | default .Values.service.targetPort | default .Values.service.port }}
              {{- else if eq $serverType "ingestion" }}
              port: {{ .Values.clustering.ingestion.service.targetPort | default .Values.service.targetPort | default .Values.service.port }}
              {{- end }}
              {{- else }}
              port: {{ .Values.service.targetPort | default .Values.service.port }}
              {{- end }}
            failureThreshold: {{ .Values.startupProbe.failureThreshold }}
            initialDelaySeconds: {{ .Values.startupProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.startupProbe.periodSeconds }}
            successThreshold: {{ .Values.startupProbe.successThreshold }}
            timeoutSeconds: {{ .Values.startupProbe.timeoutSeconds }}
            {{- end }}
          {{- end }}
          envFrom:
            {{- if .Values.envFromFiles }}
            {{- tpl (toYaml .Values.envFromFiles) . | nindent 12 }}
            {{- end }}
          env:
            # Variables from secrets have precedence
            {{- $envList := dict -}}
            {{- if .Values.envFromSecrets }}
            {{- range $key, $value := .Values.envFromSecrets }}
            {{- if not (hasKey $envList $key) }}
            - name: {{ $key | upper }}
              valueFrom:
                secretKeyRef:
                  name: {{ $value.name }}
                  key: {{ $value.key | default $key }}
            {{- $_ := set $envList $key true }}
            {{- end }}
            {{- end }}
            {{- end }}
            # Variables from configmap have precedence
            {{- if .Values.envFromConfigMap }}
            {{- range $key, $value := .Values.envFromConfigMap }}
            {{- if not (hasKey $envList $key) }}
            - name: {{ $key | upper }}
              valueFrom:
                configMapKeyRef:
                  name: {{ $value.name }}
                  key: {{ $value.key | default $key }}
            {{- $_ := set $envList $key true }}
            {{- end }}
            {{- end }}
            {{- end }}
            # Add variables in plain text if they were not already added from secrets
            {{- if .Values.env }}
            {{- range $key, $value := .Values.env }}
            {{- if not (hasKey $envList $key) }}
            - name: {{ $key | upper }}
              value: {{ $value | quote }}
            {{- $_ := set $envList $key true }}
            {{- end }}
            {{- end }}
            {{- end }}
            # Clustering-specific environment variables
            {{- if .Values.clustering.enabled }}
            {{- if eq $serverType "frontend" }}
            {{- range $key, $value := .Values.clustering.frontend.env }}
            {{- if not (hasKey $envList $key) }}
            - name: {{ $key | upper }}
              value: {{ $value | quote }}
            {{- $_ := set $envList $key true }}
            {{- end }}
            {{- end }}
            {{- else if eq $serverType "ingestion" }}
            {{- range $key, $value := .Values.clustering.ingestion.env }}
            {{- if not (hasKey $envList $key) }}
            - name: {{ $key | upper }}
              value: {{ $value | quote }}
            {{- $_ := set $envList $key true }}
            {{- end }}
            {{- end }}
            {{- end }}
            {{- end }}
          resources:
            {{- if .Values.clustering.enabled }}
            {{- if eq $serverType "frontend" }}
            {{- toYaml (.Values.clustering.frontend.resources | default .Values.resources) | nindent 12 }}
            {{- else if eq $serverType "ingestion" }}
            {{- toYaml (.Values.clustering.ingestion.resources | default .Values.resources) | nindent 12 }}
            {{- end }}
            {{- else }}
            {{- toYaml .Values.resources | nindent 12 }}
            {{- end }}
          volumeMounts:
            {{- if .Values.securityContext.readOnlyRootFilesystem }}
            # Automatically mount /tmp as writable when readOnlyRootFilesystem is enabled
            - name: tmp
              mountPath: /tmp
            {{- end }}
            {{- with .Values.volumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
      volumes:
        {{- if .Values.securityContext.readOnlyRootFilesystem }}
        # Automatically provide writable /tmp when readOnlyRootFilesystem is enabled
        - name: tmp
          emptyDir: {}
        {{- end }}
        {{- with .Values.volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if .Values.clustering.enabled }}
      {{- if eq $serverType "frontend" }}
      {{- with (.Values.clustering.frontend.affinity | default .Values.affinity) }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (.Values.clustering.frontend.tolerations | default .Values.tolerations) }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (.Values.clustering.frontend.topologySpreadConstraints | default .Values.topologySpreadConstraints) }}
      {{- $_ := include "opencti.patchTopologySpreadConstraintsFrontend" $ }}
      topologySpreadConstraints:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- else if eq $serverType "ingestion" }}
      {{- with (.Values.clustering.ingestion.affinity | default .Values.affinity) }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (.Values.clustering.ingestion.tolerations | default .Values.tolerations) }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (.Values.clustering.ingestion.topologySpreadConstraints | default .Values.topologySpreadConstraints) }}
      {{- $_ := include "opencti.patchTopologySpreadConstraintsIngestion" $ }}
      topologySpreadConstraints:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- end }}
      {{- else }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{- $patchedConstraints := . }}
        {{- range $constraint := $patchedConstraints }}
          {{- if not $constraint.labelSelector }}
            {{- $_ := set $constraint "labelSelector" (dict "matchLabels" (dict)) }}
          {{- end }}
          {{- if not $constraint.labelSelector.matchLabels }}
            {{- $_ := set $constraint.labelSelector "matchLabels" (dict) }}
          {{- end }}
          {{- $selectorLabels := include "opencti.selectorServerLabels" $ | fromYaml }}
          {{- range $key, $value := $selectorLabels }}
            {{- $_ := set $constraint.labelSelector.matchLabels $key $value }}
          {{- end }}
          {{- $_ := set $constraint.labelSelector.matchLabels "opencti.component" $serverType }}
        {{- end }}
        {{- toYaml $patchedConstraints | nindent 8 }}
      {{- end }}
      {{- end }}
      {{- with .Values.dnsConfig }}
      dnsConfig:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.dnsPolicy }}
      dnsPolicy: {{ . }}
      {{- end }}
{{- end -}}
