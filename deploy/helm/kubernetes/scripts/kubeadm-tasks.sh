#!/bin/sh
set -e

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


cat > kubeadmcfg.yaml << EOT
apiVersion: "kubeadm.k8s.io/v1beta2" 
kind: ClusterConfiguration 
imageRepository: k8s.gcr.io 
controlPlaneEndpoint: "${FULL_NAME}-apiserver:6443"
EOT

if ! kubectl get secret "${FULL_NAME}-pki-sa" >/dev/null 2>&1; then
  kubeadm init phase certs sa
  kubectl create secret generic "${FULL_NAME}-pki-sa" --from-file=/etc/kubernetes/pki/sa.pub --from-file=/etc/kubernetes/pki/sa.key
fi

rm -f /etc/kubernetes/admin.conf
kubeadm init phase kubeconfig admin --config kubeadmcfg.yaml
kubectl create secret generic "${FULL_NAME}-admin-conf" --from-file=/etc/kubernetes/admin.conf --dry-run=client -o yaml | kubectl apply -f -

rm -f /etc/kubernetes/controller-manager.conf
kubeadm init phase kubeconfig controller-manager --config kubeadmcfg.yaml
kubectl create secret generic "${FULL_NAME}-controller-manager-conf" --from-file=/etc/kubernetes/controller-manager.conf --dry-run=client -o yaml | kubectl apply -f -

rm -f /etc/kubernetes/scheduler.conf
kubeadm init phase kubeconfig scheduler --config kubeadmcfg.yaml
kubectl create secret generic "${FULL_NAME}-scheduler-conf" --from-file=/etc/kubernetes/scheduler.conf --dry-run=client -o yaml | kubectl apply -f -

# wait for cluster
echo "Waiting for api-server endpoint ${FULL_NAME}-apiserver:6443..."
until kubectl --kubeconfig /etc/kubernetes/admin.conf cluster-info >/dev/null 2>/dev/null; do
  sleep 1
done

# upload configuration
kubeadm --kubeconfig /etc/kubernetes/admin.conf init phase upload-config kubeadm

kubeadm --kubeconfig /etc/kubernetes/admin.conf init phase upload-config kubelet -v1 2>&1 \
  | while read line; do echo "$line" | grep 'Preserving the CRISocket information for the control-plane node' && killall kubeadm || echo "$line"; done

kubeadm --kubeconfig /etc/kubernetes/admin.conf init phase bootstrap-token

kubeadm --kubeconfig /etc/kubernetes/admin.conf init phase addon coredns

kubeadm --kubeconfig /etc/kubernetes/admin.conf init phase addon kube-proxy
