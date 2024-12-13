#!/bin/bash
POLICY_ASSIGNMENT_NAME=$1
APPLICATION=$2
BACKUP_POLICY=$3
FBSL_NAME=$4
RECIPE_NAME=$5


# Apply PolicyAssignment using here document
oc apply -f - <<EOF
apiVersion: data-protection.isf.ibm.com/v1alpha1
kind: PolicyAssignment
metadata:
  annotations:
    dp.isf.ibm.com/provider-name: isf-backup-restore
  name: $POLICY_ASSIGNMENT_NAME
  namespace: ibm-spectrum-fusion-ns
  finalizers:
    - policyassignment
  labels:
    dp.isf.ibm.com/application-name: $APPLICATION
    dp.isf.ibm.com/backuppolicy-name: $BACKUP_POLICY
    dp.isf.ibm.com/backupstoragelocation-name: $FBSL_NAME
    dp.isf.ibm.com/provider-name: isf-backup-restore
spec:
  application: $APPLICATION
  backupPolicy: $BACKUP_POLICY
  recipe:
    name: $RECIPE_NAME
    namespace: ibm-spectrum-fusion-ns
  runNow: false
EOF

echo "-------Fusion Backup Policy Assignment Created-------"