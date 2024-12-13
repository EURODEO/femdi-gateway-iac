#!/bin/bash

# Source common functions
source /usr/local/bin/common-functions.sh

# Variables
VAULT_ADDR=${VAULT_ADDR}
S3_BUCKET_BASE_PATH=${S3_BUCKET_BASE_PATH}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_REGION=${AWS_REGION:-"eu-north-1"}

# Check required variables
check_var "VAULT_ADDR" "$VAULT_ADDR"
check_var "S3_BUCKET_BASE_PATH" "$S3_BUCKET_BASE_PATH"
check_var "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID"
check_var "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY"

# Retrieve the provided service account token
SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Authenticate with Vault using the Kubernetes auth method to obtain a Vault token
export VAULT_TOKEN=$(vault write -field=token auth/kubernetes/login \
  role=backup-cron-job \
  jwt=$SA_TOKEN)

# Generate ISO 8601 compliant timestamp
TIMESTAMP_ISO_8601=$(generate_iso_8601_timestamp)

SNAPSHOT_NAME="snapshot-$TIMESTAMP_ISO_8601.snap"

# Take the snapshot
# https://developer.hashicorp.com/vault/tutorials/standard-procedures/sop-backup
vault operator raft snapshot save /tmp/$SNAPSHOT_NAME

# Upload to S3
aws s3 cp /tmp/$SNAPSHOT_NAME s3://${S3_BUCKET_BASE_PATH}${SNAPSHOT_NAME} --region "${AWS_REGION}"

if [ $? -ne 0 ]; then
  echo "Error: Failed to upload snapshot to S3"
  exit 1
fi

# Clean up
rm /tmp/$SNAPSHOT_NAME
