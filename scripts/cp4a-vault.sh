#!/bin/bash
# set -x
###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2022. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
###############################################################################

## This script will take 3 parameters from the command line
## -m --mode: patch
## -n --namespace: the namespace to patch
##    --csv : The name of the CSV to patch

# The script will first retrieve the CSV by name, then save it to a temporary file under scripts/.tmp/$namespace
# It will read all the SecretProviderClass from scripts/cp4ba-prerequisites/project/$namespace/secret_template/vault/*.yaml, then mount it as a secret into the CSV.
# For example, ldap-bind-secret-provider-class.yaml has
#####
#apiVersion: secrets-store.csi.x-k8s.io/v1
#kind: SecretProviderClass
#metadata:
#   name: ldap-bind-secret             
#   namespace: "scott-olm"
#   labels:
#     cp4ba.ibm.com/backup-type: mandatory
# spec:
#   provider: vault                           
#   parameters:                               
#     roleName: "csi"
#     vaultAddress: "http://vault.vault:8200"
#     objects:  |
#      - secretPath: "/secret/data/cp4ba/ldap-bind-secret"
#        objectName: "ldapUsername"
#        secretKey: "ldapUsername"
#      - secretPath: "/secret/data/cp4ba/ldap-bind-secret"
#        objectName: "ldapPassword"
#        secretKey: "ldapPassword"
#####
# then it will mount (append) these secrets into the CSV as follows:
#     volumeMounts:
#     ...
#     - mountPath: /tmp/secrets/ldap-bind-secret
#       name: ldap-bind-secret
#       readOnly: true
#  volumes:
#   ...
#   - csi:
#       driver: secrets-store.csi.k8s.io
#       readOnly: true
#       volumeAttributes:
#         secretProviderClass: ldap-bind-secret
#     name: ldap-bind-secret

# Source common.sh file - follow the same pattern as other scripts
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # This is helper/vault
#DBACLD-189643: Define backup directories for CSVs during upgrade
UPGRADE_DEPLOYMENT_FOLDER=${CUR_DIR}/cp4ba-upgrade/project/$CP4BA_SERVICES_NS
UPGRADE_DEPLOYMENT_CSV_BAK=${UPGRADE_DEPLOYMENT_FOLDER}/csv/backup


# Source common.sh from the helper directory
source ${CUR_DIR}/helper/common.sh
source ${CUR_DIR}/helper/ext-secrets-mgmt/common_functions_vault.sh

export CURR_TIME=$(date "+%Y%m%d-%H%M%S")


function show_help() {
  info "CP4BA Vault Helper Script"
  echo "========================="
  echo "This script patches CSV files to mount vault secrets via SecretProviderClass."
  echo "After patching, it automatically checks that all pods are in Running state."
  echo ""
  echo "Usage: $0 -m <mode> -n <namespace> --csv <csv_name> [--csvDeploymentName <deployment_name>] [--operatorNamespace <operator_namespace>]"
  echo ""
  echo "Options:"
  echo "  -m                   : Mode - [patch|strategic|unpatch|generate]"
  echo "                       patch: Standard YAML patching and kubectl apply"
  echo "                       strategic: Server-side apply with conflict resolution"
  echo "                       unpatch: Remove SecretProviderClass volumes from CSV"
  echo "                       generate: Generate CSV but don't apply (generate only)."
  echo "  -n | --namespace     : Services namespace for SecretProviderClass files"
  echo "  --operatorNamespace  : [Optional]Operator namespace for CSV  (defaults to --namespace)"
  echo "  --csv                : Name of the CSV(s) to patch. Accepts a single CSV or a comma-separated list."
  echo "                         e.g. --csv ibm-cp4a-operator.$CP4BA_CSV_VERSION"
  echo "                         e.g. --csv ibm-cp4a-operator.$CP4BA_CSV_VERSION,ibm-content-operator.$CP4BA_CSV_VERSION"
  echo "                         e.g. --csv \"ibm-cp4a-operator.$CP4BA_CSV_VERSION,ibm-content-operator.$CP4BA_CSV_VERSION\" (spaces around commas are trimmed)"
  echo "  --csvDeploymentName  : [Optional]Name of the deployment inside the CSV to patch. Default will be the first deployment"
  echo "  -h | --help          : Show this help message"
  echo ""
  echo ""
  echo "${GREEN_TEXT}Examples:${RESET_TEXT}"

  echo "${GREEN_TEXT}==== Separation of duties ====${RESET_TEXT}"
  echo "  $0 -m patch -n operand-ns --operatorNamespace operator-ns --csv ibm-cp4a-operator.$CP4BA_CSV_VERSION"
  echo ""
  echo "  $0 -m strategic -n operand-ns --operatorNamespace operator-ns --csv ibm-cp4a-operator.$CP4BA_CSV_VERSION --csvDeploymentName ibm-cp4a-operator"
  echo ""
  echo "  $0 -m unpatch -n operand-ns --operatorNamespace operator-ns --csv ibm-cp4a-operator.$CP4BA_CSV_VERSION"
  echo ""
  echo "  $0 -m generate -n operand-ns --operatorNamespace operator-ns --csv ibm-cp4a-operator.$CP4BA_CSV_VERSION"
  echo ""
  echo "${GREEN_TEXT}==== End of Separation of duties examples ====${RESET_TEXT}"
  echo ""
  echo "${GREEN_TEXT}==== Non separation of duties ====${RESET_TEXT}"
  echo "  $0 -m patch -n cp4ba-ns --csv ibm-cp4a-operator.$CP4BA_CSV_VERSION"
  echo ""
  echo "  $0 -m strategic -n cp4ba-ns --csv ibm-cp4a-operator.$CP4BA_CSV_VERSION --csvDeploymentName ibm-cp4a-operator"
  echo ""
  echo "  $0 -m unpatch -n cp4ba-ns --csv ibm-cp4a-operator.$CP4BA_CSV_VERSION"
  echo ""
  echo "  $0 -m generate -n cp4ba-ns --csv ibm-cp4a-operator.$CP4BA_CSV_VERSION"
  echo "${GREEN_TEXT}==== End of non separation of duties ====${RESET_TEXT}"
  echo ""
  # Below is the undocumented mode for calling during the upgrade script. This mode should not be run by users directly.
  # echo "${GREEN_TEXT}==== Upgrade (migrate vault CSI mounts from old CSV version to new CSV version) ====${RESET_TEXT}"
  # echo "  $0 -m upgrade -n operand-ns [--operatorNamespace operator-ns]"
  # echo ""
  # echo "  $0 -m upgrade -n cp4ba-ns"
  # echo "${GREEN_TEXT}==== End of upgrade examples ====${RESET_TEXT}"

}

