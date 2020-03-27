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
TMEP_FOLDER=${CUR_DIR}/.tmp

# 1Q only supports single pattern, 2Q will search dedicated file to support multiple pattern
CMD="find $TMEP_FOLDER -maxdepth 1 -name \"*ibm_cp4a_cr_demo_*\" -print"
if $CMD ; then
  echo -e "\x1B[1mShowing the access information and User credentials\x1B[0m"
    
  pattern_file=$(find $TMEP_FOLDER -maxdepth 1 -name "*ibm_cp4a_cr_demo_*" -print)
  pattern_name=$(grep -A1 'shared_configuration:' $pattern_file | tail -n1); pattern_name=${pattern_name//*sc_deployment_patterns: /}
  metadata_name=$(grep -A1 'metadata:' $pattern_file | tail -n1); metadata_name=${metadata_name//*name: /}
  optional_components=$(grep -A2 'shared_configuration:' $pattern_file | tail -n1); optional_components=${optional_components//*sc_optional_components: /}; temp="${optional_components%\"}"; temp="${temp#\"}"; optional_components="$temp"
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

function display_content_routes_credentials() {
    echo
    echo "Below are the available routes for FileNet Content Manager:"    
    echo "==========================================================:"
    echo
    oc get routes 
    echo
    echo
    echo -e "\x1B[1mYou can access ACCE and Navigator via the following URLs:\x1B[0m"
    echo -e "https://$(oc get routes --no-headers | grep cpe-route | awk {'print $2'})/acce"
    echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator"
    echo
    echo "User credentials:"
    echo "================"
    echo
    echo -n "ACCE usename: "; oc get secret ibm-fncm-secret -o jsonpath='{ .data.appLoginUsername}' | base64 -d; echo
    echo -n "ACCE user password: "; oc get secret ibm-fncm-secret -o jsonpath='{ .data.appLoginPassword}' | base64 -d; echo
    echo 
    echo -n "Navigator usename: "; oc get secret ibm-ban-secret -o jsonpath='{ .data.appLoginUsername}' | base64 -d; echo
    echo -n "Navigator user password: "; oc get secret ibm-ban-secret -o jsonpath='{ .data.appLoginPassword}' | base64 -d; echo
}

function display_workstreams_routes_credentials() {
    echo
    echo "Below are the available routes for Automation Workstream Services:"    
    echo "=================================================================:"
    echo
    oc get routes 
    echo
    echo
    echo -e "\x1B[1mYou can access Automation Workstream Services via the following URL:\x1B[0m"
    echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator"
    echo
    echo "User credentials:"
    echo "================"
    echo
    echo -n "Navigator usename: "; oc get secret ibm-fncm-secret -o jsonpath='{ .data.appLoginUsername}' | base64 -d; echo
    echo -n "Navigator user password: "; oc get secret ibm-fncm-secret -o jsonpath='{ .data.appLoginPassword}' | base64 -d; echo
}

function display_application_routes_credentials() {
    echo
    echo "Below are the available routes for Automation Applications:"    
    echo "==========================================================:"
    echo
    oc get routes 
    echo
    echo
    echo -e "\x1B[1mYou can access Business Automation Studio and Navigator via the following URLs:\x1B[0m"
    echo -e "https://$(oc get routes --no-headers | grep bastudio-route | awk {'print $2'})/BAStudio"
    echo -e "https://$(oc get routes --no-headers | grep navigator-route | awk {'print $2'})/navigator"
    echo
    echo "User credentials:"
    echo "================"
    echo
    echo -n "Default administrator username: "; echo "cp4admin"
    echo -n "Default administrator password: "; pwd=$(oc get cm "${metadata_name}-openldap-customldif" -o yaml |grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
 }

function display_contentanalyzer_routes_credentials() {
    echo
    echo "Below are the available routes for Automation Content Analyzer:"    
    echo "==============================================================:"
    echo
    oc get routes
    echo
    echo
    echo -e "\x1B[1mYou can access Automation Content Analyzer via the following URLs:\x1B[0m"    
    echo -e "https://$(oc get routes --no-headers | grep spbackend | awk {'print $2'})"
    echo -e "https://$(oc get routes --no-headers | grep spfrontend | awk {'print $2'})/?tid=ont1&ont=ONT1"
    echo
    echo "User credentials:"
    echo "================"
    echo
    echo -n "Default administrator username: "; echo "cp4admin"
    if [ "$optional_components" == "ums" ] || [ "$optional_components" == "ldap" ]; then
        echo -n "Default administrator password: "; pwd=$(oc get cm "${metadata_name}-openldap-customldif" -o yaml |grep "userpassword: " | head -n1); pwd=${pwd//*userpassword: /}; echo "$pwd"
    else
        echo -n "Default administrator password: "; echo "<no password>"
    fi
}


function display_decisions_routes_credentials() {
    echo
    echo "Below are the available routes for Operational Decision Manager:"    
    echo "===============================================================:"
    echo
    oc get routes -l app=ibm-odm-prod
    echo
    echo
    echo -e "\x1B[1mYou can access the Business Console and the Decision Server Console via the following URLs::\x1B[0m"    
    echo -e "Use https://$(oc get routes --no-headers | grep odm-dc-route | awk {'print $2'} ) to access, the Business Console"
    echo -e "Use https://$(oc get routes --no-headers | grep odm-ds-console-route | awk {'print $2'}) to access the Decision Server Console"
    echo
    echo -e "In order to access these routes from your workstation/laptop, update your local 'host' file (e.g., /private/etc/hosts on Mac or"
    echo -e "c:/windows/system32/drivers/etc/hosts on Windows) with the IP address of the OCP infrastructure node and the name of the route."
    echo -e "For example:"
    echo -e "xxx.xxx.xxx.xxx - decisions-odm-dc-route-odm-p.router.default.svc.cluster.local"
    echo -e "xxx.xxx.xxx.xxx - decisions-odm-ds-console-route-odm-p.router.default.svc.cluster.local"
    echo -e "where xxx.xxx.xxx.xxx is the IP address of the OCP infrastructure node"
    echo
    echo "User credentials:"
    echo "================"
    echo
    echo -n "Default administrator username: "; echo "odmAdmin"
    echo -n "Default administrator password: "; echo "odmAdmin"
}


validate_cli
# The script should check the .tmp directory for the CR that is being used and determine which pattern is deployed and call the correct function.
# Or the script should just ask the user which pattern was deployed, and then call the necessary function for that pattern. 
# 1Q only supports single pattern, 2Q will search dedicated file to support multiple pattern
case "$pattern_name" in 
  content)
    display_content_routes_credentials
    ;;
  workstreams)
    display_workstreams_routes_credentials
    ;;
  application)
    display_application_routes_credentials
    ;;
  contentanalyzer)
    display_contentanalyzer_routes_credentials
    ;;
  decisions)
    display_decisions_routes_credentials
    ;;
esac
    
