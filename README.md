# kofspray
scripts to assist in deployment of kof

### How to use

Set the following variables

AWS Secrets with IAM config access

```
username=<username>
export EXTERNAL_DNS_USER=$username-externaldns
export CAPI_USER=$username-capi
export KOF_VERSION=0.3.0
export CLEANUP=false
```

`./run.sh`