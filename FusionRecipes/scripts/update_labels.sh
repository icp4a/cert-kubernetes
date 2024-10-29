#!/bin/bash
#set -x
# Define an array mapping the recipe secret names to actual secret names
declare -A SECRET_MAPPING=(
  ["cp4ba-ibm-ban-secret"]="ibm-ban-secret"
  ["cp4ba-ibm-baw-secret"]="ibm-baw-wfs-server-db-secret"
  ["cp4ba-bas-admin-secret"]="icp4adeploy-bas-admin-secret"
)
# Fetch the db-name from the actual Kubernetes secrets' labels and assign to variables
ICN_DB_NAME=$(oc get secret ibm-ban-secret -o jsonpath="{.metadata.labels['db-name']}" 2>/dev/null)
BAS_DB_NAME=$(oc get secret icp4adeploy-bas-admin-secret -o jsonpath="{.metadata.labels['db-name']}" 2>/dev/null)
BAW_DB_NAME=$(oc get secret ibm-baw-wfs-server-db-secret -o jsonpath="{.metadata.labels['db-name']}" 2>/dev/null)
# Define the YAML files to update
yaml_files=(
  "cp4ba-baw-authorize-backup-restore-template.yaml"
  "cp4ba-fncm-backup-restore-template.yaml"
  "cp4ba-baw-runtime-backup-restore-template.yaml"
)
# Loop through the YAML files and update the db-name if fetched
for yaml_file in "${yaml_files[@]}"; do
  # Check if the YAML file exists
  if [ ! -f "$yaml_file" ]; then
    echo "Error: File $yaml_file not found in FusionRecipes folder."
    exit 1
  fi
  # Update the YAML file with the db-name if it exists
  if [ -n "$ICN_DB_NAME" ]; then
    sed -i "s/\${ICN_DB_NAME}/$ICN_DB_NAME/g" "$yaml_file"
    echo "Updated $yaml_file with db-name from ibm-ban-secret: $ICN_DB_NAME"
  fi
  if [ -n "$BAS_DB_NAME" ]; then
    sed -i "s/\${BAS_DB_NAME}/$BAS_DB_NAME/g" "$yaml_file"
    echo "Updated $yaml_file with db-name from icp4adeploy-bas-admin-secret: $BAS_DB_NAME"
  fi
  if [ -n "$BAW_DB_NAME" ]; then
    sed -i "s/\${BAW_DB_NAME}/$BAW_DB_NAME/g" "$yaml_file"
    echo "Updated $yaml_file with db-name from ibm-baw-wfs-server-db-secret: $BAW_DB_NAME"
  fi
done 