#!/bin/bash
all: eks bootstrap
# build:
# 	kind create cluster || true
# 	helm upgrade -i flux fluxcd/flux --wait --namespace flux --set git.url=git@github.com:yourname/my-eks-config.git --set git.pollInterval=1m
# 	cd operators/pods-hook/ && docker build -t "saada/shell-operator:pods-hook" .
# 	docker push "saada/shell-operator:pods-hook"
 	# kind load docker-image "saada/shell-operator:pods-hook"
eks:
	eksctl create cluster mahmoud-webinar
bootstrap:
	./bootstrap.sh
clean:
	clusterctl delete --all