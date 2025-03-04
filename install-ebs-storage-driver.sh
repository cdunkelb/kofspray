#!/bin/bash
#if DEBUG is true
if [ "$DEBUG" = true ]; then
    set -x
fi

# Check if we are connected to a kube cluster on aws.
if ! kubectl get nodes; then
    echo 'Error: Not connected to a cluster.' >&2
    exit 1
fi

helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update

helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
    --namespace kube-system \
    --set image.repository=amazon/aws-ebs-csi-driver \
    --set controller.serviceAccount.create=true \
    --set node.serviceAccount.create=true

cat >storageclass.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp2
  fsType: ext4
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF

kubectl apply -f storageclass.yaml