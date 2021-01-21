# Kubernetes-in-Kubernetes

Deploy Kubernetes in Kubernetes using Helm

![demo](https://gist.githubusercontent.com/kvaps/3cc5d772d750f8f2d36a76d00c3342b1/raw/8596ae812e83d186d0d57d448159b05f84cb0d53/kubernetes-in-kubernetes.gif)

## Requirements

* Kubernetes v1.15+
* Helm v3
* cert-manager v1.0.0+

## Quick Start

### Preparation

* Install [cert-manager].

* If you running over [minikube] you might also need to install a provisioner, you can use [local-path-provisioner] for example.

[cert-manager]: https://cert-manager.io/docs/installation
[minikube]: https://github.com/kubernetes/minikube
[local-path-provisioner]: https://github.com/rancher/local-path-provisioner#installation

### Installation

```bash
helm repo add kvaps https://kvaps.github.io/charts
helm install foo kvaps/kubernetes --version 0.9.0 \
  --namespace foo \
  --create-namespace \
  --set persistence.storageClassName=local-path
```

### Cleanup

```bash
kubectl delete namespace foo
```

## Usage

Kubernetes-in-Kubernetes is just a control plane, in most cases it's useless without workers.  
If you're looking for a real use case, check out the following projects that implement worker nodes management:

* **[Kubefarm]** - Automated Kubernetes deployment and the PXE-bootable servers farm

[kubefarm]: https://github.com/kvaps/kubefarm
