#!/bin/bash
set -x

#delete all cluster deployments
kubectl delete cld --all --wait -A

helm uninstall --wait --cascade foreground -n kof kof-mothership
helm uninstall --wait --cascade foreground -n kof kof-operators
kubectl delete namespace kof --wait --cascade=foreground