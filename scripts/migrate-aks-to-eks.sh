#!/usr/bin/env bash
# AKS → EKS Velero migration (assumes both clusters and Velero are already installed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VELERO_NS="${VELERO_NS:-velero}"

AKS_CONTEXT="${AKS_CONTEXT:-aks-velero-poc}"
EKS_CONTEXT="${EKS_CONTEXT:-eks-velero-poc}"
EKS_REGION="${EKS_REGION:-us-east-1}"
EKS_CLUSTER="${EKS_CLUSTER:-eks-velero-poc}"

# databases-migration (DBs only) or poc-full-migration (DBs + monitoring/Loki)
BACKUP_NAME="${BACKUP_NAME:-poc-full-migration}"
RESTORE_NAME="${RESTORE_NAME:-${BACKUP_NAME}}"
BACKUP_FILE="${BACKUP_FILE:-${ROOT}/backup-all.yaml}"
RESTORE_FILE="${RESTORE_FILE:-${ROOT}/restore-all.yaml}"

SKIP_BACKUP="${SKIP_BACKUP:-false}"
SKIP_RESTORE="${SKIP_RESTORE:-false}"
SEED_BEFORE_BACKUP="${SEED_BEFORE_BACKUP:-false}"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }
}

wait_velero_backup() {
  local ctx="$1" name="$2"
  echo "==> Waiting for backup ${name} on ${ctx}"
  for _ in $(seq 1 120); do
    phase="$(kubectl --context "$ctx" -n "$VELERO_NS" get backup "$name" \
      -o jsonpath='{.status.phase}' 2>/dev/null || echo "")"
    case "$phase" in
      Completed) echo "    Backup Completed"; return 0 ;;
      Failed | PartiallyFailed)
        echo "    Backup failed:" >&2
        kubectl --context "$ctx" -n "$VELERO_NS" get backup "$name" -o yaml | tail -40
        velero --kubecontext "$ctx" -n "$VELERO_NS" backup describe "$name" --details 2>/dev/null || true
        exit 1
        ;;
      "") echo "    waiting for Backup CR..." ; sleep 5 ;;
      *) echo "    phase=$phase" ; sleep 10 ;;
    esac
  done
  echo "Backup timed out" >&2
  exit 1
}

wait_velero_restore() {
  local ctx="$1" name="$2"
  echo "==> Waiting for restore ${name} on ${ctx}"
  for _ in $(seq 1 120); do
    phase="$(kubectl --context "$ctx" -n "$VELERO_NS" get restore "$name" \
      -o jsonpath='{.status.phase}' 2>/dev/null || echo "")"
    case "$phase" in
      Completed) echo "    Restore Completed"; return 0 ;;
      Failed | PartiallyFailed)
        echo "    Restore failed:" >&2
        velero --kubecontext "$ctx" -n "$VELERO_NS" restore describe "$name" --details 2>/dev/null || true
        exit 1
        ;;
      "") sleep 5 ;;
      *) echo "    phase=$phase" ; sleep 10 ;;
    esac
  done
  echo "Restore timed out" >&2
  exit 1
}

check_velero() {
  local ctx="$1"
  echo "==> Velero on ${ctx}"
  kubectl --context "$ctx" -n "$VELERO_NS" rollout status deploy/velero --timeout=120s
  kubectl --context "$ctx" -n "$VELERO_NS" get backupstoragelocation default \
    -o jsonpath='{.status.phase}{"\n"}' | grep -q Available || {
    echo "BackupStorageLocation not Available on ${ctx}" >&2
    exit 1
  }
}

require kubectl
require helm
command -v velero >/dev/null 2>&1 || echo "Tip: install velero CLI for richer describe output"

if grep -q 'REPLACE_ME' "${ROOT}/values-aks.yaml" "${ROOT}/values-eks.yaml" 2>/dev/null; then
  echo "Set AWS credentials in values-aks.yaml / values-eks.yaml or use AWS_CREDS_FILE when installing Velero." >&2
  exit 1
fi

