#!/usr/bin/env bash

# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2023. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product.
# Please refer to that particular license for additional information.

# ---------- Command arguments ----------

set -o errtrace
#set -o errexit

CLEANUP="false"
STORAGE_CLASS="default"
ZEN="false"
ZEN4="false"
IM="false"
KEYCLOAK="false"
MONGO="false"
UTIL="false"
LSR="false"
SELECTED="false"

function main() {
  parse_arguments "$@"
  if [ ! -d "tmp" ]; then
    mkdir tmp
  fi
  if [[ $CLEANUP == "true" ]]; then
    save_log "tmp/logs" "cleanup_log"
    trap cleanup_log EXIT
    cleanup
  else
    save_log "tmp/logs" "deploy_log"
    trap cleanup_log EXIT
    deploy_resources
  fi
}

function parse_arguments() {
  # process options
  while [[ "$@" != "" ]]; do
    case "$1" in
    --services-ns)
      shift
      TARGET_NAMESPACE=$1
      ;;
    --operator-ns)
      shift
      OPERATOR_NAMESPACE=$1
      ;;
    --tethered-ns)
      shift
      TETHERED_NS=$1
      ;;
    --lsr-ns)
      shift
      LSR_NAMESPACE=$1
      ;;
    --zen)
      ZEN="true"
      SELECTED="true"
      ;;
    --zen4)
      ZEN4="true"
      SELECTED="true"
      ;;
    --im)
      IM="true"
      SELECTED="true"
      ;;
    --keycloak)
      KEYCLOAK="true"
      SELECTED="true"
      ;;
    --mongo)
      MONGO="true"
      SELECTED="true"
      ;;
    --lsr)
      LSR="true"
      SELECTED="true"
      ;;
    --util)
      UTIL="true"
      SELECTED="true"
      ;;
    --storage-class)
      shift
      STORAGE_CLASS=$1
      ;;
    -c | --cleanup)
      CLEANUP="true"
      ;;
    -h | --help)
      print_usage
      exit 1
      ;;
    *) 
      warning "$1 not a supported parameter for deploy-br-resoruces.sh"
      ;;
    esac
    shift
  done
  if [[ $SELECTED == "false" ]]; then
    error "No component selected. Please use a combination of --im, --mongo, --keycloak, --zen, or --zen4 to select components to deploy resources for."
  fi
  if [[ $TARGET_NAMESPACE == "" ]] && [[ $OPERATOR_NAMESPACE == "" ]]; then
    error "No namespace selected. Please re-run script with --services-ns and/or --operator-ns parameter defined."
  fi
  if [[ $UTIL == "true" ]] && [[ $OPERATOR_NAMESPACE == "" ]]; then
    error "CPFS Util selected but no operator namespace provided. Please re-run script with --operator-ns parameter defined."
  fi
  if [[ $LSR == "true" ]] && [[ $LSR_NAMESPACE == "" ]]; then
    error "License Service Reporter selected but no namespace provided. Please re-run script with --lsr-ns parameter defined."
  fi
  if [[ $ZEN == "true" && $ZEN4 == "true" ]]; then
    error "Cannot select --zen and --zen4 on the same run of the script. Please verify zen version in the namespace $TARGET_NAMESPACE and select the appropriate option."
  fi
  if [[ $OPERATOR_NAMESPACE != "" ]] && [[ $TARGET_NAMESPACE == "" ]]; then
    warning "No services namespace specified, using operator namespace $OPERATOR_NAMESPACE instead. If using SOD topology, please re-run with both --operator-ns and --services-ns defined."
    TARGET_NAMESPACE=$OPERATOR_NAMESPACE
  fi
}

function print_usage() {
  echo "Usage: ${script_name} --<service> --operator-ns <operator ns> --services-ns <services ns> [OPTIONS]..."
  echo ""
  echo "Deploy the necessary resources for Backup of Keycloak."
  echo ""
  echo "Options:"
  echo " --operator-ns string                             Optional. Operator namespace for a given CPFS installation. Only required if --util specified"
  echo " --services-ns string                             Required. Namespace where IM EDB, IM Mongo, Zen, or Keycloak operands are installed. If installed in different namespaces, script will need to be run separately. Optional if it is the same as --operator-ns."
  echo " --tethered-ns string                             Optional. Comma-delimited list of namespaces attached to a given CPFS install. Should include any namespace from a given tenant in the common-service-maps cm that are not the --operator-ns or the --services-ns. Only required when --util specified."
  echo " --lsr-ns string                                  Optional. Namespace for the License Service Reporter install. Required if --lsr specified."
  echo " --im, --mongo, --keycloak, --zen, --zen4, --lsr  Required. Choose which component(s) to deploy backup/restore resources for to the target namespace. At least one is required. Multiple can be specified but only one of --zen or --zen4 can be chosen."
  echo " --util                                           Optional. Deploy the CPFS Util job for use in SOD topologies. If this option is selected, --operator-ns and --services-ns are both required."
  echo " --storage-class string                           Optional. Storage class to use for backup/restore resources. Default value is cluster's default storage class."
  echo " -c, --cleanup                                    Optional. Automated cleanup of backup/restore resources. Will run cleanup instead of deployment logic."
  echo " -h, --help                                       Print usage information"
  echo ""
}

