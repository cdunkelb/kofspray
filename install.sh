#!/bin/bash
set -x

# check to see if KOF_VERSION is set, if not exit
if [ -z "$KOF_VERSION" ]; then
    echo "Error: KOF_VERSION is not set." >&2
    exit 1
fi

#check pre-requisites, need helm, kubectl
if ! [ -x "$(command -v helm)" ]; then
  echo 'Error: helm is not installed.' >&2
  exit 1
fi
if ! [ -x "$(command -v kubectl)" ]; then
    echo 'Error: kubectl is not installed.' >&2
    exit 1
fi

# check if we are connected to a cluster.
if ! kubectl version; then
    echo 'Error: Not connected to a cluster.' >&2
    exit 1
fi

# check if we are connected to a management cluster.
management_status=$(kubectl get management -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
if [ "$management_status" != "True" ]; then
    echo 'Error: Not connected to a healthy management cluster.' >&2
    exit 1
fi

# Check if there is a default storage class
if ! kubectl get storageclass | grep -i default; then
    echo 'Error: No default storage class found.' >&2
    exit 1
fi

# check if kof is already installed
if helm list -n kof | grep -q kof; then
    echo 'Error: kof is already installed.' >&2
    exit 1
fi

# Check if external-dns-aws-credentials file exists
if [ ! -f external-dns-aws-credentials ]; then
    echo 'Error: external-dns-aws-credentials file does not exist. Try running create-external-dns-user.sh' >&2
    exit 1
fi

kubectl create namespace kof
kubectl create secret generic \
  -n kof external-dns-aws-credentials \
  --from-file external-dns-aws-credentials

# install kof via helm
helm install --wait --create-namespace -n kof kof-operators \
  oci://ghcr.io/k0rdent/kof/charts/kof-operators --version $KOF_VERSION

cat >mothership-values.yaml <<EOF
kcm:
  installTemplates: true
  kof:
    clusterProfiles:
      kof-aws-dns-secrets:
        matchLabels:
          k0rdent.mirantis.com/kof-aws-dns-secrets: "true"
        secrets:
          - external-dns-aws-credentials
EOF

helm install --wait -f mothership-values.yaml -n kof kof-mothership \
  oci://ghcr.io/k0rdent/kof/charts/kof-mothership --version $KOF_VERSION

helm install --wait -n kof kof-regional \
  oci://ghcr.io/k0rdent/kof/charts/kof-regional --version $KOF_VERSION
helm install --wait -n kof kof-child \
  oci://ghcr.io/k0rdent/kof/charts/kof-child --version $KOF_VERSION