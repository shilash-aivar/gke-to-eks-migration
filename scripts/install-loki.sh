#!/usr/bin/env bash
# Install Loki + Promtail + Grafana into namespace monitoring
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="${NS:-monitoring}"
PLATFORM="${PLATFORM:-aks}"  # aks | eks

LOKI_VALUES=(-f "${ROOT}/values-loki.yaml")
case "${PLATFORM}" in
  aks) LOKI_VALUES+=(-f "${ROOT}/values-loki-aks.yaml") ;;
  eks) LOKI_VALUES+=(-f "${ROOT}/values-loki-eks.yaml") ;;
  *) echo "PLATFORM must be aks or eks"; exit 1 ;;
esac

helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update

kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing Loki (${PLATFORM})"
helm upgrade --install loki grafana/loki \
  --namespace "${NS}" \
  "${LOKI_VALUES[@]}" \
  --wait --timeout 10m

echo "==> Installing Promtail"
helm upgrade --install promtail grafana/promtail \
  --namespace "${NS}" \
  -f "${ROOT}/values-promtail.yaml" \
  --wait --timeout 5m

echo "==> Installing Grafana"
helm upgrade --install grafana grafana/grafana \
  --namespace "${NS}" \
  -f "${ROOT}/values-grafana.yaml" \
  --wait --timeout 5m

echo ""
kubectl -n "${NS}" get pods
echo ""
echo "Grafana (port-forward):"
echo "  kubectl -n ${NS} port-forward svc/grafana 3000:80"
echo "  open http://localhost:3000  (admin / poc-admin-change-me)"
echo ""
echo "Explore logs in Grafana → Explore → Loki"
echo "  e.g. {namespace=\"databases\"}"
