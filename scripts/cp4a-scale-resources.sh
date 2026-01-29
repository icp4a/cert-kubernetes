#!/bin/bash

# Script to scale up or down all components of an IBM Cloud Pak for Business Automation deployment
# in a specific OpenShift namespace

# Source the common.sh script to get access to helper functions and variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/helper/common.sh"

# Script version
VERSION="1.2.0"

# ConfigMap name for storing replica state
CONFIGMAP_NAME="cp4ba-scale-state"

# Define color codes for better readability
HEADER="${WHITE_TEXT}"
INFO="${BLUE_TEXT}"
SUCCESS="${GREEN_TEXT}"
WARNING="${YELLOW_TEXT}"
ERROR="${RED_TEXT}"
RESET="${RESET_TEXT}"

# Function to display help information
display_help() {
  printf "\n${HEADER}IBM Cloud Pak for Business Automation - Scaling Tool v${VERSION}${RESET}\n\n"
  printf "${INFO}Description:${RESET}\n"
  printf "  This script scales up or down components of an IBM Cloud Pak for Business Automation\n"
  printf "  deployment in a specific OpenShift namespace.\n\n"
  
  printf "${INFO}Usage:${RESET}\n"
  printf "  $0 -n <namespace> | --namespace <namespace> [options]\n\n"
  
  printf "${INFO}Options:${RESET}\n"
  printf "  -h, --help                           Display this help message and exit\n"
  printf "  -n, --namespace NAMESPACE            Specify the namespace to operate on (required)\n"
  printf "  -o, --operandNamespace NAMESPACE     Specify the namespace for non-operator resources\n"
  printf "                                       (optional, defaults to main namespace)\n"
  printf "  -u, --up                             Scale operators up to 1 replica\n"
  printf "  -d, --down                           Scale down all resources to 0 replicas (default)\n"
  printf "  -s, --silent                         Run in silent mode without prompting for confirmation\n\n"
  
  printf "${INFO}Examples:${RESET}\n"
  printf "  $0 -n cp4ba                                    # Scale down components in cp4ba namespace (default)\n"
  printf "  $0 -n cp4ba -d                                 # Scale down components in cp4ba namespace (explicit)\n"
  printf "  $0 -n cp4ba -u                                 # Scale up operators in cp4ba namespace\n"
  printf "  $0 -n cp4ba -s                                 # Scale down in silent mode (no prompts)\n"
  printf "  $0 --namespace=cp4ba --up                      # Scale up using equals sign syntax\n"
  printf "  $0 -n cp4ba-operators -o cp4ba-operands        # Operators in cp4ba-operators, operands in cp4ba-operands\n"
  printf "  $0 -n=cp4ba-operators -o=cp4ba-operands        # Same as above using equals sign syntax\n"
  printf "  $0 --namespace cp4ba --operandNamespace cp4ba2 # Operators in cp4ba, operands in cp4ba2\n"
  printf "  $0 --namespace=cp4ba --operandNamespace=cp4ba2 # Same as above using equals sign syntax\n"
  printf "  $0 -n cp4ba -d -s                              # Scale down silently without confirmation\n"
  printf "  $0 -h                                          # Display help\n\n"
  
  exit 0
}

# Function to print formatted messages
print_message() {
  local level=$1
  local message=$2
  local indent=$3
  
  case $level in
    "header")
      printf "${HEADER}%s${RESET}\n" "$message"
      ;;
    "info")
      printf "%s${INFO}%s${RESET}\n" "$indent" "$message"
      ;;
    "success")
      printf "%s${SUCCESS}%s${RESET}\n" "$indent" "$message"
      ;;
    "warning")
      printf "%s${WARNING}%s${RESET}\n" "$indent" "$message"
      ;;
    "error")
      printf "%s${ERROR}%s${RESET}\n" "$indent" "$message"
      ;;
    *)
      printf "%s%s\n" "$indent" "$message"
      ;;
  esac
}

