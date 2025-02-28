#!/bin/bash

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

# This script contains shared utility functions and environment variables.
# CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

TEMP_FOLDER=${CUR_DIR}/.tmp

# Directory for common service script
COMMON_SERVICES_SCRIPT_FOLDER=${CUR_DIR}/cpfs/installer_scripts/cp3pt0-deployment
COMMON_SERVICES_SCRIPT_PARENT_FOLDER=${CUR_DIR}/cpfs/installer_scripts
OPENSEARCH_MIGRATION_SCRIPT=${CUR_DIR}/cpfs/migration/es-os-migration-script.sh

COMMON_SERVICES_SCRIPT_YQ_FOLDER=${CUR_DIR}/cpfs/yq
ALL_NAMESPACE_NAME="openshift-operators"
CP4BA_SERVICES_NS=""
CP4BA_OPERATORS_NS=""

PREREQUISITES_FOLDER=${CUR_DIR}/cp4ba-prerequisites/project/$1
PREREQUISITES_FOLDER_BAK=${CUR_DIR}/cp4ba-prerequisites-backup/project/$1
PROPERTY_FILE_FOLDER=${PREREQUISITES_FOLDER}/propertyfile
PROPERTY_FILE_FOLDER_BAK=${PREREQUISITES_FOLDER_BAK}/propertyfile
CREATE_SECRET_SCRIPT_FILE=$PREREQUISITES_FOLDER/create_secret.sh

LDAP_SSL_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert/ldap
EXT_LDAP_SSL_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert/external_ldap
DB_SSL_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert/db
ZEN_DB_SSL_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert/zen_external_db
IM_DB_SSL_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert/im_external_db
BTS_DB_SSL_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert/bts_external_db
CP4BA_TLS_ISSUER_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert/cp4ba_tls_issuer
AE_REDIS_SSL_CERT_FOLDER=${DB_SSL_CERT_FOLDER}/redis-ae
PLAYBACK_REDIS_SSL_CERT_FOLDER=${DB_SSL_CERT_FOLDER}/redis-playback
ADP_GIT_SSL_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert/adp_git
ADP_CDRA_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert/adp_cdra

TEMPORARY_PROPERTY_FILE=${TEMP_FOLDER}/.TEMPORARY.property
LDAP_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/cp4ba_LDAP.property
EXTERNAL_LDAP_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/cp4ba_External_LDAP.property

DB_NAME_USER_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/cp4ba_db_name_user.property
DB_SERVER_INFO_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/cp4ba_db_server.property
USER_PROFILE_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/cp4ba_user_profile.property

BAW_AUTH_OS_ARR=("BAWDOCS" "BAWDOS" "BAWTOS")
AEOS=("AEOS")
# Directory and script file for DB Script
DB_SCRIPT_FOLDER=${PREREQUISITES_FOLDER}/dbscript
FNCM_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/fncm
BAN_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/ban
ODM_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/odm
BAS_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/bas
ADP_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/adp
BAA_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/baa
AE_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/ae
BAW_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/baw-authoring
BAW_AWS_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/baw-aws

# Directory and template file for secret YAML template
SECRET_FILE_FOLDER=${PREREQUISITES_FOLDER}/secret_template

DB_SSL_SECRET_FOLDER=${SECRET_FILE_FOLDER}/cp4ba_db_ssl_secret
LDAP_SSL_SECRET_FOLDER=${SECRET_FILE_FOLDER}/cp4ba_ldap_ssl_secret
REDIS_SSL_SECRET_FOLDER=${SECRET_FILE_FOLDER}/cp4ba_redis_ssl_secret

CP4A_DB_SSL_SECRET_FILE=${DB_SSL_SECRET_FOLDER}/ibm-cp4ba-db-ssl-cert-secret.sh
CP4A_AE_REDIS_SSL_SECRET_FILE=${REDIS_SSL_SECRET_FOLDER}/ibm-cp4ba-ae-redis-ssl-cert-secret.sh
CP4A_PLAYBACK_REDIS_SSL_SECRET_FILE=${REDIS_SSL_SECRET_FOLDER}/ibm-cp4ba-playback-redis-ssl-cert-secret.sh
CP4A_LDAP_SSL_SECRET_FILE=${LDAP_SSL_SECRET_FOLDER}/ibm-cp4ba-ldap-ssl-cert-secret.sh
CP4A_EXT_LDAP_SSL_SECRET_FILE=${LDAP_SSL_SECRET_FOLDER}/ibm-cp4ba-external-ldap-ssl-cert-secret.sh


LDAP_SECRET_FILE=${SECRET_FILE_FOLDER}/ldap-bind-secret.yaml
EXT_LDAP_SECRET_FILE=${SECRET_FILE_FOLDER}/ext-ldap-bind-secret.yaml

FNCM_SECRET_FOLDER=${SECRET_FILE_FOLDER}/fncm
FNCM_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-fncm-secret.yaml

FNCM_ICC_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-fncm-icc-secret.yaml
FNCM_ICCSAP_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-fncm-iccsap-secret.yaml
FNCM_IER_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-fncm-ier-secret.yaml
FNCM_DB_SSL_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-fncm-db-ssl-cert-secret.sh

BAN_SECRET_FOLDER=${SECRET_FILE_FOLDER}/ban
BAN_SECRET_FILE=${BAN_SECRET_FOLDER}/ibm-ban-secret.yaml
BAN_DB_SSL_SECRET_FILE=${BAN_SECRET_FOLDER}/ibm-ban-db-ssl-cert-secret.sh

ODM_SECRET_FOLDER=${SECRET_FILE_FOLDER}/odm
ODM_SECRET_FILE=${ODM_SECRET_FOLDER}/ibm-odm-db-secret.yaml
ODM_DB_SSL_SECRET_FILE=${ODM_SECRET_FOLDER}/ibm-odm-db-ssl-cert-secret.sh

