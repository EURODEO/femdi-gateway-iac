#!/bin/bash

# Variables
VAULT_ADDR=${VAULT_ADDR}
VAULT_TOKEN=${VAULT_TOKEN}
S3_BUCKET=${S3_BUCKET}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

# Check if VAULT_ADDR is set
if [ -z "$VAULT_ADDR" ]; then
  echo "Error: VAULT_ADDR is not set."
  exit 1
fi

# Check if VAULT_ADDR is set
if [ -z "$VAULT_TOKEN" ]; then
  echo "Error: VAULT_TOKEN is not set."
  exit 1
fi

# Check if VAULT_ADDR is set
if [ -z "$S3_BUCKET" ]; then
  echo "Error: S3_BUCKET is not set."
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

# Generate ISO 8601 compliant timestamp
# (needed to use sed as couldn't make it work with '%:z' in date command)
TIMESTAMP_ISO_8601=$(date +%Y-%m-%dT%H:%M:%S$(date +%z | sed 's/\(..\)$/:\1/'))

SNAPSHOT_NAME="snapshot-$TIMESTAMP_ISO_8601.snap"

# Take the snapshot
# https://developer.hashicorp.com/vault/tutorials/standard-procedures/sop-backup
vault operator raft snapshot save /tmp/$SNAPSHOT_NAME

# Upload to S3
aws s3 cp /tmp/$SNAPSHOT_NAME s3://${S3_BUCKET}${SNAPSHOT_NAME}

# Clean up
rm /tmp/$SNAPSHOT_NAME