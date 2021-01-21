k edit sts generic-kubernetes-etcd # update: --initial-cluster-state=existing

k exec -ti pod/generic-kubernetes-etcd-0 -- etcdctl member list -w table
k exec -ti pod/generic-kubernetes-etcd-0 -- etcdctl member remove 3d7220137a2218ca

k exec -ti pod/generic-kubernetes-etcd-0 -- etcdctl member add generic-kubernetes-etcd-2 --peer-urls=https://generic-kubernetes-etcd-2.generic-kubernetes-etcd:2380
k exec -ti pod/generic-kubernetes-etcd-0 -- etcdctl endpoint status -w table
