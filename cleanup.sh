#!/bin/bash

./uninstall.sh
IAM_USER=$EXTERNAL_DNS_USER ./cleanup-iam-user.sh
IAM_USER=$CAPI_USER ./cleanup-iam-user.sh