ADP_SECRET_FOLDER=${SECRET_FILE_FOLDER}/adp
ADP_BASE_DB_SECRET_FILE=${ADP_SECRET_FOLDER}/ibm-aca-db-secret.sh
ADP_BASE_DB_SECRET_YAML_FILE=${ADP_SECRET_FOLDER}/ibm-aca-db-secret.yaml
ADP_GIT_SSL_SECRET_FILE=${ADP_SECRET_FOLDER}/ibm-adp-git-connection-secret.sh
ADP_CDRA_SSL_SECRET_FILE=${ADP_SECRET_FOLDER}/ibm-adp-cdra-route-secret.sh
ADP_SECRET_FILE=${ADP_SECRET_FOLDER}/ibm-adp-secret.yaml
ADP_ACA_DESIGN_API_KEY_SECRET_FILE=${ADP_SECRET_FOLDER}/ibm-adp-aca-design-api-key-secret.sh

ADP_DB_SSL_SECRET_FILE=${ADP_SECRET_FOLDER}/ibm-apd-db-ssl-cert-secret.sh

BAW_SECRET_FOLDER=${SECRET_FILE_FOLDER}/baw
BAW_SECRET_FILE=${BAW_SECRET_FOLDER}/ibm-baw-db-secret.yaml
BAW_DB_SSL_SECRET_FILE=${BAW_SECRET_FOLDER}/ibm-baw-authoring-db-ssl-cert-secret.sh

BAW_AWS_SECRET_FOLDER=${SECRET_FILE_FOLDER}/baw-aws
BAW_AWS_SECRET_FILE=${BAW_AWS_SECRET_FOLDER}/ibm-aws-db-secret.yaml
BAW_RUNTIME_SECRET_FILE=${BAW_AWS_SECRET_FOLDER}/ibm-baw-db-secret.yaml
ICP4A_ENCRYPTION_KEY_SECRET_FILE=${BAW_AWS_SECRET_FOLDER}/icp4a-shared-encryption-key-secret.yaml

APP_ENGINE_SECRET_FOLDER=${SECRET_FILE_FOLDER}/ae
APP_ENGINE_SECRET_FILE=${APP_ENGINE_SECRET_FOLDER}/ibm-aae-app-engine-secret.yaml
APP_ENGINE_PLAYBACK_SECRET_FILE=${APP_ENGINE_SECRET_FOLDER}/ibm-playback-server-admin-secret.yaml
APP_ENGINE_DB_SSL_SECRET_FILE=${APP_ENGINE_SECRET_FOLDER}/ibm-aae-app-engine-db-ssl-cert-secret.sh
APP_ORACLE_SSO_SSL_SECRET_FILE=${DB_SSL_SECRET_FOLDER}/ibm-ae-oracle-sso-cert-secret.sh

BAS_SECRET_FOLDER=${SECRET_FILE_FOLDER}/bas
BAS_SECRET_FILE=${BAS_SECRET_FOLDER}/ibm-bas-admin-secret.yaml
BAS_DB_SSL_SECRET_FILE=${BAS_SECRET_FOLDER}/ibm-bas-admin-db-ssl-cert-secret.sh

ADS_SECRET_FOLDER=${SECRET_FILE_FOLDER}/ads
ADS_SECRET_FILE=${ADS_SECRET_FOLDER}/ibm-dba-ads-mongo-secret.yaml
ADS_DB_SSL_SECRET_FILE=${ADS_SECRET_FOLDER}/ibm-dba-ads-mongo-db-ssl-cert-secret.sh

ZEN_SECRET_FOLDER=${SECRET_FILE_FOLDER}/zen_external_db
ZEN_SECRET_FILE=${ZEN_SECRET_FOLDER}/ibm-zen-metastore-edb-secret.sh
ZEN_CONFIGMAP_FILE=${ZEN_SECRET_FOLDER}/ibm-zen-metastore-edb-cm.yaml

IM_SECRET_FOLDER=${SECRET_FILE_FOLDER}/im_external_db
IM_SECRET_FILE=${IM_SECRET_FOLDER}/ibm-im-metastore-edb-secret.sh
IM_CONFIGMAP_FILE=${IM_SECRET_FOLDER}/ibm-im-metastore-edb-cm.yaml

BTS_SECRET_FOLDER=${SECRET_FILE_FOLDER}/bts_external_db
BTS_SSL_SECRET_FILE=${BTS_SECRET_FOLDER}/ibm-bts-metastore-edb-ssl-secret.sh
BTS_SECRET_FILE=${BTS_SECRET_FOLDER}/ibm-bts-metastore-edb-user-secret.yaml
BTS_CONFIGMAP_FILE=${BTS_SECRET_FOLDER}/ibm-bts-metastore-edb-cm.yaml

CP4BA_TLS_ISSUER_FOLDER=${SECRET_FILE_FOLDER}/cp4ba_tls_issuer
CP4BA_TLS_ISSUER_SECRET_FILE=${CP4BA_TLS_ISSUER_FOLDER}/ibm-cp4ba-tls-issuer-secret.sh
CP4BA_TLS_ISSUER_FILE=${CP4BA_TLS_ISSUER_FOLDER}/ibm-cp4ba-tls-issuer.yaml

