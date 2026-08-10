#!/usr/bin/env bash
# Capture live AWS + cluster state before teardown. Run from laptop with AWS CLI.
# Usage: bash capture-lab-aws-state.sh > lab-aws-snapshot-$(date +%Y%m%d).txt

set -euo pipefail

REGION="${AWS_REGION:-us-west-2}"
OUT="${1:-lab-aws-snapshot-$(date +%Y%m%d-%H%M).txt}"

exec > >(tee "$OUT") 2>&1

echo "=== Lab AWS snapshot $(date -u +%Y-%m-%dT%H:%M:%SZ) region=$REGION ==="
echo ""

echo "=== AWS identity ==="
aws sts get-caller-identity

echo ""
echo "=== EC2 instances (dev + obs) ==="
aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Environment,Values=dev,obs" "Name=instance-state-name,Values=running,pending,stopping,stopped" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],Env:Tags[?Key==`Environment`].Value|[0],Id:InstanceId,Private:PrivateIpAddress,Public:PublicIpAddress,SG:SecurityGroups[0].GroupId,State:State.Name}' \
  --output table

echo ""
echo "=== VPCs ==="
aws ec2 describe-vpcs --region "$REGION" \
  --filters "Name=cidr-block,Values=10.110.0.0/16,10.210.0.0/16" \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

echo ""
echo "=== VPC peering (dev↔obs) ==="
aws ec2 describe-vpc-peering-connections --region "$REGION" \
  --filters "Name=status-code,Values=active,pending-acceptance" \
  --query 'VpcPeeringConnections[].[VpcPeeringConnectionId,RequesterVpcInfo.{VpcId:VpcId,Cidr:CidrBlock},AccepterVpcInfo.{VpcId:VpcId,Cidr:CidrBlock},Status.Code]' \
  --output json

echo ""
echo "=== Route tables (peering routes) ==="
for VPC in $(aws ec2 describe-vpcs --region "$REGION" --filters "Name=cidr-block,Values=10.110.0.0/16,10.210.0.0/16" --query 'Vpcs[].VpcId' --output text); do
  echo "--- VPC $VPC ---"
  aws ec2 describe-route-tables --region "$REGION" --filters "Name=vpc-id,Values=$VPC" \
    --query 'RouteTables[].Routes[?VpcPeeringConnectionId!=null]' --output json
done

echo ""
echo "=== Security groups (dev + obs kubeadm) ==="
for SG in $(aws ec2 describe-security-groups --region "$REGION" \
  --filters "Name=group-name,Values=*kubeadm*" \
  --query 'SecurityGroups[].GroupId' --output text); do
  echo "--- $SG ---"
  aws ec2 describe-security-groups --region "$REGION" --group-ids "$SG" \
    --query 'SecurityGroups[0].{Name:GroupName,Ingress:IpPermissions}' --output json
done

echo ""
echo "=== Terraform state buckets ==="
aws s3 ls | grep -E 'cka-2026|terraform-state' || true

echo ""
echo "=== Secrets Manager (obs SSH key) ==="
aws secretsmanager list-secrets --region "$REGION" \
  --query 'SecretList[?contains(Name, `kubeadm`) || contains(Name, `obs`)].Name' --output json 2>/dev/null || true

echo ""
echo "Saved to: $OUT"
