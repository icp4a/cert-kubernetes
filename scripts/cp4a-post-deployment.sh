#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

FINAL_CR_FOLDER=${CUR_DIR}/generated-cr
PATTERN_ARR=()
OPT_COMPONENT_ARR=()
function set_global_env_vars() {
    readonly unameOut="$(uname -s)"
    case "${unameOut}" in
        Linux*)     readonly machine="Linux";;
        Darwin*)    readonly machine="Mac";;
        *)          readonly machine="UNKNOWN:${unameOut}"
    esac

    if [[ "$machine" == "Mac" ]]; then
        YQ_CMD=${CUR_DIR}/helper/yq/yq_darwin_amd64
    else
        YQ_CMD=${CUR_DIR}/helper/yq/yq_linux_amd64
    fi
}

set_global_env_vars

CMD="find $FINAL_CR_FOLDER -maxdepth 1 -name \"ibm_cp4a_cr_final.yaml\" -print"
if $CMD ; then
  echo -e "\x1B[1mShowing the access information and User credentials\x1B[0m"

  pattern_file=$(find $FINAL_CR_FOLDER -maxdepth 1 -name "ibm_cp4a_cr_final.yaml" -print)
  if [ -z $pattern_file ]; then
    echo -e "\x1B[1;31mCan not find Custom Resource file \"ibm_cp4a_cr_final.yaml\" under $FINAL_CR_FOLDER\x1B[0m"
    echo -e "\x1B[1;31mPlease run cp4a-deployment.sh script to deploy pattern firstly\x1B[0m"
    exit 1
  fi

  pattern_name=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_deployment_patterns)
  OIFS=$IFS
  IFS=',' read -r -a PATTERN_ARR <<< "$pattern_name"
  IFS=$OIFS

  # metadata_name=$(grep -A1 'metadata:' $pattern_file | tail -n1); metadata_name=${metadata_name//*name: /}
  metadata_name=$(${YQ_CMD} r $pattern_file metadata.name)
  optional_components=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_optional_components)
  deployment_type=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_deployment_type)
  platform_type=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_deployment_platform)
  graphql_flag=$(${YQ_CMD} r $pattern_file spec.ecm_configuration.graphql.graphql_production_setting.enable_graph_iql)

  OIFS=$IFS
  IFS=',' read -r -a OPT_COMPONENT_ARR <<< "$optional_components"
  IFS=$OIFS

else
  echo -e "\x1B[1;31mCan not find Custom Resource file \"ibm_cp4a_cr_final.yaml\" under $FINAL_CR_FOLDER\x1B[0m"
  echo -e "\x1B[1;31mPlease run cp4a-deployment.sh script to deploy pattern firstly\x1B[0m"
  exit 1
fi

function validate_cli(){
    which oc &>/dev/null
    [[ $? -ne 0 ]] && \
        echo "Unable to locate an OpenShift CLI. You must install it to run this script." && \
        exit 1
}

