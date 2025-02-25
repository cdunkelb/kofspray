#!/bin/bash
set -x

# check to see if KOF_VERSION is set, if not set it to 0.1.1
: ${KOF_VERSION:=0.1.1}

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

# check if kof is already installed
if helm list -n kof | grep -q kof; then
    echo 'Error: kof is already installed.' >&2
    exit 1
fi

# Check if AWS credentials are available
set_aws_credentials() {
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo 'Error: AWS credentials are not set.' >&2
    exit 1
fi

# create credentials for DNS auth
cat >external-dns-aws-credentials <<EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF

# if there is a session token add it to the credentials file
if [$AWS_SESSION_TOKEN] ; then
    echo "aws_session_token = $AWS_SESSION_TOKEN" >> external-dns-aws-credentials
fi
}

# install kof via helm
helm install --wait --create-namespace -n kof kof-operators \
  oci://ghcr.io/k0rdent/kof/charts/kof-operators --version $KOF_VERSION

cat >mothership-values.yaml <<EOF
kcm:
  installTemplates: true
EOF

helm install --wait -f mothership-values.yaml -n kof kof-mothership \
  oci://ghcr.io/k0rdent/kof/charts/kof-mothership --version $KOF_VERSION