# Release/Patch version for CP4BA
# CP4BA_RELEASE_BASE is for fetch content/foundation operator pod, only need to change for major release.
CP4BA_RELEASE_BASE="24.0.1"
CP4BA_PATCH_VERSION="IF001"
# CP4BA_CSV_VERSION is for checking CP4BA operator upgrade status, need to update for each IFIX
CP4BA_CSV_VERSION="v24.1.1"
# CP4BA_CHANNEL_VERSION is for switch CP4BA operator upgrade status, need to update for major release
CP4BA_CHANNEL_VERSION="v24.1"
# CS_OPERATOR_VERSION is for checking CPFS operator upgrade status, need to update for each IFIX
CS_OPERATOR_VERSION="v4.10.0"
# CS_CHANNEL_VERSION is for for CPFS script -c option, need to update for each IFIX
CS_CHANNEL_VERSION="v4.10"
# CERT_LICENSE_OPERATOR_VERSION is for checking IBM cert-manager/licensing operator upgrade status, need to update for each IFIX
CERT_LICENSE_OPERATOR_VERSION="v4.2.11"
# CERT_LICENSE_CHANNEL_VERSION is for for IBM cert-manager/licensing script -c option, need to update for each IFIX
CERT_LICENSE_CHANNEL_VERSION="v4.2"
# CS_CATALOG_VERSION is for CPFS script -s option, need to update for each IFIX
CS_CATALOG_VERSION="ibm-cs-install-catalog-v4-10-0"
# ZEN_OPERATOR_VERSION is for checking ZenService operator upgrade status, need to update for each IFIX
ZEN_OPERATOR_VERSION="v6.1.0"
# BTS_CHANNEL_VERSION is for for BTS, need to update for each IFIX
BTS_CHANNEL_VERSION="v3.35"
# BTS_CATALOG_VERSION is for BTS 3.35.1.
BTS_CATALOG_VERSION="bts-operator-v3-35-1"
# REQUIREDVER_BTS is for checking bts operator upgrade status before run removal_iaf.sh, need to update for each IFIX
REQUIREDVER_BTS="3.35.1"
# REQUIREDVER_POSTGRESQL is for checking postgresql operator upgrade status before run removal_iaf.sh, need to update for each IFIX
REQUIREDVER_POSTGRESQL="1.22.7"
# EVENTS_OPERATOR_VERSION is for checking IBM Events operator upgrade status, need to update for each IFIX
EVENTS_OPERATOR_VERSION="v5.0.1"
# List of CP4BA versions that are supported for upgrade to $CP4BA_CSV_VERSION
MINIMUM_SUPPORTED_UPGRADE_VERSIONS=("24.0." "24.1." )

CERT_MANAGER_PROJECT="ibm-cert-manager"
LICENSE_MANAGER_PROJECT="ibm-licensing"
DEDICATED_CS_PROJECT="cs-control"
# Directory for upgrade operator and prerequisites
UPGRADE_TEMP_FOLDER=${TEMP_FOLDER}/upgrade
UPGRADE_PREREQUISITE_FOLDER=${UPGRADE_TEMP_FOLDER}/prerequisites
UPGRADE_CERT_MANAGER_FILE=${UPGRADE_PREREQUISITE_FOLDER}/cert_manager_operator.yaml
UPGRADE_IBM_LICENSE_FILE=${UPGRADE_PREREQUISITE_FOLDER}/license_operator.yaml
UPGRADE_OPERATOR_GROUP=${UPGRADE_PREREQUISITE_FOLDER}/operator_group.yaml

# Zen metastore EDB configmap name
ZEN_EDB_CFG="ibm-zen-metastore-edb-cm"
# Check CS is dedicated or shared
COMMON_SERVICES_CM_NAMESPACE="kube-public"
COMMON_SERVICES_CM_DEDICATED_NAME="common-service-maps"
COMMON_SERVICES_CM_SHARED_NAME="ibm-common-services-status"
COMMON_SERVICES_NAME="IBM Cloud Pak foundational services"
COMMON_SERVICES_CM_DEDICATE_FILE_NAME_UPDATE="common-service-maps-update.yaml"
COMMON_SERVICES_CM_DEDICATE_FILE_NAME="common-service-maps.yaml"
COMMON_SERVICES_CM_DEDICATE_FILE="${PARENT_DIR}/descriptors/${COMMON_SERVICES_CM_DEDICATE_FILE_NAME}"
COMMON_SERVICES_CM_DEDICATE_FILE_UPDATE="${PARENT_DIR}/descriptors/${COMMON_SERVICES_CM_DEDICATE_FILE_NAME_UPDATE}"

#List of operators to be scale up or down
CP4BA_OPERATOR_LIST="ibm-cp4a-operator ibm-content-operator icp4a-foundation-operator  ibm-ads-operator  ibm-cp4a-wfps-operator ibm-dpe-operator ibm-insights-engine-operator ibm-odm-operator ibm-pfs-operator ibm-workflow-operator"

# CP4BA EDB instance default name
EDB_INSTANCE_CP4BA_NAME="postgres-cp4ba"

# set CLI_CMD var
if which oc >/dev/null 2>&1; then
    CLI_CMD=oc
elif which kubectl >/dev/null 2>&1; then
    CLI_CMD=kubectl
else
    echo -e  "\x1B[1;31mUnable to locate Kubernetes CLI or OpenShift CLI. You must install it to run this script.\x1B[0m" && \
    exit 1
fi

function prop_upgrade_property_file() {
    grep "^${1}=" ${UPGRADE_DEPLOYMENT_PROPERTY_FILE}|cut -d'=' -f2
}

function prop_tmp_property_file() {
    grep "^${1}=" ${TEMPORARY_PROPERTY_FILE}|cut -d'=' -f2
}

function prop_ldap_property_file() {
    grep "^${1}=" ${LDAP_PROPERTY_FILE}|cut -d'"' -f2
}

function prop_ext_ldap_property_file() {
    grep "^${1}=" ${EXTERNAL_LDAP_PROPERTY_FILE}|cut -d'"' -f2
}

