#!/bin/bash
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

# Detect CLI command (oc for OpenShift, kubectl for Kubernetes/Rancher)
if command -v oc &> /dev/null; then
  CLI_CMD="oc"
elif command -v kubectl &> /dev/null; then
  CLI_CMD="kubectl"
else
  echo "Unable to locate Kubernetes CLI or OpenShift CLI. You must install it to run this script."
  exit 1
fi

CP4BA_SERVICE_NAMESPACE=""
HELP=""
UNINSTALL=""
CR_NAME=""
BTS_CR_NAME=""
INSIGHTS_ENGINE_CR_NAME=""
DPE_CR_NAME=""
PFS_CR_NAME=""
WFPS_RUNTIME_CR_NAME=""
ADS_CR_NAME=""
CCX_CR_NAME=""
ODM_CR_NAME=""

function info() { printf '%b\n' "\033[34m[INFO]\033[0m $1"; }
function success() { printf '%b\n' "\033[32m[SUCCESS]\033[0m $1"; }
function warning() { printf '%b\n' "\033[33m[WARNING]\033[0m $1"; }
function error() { printf '%b\n' "\033[31m[ERROR]\033[0m $1"; exit 1; }

function check_cluster_login() {
  if ! ${CLI_CMD} cluster-info >/dev/null 2>&1; then
    error "You must be logged into the cluster."
  fi
}

function parse_arguments() {
  while getopts 'n:hU' OPTION; do
    case "$OPTION" in
      n) CP4BA_SERVICE_NAMESPACE=$OPTARG ;;
      h) HELP="true" ;;
      U) UNINSTALL="true" ;;
      ?) HELP="true" ;;
    esac
  done
  shift "$(($OPTIND - 1))"
}

function validate_namespace() {
  if [ -z "$CP4BA_SERVICE_NAMESPACE" ]; then
    error "CP4BA service namespace needed. Use -n <namespace>."
  fi
  if ! ${CLI_CMD} get namespace "${CP4BA_SERVICE_NAMESPACE}" >/dev/null 2>&1; then
    error "Namespace ${CP4BA_SERVICE_NAMESPACE} does not exist."
  fi
}