# Function to confirm an action before proceeding
confirm_action() {
  local action=$1
  local resource_type=$2
  local namespace=$3
  
  # Skip confirmation in silent mode
  if [ "$SILENT_MODE" = true ]; then
    return 0
  fi
  
  printf "${WARNING}Are you sure you want to %s all %s in namespace %s? [y/N] (Default: N): ${RESET}" "$action" "$resource_type" "$namespace"
  read -r response
  
  case "$response" in
    [yY][eE][sS]|[yY])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Function to capitalize first letter of a string (portable across bash versions)
capitalize_first() {
  local str="$1"
  local first=$(echo "${str:0:1}" | tr '[:lower:]' '[:upper:]')
  local rest="${str:1}"
  echo "${first}${rest}"
}

# Function to save replica count to ConfigMap
save_replica_count() {
  local namespace=$1
  local resource_type=$2
  local resource_name=$3
  local replica_count=$4
  
  # Create ConfigMap if it doesn't exist
  if ! $CLI_CMD get configmap -n $namespace $CONFIGMAP_NAME &> /dev/null; then
    $CLI_CMD create configmap -n $namespace $CONFIGMAP_NAME --from-literal=created="$(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null
  fi
  
  # Save the replica count with a key format: resourcetype-resourcename
  local key="${resource_type}-${resource_name}"
  $CLI_CMD patch configmap -n $namespace $CONFIGMAP_NAME --type merge -p "{\"data\":{\"${key}\":\"${replica_count}\"}}" 2>/dev/null
}

# Function to get saved replica count from ConfigMap
get_saved_replica_count() {
  local namespace=$1
  local resource_type=$2
  local resource_name=$3
  
  # Check if ConfigMap exists
  if ! $CLI_CMD get configmap -n $namespace $CONFIGMAP_NAME &> /dev/null; then
    echo ""
    return
  fi
  
  # Retrieve the saved replica count
  local key="${resource_type}-${resource_name}"
  local saved_count=$($CLI_CMD get configmap -n $namespace $CONFIGMAP_NAME -o jsonpath="{.data.${key}}" 2>/dev/null)
  
  echo "$saved_count"
}

# Function to get the appropriate action verb based on scale direction
get_action_verb() {
  local scale_up=$1
  
  if [ "$scale_up" = true ]; then
    echo "scale up"
  else
    echo "scale down"
  fi
}

# Function to get the appropriate replicas count based on scale direction
get_replicas_count() {
  local scale_up=$1
  
  if [ "$scale_up" = true ]; then
    echo "1"
  else
    echo "0"
  fi
}

# Function to print section headers
print_section() {
  local section_number=$1
  local section_title=$2
  printf "\n${HEADER}%d. %s${RESET}\n" "$section_number" "$section_title"
}

# Function to check prerequisites
check_prerequisites() {
  local namespace=$1
  
  # Check if namespace parameter is provided
  if [ -z "$namespace" ]; then
    print_message "error" "Namespace is required. Use -n or --namespace to specify a namespace."
    print_message "info" "Run '$0 --help' for usage information."
    exit 1
  fi
  
  # Check if CLI is installed
  if ! command -v $CLI_CMD &> /dev/null; then
    print_message "error" "Error: OpenShift CLI ($CLI_CMD) is not installed or not in PATH"
    exit 1
  fi
  
  # Check if logged in to OpenShift
  check_cluster_login
  
  # Check if namespace exists
  if ! $CLI_CMD get namespace "$namespace" &> /dev/null; then
    print_message "error" "Error: Namespace $namespace does not exist"
    exit 1
  fi
  
  print_message "success" "Prerequisites check passed"
  return 0
}

