FROM docker.io/library/alpine:3.12

RUN apk add --no-cache openssl
ARG VERSION=v1.22.2
RUN wget "https://storage.googleapis.com/kubernetes-release/release/${VERSION}/bin/linux/amd64/kubectl" \
      -O /usr/local/bin/kubectl \
 && chmod +x /usr/local/bin/kubectl
RUN wget "https://storage.googleapis.com/kubernetes-release/release/${VERSION}/bin/linux/amd64/kubeadm" \
      -O /usr/local/bin/kubeadm \
 && chmod +x /usr/local/bin/kubeadm
