#!/usr/bin/env bash
# EKS target cluster for AKS → EKS Velero migration POC
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT}/terraform/eks"
CLUSTER="${CLUSTER:-eks-velero-poc}"
REGION="${REGION:-us-east-1}"
VELERO_NS="${VELERO_NS:-velero}"
AWS_CREDS_FILE="${AWS_CREDS_FILE:-}"
INSTALL_LOKI="${INSTALL_LOKI:-false}"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1"; exit 1; }
}

require aws
require terraform
require kubectl
require helm

echo "==> Checking AWS credentials"
aws sts get-caller-identity >/dev/null

echo "==> Provisioning EKS (Terraform)"
cd "${TF_DIR}"
terraform init -input=false
terraform apply -auto-approve -input=false

echo "==> Configuring kubectl"
aws eks update-kubeconfig --region "${REGION}" --name "${CLUSTER}" --alias "${CLUSTER}"

echo "==> Default StorageClass (gp2)"
kubectl apply -f "${ROOT}/eks-storageclass.yaml"

echo "==> Waiting for nodes"
kubectl wait --for=condition=ready node --all --timeout=600s

echo "==> Installing Velero on EKS"
kubectl create namespace "${VELERO_NS}" --dry-run=client -o yaml | kubectl apply -f -

helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts 2>/dev/null || true
helm repo update

if [[ -n "${AWS_CREDS_FILE}" && -f "${AWS_CREDS_FILE}" ]]; then
  kubectl -n "${VELERO_NS}" create secret generic velero-credentials \
    --from-file=cloud="${AWS_CREDS_FILE}" \
    --dry-run=client -o yaml | kubectl apply -f -
  helm upgrade --install velero vmware-tanzu/velero \
    --namespace "${VELERO_NS}" \
    --create-namespace \
    -f "${ROOT}/values-eks.yaml" \
    --set credentials.useSecret=true \
    --set credentials.existingSecret=velero-credentials
else
  echo "    Set AWS keys in values-eks.yaml or export AWS_CREDS_FILE"
  helm upgrade --install velero vmware-tanzu/velero \
    --namespace "${VELERO_NS}" \
    --create-namespace \
    -f "${ROOT}/values-eks.yaml"
fi

kubectl -n "${VELERO_NS}" rollout status deploy/velero --timeout=300s
kubectl -n "${VELERO_NS}" rollout status daemonset/node-agent --timeout=300s 2>/dev/null || true

if [[ "${INSTALL_LOKI}" == "true" ]]; then
  PLATFORM=eks "${ROOT}/scripts/install-loki.sh"
fi

echo ""
echo "EKS target ready (${REGION})."
echo ""
echo "After backup on AKS:"
echo "  1. kubectl apply -f ${ROOT}/backup-all.yaml    # on AKS"
echo "  2. velero backup describe poc-full-migration -n velero"
echo ""
echo "Restore on EKS:"
echo "  kubectl config use-context ${CLUSTER}"
echo "  kubectl apply -f ${ROOT}/restore-all.yaml"
echo "  velero restore describe poc-full-migration -n velero"
echo ""
echo "Verify DB data:"
echo "  ./scripts/seed-databases.sh   # or query existing restored DBs"
echo "  CLUSTER_NAME=${CLUSTER} ./scripts/deploy-log-generator.sh"