function parse_arguments(){
    # process options
    while [[ "$@" != "" ]]; do
        case "$1" in
        -m)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: -m requires an argument"
                exit 1
            fi
            RUNTIME_MODE=$1
            if [[ $RUNTIME_MODE == "patch" || $RUNTIME_MODE == "strategic" || $RUNTIME_MODE == "unpatch" || $RUNTIME_MODE == "generate" || $RUNTIME_MODE == "upgrade" ]]; then
                # Valid mode
                info "Mode set to: $RUNTIME_MODE"
            else
                error "Use a valid value: -m [patch|strategic|unpatch|generate|upgrade]"
                exit 1
            fi
            ;;
        -n)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: -n requires an argument"
                exit 1
            fi
            TARGET_PROJECT_NAME=$1
            case "$TARGET_PROJECT_NAME" in
            "")
                error "Enter a valid namespace name, namespace name can not be blank"
                exit 1
                ;;
            "openshift"*)
                error "Enter a valid project name, project name should not be 'openshift' or start with 'openshift'"
                exit 1
                ;;
            "kube"*)
                error "Enter a valid project name, project name should not be 'kube' or start with 'kube'"
                exit 1
                ;;
            *)
                # Check cluster login
                check_cluster_login
                # Check project name
                isProjExists=$($CLI_CMD get project $TARGET_PROJECT_NAME --ignore-not-found | wc -l)  >/dev/null 2>&1
                if [ $isProjExists -ne 2 ] ; then
                    error "Invalid project name \"$TARGET_PROJECT_NAME\", please set an existing project name."
                    exit 1
                fi
                success "Valid project name: $TARGET_PROJECT_NAME"
                ;;
            esac
            ;;
        --csv)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: --csv requires an argument"
                exit 1
            fi
            CSV="$1"
            # Consume space-separated continuation tokens to support forms like:
            #   --csv a , b       ($2=","  $3="b")
            #   --csv a ,b        ($2=",b")
            # A continuation is either a bare "," or a token starting with "," (and not a flag).
            while true; do
                if [[ "$2" == "," ]]; then
                    shift  # consume the bare ","
                    if [[ -n "$2" && "$2" != -* ]]; then
                        shift
                        CSV="${CSV},${1}"
                    fi
                elif [[ "$2" == ,* && "$2" != -* ]]; then
                    shift
                    CSV="${CSV}${1}"  # $1 already starts with ","
                else
                    break
                fi
            done
            ;;
        --csvDeploymentName)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: --csvDeploymentName requires an argument"
                exit 1
            fi
            CSV_DEPLOYMENT_NAME=$1
            ;;
        --operatorNamespace)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: --operatorNamespace requires an argument"
                exit 1
            fi
            OPERATOR_NAMESPACE=$1
            ;;
        -h | --help | \?)
            show_help
            exit 0
            ;;
        *)
            echo "Invalid option"
            show_help
            exit 1
            ;;
        esac
        shift
    done

# Validate required arguments after parsing
if [ -z "$RUNTIME_MODE" ]; then
    error "Mode is required. Use -m [patch|strategic|unpatch|generate|upgrade]"
    show_help
    exit 1
fi

if [ -z "$TARGET_PROJECT_NAME" ]; then
    error "Namespace is required. Use -n <namespace>"
    show_help
    exit 1
fi

if [ -z "$CSV" ] && [[ "$RUNTIME_MODE" != "upgrade" ]]; then
    error "CSV name is required. Use --csv <csv_name>"
    show_help
    exit 1
fi

}
function save_log_wrapper(){
  # Use the save_log function from common.sh to save log to scripts/.tmp/<namespace>
  save_log ".tmp/${TARGET_PROJECT_NAME}" "vault-csv-log"
}

