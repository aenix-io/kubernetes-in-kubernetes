#!/bin/sh
set -e
set -x
ENDPOINT=$(awk -F'[ "]+' '$1 == "controlPlaneEndpoint:" {print $2}' /config/kubeadmcfg.yaml)

# ------------------------------------------------------------------------------
# Update secrets and component configs
# ------------------------------------------------------------------------------

# wait for cluster
echo "Waiting for api-server endpoint ${ENDPOINT}..."
until kubectl cluster-info >/dev/null 2>/dev/null; do
  sleep 1
done

# ------------------------------------------------------------------------------
# Cluster configuration
# ------------------------------------------------------------------------------
export KUBECONFIG=/etc/kubernetes/admin.conf

# upload configuration
# TODO: https://github.com/kvaps/kubernetes-in-kubernetes/issues/6
kubeadm init phase upload-config kubeadm --config /config/kubeadmcfg.yaml
kubectl patch configmap -n kube-system kubeadm-config \
  -p '{"data":{"ClusterStatus":"apiEndpoints: {}\napiVersion: kubeadm.k8s.io/v1beta2\nkind: ClusterStatus"}}'

# upload configuration
# TODO: https://github.com/kvaps/kubernetes-in-kubernetes/issues/5
kubeadm init phase upload-config kubelet --config /config/kubeadmcfg.yaml -v1 2>&1 |
  while read line; do echo "$line" | grep 'Preserving the CRISocket information for the control-plane node' && killall kubeadm || echo "$line"; done

# setup bootstrap-tokens
# TODO: https://github.com/kvaps/kubernetes-in-kubernetes/issues/7
# TODO: https://github.com/kubernetes/kubernetes/issues/98881
flatconfig=$(mktemp)
kubectl config view --flatten > "$flatconfig"
kubeadm init phase bootstrap-token --config /config/kubeadmcfg.yaml --skip-token-print --kubeconfig="$flatconfig"
rm -f "$flatconfig"

# correct apiserver address for the external clients
kubectl apply -n kube-public -f - <<EOT
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-info
data:
  kubeconfig: |
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: $(base64 /pki/admin-client/ca.crt | tr -d '\n')
        server: https://${ENDPOINT}
      name: ""
    contexts: null
    current-context: ""
    kind: Config
    preferences: {}
    users: null
EOT

{{- if .Values.konnectivityServer.enabled }}{{"\n"}}
# install konnectivity server
kubectl apply -f /manifests/konnectivity-server-rbac.yaml
{{- else }}{{"\n"}}
kubectl delete -f /manifests/konnectivity-server-rbac.yaml 2>/dev/null || true
{{- end }}

{{- if .Values.konnectivityAgent.enabled }}{{"\n"}}
# install konnectivity agent
kubectl apply -f /manifests/konnectivity-agent-deployment.yaml -f /manifests/konnectivity-agent-rbac.yaml
{{- else }}{{"\n"}}
# uninstall konnectivity agent
kubectl delete -f /manifests/konnectivity-agent-deployment.yaml -f /manifests/konnectivity-agent-rbac.yaml 2>/dev/null || true
{{- end }}

{{- if .Values.coredns.enabled }}{{"\n"}}
# install coredns addon
kubectl apply -f /manifests/coredns.yaml
{{- else }}{{"\n"}}
# uninstall coredns addon
kubectl delete -f /manifests/coredns.yaml 2>/dev/null || true
{{- end }}

{{- if .Values.kubeProxy.enabled }}{{"\n"}}
# install kube-proxy addon
# TODO: https://github.com/kvaps/kubernetes-in-kubernetes/issues/4
kubeadm init phase addon kube-proxy --config /config/kubeadmcfg.yaml
{{- else }}{{"\n"}}
# uninstall kube-proxy addon
kubectl -n kube-system delete configmap/kube-proxy daemonset/kube-proxy 2>/dev/null || true
{{- end }}

{{- with .Values.extraManifests }}{{"\n"}}
kubectl apply{{- range $key, $value := . }} -f /manifests/{{ $key }}{{- end }}
{{- end }}
