#!/bin/bash
set -x

# check if CAPI_DNS_USER is set and if not exit
if [ -z "$CAPI_USER" ]; then
    echo "Error: CAPI_USER is not set." >&2
    exit 1
fi

# Check is clusterawsadm is installed
if ! [ -x "$(command -v clusterawsadm)" ]; then
  echo 'Error: clusterawsadm is not installed.' >&2
  exit 1
fi

# Check if AWS CLI is installed
if ! [ -x "$(command -v aws)" ]; then
  echo 'Error: aws is not installed.' >&2
  exit 1
fi

# Check to see if aws credentials are set and have IAM permissions
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then 
    echo 'Error: AWS credentials for iam-user are not set.' >&2
    exit 1
fi

# Create Policies
clusterawsadm bootstrap iam create-cloudformation-stack --region us-east-1

# Create User
aws iam create-user --user-name $CAPI_USER

# Get Policy ARN
AWS_ARN_ID=$(aws iam get-user --user-name $CAPI_USER --query 'User.Arn' --output text | sed -E 's/.*::([0-9]+):.*/\1/')
echo $AWS_ARN_ID

# Attach Policies
aws iam attach-user-policy --user-name $CAPI_USER --policy-arn arn:aws:iam::$AWS_ARN_ID:policy/control-plane.cluster-api-provider-aws.sigs.k8s.io
aws iam attach-user-policy --user-name $CAPI_USER --policy-arn arn:aws:iam::$AWS_ARN_ID:policy/controllers-eks.cluster-api-provider-aws.sigs.k8s.io
aws iam attach-user-policy --user-name $CAPI_USER --policy-arn arn:aws:iam::$AWS_ARN_ID:policy/controllers.cluster-api-provider-aws.sigs.k8s.io

# Create Access Key

SECRET_ACCESS_KEY=$(aws iam create-access-key --user-name $CAPI_USER)
ACCESS_KEY_ID=$(echo $SECRET_ACCESS_KEY | jq -r '.AccessKey.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo $SECRET_ACCESS_KEY | jq -r '.AccessKey.SecretAccessKey')

echo "Creating credentials file for $CAPI_USER capi-aws-credentials"

cat > capi-aws-credentials << EOF
[default]
aws_access_key_id = $ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF

cat > aws-cluster-identity-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: aws-cluster-identity-secret
  namespace: kcm-system
  labels:
    k0rdent.mirantis.com/component: "kcm"
type: Opaque
stringData:
  AccessKeyID: $ACCESS_KEY_ID
  SecretAccessKey: $AWS_SECRET_ACCESS_KEY
EOF

kubectl apply -f aws-cluster-identity-secret.yaml

cat > aws-cluster-identity.yaml << EOF
apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
kind: AWSClusterStaticIdentity
metadata:
  name: aws-cluster-identity
  labels:
    k0rdent.mirantis.com/component: "kcm"
spec:
  secretRef: aws-cluster-identity-secret
  allowedNamespaces:
    selector:
      matchLabels: {}
EOF

kubectl apply -f aws-cluster-identity.yaml  -n kcm-system

cat > aws-cluster-identity-cred.yaml << EOF
apiVersion: k0rdent.mirantis.com/v1alpha1
kind: Credential
metadata:
  name: aws-cluster-identity-cred
  namespace: kcm-system
spec:
  description: "Credential Example"
  identityRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
    kind: AWSClusterStaticIdentity
    name: aws-cluster-identity
EOF
kubectl apply -f aws-cluster-identity-cred.yaml -n kcm-system

cat > aws-cluster-identity-resource-template.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-cluster-identity-resource-template
  namespace: kcm-system
  labels:
    k0rdent.mirantis.com/component: "kcm"
  annotations:
    projectsveltos.io/template: "true"
EOF

kubectl apply -f aws-cluster-identity-resource-template.yaml -n kcm-system