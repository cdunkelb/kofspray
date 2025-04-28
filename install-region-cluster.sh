#!/bin/bash

# Set your KOF variables using your own values:

# Check if EXTERNAL_DOMAIN is set
if [ -z "$EXTERNAL_DOMAIN" ]; then
    echo "EXTERNAL_DOMAIN is not set. Please set it to the domain you want to use for your KOF installation."
    exit 1
fi

#Check if REGIONAL_CLUSTER_NAME is set
if [ -z "$REGIONAL_CLUSTER_NAME" ]; then
    echo "REGIONAL_CLUSTER_NAME is not set. Please set it to the name of the regional cluster you want to create."
    exit 1
fi

REGIONAL_DOMAIN=$REGIONAL_CLUSTER_NAME.$EXTERNAL_DOMAIN

# check if ADMIN_EMAIL is set
if [ -z "$ADMIN_EMAIL" ]; then
    echo "ADMIN_EMAIL is not set. Please set it to the email address you want to use for your Grafana admin user."
    exit 1
fi

echo "$REGIONAL_CLUSTER_NAME, $REGIONAL_DOMAIN, $ADMIN_EMAIL"

# check if TEMPLATE is set and if not, set the default
if [ -z "$TEMPLATE" ]; then
    echo "TEMPLATE is not set. exiting."
    exit 1
fi

cat >regional-cluster.yaml <<EOF
apiVersion: k0rdent.mirantis.com/v1alpha1
kind: ClusterDeployment
metadata:
  name: $REGIONAL_CLUSTER_NAME
  namespace: kcm-system
  labels:
    k0rdent.mirantis.com/kof-storage-secrets: "true"
    k0rdent.mirantis.com/kof-aws-dns-secrets: "true"
    k0rdent.mirantis.com/kof-cluster-role: regional
spec:
  template: $TEMPLATE
  credential: aws-cluster-identity-cred
  config:
    clusterAnnotations:
      k0rdent.mirantis.com/kof-regional-domain: $REGIONAL_DOMAIN
      k0rdent.mirantis.com/kof-cert-email: $ADMIN_EMAIL
    clusterIdentity:
      name: aws-cluster-identity
      namespace: kcm-system
    controlPlane:
      instanceType: t3.large
    controlPlaneNumber: 1
    publicIP: false
    region: us-east-2
    worker:
      instanceType: t3.medium
    workersNumber: 3
EOF

kubectl apply -f regional-cluster.yaml