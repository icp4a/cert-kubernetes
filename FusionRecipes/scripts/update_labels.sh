#!/bin/bash
#set -x
# Map variable names to secret names
declare -A SECRET_VARS=(
  [ICN_DB_NAME]="ibm-ban-secret"
  [BAS_DB_NAME]="icp4adeploy-bas-admin-secret"
  [BAW_DB_NAME]="ibm-baw-wfs-server-db-secret"
  [ODM_DB_NAME]="ibm-odm-db-secret"
  [APP_DB_NAME]="playback-server-admin-secret"
)

yaml_files=(
  "cp4ba-baw-authorize-backup-restore-template.yaml"
  "cp4ba-fncm-backup-restore-template.yaml"
  "cp4ba-baw-runtime-backup-restore-template.yaml"
  "cp4ba-ads-backup-restore-template.yaml"
  "cp4ba-odm-backup-restore-template.yaml"
)

# Fetch db-names and replace in YAMLs
for yaml_file in "${yaml_files[@]}"; do
  if [ ! -f "$yaml_file" ]; then
    echo "Error: File $yaml_file not found in FusionRecipes folder."
    exit 1
  fi
  for VAR in "${!SECRET_VARS[@]}"; do
    SECRET_NAME="${SECRET_VARS[$VAR]}"
    DB_NAME=$(oc get secret "$SECRET_NAME" -o jsonpath="{.metadata.labels['db-name']}" 2>/dev/null)
    if [ -n "$DB_NAME" ]; then
      sed -i "s/\${$VAR}/$DB_NAME/g" "$yaml_file"
      echo "Updated $yaml_file with db-name from $SECRET_NAME: $DB_NAME"
    fi
  done
done