function prop_user_profile_property_file() {
    grep "^${1}=" ${USER_PROFILE_PROPERTY_FILE}|cut -d'"' -f2
}

function prop_db_name_user_property_file() {
    grep "^.*${1}=" ${DB_NAME_USER_PROPERTY_FILE}|cut -d'"' -f2
}

function prop_db_name_user_property_file_for_server_name() {
    grep "^.*${1}=" ${DB_NAME_USER_PROPERTY_FILE}|cut -d'.' -f1
}

function prop_osdb_property_file() {
    grep "^.*${1}=" ${DB_NAME_USER_PROPERTY_FILE}|cut -d'=' -f2
}

function prop_db_server_property_file() {
    grep "^${1}=" ${DB_SERVER_INFO_PROPERTY_FILE}|cut -d'"' -f2
}

function prop_db_oracle_server_property_file() {
    grep "^${1}=" ${DB_SERVER_INFO_PROPERTY_FILE}|cut -d'"' -f2
}


function set_global_env_vars() {
    unameOut="$(uname -s)"
    case "${unameOut}" in
        Linux*)     machine="Linux";;
        Darwin*)    machine="Mac";;
        *)          machine="UNKNOWN:${unameOut}"
    esac

    if [[ "$machine" == "Mac" ]]; then
        SED_COMMAND='sed -i ""'
        SED_COMMAND_FORMAT='sed -i "" s/^M//g'
        YQ_CMD=${CUR_DIR}/helper/yq/yq_darwin_amd64
        CPFS_YQ_PATH=$COMMON_SERVICES_SCRIPT_YQ_FOLDER/macos/yq
        COPY_CMD=/bin/cp
    else
        SED_COMMAND='sed -i'
        SED_COMMAND_FORMAT='sed -i s/\r//g'
        if [[ $(uname -m) == 'x86_64' ]]; then
            YQ_CMD=${CUR_DIR}/helper/yq/yq_linux_amd64
            CPFS_YQ_PATH=$COMMON_SERVICES_SCRIPT_YQ_FOLDER/amd64/yq
        elif [[ $(uname -m) == 'ppc64le' ]]; then
            YQ_CMD=${CUR_DIR}/helper/yq/yq_linux_ppc64le
            CPFS_YQ_PATH=$COMMON_SERVICES_SCRIPT_YQ_FOLDER/ppc64le/yq
        else
            YQ_CMD=${CUR_DIR}/helper/yq/yq_linux_s390x
            CPFS_YQ_PATH=$COMMON_SERVICES_SCRIPT_YQ_FOLDER/s390x/yq
        fi
        COPY_CMD=/usr/bin/cp
    fi
}

############################
# CLI installation utilities
############################

function validate_cli(){
    which ${YQ_CMD} &>/dev/null
    [[ $? -ne 0 ]] && \
        while true; do
            echo_bold "\"yq\" Command Not Found\n"
            echo_bold "Please download \"yq\" binary file from cert-kubernetes repo\n"
            exit 0
        done
    which timeout &>/dev/null
    [[ $? -ne 0 ]] && \
        while true; do
            echo_bold "\"timeout\" Command Not Found\n"
            echo_bold "The \"timeout\" will be installed automatically\n"
            echo_bold "Do you accept (Yes/No, default: No):"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                install_timeout_cli
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                echo -e "You do not accept, exiting...\n"
                exit 0
                ;;
            *)
                echo_red "You do not accept, exiting...\n"
                exit 0
                ;;
            esac
        done
}

function install_timeout_cli(){
    if [[ ${machine} = "Mac" ]]; then
        echo -n "Installing timeout..."; brew install coreutils >/dev/null 2>&1; sudo ln -s /usr/local/bin/gtimeout /usr/local/bin/timeout >/dev/null 2>&1; echo "done.";
    fi
    printf "\n"
}

function install_yq_cli(){
    if [[ ${machine} = "Linux" ]]; then
        echo -n "Downloading..."; curl -LO https://github.com/mikefarah/yq/releases/download/3.2.1/yq_linux_amd64  >/dev/null 2>&1; echo "done.";
        echo -n "Installing yq..."; sudo chmod +x yq_linux_amd64 >/dev/null; sudo mv yq_linux_amd64 /usr/local/bin/yq >/dev/null; echo "done.";
    else
        echo -n "Installing yq..."; brew install yq >/dev/null; echo "done.";
    fi
    printf "\n"
}

function install_ibm_jre(){
    if [[ ${machine} = "Linux" ]]; then
        local JRE_VERSION=""
        local JRE_VERSION_TMP=""
        JRE_VERSION=$(curl -s https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/  | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | tail -n 1)
        if [[ -z $JRE_VERSION ]]; then
            fail "Can NOT access official IBM JRE Repository https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java, Please install IBM JRE manually."
            exit 1
        else
            JRE_VERSION_TMP=$(echo "$JRE_VERSION" | sed 's/\./-/2')
            local tmp_file="/tmp/ibm-java.tgz"
            local download_url=https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/${JRE_VERSION}/linux/$(uname -m)/ibm-java-jre-${JRE_VERSION_TMP}-linux-$(uname -m).tgz
            echo -n "Downloading $download_url";
            curl -o $tmp_file -f $download_url
            if [ ! -e $tmp_file ]; then
                fail "Can NOT access official IBM JRE Repository https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java, Please install IBM JRE manually."
                exit 1
            fi
            mkdir -p /opt/ibm/java
            tar -xzf $tmp_file --strip-components=1 -C /opt/ibm/java
            #  add keytool to system PATH.
            echo -n "Add keytool to system environment variable PATH..."; sudo -s export PATH="/opt/ibm/java/jre/bin/:$PATH"; export PATH="/opt/ibm/java/jre/bin/:$PATH"; echo "PATH=$PATH:/opt/ibm/java/jre/bin/" >> ~/.bashrc;echo "done."
            info "IBM JRE has been installed and system enviroment variable PATH was configured. Please run command \"source ~/.bashrc\" before running the validate command again. Exiting this script."
            exit 1
        fi
    elif [[ ${machine} = "Mac" ]]; then
        echo -n "IBM's Java JRE is not available for Mac OS X. Install valid JRE for Mac OS X manually refer to MacOS document"; echo "done.";
    fi
    printf "\n"
}

