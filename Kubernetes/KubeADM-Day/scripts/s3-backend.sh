#!/usr/bin/env bash
# Create S3 backends for dev/prod Terraform state (us-west-2).
set -euo pipefail

REGION="${AWS_REGION:-us-west-2}"

create_state_bucket() {
  local bucket="$1"

  if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    echo "Bucket already exists: ${bucket}"
  else
    echo "Creating bucket: ${bucket} (${REGION})"
    if [[ "${REGION}" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$bucket" --region "$REGION"
    else
      aws s3api create-bucket --bucket "$bucket" --region "$REGION" \
        --create-bucket-configuration "LocationConstraint=${REGION}"
    fi
  fi

  aws s3api put-bucket-versioning --bucket "$bucket" --region "$REGION" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption --bucket "$bucket" --region "$REGION" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
}

create_state_bucket "cka-2026-study-terraform-state-dev"
create_state_bucket "cka-2026-study-terraform-state-prod"

echo "Done."
