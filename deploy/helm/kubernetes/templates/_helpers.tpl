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
{{- $name := default "kubernetes" .Values.nameOverride -}}
{{- if eq (.Release.Name | upper) "RELEASE-NAME" -}}
{{- $name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
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
