#!/bin/bash
build-operators:
	cd operators/secret-copier/ && docker build -t "saada/shell-operator:secret-copier" .
	docker push "saada/shell-operator:secret-copier"
	cd operators/deployment-copier/ && docker build -t "saada/shell-operator:deployment-copier" .
	docker push "saada/shell-operator:deployment-copier"
eks:
	eksctl create cluster --version 1.16 mahmoud-webinar
bootstrap:
	./bootstrap.sh
clean:
	clusterctl delete --all