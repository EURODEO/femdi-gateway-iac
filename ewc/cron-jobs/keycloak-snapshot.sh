#!/bin/bash

# Source common functions
source /usr/local/bin/common-functions.sh

# Variables
POSTGRES_HOST=${POSTGRES_HOST}
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
S3_BUCKET_BASE_PATH=${S3_BUCKET_BASE_PATH}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_REGION=${AWS_REGION:-"eu-north-1"}

# Check required variables
check_var "POSTGRES_HOST" "$POSTGRES_HOST"
check_var "POSTGRES_DB" "$POSTGRES_DB"
check_var "POSTGRES_USER" "$POSTGRES_USER"
check_var "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD"
check_var "S3_BUCKET_BASE_PATH" "$S3_BUCKET_BASE_PATH"
check_var "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID"
check_var "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY"

# Generate ISO 8601 compliant timestamp
TIMESTAMP_ISO_8601=$(generate_iso_8601_timestamp)

SNAPSHOT_NAME="snapshot-$TIMESTAMP_ISO_8601.sql"

# Take the db snapshot
PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -F c -b -v -f /tmp/$SNAPSHOT_NAME

# Upload to S3
aws s3 cp /tmp/$SNAPSHOT_NAME s3://${S3_BUCKET_BASE_PATH}${SNAPSHOT_NAME} --region "${AWS_REGION}"

if [ $? -ne 0 ]; then
  echo "Error: Failed to upload snapshot to S3"
  exit 1
fi

# Clean up
rm /tmp/$SNAPSHOT_NAME
