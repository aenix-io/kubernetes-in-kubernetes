{{/* vim: set filetype=gohtmltmpl: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "kubernetes.name" -}}
{{- default "kubernetes" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "kubernetes.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "kubernetes" .Values.nameOverride -}}
{{- if or (eq $name .Release.Name) (eq (.Release.Name | upper) "RELEASE-NAME") -}}
{{- $name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create a default certificate name.
*/}}
{{- define "kubernetes.certname" -}}
{{- if .Values.certnameOverride -}}
{{- .Values.certnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- template "kubernetes.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Generate etcd servers list.
*/}}
{{- define "kubernetes.etcdEndpoints" -}}
  {{- $fullName := include "kubernetes.fullname" . -}}
  {{- range $etcdcount, $e := until (int .Values.etcd.replicaCount) -}}
    {{- printf "https://" -}}
    {{- printf "%s-etcd-%d." $fullName $etcdcount -}}
    {{- printf "%s-etcd:%d" $fullName (int $.Values.etcd.ports.client) -}}
    {{- if lt $etcdcount (sub (int $.Values.etcd.replicaCount) 1 ) -}}
      {{- printf "," -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "kubernetes.etcdInitialCluster" -}}
  {{- $fullName := include "kubernetes.fullname" . -}}
  {{- range $etcdcount, $e := until (int .Values.etcd.replicaCount) -}}
    {{- printf "%s-etcd-%d=" $fullName $etcdcount -}}
    {{- printf "https://" -}}
    {{- printf "%s-etcd-%d." $fullName $etcdcount -}}
    {{- printf "%s-etcd:%d" $fullName (int $.Values.etcd.ports.peer) -}}
    {{- if lt $etcdcount (sub (int $.Values.etcd.replicaCount) 1 ) -}}
      {{- printf "," -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Take the first IP address from the serviceClusterIPRange for the kube-dns service.
*/}}
{{- define "getCoreDNS" -}}
  {{- $octetsList := splitList "." .Values.apiServer.serviceClusterIPRange -}}
  {{- printf "%d.%d.%d.%d" (index $octetsList 0 | int) (index $octetsList 1 | int) (index $octetsList 2 | int) 10 -}}
{{- end -}}

{{- define "getAPIAddress" -}}
  {{- $octetsList := splitList "." .Values.apiServer.serviceClusterIPRange -}}
  {{- printf "%d.%d.%d.%d" (index $octetsList 0 | int) (index $octetsList 1 | int) (index $octetsList 2 | int) 1 -}}
{{- end -}}

{{/*
Template for konnectivityServer containers
*/}}
{{- define "kubernetes.konnectivityServer.containers" -}}
      - command:
        - /proxy-server
        - --logtostderr=true
        - --server-count={{ .Values.konnectivityServer.replicaCount }}
        - --server-id=$(POD_NAME)
        - --cluster-cert=/pki/apiserver/tls.crt
        - --cluster-key=/pki/apiserver/tls.key
        {{- if eq .Values.konnectivityServer.mode "HTTPConnect" }}
        - --mode=http-connect
        - --server-port={{ .Values.konnectivityServer.ports.server }}
        - --server-ca-cert=/pki/konnectivity-server/ca.crt
        - --server-cert=/pki/konnectivity-server/tls.crt
        - --server-key=/pki/konnectivity-server/tls.key
        {{- else }}
        - --mode=grpc
        - --uds-name=/run/konnectivity-server/konnectivity-server.socket
        - --server-port=0
        {{- end }}
        - --agent-port={{ .Values.konnectivityServer.ports.agent }}
        - --admin-port={{ .Values.konnectivityServer.ports.admin }}
        - --health-port={{ .Values.konnectivityServer.ports.health }}
        - --agent-namespace=kube-system
        - --agent-service-account=konnectivity-agent
        - --kubeconfig=/etc/kubernetes/konnectivity-server.conf
        - --authentication-audience=system:konnectivity-server
        {{- range $key, $value := .Values.konnectivityServer.extraArgs }}
        - --{{ $key }}={{ $value }}
        {{- end }}
        ports:
        {{- if eq .Values.konnectivityServer.mode "HTTPConnect" }}
        - containerPort: {{ .Values.konnectivityServer.ports.server }}
          name: server
        {{- end }}
        - containerPort: {{ .Values.konnectivityServer.ports.agent }}
          name: agent
        - containerPort: {{ .Values.konnectivityServer.ports.admin }}
          name: admin
        - containerPort: {{ .Values.konnectivityServer.ports.health }}
          name: health
        {{- with .Values.konnectivityServer.image }}
        image: "{{ .repository }}{{ if .digest }}@{{ .digest }}{{ else }}:{{ .tag }}{{ end }}"
        imagePullPolicy: {{ .pullPolicy }}
        {{- end }}
        livenessProbe:
          failureThreshold: 8
          httpGet:
            path: /healthz
            port: {{ .Values.konnectivityServer.ports.health }}
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 60
        name: konnectivity-server
        resources:
          {{- toYaml .Values.konnectivityServer.resources | nindent 10 }}
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        {{- with .Values.konnectivityServer.extraEnv }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        volumeMounts:
        - mountPath: /pki/apiserver
          name: pki-apiserver
        {{- if eq .Values.konnectivityServer.mode "HTTPConnect" }}
        - mountPath: /pki/konnectivity-server
          name: pki-konnectivity-server
        {{- else }}
        - mountPath: /run/konnectivity-server
          name: konnectivity-uds
        {{- end }}
        - mountPath: /pki/konnectivity-server-client
          name: pki-konnectivity-server-client
        - mountPath: /etc/kubernetes/
          name: kubeconfig
          readOnly: true
        {{- with .Values.konnectivityServer.extraVolumeMounts }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
{{- end -}}

{{/*
Template for konnectivityServer volumes
*/}}
{{- define "kubernetes.konnectivityServer.volumes" -}}
      - secret:
          secretName: "{{ template "kubernetes.fullname" . }}-pki-apiserver-server"
        name: pki-apiserver
      {{- if eq .Values.konnectivityServer.mode "HTTPConnect" }}
      - secret:
          secretName: "{{ template "kubernetes.fullname" . }}-pki-konnectivity-server"
        name: pki-konnectivity-server
      {{- else }}
      - secret:
          secretName: "{{ template "kubernetes.fullname" . }}-pki-konnectivity-server-client"
        name: pki-konnectivity-server-client
      - emptyDir: {}
        name: konnectivity-uds
      {{- end }}
      - configMap:
          name: "{{ template "kubernetes.fullname" . }}-konnectivity-server-conf"
        name: kubeconfig
      {{- with .Values.konnectivityServer.extraVolumes }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
{{- end -}}
