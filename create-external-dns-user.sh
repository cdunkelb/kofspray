# Check to see if aws credentials are set and have IAM permissions
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then 
    echo 'Error: AWS credentials for external-dns are not set.' >&2
    exit 1
fi

# Create a policy that allows external-dns to update Route53 records
cat >policy.json <<EOF
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
aws iam create-user --user-name "externaldns"

# attach policy arn created earlier to IAM user
aws iam attach-user-policy --user-name "externaldns" --policy-arn $POLICY_ARN

SECRET_ACCESS_KEY=$(aws iam create-access-key --user-name "externaldns")
ACCESS_KEY_ID=$(echo $SECRET_ACCESS_KEY | jq -r '.AccessKey.AccessKeyId')

cat <<-EOF > external-dns-aws-credentials.txt

[default]
aws_access_key_id = $(echo $ACCESS_KEY_ID)
aws_secret_access_key = $(echo $SECRET_ACCESS_KEY | jq -r '.AccessKey.SecretAccessKey')
EOF

