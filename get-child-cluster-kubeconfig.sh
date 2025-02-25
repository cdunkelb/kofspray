#!/bin/bash

#Check if REGIONAL_CLUSTER_NAME is set
if [ -z "$REGIONAL_CLUSTER_NAME" ]; then
    echo "REGIONAL_CLUSTER_NAME is not set. Please set it to the name of the regional cluster you want to create."
    exit 1
fi

CHILD_CLUSTER_NAME=$REGIONAL_CLUSTER_NAME-child1

kubectl get secrets -n kcm-system $CHILD_CLUSTER_NAME-kubeconfig -o jsonpath="{.data.value}" | base64 -d > $CHILD_CLUSTER_NAME-kubeconfig.yaml

echo "kubeconfig created at $CHILD_CLUSTER_NAME-kubeconfig.yaml"