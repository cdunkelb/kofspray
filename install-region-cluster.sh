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

cat >regional-cluster.yaml <<EOF
apiVersion: k0rdent.mirantis.com/v1alpha1
kind: ClusterDeployment
metadata:
  name: $REGIONAL_CLUSTER_NAME
  namespace: kcm-system
  labels:
    kof: storage
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
    publicIP: true
    region: us-east-2
    worker:
      instanceType: t3.medium
    workersNumber: 3
    clusterLabels:
      k0rdent.mirantis.com/kof-storage-secrets: "true"
      k0rdent.mirantis.com/kof-aws-dns-secrets: "true"
  serviceSpec:
    priority: 100
    services:
      - name: ingress-nginx
        namespace: ingress-nginx
        template: ingress-nginx-4-11-3
      - name: cert-manager
        namespace: cert-manager
        template: cert-manager-1-16-2
        values: |
          cert-manager:
            crds:
              enabled: true
      - name: kof-storage
        namespace: kof
        template: kof-storage-0-1-1
        values: |
          external-dns:
            enabled: true
          victoriametrics:
            vmauth:
              ingress:
                host: vmauth.$REGIONAL_DOMAIN
            security:
              username_key: username
              password_key: password
              credentials_secret_name: storage-vmuser-credentials
          grafana:
            ingress:
              host: grafana.$REGIONAL_DOMAIN
            security:
              credentials_secret_name: grafana-admin-credentials
          cert-manager:
            email: $ADMIN_EMAIL
---
apiVersion: kof.k0rdent.mirantis.com/v1alpha1
kind: PromxyServerGroup
metadata:
  labels:
    app.kubernetes.io/name: promxy-operator
    k0rdent.mirantis.com/promxy-secret-name: kof-mothership-promxy-config
  name: $REGIONAL_CLUSTER_NAME-metrics
  namespace: kof
spec:
  cluster_name: $REGIONAL_CLUSTER_NAME
  targets:
    - "vmauth.$REGIONAL_DOMAIN:443"
  path_prefix: /vm/select/0/prometheus/
  scheme: https
  http_client:
    dial_timeout: "5s"
    tls_config:
      insecure_skip_verify: true
    basic_auth:
      credentials_secret_name: storage-vmuser-credentials
      username_key: username
      password_key: password
---
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  labels:
    app.kubernetes.io/managed-by: Helm
  name: $REGIONAL_CLUSTER_NAME-logs
  namespace: kof
spec:
  valuesFrom:
    - targetPath: "basicAuthUser"
      valueFrom:
        secretKeyRef:
          key: username
          name: storage-vmuser-credentials
    - targetPath: "secureJsonData.basicAuthPassword"
      valueFrom:
        secretKeyRef:
          key: password
          name: storage-vmuser-credentials
  datasource:
    name: $REGIONAL_CLUSTER_NAME
    url: https://vmauth.$REGIONAL_DOMAIN/vls
    access: proxy
    isDefault: false
    type: "victoriametrics-logs-datasource"
    basicAuth: true
    basicAuthUser: \${username}
    secureJsonData:
      basicAuthPassword: \${password}
  instanceSelector:
    matchLabels:
      dashboards: grafana
  resyncPeriod: 5m
EOF

kubectl apply -f regional-cluster.yaml