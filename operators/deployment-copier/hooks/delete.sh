#!/usr/bin/env bash

source /hooks/common/functions.sh

hook::config() {
  cat <<EOF
{
  "configVersion": "v1",
  "kubernetes": [
    {
      "apiVersion": "apps/v1",
      "kind": "Deployment",
      "executeHookOnEvent": [
        "Deleted"
      ],
      "labelSelector": {
        "matchLabels": {
           "deployment-copier": "yes"
        }
      },
      "namespace": {
        "nameSelector": {
          "matchNames": [
            "default"
          ]
        }
      }
    }
  ]
}
EOF
}

hook::trigger() {
  # ignore Synchronization for simplicity
  type=$(jq -r '.[0].type' $BINDING_CONTEXT_PATH)
  if [[ $type == "Synchronization" ]] ; then
    echo Got Synchronization event
    exit 0
  fi

  echo "TRIGGER - deployment deleted"

  for deployment in $(jq -r '.[] | .object.metadata.name' $BINDING_CONTEXT_PATH)
    do
      for namespace in $(kubectl get namespace -o json |
                          jq -r '.items[] |
                            select((.metadata.name == "default" | not) and .status.phase == "Active") | .metadata.name')
      do
        kubectl -n $namespace delete deployment $deployment
      done
    done
}

common::run_hook "$@"