function containsElement () {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

function check_ocp_version(){
    if [[ ${platform_type} == "ROKS" ]];then
        temp_ver=`oc version | grep v[1-9]\.[1-9][1-9] | tail -n1`
        if [[ $temp_ver == *"Kubernetes Version"* ]]; then
            currentver="${temp_ver:20:7}"
        else
            currentver="${temp_ver:11:7}"
        fi
        requiredver="v1.18.1"
        if [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" = "$requiredver" ]; then
            INGRESS_COLUMN=3
            ROKS_VERSION="4.5OrLater"
        else
            INGRESS_COLUMN=2
            ROKS_VERSION="4.4OrOlder"
        fi
    fi
}

# Display Gitea route URL and credentail, shared by document_processing and decisions_ads pattern
function display_gitea_routes_credentails() {
    if [[ $deployment_type == "demo" ]]; then
      echo -e "\x1B[1mYou can access Gitea using the following URL:\x1B[0m"
      echo -e "https://$(oc get routes --no-headers | grep gitea-route | awk {'print $2'})"
      echo "User credentials:"
      echo "================="
      echo
      echo -n "Default Gitea username: "; oc get secret ${metadata_name}-gitea-secret -o jsonpath='{ .data.gitea_user_name}' | base64 --decode; echo
      echo -n "Default Gitea password: "; oc get secret ${metadata_name}-gitea-secret -o jsonpath='{ .data.gitea_user_password}' | base64 --decode; echo
    fi
}

function display_content_routes_credentials() {
    if [ -z "$graphql_flag" ]; then
      graphql_val="false"
    else
      graphql_val=$(echo "$graphql_flag" | tr '[:upper:]' '[:lower:]')
    fi
    isIngressEnabed=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_ingress_enable)
    printf "\n"
    echo -e "\x1B[1mYou can access ACCE and Navigator using the following URLs:\x1B[0m"

    if [ "$isIngressEnabed" = "true" ]; then
      echo -e "https://$(oc get ingress --no-headers | grep fncm-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/acce"
      if [[ "$graphql_val" == "true" ]]; then
        echo -e "https://$(oc get ingress --no-headers | grep fncm-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/content-services-graphql"
      fi
      if [[ " ${OPT_COMPONENT_ARR[@]} " =~ "cmis" ]]; then
        echo -e "https://$(oc get ingress --no-headers | grep fncm-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/openfncmis_wlp"
      fi
      echo -e "https://$(oc get ingress --no-headers | grep ban-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/navigator"
    else
      echo -e "https://$(oc get routes --no-headers | grep cpe-route | awk {'print $2'})/acce"
      echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator"
      if [[ "$graphql_val" == "true" ]]; then
        echo -e "https://$(oc get routes --no-headers | grep graphql-route | awk {'print $2'})/content-services-graphql"
      fi
      if [[ " ${OPT_COMPONENT_ARR[@]} " =~ "cmis" ]]; then
        echo -e "https://$(oc get routes --no-headers | grep cmis-route | awk {'print $2'})/openfncmis_wlp"
      fi
    fi
    echo
    if [[ $deployment_type == "demo" ]]; then
      echo "User credentials:"
      echo "================="
      echo
      echo -n "ACCE usename: "; oc get secret ibm-fncm-secret -o jsonpath='{ .data.appLoginUsername}' | base64 --decode; echo
      echo -n "ACCE user password: "; oc get secret ibm-fncm-secret -o jsonpath='{ .data.appLoginPassword}' | base64 --decode; echo
      echo
      echo -n "Navigator usename: "; oc get secret ibm-ban-secret -o jsonpath='{ .data.appLoginUsername}' | base64 --decode; echo
      echo -n "Navigator user password: "; oc get secret ibm-ban-secret -o jsonpath='{ .data.appLoginPassword}' | base64 --decode; echo
    fi
}

function display_workflow_workstreams_routes_credentials() {
  if [ "$workflowWorkstreamsDisplayed" == "false" ]; then
    isIngressEnabed=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_ingress_enable)
    printf "\n"
    echo -e "\x1B[1mYou can access Process Federated Server to see federated workflow servers using the following URL:\x1B[0m"
    if [ "$isIngressEnabed" = "true" ]; then
      echo -e "https://$(oc get ingress --no-headers | grep pfs-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/rest/bpm/federated/v1/systems"
    else
      echo -e "https://$(oc get routes --no-headers | grep pfs-route | awk {'print $2'})/rest/bpm/federated/v1/systems"
    fi
    echo
    echo
    if [[ " ${PATTERN_ARR[@]} " =~ "workflow" || " ${PATTERN_ARR[@]} " =~ "workflow-workstreams" || " ${PATTERN_ARR[@]} " =~ "document_processing" ]]; then
      echo -e "\x1B[1mYou can access Business Automation Workflow Portal, Case Client using the following URLs:\x1B[0m"
      if [ "$isIngressEnabed" = "true" ]; then
        oc get ingress --no-headers | grep baw-service | awk  -v temp=${INGRESS_COLUMN} '{print "https://"$temp"/ProcessPortal"}'
        echo -e $(oc get ingress --no-headers | grep ban-ingress | awk  -v temp=${INGRESS_COLUMN} {'print "https://"$temp"/navigator?desktop=baw"'})
      else
        oc get routes --no-headers | grep baw-server | awk '{print "https://"$2"/ProcessPortal"}'
        echo -e $(oc get routes --no-headers | grep navigator-route | awk {'print "https://"$2"/navigator?desktop=baw"'})
      fi
      echo
      echo -e "\x1B[1mTo access Portal and Case Client, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
      if [ "$isIngressEnabed" = "true" ]; then
        echo -e $(oc get ingress --no-headers | grep pfs-service | awk  -v temp=${INGRESS_COLUMN} {'print "https://"$temp'})
        oc get ingress --no-headers | grep baw-service | awk  -v temp=${INGRESS_COLUMN} '{print "https://"$temp}'
      else
        echo -e $(oc get routes --no-headers | grep pfs-route | awk {'print "https://"$2'})
        oc get routes --no-headers | grep baw-server | awk '{print "https://"$2}'
      fi
    fi
    echo
    echo
    echo -e "\x1B[1mYou can access IBM Workplace using the following URLs:\x1B[0m"
    if [ "$isIngressEnabed" = "true" ]; then
      echo -e "https://$(oc get ingress --no-headers | grep ban-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/navigator?desktop=workplace"
      echo
      echo -e "\x1B[1mTo access the IBM Workplace, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
      echo -e $(oc get ingress --no-headers | grep aae-ae-service | awk -v temp=${INGRESS_COLUMN} '$temp !~ /pbk/ {print "https://"$temp}')
      oc get ingress --no-headers | grep baw-service | awk -v temp=${INGRESS_COLUMN} '{print "https://"$temp}'
      echo -e $(oc get ingress --no-headers | grep pfs-service | awk -v temp=${INGRESS_COLUMN} {'print "https://"$temp'})
    else
      echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator?desktop=workplace"
      echo
      echo -e "\x1B[1mTo access the IBM Workplace, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
      echo -e $(oc get routes --no-headers | grep aae-ae-service | awk '$2 !~ /pbk/ {print "https://"$2}')
      oc get routes --no-headers | grep baw-server | awk '{print "https://"$2}'
      echo -e $(oc get routes --no-headers | grep pfs-route | awk {'print "https://"$2'})
    fi
    echo
    if [[ $deployment_type == "demo" ]]; then
      echo "User credentials:"
      echo "================="
      echo
      echo -n "Default administrator username: "; echo "cp4admin"
      echo -n "Default administrator password: "; pwd=$(echo $(oc get secret ${metadata_name}-openldap-customldif -o yaml | grep ldap_user.ldif | cut -d ' ' -f4) | base64 --decode | grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
    fi

    workflowWorkstreamsDisplayed="true"
  fi
}

function display_application_routes_credentials() {
    isIngressEnabed=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_ingress_enable)
    printf "\n"
    echo -e "\x1B[1mTo access Navigator, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
    if [ "$isIngressEnabed" = "true" ]; then
      aae_ae_service="$(oc get ingress --no-headers | grep aae-ae-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
      if [[ -n "$aae_ae_service" ]]; then
        echo -e "https://$aae_ae_service/"
      fi
      if [[ $deployment_type == "demo" ]]; then
        echo -e "https://$(oc get ingress --no-headers | grep pbk-ae-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/"
      fi
    else
      aae_ae_service="$(oc get routes --no-headers | grep aae-ae-service | awk {'print $2'})"
      if [[ -n "$aae_ae_service" ]]; then
        echo -e "https://$aae_ae_service/"
      fi
      if [[ $deployment_type == "demo" ]]; then
        echo -e "https://$(oc get routes --no-headers | grep pbk-ae-service | awk {'print $2'})/"
      fi
    fi
    printf "\n"
    echo -e "\x1B[1mYou can access Navigator using the following URLs:\x1B[0m"
    if [ "$isIngressEnabed" = "true" ]; then
      echo -e "https://$(oc get ingress --no-headers | grep fncm-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/navigator"
    else
      echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator"
    fi
    printf "\n"
    bastudio_install=$(${YQ_CMD} r $pattern_file spec.bastudio_configuration)
    if [[ " ${OPT_COMPONENT_ARR[@]} " =~ "app_designer" || (-n "$bastudio_install") ]]; then
      echo -e "\x1B[1mTo access Business Automation Studio, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
      if [ "$isIngressEnabed" = "true" ]; then
        baw_authoring_serve="$(oc get ingress --no-headers | grep authoring-baw-server | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
        if [[ -n "$baw_authoring_serve" ]]; then
          echo -e "https://$baw_authoring_serve/"
        fi
        echo -e "https://$(oc get ingress --no-headers | grep pbk-ae-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/"
      else
        baw_authoring_serve="$(oc get routes --no-headers | grep authoring-baw-server | awk {'print $2'})"
        if [[ -n "$baw_authoring_serve" ]]; then
          echo -e "https://$baw_authoring_serve/"
        fi
        echo -e "https://$(oc get routes --no-headers | grep pbk-ae-service | awk {'print $2'})/"
      fi
      printf "\n"
      echo -e "\x1B[1mYou can access Business Automation Studio using the following URLs:\x1B[0m"
      echo -e "https://$(oc get routes --no-headers | grep ^cpd | awk {'print $2'})/"
      if [ "$isIngressEnabed" = "true" ]; then
        echo -e "https://$(oc get ingress --no-headers | grep bastudio-route | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/BAStudio"
      else
        echo -e "https://$(oc get routes --no-headers | grep bastudio-route | awk {'print $2'})/BAStudio"
      fi
    fi
    echo
    if [[ $deployment_type == "demo" ]]; then
      echo "User credentials:"
      echo "================="
      echo
      echo -n "Default administrator username: "; echo "cp4admin"
      echo -n "Default administrator password: "; pwd=$(echo $(oc get secret ${metadata_name}-openldap-customldif -o yaml | grep ldap_user.ldif | cut -d ' ' -f4) | base64 --decode | grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
    fi
 }


function getODMUrl(){
  serviceName=$1
  isIngressEnabed=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_ingress_enable)
  if [ "$serviceName" = "odm-decisioncenter" ] && [ "$isIngressEnabed" = "true" ]; then
    path="$(oc get routes --no-headers | grep ${metadata_name}-${serviceName} | awk {'print $3'} | grep '/decisioncenter$' )"
    echo "$(oc get routes --no-headers | grep ${metadata_name}-${serviceName} | grep '/decisioncenter '| awk {'print $2'})$path"
  else
    path=''
    if [ "$isIngressEnabed" = "true" ]; then
      path=$(oc get routes --no-headers | grep ${metadata_name}-${serviceName} | awk {'print $3'})
    fi
    echo "$(oc get routes --no-headers | grep ${metadata_name}-${serviceName} | awk {'print $2'})$path"
  fi
}

