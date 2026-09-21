#!/usr/bin/env bash
# Deprecated — use role-specific scripts:
#   sudo bash prep-node-master.sh     # control plane (init + Flannel)
#   sudo -E bash prep-node-worker.sh  # workers (requires JOIN_CMD)
#
# This wrapper runs common prep (steps 1–5) only.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=prep-node-common.sh
source "${SCRIPT_DIR}/prep-node-common.sh"

echo ""
echo "Common prep done. Next:"
echo "  Master:  sudo bash prep-node-master.sh"
echo "  Worker:  export JOIN_CMD='kubeadm join ...' && sudo -E bash prep-node-worker.sh"
