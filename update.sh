#!/bin/bash

while getopts :c:d:h option; do
  case $option in
    c)
      cflag=true
      containerToUpdate=$OPTARG
      ;;
    d)
      dflag=true
      deploymentToUpdate=$OPTARG
      ;;
    h)
      cat <<EOF
Update Script for Drupal in EKS
===============================
This script is used to manually restart the pods within a kubernetes deployment. This script was made for Drupal deployments in EKS, but it could be used for other deployments as well. What it does is it patches the deployment with a new or changed environment variable LAST_UPDATE, which will have the date and time you ran this script in ISO format.

Usage: update.sh -c [container] -d [deployment]
  -c The name of the container in the deployment you want to update.
  -d The deployment that you want to update.

EOF
      exit 0
      ;;
    ?)
      echo "Unknown flag -$OPTARG"
      exit 1
      ;;
  esac
done

if [[ -z $cflag && -z $dflag ]]; then
  echo "Both the -c and -d flags must be specified. Use update.sh -h for help."
  exit 1
fi

updateDate=$(date -Iseconds)
updatePatch=$(cat <<EOF
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "$containerToUpdate",
            "env": [
              {
                "name": "LAST_UPDATE",
                "value": "$updateDate"
              }
            ]
          }
        ]
      }
    }
  }
}
EOF
)
kubectl patch deployment $deploymentToUpdate -p "$(echo $updatePatch)"
