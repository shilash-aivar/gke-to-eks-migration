image:
  repository: velero/velero
  tag: v1.18.0
  pullPolicy: IfNotPresent

initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.11.0
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

metrics:
  enabled: true
  scrapeInterval: 30s
