# Kubernetes-in-Kubernetes

Deploy Kubernetes in Kubernetes using Helm

![demo](https://gist.githubusercontent.com/kvaps/3cc5d772d750f8f2d36a76d00c3342b1/raw/8d127a5efe738d82c18bfc70a0c460299cf404b5/kubernetes-in-kubernetes.gif)

## Requirements

* Kubernetes v1.15+
* Helm v3
* cert-manager v0.14+

## Quick Start

### Preparation

* Install [cert-manager].

* If you running over [minikube] you might also need to install a provisioner, you can use [local-path-provisioner] for example.

* Clone repo locally and cd to helm charts directory:
  ```bash
  git clone https://github.com/kvaps/kubernetes-in-kubernetes
  cd kubernetes-in-kubernetes/deploy/helm
  ```

[cert-manager]: https://cert-manager.io/docs/installation
[minikube]: https://github.com/kubernetes/minikube
[local-path-provisioner]: https://github.com/rancher/local-path-provisioner#installation

### Installation

```bash
kubectl create ns kubernetes
helm upgrade --install -n kubernetes foo kubernetes --wait
```

### Cleanup

```bash
helm -n kubernetes delete foo
kubectl delete ns kubernetes
```
