#!/bin/sh
set -eu

awslocal sqs create-queue --queue-name busybee-deliveries-dlq >/dev/null
dlq_arn=$(awslocal sqs get-queue-attributes --queue-url http://localhost:4566/000000000000/busybee-deliveries-dlq --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)
awslocal sqs create-queue --queue-name busybee-deliveries --attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"$dlq_arn\\\",\\\"maxReceiveCount\\\":\\\"5\\\"}\",\"VisibilityTimeout\":\"120\"}" >/dev/null
awslocal sns create-topic --name busybee-events >/dev/null
awslocal s3api head-bucket --bucket busybee-proofs 2>/dev/null || awslocal s3api create-bucket --bucket busybee-proofs --create-bucket-configuration LocationConstraint=eu-central-1 >/dev/null
awslocal dynamodb describe-table --table-name busybee-consumed-events >/dev/null 2>&1 || awslocal dynamodb create-table --table-name busybee-consumed-events --attribute-definitions AttributeName=event_id,AttributeType=S --key-schema AttributeName=event_id,KeyType=HASH --billing-mode PAY_PER_REQUEST >/dev/null
ttl_status=$(awslocal dynamodb describe-time-to-live --table-name busybee-consumed-events --query TimeToLiveDescription.TimeToLiveStatus --output text)
if [ "$ttl_status" = "DISABLED" ]; then
  awslocal dynamodb update-time-to-live --table-name busybee-consumed-events --time-to-live-specification Enabled=true,AttributeName=expires_at >/dev/null
fi
awslocal ssm put-parameter --name /busybee/dispatch/max_radius_m --type String --value 5000 --overwrite >/dev/null