# --- AKS: backup ---
if [[ "$SKIP_BACKUP" != "true" ]]; then
  check_velero "$AKS_CONTEXT"

  if [[ "$SEED_BEFORE_BACKUP" == "true" ]]; then
    echo "==> Seeding databases on AKS"
    kubectl --context "$AKS_CONTEXT" get ns databases >/dev/null 2>&1 || kubectl --context "$AKS_CONTEXT" apply -f "${ROOT}/databases-aks.yaml"
    kubectl --context "$AKS_CONTEXT" -n databases wait --for=condition=ready pod -l app=postgres --timeout=600s
    kubectl --context "$AKS_CONTEXT" -n databases wait --for=condition=ready pod -l app=mysql --timeout=600s
    kubectl --context "$AKS_CONTEXT" -n databases exec -i postgres-0 -- psql -U appuser -d appdb < "${ROOT}/scripts/seed-postgres.sql"
    kubectl --context "$AKS_CONTEXT" -n databases exec -i mysql-0 -- mysql -u appuser -papppassword appdb < "${ROOT}/scripts/seed-mysql.sql"
  fi

  echo "==> Creating backup ${BACKUP_NAME} on AKS"
  if grep -q "name: ${BACKUP_NAME}" "$BACKUP_FILE"; then
    kubectl --context "$AKS_CONTEXT" apply -f "$BACKUP_FILE"
  else
    sed -E "s/name: (poc-full-migration|databases-migration)/name: ${BACKUP_NAME}/" "$BACKUP_FILE" | \
      kubectl --context "$AKS_CONTEXT" apply -f -
  fi

  wait_velero_backup "$AKS_CONTEXT" "$BACKUP_NAME"
  velero --kubecontext "$AKS_CONTEXT" -n "$VELERO_NS" backup describe "$BACKUP_NAME" 2>/dev/null || \
    kubectl --context "$AKS_CONTEXT" -n "$VELERO_NS" describe backup "$BACKUP_NAME"
else
  echo "==> SKIP_BACKUP=true — using existing backup ${BACKUP_NAME} in S3"
fi

# --- EKS: restore ---
if [[ "$SKIP_RESTORE" != "true" ]]; then
  aws eks update-kubeconfig --region "$EKS_REGION" --name "$EKS_CLUSTER" --alias "$EKS_CONTEXT" 2>/dev/null || true
  check_velero "$EKS_CONTEXT"

  echo "==> StorageClass gp2 on EKS"
  kubectl --context "$EKS_CONTEXT" apply -f "${ROOT}/eks-storageclass.yaml"

  if kubectl --context "$EKS_CONTEXT" -n "$VELERO_NS" get restore "$RESTORE_NAME" >/dev/null 2>&1; then
    echo "Restore ${RESTORE_NAME} already exists — delete it to re-run:" >&2
    echo "  kubectl --context ${EKS_CONTEXT} -n velero delete restore ${RESTORE_NAME}" >&2
    exit 1
  fi

  echo "==> Restore ${RESTORE_NAME} on EKS from backup ${BACKUP_NAME}"
  if grep -q "name: ${RESTORE_NAME}" "$RESTORE_FILE" && grep -q "backupName: ${BACKUP_NAME}" "$RESTORE_FILE"; then
    kubectl --context "$EKS_CONTEXT" apply -f "$RESTORE_FILE"
  else
    sed -E \
      -e "s/name: (poc-full-migration|databases-migration)/name: ${RESTORE_NAME}/" \
      -e "s/backupName: (poc-full-migration|databases-migration)/backupName: ${BACKUP_NAME}/" \
      "$RESTORE_FILE" | kubectl --context "$EKS_CONTEXT" apply -f -
  fi

  wait_velero_restore "$EKS_CONTEXT" "$RESTORE_NAME"

  echo "==> Waiting for database pods"
  kubectl --context "$EKS_CONTEXT" -n databases wait --for=condition=ready pod -l app=postgres --timeout=600s || true
  kubectl --context "$EKS_CONTEXT" -n databases wait --for=condition=ready pod -l app=mysql --timeout=600s || true

  echo ""
  echo "==> Verify data (EKS)"
  kubectl --context "$EKS_CONTEXT" -n databases exec postgres-0 -- psql -U appuser -d appdb -c \
    "SELECT count(*) AS customers FROM customers;" 2>/dev/null || echo "(postgres not ready yet)"
  kubectl --context "$EKS_CONTEXT" -n databases exec mysql-0 -- mysql -u appuser -papppassword appdb -e \
    "SELECT count(*) AS customers FROM customers;" 2>/dev/null || echo "(mysql not ready yet)"

  echo ""
  echo "Migration finished."
  echo "  velero --kubecontext ${EKS_CONTEXT} restore describe ${RESTORE_NAME} --details"
  echo "  CLUSTER_NAME=${EKS_CLUSTER} ./scripts/deploy-log-generator.sh"
else
  echo "SKIP_RESTORE=true — backup only."
fi
