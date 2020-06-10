## Maintainer Notes

### Shell Operator

```sh
kubectl create namespace example-monitor-pods --dry-run -o yaml > operators/shell-operator/ns.yaml
kubectl create serviceaccount monitor-pods-acc --namespace example-monitor-pods --dry-run -o yaml > operators/shell-operator/sa.yaml
kubectl create clusterrole monitor-pods --verb=get,watch,list --resource=pods --dry-run -o yaml > operators/shell-operator/cr.yaml
kubectl create clusterrolebinding monitor-pods --clusterrole=monitor-pods --serviceaccount=example-monitor-pods:monitor-pods-acc --dry-run -o yaml > operators/shell-operator/crb.yaml
```

### Cluster API

```sh
curl -L -o examples/cni/weavenet.yaml https://cloud.weave.works/k8s/net
curl -L -o examples/cni/calico.yaml https://docs.projectcalico.org/manifests/calico.yaml

## regenerate capi manifests
export AWS_B64ENCODED_CREDENTIALS=$(cat <<EOF | base64
[default]
aws_access_key_id = ${CAPI_AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${CAPI_AWS_SECRET_ACCESS_KEY}
EOF
)
clusterctl init --infrastructure aws || true
for ns in capa-system capi-system capi-kubeadm-bootstrap-system capi-kubeadm-control-plane-system
do
    kubectl get deploy,svc,role,rolebinding -n ${ns} -o yaml | kubectl neat | grep -v clusterIP > ./flux-mgmt/capi/${ns}.yaml
done
kubectl get crd -o yaml | kubectl neat > ./flux-mgmt/capi/crds.yaml
kubectl get issuers -A -o yaml | kubectl neat > ./flux-mgmt/capi/cert-manager-issuers.yaml

# create sample clusters
clusterctl config cluster ec2-cluster-1 --kubernetes-version v1.17.3 --control-plane-machine-count=3 --worker-machine-count=3 > examples/clusters/ec2-cluster-1.yaml
clusterctl config cluster ec2-cluster-2 --kubernetes-version v1.17.3 --control-plane-machine-count=3 --worker-machine-count=3 > examples/clusters/ec2-cluster-2.yaml

clusterctl delete --all
```