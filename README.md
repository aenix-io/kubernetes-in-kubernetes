# Kubernetes-in-Kubernetes

Deploy Kubernetes in Kubernetes using Helm

> Warning: This project on heavy development and not ready for production use!

## Requirements

* Kubernetes v1.16+
* Helm v3
* cert-manager v0.14+

## Usage

1. [Install cert-manager](https://cert-manager.io/docs/installation/kubernetes/).

2. Clone this replo.

3. Create `kubernetes` namespace

   ```
   kubectl create ns kubernetes
   ```

4. Deploy Kubernetes-in-Kubernetes:

   ```
   cd deploy/helm
   helm upgrade --install -n kubernetes foo kubernetes --wait
   ```
