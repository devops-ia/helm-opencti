{{- define "opencti.serviceTemplate" -}}
{{- $serverType := .serverType -}}
{{- $serviceConfig := .serviceConfig -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "opencti.fullname" . }}-{{ $serverType }}
  labels:
    {{- include "opencti.serverLabels" . | nindent 4 }}
    opencti.component: {{ $serverType }}
    {{- with $serviceConfig.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $serviceConfig.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ $serviceConfig.type }}
  {{- if and (eq $serviceConfig.type "ClusterIP") (eq $serviceConfig.clusterIP "None") }}
  clusterIP: None
  {{- else if $serviceConfig.clusterIP }}
  clusterIP: {{ $serviceConfig.clusterIP }}
  {{- end }}
  {{- if $serviceConfig.clusterIPs }}
  clusterIPs:
    {{- toYaml $serviceConfig.clusterIPs | nindent 4 }}
  {{- end }}
  {{- if $serviceConfig.externalIPs }}
  externalIPs:
    {{- toYaml $serviceConfig.externalIPs | nindent 4 }}
  {{- end }}
  {{- if and (eq $serviceConfig.type "LoadBalancer") $serviceConfig.loadBalancer.ip }}
  loadBalancerIP: {{ $serviceConfig.loadBalancer.ip }}
  {{- end }}
  {{- if and (eq $serviceConfig.type "LoadBalancer") $serviceConfig.loadBalancer.sourceRanges }}
  loadBalancerSourceRanges:
    {{- toYaml $serviceConfig.loadBalancer.sourceRanges | nindent 4 }}
  {{- end }}
  {{- if and (eq $serviceConfig.type "LoadBalancer") $serviceConfig.loadBalancer.class }}
  loadBalancerClass: {{ $serviceConfig.loadBalancer.class }}
  {{- end }}
  {{- if and (eq $serviceConfig.type "ExternalName") $serviceConfig.externalName }}
  externalName: {{ $serviceConfig.externalName }}
  {{- end }}
  {{- if and (or (eq $serviceConfig.type "NodePort") (eq $serviceConfig.type "LoadBalancer")) $serviceConfig.externalTrafficPolicy }}
  externalTrafficPolicy: {{ $serviceConfig.externalTrafficPolicy }}
  {{- end }}
  {{- if $serviceConfig.internalTrafficPolicy }}
  internalTrafficPolicy: {{ $serviceConfig.internalTrafficPolicy }}
  {{- end }}
  {{- if and (eq $serviceConfig.type "LoadBalancer") $serviceConfig.healthCheckNodePort }}
  healthCheckNodePort: {{ $serviceConfig.healthCheckNodePort }}
  {{- end }}
  {{- if $serviceConfig.publishNotReadyAddresses }}
  publishNotReadyAddresses: {{ $serviceConfig.publishNotReadyAddresses }}
  {{- end }}
  {{- if $serviceConfig.sessionAffinity }}
  sessionAffinity: {{ $serviceConfig.sessionAffinity }}
  {{- if and (eq $serviceConfig.sessionAffinity "ClientIP") $serviceConfig.sessionAffinityConfig }}
  sessionAffinityConfig:
    clientIP:
      {{- if $serviceConfig.sessionAffinityConfig.clientIP.timeoutSeconds }}
      timeoutSeconds: {{ $serviceConfig.sessionAffinityConfig.clientIP.timeoutSeconds }}
      {{- end }}
  {{- end }}
  {{- end }}
  {{- if $serviceConfig.ipFamilies }}
  ipFamilies:
    {{- toYaml $serviceConfig.ipFamilies | nindent 4 }}
  {{- end }}
  {{- if $serviceConfig.ipFamilyPolicy }}
  ipFamilyPolicy: {{ $serviceConfig.ipFamilyPolicy }}
  {{- end }}
  {{- if and (eq $serviceConfig.type "LoadBalancer") (hasKey $serviceConfig "allocateLoadBalancerNodePorts") }}
  allocateLoadBalancerNodePorts: {{ $serviceConfig.allocateLoadBalancerNodePorts }}
  {{- end }}
  {{- if $serviceConfig.trafficDistribution }}
  trafficDistribution: {{ $serviceConfig.trafficDistribution }}
  {{- end }}
  ports:
    - port: {{ $serviceConfig.port }}
      targetPort: {{ $serviceConfig.targetPort | default $serviceConfig.port }}
      protocol: {{ $serviceConfig.protocol | default "TCP" }}
      name: {{ $serviceConfig.portName | default "http" }}
      {{- if and (or (eq $serviceConfig.type "NodePort") (eq $serviceConfig.type "LoadBalancer")) $serviceConfig.nodePort }}
      nodePort: {{ $serviceConfig.nodePort }}
      {{- end }}
      {{- if $serviceConfig.appProtocol }}
      appProtocol: {{ $serviceConfig.appProtocol }}
      {{- end }}
    {{- range $port := $serviceConfig.extraPorts }}
    - name: {{ $port.name }}
      port: {{ $port.port }}
      targetPort: {{ $port.targetPort | default $port.port }}
      protocol: {{ $port.protocol | default "TCP" }}
      {{- if and (or (eq $serviceConfig.type "NodePort") (eq $serviceConfig.type "LoadBalancer")) $port.nodePort }}
      nodePort: {{ $port.nodePort }}
      {{- end }}
      {{- if $port.appProtocol }}
      appProtocol: {{ $port.appProtocol }}
      {{- end }}
    {{- end }}
    {{- if .Values.env.APP__TELEMETRY__METRICS__ENABLED }}
    - name: metrics
      port: {{ .Values.env.APP__TELEMETRY__METRICS__EXPORTER_PROMETHEUS | default 14269 }}
      targetPort: {{ .Values.env.APP__TELEMETRY__METRICS__EXPORTER_PROMETHEUS | default 14269 }}
      protocol: TCP
    {{- end }}
  selector:
    {{- include "opencti.selectorServerLabels" . | nindent 4 }}
    opencti.component: {{ $serverType }}
{{- end -}}