function retrieve_csv() {
  info "Retrieving CSV: $CSV from namespace: $OPERATOR_NAMESPACE"

  ${CLI_CMD} get csv $CSV -n $OPERATOR_NAMESPACE -o yaml > $TMP_DIR/$CSV.yaml
  if [ $? -ne 0 ]; then
    error "Failed to retrieve CSV: $CSV from namespace: $OPERATOR_NAMESPACE"
    return 1
  else
    success "CSV $CSV retrieved successfully from namespace $OPERATOR_NAMESPACE and saved to $TMP_DIR/$CSV.yaml"
    retrieve_secret_provider_classes $CSV
  fi
}
function retrieve_secret_provider_classes() {
  info "Retrieving SecretProviderClasses for CSV: $CSV"
  cp $TMP_DIR/$CSV.yaml $TMP_DIR/$CSV-patched.yaml > /dev/null 2>&1

  # Strip version suffix from CSV name (e.g. ibm-cp4a-operator.v25.0.1 -> ibm-cp4a-operator)
  # Not local so create_volumes_structure (generate mode summary) can reference it
  csv_base_name="${CSV%%.*}"
  info "CSV base name (version stripped): $csv_base_name"

  info "Get a list of all SecretProviderClass yaml files from $SECRET_PROVIDER_CLASS_DIR recursively"
  
  # For non-separation of duty we can find all the yaml.  However, for separation of duty there will be two SecretProviderClass for each secret.  One will have the operator namespace append to it.  For example: ldap-bind-secret-secret-provider-class-cp4ba-operator.yaml
  # For seperation of duties, we need to only search on the operator namespace

  if [[ $TARGET_PROJECT_NAME != $OPERATOR_NAMESPACE ]]; then # Separation of duties
    SECRET_PROVIDER_CLASS_FILES=$(find $SECRET_PROVIDER_CLASS_DIR -name "*-$OPERATOR_NAMESPACE.yaml")
  else # Non-separation of duties
    SECRET_PROVIDER_CLASS_FILES=$(find $SECRET_PROVIDER_CLASS_DIR -name "*.yaml")
  fi

  if [ -z "$SECRET_PROVIDER_CLASS_FILES" ]; then
    warning "No SecretProviderClass yaml files found in $SECRET_PROVIDER_CLASS_DIR"
    exit 1
  else
    success "Found SecretProviderClass files:"
    echo "$SECRET_PROVIDER_CLASS_FILES"
  fi

  # Loop through each SecretProviderClass file, get the metadata.name and determine mount path
  for spc_file in $SECRET_PROVIDER_CLASS_FILES; do
    info "Retrieving CSV with SecretProviderClass: $spc_file"

    # Filter by cp4ba.ibm.com/owned-by annotation: only mount if the base CSV name is listed.
    # If the annotation is absent, apply to all CSVs (fallback for unlabeled SPC files).
    local owned_by
    owned_by=$($YQ_CMD ".metadata.annotations[\"cp4ba.ibm.com/owned-by\"] // \"\"" "$spc_file" 2>/dev/null)
    owned_by=$(sed -e 's/^"//' -e 's/"$//' <<<"$owned_by")  # strip surrounding quotes from yq output
    if [[ -n "$owned_by" ]]; then
      # owned-by is a comma-separated list; check if csv_base_name is one of the entries
      local match=0
      IFS=',' read -ra owned_by_arr <<< "$owned_by"
      for owner in "${owned_by_arr[@]}"; do
        owner=$(echo "$owner" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        if [[ "$owner" == "$csv_base_name" ]]; then
          match=1
          break
        fi
      done
      if [[ $match -eq 0 ]]; then
        info "Skipping $spc_file: '$csv_base_name' not in owned-by list '$owned_by'"
        continue
      fi
    else
      info "No cp4ba.ibm.com/owned-by annotation found in $spc_file — applying to all CSVs (fallback)"
    fi

    # Use yq to get the metadata.name, and add to the list recursively
    SPC_NAME=$($YQ_CMD ".metadata.name" $spc_file)
    success "Found SecretProviderClass name: $SPC_NAME"
    SECRET_PROVIDER_CLASS_NAMES+=("$SPC_NAME")
    
    # Determine mount path: prefer cp4ba.ibm.com/secret-store-type annotation; fall back to sub-directory name
    local store_type
    store_type=$($YQ_CMD ".metadata.annotations[\"cp4ba.ibm.com/secret-store-type\"] // \"\"" "$spc_file" 2>/dev/null)
    store_type=$(sed -e 's/^"//' -e 's/"$//' <<<"$store_type")
    if [[ "$store_type" == "tls" ]]; then
      SECRET_PROVIDER_CLASS_MOUNT_PATHS+=("/tmp/certificates/$SPC_NAME")
      info "SecretProviderClass $SPC_NAME will mount to /tmp/certificates/$SPC_NAME (annotation: tls)"
    elif [[ "$store_type" == "secrets" ]]; then
      SECRET_PROVIDER_CLASS_MOUNT_PATHS+=("/tmp/secrets/$SPC_NAME")
      info "SecretProviderClass $SPC_NAME will mount to /tmp/secrets/$SPC_NAME (annotation: secrets)"
    elif [[ "$spc_file" == *"/vault/secrets/"* ]]; then
      SECRET_PROVIDER_CLASS_MOUNT_PATHS+=("/tmp/secrets/$SPC_NAME")
      info "SecretProviderClass $SPC_NAME will mount to /tmp/secrets/$SPC_NAME (fallback: secrets folder)"
    elif [[ "$spc_file" == *"/vault/tls/"* ]]; then
      SECRET_PROVIDER_CLASS_MOUNT_PATHS+=("/tmp/certificates/$SPC_NAME")
      info "SecretProviderClass $SPC_NAME will mount to /tmp/certificates/$SPC_NAME (fallback: tls folder)"
    else
      SECRET_PROVIDER_CLASS_MOUNT_PATHS+=("/tmp/secrets/$SPC_NAME")
      warning "SecretProviderClass $SPC_NAME: no annotation or known sub-directory, defaulting to /tmp/secrets/$SPC_NAME"
    fi
    
    echo "${SECRET_PROVIDER_CLASS_NAMES[@]}"

  done

  if [ ${#SECRET_PROVIDER_CLASS_NAMES[@]} -eq 0 ]; then
    warning "No SecretProviderClasses need to be included for CSV '$CSV' (base name: '$csv_base_name'). Either no files exist or none have '$csv_base_name' in their cp4ba.ibm.com/owned-by label."
    return 1
  else
    create_volumes_structure
  fi
}

function create_volumes_structure(){
  info "Creating volumes structure for SecretProviderClasses: ${SECRET_PROVIDER_CLASS_NAMES[*]}"
  
  # Process based on mode
  if [[ $RUNTIME_MODE == "unpatch" ]]; then
    unpatch_volumes_from_csv
  else
    # patch or generate or strategic - all need patching
    patch_volume_to_csv
  fi
  
  # Apply the CSV based on the mode
  if [[ $RUNTIME_MODE == "strategic" ]]; then
    info "Applying strategic patch to CSV: $CSV in namespace: $OPERATOR_NAMESPACE"
    apply_strategic_patch "$TMP_DIR/$CSV-patched.yaml" "$CSV" "$OPERATOR_NAMESPACE" "$DEPLOYMENT_NAME"
  elif [[ $RUNTIME_MODE == "patch" ]]; then
    info "Applying patched CSV: $CSV to namespace: $OPERATOR_NAMESPACE"

    if [[ ${#JSON_PATCH_OPS[@]} -eq 0 ]]; then
      info "All CSI volumes already present in '$CSV', no changes needed."
    else # -m patch
      local patch_json
      patch_json="[$(IFS=,; echo "${JSON_PATCH_OPS[*]}")]"
      info "Patching CSV '$CSV' with ${#JSON_PATCH_OPS[@]} operation(s) via JSON patch..."
      patch_output=$(${CLI_CMD} patch csv "$CSV" -n "$OPERATOR_NAMESPACE" --type=json -p "$patch_json" 2>&1)
      patch_exit_code=$?

      if [ $patch_exit_code -eq 0 ]; then
        success "CSV $CSV patched successfully in namespace: $OPERATOR_NAMESPACE"
        info "Restarting deployment '$DEPLOYMENT_NAME' to pick up new vault mounts..."
        ${CLI_CMD} rollout restart deployment/"$DEPLOYMENT_NAME" -n "$OPERATOR_NAMESPACE" 2>/dev/null || true
        check_pods_running_status "$OPERATOR_NAMESPACE" "$CSV" "$DEPLOYMENT_NAME" 180
        validate_csv_vault_mounts "$TMP_DIR/$CSV-patched.yaml" "$CSV" "$OPERATOR_NAMESPACE"
      else
        error "Failed to patch CSV: $CSV in namespace: $OPERATOR_NAMESPACE"
        echo "$patch_output"
        exit 1
      fi
    fi
  elif [[ $RUNTIME_MODE == "unpatch" ]]; then
    info "Applying unpatched CSV: $CSV to namespace: $OPERATOR_NAMESPACE"
    ${CLI_CMD} apply -f "$TMP_DIR/$CSV-patched.yaml" -n "$OPERATOR_NAMESPACE"
    if [ $? -eq 0 ]; then
      success "CSV $CSV unpatched and applied successfully to namespace: $OPERATOR_NAMESPACE"
      # Check pod status after unpatching
      check_pods_running_status "$OPERATOR_NAMESPACE" "$CSV" "$DEPLOYMENT_NAME" 180
    else
      error "Failed to apply unpatched CSV: $CSV to namespace: $OPERATOR_NAMESPACE"
      exit 1
    fi
  elif [[ $RUNTIME_MODE == "generate" ]]; then
    info "CSV patching completed. Generated file: $TMP_DIR/$CSV-patched.yaml"
    info "--- owned-by annotation filter summary (csv_base_name: '$csv_base_name') ---"
    if [[ ${#SECRET_PROVIDER_CLASS_NAMES[@]} -gt 0 ]]; then
      info "SecretProviderClasses included for '$csv_base_name':"
      for spc in "${SECRET_PROVIDER_CLASS_NAMES[@]}"; do
        info "  + $spc"
      done
    else
      warning "No SecretProviderClasses matched for '$csv_base_name' — generated file will have no CSI mounts."
    fi
    success "Generated patched CSV without applying. File saved to: $TMP_DIR/$CSV-patched.yaml"
  fi
}

function patch_volume_to_csv(){
  info "Patching volumes to CSV..."
  JSON_PATCH_OPS=()
  
  # Find the deployment index - use index 0 if CSV_DEPLOYMENT_NAME is not provided
  if [ -z "$CSV_DEPLOYMENT_NAME" ]; then
    DEPLOYMENT_INDEX=0
    DEPLOYMENT_NAME=$(${YQ_CMD} ".spec.install.spec.deployments[0].name" $TMP_DIR/$CSV-patched.yaml)

  else
    DEPLOYMENT_INDEX=$(${YQ_CMD} '.spec.install.spec.deployments[].name // ""' $TMP_DIR/$CSV-patched.yaml  | grep -n "$CSV_DEPLOYMENT_NAME" | cut -d: -f1)
    if [ -z "$DEPLOYMENT_INDEX" ]; then
      error "Deployment $CSV_DEPLOYMENT_NAME not found in CSV. Available deployments:"
      ${YQ_CMD} '.spec.install.spec.deployments[].name' "$TMP_DIR/$CSV-patched.yaml"
      exit 1
    fi
    DEPLOYMENT_INDEX=$((DEPLOYMENT_INDEX - 1))  # Convert to 0-based index
    DEPLOYMENT_NAME="$CSV_DEPLOYMENT_NAME"
  fi
  
  info "Using deployment: $DEPLOYMENT_NAME at index: $DEPLOYMENT_INDEX"
  
  # Get current number of volumes to determine where to append
  CURRENT_VOLUMES=$(${YQ_CMD} ".spec.install.spec.deployments[$DEPLOYMENT_INDEX].spec.template.spec.volumes" $TMP_DIR/$CSV-patched.yaml | grep -c "name:" || echo "0")
  # echo "Current volumes count: $CURRENT_VOLUMES"
  
  # Parse volume content file to extract volume information efficiently
  # echo "Adding volumes directly from SECRET_PROVIDER_CLASS_NAMES array"
  
  # Add each volume directly from the SECRET_PROVIDER_CLASS_NAMES array
  for i in "${!SECRET_PROVIDER_CLASS_NAMES[@]}"; do
    SPC_NAME="${SECRET_PROVIDER_CLASS_NAMES[$i]}"
    
    # Check if volume already exists
    EXISTING_VOLUME=$(${YQ_CMD} ".spec.install.spec.deployments[$DEPLOYMENT_INDEX].spec.template.spec.volumes[].name" $TMP_DIR/$CSV-patched.yaml | grep -x "$SPC_NAME" || echo "")
    
    if [ -n "$EXISTING_VOLUME" ]; then
      info "Volume $SPC_NAME already exists, skipping"
      continue
    fi
    
    VOLUME_INDEX=$CURRENT_VOLUMES
    #info "Adding volume for SecretProviderClass: $SPC_NAME at index $VOLUME_INDEX"
    
    # Add volume with simple yq write commands
    ${YQ_CMD} -i ".spec.install.spec.deployments[$DEPLOYMENT_INDEX].spec.template.spec.volumes[$VOLUME_INDEX].name = \"$SPC_NAME\"" $TMP_DIR/$CSV-patched.yaml
    ${YQ_CMD} -i ".spec.install.spec.deployments[$DEPLOYMENT_INDEX].spec.template.spec.volumes[$VOLUME_INDEX].csi.driver = \"secrets-store.csi.k8s.io\"" $TMP_DIR/$CSV-patched.yaml
    ${YQ_CMD} -i ".spec.install.spec.deployments[$DEPLOYMENT_INDEX].spec.template.spec.volumes[$VOLUME_INDEX].csi.readOnly = true" $TMP_DIR/$CSV-patched.yaml
    ${YQ_CMD} -i ".spec.install.spec.deployments[$DEPLOYMENT_INDEX].spec.template.spec.volumes[$VOLUME_INDEX].csi.volumeAttributes.secretProviderClass = \"$SPC_NAME\"" $TMP_DIR/$CSV-patched.yaml
    
    JSON_PATCH_OPS+=("{\"op\":\"add\",\"path\":\"/spec/install/spec/deployments/$DEPLOYMENT_INDEX/spec/template/spec/volumes/-\",\"value\":{\"name\":\"$SPC_NAME\",\"csi\":{\"driver\":\"secrets-store.csi.k8s.io\",\"readOnly\":true,\"volumeAttributes\":{\"secretProviderClass\":\"$SPC_NAME\"}}}}")  
    CURRENT_VOLUMES=$((CURRENT_VOLUMES + 1))
  done
  
  # echo "Added volumes to CSV (skipped duplicates)"
  
  # Add volume mounts for each SecretProviderClass
  add_volume_mounts "$DEPLOYMENT_INDEX"
  
  info "CSV volume patching completed. Updated file: $TMP_DIR/$CSV-patched.yaml"
}

function add_volume_mounts() {
  local deployment_index=$1
  
  # echo "Adding volume mounts for SecretProviderClasses"
  
  # Get current number of volume mounts in the first container
  CURRENT_MOUNTS=$(${YQ_CMD} ".spec.install.spec.deployments[$deployment_index].spec.template.spec.containers[0].volumeMounts" $TMP_DIR/$CSV-patched.yaml | grep -c "name:" || echo "0")
  # echo "Current volume mounts count: $CURRENT_MOUNTS"
  
  # Parse volume mounts content file to extract mount information efficiently
  # echo "Adding volume mounts directly from SECRET_PROVIDER_CLASS_NAMES array with custom mount paths"
  
  # Get all existing mount paths once for efficiency
  EXISTING_MOUNT_PATHS=$(${YQ_CMD} ".spec.install.spec.deployments[$deployment_index].spec.template.spec.containers[0].volumeMounts[].mountPath" $TMP_DIR/$CSV-patched.yaml || echo "")
  
  # Add volume mounts directly from the SECRET_PROVIDER_CLASS_NAMES array
  for i in "${!SECRET_PROVIDER_CLASS_NAMES[@]}"; do
    SPC_NAME="${SECRET_PROVIDER_CLASS_NAMES[$i]}"
    MOUNT_PATH="${SECRET_PROVIDER_CLASS_MOUNT_PATHS[$i]}"
    
    # Check if volume mount already exists by mount path
    EXISTING_MOUNT=$(echo "$EXISTING_MOUNT_PATHS" | grep -x "$MOUNT_PATH" || echo "")
    
    if [ -n "$EXISTING_MOUNT" ]; then
      # echo "Volume mount with path $MOUNT_PATH already exists, skipping"
      continue
    fi
    
    MOUNT_INDEX=$CURRENT_MOUNTS
    # echo "Adding volume mount for $SPC_NAME at mount index $MOUNT_INDEX with path $MOUNT_PATH"
    
    # Add volume mount with simple yq write commands
    ${YQ_CMD} -i ".spec.install.spec.deployments[$deployment_index].spec.template.spec.containers[0].volumeMounts[$MOUNT_INDEX].name = \"$SPC_NAME\"" $TMP_DIR/$CSV-patched.yaml
    ${YQ_CMD} -i ".spec.install.spec.deployments[$deployment_index].spec.template.spec.containers[0].volumeMounts[$MOUNT_INDEX].mountPath = \"$MOUNT_PATH\"" $TMP_DIR/$CSV-patched.yaml
    ${YQ_CMD} -i ".spec.install.spec.deployments[$deployment_index].spec.template.spec.containers[0].volumeMounts[$MOUNT_INDEX].readOnly = true" $TMP_DIR/$CSV-patched.yaml
    
    JSON_PATCH_OPS+=("{\"op\":\"add\",\"path\":\"/spec/install/spec/deployments/$deployment_index/spec/template/spec/containers/0/volumeMounts/-\",\"value\":{\"name\":\"$SPC_NAME\",\"mountPath\":\"$MOUNT_PATH\",\"readOnly\":true}}")  
    CURRENT_MOUNTS=$((CURRENT_MOUNTS + 1))
  done
  
  # echo "Added volume mounts to CSV (skipped duplicates)"
}

function unpatch_volumes_from_csv(){
  echo "Removing SecretProviderClass volumes and mounts from CSV..."
  
  # Find the deployment index - use index 0 if CSV_DEPLOYMENT_NAME is not provided
  if [ -z "$CSV_DEPLOYMENT_NAME" ]; then
    DEPLOYMENT_INDEX=0
    DEPLOYMENT_NAME=$(${YQ_CMD} ".spec.install.spec.deployments[0].name" $TMP_DIR/$CSV-patched.yaml)
    echo "CSV_DEPLOYMENT_NAME not provided, using first deployment (index 0): $DEPLOYMENT_NAME"
  else
    DEPLOYMENT_INDEX=$(${YQ_CMD} '.spec.install.spec.deployments[].name // ""' $TMP_DIR/$CSV-patched.yaml  | grep -n "$CSV_DEPLOYMENT_NAME" | cut -d: -f1)
    if [ -z "$DEPLOYMENT_INDEX" ]; then
      error "Deployment $CSV_DEPLOYMENT_NAME not found in CSV. Available deployments:"
      ${YQ_CMD} '.spec.install.spec.deployments[].name' "$TMP_DIR/$CSV-patched.yaml"
      exit 1
    fi
    DEPLOYMENT_INDEX=$((DEPLOYMENT_INDEX - 1))  # Convert to 0-based index
    DEPLOYMENT_NAME="$CSV_DEPLOYMENT_NAME"
    echo "Found $CSV_DEPLOYMENT_NAME deployment at index: $DEPLOYMENT_INDEX"
  fi
  
  # Remove volumes for each SecretProviderClass
  for SPC_NAME in "${SECRET_PROVIDER_CLASS_NAMES[@]}"; do
    echo "Removing volume: $SPC_NAME"
    
    # Get all volume names and find the index of the one to remove
    VOLUME_NAMES=$(${YQ_CMD} ".spec.install.spec.deployments[$DEPLOYMENT_INDEX].spec.template.spec.volumes[].name" $TMP_DIR/$CSV-patched.yaml)
    VOLUME_INDEX=-1
    INDEX=0
    
    while read -r volume_name; do
      if [[ "$volume_name" == "$SPC_NAME" ]]; then
        VOLUME_INDEX=$INDEX
        break
      fi
      INDEX=$((INDEX + 1))
    done <<< "$VOLUME_NAMES"
    
    if [[ $VOLUME_INDEX -ge 0 ]]; then
      echo "Removing volume $SPC_NAME at index $VOLUME_INDEX"
      ${YQ_CMD} -i "del(.spec.install.spec.deployments[\"${DEPLOYMENT_INDEX}\"].spec.template.spec.volumes[\"${VOLUME_INDEX}\"])" "$TMP_DIR/$CSV-patched.yaml"
    else
      echo "Volume $SPC_NAME not found, skipping"
    fi
  done
  
  # Remove volume mounts for each SecretProviderClass
  for SPC_NAME in "${SECRET_PROVIDER_CLASS_NAMES[@]}"; do
    echo "Removing volume mount: $SPC_NAME"
    
    # Get all volume mount names and find the index of the one to remove
    MOUNT_NAMES=$(${YQ_CMD} ".spec.install.spec.deployments[$DEPLOYMENT_INDEX].spec.template.spec.containers[0].volumeMounts[].name" $TMP_DIR/$CSV-patched.yaml)
    MOUNT_INDEX=-1
    INDEX=0
    
    while read -r mount_name; do
      if [[ "$mount_name" == "$SPC_NAME" ]]; then
        MOUNT_INDEX=$INDEX
        break
      fi
      INDEX=$((INDEX + 1))
    done <<< "$MOUNT_NAMES"
    
    if [[ $MOUNT_INDEX -ge 0 ]]; then
      echo "Removing volume mount $SPC_NAME at index $MOUNT_INDEX"
      ${YQ_CMD} -i "del(.spec.install.spec.deployments[\"${DEPLOYMENT_INDEX}\"].spec.template.spec.containers[0].volumeMounts[\"${MOUNT_INDEX}\"])" "$TMP_DIR/$CSV-patched.yaml"
    else
      echo "Volume mount $SPC_NAME not found, skipping"
    fi
  done
  
  echo "CSV volume unpatching completed. Updated file: $TMP_DIR/$CSV-patched.yaml"
}

# Validate that every CSI vault volume and volumeMount present in <patched_yaml>
# also exists in the live cluster CSV <csv_name> in <namespace>.
# Usage: validate_csv_vault_mounts <patched_yaml> <csv_name> <namespace>
# Returns 0 if all expected mounts are present, 1 if any are missing.
function validate_csv_vault_mounts() {
  local patched_yaml="$1"
  local csv_name="$2"
  local namespace="$3"

  if [[ -z "$patched_yaml" || ! -f "$patched_yaml" ]]; then
    warning "validate_csv_vault_mounts: patched yaml '$patched_yaml' not found, skipping validation."
    return 0
  fi

  info "Validating vault CSI mounts for CSV '$csv_name' in namespace '$namespace'..."

  # Fetch live CSV from cluster into a temp file
  local live_csv_file
  live_csv_file=$(mktemp)
  ${CLI_CMD} get csv "$csv_name" -n "$namespace" -o yaml > "$live_csv_file" 2>&1
  if [[ $? -ne 0 || ! -s "$live_csv_file" ]]; then
    warning "Could not retrieve live CSV '$csv_name' from namespace '$namespace', skipping validation."
    rm -f "$live_csv_file"
    return 0
  fi

  local deploy_count
  deploy_count=$(${YQ_CMD} '.spec.install.spec.deployments | length' "$patched_yaml" 2>/dev/null)
  deploy_count=${deploy_count:-0}

  local missing=0

  for ((d=0; d<deploy_count; d++)); do
    local deploy_name
    deploy_name=$(${YQ_CMD} ".spec.install.spec.deployments[$d].name" "$patched_yaml" 2>/dev/null)

    # Find matching deployment index in the live CSV
    local live_idx
    live_idx=$(${YQ_CMD} '.spec.install.spec.deployments[].name' "$live_csv_file" \
        | grep -n "^${deploy_name}$" | cut -d: -f1)
    if [[ -z "$live_idx" ]]; then
      warning "  [SKIP] Deployment '$deploy_name' not found in live CSV, skipping."
      continue
    fi
    live_idx=$((live_idx - 1))

    # Check each CSI volume in the patched file
    local expected_vols
    expected_vols=$(${YQ_CMD} ".spec.install.spec.deployments[$d].spec.template.spec.volumes[] | select(.csi.driver == \"secrets-store.csi.k8s.io\") | .name" "$patched_yaml" 2>/dev/null)

    while IFS= read -r vol_name; do
      [[ -z "$vol_name" ]] && continue
      local found_vol
      found_vol=$(${YQ_CMD} ".spec.install.spec.deployments[$live_idx].spec.template.spec.volumes[] | select(.name == \"$vol_name\" and .csi.driver == \"secrets-store.csi.k8s.io\") | .name" "$live_csv_file" 2>/dev/null)
      if [[ -n "$found_vol" ]]; then
        success "  [OK]  volume '$vol_name' present in live CSV (deployment: $deploy_name)"
      else
        warning "  [MISSING] volume '$vol_name' NOT found in live CSV (deployment: $deploy_name)"
        missing=$((missing + 1))
      fi
    done <<< "$expected_vols"

    # Check each CSI volumeMount in the patched file (only those whose volume is CSI)
    while IFS= read -r vol_name; do
      [[ -z "$vol_name" ]] && continue
      local found_mount
      found_mount=$(${YQ_CMD} ".spec.install.spec.deployments[$live_idx].spec.template.spec.containers[0].volumeMounts[] | select(.name == \"$vol_name\") | .name" "$live_csv_file" 2>/dev/null)
      if [[ -n "$found_mount" ]]; then
        success "  [OK]  volumeMount '$vol_name' present in live CSV (deployment: $deploy_name)"
      else
        warning "  [MISSING] volumeMount '$vol_name' NOT found in live CSV (deployment: $deploy_name)"
        missing=$((missing + 1))
      fi
    done <<< "$expected_vols"

  done

  rm -f "$live_csv_file"

  if [[ $missing -eq 0 ]]; then
    success "Validation passed: all expected vault CSI mounts are present in live CSV '$csv_name'"
    return 0
  else
    warning "Validation found $missing missing item(s) in live CSV '$csv_name'"
    return 1
  fi
}

function apply_strategic_patch() {
  info "Applying strategic patch to CSV: $CSV"

  #Scale down the operator deployment to avoid conflicts during patch
  scale_deployment "$DEPLOYMENT_NAME" 0 "$OPERATOR_NAMESPACE"

  # For CSV resources, use kubectl apply with --force-conflicts to handle large annotations
  info "Applying patched CSV with --force-conflicts"
  strategic_output=$(${CLI_CMD} apply -f "$TMP_DIR/$CSV-patched.yaml" --force-conflicts=true --server-side=true 2>&1)
  strategic_exit_code=$?
  
  if [ $strategic_exit_code -eq 0 ]; then
    success "Strategic patch applied successfully to CSV: $CSV"
    scale_deployment "$DEPLOYMENT_NAME" 1 "$OPERATOR_NAMESPACE"
    validate_csv_vault_mounts "$TMP_DIR/$CSV-patched.yaml" "$CSV" "$OPERATOR_NAMESPACE"
    return 0
  fi
  
  # Strategic patch failed, check if it's due to annotation size limit
  if echo "$strategic_output" | grep -q "Too long: must have at most 262144 bytes"; then
    warning "Strategic patch failed due to annotation size limit. Using replace as fallback..."
    echo "$strategic_output"
    
    info "Using ${CLI_CMD} replace to avoid annotation size issues..."
    replace_output=$(${CLI_CMD} replace -f "$TMP_DIR/$CSV-patched.yaml" 2>&1)
    replace_exit_code=$?
    
    if [ $replace_exit_code -eq 0 ]; then
      success "CSV replaced successfully: $CSV"
      scale_deployment "$DEPLOYMENT_NAME" 1 "$OPERATOR_NAMESPACE"
      return 0
    else
      error "Replace failed for CSV: $CSV"
      echo "$replace_output"
      scale_deployment "$DEPLOYMENT_NAME" 1 "$OPERATOR_NAMESPACE"
      exit 1
    fi
  fi

  # Server-side apply failed for a reason other than annotation size
  error "Failed to apply CSV: $CSV"
  echo "$strategic_output"
  scale_deployment "$DEPLOYMENT_NAME" 1 "$OPERATOR_NAMESPACE"
  exit 1
}

function scale_deployment() {
  local deployment_name=$1
  local replicas=$2
  local namespace=$3
  
  if [ -z "$deployment_name" ] || [ -z "$replicas" ] || [ -z "$namespace" ]; then
    error "scale_deployment requires: deployment_name, replicas, namespace"
    return 1
  fi
  
  info "Scaling deployment '$deployment_name' to $replicas replicas in namespace '$namespace'"
  
  # Scale the deployment
  ${CLI_CMD} scale deployment "$deployment_name" --replicas="$replicas" -n "$namespace" >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    success "Deployment '$deployment_name' scaled to $replicas replicas"
    
    #call check pod status when scaling up
    if [ "$replicas" -gt 0 ]; then
        check_pods_running_status "$OPERATOR_NAMESPACE" "$CSV" "$DEPLOYMENT_NAME" 180
    fi

    return 0
  else
    error "Failed to scale deployment '$deployment_name' in namespace '$namespace'"
    return 1
  fi
}

# Migrate CSI vault volumes and volumeMounts to the current CSVs in the cluster by reading
# SPC annotations (cp4ba.ibm.com/owned-by, cp4ba.ibm.com/secret-store-type) from the cluster.
# Usage: upgrade_csv_between_versions   (no parameters)
function upgrade_csv_between_versions() {
    info "=== Upgrade mode: building CSV-to-SPC mapping from live cluster SPCs ==="

    local spc_list
    spc_list=$(${CLI_CMD} get secretproviderclass -n "$OPERATOR_NAMESPACE" --no-headers \
        -o custom-columns="NAME:.metadata.name" 2>/dev/null)
    if [[ -z "$spc_list" ]]; then
        warning "No SecretProviderClass resources found in namespace '$OPERATOR_NAMESPACE'"
        return 1
    fi

    declare -A _op_spc_map
    declare -A _op_mount_map

    while IFS= read -r spc_name; do
        [[ -z "$spc_name" ]] && continue

        local owned_by store_type
        owned_by=$(${CLI_CMD} get secretproviderclass "$spc_name" -n "$OPERATOR_NAMESPACE" \
            -o jsonpath='{.metadata.annotations.cp4ba\.ibm\.com/owned-by}' 2>/dev/null)
        store_type=$(${CLI_CMD} get secretproviderclass "$spc_name" -n "$OPERATOR_NAMESPACE" \
            -o jsonpath='{.metadata.annotations.cp4ba\.ibm\.com/secret-store-type}' 2>/dev/null)

        if [[ -z "$owned_by" || "$owned_by" == "null" ]]; then
            warning "SPC '$spc_name' missing 'cp4ba.ibm.com/owned-by' annotation — skipping."
            continue
        fi

        local mount_path
        if [[ "$store_type" == "tls" ]]; then
            mount_path="/tmp/certificates/${spc_name}"
        elif [[ "$store_type" == "secrets" ]]; then
            mount_path="/tmp/secrets/${spc_name}"
        else
            warning "SPC '$spc_name' missing/unknown 'cp4ba.ibm.com/secret-store-type' ('$store_type'), defaulting to /tmp/secrets/"
            mount_path="/tmp/secrets/${spc_name}"
        fi
        # Extract operator names from owned_by (comma-separated), trim whitespace, and build mapping.  End results:
        ## _op_spc_map[ibm-cp4a-operator]="root-ca external-tls-cert trusted-cert ..." 
        ## _op_spc_map[ibm-content-operator]="root-ca trusted-cert cp4ba-db-ssl..."
        ## _op_mount_map[ibm-cp4a-operator]="/tmp/certificates/root-ca /tmp/certificates/external-tls-cert /tmp/secrets/trusted-cert ..." 
        ## _op_mount_map[ibm-content-operator]="/tmp/certificates/root-ca /tmp/secrets/trusted-cert /tmp/secrets/cp4ba-db-ssl..."
        IFS=',' read -ra owners <<< "$owned_by"
        for owner in "${owners[@]}"; do
            owner=$(echo "$owner" | xargs)
            [[ -z "$owner" ]] && continue

            local excluded=false
            for excl_op in "${VAULT_EXCLUDE_PATCH_LIST_OF_CSV[@]}"; do
                excl_op="${excl_op%,}"
                excl_op=$(echo "$excl_op" | xargs)
                if [[ "$owner" == "$excl_op" ]]; then
                    excluded=true
                    info "Skipping '$spc_name' for operator '$owner' (in VAULT_EXCLUDE_PATCH_LIST_OF_CSV)"
                    break
                fi
            done
            [[ "$excluded" == true ]] && continue

            if [[ -n "${_op_spc_map[$owner]+_}" ]]; then
                _op_spc_map[$owner]+=" $spc_name"
                _op_mount_map[$owner]+=" $mount_path"
            else
                _op_spc_map[$owner]="$spc_name"
                _op_mount_map[$owner]="$mount_path"
            fi
        done
    done <<< "$spc_list"

    if [[ ${#_op_spc_map[@]} -eq 0 ]]; then
        warning "No operators found to patch after applying exclusion list."
        return 1
    fi

    info "=== CSV-to-SPC mapping (operators to patch) ==="
    for op in "${!_op_spc_map[@]}"; do
        info "  $op: ${_op_spc_map[$op]}"
    done

    # Patch each CSV based on the mapping built from the live cluster.  This ensures we are patching the correct CSV names and only those that have SPCs referencing them, rather than relying on hardcoded CSV names or assumptions about which operators use which SPCs.  
    #It also allows us to handle multiple operators and multiple SPCs per operator in a dynamic way based on the actual cluster state.
    local found_any=0
    for operator in "${!_op_spc_map[@]}"; do
        local csv_name="${operator}.${CP4BA_CSV_VERSION}"
        info "=== Patching CSV: $csv_name ==="

        local csv_exists
        csv_exists=$(${CLI_CMD} get csv "$csv_name" -n "$OPERATOR_NAMESPACE" \
            --ignore-not-found --no-headers 2>/dev/null)
        if [[ -z "$csv_exists" ]]; then
            warning "CSV '$csv_name' not found in namespace '$OPERATOR_NAMESPACE', skipping."
            continue
        fi
        found_any=1

        mkdir -p "$TMP_DIR" >/dev/null 2>&1
        local csv_file="$TMP_DIR/${csv_name}.yaml"
        local csv_patched="$TMP_DIR/${csv_name}-patched.yaml"

        ${CLI_CMD} get csv "$csv_name" -n "$OPERATOR_NAMESPACE" -o yaml > "$csv_file" 2>&1
        if [[ $? -ne 0 || ! -s "$csv_file" ]]; then
            error "Failed to retrieve CSV '$csv_name', skipping."
            continue
        fi
        cp "$csv_file" "$csv_patched"

        CSV="$csv_name"
        csv_base_name="$operator"
        SECRET_PROVIDER_CLASS_NAMES=()
        SECRET_PROVIDER_CLASS_MOUNT_PATHS=()
        JSON_PATCH_OPS=()
        CSV_DEPLOYMENT_NAME=""

        IFS=' ' read -ra _spc_arr <<< "${_op_spc_map[$operator]}"
        IFS=' ' read -ra _mnt_arr <<< "${_op_mount_map[$operator]}"
        for i in "${!_spc_arr[@]}"; do
            SECRET_PROVIDER_CLASS_NAMES+=("${_spc_arr[$i]}")
            SECRET_PROVIDER_CLASS_MOUNT_PATHS+=("${_mnt_arr[$i]}")
        done

        patch_volume_to_csv

        if [[ ${#JSON_PATCH_OPS[@]} -eq 0 ]]; then
            info "All CSI volumes already present in '$csv_name', no changes needed."
            continue
        fi

        local patch_json
        patch_json="[$(IFS=,; echo "${JSON_PATCH_OPS[*]}")]"
        info "Patching '$csv_name' with ${#JSON_PATCH_OPS[@]} operation(s) via JSON patch..."
        local patch_out
        patch_out=$(${CLI_CMD} patch csv "$csv_name" -n "$OPERATOR_NAMESPACE" \
            --type=json -p "$patch_json" 2>&1)
        if [[ $? -ne 0 ]]; then
            error "Failed to patch CSV '$csv_name'"
            echo "$patch_out"
            continue
        fi
        success "CSV '$csv_name' patched. Patched file saved: $csv_patched"

        validate_csv_vault_mounts "$csv_patched" "$csv_name" "$OPERATOR_NAMESPACE"

        local deploy_count
        deploy_count=$(${YQ_CMD} '.spec.install.spec.deployments | length' "$csv_patched" 2>/dev/null)
        deploy_count=${deploy_count:-0}
        for ((rd=0; rd<deploy_count; rd++)); do
            local dep_name
            dep_name=$(${YQ_CMD} ".spec.install.spec.deployments[$rd].name" "$csv_patched" 2>/dev/null)
            [[ -z "$dep_name" ]] && continue
            info "Restarting deployment '$dep_name'..."
            ${CLI_CMD} rollout restart deployment/"$dep_name" -n "$OPERATOR_NAMESPACE" 2>/dev/null || true
            check_pods_running_status "$OPERATOR_NAMESPACE" "$dep_name" "$dep_name" 180
        done
        success "Vault CSI mounts applied to '$csv_name'"
    done

    [[ $found_any -eq 0 ]] && { warning "No matching CSVs were found to patch."; return 1; }
    success "Upgrade vault migration completed for all operators."
}

function check_pods_running_status() {
  local namespace=$1
  local csv_name=$2
  local deployment_name=$3
  local timeout=${4:-180}  # Default 3 minutes timeout
  
  info "Checking pod status for CSV: $csv_name, deployment: $deployment_name in namespace: $namespace"
  
  # Calculate max retries based on timeout (check every 15 seconds)
  local maxRetry=$((timeout / 15))
  
  for ((retry=0;retry<=maxRetry;retry++)); do
    # Get running pods with proper ready status and not being deleted
    local ready_pods
    ready_pods=$(${CLI_CMD} get pods -n "$namespace" -l "name=$deployment_name" \
      -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' \
      --no-headers 2>/dev/null | grep 'Running' | grep 'true' | grep '<none>' | wc -l)
    
    # If no pods found with name label, try alternative label selectors
    if [ "$ready_pods" -eq 0 ]; then
      ready_pods=$(${CLI_CMD} get pods -n "$namespace" -l "app=$deployment_name" \
        -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETED:.metadata.deletionTimestamp' \
        --no-headers 2>/dev/null | grep 'Running' | grep 'true' | grep '<none>' | wc -l)
    fi
    
    
    # Get total expected pods for comparison
    local total_pods
    total_pods=$(${CLI_CMD} get pods -n "$namespace" -l "name=$deployment_name" --no-headers 2>/dev/null | wc -l)
    if [ "$total_pods" -eq 0 ]; then
      total_pods=$(${CLI_CMD} get pods -n "$namespace" -l "app=$deployment_name" --no-headers 2>/dev/null | wc -l)
    fi

    
    # Check if all pods are ready or if we have any ready pods when total is unknown
    if [[ "$ready_pods" -gt 0 ]] && [[ "$total_pods" -gt 0 ]] && [[ "$ready_pods" -eq "$total_pods" ]]; then
      success "All $ready_pods pods for CSV deployment '$deployment_name' are running and ready in namespace: $namespace"
      return 0
    elif [[ "$ready_pods" -gt 0 ]] && [[ "$total_pods" -eq 0 ]]; then
      success "$ready_pods pods for CSV deployment '$deployment_name' are running and ready in namespace: $namespace"
      return 0
    fi
    
    
    # Check if this is the last retry
    if [[ $retry -eq $maxRetry ]]; then
      printf "\n"
      error "Timeout waiting for CSV deployment '$deployment_name' pods to be ready in namespace: $namespace"
      warning "Current pod status for deployment '$deployment_name':"
      ${CLI_CMD} get pods -n "$namespace" -l "name=$deployment_name" 2>/dev/null || \
      ${CLI_CMD} get pods -n "$namespace" -l "app=$deployment_name" 2>/dev/null || \
      return 1
    else
      info "Waiting for pods to be ready... ($ready_pods/$total_pods ready) - retry $((retry+1))/$((maxRetry+1))"
      sleep 15
      printf '%s' "..."
    fi
  done
}

#### Main
# Show help if no arguments are provided
if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi

parse_arguments "$@"

# Set default OPERATOR_NAMESPACE to TARGET_PROJECT_NAME if not provided
info "TARGET_PROJECT_NAME set to: $TARGET_PROJECT_NAME"
OPERATOR_NAMESPACE=${OPERATOR_NAMESPACE:-$TARGET_PROJECT_NAME}
info "OPERATOR_NAMESPACE set to: $OPERATOR_NAMESPACE"

## Global variables
TMP_DIR="${CUR_DIR}/.tmp/${TARGET_PROJECT_NAME}"
SECRET_PROVIDER_CLASS_DIR="${CUR_DIR}/cp4ba-prerequisites/project/${TARGET_PROJECT_NAME}/secret_template/vault"
# Initialize arrays for SecretProviderClass names and their corresponding mount paths
SECRET_PROVIDER_CLASS_NAMES=()
csv_base_name=""  # set by retrieve_secret_provider_classes; used by create_volumes_structure (generate summary)
SECRET_PROVIDER_CLASS_MOUNT_PATHS=()
## End of global variables
# 
save_log_wrapper


echo "TMP_DIR: $TMP_DIR"
echo "SECRET_PROVIDER_CLASS_DIR: $SECRET_PROVIDER_CLASS_DIR"
echo "TARGET_PROJECT_NAME (for SecretProviderClass files): $TARGET_PROJECT_NAME"
echo "OPERATOR_NAMESPACE (for CSV operations): $OPERATOR_NAMESPACE"



if [[ $RUNTIME_MODE == "patch" || $RUNTIME_MODE == "strategic" || $RUNTIME_MODE == "unpatch" || $RUNTIME_MODE == "generate" ]]; then
  # Parse comma-separated CSV list; trim spaces around commas
  IFS=',' read -ra CSV_LIST <<< "$CSV"
  for csv_item in "${CSV_LIST[@]}"; do
    csv_item=$(echo "$csv_item" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    [[ -z "$csv_item" ]] && continue
    CSV="$csv_item"
    # Reset per-CSV state before each iteration
    SECRET_PROVIDER_CLASS_NAMES=()
    SECRET_PROVIDER_CLASS_MOUNT_PATHS=()
    csv_base_name=""
    info "=== Processing CSV: $CSV ==="
    retrieve_csv "$CSV" "$OPERATOR_NAMESPACE" || { continue; }
  done
elif [[ $RUNTIME_MODE == "upgrade" ]]; then
  upgrade_csv_between_versions
fi