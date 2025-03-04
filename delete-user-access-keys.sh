# Define the IAM username

#if there is an argument set IAM_USER to that argument
if [ -n "$1" ]; then
    IAM_USER=$1
fi

if [ -z "$IAM_USER" ]; then
    echo "Error: IAM_USER is not set." >&2
    exit 1
fi

# List all access keys for the user
ACCESS_KEYS=$(aws iam list-access-keys --user-name "$IAM_USER" --query 'AccessKeyMetadata[*].AccessKeyId' --output text)

# Loop through each access key and delete it
for KEY in $ACCESS_KEYS; do
    echo "Deleting access key: $KEY for user: $IAM_USER"
    aws iam delete-access-key --user-name "$IAM_USER" --access-key-id "$KEY"
done

echo "All access keys for user $IAM_USER have been deleted."
