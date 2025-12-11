#!/bin/bash

# Script Name: apply-zen-files.sh
# Usage: ./apply-zen-files.sh $NAMESPACE <zenservice-name>
# Example: ./apply-zen-files.sh cp4ba iaf-zen-cpdservice

set -e 
set -o pipefail

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 \$NAMESPACE <zenservice-name>"
  exit 1
fi

NAMESPACE=$1
ZENSERVICE_NAME=$2
YAML_DIR="yamls/zen"

echo "Replacing placeholders in $YAML_DIR..."
echo " <zenservice namespace> → $NAMESPACE"
echo " <zenservice name> → $ZENSERVICE_NAME"

# Loop through YAML files and replace both placeholders
find "$YAML_DIR" -type f -name "*.yaml" | while read -r file; do
  sed "s/<zenservice namespace>/$NAMESPACE/g; s/<zenservice name>/$ZENSERVICE_NAME/g" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  echo "Updated $file"
done

echo "Replacement completed."

echo "Applying ZenService resources..."

oc apply -f "$YAML_DIR/zen5-backup-pvc.yaml" -n "$NAMESPACE"
oc apply -f "$YAML_DIR/zen5-br-scripts-cm.yaml" -n "$NAMESPACE"
oc apply -f "$YAML_DIR/zen5-backup-deployment.yaml" -n "$NAMESPACE"
oc apply -f "$YAML_DIR/zen5-role.yaml" -n "$NAMESPACE"
oc apply -f "$YAML_DIR/zen5-sa.yaml" -n "$NAMESPACE"
oc apply -f "$YAML_DIR/zen5-rolebinding.yaml" -n "$NAMESPACE"

echo "All zen files applied successfully."