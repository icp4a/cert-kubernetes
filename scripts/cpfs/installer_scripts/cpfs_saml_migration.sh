#!/bin/bash

# This script migrates cloudctl configured saml present in old namespace to new CS instance in new namespace
# Prompt for user input
read -rp "Enter the Old Common services namespace: " OLD_CS_NAMESPACE
read -rp "Enter the New Common services namespace: " NEW_CS_NAMESPACE

# Validate if provided namespace exist or not
if ! oc get namespace "$OLD_CS_NAMESPACE" &>/dev/null; then
  echo "Error: Namespace '$OLD_CS_NAMESPACE' does not exist!"
  exit 1
fi

# Validate if provided namespace exist or not
if ! oc get namespace "$NEW_CS_NAMESPACE" &>/dev/null; then
  echo "Error: Namespace '$NEW_CS_NAMESPACE' does not exist!"
  exit 1
fi

# Check if jq is installed
if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' command not found. Please install jq to proceed."
  exit 1
fi

# Check if icp-mongodb-0 pod exists
if ! oc get pod icp-mongodb-0 -n "$OLD_CS_NAMESPACE" &>/dev/null; then
  echo "Error: Pod 'icp-mongodb-0' does not exist in namespace '$OLD_CS_NAMESPACE'."
  exit 1
fi

# Check if icp-mongodb-0 pod is running
POD_STATUS=$(oc get pod icp-mongodb-0 -n "$OLD_CS_NAMESPACE" -o jsonpath='{.status.phase}')
if [[ "$POD_STATUS" != "Running" ]]; then
  echo "Error: Pod 'icp-mongodb-0' exists but is not in 'Running' state (current state: $POD_STATUS)."
  exit 1
fi

# Check if samlDB exists, then check if saml collection exists and is not empty
echo "Validating samlDB and 'saml' collection existence and data..."
VALIDATION_RESULT=$(oc exec -n "$OLD_CS_NAMESPACE" icp-mongodb-0 -- bash -c '
  mongo --host rs0/mongodb:27017 \
        --username "$ADMIN_USER" \
        --password "$ADMIN_PASSWORD" \
        --authenticationDatabase admin \
        --ssl \
        --sslCAFile /data/configdb/tls.crt \
        --sslPEMKeyFile /work-dir/mongo.pem \
        --quiet --eval "
          var dbs = db.adminCommand({ listDatabases: 1 }).databases.map(d => d.name);
          if (!dbs.includes(\"samlDB\")) {
              print(\"ERROR: samlDB not found, saml is not configured via cloudctl\");
              quit(1);
          }
          db = db.getSiblingDB(\"samlDB\");
          var collections = db.getCollectionNames();
          if (!collections.includes(\"saml\")) {
              print(\"ERROR: saml collection not found, saml is not configured via cloudctl\");
              quit(1);
          }
          var count = db.saml.countDocuments({});
          if (count === 0) {
              print(\"ERROR: saml collection is empty, saml is not configured via cloudctl\");
              quit(1);
          }
          print(\"OK\");
        "
')

VALIDATION_RESULT=$(echo "$VALIDATION_RESULT" | grep -vE "^[0-9]{4}-[0-9]{2}-[0-9]{2}T.* [A-Z]+  \[.*\]" | tail -n 1) 
if [[ "$VALIDATION_RESULT" != "OK" ]]; then
  echo "$VALIDATION_RESULT"
  exit 1
fi
# Step 1: Fetch metadata from MongoDB pod and clean the output
echo "Fetching idp_metadata from MongoDB pod..."
RAW_OUTPUT=$(oc exec -n "$OLD_CS_NAMESPACE" icp-mongodb-0 -- bash -c '
  mongo --host rs0/mongodb:27017 \
        --username "$ADMIN_USER" \
        --password "$ADMIN_PASSWORD" \
        --authenticationDatabase admin \
        --ssl \
        --sslCAFile /data/configdb/tls.crt \
        --sslPEMKeyFile /work-dir/mongo.pem \
        --quiet --eval "
          db = db.getSiblingDB(\"samlDB\");
          doc = db.saml.findOne({ name: \"saml\" });
          if (doc && doc.metadata) {
              print(doc.metadata);
          } else {
              print(\"ERROR: Metadata not found\");
              quit(1);
          }
        "
')

# Only keep the line containing the actual base64 string (it is the last one or only one without timestamps)
IDP_METADATA=$(echo "$RAW_OUTPUT" | grep -vE "^[0-9]{4}-[0-9]{2}-[0-9]{2}T.* [A-Z]+  \[.*\]" | tail -n 1) 

echo "printing idp_metadata below"

echo $IDP_METADATA

# Validate
if [[ "$IDP_METADATA" == ERROR* ]] || [[ -z "$IDP_METADATA" ]]; then
  echo "Failed to retrieve clean metadata."
  echo "Full raw output was:"
  echo "$RAW_OUTPUT"
  exit 1
fi

echo "Building payload..."
cat <<EOF > payload.json
{
  "name": "saml",
  "description": "this is plain saml",
  "protocol": "saml",
  "type": "default",
  "idp_config": {
    "token_attribute_mappings": {
      "sub": "uid",
      "given_name": "firstName",
      "family_name": "lastName",
      "groups": "blueGroups",
      "email": "emailAddress",
      "first_name": "firstName",
      "last_name": "lastName"
    },
    "idp_metadata": "$IDP_METADATA"
  },
  "jit": true
}
EOF


echo "Fetching IAM admin credentials..."
IAM_ADMIN=$(oc get secret platform-auth-idp-credentials -n "$NEW_CS_NAMESPACE" -o jsonpath='{.data.admin_username}' | base64 -d)
IAM_PASS=$(oc get secret platform-auth-idp-credentials -n "$NEW_CS_NAMESPACE" -o jsonpath='{.data.admin_password}' | base64 -d)
IAM_HOST="https://$(oc get route cp-console -n "$NEW_CS_NAMESPACE" -o jsonpath="{.spec.host}")"

echo "Obtaining IAM access token..."
IAM_ACCESS_TOKEN=$(curl -sk -X POST -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" \
  -d "grant_type=password&username=$IAM_ADMIN&password=$IAM_PASS&scope=openid" \
  "$IAM_HOST/idprovider/v1/auth/identitytoken" | jq -r .access_token)

if [[ -z "$IAM_ACCESS_TOKEN" || "$IAM_ACCESS_TOKEN" == "null" ]]; then
  echo "Error: Failed to obtain IAM access token."
else
  echo "IAM access token retrieved successfully."
fi

echo "Register saml using idpv3 api"
curl -k -X POST "$IAM_HOST/idprovider/v3/auth/idsource" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $IAM_ACCESS_TOKEN" \
  --data @payload.json