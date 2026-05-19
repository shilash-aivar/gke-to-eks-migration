#!/usr/bin/env bash
# AKS → EKS Velero POC: provision AKS, install Velero, deploy sample DBs
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT}/terraform/aks"
RG="${RG:-rg-aks-velero-poc}"
CLUSTER="${CLUSTER:-aks-velero-poc}"
VELERO_NS="${VELERO_NS:-velero}"
AWS_CREDS_FILE="${AWS_CREDS_FILE:-}"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1"; exit 1; }
}

require az
require terraform
require kubectl
require helm

echo "==> Checking Azure login"
az account show >/dev/null

echo "==> Provisioning AKS (Terraform)"
cd "${TF_DIR}"
terraform init -input=false
terraform apply -auto-approve -input=false

echo "==> Fetching kubeconfig"
az aks get-credentials \
  --resource-group "${RG}" \
  --name "${CLUSTER}" \
  --overwrite-existing

echo "==> AKS storage classes"
kubectl get storageclass

echo "==> Creating namespace ${VELERO_NS}"
kubectl create namespace "${VELERO_NS}" --dry-run=client -o yaml | kubectl apply -f -

if [[ -n "${AWS_CREDS_FILE}" && -f "${AWS_CREDS_FILE}" ]]; then
  echo "==> Creating velero-credentials from ${AWS_CREDS_FILE}"
  kubectl -n "${VELERO_NS}" create secret generic velero-credentials \
    --from-file=cloud="${AWS_CREDS_FILE}" \
    --dry-run=client -o yaml | kubectl apply -f -
  helm upgrade --install velero vmware-tanzu/velero \
    --namespace "${VELERO_NS}" \
    --create-namespace \
    -f "${ROOT}/values-aks.yaml" \
    --set credentials.useSecret=true \
    --set credentials.existingSecret=velero-credentials
else
  echo "==> Installing Velero (credentials from values-aks.yaml)"
  helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts 2>/dev/null || true
  helm repo update
  helm upgrade --install velero vmware-tanzu/velero \
    --namespace "${VELERO_NS}" \
    --create-namespace \
    -f "${ROOT}/values-aks.yaml"
fi

echo "==> Waiting for Velero"
kubectl -n "${VELERO_NS}" rollout status deploy/velero --timeout=300s
kubectl -n "${VELERO_NS}" rollout status daemonset/node-agent --timeout=300s 2>/dev/null || true

echo "==> Deploying sample databases (AKS storage class)"
kubectl apply -f "${ROOT}/databases-aks.yaml"
kubectl -n databases wait --for=condition=ready pod -l app=postgres --timeout=600s
kubectl -n databases wait --for=condition=ready pod -l app=mysql --timeout=600s

echo ""
echo "POC ready on AKS. Next steps:"
echo "  0. (optional) ${ROOT}/scripts/install-loki.sh"
echo "  1. kubectl apply -f ${ROOT}/backup.yaml"
echo "  2. velero backup describe databases-migration -n ${VELERO_NS}"
echo "  3. On EKS: ${ROOT}/scripts/setup-eks-poc.sh"
echo "  4. kubectl apply -f ${ROOT}/restore-all.yaml   # or restore.yaml for DBs only"
