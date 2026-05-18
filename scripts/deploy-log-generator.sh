#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="${NS:-databases}"
CLUSTER_NAME="${CLUSTER_NAME:-aks-velero-poc}"

kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "${NS}" create configmap log-generator-script \
  --from-file=log-generator.py="${ROOT}/scripts/log-generator.py" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "${ROOT}/log-generator.yaml"

kubectl -n "${NS}" set env deployment/log-generator CLUSTER_NAME="${CLUSTER_NAME}" --containers=log-generator

kubectl -n "${NS}" rollout status deployment/log-generator --timeout=120s

echo ""
echo "Log generator running. Tail logs:"
echo "  kubectl -n ${NS} logs -f deploy/log-generator"
echo ""
echo "Grafana / Loki queries:"
echo '  {namespace="databases", app="log-generator"}'
echo '  {namespace="databases"} |= "MIGRATION_POC"'
echo ""
echo "Local test (no cluster):"
echo "  python3 ${ROOT}/scripts/log-generator.py"