function deploy_resources(){
  if [[ $STORAGE_CLASS == "default" ]]; then
    STORAGE_CLASS=$(oc get sc | grep default | awk '{print $1}')
    info "Using default storage class $STORAGE_CLASS."
  else
    info "Using specified storage class $STORAGE_CLASS."
  fi

  #deploy IM EDB resources
  if [[ $IM == "true" ]]; then
    info "Creating IM Backup/Restore resources in namespace $TARGET_NAMESPACE."
    
    rm -rf tmp/common-service-db/
    mkdir tmp/common-service-db
    cp common-service-db/cs-db-backup-deployment.yaml tmp/common-service-db/cs-db-backup-deployment.yaml
    cp common-service-db/cs-db-backup-pvc.yaml tmp/common-service-db/cs-db-backup-pvc.yaml
    cp common-service-db/cs-db-role.yaml tmp/common-service-db/cs-db-role.yaml
    cp common-service-db/cs-db-rolebinding.yaml tmp/common-service-db/cs-db-rolebinding.yaml
    cp common-service-db/cs-db-sa.yaml tmp/common-service-db/cs-db-sa.yaml
    cp common-service-db/cs-db-br-script-cm.yaml tmp/common-service-db/cs-db-br-script-cm.yaml

    sed -i -E "s/<cs-db namespace>/$TARGET_NAMESPACE/" tmp/common-service-db/cs-db-backup-deployment.yaml
    sed -i -E "s/<cs-db namespace>/$TARGET_NAMESPACE/" tmp/common-service-db/cs-db-backup-pvc.yaml
    sed -i -E "s/<storage class>/$STORAGE_CLASS/" tmp/common-service-db/cs-db-backup-pvc.yaml
    sed -i -E "s/<cs-db namespace>/$TARGET_NAMESPACE/" tmp/common-service-db/cs-db-role.yaml
    sed -i -E "s/<cs-db namespace>/$TARGET_NAMESPACE/" tmp/common-service-db/cs-db-rolebinding.yaml
    sed -i -E "s/<cs-db namespace>/$TARGET_NAMESPACE/" tmp/common-service-db/cs-db-sa.yaml
    sed -i -E "s/<cs-db namespace>/$TARGET_NAMESPACE/" tmp/common-service-db/cs-db-br-script-cm.yaml
    oc apply -f tmp/common-service-db -n $TARGET_NAMESPACE || error "Unable to deploy resources for IM."
    success "Resources to backup IM deployed in namespace $TARGET_NAMESPACE."
  fi

  #Deploy IM Mongo resources
  if [[ $MONGO == "true" ]]; then
    info "Creating IM Mongo Backup/Restore resources in namespace $TARGET_NAMESPACE."
    
    rm -rf tmp/mongo
    mkdir tmp/mongo
    cp mongodb-backup-deployment.yaml tmp/mongo/mongodb-backup-deployment.yaml
    cp mongodb-backup-pvc.yaml tmp/mongo/mongodb-backup-pvc.yaml

    sed -i -E "s~<mongo namespace>~$TARGET_NAMESPACE~g" tmp/mongo/mongodb-backup-deployment.yaml
    sed -i -E "s/<mongo namespace>/$TARGET_NAMESPACE/" tmp/mongo/mongodb-backup-pvc.yaml
    sed -i -E "s/<storage class>/$STORAGE_CLASS/" tmp/mongo/mongodb-backup-pvc.yaml
    oc apply -f tmp/mongo/mongodb-backup-deployment.yaml -f tmp/mongo/mongodb-backup-pvc.yaml -n $TARGET_NAMESPACE || error "Unable to deploy resources for IM Mongo."
    success "Resources to backup IM Mongo deployed in namespace $TARGET_NAMESPACE."
  fi

  #Deploy Keycloak resources
  if [[ $KEYCLOAK == "true" ]]; then 
    info "Creating Keycloak Backup/Restore resources in namespace $TARGET_NAMESPACE."
    
    rm -rf tmp/keycloak/
    mkdir tmp/keycloak
    cp keycloak/keycloak-backup-deployment.yaml tmp/keycloak/keycloak-backup-deployment.yaml
    cp keycloak/keycloak-backup-pvc.yaml tmp/keycloak/keycloak-backup-pvc.yaml
    cp keycloak/keycloak-role.yaml tmp/keycloak/keycloak-role.yaml
    cp keycloak/keycloak-rolebinding.yaml tmp/keycloak/keycloak-rolebinding.yaml
    cp keycloak/keycloak-sa.yaml tmp/keycloak/keycloak-sa.yaml
    cp keycloak/keycloak-br-script-cm.yaml tmp/keycloak/keycloak-br-script-cm.yaml
    
    sed -i -E "s/<keycloak namespace>/$TARGET_NAMESPACE/" tmp/keycloak/keycloak-backup-deployment.yaml
    sed -i -E "s/<keycloak namespace>/$TARGET_NAMESPACE/" tmp/keycloak/keycloak-backup-pvc.yaml
    sed -i -E "s/<storage class>/$STORAGE_CLASS/" tmp/keycloak/keycloak-backup-pvc.yaml
    sed -i -E "s/<keycloak namespace>/$TARGET_NAMESPACE/" tmp/keycloak/keycloak-role.yaml
    sed -i -E "s/<keycloak namespace>/$TARGET_NAMESPACE/" tmp/keycloak/keycloak-rolebinding.yaml
    sed -i -E "s/<keycloak namespace>/$TARGET_NAMESPACE/" tmp/keycloak/keycloak-sa.yaml
    sed -i -E "s/<keycloak namespace>/$TARGET_NAMESPACE/" tmp/keycloak/keycloak-br-script-cm.yaml
    oc apply -f tmp/keycloak -n $TARGET_NAMESPACE || error "Unable to deploy resources for Keycloak."
    success "Resources to backup Keycloak deployed in namespace $TARGET_NAMESPACE."
  fi

  #Deploy zen 5 resources
  if [[ $ZEN == "true" ]]; then
    if [[ $ZENSERVICE == "" ]]; then
      ZENSERVICE=$(oc get zenservice -n $TARGET_NAMESPACE --no-headers | awk '{print $1}')
    fi
    if [[ $ZENSERVICE != "" ]]; then
      exists=$(oc get zenservice $ZENSERVICE -n $TARGET_NAMESPACE --no-headers --ignore-not-found)
      if [[ $exists == "" ]]; then
        warning "Zenservice $ZENSERVICE not found in namespace $TARGET_NAMESPACE. Make sure the zenservice is deployed to the target namespace $TARGET_NAMESPACE or change the namespace used."
      else
        info "Creating Zen Backup/Restore resources in namespace $TARGET_NAMESPACE."
        
        rm -rf tmp/zen/
        mkdir tmp/zen
        cp zen5-backup-deployment.yaml tmp/zen/zen5-backup-deployment.yaml
        cp zen5-backup-pvc.yaml tmp/zen/zen5-backup-pvc.yaml
        cp zen5-role.yaml tmp/zen/zen5-role.yaml
        cp zen5-rolebinding.yaml tmp/zen/zen5-rolebinding.yaml
        cp zen5-sa.yaml tmp/zen/zen5-sa.yaml
        cp zen5-br-scripts-cm.yaml tmp/zen/zen5-br-scripts-cm.yaml

        sed -i -E "s/<zenservice namespace>/$TARGET_NAMESPACE/" tmp/zen/zen5-backup-deployment.yaml
        sed -i -E "s/<zenservice name>/$ZENSERVICE/" tmp/zen/zen5-backup-deployment.yaml
        sed -i -E "s/<zenservice namespace>/$TARGET_NAMESPACE/" tmp/zen/zen5-backup-pvc.yaml
        sed -i -E "s/<storage class>/$STORAGE_CLASS/" tmp/zen/zen5-backup-pvc.yaml
        sed -i -E "s/<zenservice namespace>/$TARGET_NAMESPACE/" tmp/zen/zen5-role.yaml
        sed -i -E "s/<zenservice namespace>/$TARGET_NAMESPACE/" tmp/zen/zen5-rolebinding.yaml
        sed -i -E "s/<zenservice namespace>/$TARGET_NAMESPACE/" tmp/zen/zen5-sa.yaml
        sed -i -E "s/<zenservice namespace>/$TARGET_NAMESPACE/" tmp/zen/zen5-br-scripts-cm.yaml
        oc apply -f tmp/zen -n $TARGET_NAMESPACE || error "Unable to deploy resources for Zen 5."   
        success "Resources to backup Zen deployed in namespace $TARGET_NAMESPACE."
      fi
    else
      warning "No zenservice found in namespace $TARGET_NAMESPACE. Skipping."
    fi
  fi

  #deploy zen 4 resources
  if [[ $ZEN4 == "true" ]]; then
    if [[ $ZENSERVICE == "" ]]; then
      ZENSERVICE=$(oc get zenservice -n $TARGET_NAMESPACE --no-headers | awk '{print $1}')
    fi
    if [[ $ZENSERVICE != "" ]]; then
      exists=$(oc get zenservice $ZENSERVICE -n $TARGET_NAMESPACE --no-headers --ignore-not-found)
      if [[ $exists == "" ]]; then
        error "Zenservice $ZENSERVICE not found in namespace $TARGET_NAMESPACE. Make sure the zenservice is deployed to the target namespace $TARGET_NAMESPACE or change the namespace used."
      else
        info "Creating Zen Backup/Restore resources in namespace $TARGET_NAMESPACE."
        
        rm -rf tmp/zen4
        mkdir tmp/zen4
        cp zen-backup-deployment.yaml tmp/zen4/zen-backup-deployment.yaml
        cp zen-backup-pvc.yaml tmp/zen4/zen-backup-pvc.yaml
        cp zen4-role.yaml tmp/zen4/zen4-role.yaml
        cp zen4-rolebinding.yaml tmp/zen4/zen4-rolebinding.yaml
        cp zen4-sa.yaml tmp/zen4/zen4-sa.yaml
        cp zen4-br-scripts.yaml tmp/zen4/zen4-br-scripts.yaml
        
        sed -i -E "s/<zenservice namespace>/$TARGET_NAMESPACE/" tmp/zen4/zen-backup-deployment.yaml
        sed -i -E "s/<zenservice namespace>/$TARGET_NAMESPACE/" tmp/zen4/zen-backup-pvc.yaml
        sed -i -E "s/<storage class>/$STORAGE_CLASS/" tmp/zen4/zen-backup-pvc.yaml
        sed -i -E "s/<zenservice namespace>/$TARGET_NAMESPACE/" tmp/zen4/zen4-role.yaml
        sed -i -E "s/<zenservice namespace>/$TARGET_NAMESPACE/" tmp/zen4/zen4-rolebinding.yaml
        sed -i -E "s/<zenservice namespace>/$TARGET_NAMESPACE/" tmp/zen4/zen4-sa.yaml
        sed -i -E "s/<zenservice namespace>/$TARGET_NAMESPACE/" tmp/zen4/zen4-br-scripts.yaml
        oc apply -f tmp/zen4/ -n $TARGET_NAMESPACE || error "Unable to deploy resources for Zen 4."
      fi        
    fi
    success "Resources to backup Zen 4 deployed in namespace $TARGET_NAMESPACE."
  fi
  
  success "Backup/Restore resources created in namespace $TARGET_NAMESPACE."

  #Deploy cpfs-util resources
  if [[ $UTIL == "true" ]]; then
    info "Creating CPFS Util Backup/Restore resources in namespace $OPERATOR_NAMESPACE."
    
    rm -rf tmp/cpfs-util-resources
    mkdir tmp/cpfs-util-resources
    cp ../spectrum-fusion/cpfs-util-resources/cpfs-util-deployment.yaml tmp/cpfs-util-resources/cpfs-util-deployment.yaml
    cp ../spectrum-fusion/cpfs-util-resources/cpfs-util-role.yaml tmp/cpfs-util-resources/cpfs-util-role.yaml
    cp ../spectrum-fusion/cpfs-util-resources/cpfs-util-rolebinding.yaml tmp/cpfs-util-resources/cpfs-util-rolebinding.yaml
    cp ../spectrum-fusion/cpfs-util-resources/cpfs-util-sa.yaml tmp/cpfs-util-resources/cpfs-util-sa.yaml
    cp ../spectrum-fusion/cpfs-util-resources/cpfs-util-services-role.yaml tmp/cpfs-util-resources/cpfs-util-services-role.yaml
    cp ../spectrum-fusion/cpfs-util-resources/cpfs-util-services-rolebinding.yaml tmp/cpfs-util-resources/cpfs-util-services-rolebinding.yaml
    

    cp ../spectrum-fusion/cpfs-util-resources/setup-tenant-job.yaml tmp/cpfs-util-resources/setup-tenant-job.yaml
    cp ../spectrum-fusion/cpfs-util-resources/setup-tenant-job-configmap.yaml tmp/cpfs-util-resources/setup-tenant-job-configmap.yaml
    cp ../spectrum-fusion/cpfs-util-resources/setup-tenant-job-pvc.yaml tmp/cpfs-util-resources/setup-tenant-job-pvc.yaml
    cp ../spectrum-fusion/cpfs-util-resources/setup-tenant-job-role.yaml tmp/cpfs-util-resources/setup-tenant-job-role.yaml
    cp ../spectrum-fusion/cpfs-util-resources/setup-tenant-job-rolebinding.yaml tmp/cpfs-util-resources/setup-tenant-job-rolebinding.yaml
    cp ../spectrum-fusion/cpfs-util-resources/setup-tenant-job-sa.yaml tmp/cpfs-util-resources/setup-tenant-job-sa.yaml
    cp ../spectrum-fusion/cpfs-util-resources/setup-tenant-job-serv-tethered-role.yaml tmp/cpfs-util-resources/setup-tenant-job-serv-tethered-role.yaml
    cp ../spectrum-fusion/cpfs-util-resources/setup-tenant-job-serv-tethered-rolebinding.yaml tmp/cpfs-util-resources/setup-tenant-job-serv-tethered-rolebinding.yaml

    sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/cpfs-util-deployment.yaml
    sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/cpfs-util-role.yaml
    sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/cpfs-util-rolebinding.yaml
    sed -i -E "s/<services namespace>/$TARGET_NAMESPACE/" tmp/cpfs-util-resources/cpfs-util-services-role.yaml
    sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/cpfs-util-services-rolebinding.yaml
    sed -i -E "s/<services namespace>/$TARGET_NAMESPACE/" tmp/cpfs-util-resources/cpfs-util-services-rolebinding.yaml
    sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/cpfs-util-sa.yaml
    
    sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/setup-tenant-job-configmap.yaml
    sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/setup-tenant-job-pvc.yaml
    sed -i -E "s/<storage class>/$STORAGE_CLASS/" tmp/cpfs-util-resources/setup-tenant-job-pvc.yaml
    sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/setup-tenant-job-role.yaml
    sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/setup-tenant-job-rolebinding.yaml
    sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/setup-tenant-job-sa.yaml
    sed -i -E "s/<services or tethered namespace>/$TARGET_NAMESPACE/" tmp/cpfs-util-resources/setup-tenant-job-serv-tethered-role.yaml
    sed -i -E "s/<services or tethered namespace>/$TARGET_NAMESPACE/" tmp/cpfs-util-resources/setup-tenant-job-serv-tethered-rolebinding.yaml
    sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/setup-tenant-job-serv-tethered-rolebinding.yaml
    sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/setup-tenant-job.yaml

    if [[ $TETHERED_NS != "" ]]; then
      for ns in ${TETHERED_NS//,/ }; do
        cp ../spectrum-fusion/cpfs-util-resources/setup-tenant-job-serv-tethered-role.yaml tmp/cpfs-util-resources/setup-tenant-job-serv-tethered-role-$ns.yaml
        cp ../spectrum-fusion/cpfs-util-resources/setup-tenant-job-serv-tethered-rolebinding.yaml tmp/cpfs-util-resources/setup-tenant-job-serv-tethered-rolebinding-$ns.yaml
        sed -i -E "s/<services or tethered namespace>/$ns/" tmp/cpfs-util-resources/setup-tenant-job-serv-tethered-role-$ns.yaml
        sed -i -E "s/<services or tethered namespace>/$ns/" tmp/cpfs-util-resources/setup-tenant-job-serv-tethered-rolebinding-$ns.yaml
        sed -i -E "s/<operator namespace>/$OPERATOR_NAMESPACE/" tmp/cpfs-util-resources/setup-tenant-job-serv-tethered-rolebinding-$ns.yaml
      done
    fi
    oc apply -f tmp/cpfs-util-resources || error "Unable to deploy resources for CPFS Util."
    oc patch job setup-tenant-job -n $OPERATOR_NAMESPACE -p '{"spec": { "suspend" : true }}'
    success "CPFS Util resources deployed in namespace $OPERATOR_NAMESPACE."
  fi

  #Deploy LSR resources
  if [[ $LSR == "true" ]]; then
    info "Creating License Service Reporter Backup/Restore resources in namespace $LSR_NAMESPACE."
    rm -rf tmp/license_service_reporter/
    mkdir tmp/license_service_reporter
    cp license_service_reporter/lsr-backup-deployment.yaml tmp/license_service_reporter/lsr-backup-deployment.yaml
    cp license_service_reporter/lsr-backup-pvc.yaml tmp/license_service_reporter/lsr-backup-pvc.yaml
    cp license_service_reporter/lsr-role.yaml tmp/license_service_reporter/lsr-role.yaml
    cp license_service_reporter/lsr-rolebinding.yaml tmp/license_service_reporter/lsr-rolebinding.yaml
    cp license_service_reporter/lsr-sa.yaml tmp/license_service_reporter/lsr-sa.yaml
    cp license_service_reporter/lsr-br-scripts-cm.yaml tmp/license_service_reporter/lsr-br-scripts-cm.yaml
    
    sed -i -E "s/<lsr namespace>/$LSR_NAMESPACE/" tmp/license_service_reporter/lsr-backup-deployment.yaml
    sed -i -E "s/<lsr namespace>/$LSR_NAMESPACE/" tmp/license_service_reporter/lsr-backup-pvc.yaml
    sed -i -E "s/<storage class>/$STORAGE_CLASS/" tmp/license_service_reporter/lsr-backup-pvc.yaml
    sed -i -E "s/<lsr instance namespace>/$LSR_NAMESPACE/" tmp/license_service_reporter/lsr-role.yaml
    sed -i -E "s/<lsr instance namespace>/$LSR_NAMESPACE/" tmp/license_service_reporter/lsr-rolebinding.yaml
    sed -i -E "s/<lsr instance namespace>/$LSR_NAMESPACE/" tmp/license_service_reporter/lsr-sa.yaml
    sed -i -E "s/<lsr namespace>/$LSR_NAMESPACE/" tmp/license_service_reporter/lsr-br-scripts-cm.yaml
    oc apply -f tmp/license_service_reporter -n $LSR_NAMESPACE || error "Unable to deploy resources for License Service Reporter."
    success "Resources to backup License Service Reporter deployed in namespace $LSR_NAMESPACE."
  fi

}

function cleanup() {
  title "Cleaning Backup/Restore resources deployed to namespace $TARGET_NAMESPACE."
  #clean up IM EDB BR resources
  if [[ $IM == "true" ]]; then
    info "Clean up IM BR resources..."
    oc delete deploy cs-db-backup -n $TARGET_NAMESPACE --ignore-not-found && oc delete sa cs-db-backup-sa -n $TARGET_NAMESPACE --ignore-not-found && oc delete role cs-db-backup-role -n $TARGET_NAMESPACE --ignore-not-found && oc delete rolebinding cs-db-backup-rolebinding -n $TARGET_NAMESPACE --ignore-not-found
    pod=$(oc get pod -n $TARGET_NAMESPACE --no-headers --ignore-not-found | grep cs-db-backup | awk '{print $1}' | tr "\n" " ")
    if [[ $pod != "" ]]; then
      oc delete pod $pod -n $TARGET_NAMESPACE --ignore-not-found || warning "IM backup pod not found, moving on."
    fi
    oc delete pvc cs-db-backup-pvc -n $TARGET_NAMESPACE --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        info "Failed to delete pvc cs-db-backup-pvc in $TARGET_NAMESPACE, patching its finalizer to null..."
        oc patch pvc cs-db-backup-pvc -n $TARGET_NAMESPACE --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi
    oc delete cm cs-db-br-configmap -n $TARGET_NAMESPACE --ignore-not-found
    success "IM BR resources cleaned up."
  fi

  #Clean up IM Mongo BR resources
  if [[ $MONGO == "true" ]]; then
    info "Clean up IM Mongo BR resources..."
    oc delete deploy mongodb-backup -n $TARGET_NAMESPACE --ignore-not-found && oc delete sa cs-db-backup-sa -n $TARGET_NAMESPACE --ignore-not-found && oc delete role cs-db-backup-role -n $TARGET_NAMESPACE --ignore-not-found && oc delete rolebinding cs-db-backup-rolebinding -n $TARGET_NAMESPACE --ignore-not-found
    pod=$(oc get pod -n $TARGET_NAMESPACE --no-headers --ignore-not-found | grep cs-db-backup | awk '{print $1}' | tr "\n" " ")
    if [[ $pod != "" ]]; then
      oc delete pod $pod -n $TARGET_NAMESPACE --ignore-not-found || warning "IM backup pod not found, moving on."
    fi
    oc delete pvc cs-mongodump -n $TARGET_NAMESPACE --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        info "Failed to delete pvc cs-mongodump in $TARGET_NAMESPACE, patching its finalizer to null..."
        oc patch pvc cs-mongodump -n $TARGET_NAMESPACE --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi    
    success "IM BR resources cleaned up."
  fi

  #Clean up Keycloak BR resources
  if [[ $KEYCLOAK == "true" ]]; then
    info "Clean up Keycloak BR resources..."
    oc delete deploy keycloak-backup -n $TARGET_NAMESPACE --ignore-not-found && oc delete sa keycloak-backup-sa -n $TARGET_NAMESPACE --ignore-not-found && oc delete role keycloak-backup-role -n $TARGET_NAMESPACE --ignore-not-found && oc delete rolebinding keycloak-backup-rolebinding -n $TARGET_NAMESPACE --ignore-not-found
    pod=$(oc get pod -n $TARGET_NAMESPACE --no-headers --ignore-not-found | grep keycloak-backup | awk '{print $1}' | tr "\n" " ")
    if [[ $pod != "" ]]; then
      oc delete pod $pod -n $TARGET_NAMESPACE --ignore-not-found || warning "Keycloak backup pod not found, moving on."
    fi
    oc delete pvc keycloak-backup-pvc -n $TARGET_NAMESPACE --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        info "Failed to delete pvc keycloak-backup-pvc in $TARGET_NAMESPACE, patching its finalizer to null..."
        oc patch pvc keycloak-backup-pvc -n $TARGET_NAMESPACE --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi 
    oc delete cm keycloak-br-configmap -n $TARGET_NAMESPACE --ignore-not-found
    success "IM Mongo BR resources cleaned up."
  fi

  #Clean up zen 5 BR resources
  if [[ $ZEN == "true" ]]; then
    info "Clean up Zen BR resources..."
    oc delete deploy zen5-backup -n $TARGET_NAMESPACE --ignore-not-found && oc delete sa zen5-backup-sa -n $TARGET_NAMESPACE --ignore-not-found && oc delete role zen5-backup-role -n $TARGET_NAMESPACE --ignore-not-found && oc delete rolebinding zen5-backup-rolebinding -n $TARGET_NAMESPACE --ignore-not-found
    pod=$(oc get pod -n $TARGET_NAMESPACE --no-headers --ignore-not-found | grep zen5-backup | awk '{print $1}' | tr "\n" " ")
    if [[ $pod != "" ]]; then
      oc delete pod $pod -n $TARGET_NAMESPACE --ignore-not-found || warning "Zen backup pod not found, moving on."
    fi
    oc delete pvc zen5-backup-pvc -n $TARGET_NAMESPACE --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        info "Failed to delete pvc zen5-backup-pvc in $TARGET_NAMESPACE, patching its finalizer to null..."
        oc patch pvc zen5-backup-pvc -n $TARGET_NAMESPACE --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi 
    oc delete cm zen5-br-configmap -n $TARGET_NAMESPACE --ignore-not-found
    success "Zen BR resources cleaned up."
  fi

  #clean up zen 4 BR resources
  if [[ $ZEN4 == "true" ]]; then
    info "Clean up Zen 4 BR resources..."
    oc delete deploy zen4-backup -n $TARGET_NAMESPACE --ignore-not-found && oc delete sa zen4-backup-sa -n $TARGET_NAMESPACE --ignore-not-found && oc delete role zen4-backup-role -n $TARGET_NAMESPACE --ignore-not-found && oc delete rolebinding zen4-backup-rolebinding -n $TARGET_NAMESPACE --ignore-not-found
    pod=$(oc get pod -n $TARGET_NAMESPACE --no-headers --ignore-not-found | grep zen4-backup | awk '{print $1}' | tr "\n" " ")
    if [[ $pod != "" ]]; then
      oc delete pod $pod -n $TARGET_NAMESPACE --ignore-not-found || warning "Zen 4 backup pod not found, moving on."
    fi
    oc delete pvc zen4-backup-pvc -n $TARGET_NAMESPACE --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        info "Failed to delete pvc zen4-backup-pvc in $TARGET_NAMESPACE, patching its finalizer to null..."
        oc patch pvc zen4-backup-pvc -n $TARGET_NAMESPACE --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi 
    oc delete cm zen4-br-configmap -n $TARGET_NAMESPACE --ignore-not-found
    success "Zen 4 BR resources cleaned up."
  fi

  #clean up LSR resources
  if [[ $LSR == "true" ]]; then
    info "Clean up License Service Reporter resources..."
    oc delete deploy lsr-backup -n $LSR_NAMESPACE && oc delete role lsr-backup-role -n $LSR_NAMESPACE && oc delete rolebinding lsr-backup-rolebinding -n $LSR_NAMESPACE && oc delete sa lsr-backup-sa -n $LSR_NAMESPACE && oc delete cm lsr-br-configmap -n $LSR_NAMESPACE 
    pod=$(oc get pod -n $LSR_NAMESPACE --no-headers --ignore-not-found | grep lsr-backup | awk '{print $1}' | tr "\n" " ")
    if [[ $pod != "" ]]; then
      oc delete pod $pod -n $LSR_NAMESPACE --ignore-not-found || warning "LSR backup pod not found, moving on."
    fi
    oc delete pvc lsr-backup-pvc -n $LSR_NAMESPACE --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        info "Failed to delete pvc lsr-backup-pvc in $LSR_NAMESPACE, patching its finalizer to null..."
        oc patch pvc lsr-backup-pvc -n $LSR_NAMESPACE --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi 
    success "LSR BR resources cleaned up."
  fi

  #clean up util resources
  if [[ $UTIL == "true" ]]; then
    info "Clean up Utility BR resources..."
    oc delete deploy cpfs-util -n $OPERATOR_NAMESPACE --ignore-not-found && oc delete role cpfs-util-role -n $OPERATOR_NAMESPACE --ignore-not-found && oc delete rolebinding cpfs-util-rolebinding -n $OPERATOR_NAMESPACE --ignore-not-found && oc delete sa cpfs-util-sa -n $OPERATOR_NAMESPACE --ignore-not-found
    oc delete role cpfs-util-services-role --ignore-not-found -n $TARGET_NAMESPACE && oc delete rolebinding cpfs-util-services-rolebinding --ignore-not-found -n $TARGET_NAMESPACE
    oc delete cm setup-tenant-job-configmap -n $OPERATOR_NAMESPACE --ignore-not-found && oc delete role setup-tenant-job-role -n $OPERATOR_NAMESPACE --ignore-not-found && oc delete rolebinding setup-tenant-job-rolebinding -n $OPERATOR_NAMESPACE --ignore-not-found && oc delete sa setup-tenant-job-sa -n $OPERATOR_NAMESPACE --ignore-not-found && oc delete job setup-tenant-job -n $OPERATOR_NAMESPACE --ignore-not-found
    if [[ $TETHERED_NS != "" ]]; then
      for ns in ${TETHERED_NS//,/ }; do
        oc delete role setup-tenant-job-role -n $ns --ignore-not-found && oc delete rolebinding setup-tenant-job-rolebinding -n $ns --ignore-not-found
      done
    fi
    pod=$(oc get pod -n $OPERATOR_NAMESPACE --no-headers --ignore-not-found | grep setup-tenant | awk '{print $1}' | tr "\n" " ")
    if [[ $pod != "" ]]; then
      oc delete pod $pod -n $OPERATOR_NAMESPACE --ignore-not-found || warning "Setup tenant pod not found, moving on."
    fi
    oc delete pvc setup-tenant-job-pvc -n $OPERATOR_NAMESPACE --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        info "Failed to delete pvc setup-tenant-job-pvc in $OPERATOR_NAMESPACE, patching its finalizer to null..."
        oc patch pvc setup-tenant-job-pvc -n $OPERATOR_NAMESPACE --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi 
    success "Utility BR resources cleaned up."
  fi
  
  success "BR resources succesfully removed from namespace $TARGET_NAMESPACE."
}

function save_log(){
  local LOG_DIR="$1"
  LOG_FILE="$LOG_DIR/$2_$(date +'%Y%m%d%H%M%S').log"

  if [[ ! -d $LOG_DIR ]]; then
      mkdir -p "$LOG_DIR"
  fi

  # Create a named pipe
  PIPE=$(mktemp -u)
  mkfifo "$PIPE"

  # Tee the output to both the log file and the terminal
  tee "$LOG_FILE" < "$PIPE" &

  # Redirect stdout and stderr to the named pipe
  exec > "$PIPE" 2>&1

  # Remove the named pipe
  rm "$PIPE"
}

function cleanup_log() {
  # Check if the log file already exists
  if [[ -e $LOG_FILE ]]; then
      # Remove ANSI escape sequences from log file
      sed -E 's/\x1B\[[0-9;]+[A-Za-z]//g' "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
  fi
}

function msg() {
  printf '%b\n' "$1"
}

function success() {
  msg "\33[32m[✔] ${1}\33[0m"
}

function warning() {
  msg "\33[33m[✗] ${1}\33[0m"
}

function error() {
  msg "\33[31m[✘] ${1}\33[0m"
  exit 1
}

function title() {
  msg "\33[34m# ${1}\33[0m"
}

function info() {
  msg "[INFO] ${1}"
}

main $*