function display_decisions_routes_credentials() {

    echo -e "\x1B[1mYou can access Operational Decision Manager using the following URLs:\x1B[0m"
    isDsrEnabled=$(${YQ_CMD} r $pattern_file spec.odm_configuration.decisionServerRuntime.enabled)
    isDrEnabled=$(${YQ_CMD} r $pattern_file spec.odm_configuration.decisionRunner.enabled)
    if [ $(${YQ_CMD} r $pattern_file spec.odm_configuration.decisionCenter.enabled) == true ]; then
      echo -e "\x1B[1mTo access Decision Center console, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
      echo -e "https://$(getODMUrl 'odm-decisioncenter')"
    fi
    if  [[ $isDsrEnabled == true || $isDrEnabled == true ]]; then
      echo -e "\x1B[1mTo access Decision Server Console, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
      echo -e "https://$(getODMUrl 'odm-decisionserverconsole')"
    fi
    if  [[ $isDsrEnabled == true ]]; then
      echo -e "\x1B[1mTo access Decision Server Runtime, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
      echo -e "https://$(getODMUrl 'odm-decisionserverruntime')"
    fi
    if  [[ $isDrEnabled == true ]]; then
      echo -e "\x1B[1mTo access Decision Runner, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
      echo -e "https://$(getODMUrl 'odm-decisionrunner')"
    fi

    if [[ ! "$optional_components" =~ "ums" ]] || [ $deployment_type == "demo" ]; then
    echo
    echo "User credentials:"
    echo "================"
    echo
    echo -n "Default administrator username: "; echo "odmAdmin"
    echo -n "Default administrator password: "; echo "odmAdmin"
    fi
}
function display_decisions_ads_routes_credentials() {
    isIngressEnabed=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_ingress_enable)
    printf "\n"
    if [[ " ${OPT_COMPONENT_ARR[@]} " =~ "ads_designer" ]]; then
        echo -e "\x1B[1mYou can access ADS Designer using the Business Automation Studio URL:\x1B[0m"
        echo -e "https://$(oc get routes --no-headers | grep ^cpd | awk {'print $2'})/"
        if [ "$isIngressEnabed" = "true" ]; then
          echo -e "https://$(oc get ingress --no-headers | grep bastudio-route | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/BAStudio"
        else
          echo -e "https://$(oc get routes --no-headers | grep bastudio-route | awk {'print $2'})/BAStudio"
        fi
        if [ "$(${YQ_CMD} r $pattern_file spec.ads_configuration.decision_designer.embedded_build_and_run.enabled)" != "false" ]; then
          echo -e "\x1B[1mYou can access ADS Embedded Runtime swagger URL (UMS authentication):\x1B[0m"
          if [ "$isIngressEnabed" = "true" ]; then
            echo -e "https://$(oc get ingress --no-headers | grep embedded-runtime-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/api/swagger-ui"
          else
            echo -e "https://$(oc get routes --no-headers | grep embedded-runtime-service | awk {'print $2'})/api/swagger-ui"
          fi
        fi
        echo
        if [[ ${deployment_type} == "demo" ]]; then
            echo "User credentials:"
            echo "================="
            echo
            echo -n "Default administrator username: "; echo "cp4admin"
            echo -n "Default administrator password: "; pwd=$(echo $(oc get secret ${metadata_name}-openldap-customldif -o yaml | grep ldap_user.ldif | cut -d ' ' -f4) | base64 --decode | grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
            echo
        fi
        display_gitea_routes_credentails
    fi
    if [[ " ${OPT_COMPONENT_ARR[@]} " =~ "ads_runtime" ]]; then
        echo -e "\x1B[1mYou can access ADS Runtime swagger URL:\x1B[0m"
        if [ "$isIngressEnabed" = "true" ]; then
          echo -e "https://$(oc get ingress --no-headers | grep ads-runtime-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/api/swagger-ui"
        else
          echo -e "https://$(oc get routes --no-headers | grep ads-runtime-service | awk {'print $2'})/api/swagger-ui"
        fi

        echo
        echo "User credentials (for execution):"
        echo "================================="
        echo
        echo -n "username: "; oc get secret ibm-dba-ads-runtime-secret -o jsonpath='{ .data.decisionRuntimeUser}' | base64 --decode; echo
        echo -n "password: "; oc get secret ibm-dba-ads-runtime-secret -o jsonpath='{ .data.decisionRuntimePassword}' | base64 --decode; echo
        echo
    fi
}


