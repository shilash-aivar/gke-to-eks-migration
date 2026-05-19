# AKS → EKS Migration POC

Proof-of-concept for migrating stateful workloads (MySQL, Postgres) from Azure Kubernetes Service (AKS) to Amazon EKS using Velero with cross-cloud backup/restore via AWS S3.

## Architecture

```
AKS (source)                           AWS S3                    EKS (destination)
  └─ databases namespace               (Velero bucket)             └─ databases namespace
       ├─ MySQL 8.4                         │                            ├─ MySQL 8.4  (restored)
       └─ Postgres 17                       │                            └─ Postgres 17 (restored)
  └─ Velero ──────────────────────────── backups ──────────────── Velero (IRSA)
       └─ static AWS credentials                                    └─ no static credentials
```

- AKS Velero authenticates to S3 with static AWS credentials stored in a Kubernetes secret
- EKS Velero authenticates via IRSA (IAM Roles for Service Accounts) — no stored credentials
- Storage class is remapped automatically: `managed-csi` (AKS) → `gp2` (EKS)
- Volume data is backed up using Velero file system backup (kopia uploader)

## Repository Layout

```
.
├── infrastructure/
│   ├── environments/
│   │   ├── aws/
│   │   │   ├── dev.tfvars
│   │   │   └── prod.tfvars
│   │   └── azure/
│   │       ├── dev.tfvars
│   │       └── prod.tfvars
│   └── terraform/
│       ├── aws/
│       │   ├── bootstrap/        # S3 bucket for Terraform state
│       │   ├── vpc/              # VPC, subnets, NAT gateway
│       │   ├── s3/               # Velero backup bucket
│       │   ├── eks/              # EKS cluster, node group, addons
│       │   ├── bootstrap-iam/    # IRSA roles (Velero + EBS CSI)
│       │   └── helm-velero/      # Velero Helm release on EKS
│       └── azure/
│           ├── bootstrap/        # Storage account for Terraform state
│           ├── vnet/             # VNet + AKS subnet
│           ├── storage/          # Azure Blob container
│           ├── aks/              # AKS cluster + node pools
│           ├── bootstrap-iam/    # Workload identity for Velero
│           └── helm-velero/      # Velero Helm release on AKS
├── manifests/
│   ├── databases-aks.yaml        # MySQL + Postgres StatefulSets for AKS
│   └── databases-eks.yaml        # MySQL + Postgres StatefulSets for EKS (gp2 storage)
├── velero/
│   ├── backup.yaml               # Backup + Schedule definitions
│   └── restore.yaml              # Restore definition
├── data-generator/
│   ├── generate.py               # Seed fake customers + orders
│   ├── count.py                  # Count rows per cluster
│   ├── verify.py                 # Compare AKS vs EKS — PASS/FAIL
│   └── pyproject.toml
└── Taskfile.yaml
```

## Prerequisites

| Tool | Purpose |
|------|---------|
| `terraform >= 1.10` | Provision infrastructure |
| `task` | Run Taskfile commands |
| `kubectl` | Interact with clusters |
| `helm` | Install Velero |
| `velero` CLI | Inspect backups/restores |
| `az` | Azure CLI |
| `aws` | AWS CLI |
| `uv` | Python package manager (data generator) |

AWS credentials must be configured (`aws configure`) and Azure CLI logged in (`az login`).

## Cluster Contexts

Tasks detect contexts automatically from `kubectl config`. The detection logic:

- **AKS**: first context whose name does **not** contain `arn:aws:eks`
- **EKS**: first context whose name **contains** `arn:aws:eks`

Update kubeconfig:

```bash
az aks get-credentials --name aivar-aks-dev --resource-group aivar-aks-rg-dev
aws eks update-kubeconfig --name aivar-eks-dev --region us-east-1
```

## Infrastructure Provisioning

### Step 1 — AWS

```bash
task aws:init-all
task bootstrap:apply        # creates S3 state bucket first
task vpc:apply
task s3:apply
task eks:apply
```

After `vpc:apply`, copy the outputs into `infrastructure/environments/aws/dev.tfvars`:

```bash
terraform -chdir=infrastructure/terraform/aws/vpc output -json
# set vpc_id and private_subnet_ids
```

```bash
task bootstrap-iam:apply    # creates Velero IRSA + EBS CSI IRSA roles
```

After `bootstrap-iam:apply`, add the EBS CSI role ARN to `dev.tfvars`:

```bash
terraform -chdir=infrastructure/terraform/aws/bootstrap-iam output ebs_csi_role_arn
# set ebs_csi_role_arn in dev.tfvars
```

```bash
task eks:apply              # installs EKS addons (vpc-cni, coredns, kube-proxy, ebs-csi-driver)
task helm-velero:apply      # installs Velero on EKS via Helm
```

Or apply everything at once after the manual tfvars steps:

```bash
task aws:apply-all
```

### Step 2 — Azure

Export AWS credentials for Velero's S3 backend before applying:

```bash
export TF_VAR_aws_access_key_id="$(aws configure get aws_access_key_id)"
export TF_VAR_aws_secret_access_key="$(aws configure get aws_secret_access_key)"
```

```bash
task az:init-all
task az:bootstrap:apply
task az:vnet:apply
task az:storage:apply
task az:aks:apply
```

After `vnet:apply`, copy the subnet ID into `infrastructure/environments/azure/dev.tfvars`:

```bash
terraform -chdir=infrastructure/terraform/azure/vnet output -json
# set aks_subnet_id
```

```bash
task az:bootstrap-iam:apply
task az:helm-velero:apply
```

Or:

```bash
task az:apply-all
```

### AWS Terraform modules

