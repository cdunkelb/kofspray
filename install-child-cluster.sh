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
    TEMPLATE=aws-standalone-cp-0-1-0
fi

CHILD_CLUSTER_NAME=$REGIONAL_CLUSTER_NAME-child1

cat >child-cluster.yaml <<EOF
apiVersion: k0rdent.mirantis.com/v1alpha1
kind: ClusterDeployment
metadata:
  name: $CHILD_CLUSTER_NAME
  namespace: kcm-system
  labels:
    kof: collector
spec:
  template: $TEMPLATE
  credential: aws-cluster-identity-cred
  config:
    clusterIdentity:
      name: aws-cluster-identity
      namespace: kcm-system
    controlPlane:
      instanceType: t3.large
    controlPlaneNumber: 1
    publicIP: false
    region: us-east-2
    worker:
      instanceType: t3.small
    workersNumber: 3
    clusterLabels:
      k0rdent.mirantis.com/kof-storage-secrets: "true"
  serviceSpec:
    priority: 100
    services:
      - name: cert-manager
        namespace: kof
        template: cert-manager-1-16-2
        values: |
          cert-manager:
            crds:
              enabled: true
      - name: kof-operators
        namespace: kof
        template: kof-operators-0-1-1
      - name: kof-collectors
        namespace: kof
        template: kof-collectors-0-1-1
        values: |
          global:
            clusterName: $CHILD_CLUSTER_NAME
          opencost:
            enabled: true
            opencost:
              prometheus:
                username_key: username
                password_key: password
                existingSecretName: storage-vmuser-credentials
                external:
                  url: https://vmauth.$REGIONAL_DOMAIN/vm/select/0/prometheus
              exporter:
                defaultClusterId: $CHILD_CLUSTER_NAME
          kof:
            logs:
              username_key: username
              password_key: password
              credentials_secret_name: storage-vmuser-credentials
              endpoint: https://vmauth.$REGIONAL_DOMAIN/vls/insert/opentelemetry/v1/logs
            metrics:
              username_key: username
              password_key: password
              credentials_secret_name: storage-vmuser-credentials
              endpoint: https://vmauth.$REGIONAL_DOMAIN/vm/insert/0/prometheus/api/v1/write
EOF