function display_bai_routes_credentials() {
    isIngressEnabed=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_ingress_enable)

    echo -e "\x1B[1mYou can access Business Performance Center using the following URL:\x1B[0m"
    if [ "$isIngressEnabed" = "true" ]; then
        echo -e "https://$(oc get ingress --no-headers | grep bai-business-performance-center-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
    else
        echo -e "https://$(oc get routes --no-headers | grep ${metadata_name}-bai-business-performance-center-route | awk {'print $2'})"
    fi
    if [[ ${deployment_type} == "demo" ]]; then
        echo "User credentials:"
        echo "================="
        echo
        echo -n "Default administrator username: "; echo "cp4admin"
        echo -n "Default administrator password: "; pwd=$(echo $(oc get secret ${metadata_name}-openldap-customldif -o yaml | grep ldap_user.ldif | cut -d ' ' -f4) | base64 --decode | grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
    fi

    nav_installed=$(${YQ_CMD} r $pattern_file spec.navigator_configuration)
    if [[ -n "${nav_installed}" ]]; then
      echo -e "\x1B[1mTo access Business Performance Center in Content Navigator, first go to the instance of Business Performance Center that is shown just above and accept the self-signed certificate.\x1B[0m"
      echo -e "\x1B[1mThen you can access Business Performance Center by using the following URL:\x1B[0m"
      if [ "$isIngressEnabed" = "true" ]; then
        echo -e "https://$(oc get ingress --no-headers | grep ban-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/navigator?desktop=BAI"
      else
        echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator?desktop=BAI"
      fi
      if [[ $deployment_type == "demo" ]]; then
        echo "User credentials:"
        echo "================="
        echo
        echo -n "Navigator username: "; oc get secret ibm-ban-secret -o jsonpath='{ .data.appLoginUsername}' | base64 --decode; echo
        echo -n "Navigator password: "; oc get secret ibm-ban-secret -o jsonpath='{ .data.appLoginPassword}' | base64 --decode; echo
      fi
    fi

    echo -e "\x1B[1mYou can access Admin API using the following URL:\x1B[0m"
    if [ "$isIngressEnabed" = "true" ]; then
        echo -e "https://$(oc get ingress --no-headers | grep bai-admin-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
    else
        echo -e "https://$(oc get routes --no-headers | grep ${metadata_name}-bai-admin-route | awk {'print $2'})"
    fi
    if [[ $deployment_type == "demo" ]]; then
      echo
      echo "User credentials:"
      echo "================="
      echo
      echo -n "Default username: "; oc get secret ${metadata_name}-bai-secret-internal -o jsonpath='{ .data.admin-username}' | base64 --decode; echo
      echo -n "Default password: "; oc get secret ${metadata_name}-bai-secret-internal -o jsonpath='{ .data.admin-password}' | base64 --decode; echo
      echo
    fi

    echo -e "\x1B[1mYou can access Management API using the following URL:\x1B[0m"
    if [ "$isIngressEnabed" = "true" ]; then
        echo -e "https://$(oc get ingress --no-headers | grep bai-management-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
    else
        echo -e "https://$(oc get routes --no-headers | grep ${metadata_name}-bai-management-route | awk {'print $2'})"
    fi
    if [[ $deployment_type == "demo" ]]; then
      echo
      echo "User credentials:"
      echo "================="
      echo
      echo -n "Default username: "; oc get secret ${metadata_name}-bai-secret-internal -o jsonpath='{ .data.management-username}' | base64 --decode; echo
      echo -n "Default password: "; oc get secret ${metadata_name}-bai-secret-internal -o jsonpath='{ .data.management-password}' | base64 --decode; echo
    fi
}

