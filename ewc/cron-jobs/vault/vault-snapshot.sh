#!/bin/bash

# Variables
VAULT_ADDR=${VAULT_ADDR}
S3_BUCKET_BASE_PATH=${S3_BUCKET_BASE_PATH}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_REGION=${AWS_REGION:-"eu-north-1"}

# Check if VAULT_ADDR is set
if [ -z "$VAULT_ADDR" ]; then
  echo "Error: VAULT_ADDR is not set."
  exit 1
fi

# Check if VAULT_ADDR is set
if [ -z "$S3_BUCKET_BASE_PATH" ]; then
  echo "Error: S3_BUCKET_BASE_PATH is not set."
  exit 1
fi

# Check if AWS_ACCESS_KEY_ID is set
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "Error: AWS_ACCESS_KEY_ID is not set."
  exit 1
fi

# Check if AWS_SECRET_ACCESS_KEY is set
if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "Error: AWS_SECRET_ACCESS_KEY is not set."
  exit 1
fi

# Retrieve the provided service account token
SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# Authenticate with Vault using the Kubernetes auth method to obtain a Vault token
export VAULT_TOKEN=$(vault write -field=token auth/kubernetes/login \
  role=backup-cron-job \
  jwt=$SA_TOKEN)

# Generate ISO 8601 compliant timestamp
# Check the current timezone offset
TIMEZONE_OFFSET=$(date +%z)

# Generate ISO 8601 compliant timestamp
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
TIMEZONE_OFFSET=$(date +%z)

if [ "$TIMEZONE_OFFSET" == "+0000" ]; then
  TIMESTAMP_ISO_8601="${TIMESTAMP}Z"
else
  # (need to use sed as couldn't make it work with '%:z' in date command)
  TIMESTAMP_ISO_8601="${TIMESTAMP}$(echo $TIMEZONE_OFFSET | sed 's/\(..\)$/:\1/')"
fi

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