function install_kubectl_cli(){
    if [[ ${machine} = "Linux" ]]; then
        echo -n "Downloading..."
        if [[ $(uname -m) == 'x86_64' ]]; then
            PLATFORM_ARCH='amd64'
        elif [[ $(uname -m) == 'ppc64le' ]]; then
            PLATFORM_ARCH='ppc64le'
        elif [[ $(uname -m) == 's390x' ]]; then
            PLATFORM_ARCH='s390x'
        fi
        curl -o /tmp/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${PLATFORM_ARCH}/kubectl" >/dev/null 2>&1; echo "done."
        echo -n "Installing Kubectl CLI..."; sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl >/dev/null; echo "done.";
    elif [[ ${machine} = "Mac" ]]; then
        echo -n "Downloading..."; curl -o /tmp/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl" >/dev/null 2>&1; echo "done.";
        echo -n "Installing Kubectl CLI..."; chmod +x /tmp/kubectl >/dev/null; sudo mv /tmp/kubectl /usr/local/bin/kubectl >/dev/null; sudo chown root: /usr/local/bin/kubectl; echo "done.";
    fi
    printf "\n"
}

function install_openssl(){
    if [[ ${machine} = "Linux" ]]; then
        echo -n "Installing OpenSSL..."; sudo yum install openssl -y >/dev/null; echo "done.";
    elif [[ ${machine} = "Mac" ]]; then
        echo -n "Installing OpenSSL..."; sudo brew install openssl >/dev/null; echo 'export PATH="/usr/local/opt/openssl/bin:$PATH"' >> ~/.bash_profile; source ~/.bash_profile; echo "done.";
    fi
    printf "\n"
}

###################
# Echoing utilities
###################
RED_TEXT=`tput setaf 1`
GREEN_TEXT=`tput setaf 2`
YELLOW_TEXT=`tput setaf 3`
BLUE_TEXT=`tput setaf 6`
WHITE_TEXT=`tput setaf 7`
RESET_TEXT=`tput sgr0`

printHeaderMessage()
{
 echo ""
  if [  "${#2}" -ge 1 ] ;then
      echo "${2}${1}"
  else
      echo "${WHITE_TEXT}##########################################################${RESET_TEXT}"
      echo "             ${WHITE_TEXT}${1}"
  fi
  echo "##########################################################${RESET_TEXT}"
}

printFooterMessage()
{
  echo "${WHITE_TEXT}##########################################################${RESET_TEXT}"
}

function msg() {

  printf '\n%b\n' "$1"

}



function wait_msg() {

  printf '%s\r' "${1}"

}

function success() {

  msg "\33[32m[✔] ${1}\33[0m"

}

function info() {

  msg "\x1B[33;5m[INFO] \x1B[0m${1}"

}

function INFO() {

  msg "============== ${1} =============="

}


function tips() {

  echo -en "\x1B[1;31m[NEXT ACTIONS]\x1B[0m${1}\n"

}

function warning() {

  msg "\33[33m[✗] ${1}\33[0m"

}



function error() {

  msg "\33[31m[✘] ${1}\33[0m"

}


function msgRed() {

  echo -en "\x1B[1;31m[*] ${1}\x1B[0m\n"

}

function fail() {

  msg "\33[31m[FAILED] ${1}\33[0m"

}



function title() {

  msg "\33[1m ($step) ${1}\33[0m"
  step=$((step + 1))

}



function msgB() {

  echo -e "\x1B[1m${1}\x1B[0m\n"

}

function echo_bold() {
    # Echoes a message in bold characters
    echo_impl "${1}" "m"
}

function echo_red() {
    # Echoes a message in red bold characters
    echo_impl "${1}" ";31m"
}

function echo_impl() {
    # Echoes a message prefixed and suffixed by formatting characters
    local MSG=${1:?Missing message to echo}
    local PREFIX=${2:?Missing message prefix}
    #local SUFFIX=${3:?Missing message suffix}
    echo -e "\x1B[1${PREFIX}${MSG}\x1B[0m"
}

## <https://jsw.ibm.com/browse/DBACLD-159357> - Introduced new function to deal with pressing control keys to continune, need to clear buffer before and after reading user input.
## - - https://jsw.ibm.com/browse/DBACLD-165921 - <Press any key to continue...does not continue when "shift key" is pressed>
function prompt_press_any_key_to_continue() {
    while read -r -t 1; do :; done  # Clear the buffer
    read -rsn1 -p "Press Enter/Return to continue ${1}..."; echo # wait for user input
    read -r -t 1 # Clear any remaining escape seqence
}