function display_workflow_authoring_routes_credentials() {
    isIngressEnabed=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_ingress_enable)
    printf "\n"
    echo -e "\x1B[1mYou can access Process Federated Server to see federated workflow servers using the following URL:\x1B[0m"
    if [ "$isIngressEnabed" = "true" ]; then
      echo -e "https://$(oc get ingress --no-headers | grep pfs-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/rest/bpm/federated/v1/systems"
    else
      echo -e "https://$(oc get routes --no-headers | grep pfs-route | awk {'print $2'})/rest/bpm/federated/v1/systems"
    fi
    echo
    if [[ $item == "workflow" || $item == "workflow-workstreams" ]]; then
      echo -e "\x1B[1mYou can access Business Automation Studio, Business Automation Workflow Portal, Case Client, and IBM Workplace using the following URLs:\x1B[0m"
      echo -e "https://$(oc get routes --no-headers | grep ^cpd | awk {'print $2'})/"
      if [ "$isIngressEnabed" = "true" ]; then
        echo -e "https://$(oc get ingress --no-headers | grep bastudio-route | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/BAStudio"
        echo -e "https://$(oc get ingress --no-headers | grep baw-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/ProcessPortal"
        echo -e "https://$(oc get ingress --no-headers | grep ban-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/navigator?desktop=baw"
        echo -e "https://$(oc get ingress --no-headers | grep ban-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/navigator?desktop=workplace"
        echo
        echo -e "\x1B[1mTo access IBM Workplace, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
        echo -e "https://$(oc get ingress --no-headers | grep aae-ae-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
        echo -e "https://$(oc get ingress --no-headers | grep baw-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
        echo -e "https://$(oc get ingress --no-headers | grep pfs-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
        echo
        echo -e "\x1B[1mTo access Workflow Portal and Case Client, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
        echo -e "https://$(oc get ingress --no-headers | grep pfs-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
        echo -e "https://$(oc get ingress --no-headers | grep baw-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
        echo
        echo -e "\x1B[1mTo access Business Automation Studio, first go to the following URL and accept the self-signed certificate:\x1B[0m"
        echo -e "https://$(oc get ingress --no-headers | grep baw-service | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
      else
        echo -e "https://$(oc get routes --no-headers | grep bastudio-route | awk {'print $2'})/BAStudio"
        echo -e "https://$(oc get routes --no-headers | grep baw-service | awk {'print $2'})/ProcessPortal"
        echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator?desktop=baw"
        echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator?desktop=workplace"
        echo
        echo -e "\x1B[1mTo access IBM Workplace, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
        echo -e "https://$(oc get routes --no-headers | grep aae-ae-service | awk {'print $2'})"
        echo -e "https://$(oc get routes --no-headers | grep baw-service | awk {'print $2'})"
        echo -e "https://$(oc get routes --no-headers | grep pfs-service | awk {'print $2'})"
        echo
        echo -e "\x1B[1mTo access Workflow Portal and Case Client, first go to the following URLs and accept the self-signed certificates:\x1B[0m"
        echo -e "https://$(oc get routes --no-headers | grep pfs-service | awk {'print $2'})"
        echo -e "https://$(oc get routes --no-headers | grep baw-service | awk {'print $2'})"
        echo
        echo -e "\x1B[1mTo access Business Automation Studio, first go to the following URL and accept the self-signed certificate:\x1B[0m"
        echo -e "https://$(oc get routes --no-headers | grep baw-service | awk {'print $2'})"
      fi
    fi
    echo
    if [[ $deployment_type == "demo" ]]; then
      echo "User credentials:"
      echo "================="
      echo
      echo -n "Default administrator username: "; echo "cp4admin"
      echo -n "Default administrator password: "; pwd=$(echo $(oc get secret ${metadata_name}-openldap-customldif -o yaml | grep ldap_user.ldif | cut -d ' ' -f4) | base64 --decode | grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
    fi

}

