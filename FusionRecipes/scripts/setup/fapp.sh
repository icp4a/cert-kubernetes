#!/bin/bash

# Check if all required arguments are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <APPLICATION_NAME> <NAMESPACE_1> <NAMESPACE_2> [<NAMESPACE_3> ... <NAMESPACE_N>]"
    exit 1
fi

# Input variables
APPLICATION_NAME="$1"
shift
NAMESPACE_1="$1"
shift
NAMESPACE_2="$1"
shift
INCLUDED_NAMESPACES=("$NAMESPACE_1" "$NAMESPACE_2" "$@")

# Template for the YAML file
YAML_TEMPLATE=$(cat <<'EOF'
apiVersion: application.isf.ibm.com/v1alpha1
kind: Application
metadata:
  annotations:
    dp.isf.ibm.com/provider-name: isf-backup-restore
  name: <APPLICATION>
  namespace: ibm-spectrum-fusion-ns
  finalizers:
    - application-controller
  labels:
    dp.isf.ibm.com/provider-name: isf-backup-restore
spec:
  enableDR: false
  includedNamespaces:
<included_namespaces>
EOF
)

# Generate included namespaces part of the YAML
INCLUDED_NAMESPACES_YAML=""
for NAMESPACE in "${INCLUDED_NAMESPACES[@]}"
do
  INCLUDED_NAMESPACES_YAML+="    - $NAMESPACE\n"
done

# Replace placeholders with actual values
YAML_CONTENT=$(echo "$YAML_TEMPLATE" | sed "s/<APPLICATION>/$APPLICATION_NAME/g; s|<included_namespaces>|$INCLUDED_NAMESPACES_YAML|")

# Apply the YAML directly using oc apply
echo -e "$YAML_CONTENT" | oc apply -f -
