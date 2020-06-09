#!/usr/bin/env bash
#
# Hook with a schedule binding: sync deployments with the 'deployment-copier: yes' label from the 'default' namespace to the other namespaces.
#

source /hooks/common/functions.sh

hook::config() {
  cat <<EOF
{
  "configVersion": "v1",
  "schedule": [
    {
      "allowFailure": true,
      "crontab": "* * * * *"
    }
  ]
}
EOF
}

hook::trigger() {
  echo "TRIGGER - crontab"

  # Copy deployments to the other namespaces.
  for deployment in $(kubectl -n default get deployment -l deployment-copier=yes -o name);
    do
    for namespace in $(kubectl get namespace -o json |
                        jq -r '.items[] |
                          select((.metadata.name == "default" | not) and .status.phase == "Active") | .metadata.name')
    do
      kubectl -n default get $deployment -o json | \
        jq -r ".metadata.namespace=\"${namespace}\" |
                .metadata |= with_entries(select([.key] | inside([\"name\", \"namespace\", \"labels\"])))" \
        | kubectl::replace_or_create
    done
  done

  # Delete deployments with the 'deployment-copier: yes' label in namespaces except 'default', which are not exist in the 'default' namespace.
  kubectl get deployment --all-namespaces -o json | \
    jq -r '([.items[] | select(.metadata.labels."deployment-copier" == "yes" and .metadata.namespace == "default").metadata.name]) as $deployments |
             .items[] | select(.metadata.labels."deployment-copier" == "yes" and .metadata.namespace != "default" and ([.metadata.name] | inside($deployments) | not)) |
             "\(.metadata.namespace) deployment \(.metadata.name)"' | \
    while read -r deployment
    do
      kubectl delete -n $deployment
    done
}

common::run_hook "$@"
