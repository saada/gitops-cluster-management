# Codifying Multicloud Ops: Exploring the operator pattern with GitOps

Estimated time: 75 mins

## Abstract

> "Kubernetes is a platform for building platforms." - Kelsey Hightower [tweet](https://twitter.com/kelseyhightower/status/935252923721793536)

But how do we build this platform? What would a platform on Kubernetes look like? And how do we deploy this platform across multiple clusters? Or multiple cloud providers?

In this talk, Mahmoud will explore how we can leverage the operator pattern to build platforms on top of Kubernetes.
We'll learn how to use operator patterns and tools such as the shell-operator to write simple operators that can help manage large deployments and complex systems. By codifying our operations, we can save a large amount of toil, standardize, and have more reliable platforms for development teams; and save some precious SRE time in the process.

* Run CAPI controllers to spin up Kubernetes clusters
* Create an operator with shell-operator that monitors deployments with a special annotation
    * if annotation exists, it runs the following
        * provision s3 bucket with custom operator
        * create s3 bucket
        * create redis cluster with helm
        * backup redis to s3 bucket with cron job
* Deploy our operator with gitops
    * Spin up kind cluster
    * Setup flux
* Deploy WKP on top to monitor the cluster
* Spin up 1 EKS cluster and 1 local cluster
    * show how both clusters are in sync with git changes and how backups are not separated by bucket name
* Tear down
    * show how s3 bucket is cleaned up
    * show how redis cluster is cleaned up

## Pre-requisites

* [Install eksctl](https://github.com/weaveworks/eksctl#installation)
* direnv
* ssh key pair name in us-east-1 region

### Maintainer pre-requisites

* clusterctl
* krew
* kubectl krew install neat

## Instructions

* Fork this repo and then

```sh
git clone <ssh-url-to-fork-repo>
cp .envrc.example .envrc
vi .envrc # fill in all credentials
direnv allow
# create eks cluster
make eks
# install flux and CAPI on management cluster
make bootstrap
```

## Automatically install things on remote cluster

```yaml
  postKubeadmCommands:
    - 'sh /tmp/addons_install.sh'
  files:
  - owner: root:root
    path: /tmp/addons_install.sh
    permissions: "0700"
    content: |
      #!/bin/bash
      apt-get install curl
      export GITHUB_TOKEN="..."
      curl --request GET --header "Authorization: token ${GITHUB_TOKEN}" --header 'Accept: application/vnd.github.v3.raw' 'https://raw.githubusercontent.com/saada/aws-webinar/master/flux-ec2/install.sh' -o install.sh
      sh install.sh
```

## Monitor cluster creation

```
kubectl get clusters -w
kubectl get machines -w
kubectl logs --tail 100 -f -n capa-system deploy/capa-controller-manager -c manager
```

## Shell Operator

```sh
kubectl create namespace example-monitor-pods --dry-run -o yaml > operators/shell-operator/ns.yaml
kubectl create serviceaccount monitor-pods-acc --namespace example-monitor-pods --dry-run -o yaml > operators/shell-operator/sa.yaml
kubectl create clusterrole monitor-pods --verb=get,watch,list --resource=pods --dry-run -o yaml > operators/shell-operator/cr.yaml
kubectl create clusterrolebinding monitor-pods --clusterrole=monitor-pods --serviceaccount=example-monitor-pods:monitor-pods-acc --dry-run -o yaml > operators/shell-operator/crb.yaml
```

## Maintainer Notes

```sh
curl -L -o examples/cni/weavenet.yaml https://cloud.weave.works/k8s/net
curl -L -o examples/cni/calico.yaml https://docs.projectcalico.org/manifests/calico.yaml

## regenerate capi manifests
clusterctl init --infrastructure aws || true
for ns in capa-system capi-system capi-kubeadm-bootstrap-system capi-kubeadm-control-plane-system
do
    kubectl get deploy,svc,role,rolebinding -n ${ns} -o yaml | kubectl neat | grep -v clusterIP > ./flux-mgmt/capi/${ns}.yaml
done

# create sample clusters
clusterctl config cluster ec2-cluster-1 --kubernetes-version v1.17.3 --control-plane-machine-count=3 --worker-machine-count=3 > examples/clusters/ec2-cluster-1.yaml
clusterctl config cluster ec2-cluster-2 --kubernetes-version v1.17.3 --control-plane-machine-count=3 --worker-machine-count=3 > examples/clusters/ec2-cluster-2.yaml

clusterctl delete --all
```