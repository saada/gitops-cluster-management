#!/bin/bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl install -f https://raw.githubusercontent.com/saada/gitops-cluster-management/master/examples/cni/weavenet.yaml
echo "Waiting for cni"
sleep 1m

# install helm
curl -L https://get.helm.sh/helm-v3.1.2-linux-amd64.tar.gz -o helm.tar.gz
tar xvfz helm.tar.gz linux-amd64/helm
chmod +x ./linux-amd64/helm
sudo mv ./linux-amd64/helm /usr/local/bin
rm -rf ./linux-amd64
rm helm.tar.gz

# FLUX
kubectl create ns fluxcd || true
helm repo add fluxcd https://charts.fluxcd.io
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/master/deploy/crds.yaml
helm upgrade -i flux fluxcd/flux --wait \
  --namespace fluxcd \
  --set git.url=https://github.com/${GIT_USER}/${GIT_REPO_NAME}.git \
  --set git.path="flux-ec2" \
  --set git.timeout=120s \
  --set git.readonly=true \
  --set git.pollInterval=1m \
  --set sync.interval=1m \
  --set sync.state=secret \
  --set syncGarbageCollection.enabled=true \
  --set rbac.create=true

# Helm Operator
helm upgrade helm-operator fluxcd/helm-operator \
  --force \
  -i \
  --wait \
  --namespace fluxcd \
  --set helm.versions=v3
