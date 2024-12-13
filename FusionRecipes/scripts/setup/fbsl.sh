#!/bin/bash

FBSL_NAME=$1
FBSL_TYPE=$2
SECRET_DATA=$3
PARAMS=$4

# Apply YAML files using oc apply command
cat <<EOF | oc apply -f -
apiVersion: v1
data:
$SECRET_DATA
kind: Secret
metadata:
  labels:
    dp.isf.ibm.com/ownedBy: fbsl
    dp.isf.ibm.com/provider-name: isf-backup-restore
  name: ${FBSL_NAME}-secret
  namespace: ibm-spectrum-fusion-ns
type: Opaque
---
apiVersion: data-protection.isf.ibm.com/v1alpha1
kind: BackupStorageLocation
metadata:
  name: $FBSL_NAME
  namespace: ibm-spectrum-fusion-ns
  finalizers:
    - backupstoragelocation
  labels:
    dp.isf.ibm.com/backupstoragelocation-type: $FBSL_TYPE
    dp.isf.ibm.com/provider-name: isf-backup-restore
spec:
  credentialName: ${FBSL_NAME}-secret
  params:
    $PARAMS
  provider: isf-backup-restore
  type: $FBSL_TYPE
EOF
