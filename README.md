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
* clusterctl

### Maintainer pre-requisites

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

Update your `KubeadmControlPlane` as follows

```yaml
  postKubeadmCommands:
    - 'sh /tmp/addons_install.sh'
  files:
  - owner: root:root
    path: /tmp/addons_install.sh
    permissions: "0700"
    content: |
      #!/bin/bash
      TODO: install kubectl and helm
      helm install --namespace kube-system --name sealed-secrets stable/sealed-secrets
      apt-get install curl
      TODO: export GITHUB_TOKEN=kubectl get secret from sealedsecret
      curl --request GET --header "Authorization: token ${GITHUB_TOKEN}" --header 'Accept: application/vnd.github.v3.raw' 'https://raw.githubusercontent.com/saada/gitops-cluster-management/master/flux-ec2/install.sh' | bash
```

## Monitor cluster creation

```
kubectl get clusters -w
kubectl get machines -w
kubectl logs --tail 100 -f -n capa-system deploy/capa-controller-manager -c manager
```

# Maintainers

Check out [MAINTAINERS.md](./MAINTAINERS.md)