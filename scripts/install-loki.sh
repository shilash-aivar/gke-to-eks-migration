#!/usr/bin/env bash
# Install Loki + Promtail + Grafana into namespace monitoring
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="${NS:-monitoring}"
PLATFORM="${PLATFORM:-aks}"  # aks | eks
INSTALL_GRAFANA="${INSTALL_GRAFANA:-false}"

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

if [[ "${INSTALL_GRAFANA}" == "true" ]]; then
  echo "==> Installing Grafana"
  helm upgrade --install grafana grafana/grafana \
    --namespace "${NS}" \
    -f "${ROOT}/values-grafana.yaml" \
    --wait --timeout 5m
else
  echo "==> Skipping Grafana (set INSTALL_GRAFANA=true to enable UI)"
fi

echo ""
kubectl -n "${NS}" get pods
echo ""
if [[ "${INSTALL_GRAFANA}" == "true" ]]; then
  echo "Grafana: kubectl -n ${NS} port-forward svc/grafana 3000:80"
fi
echo "Query Loki via port-forward:"
echo "  kubectl -n ${NS} port-forward svc/loki-gateway 3100:80"
echo '  curl -G "http://127.0.0.1:3100/loki/api/v1/query_range" --data-urlencode '"'"'query={namespace="databases"}'"'"''
