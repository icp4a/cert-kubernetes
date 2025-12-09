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
function show_help() {
    echo -e "\nUsage: ./cp4a-storage-validation.sh -m <mode> -n <CP4BA_NAMESPACE>\n"
    echo "Modes:"
    echo "  storage_validation                    : Run only Storage Validation"
    echo "  performance_validation                : Run only Storage Performance Validation"
    echo "  storage_and_performance_validation    : Run Storage Validation and Storage Performance Validation"
    echo
    echo "Examples:"
    echo "  ./cp4a-storage-validation.sh -m storage_validation -n <CP4BA_NAMESPACE>"
    echo "  ./cp4a-storage-validation.sh -m performance_validation -n <CP4BA_NAMESPACE>"
    echo "  ./cp4a-storage-validation.sh -m storage_and_performance_validation -n <CP4BA_NAMESPACE>"
    echo
}


function check_prerequisites() {
  CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "${CUR_DIR}/helper/common.sh"
  echo
  echo "Next, checking prerequisites for Storage Validation/Storage Performance Validation. For details, refer to the topic 'Storage Validation and Storage Performance Validation': https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/${CP4BA_RELEASE_BASE}?topic=pycc-recommended-preparing-databases-secrets-your-chosen-capabilities-by-running-script"
  
  echo -e "${WHITE}${BOLD}Checking prerequisites...${RESET}"
  echo
    all_ok=true
    if command -v python &>/dev/null; then
        py_version=$(python -c 'import sys; print("{}.{}".format(sys.version_info[0], sys.version_info[1]))')
    elif command -v python3 &>/dev/null; then
        py_version=$(python3 -c 'import sys; print("{}.{}".format(sys.version_info[0], sys.version_info[1]))')
    else
        py_version="0.0"
    fi

    py_major=${py_version%%.*}
    py_minor=${py_version##*.}

    if [[ "$py_major" -lt 3 || ( "$py_major" -eq 3 && "$py_minor" -lt 6 ) ]]; then
        echo -e "${RED}Python 3.6 or later is not installed.${RESET}"
        echo -e "${WHITE}${BOLD}Please install Python 3.6 or later.${RESET}"
        all_ok=false
    else
        echo -e "${WHITE}${BOLD}Python version: $py_version ------ OK${RESET} "
    fi
    echo

    # Check pip version
    if command -v pip &>/dev/null; then
        pip_version=$(pip --version | awk '{print $2}')
    elif command -v pip3 &>/dev/null; then
        pip_version=$(pip3 --version | awk '{print $2}')
    else
        pip_version="0.0"
    fi

    pip_major=$(echo "$pip_version" | cut -d. -f1)
    pip_minor=$(echo "$pip_version" | cut -d. -f2)

    if [[ "$pip_major" -lt 21 || ( "$pip_major" -eq 21 && "$pip_minor" -lt 1 ) ]]; then
        echo -e "${RED}pip 21.1.3 or later is not installed.${RESET}"
        echo -e "${WHITE}${BOLD}Please install pip 21.1.3 or later.${RESET}"
        all_ok=false
    else
        echo -e "${WHITE}${BOLD}pip version: $pip_version ------ OK${RESET}"
    fi
    echo

    # Check Ansible version
    if command -v ansible &>/dev/null; then
        ansible_version_line=$(ansible --version | head -n1)
        ansible_version=$(echo "$ansible_version_line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        ansible_major=$(echo "$ansible_version" | cut -d. -f1)
        ansible_minor=$(echo "$ansible_version" | cut -d. -f2)

        # Compare ansible version
        if (( ansible_major < 2 || ( ansible_major == 2 && ansible_minor < 10 ) )); then
            echo -e "${RED}Ansible 2.10.5 or later is required (found $ansible_version).${RESET}"
            echo -e "${WHITE}${BOLD}Please install Ansible 2.10.5 or later.${RESET}"
            all_ok=false
        else
            echo -e "${WHITE}${BOLD}Ansible version: $ansible_version ------ OK${RESET}"
        fi
    else
          echo -e "${RED}Ansible is not installed.${RESET}"
          echo -e "${WHITE}${BOLD}Please install Ansible 2.10.5 or later.${RESET}"
          all_ok=false
    fi
    echo

    # Check openshift Python package
    if ! python -c "import openshift" &>/dev/null 2>&1; then
        echo -e "${RED}Python package 'openshift' is not installed.${RESET}"
        echo -e "${WHITE}${BOLD}Install it using:${RESET}"
        echo -e "${WHITE}${BOLD}pip install openshift${RESET}"
        all_ok=false
    else
        echo -e "${WHITE}${BOLD}Python package 'openshift' is installed ------ OK${RESET}"
    fi
    echo

    # Check Ansible collections
    for coll in operator_sdk.util kubernetes.core; do
        if ! ansible-galaxy collection list "$coll" &>/dev/null; then
            echo -e "${RED}Ansible collection '$coll' is not installed.${RESET}"
            echo -e "${WHITE}${BOLD}Install it using:${RESET}"
            echo -e "${WHITE}${BOLD}ansible-galaxy collection install $coll${RESET}"
            all_ok=false
        else
            echo -e "${WHITE}${BOLD}Ansible collection '$coll' is installed ------ OK${RESET}"
        fi
        echo
    done

    # Check OpenShift Client
    if command -v "${CLI_CMD}" &>/dev/null; then
        oc_version=$(${CLI_CMD} version --client | grep "Client Version" | awk '{print $3}' | sed 's/v//')
        major=$(echo "$oc_version" | cut -d. -f1)
        minor=$(echo "$oc_version" | cut -d. -f2)

        if (( major < 4 )) || { (( major == 4 )) && (( minor < 6 )); }; then
            echo -e "OpenShift Client version $oc_version is not supported for storage and performance tests."
            echo -e "Please install OpenShift Client 4.6 or later."
            all_ok=false
        else
            echo -e "${WHITE}${BOLD}OpenShift Client version $oc_version ------ OK${RESET}"
        fi
    else
        echo -e "OpenShift Client is not installed."
        echo -e "Please install OpenShift Client 4.6 or later."
        all_ok=false
    fi
    echo
    # ----------------- Final summary -----------------
    if [ "$all_ok" != true ]; then
        echo
        echo -e "${WHITE}${BOLD}Please install all required prerequisites and then run the following command:${RESET}"
        echo -e "./cp4a-storage-validation.sh -m storage_and_performance_validation -n ${TARGET_PROJECT_NAME}\n"
        exit 1
    else
        echo -e "${WHITE}${BOLD}All prerequisites are satisfied.${RESET}"
    fi
  }

function prompt_user_for_validation() {
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    RED='\033[0;31m'
    RESET='\033[0m'
    echo
    INFO "STORAGE VALIDATION AND STORAGE PERFORMANCE VALIDATION"
    # Prompt user about running validation
    info "Next step is to perform Storage Validation and Storage Performance Validation. This step will validate fast file storage (RWX) and block storage (RWO)."
    echo

    echo "Validation might take:"
    echo " - Storage Validation               (might take up to 25 minutes)"
    echo " - Storage Performance Validation   (might take up to 1 hour)"
    echo
    echo -e "${WHITE}${BOLD}Note: These tests only verify the basic readiness of your storage and are intended as an initial pre-check before deploying any actual Cloud Pak workloads in the environment.${RESET}"
    echo

    read -p "Run Storage Validation? (yes/no) [default: no]: " run_storage
    run_storage=${run_storage:-no}
    run_storage=$(echo "$run_storage" | tr '[:upper:]' '[:lower:]')

    read -p "Run Storage Performance Validation? (yes/no) [default: no]: " run_perf
    run_perf=${run_perf:-no}
    run_perf=$(echo "$run_perf" | tr '[:upper:]' '[:lower:]')
}


function cleanup_storage_resources() {
    CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "${CUR_DIR}/helper/common.sh"
    local ns="$1"

    echo -e "\n${YELLOW}${BOLD}Next step: Cleaning up resources created for storage validation${RESET}"
    echo -e "${YELLOW}Note: This will remove specific resources created for Storage Validation in the namespace '$ns'.${RESET}"
    read -p "Type 'yes' or 'y' to proceed, anything else to cancel: " confirm

    if [[ "$confirm" =~ ^([yY]|[yY][eE][sS])$ ]]; then
        echo -e "\n${WHITE}${BOLD}Cleaning up Storage Validation resources in namespace: $ns${RESET}"

        ${CLI_CMD} get jobs -n "$ns" --no-headers | awk '/^readiness-|^sysbench-/{print $1}' | \
            xargs -r ${CLI_CMD} delete job -n "$ns" --ignore-not-found

        for cm in consumer-cm consumer-nocheck-cm producer-cm; do
            ${CLI_CMD} delete cm "$cm" -n "$ns" --ignore-not-found
        done

        ${CLI_CMD} get pvc -n "$ns" --no-headers | awk '/readiness-|sysbench-/{print $1}' | \
            xargs -r ${CLI_CMD} delete pvc -n "$ns" --ignore-not-found

        ${CLI_CMD} delete scc zz-fsgroup-scc --ignore-not-found

        success "Cleanup completed successfully"
    else
        echo -e "Cleanup skipped."
    fi
}


# Update params.yml only if storage selected
function run_storage_validation() {
          CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
          source "${CUR_DIR}/helper/common.sh"
          local STORAGE_NS="$1"
          PARAMS_FILE="$STORAGE_DIR/k8s-storage-tests/params.yml"
          OCP_URL=$(${CLI_CMD} whoami --show-server)
          OCP_USER=$(${CLI_CMD} whoami)
          OCP_TOKEN=$(${CLI_CMD} whoami -t)

          tmp_storage_classname=$(prop_user_profile_property_file CP4BA.FAST_FILE_STORAGE_CLASSNAME)
          tmp_storage_classname_block=$(prop_user_profile_property_file CP4BA.BLOCK_STORAGE_CLASS_NAME)
        
          $SED_COMMAND "s|^ocp_url:.*|ocp_url: $OCP_URL|" "$PARAMS_FILE"
          $SED_COMMAND "s|^ocp_username:.*|ocp_username: $OCP_USER|" "$PARAMS_FILE"
          $SED_COMMAND 's|^ocp_password:.*|ocp_password: ""|' "$PARAMS_FILE"
          $SED_COMMAND "s|^ocp_token:.*|ocp_token: $OCP_TOKEN|" "$PARAMS_FILE"
          $SED_COMMAND "s|^storageClass_ReadWriteOnce:.*|storageClass_ReadWriteOnce: $tmp_storage_classname_block|" "$PARAMS_FILE"
          $SED_COMMAND "s|^storageClass_ReadWriteMany:.*|storageClass_ReadWriteMany: $tmp_storage_classname|" "$PARAMS_FILE"
          $SED_COMMAND "s|^storage_validation_namespace:.*|storage_validation_namespace: $STORAGE_NS|" "$PARAMS_FILE"

         (
              SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
              LOGS_DIR="$SCRIPT_DIR/cp4a-script-logs/project/$STORAGE_NS"
              LOG_FILE="$LOGS_DIR/storage-validation-output.log"
              : > "$LOG_FILE"
                
              cd "$STORAGE_REPO_DIR" || exit 1

              echo -e "\n${WHITE}${BOLD}Running Storage Validation Playbook...${RESET}"
              export K8S_AUTH_VERIFY_SSL=no

              echo -e "\n${WHITE}${BOLD}Storage Validation Results:${RESET}"
              ansible-playbook main.yml --extra-vars "@params.yml" 2>&1 | tee "$LOG_FILE" | \
              while IFS= read -r line; do
                  if [[ $line =~ \"msg\":\ \"######################## ]]; then
                      clean_line=$(echo "$line" | sed -E 's/.*"msg": ?"//; s/"$//')
                      echo -ne "\r\033[K"
                      if [[ $clean_line =~ PASSED ]]; then
                          echo -e "\033[32m$clean_line\033[0m"  # green
                      elif [[ $clean_line =~ FAILED ]]; then
                          echo -e "\033[31m$clean_line\033[0m"  # red
                      else
                          echo "$clean_line"
                      fi
                  elif [[ $line =~ ^PLAY\ RECAP ]]; then
                      echo -ne "\r\033[K"
                      echo
                      echo -e "\033[32m$line\033[0m"
                      if read -r nextline; then
                          echo -e "\033[32m$nextline\033[0m"
                      fi
                      break
                  else
                      echo -ne "\rValidating Storage\033[5;37m...\033[0m   "
                      sleep 0.3
                  fi
              done

              info "For detailed logs, check: ${LOG_FILE}"

          )
          
          # Only clean up here if storage-perf is NOT selected
          if [[ "$run_perf" != "yes" && "$run_perf" != "y" && "$run_perf" != "YES" && "$run_perf" != "Y" ]]; then
              cleanup_storage_resources "$STORAGE_NS"
              exit 0 
          fi
}

function run_perf_validation() {
    local STORAGE_NS="$1"
    CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "${CUR_DIR}/helper/common.sh"
    PARAMS_FILE="$PERF_REPO_DIR/params-all-metrics.yml"
    OCP_URL=$(${CLI_CMD} whoami --show-server)
    OCP_USER=$(${CLI_CMD} whoami)
    OCP_TOKEN=$(${CLI_CMD} whoami -t)
    tmp_storage_classname=$(prop_user_profile_property_file CP4BA.FAST_FILE_STORAGE_CLASSNAME)
    tmp_storage_classname_block=$(prop_user_profile_property_file CP4BA.BLOCK_STORAGE_CLASS_NAME)


    $SED_COMMAND "s|^ocp_url:.*|ocp_url: $OCP_URL|" "$PARAMS_FILE"
    $SED_COMMAND "s|^ocp_username:.*|ocp_username: $OCP_USER|" "$PARAMS_FILE"
    $SED_COMMAND 's|^ocp_password:.*|ocp_password: ""|' "$PARAMS_FILE"
    $SED_COMMAND "s|^ocp_token:.*|ocp_token: $OCP_TOKEN|" "$PARAMS_FILE"
    $SED_COMMAND 's|^ocp_apikey:.*|ocp_apikey: ""|' "$PARAMS_FILE"
    $SED_COMMAND "s|^storageClass_ReadWriteOnce:.*|storageClass_ReadWriteOnce: $tmp_storage_classname_block|" "$PARAMS_FILE"
    $SED_COMMAND "s|^storageClass_ReadWriteMany:.*|storageClass_ReadWriteMany: $tmp_storage_classname|" "$PARAMS_FILE"
    $SED_COMMAND "s|^storage_perf_namespace:.*|storage_perf_namespace: $STORAGE_NS|" "$PARAMS_FILE"

    # ------------------ Image accessibility check ------------------
    IMAGE_TO_CHECK="quay.io/ibm-cp4d-public/xsysbench:1.1"
    TEMP_NS="image-check-$(date +%s)"
    
    echo -e "\n\033[1;37mRunning Storage Performance Validation:\033[0m"
    echo -e "Validating access to $IMAGE_TO_CHECK ..."
    ${CLI_CMD} create namespace "$TEMP_NS" >/dev/null 2>&1

    cat <<EOF | ${CLI_CMD} apply -n "$TEMP_NS" -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: image-pull-test
spec:
  containers:
  - name: test
    image: $IMAGE_TO_CHECK
    command: ["sleep", "60"]
  restartPolicy: Never
EOF
    sleep 10
    STATUS=$(${CLI_CMD} get pod image-pull-test -n "$TEMP_NS" -o jsonpath='{.status.phase}')
    ${CLI_CMD} delete namespace "$TEMP_NS" &>/dev/null

    if [[ "$STATUS" != "Running" && "$STATUS" != "Succeeded" ]]; then
        echo -e "\n\033[1;31mThe cluster does NOT have access to the required container image: $IMAGE_TO_CHECK\033[0m"
        echo -e "\n\033[1;37m[NOTE:] This storage performance test suite relies on a container image: $IMAGE_TO_CHECK\033[0m"
        echo -e "\033[1;37mThis image may not be directly accessible on an airgap cluster.\033[0m"
        echo -e "\033[1;37mTo resolve this, follow the steps below to download the image onto an intermediary host and then copy it to the airgap cluster's private registry:\033[0m"
        echo
        echo "Please refer to the topic 'Storage Validation and Storage Performance Validation': https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/${CP4BA_RELEASE_BASE}?topic=pycc-recommended-preparing-databases-secrets-your-chosen-capabilities-by-running-script"
       
        echo -e "\n\033[1;37m# On an intermediary host that can access the image\033[0m"
        echo "podman pull $IMAGE_TO_CHECK"
        echo "podman save -o xsysbench-1.1.tar $IMAGE_TO_CHECK"

        echo -e "\n\033[1;37m# Copy the tar file to your airgap cluster\033[0m"

        echo -e "\n\033[1;37m# On the airgap cluster\033[0m"
        echo "podman load -i xsysbench-1.1.tar"
        echo "podman tag \"$IMAGE_TO_CHECK\" <private-registry>/ibm-cp4d-public/xsysbench:1.1"
        echo "podman tag \"$IMAGE_TO_CHECK\" <private-registry>/ibm-cp4d-public/xsysbench:1.1-amd64"
        echo "podman login -u <username> -p <password> <private-registry> --tls-verify=false"
        echo "podman push <private-registry>/ibm-cp4d-public/xsysbench:1.1"
        echo "podman push <private-registry>/ibm-cp4d-public/xsysbench:1.1-amd64"

        echo -e "\n\033[1;37mModify imageurl: in $PERF_REPO_DIR/params-all-metrics.yml file to\033[0m"
        echo "imageurl: <private-registry>/ibm-cp4d-public/xsysbench:1.1"

        echo -e "\n\033[1;37mAfter completing the above Loading and Pushing image steps, run the storage performance validation using:\033[0m"

        # Prompt user to run the script
        echo -e "./cp4a-storage-validation.sh -m run_storage_performance -n $STORAGE_NS\n"
        return
     fi
        # -----------------------------------------------------------------
        echo -e "\n\033[1;37mImage is accessible from the cluster. Running the storage performance validation:\033[0m"
        run_storage_performance $STORAGE_NS

}

function run_storage_performance() {
    CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "${CUR_DIR}/helper/common.sh"
    local STORAGE_NS="$1"
    export K8S_AUTH_VERIFY_SSL=no

    cleanup_storage_performance_resources() {
        echo -e "\n\033[1mNext step: Cleaning up resources created for storage performance validation\033[0m"
        echo -e "Note: This will remove all resources created for storage performance validation in the namespace '$STORAGE_NS'.\033[0m"
        read -p "Type 'yes' or 'y' to proceed, anything else to cancel: " confirm

        if [[ "$confirm" =~ ^([yY]|[yY][eE][sS])$ ]]; then
            echo -e "\n\033[1;37mCleaning up storage performance validation resources in namespace: $STORAGE_NS\033[0m"

            ${CLI_CMD} get jobs -n "$STORAGE_NS" --no-headers | awk '/^readiness-|^sysbench-/{print $1}' | \
            xargs -r ${CLI_CMD} delete job -n "$STORAGE_NS" --ignore-not-found

        for cm in consumer-cm consumer-nocheck-cm producer-cm; do
            ${CLI_CMD} delete cm "$cm" -n "$STORAGE_NS" --ignore-not-found
        done

        ${CLI_CMD} get pvc -n "$STORAGE_NS" --no-headers | awk '/readiness-|sysbench-/{print $1}' | \
            xargs -r ${CLI_CMD} delete pvc -n "$STORAGE_NS" --ignore-not-found

        ${CLI_CMD} delete scc zz-fsgroup-scc --ignore-not-found

            success "Cleanup completed successfully"
        else
            echo -e "Cleanup skipped."
        fi
    }
   
    # ----------------- Run Ansible playbook and display filtered TASK output -----------------
    PERF_REPO_DIR="storage-validation/k8s-storage-perf"
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    LOGS_DIR="$SCRIPT_DIR/cp4a-script-logs/project/$STORAGE_NS"
    PERF_LOG_FILE="$LOGS_DIR/performance-validation-output.log"
    : > "$PERF_LOG_FILE"

    cd "$PERF_REPO_DIR"
    #Trap for any interruption
    trap 'cleanup_storage_performance_resources; exit 1' INT TERM HUP
    ansible-playbook main.yml --extra-vars "@params-all-metrics.yml" 2>&1 | tee "$PERF_LOG_FILE" | \
    while IFS= read -r line; do
        if [[ $line =~ TASK\ \[storage-perf-test\ : ]]; then
            echo -ne "\r\033[K"
            echo "$line"

        elif [[ $line =~ ^PLAY\ RECAP ]]; then
            # Clear line and print PLAY RECAP in bold white
            echo -ne "\r\033[K"
            echo
            echo -e "\033[1;37;1m$line\033[0m"
            if read -r nextline; then
                echo -e "\033[1;37;1m$nextline\033[0m"
            fi

        else
            echo -ne "\rValidating Storage Performance\033[5;37m...\033[0m   "
            sleep 0.3
        fi
    done
    # Remove trap after playbook finishes
    trap - INT TERM HUP

    # ----------------- Extract storage-perf.tar -----------------
    TAR_FILE="storage-perf.tar"
    CSV_FILE="result.csv"
    EXCEL_FILE="storage_performance_results.xls"

    if [[ -f "$TAR_FILE" ]]; then
        echo -e "\nExtracting $TAR_FILE..."
        tar -xf "$TAR_FILE"
        echo "Extraction completed."
    else
        echo "Error: $TAR_FILE not found."
        return 1
    fi

    # ----------------- Convert CSV to Excel XML -----------------
    if [[ -f "$CSV_FILE" ]]; then
        {
        echo '<?xml version="1.0"?>'
        echo '<?mso-application progid="Excel.Sheet"?>'
        echo '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"'
        echo ' xmlns:o="urn:schemas-microsoft-com:office:office"'
        echo ' xmlns:x="urn:schemas-microsoft-com:office:excel"'
        echo ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">'
        echo ' <Worksheet ss:Name="StoragePerf">'
        echo '  <Table>'
        while IFS= read -r line; do
            echo '   <Row>'
            IFS=',' read -ra cols <<< "$line"
            for col in "${cols[@]}"; do
                echo "    <Cell><Data ss:Type=\"String\">$col</Data></Cell>"
            done
            echo '   </Row>'
        done < "$CSV_FILE"
        echo '  </Table>'
        echo ' </Worksheet>'
        echo '</Workbook>'
        } > "$EXCEL_FILE"
        
        echo -e "You can view the storage performance test results in CSV file: $CSV_FILE"
        echo -e "\nYou can also view the same storage performance test results in Excel file: $EXCEL_FILE"
    else
        echo "Error: $CSV_FILE not found. Cannot convert to Excel."
    fi

    # ----------------- Final instructions -----------------
    info "For detailed logs, check: ${PERF_LOG_FILE}"

    # Run cleanup
    cleanup_storage_performance_resources
}


#when user selets no for both storgae and performnace - for command to run tests
function storage_and_performance_validation() {
  CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "${CUR_DIR}/helper/common.sh"
  STORAGE_DIR="storage-validation"
  STORAGE_REPO_DIR="${STORAGE_DIR}/k8s-storage-tests"
  PERF_REPO_DIR="${STORAGE_DIR}/k8s-storage-perf"

  local NAMESPACE="$1"
    if [[ -z "$NAMESPACE" ]]; then
        NAMESPACE=$(${CLI_CMD} project --short 2>/dev/null || echo "default")
    fi
    if ! ${CLI_CMD} get namespace "$NAMESPACE" &>/dev/null; then
        echo -e "\nError: Namespace '$NAMESPACE' does not exist in the cluster"
        return 1
    fi

    prompt_user_for_validation
    if [[ "$run_storage" != "yes" && "$run_storage" != "y" && "$run_perf" != "yes" && "$run_perf" != "y" ]]; then
    echo -e "\n${WHITE}${BOLD}You did not select any Storage Validation or storage performance validation to run.${RESET}"
    return
    fi
    check_prerequisites   
     if [[ "$run_storage" == "yes" || "$run_storage" == "y" ]]; then
        run_storage_validation "$NAMESPACE"
     fi

    # Run performance validation only if selected
    if [[ "$run_perf" == "yes" || "$run_perf" == "y" ]]; then
        run_perf_validation "$NAMESPACE"
    fi
}


function performance_validation(){
  CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "${CUR_DIR}/helper/common.sh"
  STORAGE_DIR="storage-validation"
  STORAGE_REPO_DIR="${STORAGE_DIR}/k8s-storage-tests"
  PERF_REPO_DIR="${STORAGE_DIR}/k8s-storage-perf"
  
  local NAMESPACE="$1"
  
    if [[ -z "$NAMESPACE" ]]; then
        return 1
    fi

    # Validate namespace exists in the cluster
    if ! ${CLI_CMD} get namespace "$NAMESPACE" &>/dev/null; then
        echo -e "\nError: Namespace '$NAMESPACE' does not exist in the cluster"
        return 1
    fi
    
  echo -e "\n${WHITE}${BOLD}Now Storage Performance Validation will be performed...${RESET}"
  check_prerequisites 
  run_perf_validation $NAMESPACE
}

function storage_validation(){
  local NAMESPACE="$1"
  CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "${CUR_DIR}/helper/common.sh"
  echo -e "\n${WHITE}${BOLD}Now Storage Validation will be performed...${RESET}"
  
  STORAGE_DIR="storage-validation"
  STORAGE_REPO_DIR="${STORAGE_DIR}/k8s-storage-tests"
  PERF_REPO_DIR="${STORAGE_DIR}/k8s-storage-perf"
  # Detect namespace if not provided
   
    if [[ -z "$NAMESPACE" ]]; then
        return 1
    fi
  check_prerequisites
  run_storage_validation $NAMESPACE
}

#<DBACLD-182755>Ability to run storage and performance testing suite
function storage_and_performance_validation_tests() {
  STORAGE_DIR="storage-validation"
  STORAGE_REPO_DIR="${STORAGE_DIR}/k8s-storage-tests"
  PERF_REPO_DIR="${STORAGE_DIR}/k8s-storage-perf"

  NAMESPACE="$1"
  
  # Fail immediately if no namespace is provided
  if [[ -z "$NAMESPACE" ]]; then
    return 1
  fi
 
  prompt_user_for_validation
   # ------------------ Case 1: Neither selected ------------------
   if [[ "$run_storage" != "yes" && "$run_storage" != "y" && "$run_perf" != "yes" && "$run_perf" != "y" ]]; then
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    RESET='\033[0m'
    echo -e "\n${WHITE}${BOLD}No validation option was selected.${RESET}"
    echo -e "${WHITE}${BOLD}If you want to run Storage Validation and Storage Performance Validation later, you can do so by executing below command:${RESET}"
    echo
    echo -e "./cp4a-storage-validation.sh -m storage_and_performance_validation -n ${TARGET_PROJECT_NAME}\n"
    return
  fi
    
       # ------------------ Case 2: Only storage ------------------
  if [[ ( "$run_storage" = "yes" || "$run_storage" = "y" ) && "$run_perf" != "yes" && "$run_perf" != "y" ]]; then
    echo -e "\n${WHITE}${BOLD}Now Storage validation will be performed...${RESET}"
    echo -e "${WHITE}${BOLD}If you want to run storage performance validation later, execute:${RESET}"
    echo -e "./cp4a-storage-validation.sh -m performance_validation -n ${TARGET_PROJECT_NAME}\n"
    check_prerequisites
    run_storage_validation $NAMESPACE
    return
  fi

  # ------------------ Case 3: Only performance ------------------
if [[ ( "$run_perf" = "yes" || "$run_perf" = "y" ) && "$run_storage" != "yes" && "$run_storage" != "y" ]]; then
    echo -e "\n${WHITE}${BOLD}Now Storage Performance Validation will be performed...${RESET}"
    echo -e "${WHITE}${BOLD}If you want to run Storage Validation later, execute:${RESET}"
    echo -e "./cp4a-storage-validation.sh -m storage_validation -n ${TARGET_PROJECT_NAME} \n"
    check_prerequisites
    run_perf_validation $NAMESPACE
    return
  fi
  # ------------------ Case 4: Both selected ------------------
   echo -e "\n${WHITE}${BOLD}Now Storage Validation and Storage Performance Validation will be performed...${RESET}"
    check_prerequisites
    run_storage_validation $NAMESPACE
    run_perf_validation $NAMESPACE
}
   

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    source "${CUR_DIR}/helper/common.sh"
    chmod +x "${BASH_SOURCE[0]}"

    # Show help if no arguments or help flag
    if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi

    # Parse -m for mode and -n for namespace
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m)
                MODE="$2"
                shift 2
                ;;
            -n)
                NAMESPACE="$2"
                shift 2
                ;;
            *)
                echo -e "\nError: Unknown option '$1'"
                show_help
                exit 1
                ;;
        esac
    done

    # Validate mode
    if ! declare -f "$MODE" >/dev/null; then
        echo -e "\nError: Unknown mode '$MODE'"
        show_help
        exit 1
    fi

    # Namespace required
    if [[ -z "$NAMESPACE" ]]; then
        echo -e "\nError: Missing required '-n <CP4BA_NAMESPACE>' argument."
        show_help
        exit 1
    fi
    
    # Validate namespace existence in cluster
    if ! ${CLI_CMD} get ns "$NAMESPACE" >/dev/null 2>&1; then
        echo -e "\nError: Namespace '$NAMESPACE' does not exist in the cluster."
        show_help
        exit 1
    fi

    # Execute the selected mode function
    "$MODE" "$NAMESPACE"
fi

