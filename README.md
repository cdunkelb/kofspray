# kofspray
scripts to assist in deployment of kof

### How to use

AWS Secrets with IAM config access

```
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_SESSION_TOKEN=
```

Set other variables

```
#Set variables in env.sh
source env.sh
./run.sh
./install-region-cluster.sh
./install-child-cluster.sh
```