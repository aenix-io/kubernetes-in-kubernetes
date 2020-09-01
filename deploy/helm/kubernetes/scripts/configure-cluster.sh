#!/bin/sh
set -e
set -x

# ------------------------------------------------------------------------------
# Setup environment
# ------------------------------------------------------------------------------

mkdir -p /etc/kubernetes/pki
ln -sf /pki/apiserver-etcd-client/tls.crt /etc/kubernetes/pki/apiserver-etcd-client.crt
ln -sf /pki/apiserver-etcd-client/tls.key /etc/kubernetes/pki/apiserver-etcd-client.key
ln -sf /pki/apiserver-kubelet-client/tls.crt /etc/kubernetes/pki/apiserver-kubelet-client.crt
ln -sf /pki/apiserver-kubelet-client/tls.key /etc/kubernetes/pki/apiserver-kubelet-client.key
ln -sf /pki/apiserver/tls.crt /etc/kubernetes/pki/apiserver.crt
ln -sf /pki/apiserver/tls.key /etc/kubernetes/pki/apiserver.key
ln -sf /pki/ca/tls.crt /etc/kubernetes/pki/ca.crt
ln -sf /pki/ca/tls.key /etc/kubernetes/pki/ca.key
ln -sf /pki/front-proxy-ca/tls.key /etc/kubernetes/pki/front-proxy-ca.crt
ln -sf /pki/front-proxy-ca/tls.crt /etc/kubernetes/pki/front-proxy-ca.key
ln -sf /pki/front-proxy-client/tls.key /etc/kubernetes/pki/front-proxy-client.crt
ln -sf /pki/front-proxy-client/tls.crt /etc/kubernetes/pki/front-proxy-client.key

# ------------------------------------------------------------------------------
# Update secrets and component configs
# ------------------------------------------------------------------------------

cat > kubeadmcfg.yaml << EOT
apiVersion: "kubeadm.k8s.io/v1beta2" 
kind: ClusterConfiguration 
imageRepository: k8s.gcr.io 
controlPlaneEndpoint: "${FULL_NAME}-apiserver:6443"
EOT

{{- if .Values.apiServer.enabled }}{{"\n"}}
# generate sa key
if [ -z "$(kubectl get secret  "${FULL_NAME}-pki-sa" -o jsonpath='{.data}')" ]; then
  kubeadm init phase certs sa
  kubectl patch secret "${FULL_NAME}-pki-sa" --type merge \
    -p "{\"data\":{\"sa.pub\":\"$(base64 /etc/kubernetes/pki/sa.pub | tr -d '\n')\", \"sa.key\":\"$(base64 /etc/kubernetes/pki/sa.key | tr -d '\n')\" }}"
fi
{{- end }}

# generate cluster-admin kubeconfig
rm -f /etc/kubernetes/admin.conf
kubeadm init phase kubeconfig admin --config kubeadmcfg.yaml
kubectl patch secret "${FULL_NAME}-admin-conf" --type merge \
  -p "{\"data\":{\"admin.conf\":\"$(base64 /etc/kubernetes/admin.conf | tr -d '\n')\" }}"

{{- if .Values.controllerManager.enabled }}{{"\n"}}
# generate controller-manager kubeconfig
rm -f /etc/kubernetes/controller-manager.conf
kubeadm init phase kubeconfig controller-manager --config kubeadmcfg.yaml
kubectl patch secret "${FULL_NAME}-controller-manager-conf" --type merge \
  -p "{\"data\":{\"controller-manager.conf\":\"$(base64 /etc/kubernetes/controller-manager.conf | tr -d '\n')\" }}"
{{- end }}


{{- if .Values.scheduler.enabled }}{{"\n"}}
# generate scheduler kubeconfig
rm -f /etc/kubernetes/scheduler.conf
kubeadm init phase kubeconfig scheduler --config kubeadmcfg.yaml
kubectl patch secret "${FULL_NAME}-scheduler-conf" --type merge \
  -p "{\"data\":{\"scheduler.conf\":\"$(base64 /etc/kubernetes/scheduler.conf | tr -d '\n')\" }}"
{{- end }}

# wait for cluster
echo "Waiting for api-server endpoint ${FULL_NAME}-apiserver:6443..."
until kubectl --kubeconfig /etc/kubernetes/admin.conf cluster-info >/dev/null 2>/dev/null; do
  sleep 1
done

# ------------------------------------------------------------------------------
# Cluster configuration
# ------------------------------------------------------------------------------
export KUBECONFIG=/etc/kubernetes/admin.conf

# upload configuration
kubeadm init phase upload-config kubeadm --config /config/kubeadmcfg.yaml
kubectl --kubeconfig /etc/kubernetes/admin.conf patch configmap -n kube-system kubeadm-config \
  -p '{"data":{"ClusterStatus":"apiEndpoints: {}\napiVersion: kubeadm.k8s.io/v1beta2\nkind: ClusterStatus"}}'

# upload configuration
kubeadm init phase upload-config kubelet --config /config/kubeadmcfg.yaml -v1 2>&1 \
  | while read line; do echo "$line" | grep 'Preserving the CRISocket information for the control-plane node' && killall kubeadm || echo "$line"; done

# setup bootstrap-tokens
kubeadm init phase bootstrap-token --config /config/kubeadmcfg.yaml --skip-token-print

# correct apiserver address for the external clients
if [ -n "$CONTROL_PLANE_ENDPOINT" ]; then
  tmp="$(mktemp -d)"
  kubectl --kubeconfig /etc/kubernetes/admin.conf get configmap -n kube-public cluster-info -o jsonpath='{.data.kubeconfig}' > "$tmp/kubeconfig"
  kubectl --kubeconfig "$tmp/kubeconfig" config set clusters..server "https://${CONTROL_PLANE_ENDPOINT}"
  kubectl create configmap cluster-info --from-file="$tmp/kubeconfig" --dry-run=client -o yaml | kubectl --kubeconfig /etc/kubernetes/admin.conf apply -n kube-public -f -
  rm -rf "$tmp"
fi

{{- if .Values.coredns.enabled }}{{"\n"}}
# install coredns addon
kubeadm init phase addon coredns --config /config/kubeadmcfg.yaml || true #TODO: workaround https://github.com/kubernetes/kubeadm/issues/2267
{{- else }}{{"\n"}}
# uninstall coredns addon
kubectl --kubeconfig /etc/kubernetes/admin.conf -n kube-system delete configmap/coredns deployment/coredns 2>/dev/null || true
{{- end }}

{{- if .Values.kubeProxy.enabled }}{{"\n"}}
# install kube-proxy addon
kubeadm init phase addon kube-proxy --config /config/kubeadmcfg.yaml
{{- else }}{{"\n"}}
# uninstall kube-proxy addon
kubectl --kubeconfig /etc/kubernetes/admin.conf -n kube-system delete configmap/kube-proxy daemonset/kube-proxy 2>/dev/null || true
{{- end }}
