# Kubernetes-in-Kubernetes

Deploy Kubernetes in Kubernetes using Helm

> Warning: This project on heavy development and not ready for production use!

## Requirements

* Kubernetes v1.15+
* Helm v3
* cert-manager v0.14+

## Quick Start

### Preparation

Install cert-manager:

```bash
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.14.3/cert-manager.yaml
```

If you running over [minikube](https://github.com/kubernetes/minikube) you also need to use provisioner, you can use [local-path-provisioner](https://github.com/rancher/local-path-provisioner) for example:

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

### Installation

```bash
kubectl create ns kubernetes
git clone https://github.com/kvaps/kubernetes-in-kubernetes
helm upgrade --install -n kubernetes foo kubernetes-in-kubernetes/deploy/helm/kubernetes
kubectl exec -n kubernetes -ti `kubectl get pod -n kubernetes -l app=foo-kubernetes-admin -o name` -- sh
```

### Cleanup

```bash
helm -n kubernetes delete foo
kubectl delete ns kubernetes
```