# Function to scale CP4BA operators
scale_operators() {
  local namespace=$1
  local section_num=$2
  local scale_up=$3
  
  local action_verb=$(get_action_verb "$scale_up")
  local replicas=$(get_replicas_count "$scale_up")
  
  print_section "$section_num" "Scaling ${action_verb/scale /} CP4BA Operators in namespace $namespace"
  
  # Additional operators to include beyond CP4BA_OPERATOR_LIST
  local ADDITIONAL_OPERATORS="ibm-iam-operator ibm-zen-operator ibm-common-service-operator ibm-commonui-operator operand-deployment-lifecycle-manager"
  
  # Combine CP4BA operators with additional operators
  local ALL_OPERATORS="$CP4BA_OPERATOR_LIST $ADDITIONAL_OPERATORS"
  
  # Check if there are any operator deployments
  local any_deployments=false
  for operator in $ALL_OPERATORS; do
    OPERATOR_DEPLOYMENTS=$($CLI_CMD get deployment -n $namespace $operator -o jsonpath='{.metadata.name}' 2>/dev/null)
    if [ -n "$OPERATOR_DEPLOYMENTS" ]; then
      any_deployments=true
      break
    fi
  done
  
  if [ "$any_deployments" = false ]; then
    print_message "info" "No CP4BA operator deployments found in namespace $namespace" "  "
    return 0
  fi
  
  # Confirm before proceeding
  if ! confirm_action "$action_verb" "CP4BA operator deployments" "$namespace"; then
    print_message "warning" "Skipping CP4BA operator deployments $action_verb" "  "
    return 0
  fi
  
  # Scale all operators (CP4BA + additional)
  for operator in $ALL_OPERATORS; do
    OPERATOR_DEPLOYMENTS=$($CLI_CMD get deployment -n $namespace $operator -o jsonpath='{.metadata.name}' 2>/dev/null)
    if [ -z "$OPERATOR_DEPLOYMENTS" ]; then
      print_message "info" "No deployments found for operator: $operator" "  "
    else
      for deployment in $OPERATOR_DEPLOYMENTS; do
        print_message "info" "$(capitalize_first "$action_verb") operator deployment: $deployment" "  "
        $CLI_CMD scale deployment $deployment --replicas=$replicas -n $namespace
      done
    fi
  done
  
  return 0
}