############################
# check OCP version
############################
function check_platform_version(){
    currentver=$(oc get nodes | awk 'NR==2{print $5}')
    requiredver="v1.17.1"
    if [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" = "$requiredver" ]; then
        PLATFORM_VERSION="4.4OrLater"
    else
        # PLATFORM_VERSION="3.11"
        PLATFORM_VERSION="4.4OrLater"
        echo -e "\x1B[1;31mIMPORTANT: Only support OCp4.4 or Later, exit...\n\x1B[0m"
        exit 1
    fi
}

## <https://jsw.ibm.com/browse/DBACLD-161428> - Create a common function to check cluster login for all related scripts.
#############################
# Check Cluster Login
#############################
function check_cluster_login() {
    if [[ "$CLI_CMD" == "oc" ]]; then
        oc whoami >/dev/null 2>&1
        if [ $? -gt 0 ]; then
            error "Not logged in to a cluster. Please login to a cluster before running this script."
            exit 1
        fi
    elif [[ "$CLI_CMD" == "kubectl" ]]; then
        kubectl auth whoami >/dev/null 2>&1
        if [ $? -gt 0 ]; then
            error "Not logged in to a cluster. Please login to a cluster before running this script."
            exit 1
        fi
    fi
}

set_global_env_vars


function allocate_operator_pvc(){
    # For dynamic storage classname
    printf "\n"
    echo -e "\x1B[1mApplying the persistent volumes for the Cloud Pak operator by using the storage classname: ${STORAGE_CLASS_NAME}...\x1B[0m"

    printf "\n"
    if [[ $DEPLOYMENT_TYPE == "starter" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "other") ]] ;
    then
        sed "s/<StorageClassName>/$STORAGE_CLASS_NAME/g" ${OPERATOR_PVC_FILE_BAK} > ${OPERATOR_PVC_FILE_TMP1}
        sed "s/<Fast_StorageClassName>/$STORAGE_CLASS_NAME/g" ${OPERATOR_PVC_FILE_TMP1}  > ${OPERATOR_PVC_FILE_TMP} # &> /dev/null

    elif [[ ($DEPLOYMENT_TYPE == "production" && ($PLATFORM_SELECTED == "OCP" || $PLATFORM_SELECTED == "other")) || $PLATFORM_SELECTED == "ROKS" ]];
    then
        sed "s/<StorageClassName>/$SLOW_STORAGE_CLASS_NAME/g" ${OPERATOR_PVC_FILE_BAK} > ${OPERATOR_PVC_FILE_TMP1} # &> /dev/null
        sed "s/<Fast_StorageClassName>/$FAST_STORAGE_CLASS_NAME/g" ${OPERATOR_PVC_FILE_TMP1} > ${OPERATOR_PVC_FILE_TMP} # &> /dev/null
    fi

    ${COPY_CMD} -rf ${OPERATOR_PVC_FILE_TMP} ${OPERATOR_PVC_FILE_BAK}
    # Create Operator Persistent Volume.
    CREATE_PVC_CMD="${CLI_CMD} apply -f ${OPERATOR_PVC_FILE_TMP}"
    if $CREATE_PVC_CMD ; then
        echo -e "\x1B[1mDone\x1B[0m"
    else
        echo -e "\x1B[1;31mFailed\x1B[0m"
    fi
   # Check Operator Persistent Volume status every 5 seconds (max 10 minutes) until allocate.
    ATTEMPTS=0
    TIMEOUT=60
    printf "\n"
    echo -e "\x1B[1mWaiting for the persistent volumes to be ready...\x1B[0m"
    until ${CLI_CMD} get pvc | grep cp4a-shared-log-pvc | grep -q -m 1 "Bound" || [ $ATTEMPTS -eq $TIMEOUT ]; do
        ATTEMPTS=$((ATTEMPTS + 1))
        echo -e "......"
        sleep 10
        if [ $ATTEMPTS -eq $TIMEOUT ] ; then
            echo -e "\x1B[1;31mFailed to allocate the persistent volumes!\x1B[0m"
            echo -e "\x1B[1;31mRun the following command to check the claim '${CLI_CMD} describe pvc operator-shared-pvc'\x1B[0m"
            exit 1
        fi
    done
    if [ $ATTEMPTS -lt $TIMEOUT ] ; then
            echo -e "\x1B[1mDone\x1B[0m"
    fi
}

