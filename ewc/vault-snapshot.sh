#!/bin/bash

# Variables
VAULT_ADDR=${VAULT_ADDR:-"http://127.0.0.1:8200"}
S3_BUCKET=${S3_BUCKET:-"your-s3-bucket-name"}
SNAPSHOT_NAME="vault-snapshot-$(date +%Y-%m-%d_%H-%M-%S).snap"

# Take the snapshot
# https://developer.hashicorp.com/vault/tutorials/standard-procedures/sop-backup
vault operator raft snapshot save /tmp/$SNAPSHOT_NAME

# Upload to S3
aws s3 cp /tmp/$SNAPSHOT_NAME s3://$S3_BUCKET/$SNAPSHOT_NAME

# Clean up
rm /tmp/$SNAPSHOT_NAME