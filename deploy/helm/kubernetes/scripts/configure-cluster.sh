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

cat >kubeadmcfg.yaml <<EOT
apiVersion: "kubeadm.k8s.io/v1beta2" 
kind: ClusterConfiguration 
imageRepository: k8s.gcr.io 
controlPlaneEndpoint: "${FULL_NAME}-apiserver:6443"
EOT

{{- if .Values.apiServer.enabled }}{{"\n"}}
# generate sa key
if ! kubectl get secret "${FULL_NAME}-pki-sa" >/dev/null; then
  kubeadm init phase certs sa
  kubectl create secret generic "${FULL_NAME}-pki-sa" --from-file=/etc/kubernetes/pki/sa.pub --from-file=/etc/kubernetes/pki/sa.key
fi
{{- end }}

# generate cluster-admin kubeconfig
rm -f /etc/kubernetes/admin.conf
kubeadm init phase kubeconfig admin --config kubeadmcfg.yaml
kubectl --kubeconfig=/etc/kubernetes/admin.conf config set-cluster kubernetes --server "https://${FULL_NAME}-apiserver:6443"
kubectl create secret generic "${FULL_NAME}-admin-conf" --from-file=/etc/kubernetes/admin.conf --dry-run=client -o yaml | kubectl apply -f -

{{- if .Values.controllerManager.enabled }}{{"\n"}}
# generate controller-manager kubeconfig
rm -f /etc/kubernetes/controller-manager.conf
kubeadm init phase kubeconfig controller-manager --config kubeadmcfg.yaml
kubectl --kubeconfig=/etc/kubernetes/controller-manager.conf config set-cluster kubernetes --server "https://${FULL_NAME}-apiserver:6443"
kubectl create secret generic "${FULL_NAME}-controller-manager-conf" --from-file=/etc/kubernetes/controller-manager.conf --dry-run=client -o yaml | kubectl apply -f -
{{- end }}

{{- if .Values.scheduler.enabled }}{{"\n"}}
# generate scheduler kubeconfig
rm -f /etc/kubernetes/scheduler.conf
kubeadm init phase kubeconfig scheduler --config kubeadmcfg.yaml
kubectl --kubeconfig=/etc/kubernetes/scheduler.conf config set-cluster kubernetes --server "https://${FULL_NAME}-apiserver:6443"
kubectl create secret generic "${FULL_NAME}-scheduler-conf" --from-file=/etc/kubernetes/scheduler.conf --dry-run=client -o yaml | kubectl apply -f -
{{- end }}

{{- if .Values.konnectivityServer.enabled }}{{"\n"}}
# generate konnectivity-server kubeconfig
openssl req -subj "/CN=system:konnectivity-server" -new -newkey rsa:2048 -nodes -out konnectivity.csr -keyout konnectivity.key -out konnectivity.csr
openssl x509 -req -in konnectivity.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out konnectivity.crt -days 375 -sha256
kubectl --kubeconfig /etc/kubernetes/konnectivity-server.conf config set-credentials system:konnectivity-server --client-certificate konnectivity.crt --client-key konnectivity.key --embed-certs=true
kubectl --kubeconfig /etc/kubernetes/konnectivity-server.conf config set-cluster kubernetes --server "https://${FULL_NAME}-apiserver:6443" --certificate-authority /etc/kubernetes/pki/ca.crt --embed-certs=true
kubectl --kubeconfig /etc/kubernetes/konnectivity-server.conf config set-context system:konnectivity-server@kubernetes --cluster kubernetes --user system:konnectivity-server
kubectl --kubeconfig /etc/kubernetes/konnectivity-server.conf config use-context system:konnectivity-server@kubernetes
kubectl create secret generic "${FULL_NAME}-konnectivity-server-conf" --from-file=/etc/kubernetes/konnectivity-server.conf --dry-run=client -o yaml | kubectl apply -f -
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
kubeadm init phase upload-config kubelet --config /config/kubeadmcfg.yaml -v1 2>&1 |
  while read line; do echo "$line" | grep 'Preserving the CRISocket information for the control-plane node' && killall kubeadm || echo "$line"; done

# setup bootstrap-tokens
kubeadm init phase bootstrap-token --config /config/kubeadmcfg.yaml --skip-token-print

# correct apiserver address for the external clients
tmp="$(mktemp -d)"
kubectl --kubeconfig "$tmp/kubeconfig" config set clusters..server "https://${CONTROL_PLANE_ENDPOINT:-${FULL_NAME}-apiserver:6443}"
kubectl --kubeconfig "$tmp/kubeconfig" config set clusters..certificate-authority-data "$(base64 /etc/kubernetes/pki/ca.crt | tr -d '\n')"
kubectl create configmap cluster-info --from-file="$tmp/kubeconfig" --dry-run=client -o yaml | kubectl --kubeconfig /etc/kubernetes/admin.conf apply -n kube-public -f -
rm -rf "$tmp"

{{- if .Values.konnectivityServer.enabled }}{{"\n"}}
# install konnectivity server
kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f /manifests/konnectivity-server-rbac.yaml
{{- else }}{{"\n"}}
kubectl --kubeconfig /etc/kubernetes/admin.conf delete clusterrolebinding/system:konnectivity-server 2>/dev/null || true
{{- end }}

{{- if .Values.konnectivityAgent.enabled }}{{"\n"}}
# install konnectivity agent
kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f /manifests/konnectivity-agent-deployment.yaml -f /manifests/konnectivity-agent-rbac.yaml
{{- else }}{{"\n"}}
# uninstall konnectivity agent
kubectl --kubeconfig /etc/kubernetes/admin.conf -n kube-system delete deployment/konnectivity-agent serviceaccount/konnectivity-agent 2>/dev/null || true
{{- end }}

{{- if .Values.coredns.enabled }}{{"\n"}}
# install coredns addon
kubeadm init phase addon coredns --config /config/kubeadmcfg.yaml
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