function save_log(){
    local LOG_DIR="$CUR_DIR/$1"
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

function decode_xor_password() {

  local encoded=$1
  local operator_project_name=$2
  local operator_pod_name=$3
  local was_home="/opt/ibm/securityUtility"
  local class_path="${was_home}/plugins/com.ibm.ws.runtime.jar:${was_home}/lib/bootstrap.jar:${was_home}/plugins/com.ibm.ws.emf.jar:${was_home}/lib/ffdc.jar:${was_home}/plugins/org.eclipse.emf.ecore.jar:${was_home}/plugins/org.eclipse.emf.common.jar:${was_home}/glassfish-corba-omgapi-4.2.4.jar"
  if [[ $encoded != "" ]] && [[ "$encoded" == *"{xor}"* ]]; then
    local decoded=$( ${CLI_CMD} exec -i -n $operator_project_name $operator_pod_name -- bash -c "java -cp \"${class_path}\" com.ibm.ws.security.util.PasswordDecoder \"$encoded\"")
    echo "$decoded" | grep -i 'decoded password == ' | awk '{print $8}' | sed -e 's/^"//' -e 's/"$//'
  else
    echo $encoded
  fi
}

# Function to encode the certificate contents to a base64 string
encode_crt_file_to_base64() {
    local crt_file="$1"
    if [[ ! -f "$crt_file" ]]; then
        echo "File not found: $crt_file"
        return 1
    fi

    # Read and base64 encode the .crt file
    local machine_lower=$(echo "${machine}" | tr '[:upper:]' '[:lower:]')
    if [[ "$machine_lower" == "linux" ]]; then
        base64_encoded_content=$(cat "$crt_file" | base64 -w 0)
    else
        base64_encoded_content=$(cat "$crt_file" | base64 )
    fi

    echo "$base64_encoded_content"
}

function check_single_quotes_password() {
    local temp_pwd=$1
    local variable_name=$2
    temp_pwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$temp_pwd")
    variable_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$variable_name")
    if [[ $temp_pwd == *"'"* ]]; then
        fail "Found single quotes (') in \"$variable_name\". Exiting..."
        warning "DO NOT use special character single quotes (') in the password."
        exit 1
    fi
}


function check_single_quotes_password() {
    local temp_pwd=$1
    local variable_name=$2
    temp_pwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$temp_pwd")
    variable_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$variable_name")
    if [[ $temp_pwd == *"'"* ]]; then
        fail "Found single quotes (') in \"$variable_name\". Exiting..."
        warning "DO NOT use special character single quotes (') in the password."
        exit 1
    fi
}

# For https://jsw.ibm.com/browse/DBACLD-157020
# Function that base64 encodes the password in the generated secret template and moves it to the data section of the template
# We cant directy use the base64 value in the stringData field as when the secret template is applied the cluster automatically base64 encodes it again and this will result in a wrong password being used by the operator code
# This was code that was repeating in numerous places so it was made a common function
# password_value is the value to base64 and update in the secret template
# secret template field is the property field in the secret template who's value will be the value in password_value
# secret_file is the name of the secret template file. (this file is already created prior to this function call)
# new_secret_template_field is the name of a new secret field to be added. This is only passed for the fncm secret where we add password fields to the existing template
# for new_secret_template_field to be used, secret template field must be osDBpassword as the current logic will append the new field after osDBpassword . 
# Other than for fncm secret the new_secret_template_field field is empty and not needed
function update_secret_template_passwords(){
    local password_value=$1
    local secret_template_field=$2
    local secret_file=$3
    local new_secret_template_field=$4
    # Checking if the password in the property file is base64 encoded and if so we just remove the prefix.
    # IF the password is plaintext we base64 encode it
    
    if [[ "${password_value:0:8}" == "{Base64}"  ]]; then
        temp_val=$(echo "$password_value" | sed -e "s/^{Base64}//" )
    else
        local machine_lower=$(echo "${machine}" | tr '[:upper:]' '[:lower:]')
        if [[ "$machine_lower" == "linux" ]]; then
            temp_val=$(echo -n "$password_value" | base64 -w 0 )
        else
            # printf makes sure there is no addition of newline character in certain cases
            temp_val=$(printf "%s" "$password_value" | base64 )
        fi
    fi
    # Remove the field from stringData and add it to data with the new encoded value
    # Use yq to delete and add the field in a more compatible way without eval
    if [[ "$secret_template_field" != "osDBPassword" && "$secret_template_field" != "mongoPwd" ]]; then
        ${YQ_CMD} w -i "$secret_file" "data.$secret_template_field" "$temp_val"
        ${YQ_CMD} d -i "$secret_file" "stringData.$secret_template_field"
    else
        ${YQ_CMD} w -i "$secret_file" "data.$new_secret_template_field" "$temp_val"
    fi
}



# function to create a userpassword dictionary string to pass to the ldap validation jar
# Sample format - username:testuser,password:testpassword;username:testuser2,password:;
# All values are base64 encoded so that all special characters are parsed correctly
function create_user_password_dictionary_string(){
    usernames=("${!1}")
    passwords=("${!2}")
    output=""
    # Loop through the arrays
    for i in "${!usernames[@]}"; do
        # Username is already encoded in the add_to_list function
        username="${usernames[$i]}"
        password="${passwords[$i]}"
        
        
        # Check if the password is empty or not
        if [ -n "$password" ]; then
            # For https://jsw.ibm.com/browse/DBACLD-157019 where we want to make sure we consider if passwords are encoded
            # If the value provided is base64 already we take the base64 value else we convert it to base64
            # Check if the password starts with {Base64}
            if [[ $password == "{Base64}"* ]]; then
                encoded_password="${password#'{Base64}'}"
            else
                encoded_password=$(printf "$password" | base64)
            fi
        else
            encoded_password=""
        fi
        
        # Append to the output string
        output="${output}username:${username},password:${encoded_password};"
    done

    # Print the final output
    echo "$output"
}

# certain fields have the full bind dn , and i am extracting it to just get the username
function extract_user_from_ldap_bind() {
  local ldap_bind_dn="$1"
  local display_name_attr="$2"  # LDAP_USER_DISPLAY_NAME_ATTR (e.g., cn or CN)

  # Use sed to dynamically extract the value based on the attribute name (case-insensitive)
  user=$(echo "$ldap_bind_dn" | sed -n "s/^${display_name_attr}=\([^,]*\).*/\1/ip")

  echo "$user"
}

# function that processes all properties from the property files that are associated with an LDAP value
# The function returns values that are passed in the appropriate format to the LDAPTest.jar for additional validation
function ldap_validation_parameter_generator(){
    ldap_group_basedn="$(prop_ldap_property_file LDAP_GROUP_BASE_DN)"
    ldap_user_filter="$(prop_ldap_property_file LC_USER_FILTER)"
    ldap_user_attribute="$(prop_ldap_property_file LDAP_USER_DISPLAY_NAME_ATTR)"
    ldap_group_filter="$(prop_ldap_property_file LC_GROUP_FILTER)"
    if [ -f "${USER_PROFILE_PROPERTY_FILE}" ]; then
        ldap_admins_group_name="$(prop_user_profile_property_file CONTENT_INITIALIZATION.LDAP_ADMINS_GROUPS_NAME)"
        cpe_obj_store_group_name="$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)"
        adp_service_user_name="$(extract_user_from_ldap_bind "$(prop_user_profile_property_file ADP.SERVICE_USER_NAME)" "$ldap_user_attribute")"
        adp_service_user_name_base="$(extract_user_from_ldap_bind "$(prop_user_profile_property_file ADP.SERVICE_USER_NAME_BASE)" "$ldap_user_attribute")"
        adp_service_user_name_ca="$(extract_user_from_ldap_bind "$(prop_user_profile_property_file ADP.SERVICE_USER_NAME_CA)" "$ldap_user_attribute")"
        adp_env_owner_user_name="$(extract_user_from_ldap_bind "$(prop_user_profile_property_file ADP.ENV_OWNER_USER_NAME)" "$ldap_user_attribute")"
    else
        ldap_admins_group_name=""
        cpe_obj_store_group_name=""
        adp_service_user_name=""
        adp_service_user_name_ca=""
        adp_service_user_name_base=""
        adp_env_owner_user_name=""
    fi
    ldap_user_list=()
    ldap_password_list=()
    ldap_group_list=()
    ldap_user_password_list=()
    # Function to add a string if it's not in the list
    # if the value is null that means that the property is not in the property file and the functions skips that value
    add_to_list() {
        local value="$1"
        local found=0
        if [ "$value" ]; then
            # Check if the user starts with {Base64}
            # For https://jsw.ibm.com/browse/DBACLD-157019 where we want to make sure we consider if passwords are encoded
            # If the value provided is base64 already we take the base64 value else we convert it to base64
            if [[ $value == "{Base64}"* ]]; then
                encoded_value="${value#'{Base64}'}"
            else
                encoded_value=$(printf "$value" | base64)
            fi
            # Loop through the array to check if the value already exists
            for user in "${ldap_user_list[@]}"; do
                if [[ "$user" == "$encoded_value" ]]; then
                found=1
                break
                fi
            done

            # If the value was not found, add it to the list
            if [[ $found -eq 0 ]]; then
                ldap_user_list+=("$encoded_value")
                return 0  # Indicates the value was added
            fi
        fi
        return 1
    }
    # If a user processed is not a duplicate found, then for values that we have a password field we append it, else we append an empty string
    if [ -f "${USER_PROFILE_PROPERTY_FILE}" ]; then
        if add_to_list "$(prop_user_profile_property_file CONTENT.APPLOGIN_USER)"; then
            ldap_password_list+=("$(prop_user_profile_property_file CONTENT.APPLOGIN_PASSWORD)")
        fi
        if add_to_list "$(prop_user_profile_property_file BAN.APPLOGIN_USER)"; then
            ldap_password_list+=("$(prop_user_profile_property_file BAN.APPLOGIN_PASSWORD)")
        fi
        if add_to_list "$(prop_user_profile_property_file CONTENT_INITIALIZATION.LDAP_ADMIN_USER_NAME)"; then
            ldap_password_list+=("")
        fi
        if add_to_list "$(prop_user_profile_property_file APP_ENGINE.ADMIN_USER)"; then
            ldap_password_list+=("")
        fi
        if add_to_list "$(prop_user_profile_property_file APP_PLAYBACK.ADMIN_USER)"; then
            ldap_password_list+=("")
        fi
        if add_to_list "$(prop_user_profile_property_file BASTUDIO.ADMIN_USER)"; then
            ldap_password_list+=("")
        fi
        if add_to_list "$(prop_user_profile_property_file BAW_RUNTIME.ADMIN_USER)"; then
            ldap_password_list+=("")
        fi
        if add_to_list "$adp_service_user_name"; then
            ldap_password_list+=("")
        fi
        if add_to_list "$adp_service_user_name_ca"; then
            ldap_password_list+=("")
        fi
        if add_to_list "$adp_service_user_name_base"; then
            ldap_password_list+=("")
        fi
        if add_to_list "$adp_env_owner_user_name"; then
            ldap_password_list+=("")
        fi
    fi
    # collecting groups for the ldap group list
    if [[ -n "$ldap_admins_group_name" ]]; then
        # Convert the comma-separated values to an array
        IFS=',' read -r -a values_array <<< "$ldap_admins_group_name"
        for value in "${values_array[@]}"; do
            ldap_group_list+=("$value")
        done
    fi
    if [[ -n "$cpe_obj_store_group_name" ]]; then
        # Convert the comma-separated values to an array
        IFS=',' read -r -a values_array <<< "$cpe_obj_store_group_name"
        for value in "${values_array[@]}"; do
            ldap_group_list+=("$value")
        done
    fi

    # Convert the space-separated list to a comma-separated string with unique values
    final_ldap_group_list=$(echo "${ldap_group_list[@]}" | tr ' ' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')

    # creating the user password dictionary string
    ldap_user_password_list=$(create_user_password_dictionary_string ldap_user_list[@] ldap_password_list[@])
    ldap_details=("$ldap_group_basedn" "$ldap_user_filter" "$ldap_group_filter" "$ldap_user_password_list" "$final_ldap_group_list")
}

# This function is used to display a latency warning based on the time taken for a DB/LDAP connection
# Takes in 2 parameters
# 1. time_taken which is used to display the latency and make comparisons using bc -l which allows for float point based comparisons
# connection_type which is used to display if the connection is for a DB or LDAP
# DBACLD-159742
function display_latency_warning() {
    local time_taken=$1
    local connection_type=$2
    echo "Latency: $time_taken ms"
    # Check if elapsed time is greater than 10 ms using awk. [[ ]] not used since it doesnt do float point comparisons correctly
    # If tt is between 10 and 30, it exits with 0 (success)
    if awk -v tt="$time_taken" 'BEGIN { exit !(tt < 10) }'; then
        echo "The latency is less than 10ms, which is acceptable performance for a simple $connection_type operation."
    elif awk -v tt="$time_taken" 'BEGIN { exit !(tt >= 10 && tt <= 30) }'; then
        echo "The latency is between 10ms and 30ms, which exceeds acceptable performance of 10 ms for a simple $connection_type operation, but the service is still accessible."
    else
        echo "The latency exceeds 30ms for a simple $connection_type operation, which indicates potential for failures."
    fi
}