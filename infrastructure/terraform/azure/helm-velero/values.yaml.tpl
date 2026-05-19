image:
  repository: velero/velero
  tag: v1.18.0
  pullPolicy: IfNotPresent

upgradeCRDs: true

kubectl:
  image:
    repository: registry.k8s.io/kubectl
    tag: "v1.32.3"

initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.13.1
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins

configuration:
  backupStorageLocation:
    - name: default
      provider: aws
      bucket: ${velero_bucket_name}
      default: true
      config:
        region: ${aws_region}
  volumeSnapshotLocation:
    - name: default
      provider: aws
      config:
        region: ${aws_region}
  defaultVolumesToFsBackup: true
  uploaderType: kopia

credentials:
  useSecret: true
  name: velero-credentials
  secretContents:
    cloud: |
      [default]
      aws_access_key_id=${aws_access_key_id}
      aws_secret_access_key=${aws_secret_access_key}

serviceAccount:
  server:
    name: velero-server
    namespace: velero

rbac:
  create: true
  clusterAdministrator: true
  clusterAdministratorName: cluster-admin

deployNodeAgent: true

nodeAgent:
  podVolumePath: /var/lib/kubelet/pods
  privileged: false
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

configMaps:
  change-storage-class:
    labels:
      velero.io/plugin-config: ""
      velero.io/change-storage-class: RestoreItemAction
    data:
      standard: gp2
      standard-rwo: gp2
      premium-rwo: gp3
      managed-csi: gp2
      managed: gp2
      default: gp2
      managed-csi-premium: gp3
      managed-premium: gp3

metrics:
  enabled: true
  scrapeInterval: 30s
