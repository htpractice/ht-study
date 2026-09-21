#!/usr/bin/env bash
# Create isolated S3 buckets for obs-on-eks Terraform state (do not reuse KubeADM buckets).
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

WORKLOAD_BUCKET="obs-on-eks-tfstate-workload-${ACCOUNT_ID}"
OBS_BUCKET="obs-on-eks-tfstate-obs-${ACCOUNT_ID}"

create_bucket() {
  local bucket="$1"
  if aws s3api head-bucket --bucket "${bucket}" 2>/dev/null; then
    echo "Exists: ${bucket}"
    return 0
  fi
  echo "Creating: ${bucket}"
  if [[ "${AWS_REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${bucket}" --region "${AWS_REGION}"
  else
    aws s3api create-bucket --bucket "${bucket}" \
      --region "${AWS_REGION}" \
      --create-bucket-configuration "LocationConstraint=${AWS_REGION}"
  fi
  aws s3api put-bucket-versioning --bucket "${bucket}" \
    --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "${bucket}" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  aws s3api put-public-access-block --bucket "${bucket}" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
}

create_bucket "${WORKLOAD_BUCKET}"
create_bucket "${OBS_BUCKET}"

echo ""
echo "Buckets ready:"
echo "  workload: ${WORKLOAD_BUCKET}"
echo "  obs:      ${OBS_BUCKET}"
echo ""
echo "Backend config (already wired in terraform/environments/*/main.tf):"
echo "  obs:      s3://${OBS_BUCKET}/environments/eks-obs/terraform.tfstate"
echo "  workload: s3://${WORKLOAD_BUCKET}/environments/eks-workload/terraform.tfstate"
echo "  peering:  s3://${OBS_BUCKET}/environments/eks-peering/terraform.tfstate"
