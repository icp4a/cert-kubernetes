#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2025. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
# DBACLD-185068 Implementing script to apply all the Turbonomic ORM yaml files
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
CLI_CMD="oc"

CP4BA_NAMESPACE=""
HELP=""
UNINSTALL=""
CR_NAME=""

function info() { echo -e "\033[34m[INFO]\033[0m $1"; }
function error() { echo -e "\033[31m[ERROR]\033[0m $1"; exit 1; }

function check_cluster_login() {
  if ! ${CLI_CMD} whoami >/dev/null 2>&1; then
    error "You must be logged into the OpenShift cluster with '${CLI_CMD} login'."
  fi
}

function parse_arguments() {
  while getopts 'n:hU' OPTION; do
    case "$OPTION" in
      n) CP4BA_NAMESPACE=$OPTARG ;;
      h) HELP="true" ;;
      U) UNINSTALL="true" ;;
      ?) HELP="true" ;;
    esac
  done
  shift "$(($OPTIND - 1))"
}

function validate_namespace() {
  if [ -z "$CP4BA_NAMESPACE" ]; then
    error "CP4BA namespace needed. Use -n <namespace>."
  fi
  if [ -z "$(${CLI_CMD} get project "${CP4BA_NAMESPACE}" 2>/dev/null)" ]; then
    error "Namespace ${CP4BA_NAMESPACE} does not exist. Specify an existing namespace where CP4BA is installed."
  fi
}

function detect_cr_name() {
  if [ -z "$CR_NAME" ]; then
    local icp4a_cr=$(${CLI_CMD} get icp4acluster -n "$CP4BA_NAMESPACE" --no-headers --ignore-not-found | awk '{print $1}')
    if [ -n "$icp4a_cr" ]; then
      CR_NAME="$icp4a_cr"
      info "Detected ICP4ACluster CR: $CR_NAME"
    else
      local content_cr=$(${CLI_CMD} get content -n "$CP4BA_NAMESPACE" --no-headers --ignore-not-found | awk '{print $1}')
      if [ -n "$content_cr" ]; then
        CR_NAME="$content_cr"
        info "Detected Content CR: $CR_NAME"
      fi
    fi
  fi
}

function apply_orms() {
  local found=0
  for f in "$CUR_DIR"/ORMs/*.yaml; do
    [ -e "$f" ] || continue
    found=1
    info "Applying $(basename "$f") with CR name: $CR_NAME ..."
    sed -e "s/{{ placeholder_namespace }}/$CP4BA_NAMESPACE/g" \
        -e "s/{{ meta.name }}/$CR_NAME/g" "$f" \
      | $CLI_CMD -n "$CP4BA_NAMESPACE" apply -f -
  done
  [[ $found -eq 0 ]] && error "No ORM YAML files found in $CUR_DIR/ORMs"
  info "Apply complete."
}

function uninstall_orms() {
  local found=0
  info "Uninstalling ORMs..."
  for f in "$CUR_DIR"/ORMs/*.yaml; do
    [ -e "$f" ] || continue
    found=1
    orm_name=$(awk '/^kind:[[:space:]]*OperatorResourceMapping/{f=1} f && /^[[:space:]]*name:[[:space:]]*/{gsub(/^[[:space:]]*name:[[:space:]]*/, ""); print; exit}' "$f")
    if [[ -n "$orm_name" ]]; then
      info "Deleting ORM $orm_name ..."
      $CLI_CMD -n "$CP4BA_NAMESPACE" delete operatorresourcemapping "$orm_name" --ignore-not-found
    fi
  done
  [[ $found -eq 0 ]] && error "No ORM YAML files found in $CUR_DIR/ORMs"
  info "Uninstall complete."
}

parse_arguments "$@"

if [[ $HELP == "true" ]]; then
  echo "This script applies or uninstalls Cloud Pak for Business Automation OperatorResourceMappings(ORM)."
  echo "Usage: $0 -n <namespace> [-U]"
  echo "  -n  Target CP4BA namespace (required)"
  echo "  -U  Uninstall IBM Cloud Pak for Business Automation OperatorResourceMapping"
  echo "  -h  Display help"
  exit 0
fi

if ! [ -x "$(command -v ${CLI_CMD})" ]; then
  error "OpenShift CLI (${CLI_CMD}) is not installed."
fi

check_cluster_login
validate_namespace
detect_cr_name

if [[ "$UNINSTALL" == "true" ]]; then
  uninstall_orms
else
  apply_orms
fi