function detect_cr_name() {
  # Detect ICP4ACluster CR
  local icp4a_cr=$(${CLI_CMD} get icp4acluster -n "$CP4BA_SERVICE_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')
  if [ -n "$icp4a_cr" ]; then
    CR_NAME="$icp4a_cr"
    info "Detected ICP4ACluster CR: $CR_NAME"
  else
    # Detect Content CR
    local content_cr=$(${CLI_CMD} get content -n "$CP4BA_SERVICE_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')
    if [ -n "$content_cr" ]; then
      CR_NAME="$content_cr"
      info "Detected Content CR: $CR_NAME"
    fi
  fi

  # Detect ODM CR
  local odm_cr=$(${CLI_CMD} get ICP4AOperationalDecisionManager -n "$CP4BA_SERVICE_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')
  if [ -n "$odm_cr" ]; then
    ODM_CR_NAME="$odm_cr"
    info "Detected OperationalDecisionManager CR: $ODM_CR_NAME"
  fi
  
  # Detect BusinessTeamsService CR
  local bts_cr=$(${CLI_CMD} get businessteamsservice -n "$CP4BA_SERVICE_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')
  if [ -n "$bts_cr" ]; then
    BTS_CR_NAME="$bts_cr"
    info "Detected BusinessTeamsService CR: $BTS_CR_NAME"
  fi

  # Detect InsightsEngine CR for bai_orm
  local insights_cr=$(${CLI_CMD} get insightsengines.icp4a.ibm.com -n "$CP4BA_SERVICE_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')
  if [ -n "$insights_cr" ]; then
    INSIGHTS_ENGINE_CR_NAME="$insights_cr"
    info "Detected InsightsEngine CR: $INSIGHTS_ENGINE_CR_NAME"
  fi

  # Detect ICP4ADocumentProcessingEngine CR for dpe_orm
  local dpe_cr=$(${CLI_CMD} get icp4adocumentprocessingengine -n "$CP4BA_SERVICE_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')
  if [ -n "$dpe_cr" ]; then
    DPE_CR_NAME="$dpe_cr"
    info "Detected ICP4ADocumentProcessingEngine CR: $DPE_CR_NAME"
  fi

  # Detect PFS CR name for wfps_orm
  local pfs_cr=$(${CLI_CMD} get pfs -n "$CP4BA_SERVICE_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')
  if [ -n "$pfs_cr" ]; then
    PFS_CR_NAME="$pfs_cr"
    info "Detected PFS CR: $PFS_CR_NAME"
  fi

  # Detect WFPS Runtime CR name for baw_orm
  local wfps_runtime_cr=$(${CLI_CMD} get wfpsruntime -n "$CP4BA_SERVICE_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')
  if [ -n "$wfps_runtime_cr" ]; then
    WFPS_RUNTIME_CR_NAME="$wfps_runtime_cr"
    info "Detected WFPSRuntime CR: $WFPS_RUNTIME_CR_NAME"
  fi

   # Detect CCXAIServices CR
  local ccx_cr=$(${CLI_CMD} get CCXAIServices -n "$CP4BA_SERVICE_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')
  if [ -n "$ccx_cr" ]; then
    CCX_CR_NAME="$ccx_cr"
    info "Detected CCXAIServices CR: $CCX_CR_NAME"
  fi

  # Detect ICP4AAutomationDecisionService CR for dicms_orm
  local ads_cr=$(${CLI_CMD} get icp4aautomationdecisionservice -n "$CP4BA_SERVICE_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')
  if [ -n "$ads_cr" ]; then
    ADS_CR_NAME="$ads_cr"
    info "Detected ICP4AAutomationDecisionService CR: $ADS_CR_NAME"
  fi

  # Detect deployment patterns for ICP4ACluster
  DEPLOYMENT_PATTERNS=""
  if [ -n "$icp4a_cr" ]; then
    DEPLOYMENT_PATTERNS=$(${CLI_CMD} get icp4acluster "$icp4a_cr" -n "$CP4BA_SERVICE_NAMESPACE" -o jsonpath='{.spec.shared_configuration.sc_deployment_patterns}' 2>/dev/null)
  fi
}

function apply_orms() {
  local found=0
  local applied=0
  local icp4a_cr=$(${CLI_CMD} get icp4acluster -n "$CP4BA_SERVICE_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')
  local content_cr=$(${CLI_CMD} get content -n "$CP4BA_SERVICE_NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}')

  for f in "$CUR_DIR"/ORMs/*.yaml; do
    [ -e "$f" ] || continue
    found=1
    local filename=$(basename "$f")
    local cr_name="$CR_NAME"
    local meta_name="$cr_name"

    # Skip fncm_orm.yaml if ICP4ACluster CR not found
    if [[ "$filename" == "fncm_orm.yaml" ]]; then
      if [ -z "$icp4a_cr" ]; then
        continue
      fi
      if [[ ! "$DEPLOYMENT_PATTERNS" =~ "content" ]] && \
         [[ ! "$DEPLOYMENT_PATTERNS" =~ "application" ]] && \
         [[ ! "$DEPLOYMENT_PATTERNS" =~ "document_processing" ]] && \
         [[ ! "$DEPLOYMENT_PATTERNS" =~ "workflow" ]] && \
         [[ ! "$DEPLOYMENT_PATTERNS" =~ "workstreams" ]]; then
        continue
      fi
    fi

    # Skip content_orm.yaml if Content CR not found OR if ICP4ACluster CR exists
    if [[ "$filename" == "content_orm.yaml" ]]; then
      if [ -n "$icp4a_cr" ]; then
        continue
      fi
      if [ -z "$content_cr" ]; then
        continue
      fi
    fi

    # Apply for all ICP4ACluster deployments
    if [[ "$filename" == "ban_orm.yaml" ]]; then
      if [ -z "$icp4a_cr" ]; then
        continue
      fi
    fi

    # Skip odm_orm.yaml if OperationalDecisionManager CR not found
    if [[ "$filename" == "odm_orm.yaml" ]]; then
      if [ -z "$ODM_CR_NAME" ]; then
        continue
      fi
      cr_name="$ODM_CR_NAME"
    fi

    # Skip ccx_orm.yaml if CCXAIServices CR not found
    if [[ "$filename" == "ccx_orm.yaml" ]]; then
      if [ -z "$CCX_CR_NAME" ]; then
        continue
      fi
      cr_name="$CCX_CR_NAME"
    fi

    # Skip adp_orm.yaml if ICP4ACluster CR not found
    if [[ "$filename" == "adp_orm.yaml" ]]; then
      if [ -z "$icp4a_cr" ]; then
        continue
      fi
      if [[ ! "$DEPLOYMENT_PATTERNS" =~ "document_processing" ]]; then
        continue
      fi
    fi

    # Skip bai_orm.yaml if InsightsEngine CR not found
    if [[ "$filename" == "bai_orm.yaml" ]]; then
      if [ -z "$INSIGHTS_ENGINE_CR_NAME" ]; then
        continue
      fi
      cr_name="$INSIGHTS_ENGINE_CR_NAME"
    fi

    # Skip bts_orm.yaml if BusinessTeamsService CR not found
    if [[ "$filename" == "bts_orm.yaml" ]]; then
      if [ -z "$BTS_CR_NAME" ]; then
        continue
      fi
      cr_name="$BTS_CR_NAME"
    fi

    # Skip dpe_orm.yaml if ICP4ADocumentProcessingEngine CR not found
    if [[ "$filename" == "dpe_orm.yaml" ]]; then
      if [ -z "$DPE_CR_NAME" ]; then
        continue
      fi
      cr_name="$DPE_CR_NAME"
      if [ -n "$icp4a_cr" ]; then
        meta_name="$icp4a_cr"
      fi
    fi

    # Skip baw_orm.yaml - Apply only for workflow pattern
    if [[ "$filename" == "baw_orm.yaml" ]]; then
      if [ -z "$icp4a_cr" ]; then
        continue
      fi
      if [[ ! "$DEPLOYMENT_PATTERNS" =~ "workflow" ]] && \
        [[ ! "$DEPLOYMENT_PATTERNS" =~ "workstreams" ]]; then
        continue
      fi
    fi

    # Skip pfs_orm.yaml if PFS CR not found
    if [[ "$filename" == "pfs_orm.yaml" ]]; then
      if [ -z "$PFS_CR_NAME" ]; then
        continue
      fi
      cr_name="$PFS_CR_NAME"
    fi

    # Skip wfps_orm.yaml if WFPS Runtime CR not found
    if [[ "$filename" == "wfps_orm.yaml" ]]; then
      if [ -z "$WFPS_RUNTIME_CR_NAME" ]; then
        continue
      fi
      cr_name="$WFPS_RUNTIME_CR_NAME"
    fi

    # Skip dicms_orm.yaml if ICP4AAutomationDecisionService CR not found
    if [[ "$filename" == "dicms_orm.yaml" ]]; then
      if [ -z "$ADS_CR_NAME" ]; then
        continue
      fi
    fi

    info "Applying $filename with CR name: $cr_name..."
    if sed -e "s/{{ placeholder_namespace }}/$CP4BA_SERVICE_NAMESPACE/g" \
           -e "s/{{ meta.name }}/$meta_name/g" \
           -e "s/{{ meta.pfs_name }}/$PFS_CR_NAME/g" \
           -e "s/{{ meta.wfps_runtime_name }}/$WFPS_RUNTIME_CR_NAME/g" \
           -e "s/{{ meta.insights_engine_name }}/$INSIGHTS_ENGINE_CR_NAME/g" "$f" \
       | $CLI_CMD -n "$CP4BA_SERVICE_NAMESPACE" apply -f - ; then
      success "Applied $filename"
      ((applied++))
    else
      warning "Failed to apply $filename"
    fi
  done

  [[ $found -eq 0 ]] && error "No ORM YAML files found in $CUR_DIR/ORMs"
  
  if [[ $applied -eq 0 ]]; then
    error "No ORMs were applied. Ensure matching CRs exist in namespace $CP4BA_SERVICE_NAMESPACE and Turbonomic CRD is installed."
  fi

  success "Apply complete. $applied ORM(s) applied."
}

function uninstall_orms() {
  local found=0
  local deleted=0

  info "Uninstalling ORMs from namespace: $CP4BA_SERVICE_NAMESPACE"

  for f in "$CUR_DIR"/ORMs/*.yaml; do
    [ -e "$f" ] || continue
    found=1

    local orm_name=$(awk '/^metadata:/{m=1} m && /^[[:space:]]*name:/{print $2; exit}' "$f")

    if [[ -n "$orm_name" ]]; then
      if $CLI_CMD -n "$CP4BA_SERVICE_NAMESPACE" get operatorresourcemapping "$orm_name" >/dev/null 2>&1; then
        info "Deleting ORM: $orm_name"
        $CLI_CMD -n "$CP4BA_SERVICE_NAMESPACE" delete operatorresourcemapping "$orm_name"
        success "Deleted ORM: $orm_name"
        ((deleted++))
      fi
    fi
  done

  [[ $found -eq 0 ]] && error "No ORM YAML files found in $CUR_DIR/ORMs"
  
  if [[ $deleted -eq 0 ]]; then
    warning "No ORMs found to delete in namespace $CP4BA_SERVICE_NAMESPACE"
  else
    success "Uninstall complete. $deleted ORM(s) deleted."
  fi
}

# Main
parse_arguments "$@"

if [[ $HELP == "true" ]]; then
  echo "This script applies or uninstalls CP4BA OperatorResourceMappings (ORM) for Turbonomic."
  echo ""
  echo "Usage: $0 -n <service_namespace> [-U] [-h]"
  echo ""
  echo "Options:"
  echo "  -n  Target CP4BA service namespace where workloads are deployed (required)"
  echo "  -U  Uninstall ORMs"
  echo "  -h  Display help"
  echo ""
  exit 0
fi

check_cluster_login
validate_namespace
detect_cr_name

if [[ "$UNINSTALL" == "true" ]]; then
  uninstall_orms
else
  apply_orms
fi
