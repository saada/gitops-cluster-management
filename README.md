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

* Go through [pre-requisities](https://weaveworks-gitops.awsworkshop.io/20_weaveworks_prerequisites.html)
  * For the IAM Profile, use "modernization-admin"
  * Show hidden files in Cloud9 by going to `Settings > User Settings > Tree and Go Panel`, then set the Hidden File Pattern to `*.pyc, __pycache__`

* direnv

```sh
curl -sfL https://direnv.net/install.sh | bash
echo "eval '$(direnv hook bash)'" >> ~/.bashrc
source ~/.bashrc
```

* clusterctl

```sh
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.3.6/clusterctl-linux-amd64 -o clusterctl
chmod +x ./clusterctl
sudo mv ./clusterctl /usr/local/bin/clusterctl
clusterctl version
```

## Workshop


* You should see an eks cluster already provisioned under `eksctl get clusters`
* `eksctl utils write-kubeconfig --cluster EKS-G7H1LEOA`
* Ensure `aws sts get-caller-identity` shows the right IAM profile: `arn:aws:sts::440220270053:assumed-role/modernization-admin`
* Navigate to the [AWS console](https://us-west-2.console.aws.amazon.com/ec2/v2/home?region=us-west-2#KeyPairs:)
  * Add a new Key Pair named "weaveworks-workshop"
  * In Cloud9 tab, click File > Upload local files, then choose the Key Pair's pem file that was downloaded. It should have the name `weaveworks-workshop.pem`
* Add ssh key to your Github account
  * On Cloud9, run: `ssh-keygen -t rsa -b 4096` and accept defaults
  * Run `cat ~/.ssh/id_rsa.pub` and copy the output
  * Go to [Github > Settings > SSH Keys > New SSH key](https://github.com/settings/ssh/new) and paste your public key
* Go to [workshop repo](git@github.com:saada/gitops-cluster-management.git), and click on Fork
* Clone the forked repo workshop repo with `git clone git@github.com:YOURUSERNAME/gitops-cluster-management.git`
* Set up credentials
  * `cd gitops-cluster-management`, then run `cp .envrc.example .envrc`
  * Open `.envrc` and start populating
    * `CAPI_AWS_ACCESS_KEY_ID` to your workshop `AWS_ACCESS_KEY_ID`
    * `CAPI_AWS_SECRET_ACCESS_KEY` to your workshop `AWS_SECRET_ACCESS_KEY`
    * `GIT_USER` to your github username
    * `GIT_DEPLOY_TOKEN` is populated by:
      * Create ssh key with `ssh-keygen -t rsa -b 4096 -f flux_rsa`
      * Go to https://github.com/YOURUSERNAME/gitops-cluster-management/settings/keys/new and create a github deploy key using the public key with `Allow write access` permission.
    * `GIT_REPO_NAME` to the forked repo name `gitops-cluster-management`
    * `AWS_REGION` to `us-west-2`
    * `AWS_SSH_KEY_NAME` to `weaveworks-workshop` that we created earlier
    * we can leave `AWS_CONTROL_PLANE_MACHINE_TYPE` and `AWS_NODE_MACHINE_TYPE` as `t3.large`
  * Finally run `direnv allow`. Which will export these env vars whenever you're in the git repo directory.

* Bootstrap your cluster
  * run `make bootstrap`
  * Copy printed public key and paste it in your git repo's Settings > Deploy Keys > Add Deploy Key. Make sure to turn on write access. If no key shows up, try running `fluxctl identity --k8s-fwd-ns fluxcd` until it shows up.
  * `kubectl get pod` should now show pods under `flux-mgmt` directory

* Create EC2 clusters with GitOps
  * copy `examples/clusters/ec2-cluster-1.yaml` into `flux-mgmt/clusters`. Then, modify the new file's region to `us-west-2`.

* Cleanup
  * Delete the [ssh key](https://github.com/settings/keys) we added to your github
  * Delete the deploy key in https://github.com/YOURUSERNAME/gitops-cluster-management/settings/keys we added to your github


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