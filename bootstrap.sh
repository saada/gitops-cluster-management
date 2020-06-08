#!/bin/bash
set -eu

if [[ -z "${AWS_ACCESS_KEY_ID}" ]] || [[ -z "${AWS_SECRET_ACCESS_KEY}" ]]; then
  echo "No AWS credentials found [AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY]"
  exit 1
fi

if [[ -z "${GIT_USER}" ]] || [[ -z "${GIT_DEPLOY_TOKEN}" ]] || [[ -z "${GIT_REPO_NAME}" ]]; then
  echo "No GIT credentials found [GIT_USER, GIT_DEPLOY_TOKEN]"
  exit 1
fi


export AWS_B64ENCODED_CREDENTIALS=$(cat <<EOF | base64
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
)

kubectl apply -f - <<END
apiVersion: v1
kind: Namespace
metadata:
  name: capa-system
---
apiVersion: v1
kind: Secret
metadata:
  name: capa-manager-bootstrap-credentials
  namespace: capa-system
type: Opaque
data:
  credentials: ${AWS_B64ENCODED_CREDENTIALS}
END

export AWS_CAPI_VALUES_B64=$(cat <<END | base64
bootstrap:
  secret:
    value: ${AWS_B64ENCODED_CREDENTIALS}
controlplane:
  addons:
    authkey: ${GIT_DEPLOY_TOKEN}
flux:
  authkey: ${GIT_DEPLOY_TOKEN}
  authuser: ${GIT_USER}
END
)

kubectl apply -f - <<END
apiVersion: v1
kind: Namespace
metadata:
  name: mgmt-clusters
---
apiVersion: v1
kind: Secret
metadata:
  name: aws-capi-values
  namespace: mgmt-clusters
type: Opaque
data:
  values: ${AWS_CAPI_VALUES_B64}
END

# flux
kubectl create ns fluxcd || true
helm repo add fluxcd https://charts.fluxcd.io
kubectl apply -f https://raw.githubusercontent.com/fluxcd/helm-operator/master/deploy/crds.yaml
helm upgrade -i flux fluxcd/flux --wait \
    --namespace fluxcd \
    --set git.url=https://${GIT_USER}:${GIT_DEPLOY_TOKEN}@github.com/${GIT_USER}/${GIT_REPO_NAME}.git \
    --set git.path="deploy" \
    --set git.timeout=120s \
    --set git.pollInterval=1m \
    --set rbac.create=true

## helm operator
helm upgrade helm-operator fluxcd/helm-operator \
    --force \
    -i \
    --wait \
    --namespace fluxcd \
    --set helm.versions=v3

# CAPI
clusterctl init --infrastructure aws || true

## hand over gitops management to flux
for ns in capa-system capi-system capi-kubeadm-bootstrap-system capi-kubeadm-control-plane-system
do
    kubectl get deploy,svc,role,rolebinding -n ${ns} -o yaml | kubectl neat > ./deploy/capi/${ns}.yaml
done

# create clusters
clusterctl config cluster ec2-cluster-1 --kubernetes-version v1.17.3 --control-plane-machine-count=3 --worker-machine-count=3 > deploy/clusters/ec2-cluster-1.yaml
clusterctl config cluster ec2-cluster-2 --kubernetes-version v1.17.3 --control-plane-machine-count=3 --worker-machine-count=3 > deploy/clusters/ec2-cluster-2.yaml