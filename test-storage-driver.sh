#!/bin/bash
if [ "$DEBUG" = true ]; then
    set -x
fi

cat >pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
    name: test-ebs-pvc
spec:
    accessModes:
        - ReadWriteOnce
    resources:
        requests:
            storage: 1Gi
EOF

kubectl apply -f pvc.yaml

kubectl get pvc test-ebs-pvc

kubectl describe pvc test-ebs-pvc

cat >pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-ebs-pod
spec:
  containers:
  - name: my-frontend
    image: busybox
    command: [ "sleep", "3600" ]
    volumeMounts:
    - mountPath: "/data"
      name: ebs-volume
  volumes:
  - name: ebs-volume
    persistentVolumeClaim:
      claimName: test-ebs-pvc
EOF

kubectl apply -f pod.yaml


kubectl exec -it test-ebs-pod -- touch /data/testfile
kubectl exec -it test-ebs-pod -- stat /data/testfile

kubectl delete -f pod.yaml
kubectl delete -f pvc.yaml