# Function to scale additional operator deployments
scale_additional_operators() {
  local namespace=$1
  local section_num=$2
  local scale_up=$3
  
  local action_verb=$(get_action_verb "$scale_up")
  local replicas=$(get_replicas_count "$scale_up")
  
  print_section "$section_num" "Scaling ${action_verb/scale /} additional operator deployments in namespace $namespace"
  
  OPERATOR_DEPLOYMENTS=$($CLI_CMD get deployment -n $namespace -l olm.owner -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  if [ -z "$OPERATOR_DEPLOYMENTS" ]; then
    print_message "info" "No additional operator deployments found" "  "
    return 0
  fi
  
  # Filter deployments that need scaling based on current replica count
  local DEPLOYMENTS_TO_SCALE=""
  for deployment in $OPERATOR_DEPLOYMENTS; do
    CURRENT_REPLICAS=$($CLI_CMD get deployment -n $namespace $deployment -o jsonpath='{.spec.replicas}' 2>/dev/null)
    
    # Determine if this deployment needs scaling
    local needs_scaling=false
    if [ "$scale_up" = true ]; then
      # When scaling up, only scale if current replicas is 0
      if [ "$CURRENT_REPLICAS" = "0" ]; then
        needs_scaling=true
      fi
    else
      # When scaling down, only scale if current replicas is greater than 0
      if [ "$CURRENT_REPLICAS" != "0" ] && [ -n "$CURRENT_REPLICAS" ]; then
        needs_scaling=true
      fi
    fi
    
    if [ "$needs_scaling" = true ]; then
      DEPLOYMENTS_TO_SCALE="$DEPLOYMENTS_TO_SCALE $deployment"
    else
      print_message "info" "Deployment $deployment already in desired state (replicas: $CURRENT_REPLICAS)" "  "
    fi
  done
  
  # Trim leading space
  DEPLOYMENTS_TO_SCALE=$(echo "$DEPLOYMENTS_TO_SCALE" | sed 's/^ //')
  
  if [ -z "$DEPLOYMENTS_TO_SCALE" ]; then
    print_message "info" "No additional operator deployments need scaling (all in desired state)" "  "
    return 0
  fi
  
  # Confirm before proceeding
  if ! confirm_action "$action_verb" "additional operator deployments" "$namespace"; then
    print_message "warning" "Skipping additional operator deployments $action_verb" "  "
    return 0
  fi
  
  for deployment in $DEPLOYMENTS_TO_SCALE; do
    print_message "info" "$(capitalize_first "$action_verb") operator deployment: $deployment" "  "
    $CLI_CMD scale deployment $deployment --replicas=$replicas -n $namespace
  done
  
  return 0
}

# Function to scale deployments
scale_deployments() {
  local namespace=$1
  local section_num=$2
  local scale_up=$3
  
  local action_verb=$(get_action_verb "$scale_up")
  local replicas=$(get_replicas_count "$scale_up")
  
  if [ "$scale_up" = true ]; then
    print_section "$section_num" "Scaling up deployments in namespace $namespace"
  else
    print_section "$section_num" "Scaling down all deployments in namespace $namespace"
  fi
  
  DEPLOYMENTS=$($CLI_CMD get deployment -n $namespace -o jsonpath='{.items[*].metadata.name}')
  if [ -z "$DEPLOYMENTS" ]; then
    print_message "info" "No deployments found" "  "
    return 0
  fi
  
  # Confirm before proceeding
  if ! confirm_action "$action_verb" "deployments" "$namespace"; then
    print_message "warning" "Skipping deployments $action_verb" "  "
    return 0
  fi
  
  for deployment in $DEPLOYMENTS; do
    CURRENT_REPLICAS=$($CLI_CMD get deployment -n $namespace $deployment -o jsonpath='{.spec.replicas}' 2>/dev/null)
    
    if [ "$scale_up" = true ]; then
      # When scaling up, retrieve saved replica count from ConfigMap
      if [ "$CURRENT_REPLICAS" = "0" ]; then
        SAVED_REPLICAS=$(get_saved_replica_count "$namespace" "deployment" "$deployment")
        
        # If no saved value or saved value is 0, default to 1
        if [ -z "$SAVED_REPLICAS" ] || [ "$SAVED_REPLICAS" = "0" ]; then
          SAVED_REPLICAS=1
        fi
        
        print_message "info" "$(capitalize_first "$action_verb") deployment: $deployment (restoring to $SAVED_REPLICAS replicas)" "  "
        $CLI_CMD scale deployment $deployment --replicas=$SAVED_REPLICAS -n $namespace
      else
        print_message "info" "Deployment $deployment already scaled up (replicas: $CURRENT_REPLICAS)" "  "
      fi
    else
      # When scaling down, save current replica count to ConfigMap before scaling
      if [ "$CURRENT_REPLICAS" != "0" ] && [ -n "$CURRENT_REPLICAS" ]; then
        save_replica_count "$namespace" "deployment" "$deployment" "$CURRENT_REPLICAS"
        print_message "info" "Scaling down deployment: $deployment (saving current replicas: $CURRENT_REPLICAS)" "  "
        $CLI_CMD scale deployment $deployment --replicas=0 -n $namespace
      else
        print_message "info" "Deployment $deployment already scaled down" "  "
      fi
    fi
  done
  
  return 0
}

# Function to scale statefulsets
scale_statefulsets() {
  local namespace=$1
  local section_num=$2
  local scale_up=$3
  
  local action_verb=$(get_action_verb "$scale_up")
  local replicas=$(get_replicas_count "$scale_up")
  
  if [ "$scale_up" = true ]; then
    print_section "$section_num" "Scaling up statefulsets in namespace $namespace"
  else
    print_section "$section_num" "Scaling down all statefulsets in namespace $namespace"
  fi
  
  STATEFULSETS=$($CLI_CMD get statefulset -n $namespace -o jsonpath='{.items[*].metadata.name}')
  if [ -z "$STATEFULSETS" ]; then
    print_message "info" "No statefulsets found" "  "
    return 0
  fi
  
  # Confirm before proceeding
  if ! confirm_action "$action_verb" "statefulsets" "$namespace"; then
    print_message "warning" "Skipping statefulsets $action_verb" "  "
    return 0
  fi
  
  for statefulset in $STATEFULSETS; do
    CURRENT_REPLICAS=$($CLI_CMD get statefulset -n $namespace $statefulset -o jsonpath='{.spec.replicas}' 2>/dev/null)
    
    if [ "$scale_up" = true ]; then
      # When scaling up, retrieve saved replica count from ConfigMap
      if [ "$CURRENT_REPLICAS" = "0" ]; then
        SAVED_REPLICAS=$(get_saved_replica_count "$namespace" "statefulset" "$statefulset")
        
        # If no saved value or saved value is 0, default to 1
        if [ -z "$SAVED_REPLICAS" ] || [ "$SAVED_REPLICAS" = "0" ]; then
          SAVED_REPLICAS=1
        fi
        
        print_message "info" "$(capitalize_first "$action_verb") statefulset: $statefulset (restoring to $SAVED_REPLICAS replicas)" "  "
        $CLI_CMD scale statefulset $statefulset --replicas=$SAVED_REPLICAS -n $namespace
      else
        print_message "info" "Statefulset $statefulset already scaled up (replicas: $CURRENT_REPLICAS)" "  "
      fi
    else
      # When scaling down, save current replica count to ConfigMap before scaling
      if [ "$CURRENT_REPLICAS" != "0" ] && [ -n "$CURRENT_REPLICAS" ]; then
        save_replica_count "$namespace" "statefulset" "$statefulset" "$CURRENT_REPLICAS"
        print_message "info" "Scaling down statefulset: $statefulset (saving current replicas: $CURRENT_REPLICAS)" "  "
        $CLI_CMD scale statefulset $statefulset --replicas=0 -n $namespace
      else
        print_message "info" "Statefulset $statefulset already scaled down" "  "
      fi
    fi
  done
  
  return 0
}

# Function to handle running jobs
handle_running_jobs() {
  local namespace=$1
  local section_num=$2
  
  print_section "$section_num" "Handling running jobs in namespace $namespace"
  
  JOBS=$($CLI_CMD get jobs -n $namespace -o jsonpath='{.items[?(@.status.active==1)].metadata.name}')
  if [ -z "$JOBS" ]; then
    print_message "info" "No active jobs found" "  "
    return 0
  fi
  
  # In silent mode, default to deleting jobs
  if [ "$SILENT_MODE" = true ]; then
    JOB_CHOICE=1
    print_message "info" "Silent mode: Deleting all active jobs" "  "
  else
    print_message "info" "Found active jobs. Would you like to:" "  "
    print_message "info" "1) Delete all active jobs" "    "
    print_message "info" "2) Scale down jobs to 0 parallelism (may not work for all jobs)" "    "
    print_message "info" "3) Skip jobs" "    "
    read -p "  Enter choice [1-3]: " JOB_CHOICE
  fi
  
  case $JOB_CHOICE in
    1)
      for job in $JOBS; do
        print_message "info" "Deleting job: $job" "  "
        $CLI_CMD delete job $job -n $namespace
      done
      ;;
    2)
      for job in $JOBS; do
        print_message "info" "Setting parallelism=0 for job: $job" "  "
        $CLI_CMD patch job $job -n $namespace -p '{"spec":{"parallelism":0}}'
      done
      ;;
    3)
      print_message "info" "Skipping jobs" "  "
      ;;
    *)
      print_message "warning" "Invalid choice. Skipping jobs." "  "
      ;;
  esac
  
  return 0
}

