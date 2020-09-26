#!/bin/bash
set -eu

if [[ -z "${CAPI_AWS_ACCESS_KEY_ID}" ]] || [[ -z "${CAPI_AWS_SECRET_ACCESS_KEY}" ]]; then
  echo "No AWS vars found [CAPI_AWS_ACCESS_KEY_ID, CAPI_AWS_SECRET_ACCESS_KEY]"
  exit 1
fi

if [[ -z "${GIT_USER}" ]] || [[ -z "${GIT_REPO_NAME}" ]]; then
  echo "No GIT vars found [GIT_USER, GIT_REPO_NAME]"
  exit 1
fi

for ns in capi-system capi-kubeadm-bootstrap-system capi-kubeadm-control-plane-system capa-system mgmt-clusters; do
  kubectl create namespace $ns || true
done

# FLUX
kubectl create ns fluxcd || true
helm repo add fluxcd https://charts.fluxcd.io
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/master/deploy/crds.yaml
helm upgrade -i flux fluxcd/flux --wait \
  --namespace fluxcd \
  --set git.url=https://github.com/${GIT_USER}/${GIT_REPO_NAME}.git \
  --set git.path="flux-mgmt" \
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

# CAPI
## base64 behaves differently in macOS vs Linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # linux
  alias base64="base64 -w 0"
fi

export AWS_B64ENCODED_CREDENTIALS=$(
  cat <<EOF | base64
[default]
aws_access_key_id = ${CAPI_AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${CAPI_AWS_SECRET_ACCESS_KEY}
EOF
)

clusterctl init --infrastructure aws || true

# enable if not using flux readonly mode
# echo "<<<"
# fluxctl identity --k8s-fwd-ns fluxcd || true
# echo "<<<"
# echo "Copy above public key and paste it in your git repo's Settings > Deploy Keys > Add Deploy Key. Make sure to turn on write access."