function display_document_processing_routes_credentials() {
  isIngressEnabed=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_ingress_enable)
  printf "\n"
  echo -e "\x1B[1mYou can access Content Project Deployment Service using the following URLs:\x1B[0m"
  if [[ (" ${OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer") || (" ${OPT_COMPONENT_ARR[@]} " =~ "document_processing_runtime") ]]; then
    if [ "$isIngressEnabed" = "true" ]; then
      echo -e "https://$(oc get ingress --no-headers | grep fncm-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
    else
      echo -e "https://$(oc get routes --no-headers | grep cpds-route | awk {'print $2'})"
    fi

    echo
    if [[ $deployment_type == "demo" ]]; then
      if [[ (" ${OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer") ]]; then
        echo -e "\x1B[1mYou can access Business Automation Studio using the following URLs:\x1B[0m"
        echo -e "https://$(oc get routes --no-headers | grep ^cpd | awk {'print $2'})/"
        if [ "$isIngressEnabed" = "true" ]; then
          echo -e "https://$(oc get ingress --no-headers | grep bastudio-route | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/BAStudio"
        else
          echo -e "https://$(oc get routes --no-headers | grep bastudio-route | awk {'print $2'})/BAStudio"
        fi
      fi
      echo
      echo "User credentials:"
      echo "================="
      echo
      echo -n "Default administrator username: "; echo "cp4admin"
      echo -n "Default administrator password: "; pwd=$(echo $(oc get secret ${metadata_name}-openldap-customldif -o yaml | grep ldap_user.ldif | cut -d ' ' -f4) | base64 --decode | grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
    fi
  fi
  display_gitea_routes_credentails
  display_content_routes_credentials
}

function display_ier_routes_credentials() {
    isIngressEnabed=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_ingress_enable)
    printf "\n"
    echo -e "\x1B[1mYou can access IER using the following URL:\x1B[0m" 

    if [ "$isIngressEnabed" = "true" ]; then
      echo -e "https://$(oc get ingress --no-headers | grep ier-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/EnterpriseRecordsPlugin/IERApplicationPlugin.jar"
    else
      echo -e "https://$(oc get routes --no-headers | grep ier-route | awk {'print $2'})/EnterpriseRecordsPlugin/IERApplicationPlugin.jar"
    fi
}

function display_iccsap_routes_credentials() {
    isIngressEnabed=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_ingress_enable)
    printf "\n"
    echo -e "\x1B[1mYou can access ICCSAP using the following URL:\x1B[0m" 

    if [ "$isIngressEnabed" = "true" ]; then
      echo -e "SSL Webport: https://$(oc get ingress --no-headers | grep iccsap-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})"
      echo -e "Plugin: https://$(oc get ingress --no-headers | grep iccsap-ingress | awk -v temp=${INGRESS_COLUMN} {'print $temp'})/files"
    else
      echo -e "SSL Webport: https://$(oc get routes --no-headers | grep iccsap-ssl-webport-route | awk {'print $2'})"
      echo -e "Plugin: https://$(oc get routes --no-headers | grep iccsap-plugin-route | awk {'print $2'})/files"
    fi
}

validate_cli
check_ocp_version
# The script should check the .tmp directory for the CR that is being used and determine which pattern is deployed and call the correct function.
# Or the script should just ask the user which pattern was deployed, and then call the necessary function for that pattern.
# 1Q only supports single pattern, 2Q will search dedicated file to support multiple pattern

workflowWorkstreamsDisplayed="false"
for item in "${PATTERN_ARR[@]}"; do
    while true; do
      case "$item" in
        "content")
          display_content_routes_credentials
          break
          ;;
        "workflow"|"workstreams"|"workflow-workstreams")
          if [[ " ${OPT_COMPONENT_ARR[@]} " =~ "baw_authoring" ]]; then
            display_workflow_authoring_routes_credentials
          else
            display_workflow_workstreams_routes_credentials
          fi
          break
          ;;
        "application")
          display_application_routes_credentials
          break
          ;;
        "decisions")
          display_decisions_routes_credentials
          break
          ;;
        "decisions_ads")
          display_decisions_ads_routes_credentials
          break
          ;;
        "document_processing")
          display_document_processing_routes_credentials
          if [[ " ${OPT_COMPONENT_ARR[@]} " =~ "document_processing_workflow" ]]; then
            display_workflow_workstreams_routes_credentials
          fi
          break
          ;;
        "foundation")
          break
          ;;
      esac
    done
done

for item in "${OPT_COMPONENT_ARR[@]}"; do
    case "$item" in
        "bai")
          display_bai_routes_credentials
          break
          ;;
    esac
done

#Check if IER is in Optional Components list
for item in "${OPT_COMPONENT_ARR[@]}"; do
    case "$item" in
        "ier")
          display_ier_routes_credentials
          break
          ;;
    esac
done

#Check if ICCSAP is in Optional Components list
for item in "${OPT_COMPONENT_ARR[@]}"; do
    case "$item" in
        "iccsap")
          display_iccsap_routes_credentials
          break
          ;;
    esac
done
