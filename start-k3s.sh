#!/bin/bash -e

if [ ! -w /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established ]; then
    echo "--privileged is required to run k3s" >&2
    exit 1
fi

start-dind.sh
docker images | grep -q 'coredns/coredns' || (
    for I in $(ls /opt/k3s*.tar.gz); do docker load -i "${I}"; done
)

pgrep -f 'k3s server' >/dev/null || (
    nohup k3s server --disable-agent >/var/log/k3s-server.log 2>&1 &
)
timeout 30 sh -c "until test -f /var/lib/rancher/k3s/server/node-token >/dev/null 2>&1; do echo .; sleep 1; done"
timeout 30 sh -c "until nc -zv localhost 6443 >/dev/null 2>&1; do echo .; sleep 1; done"

pgrep -f 'k3s agent' >/dev/null || (
    nohup k3s agent --server https://localhost:6443 --token "$(</var/lib/rancher/k3s/server/node-token)" --docker >/var/log/k3s-agent.log 2>&1 &
)
timeout 30 sh -c "until k3s kubectl get node | grep -qi ready >/dev/null 2>&1; do echo .; sleep 1; done"
timeout 30 sh -c "until nc -zv localhost 80 >/dev/null 2>&1; do echo .; sleep 1; done"

k3s kubectl get storageclass local-path >/dev/null 2>&1 || (
    k3s kubectl apply -f /opt/local-path-storage.yaml
    k3s kubectl patch storageclass local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
)
echo k3s Started

k3s kubectl -n kube-system get service tiller-deploy >/dev/null 2>&1 || (
    helm init
    helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/
    k3s kubectl --namespace kube-system  get serviceaccount tiller >/dev/null 2>&1 || \
        k3s kubectl create serviceaccount --namespace kube-system tiller
    k3s kubectl get clusterrolebinding tiller-cluster-rule >/dev/null 2>&1 || \
        k3s kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    k3s kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
    echo Helm Started
)
timeout 30 sh -c "until helm version >/dev/null 2>&1; do echo .; sleep 1; done"
