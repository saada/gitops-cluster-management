# Codifying Multicloud Ops: Exploring the operator pattern with GitOps

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

## Instructions

* Fork this repo and then

```sh
git clone <ssh-url-to-fork-repo>
cp .envrc.example .envrc
vi .envrc # fill in all credentials
direnv allow
```

## Shell Operator

```sh
kubectl create namespace example-monitor-pods --dry-run -o yaml > operators/shell-operator/ns.yaml
kubectl create serviceaccount monitor-pods-acc --namespace example-monitor-pods --dry-run -o yaml > operators/shell-operator/sa.yaml
kubectl create clusterrole monitor-pods --verb=get,watch,list --resource=pods --dry-run -o yaml > operators/shell-operator/cr.yaml
kubectl create clusterrolebinding monitor-pods --clusterrole=monitor-pods --serviceaccount=example-monitor-pods:monitor-pods-acc --dry-run -o yaml > operators/shell-operator/crb.yaml
```