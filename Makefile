#!/bin/bash
build-operators:
	cd operators/secret-copier/ && docker build -t "saada/shell-operator:secret-copier" .
	docker push "saada/shell-operator:secret-copier"
eks:
	eksctl create cluster mahmoud-webinar
bootstrap:
	./bootstrap.sh
clean:
	clusterctl delete --all