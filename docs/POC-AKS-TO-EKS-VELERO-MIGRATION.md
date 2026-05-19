# POC: AKS → EKS Migration with Velero

**Project:** `aks-to-eks-velero-poc`  
**Repository:** `gke-to-eks` (historical name; scope is AKS source → EKS target)  
**Method:** [Velero](https://velero.io/) backups to shared S3, restore on EKS with filesystem (Kopia) volume backup  
**AWS account:** `880335327306` · **Region:** `us-east-1`

---

## 1. Executive summary

This POC validates migrating Kubernetes workloads from **Azure Kubernetes Service (AKS)** to **Amazon Elastic Kubernetes Service (EKS)** using Velero. Application data in persistent volumes is captured via **pod volume backup** (Kopia, not cloud snapshots) and restored on EKS.

**Namespaces migrated:**

| Namespace     | Workloads                                      |
|---------------|------------------------------------------------|
| `databases`   | PostgreSQL, MySQL, log-generator (sample apps) |
| `monitoring`| Loki stack, Grafana, Promtail, MinIO           |

**Backup name:** `poc-full-migration`  
**S3 bucket:** `migration-bucket-aks-eks-velero-poc`

**Clusters:**

| Role   | Name              | Notes                          |
|--------|-------------------|--------------------------------|
| Source | `aks-velero-poc`  | Velero → S3                    |
| Target | `eks-velero-poc`  | Velero reads S3, restores apps |

---

## 2. Architecture

```
┌─────────────────────┐         ┌──────────────────────────────┐
│  AKS (source)       │         │  S3 (us-east-1)              │
│  aks-velero-poc     │ backup  │  migration-bucket-aks-eks-   │
│                     ├────────►│  velero-poc                  │
│  • Velero server    │         │  • Backup metadata + Kopia   │
│  • node-agent       │         │    volume data               │
│  • databases        │         └──────────────┬───────────────┘
│  • monitoring       │                        │ restore
└─────────────────────┘                        ▼
                               ┌───────────────────────────────┐
                               │  EKS (target)                 │
                               │  eks-velero-poc               │
                               │  • Velero server + node-agent │
                               │  • EBS CSI (IRSA)             │
                               │  • gp2-encrypted StorageClass │
                               │  • Restored namespaces        │
                               └───────────────────────────────┘
```

**Velero settings (both clusters):**

- **Velero:** `v1.18.0`
- **AWS plugin:** `velero-plugin-for-aws:v1.11.0`
- **`defaultVolumesToFsBackup: true`** — pod volumes backed up with Kopia
- **`uploaderType: kopia`**
- **`deployNodeAgent: true`** — required for fs backup/restore on nodes

**What Velero restores:**

- Kubernetes objects (Deployments, StatefulSets, Services, ConfigMaps, Secrets, PVCs, etc.)
- Pod volume **data** via PodVolumeRestore (PVR) / node-agent after PVCs exist

**What Velero does *not* migrate:**

- Nodes, cloud load balancers, DNS, IAM (must be rebuilt or mapped on EKS)
- AKS-specific resources (excluded by default restore spec)

---

## 3. Repository layout

| Path | Purpose |
|------|---------|
| `terraform/aks/` | AKS cluster for source POC |
| `terraform/eks/` | EKS cluster, node group, EBS CSI addon + IRSA |
| `values-aks.yaml` | Helm values — Velero on AKS |
| `values-eks.yaml` | Helm values — Velero on EKS + storage-class mapping |
| `eks-storageclass.yaml` | `gp2-encrypted` StorageClass (CSI, encrypted) |
| `databases-aks.yaml` | Sample DB StatefulSets (`managed-csi` on AKS) |
| `backup-all.yaml` | Backup CR `poc-full-migration` + DB hooks |
| `restore-all.yaml` | Restore CR for databases + monitoring |
| `values-loki-aks.yaml` / `values-loki-eks.yaml` | Loki Helm overrides per cloud |
| `scripts/migrate-aks-to-eks.sh` | End-to-end backup (AKS) + restore (EKS) |
| `scripts/setup-aks-poc.sh` / `setup-eks-poc.sh` | Cluster bootstrap helpers |
| `scripts/seed-*.sql` | Sample data for migration verification |

---

## 4. Prerequisites

### 4.1 Tools

- `kubectl`, `helm`, `terraform`, `aws` CLI
- Optional: `velero` CLI (restore/backup can use `kubectl` on CRs)

### 4.2 AWS

- S3 bucket in **us-east-1** (same region as EKS)
- IAM user/role credentials for Velero (`aws_access_key_id` / `aws_secret_access_key` in Helm secret — **do not commit**)
- Permissions: S3 read/write on backup bucket; EBS CSI uses `AmazonEBSCSIDriverPolicy` via IRSA

### 4.3 Organization constraints (critical)

This POC hit **AWS Organizations SCPs** in account `880335327306`:

| SCP effect | Symptom | Mitigation |
|------------|---------|------------|
| Deny `ec2:AttachVolume` on **unencrypted** volumes | `FailedAttachVolume`, CSI log: `explicit deny` in SCP `p-rsh9rmaa` | Use **`gp2-encrypted`** StorageClass (`encrypted: "true"`) |
| Deny `eks:UntagResource` | Terraform plan/apply failures | Keep cluster tags in `terraform/eks/variables.tf` aligned with existing resources |
| Deny `ec2:DeleteTags` | VPC/node destroy blocked | Use existing VPC; avoid tag drift |

**Lesson:** Encryption SCP is not “CSI broken” — volumes must be **encrypted** (and optionally use an org-approved KMS key via `kmsKeyId` on the StorageClass).

### 4.4 Azure

- AKS cluster with `managed-csi` (or equivalent) for source PVCs
- Velero on AKS pointing at the **same** S3 bucket

---

## 5. Infrastructure provisioning

### 5.1 AKS (source)

```bash
cd terraform/aks
terraform init && terraform apply
az aks get-credentials --resource-group <rg> --name aks-velero-poc
# optional alias:
kubectl config rename-context <aks-context> aks-velero-poc
```

Deploy sample workloads:

```bash
kubectl apply -f databases-aks.yaml
# Loki: helm install with values-loki-aks.yaml (see scripts/setup-aks-poc.sh)
```

### 5.2 EKS (target)

```bash
cd terraform/eks
cp terraform.tfvars.example terraform.tfvars   # edit vpc_id, tags, sizes
terraform plan    # always review — SCP/tag mismatches can suggest destroys
terraform apply
```

**EKS Terraform highlights** (`terraform/eks/`):

- **Cluster:** `eks-velero-poc`, Kubernetes **1.34** (upgrade one minor version at a time)
- **Nodes:** 2× `t3.medium`, On-Demand (`use_spot_instances = false` for stable restores)
- **VPC:** Existing VPC ID (SCP limits creating/deleting tagged VPC resources)
- **EBS CSI:** `ebs-csi-addon.tf` — addon + IRSA role `AmazonEBSCSIDriverPolicy` for `kube-system:ebs-csi-controller-sa`
- **Public nodes:** `node_assign_public_ip = true` (+ `scripts/enable-subnet-public-ip.sh` if subnets lack auto public IP)

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-velero-poc --alias eks-velero-poc
kubectl apply -f eks-storageclass.yaml    # creates gp2-encrypted (default)
```

**Storage classes on EKS (important):**

| Name | Provisioner | Encrypted | Use |
|------|-------------|-----------|-----|
| `gp2` | `kubernetes.io/aws-ebs` (legacy in-tree) | No | **Avoid** — SCP blocks attach |
| `gp2-encrypted` | `ebs.csi.aws.com` | Yes | **All new PVCs / restores** |

Legacy `gp2` cannot be edited (immutable). Do not map Velero to `gp2`.

---

## 6. Velero installation

### 6.1 Helm (both clusters)

```bash
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

# AKS
kubectl config use-context aks-velero-poc
helm upgrade --install velero vmware-tanzu/velero -n velero --create-namespace \
  -f values-aks.yaml

# EKS
kubectl config use-context eks-velero-poc
helm upgrade --install velero vmware-tanzu/velero -n velero --create-namespace \
  -f values-eks.yaml --timeout 15m
```

**`values-eks.yaml` essentials:**

```yaml
configuration:
  backupStorageLocation:
    - name: default
      bucket: migration-bucket-aks-eks-velero-poc
      config:
        region: us-east-1
  defaultVolumesToFsBackup: true
  uploaderType: kopia
deployNodeAgent: true
nodeAgent:
  privileged: true   # required on EKS for Kopia volume restore into pod paths
configMaps:
  change-storage-class:
    data:
      managed-csi: gp2-encrypted
      managed: gp2-encrypted
      default: gp2-encrypted
      gp2: gp2-encrypted
```

### 6.2 Verify Velero

```bash
kubectl -n velero get pods
kubectl -n velero get backupstoragelocation default
# phase should be Available
```

**Credentials:** If BSL is `Unavailable`, fix `velero-credentials` secret (SignatureDoesNotMatch = wrong keys). Re-run Helm after updating secret contents.

---

## 7. Backup on AKS (source)

### 7.1 Optional: seed data

```bash
kubectl -n databases exec -i postgres-0 -- psql -U appuser -d appdb < scripts/seed-postgres.sql
kubectl -n databases exec -i mysql-0 -- mysql -u appuser -papppassword appdb < scripts/seed-mysql.sql
```

### 7.2 Create backup

```bash
kubectl config use-context aks-velero-poc
kubectl apply -f backup-all.yaml
kubectl -n velero get backup poc-full-migration -w
```

**Backup spec** (`backup-all.yaml`):

- Namespaces: `databases`, `monitoring`
- `defaultVolumesToFsBackup: true`
- **Hooks:** Postgres `CHECKPOINT`; MySQL `FLUSH TABLES WITH READ LOCK` / `UNLOCK TABLES`

**Success:** `status.phase: Completed`, ~106+ items (varies with monitoring resources).

```bash
kubectl -n velero describe backup poc-full-migration
```

Or use the automation script (backup only):

```bash
SKIP_RESTORE=true ./scripts/migrate-aks-to-eks.sh
```

---

## 8. Restore on EKS (target)

### 8.1 Pre-restore checklist

- [ ] EKS nodes: **2+ Ready**, **not cordoned** (`kubectl uncordon <node>`)
- [ ] `gp2-encrypted` StorageClass exists and is **default**
- [ ] EBS CSI controller + node pods **Running**
- [ ] Velero BSL **Available**
- [ ] `change-storage-class` ConfigMap maps to **`gp2-encrypted`** (not `gp2`)
- [ ] Backup `poc-full-migration` visible on EKS: `kubectl -n velero get backup`

### 8.2 Apply restore

```bash
kubectl config use-context eks-velero-poc
kubectl apply -f restore-all.yaml
```

**Restore spec** (`restore-all.yaml`):

```yaml
spec:
  backupName: poc-full-migration
  includedNamespaces: [databases, monitoring]
  restorePVs: true
```

### 8.3 Restore phases (what to expect)

1. **Kubernetes objects** — Restore `phase: InProgress`, `itemsRestored` → `totalItems` (e.g. 106/106).
2. **PodVolumeRestores** — Kopia copies data into mounted volumes; watch `kubectl -n velero get podvolumerestores`.
3. **Restore Completed** — Only when PVRs finish and no fatal errors.

```bash
kubectl -n velero get restore poc-full-migration -o yaml | grep -A20 '^status:'
kubectl -n velero get podvolumerestores
kubectl get pods -n databases -n monitoring
```

### 8.4 StatefulSets and storage class (mandatory workaround)

Velero **change-storage-class** updates **PVCs on restore**, but **StatefulSet `volumeClaimTemplates` are immutable**. If templates still reference `managed-csi` or mapped `gp2` (legacy), deleting pods recreates **unencrypted** PVCs.

**Correct approach used in POC:**

```bash
kubectl delete statefulset -n databases postgres mysql
kubectl delete pvc -n databases --all

sed 's/storageClassName: managed-csi/storageClassName: gp2-encrypted/g' \
  databases-aks.yaml | kubectl apply -f -

kubectl get pvc -n databases   # must show gp2-encrypted + Bound
kubectl apply -f restore-all.yaml   # restore volume data
```

---

## 9. Issues encountered and resolutions

### 9.1 Velero / S3

| Issue | Resolution |
|-------|------------|
| BackupStorageLocation `Unavailable` | Fix AWS credentials in `velero-credentials`; `helm upgrade` |
| Backup failed after Velero restart | Delete failed Backup CR; create new backup |
| Helm upgrade timeout on `velero-upgrade-crds` | Job pod Pending — uncordon nodes, scale to 2 nodes, `--timeout 15m` |

### 9.2 EKS scheduling / nodes

| Issue | Resolution |
|-------|------------|
| Velero server **Pending** | Uncordon node; scale node group to 2; reduce competing pods |
| Single node **SchedulingDisabled** | `kubectl uncordon <node>` |
| Insufficient memory / too many pods | Use `t3.medium`×2; scale down Loki components for POC |

### 9.3 EBS / storage (root cause of long `ContainerCreating`)

| Issue | Resolution |
|-------|------------|
| `FailedAttachVolume` + CSI `ec2:AttachVolume` **403** + SCP explicit deny | Provision **encrypted** volumes via `gp2-encrypted` |
| PVCs on legacy **`gp2`** in-tree SC | Delete PVC/STS; use `gp2-encrypted` only |
| Cannot patch StorageClass / STS volumeClaimTemplates | Create **new** SC name; **recreate** StatefulSets |
| `VolumeAttachment` `ATTACHED false` | Fixed after encrypted volumes + healthy CSI |
| PV node affinity after node replacement | Delete old PV/PVC; reprovision in correct AZ |

### 9.4 Velero volume restore

| Issue | Resolution |
|-------|------------|
| PodVolumeRestores empty STATUS / no NODE | Ensure pods scheduled; `nodeAgent.privileged: true` on EKS |
| Restore `InProgress` with 106/106 items | Normal — waiting on PVRs / volume mount |
| No `restore-wait` init container | Often mount failure before init runs — fix EBS first |
| `loki-chunks-cache-0` Pending 4h+ | Resource pressure — optional scale-down for DB-only POC |

### 9.5 Terraform / SCP

| Issue | Resolution |
|-------|------------|
| `eks:UntagResource` denied | Match `tags` in `variables.tf` to live cluster tags |
| EKS upgrade skips versions | One minor version per upgrade (`scripts/upgrade-eks-version.sh`) |
| Sync node group before control plane upgrade | `scripts/sync-nodegroups-to-cluster.sh` |

---

## 10. Verification

### 10.1 Storage and attach

```bash
kubectl get pvc -n databases
kubectl get volumeattachment
kubectl describe pod -n databases postgres-0 | sed -n '/Events:/,$p'
aws ec2 describe-volumes --region us-east-1 --volume-ids <vol-id> \
  --query 'Volumes[0].{Encrypted:Encrypted,KmsKeyId:KmsKeyId}'
```

### 10.2 Application data

```bash
kubectl -n databases exec postgres-0 -- psql -U appuser -d appdb -c \
  "SELECT count(*) FROM customers;"
kubectl -n databases exec mysql-0 -- mysql -u appuser -papppassword appdb -e \
  "SELECT count(*) FROM customers;"
```

### 10.3 Velero

```bash
kubectl -n velero get restore poc-full-migration -o jsonpath='{.status.phase}{"\n"}'
kubectl -n velero get backup poc-full-migration -o jsonpath='{.status.phase}{"\n"}'
```

### 10.4 Log generator (optional)

```bash
CLUSTER_NAME=eks-velero-poc ./scripts/deploy-log-generator.sh
```

---

## 11. End-to-end command reference

### Fresh migration (happy path)

```bash
# 1. Backup on AKS
kubectl config use-context aks-velero-poc
kubectl apply -f backup-all.yaml
kubectl -n velero wait --for=jsonpath='{.status.phase}'=Completed backup/poc-full-migration --timeout=30m

# 2. Prepare EKS
kubectl config use-context eks-velero-poc
kubectl apply -f eks-storageclass.yaml
kubectl patch storageclass gp2 -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' 2>/dev/null || true
helm upgrade velero vmware-tanzu/velero -n velero -f values-eks.yaml --timeout 15m

# 3. Deploy DBs with encrypted SC (before or coordinated with restore)
sed 's/storageClassName: managed-csi/storageClassName: gp2-encrypted/g' databases-aks.yaml | kubectl apply -f -

# 4. Restore
kubectl -n velero delete restore poc-full-migration --ignore-not-found
kubectl apply -f restore-all.yaml
kubectl -n velero get restore poc-full-migration -w

# 5. Verify
kubectl get pods,pvc -n databases
```

### Automated script

```bash
./scripts/migrate-aks-to-eks.sh
# Env: SKIP_BACKUP=true | SKIP_RESTORE=true | SEED_BEFORE_BACKUP=true
```

---

## 12. Security notes

- Rotate any AWS keys that were placed in `values-*.yaml` during POC; use external secrets or `--set` from env.
- SCP enforcement of encryption is a **security control** — keep `gp2-encrypted` in production mappings.
- Add org-approved `kmsKeyId` to `eks-storageclass.yaml` when required.

---

## 13. POC outcome and gaps

**Demonstrated:**

- Cross-cloud backup (AKS) and restore (EKS) via shared S3
- Namespace-scoped migration with application hooks
- Kopia-based pod volume migration
- Storage class transformation (AKS `managed-csi` → EKS `gp2-encrypted`)
- Operational learnings for SCP, CSI IRSA, and immutable StatefulSet storage

**Not in scope / partial:**

- Production cutover, DNS, ingress, external databases
- Full monitoring stack on small nodes (Loki resource-heavy)
- Velero CLI optional; some Helm hook failures tolerated with `kubectl` CRs
- **Final state** may require one clean restore cycle after encrypted PVCs are in place

---

## 14. Key contacts and artifacts

| Item | Value |
|------|--------|
| S3 bucket | `migration-bucket-aks-eks-velero-poc` |
| Backup/restore name | `poc-full-migration` |
| EKS cluster | `eks-velero-poc` |
| AKS cluster | `aks-velero-poc` |
| SCP (attach deny) | `p-rsh9rmaa` (org `724772073478`) |
| EBS CSI IRSA role | `eks-velero-poc-ebs-csi-*` |

---

*Document generated from POC execution May 2026. Update `kmsKeyId`, account IDs, and cluster names if re-running in another environment.*
