#!/bin/bash
BACKUP_POLICY_NAME=$1
FBSL_NAME=$2
RETENTION_PERIOD=$3
RETENTION_UNIT=$4
SCHEDULE_CRON_EXPRESSION=$5
SCHEDULE_TIME_ZONE=$6

#!/bin/bash

# Define YAML content
cat <<EOF | oc apply -f -
apiVersion: data-protection.isf.ibm.com/v1alpha1
kind: BackupPolicy
metadata:
  annotations:
    dp.isf.ibm.com/provider-name: isf-backup-restore
  name: $BACKUP_POLICY_NAME
  namespace: ibm-spectrum-fusion-ns
  finalizers:
    - backuppolicy
  labels:
    dp.isf.ibm.com/backupstoragelocation-name: $FBSL_NAME
    dp.isf.ibm.com/provider-name: isf-backup-restore
spec:
  backupStorageLocation: $FBSL_NAME
  provider: isf-backup-restore
  retention:
    number: $RETENTION_PERIOD
    unit: $RETENTION_UNIT
  schedule:
    cron: '${SCHEDULE_CRON_EXPRESSION}'
    timezone: $SCHEDULE_TIME_ZONE
EOF
