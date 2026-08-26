#!/usr/bin/env bash
# Re-import SLI dashboard + library panels after lab redeploy.
# Prereq: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-cka-lab}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

auth=(-u "${GRAFANA_USER}:${GRAFANA_PASS}")

echo "Importing library panels..."
for f in "${SCRIPT_DIR}"/library-panels/*-full.json; do
  name=$(jq -r '.result.name' "$f")
  uid=$(jq -r '.result.uid' "$f")
  payload=$(jq '{
    folderUid: "",
    name: .result.name,
    uid: .result.uid,
    kind: .result.kind,
    model: .result.model
  }' "$f")
  curl -sS "${auth[@]}" -X POST \
    -H 'Content-Type: application/json' \
    "${GRAFANA_URL}/api/library-elements" \
    -d "$payload" | jq -r '"  \(.result.name // .message // .)"'
done

echo "Importing SLI dashboard..."
dashboard=$(jq '.dashboard | .id = null' "${SCRIPT_DIR}/sli-dashboard.json")
curl -sS "${auth[@]}" -X POST \
  -H 'Content-Type: application/json' \
  "${GRAFANA_URL}/api/dashboards/db" \
  -d "{\"dashboard\": ${dashboard}, \"overwrite\": true, \"message\": \"lab re-import\"}" \
  | jq -r '"Dashboard: \(.url // .message // .)"'

echo "Done. Open ${GRAFANA_URL}/d/fff8e002-a8e9-47ec-aa64-dd239b9dd874/sli-dashboard"