| Module | Creates |
|--------|---------|
| `bootstrap` | S3 bucket for Terraform remote state |
| `vpc` | VPC, public/private subnets, NAT gateway, IGW |
| `s3` | S3 bucket for Velero backups |
| `eks` | EKS cluster, managed node group, OIDC provider, EKS addons |
| `bootstrap-iam` | Velero IRSA role + EBS CSI driver IRSA role |
| `helm-velero` | Velero Helm release (chart 12.0.1 / app v1.18.0) |

### Azure Terraform modules

| Module | Creates |
|--------|---------|
| `bootstrap` | Azure Storage Account for Terraform remote state |
| `vnet` | VNet, AKS subnet |
| `storage` | Azure Blob container |
| `aks` | AKS cluster, system + user node pools |
| `bootstrap-iam` | Workload identity for Velero |
| `helm-velero` | Velero Helm release (chart 12.0.1 / app v1.18.0) |

## Migration Workflow

### 1. Deploy databases on AKS

```bash
task manifests:deploy:aks
task manifests:status
```

### 2. Seed data

```bash
# Default: 100 customers, 1–5 orders each
task data:generate:all

# Custom scale
task data:generate:mysql    CUSTOMERS=10000 ORDERS_MIN=5 ORDERS_MAX=20
task data:generate:postgres CUSTOMERS=10000 ORDERS_MIN=5 ORDERS_MAX=20

# Check counts
task data:count:aks
```

### 3. Back up from AKS

```bash
task velero:backup          # one-off backup of databases namespace
task velero:status          # wait for phase: Completed
```

A daily scheduled backup (`databases-daily`) is also defined in `velero/backup.yaml` and can be applied to keep S3 in sync during a phased migration.

### 4. Restore to EKS

Run the restore only after the backup shows `Completed`:

```bash
velero restore create databases-migration \
  --from-backup databases-migration \
  --include-namespaces databases \
  --context <EKS_CONTEXT> \
  --wait
```

> **Important:** The `databases` namespace must not exist on EKS before the restore. If it does, delete it first so Velero can inject the volume-restore init containers cleanly:
> ```bash
> kubectl delete namespace databases --context <EKS_CONTEXT>
> ```

Monitor restore progress:

```bash
task velero:status
kubectl get podvolumerestores -n velero --context <EKS_CONTEXT>
```

### 5. Verify

```bash
task data:verify            # compares AKS vs EKS row counts — PASS/FAIL
task manifests:status       # shows pod and PVC status on both clusters
```

Example output:

```
Migration verification
============================================
  [PASS] MySQL
         AKS → customers: 10,400  orders: 133,254
         EKS → customers: 10,400  orders: 133,254

  [PASS] Postgres
         AKS → customers: 10,400  orders: 132,785
         EKS → customers: 10,400  orders: 132,785

Overall: PASS — AKS and EKS data match
```

## Task Reference

### Data

| Task | Description |
|------|-------------|
| `task data:generate:all` | Seed fake data into AKS (MySQL + Postgres) |
| `task data:generate:mysql` | Seed MySQL only. Flags: `CUSTOMERS`, `ORDERS_MIN`, `ORDERS_MAX`, `BATCH_SIZE` |
| `task data:generate:postgres` | Seed Postgres only |
| `task data:count:aks` | Row counts on AKS |
| `task data:count:eks` | Row counts on EKS |
| `task data:count:all` | Row counts on both clusters |
| `task data:verify` | Compare AKS vs EKS — exits 1 on mismatch |

### Velero

| Task | Description |
|------|-------------|
| `task velero:backup` | Apply `velero/backup.yaml` on AKS |
| `task velero:restore` | Apply `velero/restore.yaml` on EKS |
| `task velero:status` | Backup + restore status on both clusters |

### Manifests

| Task | Description |
|------|-------------|
| `task manifests:deploy:aks` | Deploy databases on AKS |
| `task manifests:deploy:eks` | Deploy databases on EKS |
| `task manifests:delete:aks` | Delete databases from AKS |
| `task manifests:delete:eks` | Delete databases from EKS |
| `task manifests:status` | Pod + PVC status on both clusters |

### AWS Infrastructure

| Task | Description |
|------|-------------|
| `task aws:init-all` | Init all AWS modules |
| `task aws:apply-all` | Apply all AWS modules in order |
| `task aws:destroy-all` | Destroy all AWS modules in reverse order |
| `task bootstrap:apply` | Apply S3 state bucket |
| `task vpc:apply` | Apply VPC |
| `task s3:apply` | Apply Velero S3 bucket |
| `task eks:apply` | Apply EKS cluster + addons |
| `task bootstrap-iam:apply` | Apply IRSA roles |
| `task helm-velero:apply` | Install Velero on EKS |

### Azure Infrastructure

| Task | Description |
|------|-------------|
| `task az:init-all` | Init all Azure modules |
| `task az:apply-all` | Apply all Azure modules in order |
| `task az:destroy-all` | Destroy all Azure modules in reverse order |
| `task az:aks:apply` | Apply AKS cluster |
| `task az:bootstrap-iam:apply` | Apply Velero workload identity |
| `task az:helm-velero:apply` | Install Velero on AKS |

## Environments

`dev` and `prod` tfvars live under `infrastructure/environments/{aws,azure}/`. Switch with:

```bash
ENV=prod task aws:apply-all
ENV=prod task az:apply-all
```

## Teardown

```bash
task aws:destroy-all
task az:destroy-all
```

> Note: `task aws:destroy-all` destroys EKS, S3, and VPC but not the Terraform state bucket (`bootstrap`). Delete that manually if needed: `task bootstrap:destroy`.