# Function to suspend or resume cronjobs
manage_cronjobs() {
  local namespace=$1
  local section_num=$2
  local scale_up=$3
  
  if [ "$scale_up" = true ]; then
    print_section "$section_num" "Resuming cronjobs in namespace $namespace"
    local action="resume"
    local suspend_value="false"
  else
    print_section "$section_num" "Suspending all cronjobs in namespace $namespace"
    local action="suspend"
    local suspend_value="true"
  fi
  
  CRONJOBS=$($CLI_CMD get cronjob -n $namespace -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  if [ -z "$CRONJOBS" ]; then
    print_message "info" "No cronjobs found" "  "
    return 0
  fi
  
  # Confirm before proceeding
  if ! confirm_action "$action" "cronjobs" "$namespace"; then
    print_message "warning" "Skipping cronjob $action" "  "
    return 0
  fi
  
  for cronjob in $CRONJOBS; do
    if [ "$scale_up" = true ]; then
      # Check if cronjob is currently suspended
      IS_SUSPENDED=$($CLI_CMD get cronjob -n $namespace $cronjob -o jsonpath='{.spec.suspend}' 2>/dev/null)
      if [ "$IS_SUSPENDED" = "true" ]; then
        print_message "info" "Resuming cronjob: $cronjob" "  "
        $CLI_CMD patch cronjob $cronjob -n $namespace -p '{"spec":{"suspend":false}}'
      else
        print_message "info" "Cronjob $cronjob already active" "  "
      fi
    else
      print_message "info" "Suspending cronjob: $cronjob" "  "
      $CLI_CMD patch cronjob $cronjob -n $namespace -p '{"spec":{"suspend":true}}'
    fi
  done
  
  return 0
}

# Function to delete remaining pods
delete_remaining_pods() {
  local namespace=$1
  local section_num=$2
  
  print_section "$section_num" "Deleting remaining pods in namespace $namespace"
  
  PODS=$($CLI_CMD get pods -n $namespace -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
  if [ -z "$PODS" ]; then
    print_message "info" "No pods found in namespace $namespace" "  "
    return 0
  fi
  
  # Count the pods
  POD_COUNT=$(echo "$PODS" | wc -w | tr -d ' ')
  print_message "info" "Found $POD_COUNT pod(s) remaining in namespace $namespace" "  "
  
  # Confirm before proceeding
  if ! confirm_action "delete" "remaining pods" "$namespace"; then
    print_message "warning" "Skipping pod deletion" "  "
    return 0
  fi
  
  for pod in $PODS; do
    print_message "info" "Deleting pod: $pod" "  "
    $CLI_CMD delete pod $pod -n $namespace --force --grace-period=0 2>/dev/null
  done
  
  print_message "success" "Remaining pods deleted from namespace $namespace" "  "
  return 0
}

# Main function to orchestrate the scaling process
main() {
  local namespace=$1
  local scale_up=$2
  
  local operation_type="down"
  if [ "$scale_up" = true ]; then
    operation_type="up"
  fi
  
  # Print banner
  local operation_type_cap=$(capitalize_first "$operation_type")
  printf "\n${HEADER}===== IBM Cloud Pak for Business Automation - Scale ${operation_type_cap} Tool v${VERSION} =====${RESET}\n"
  printf "${INFO}Operator Namespace: ${SUCCESS}%s${RESET}\n" "$namespace"
  if [ "$OPERAND_NAMESPACE" != "$namespace" ]; then
    printf "${INFO}Operand Namespace: ${SUCCESS}%s${RESET}\n" "$OPERAND_NAMESPACE"
  fi
  printf "\n"
  
  # Check prerequisites
  check_prerequisites "$namespace"
  
  # Check operand namespace if different
  if [ "$OPERAND_NAMESPACE" != "$namespace" ]; then
    if ! $CLI_CMD get namespace "$OPERAND_NAMESPACE" &> /dev/null; then
      print_message "error" "Error: Operand namespace $OPERAND_NAMESPACE does not exist"
      exit 1
    fi
  fi
  
  # Confirm overall operation
  if [ "$scale_up" = true ]; then
    print_message "warning" "This script will scale up operators in the namespace $namespace."
    print_message "warning" "You will be prompted for confirmation before each step."
    print_message "warning" "This operation will start operator pods that were previously scaled down."
  else
    print_message "warning" "This script will scale down all components in the namespace $namespace."
    print_message "warning" "You will be prompted for confirmation before each step."
    print_message "warning" "This operation may impact running applications and services."
  fi
  
  # Skip main confirmation in silent mode
  if [ "$SILENT_MODE" != true ]; then
    printf "\n${WARNING}Do you want to continue with the scale ${operation_type} process? [y/N] (Default: N): ${RESET}"
    read -r response
    if [[ ! "$response" =~ ^[yY][eE][sS]|[yY]$ ]]; then
      print_message "info" "Scale ${operation_type} operation cancelled by user."
      exit 0
    fi
  else
    print_message "info" "Running in silent mode - skipping confirmations"
  fi
  
  # Print start message
  print_message "header" "===== Starting scale ${operation_type} operations ====="
  
  # Scale components in sequence
  scale_operators "$namespace" 1 "$scale_up"
  scale_additional_operators "$namespace" 2 "$scale_up"
  
  # Perform operand operations for both scale up and scale down
  if [ "$scale_up" = false ]; then
    scale_deployments "$OPERAND_NAMESPACE" 3 "$scale_up"
    scale_statefulsets "$OPERAND_NAMESPACE" 4 "$scale_up"
    handle_running_jobs "$OPERAND_NAMESPACE" 5
    manage_cronjobs "$OPERAND_NAMESPACE" 6 "$scale_up"
    delete_remaining_pods "$OPERAND_NAMESPACE" 7
  else
    scale_deployments "$OPERAND_NAMESPACE" 3 "$scale_up"
    scale_statefulsets "$OPERAND_NAMESPACE" 4 "$scale_up"
    manage_cronjobs "$OPERAND_NAMESPACE" 5 "$scale_up"
  fi
  
  # Print completion message
  print_message "header" "===== Scale ${operation_type} operations completed ====="
  
  if [ "$scale_up" = true ]; then
    print_message "success" "Operators in namespace $namespace have been scaled up."
  else
    print_message "success" "All components in namespace $namespace have been scaled down."
    print_message "info" "To scale back up, you may need to use the IBM Cloud Pak operator or manually scale resources."
  fi
}

# Parse command line arguments
NAMESPACE=""
OPERAND_NAMESPACE=""
SCALE_UP=false
SILENT_MODE=false

# Process command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--help)
      display_help
      ;;
    -n|--namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    -n=*|--namespace=*)
      NAMESPACE="${key#*=}"
      shift
      ;;
    -o|--operandNamespace)
      OPERAND_NAMESPACE="$2"
      shift
      shift
      ;;
    -o=*|--operandNamespace=*)
      OPERAND_NAMESPACE="${key#*=}"
      shift
      ;;
    -u|--up)
      SCALE_UP=true
      shift
      ;;
    -d|--down)
      SCALE_UP=false
      shift
      ;;
    -s|--silent)
      SILENT_MODE=true
      shift
      ;;
    *)
      # If any unrecognized argument is provided, display help
      print_message "error" "Unrecognized argument: $key"
      print_message "info" "Run '$0 --help' for usage information."
      exit 1
      ;;
  esac
done

# Check if namespace is provided
if [[ -z "$NAMESPACE" ]]; then
  print_message "error" "Namespace is required. Use -n or --namespace to specify a namespace."
  print_message "info" "Run '$0 --help' for usage information."
  exit 1
fi

# If operand namespace is not specified, use the main namespace
if [[ -z "$OPERAND_NAMESPACE" ]]; then
  OPERAND_NAMESPACE="$NAMESPACE"
fi

# Execute main function with namespace parameter and scale up flag
main "$NAMESPACE" "$SCALE_UP"

# Made with Bob
