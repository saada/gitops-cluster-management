#!/usr/bin/env bash

source /hooks/common/functions.sh

hook::config() {
  cat <<EOF
{
  "configVersion":"v1",
  "kubernetes": [
    {
      "apiVersion": "v1",
      "kind": "Deployment",
      "executeHookOnEvent": [
        "Added",
        "Modified"
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

  echo "TRIGGER - deployment added or modified"

  for deployment in $(jq -r '.[] | .object.metadata.name' $BINDING_CONTEXT_PATH)
  do
    # loop through every namespace except 'default'
    for namespace in $(kubectl get namespace -o json |
                      jq -r '.items[] |
                        select((.metadata.name == "default" | not) and .status.phase == "Active") | .metadata.name')
    do
      # copy deployment with a necessary data
      kubectl -n default get deployment $deployment -o json | \
        jq -r ".metadata.namespace=\"${namespace}\" |
                .metadata |= with_entries(select([.key] | inside([\"name\", \"namespace\", \"labels\"])))" \
        | kubectl::replace_or_create
    done
  done
}

common::run_hook "$@"
