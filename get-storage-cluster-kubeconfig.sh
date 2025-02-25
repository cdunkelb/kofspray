#!/bin/bash

#Check if REGIONAL_CLUSTER_NAME is set
if [ -z "$REGIONAL_CLUSTER_NAME" ]; then
    echo "REGIONAL_CLUSTER_NAME is not set. Please set it to the name of the regional cluster you want to create."
    exit 1
fi

kubectl get secrets -n kcm-system $REGIONAL_CLUSTER_NAME-kubeconfig -o jsonpath="{.data.value}" | base64 -d > $REGIONAL_CLUSTER_NAME-kubeconfig.yaml
