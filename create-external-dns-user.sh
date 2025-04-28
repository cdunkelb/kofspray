#!/bin/bash

# check if EXTERNAL_DNS_USER is set and if not exit
if [ -z "$EXTERNAL_DNS_USER" ]; then
    echo "Error: EXTERNAL_DNS_USER is not set." >&2
    exit 1
fi

# Check to see if aws credentials are set and have IAM permissions
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then 
    echo 'Error: AWS credentials for external-dns are not set.' >&2
    exit 1
fi

# Create a policy that allows external-dns to update Route53 records
cat > policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:ListTagsForResource"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF

aws iam create-policy --policy-name "AllowExternalDNSUpdates" --policy-document file://policy.json

# example: arn:aws:iam::XXXXXXXXXXXX:policy/AllowExternalDNSUpdates
export POLICY_ARN=$(aws iam list-policies \
 --query 'Policies[?PolicyName==`AllowExternalDNSUpdates`].Arn' --output text)

 # create IAM user
aws iam create-user --user-name $EXTERNAL_DNS_USER

# attach policy arn created earlier to IAM user
aws iam attach-user-policy --user-name $EXTERNAL_DNS_USER --policy-arn $POLICY_ARN

SECRET_ACCESS_KEY=$(aws iam create-access-key --user-name $EXTERNAL_DNS_USER)
ACCESS_KEY_ID=$(echo $SECRET_ACCESS_KEY | jq -r '.AccessKey.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo $SECRET_ACCESS_KEY | jq -r '.AccessKey.SecretAccessKey')

echo "Creating credentials file for external-dns external-dns-aws-credentials"

cat > external-dns-aws-credentials << EOF
[default]
aws_access_key_id = $ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF

