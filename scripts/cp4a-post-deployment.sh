#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2020. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
CUR_DIR=$(cd $(dirname $0); pwd)
PARENT_DIR=$(dirname "$PWD")

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
  pattern_name=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_deployment_patterns)
  OIFS=$IFS
  IFS=',' read -r -a PATTERN_ARR <<< "$pattern_name"
  IFS=$OIFS

  # metadata_name=$(grep -A1 'metadata:' $pattern_file | tail -n1); metadata_name=${metadata_name//*name: /}
  metadata_name=$(${YQ_CMD} r $pattern_file metadata.name)
  optional_components=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_optional_components)
  deployment_type=$(${YQ_CMD} r $pattern_file spec.shared_configuration.sc_deployment_type)
  OIFS=$IFS
  IFS=',' read -r -a OPT_COMPONENT_ARR <<< "$optional_components"
  IFS=$OIFS

else
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

function display_content_routes_credentials() {
    echo
    echo "Below are the available routes for FileNet Content Manager:"   
    echo "==========================================================:"
    echo
    oc get routes | grep 'cmis\|cpe\|graphql\|navigator\|ums' --color=never
    echo
    echo
    echo -e "\x1B[1mYou can access ACCE and Navigator via the following URLs:\x1B[0m"
    echo -e "https://$(oc get routes --no-headers | grep cpe-route | awk {'print $2'})/acce"
    echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator"
    echo
    if [[ $deployment_type == "demo" ]]; then
      echo "User credentials:"
      echo "================"
      echo
      echo -n "ACCE usename: "; oc get secret ibm-fncm-secret -o jsonpath='{ .data.appLoginUsername}' | base64 -d; echo
      echo -n "ACCE user password: "; oc get secret ibm-fncm-secret -o jsonpath='{ .data.appLoginPassword}' | base64 -d; echo
      echo
      echo -n "Navigator usename: "; oc get secret ibm-ban-secret -o jsonpath='{ .data.appLoginUsername}' | base64 -d; echo
      echo -n "Navigator user password: "; oc get secret ibm-ban-secret -o jsonpath='{ .data.appLoginPassword}' | base64 -d; echo
    fi
}

function display_workflow_workstreams_routes_credentials() {
    echo
    if [[ $item == "workflow-workstreams" ]]; then
      echo "Below are the available routes for Business Automation Workflow & Workstreams:"
    fi
    if [[ $item == "workflow" ]]; then
      echo "Below are the available routes for Business Automation Workflow:"
    fi
    if [[ $item == "workstreams" ]]; then
      echo "Below are the available routes for Business Automation Workstreams:"
    fi
    echo "=================================================================:"
    echo
    oc get routes | grep 'baw\|navigator' --color=never
    echo
    echo
    echo -e "\x1B[1mYou can access Process Federated Server to see federated workflow servers via the following URL:\x1B[0m"
    echo -e "https://$(oc get routes --no-headers | grep pfs-route | awk {'print $2'})/rest/bpm/federated/v1/systems"
    echo
    if [[ $item == "workflow-workstreams" ]]; then
      echo -e "\x1B[1mYou can access Business Automation Workflow Portal, Case Client, and Workstreams via the following URLs:\x1B[0m"
    fi
    if [[ $item == "workflow" ]]; then
      echo -e "\x1B[1mYou can access Business Automation Workflow Portal, Case Client via the following URLs:\x1B[0m"
    fi
    if [[ $item == "workstreams" ]]; then
      echo -e "\x1B[1mYou can access Business Automation Workstreams via the following URLs:\x1B[0m"
    fi
    if [[ $item == "workflow" || $item == "workflow-workstreams" ]]; then
      echo -e "https://$(oc get routes --no-headers | grep baw-server | awk {'print $2'})/ProcessPortal"
      echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator?desktop=baw"
    fi
    if [[ $item == "workstreams" || $item == "workflow-workstreams" ]]; then
      echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator?desktop=IBMWorkplace1"
    fi
    echo
    if [[ $deployment_type == "demo" ]]; then
      echo "User credentials:"
      echo "================"
      echo
      echo -n "Default administrator username: "; echo "cp4admin"
      echo -n "Default administrator password: "; pwd=$(oc get cm "${metadata_name}-openldap-customldif" -o yaml |grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
    fi
}

function display_application_routes_credentials() {
    echo
    echo "Below are the available routes for Business Automation Application:"   
    echo "==========================================================:"
    echo
    oc get routes | grep 'bastudio\|navigator' --color=never
    echo
    echo
    echo -e "\x1B[1mYou can access Navigator via the following URLs:\x1B[0m"
    echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator"
    bastudio_install=$(${YQ_CMD} r $pattern_file spec.bastudio_configuration)
    if [[ " ${OPT_COMPONENT_ARR[@]} " =~ "app_designer" || (-n "$bastudio_install") ]]; then
      echo -e "\x1B[1mYou can access Business Automation Studio via the following URLs:\x1B[0m"
      echo -e "https://$(oc get routes --no-headers | grep bastudio-route | awk {'print $2'})/BAStudio"
    fi
    echo
    if [[ $deployment_type == "demo" ]]; then
      echo "User credentials:"
      echo "================"
      echo
      echo -n "Default administrator username: "; echo "cp4admin"
      echo -n "Default administrator password: "; pwd=$(oc get cm "${metadata_name}-openldap-customldif" -o yaml |grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
    fi
 }

function display_contentanalyzer_routes_credentials() {
    echo
    echo "Below are the available routes for Automation Content Analyzer:"   
    echo "==============================================================:"
    echo
    oc get routes | grep 'spbackend\|navigator\|bastudio' --color=never
    echo
    echo
    echo -e "\x1B[1mYou can access Automation Content Analyzer via the following URLs:\x1B[0m"
    echo -e "https://$(oc get routes --no-headers | grep spbackend | awk {'print $2'})"
    echo
    if [[ $deployment_type == "demo" ]]; then
    echo -e "https://$(oc get routes --no-headers | grep spfrontend | awk {'print $2'})/?tid=ont1&ont=ONT1"
      echo "User credentials:"
      echo "================"
      echo
      echo -n "Default administrator username: "; echo "cp4admin"
      echo -n "Default administrator password: "; pwd=$(oc get cm "${metadata_name}-openldap-customldif" -o yaml |grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
    elif [[ $deployment_type == "enterprise" ]]; then
      echo -e "https://$(oc get routes --no-headers | grep spfrontend | awk {'print $2'})/?tid=<CHANGE_ME>&ont=<CHANGE_ME>"
      echo -e "NOTE: You must replace the <CHANGE_ME> with tenant ID and the ontology values created during the Tenant DB initialization steps"
      echo -e "You can logon to Content Analyzer with the user used when creating the Content Analyzer's tenant database"
      echo
    fi
    echo -e "\x1B[1mYou can access Business Automation Studio via the following URLs:\x1B[0m"
    echo -e "https://$(oc get routes --no-headers | grep bastudio-route | awk {'print $2'})/BAStudio"
}


function display_decisions_routes_credentials() {
    echo
    echo "Below are the available routes for Operational Decision Manager:"   
    echo "===============================================================:"
    echo
    oc get routes -l app=ibm-odm-prod
    echo
    echo
    isDsrEnabled=$(${YQ_CMD} r $pattern_file spec.odm_configuration.decisionServerRuntime.enabled)
    isDrEnabled=$(${YQ_CMD} r $pattern_file spec.odm_configuration.decisionRunner.enabled)
    if [ $(${YQ_CMD} r $pattern_file spec.odm_configuration.decisionCenter.enabled) == true ]; then
      echo -e "Use \x1B[1mhttps://$(oc get routes --field-selector metadata.name=${metadata_name}-odm-dc-route --no-headers | awk {'print $2'})/decisioncenter \x1B[0m to access, the Decision Center console"
    fi
    if  [[ $isDsrEnabled == true || $isDrEnabled == true ]]; then
      echo -e "Use \x1B[1m https://$(oc get routes --field-selector metadata.name=${metadata_name}-odm-ds-console-route --no-headers | awk {'print $2'})\x1B[0m to access the Decision Server Console"
    fi
    if  [[ $isDsrEnabled == true ]]; then
      echo -e "Use \x1B[1m https://$(oc get routes --field-selector metadata.name=${metadata_name}-odm-ds-runtime-route --no-headers | awk {'print $2'})\x1B[0m endpoint to invoke the Decision Server Runtime"
    fi
    if  [[ $isDrEnabled == true ]]; then
      echo -e "Use \x1B[1m https://$(oc get routes --field-selector metadata.name=${metadata_name}-odm-dr-route --no-headers | awk {'print $2'})\x1B[0m endpoint to invoke the Decision Runner"
    fi


    if [[ ! "$optional_components" =~ "ums" ]]; then
    echo
    echo "User credentials:"
    echo "================"
    echo
    echo -n "Default administrator username: "; echo "odmAdmin"
    echo -n "Default administrator password: "; echo "odmAdmin"
    fi
}

function display_decisions_ads_routes_credentials() {
    echo
    echo "Below are the available routes for Automation Decision Services:"
    echo "================================================================"
    echo
    oc get routes -l app.kubernetes.io/component=ads
    echo
    if [[ " ${OPT_COMPONENT_ARR[@]} " =~ "ads_designer" ]]; then
        echo -e "\x1B[1mYou can access ADS Designer via the Business Automation Studio URL:\x1B[0m"

        echo -e "https://$(oc get routes --no-headers | grep bastudio-route | awk {'print $2'})/BAStudio"
        echo
        if [[ ${deployment_type} == "demo" ]]; then
            echo "User credentials:"
            echo "================"
            echo
            echo -n "Default administrator username: "; echo "cp4admin"
            echo -n "Default administrator password: "; pwd=$(oc get cm "${metadata_name}-openldap-customldif" -o yaml |grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
            echo
        fi
    fi
    if [[ " ${OPT_COMPONENT_ARR[@]} " =~ "ads_runtime" ]]; then
        echo -e "\x1B[1mYou can access ADS Runtime swagger URL:\x1B[0m"

        echo -e "https://$(oc get routes --no-headers | grep runtime-service | awk {'print $2'})/api/swagger-ui"
        echo
        echo "User credentials (for execution):"
        echo "================================="
        echo
        echo -n "username: "; oc get secret ibm-dba-ads-runtime-secret -o jsonpath='{ .data.decisionRuntimeUser}' | base64 -d; echo
        echo -n "password: "; oc get secret ibm-dba-ads-runtime-secret -o jsonpath='{ .data.decisionRuntimePassword}' | base64 -d; echo
        echo
    fi
}

function display_digitalworker_routes_credentials() {
    echo
    echo "Below are the available routes for Automation Digital Worker:"
    echo "================================================================"
    echo

    oc get routes -l app=ibm-automation-digital-worker-prod
    echo

    echo -e "\x1B[1mYou can access ADW Designer via the Business Automation Studio URL:\x1B[0m"

    echo -e "https://$(oc get routes --no-headers | grep bastudio-route | awk {'print $2'})/BAStudio"
    echo
    if [[ ${deployment_type} == "demo" ]]; then
      echo "User credentials:"
      echo "================"
      echo
      echo -n "Default administrator username: "; echo "cp4admin"
      echo -n "Default administrator password: "; pwd=$(oc get cm "${metadata_name}-openldap-customldif" -o yaml |grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
      echo
    fi
    echo -e "\x1B[1mYou can access ADW Runtime URL:\x1B[0m"

    echo -e "https://$(oc get routes --no-headers | grep ${metadata_name}-adw-runtime-route | awk {'print $2'})"
    echo
    if [[ ${deployment_type} == "demo" ]]; then
      echo "User credentials (for execution):"
      echo "================================="
      echo
      echo -n "Default administrator username: "; echo "cp4admin"
      echo -n "Default administrator password: "; pwd=$(oc get cm "${metadata_name}-openldap-customldif" -o yaml |grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
      echo
    fi
}

function display_bai_routes_credentials() {
    echo
    echo "Below are the available routes for Business Automation Insights:"   
    echo "===============================================================:"
    echo
    oc get routes -l app=ibm-business-automation-insights

    echo -e "\x1B[1mYou can access Business Performance Center via the following URL:\x1B[0m"
    echo -e "https://$(oc get routes --no-headers | grep ${metadata_name}-bai-business-performance-center-route | awk {'print $2'})"
    echo
    if [[ $deployment_type == "demo" ]]; then
      echo "User credentials:"
      echo "================"
      echo
      echo -n "Default username: "; echo "user1"
      echo -n "Default password: "; pwd=$( oc get cm "${metadata_name}-openldap-customldif" -o yaml | grep "userpassword: " | head -n2); pwd=${pwd//*userpassword: /}; echo "$pwd"
      echo
    fi

    echo -e "\x1B[1mYou can access Kibana via the following URL:\x1B[0m"
    echo -e "https://$(oc get routes --no-headers | grep ${metadata_name}-bai-kibana-route | awk {'print $2'})"
    echo
    echo "User credentials:"
    echo "================"
    echo
    ek_secret=$(${YQ_CMD} r $pattern_file spec.bai_configuration.ekSecret)
    if [[ -z $ek_secret || $ek_secret == null ]]; then
        echo "Default username: admin";
        echo "Default password: passw0rd";
    else
        echo -n "Username: "; oc get $ek_secret -o jsonpath='{ .data.elasticsearch-username}' | base64 -d; echo
        echo -n "Password: "; oc get $ek_secret -o jsonpath='{ .data.elasticsearch-password}' | base64 -d; echo
    fi
    echo

    echo -e "\x1B[1mYou can access Admin API via the following URL:\x1B[0m"
    echo -e "https://$(oc get routes --no-headers | grep ${metadata_name}-bai-admin-route | awk {'print $2'})"
    echo
    echo "User credentials:"
    echo "================"
    echo
    bai_secret=$(${YQ_CMD} r $pattern_file spec.bai_configuration.baiSecret)
    if [[ -z $bai_secret || $bai_secret == null ]]; then
        echo -n "Default username: "; oc get cm ${metadata_name}-bai-env -o jsonpath='{ .data.admin-username}'; echo
        echo -n "Default password: "; oc get secret ${metadata_name}-bai-secrets -o jsonpath='{ .data.admin-password}' | base64 -d; echo
    else
        echo -n "Username: "; oc get secret $bai_secret -o jsonpath='{ .data.admin-username}' | base64 -d; echo
        echo -n "Password: "; oc get secret $bai_secret -o jsonpath='{ .data.admin-password}' | base64 -d; echo
    fi

    kafka_configuration=$(${YQ_CMD} r $pattern_file spec.shared_configuration.kafka_configuration)
    if [[ -z $kafka_configuration || $kafka_configuration == null ]]; then
        echo
        echo -e "\x1B[1mThere is no Kafka client configuration provided.\x1B[0m"
        echo
    else
        echo
        echo -e "\x1B[1mYou can configure Kafka client with the following configuration information:\x1B[0m"
        echo
        echo -n "Bootstrap servers: "; ${YQ_CMD} r $pattern_file spec.shared_configuration.kafka_configuration.bootstrap_servers;
        echo -n "Security protocol: "; ${YQ_CMD} r $pattern_file spec.shared_configuration.kafka_configuration.security_protocol;
        echo -n "SASL mechanism: "; ${YQ_CMD} r $pattern_file spec.shared_configuration.kafka_configuration.sasl_mechanism;
        kafka_connection_secret=$(${YQ_CMD} r $pattern_file spec.shared_configuration.kafka_configuration.connection_secret_name)
        if [[ -z $kafka_connection_secret || $kafka_connection_secret == null ]]; then
            echo "The Kafka server doesn't require authentication."
        else
            echo -n "Username: "; oc get secret $kafka_connection_secret -o jsonpath='{ .data.kafka-username}' | base64 -d; echo
            echo -n "Password: "; oc get secret $kafka_connection_secret -o jsonpath='{ .data.kafka-password}' | base64 -d; echo
            echo -n "Server certificate: "; oc get secret $kafka_connection_secret -o jsonpath='{ .data.kafka-server-certificate}' | base64 -d; echo
        fi
    fi
}

validate_cli
# The script should check the .tmp directory for the CR that is being used and determine which pattern is deployed and call the correct function.
# Or the script should just ask the user which pattern was deployed, and then call the necessary function for that pattern.
# 1Q only supports single pattern, 2Q will search dedicated file to support multiple pattern

for item in "${PATTERN_ARR[@]}"; do
    while true; do
      case "$item" in
        "content")
          display_content_routes_credentials
          break
          ;;
        "workflow"|"workstreams"|"workflow-workstreams")
          display_workflow_workstreams_routes_credentials
          break
          ;;
        "application")
          display_application_routes_credentials
          break
          ;;
        "contentanalyzer")
          display_contentanalyzer_routes_credentials
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
        "digitalworker")
          display_digitalworker_routes_credentials
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
