#!/usr/bin/env bash
# Create a client-cert kubeconfig user (Day 21 flow automated)
#
# Usage: ./set-user.sh <username> [cluster]
# Example: ./set-user.sh monitoring-bot
#
# Creates: <user>.key, <user>.csr, csr/<user>.crt, csr/csr.yaml, kubeconfig user+context
# Does NOT create RBAC — add Role/RoleBinding or ClusterRole/Binding separately
set -euo pipefail

user="${1:-}"
cluster="${2:-kind-cka-cluster01}"

if [[ -z "$user" ]]; then
  echo "Usage: $0 <username> [cluster]"
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

echo "Generating key + CSR for $user"
openssl genrsa -out "${user}.key" 2048
openssl req -new -key "${user}.key" -out "${user}.csr" -subj "/CN=${user}"

mkdir -p csr
cat > csr/csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${user}
spec:
  request: $(base64 < "${user}.csr" | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

echo "Issuing CSR (admin context required)"
kubectl config use-context "${cluster}"
kubectl delete csr "${user}" --ignore-not-found
kubectl apply -f csr/csr.yaml
kubectl certificate approve "${user}"
kubectl get csr "${user}" -o jsonpath='{.status.certificate}' | base64 -d > "csr/${user}.crt"

echo "Verify key/cert pair"
openssl x509 -noout -modulus -in "csr/${user}.crt" | openssl md5
openssl rsa -noout -modulus -in "${user}.key" | openssl md5

kubectl config set-credentials "${user}" \
  --client-certificate="${script_dir}/csr/${user}.crt" \
  --client-key="${script_dir}/${user}.key"
kubectl config set-context "${user}" --cluster="${cluster}" --user="${user}"

echo "Done. Switch: kubectl config use-context ${user}"
echo "Remember: authentication only — add RBAC for authorization."
