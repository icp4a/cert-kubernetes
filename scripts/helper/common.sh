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
IM_SECRET_FILE=${IM_SECRET_FOLDER}/ibm-im-datastore-edb-secret.sh
IM_CONFIGMAP_FILE=${IM_SECRET_FOLDER}/ibm-im-datastore-edb-cm.yaml

BTS_SECRET_FOLDER=${SECRET_FILE_FOLDER}/bts_external_db
BTS_SSL_SECRET_FILE=${BTS_SECRET_FOLDER}/ibm-bts-metastore-edb-ssl-secret.sh
BTS_SECRET_FILE=${BTS_SECRET_FOLDER}/ibm-bts-metastore-edb-user-secret.yaml
BTS_CONFIGMAP_FILE=${BTS_SECRET_FOLDER}/ibm-bts-metastore-edb-cm.yaml

CP4BA_TLS_ISSUER_FOLDER=${SECRET_FILE_FOLDER}/cp4ba_tls_issuer
CP4BA_TLS_ISSUER_SECRET_FILE=${CP4BA_TLS_ISSUER_FOLDER}/ibm-cp4ba-tls-issuer-secret.sh
CP4BA_TLS_ISSUER_FILE=${CP4BA_TLS_ISSUER_FOLDER}/ibm-cp4ba-tls-issuer.yaml

# Release/Patch version for CP4BA
# CP4BA_RELEASE_BASE is for fetch content/foundation operator pod, only need to change for major release.
CP4BA_RELEASE_BASE="24.0.0"
CP4BA_PATCH_VERSION="IF007"
# CP4BA_CSV_VERSION is for checking CP4BA operator upgrade status, need to update for each IFIX
CP4BA_CSV_VERSION="v24.0.7"
# CP4BA_CHANNEL_VERSION is for switch CP4BA operator upgrade status, need to update for major release
CP4BA_CHANNEL_VERSION="v24.0"
# CS_OPERATOR_VERSION is for checking CPFS operator upgrade status, need to update for each IFIX
CS_OPERATOR_VERSION="v4.6.18"
# CS_CHANNEL_VERSION is for for CPFS script -c option, need to update for each IFIX
CS_CHANNEL_VERSION="v4.6"
# CERT_LICENSE_OPERATOR_VERSION is for checking IBM cert-manager/licensing operator upgrade status, need to update for each IFIX
CERT_LICENSE_OPERATOR_VERSION="v4.2.13"
# CERT_LICENSE_CHANNEL_VERSION is for for IBM cert-manager/licensing script -c option, need to update for each IFIX
CERT_LICENSE_CHANNEL_VERSION="v4.2"
# CS_CATALOG_VERSION is for CPFS script -s option, need to update for each IFIX
CS_CATALOG_VERSION="ibm-cs-install-catalog-v4-6-18"
# ZEN_OPERATOR_VERSION is for checking ZenService operator upgrade status, need to update for each IFIX
ZEN_OPERATOR_VERSION="v5.1.17"
# BTS_CHANNEL_VERSION is for for BTS, need to update for each IFIX
BTS_CHANNEL_VERSION="v3.35"
# BTS_CATALOG_VERSION is for BTS 3.35.4.
BTS_CATALOG_VERSION="bts-operator-v3-35"
# REQUIREDVER_BTS is for checking bts operator upgrade status before run removal_iaf.sh, need to update for each IFIX
REQUIREDVER_BTS="3.35.4"
# REQUIREDVER_POSTGRESQL is for checking postgresql operator upgrade status before run removal_iaf.sh, need to update for each IFIX
REQUIREDVER_POSTGRESQL="1.25.1"
# EVENTS_OPERATOR_VERSION is for checking IBM Events operator upgrade status, need to update for each IFIX
EVENTS_OPERATOR_VERSION="v5.2.1"
# List of CP4BA versions that are supported for upgrade to $CP4BA_CSV_VERSION
MINIMUM_SUPPORTED_UPGRADE_VERSIONS=("21.3.31" "22.2.6" "23.2.6" )
#DBADCLD-162192. This is a list of minimum 21.0.3 CP4BA version that BAS (authoring) supports for upgrade due to schema changes.
MINIMUM_SUPPORTED_BAW_AUTHORING_UPGRADE_VERSIONS=("21.3.31" "21.3.32" "21.3.33" "21.3.34" )


CERT_MANAGER_PROJECT="ibm-cert-manager"
LICENSE_MANAGER_PROJECT="ibm-licensing"
DEDICATED_CS_PROJECT="cs-control"
# Directory for upgrade operator and prerequisites
UPGRADE_TEMP_FOLDER=${TEMP_FOLDER}/upgrade
UPGRADE_PREREQUISITE_FOLDER=${UPGRADE_TEMP_FOLDER}/prerequisites
UPGRADE_CERT_MANAGER_FILE=${UPGRADE_PREREQUISITE_FOLDER}/cert_manager_operator.yaml
UPGRADE_IBM_LICENSE_FILE=${UPGRADE_PREREQUISITE_FOLDER}/license_operator.yaml
UPGRADE_OPERATOR_GROUP=${UPGRADE_PREREQUISITE_FOLDER}/operator_group.yaml

# Check CS is dedicated or shared
COMMON_SERVICES_CM_NAMESPACE="kube-public"
COMMON_SERVICES_CM_DEDICATED_NAME="common-service-maps"
COMMON_SERVICES_CM_SHARED_NAME="ibm-common-services-status"
COMMON_SERVICES_NAME="IBM Cloud Pak foundational services"
COMMON_SERVICES_CM_DEDICATE_FILE_NAME_UPDATE="common-service-maps-update.yaml"
COMMON_SERVICES_CM_DEDICATE_FILE_NAME="common-service-maps.yaml"
COMMON_SERVICES_CM_DEDICATE_FILE="${PARENT_DIR}/descriptors/${COMMON_SERVICES_CM_DEDICATE_FILE_NAME}"
COMMON_SERVICES_CM_DEDICATE_FILE_UPDATE="${PARENT_DIR}/descriptors/${COMMON_SERVICES_CM_DEDICATE_FILE_NAME_UPDATE}"

# Becomes true if any SSL certificate validation fails (Used in the validate_ssl_certificates function and it's helper functions)
SSL_CERT_ERROR_TAG=false

# Becomes true if any required parameters are null or empty (Used in validate_property_file_required_fields)
MISSING_REQUIRED_PARAMETERS=false

# Global array to store all optional parameter keys
OPTIONAL_PARAMETERS_LIST=()

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
## <https://jsw.ibm.com/browse/DBACLD-187651> - Simplified check_cluster_login()
#############################
# Check cluster Login
#############################
function check_cluster_login() {
    if [[ "$CLI_CMD" == "oc" ]]; then
        oc whoami >/dev/null 2>&1
    else
        kubectl auth whoami >/dev/null 2>&1
    fi
    
    if [ $? -gt 0 ]; then
        error "Not logged in to a cluster. Please login to a cluster before running this script."
        exit 1
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
        ${YQ_CMD} -i ".data.$secret_template_field = \"$temp_val\"" "$secret_file"
        ${YQ_CMD} -i "del(.stringData.\"${secret_template_field}\")" "$secret_file"
    else
        ${YQ_CMD} -i ".data.$new_secret_template_field = \"$temp_val\"" "$secret_file"
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

# This function is to generate a truststore password for DB and LDAP verification
# DBACLD-167057
function generate_truststore_password() {
    local pwd_length="${1:-8}"
    local pwd_charset="${2:-A-Za-z0-9}"
    local machine_lower=$(echo "${machine}" | tr '[:upper:]' '[:lower:]')
    if [[ "$machine_lower" == "linux" ]]; then
        < /dev/urandom tr -dc "$pwd_charset" | head -c "$pwd_length"
    else
        < /dev/urandom tr -dc "$pwd_charset" | cut -c1-"$pwd_length"
    fi
    echo
}

# Function to populate the os tablespace section for table index and lob storage
# Takes in 6 parameters
# 1. os_db_name is DB name
# 2. db_type is DB type selected
# 3. os_datasource_number is OS number in the initialize configuration section of the CR
# 4 through 6 is the table , index , storage name provided in the property files

# The function appends the OS name to each of the table , index , storage name provided in the property files and uses that value to populate the CR
# This is because these values must be unique
# https://jsw.ibm.com/browse/DBACLD-175710
function populate_os_tablespaces(){   
    local os_db_name=$1
    local db_type=$2
    local os_datasource_number=$3
    local table_storage_location_prop=$4
    local index_storage_location_prop=$5
    local lob_storage_location_prop=$6

    # All tablespaces are being generated with unique names by appending the OS DB Name in front of it
    # This is because you cannot have same tablespaces
    # https://jsw.ibm.com/browse/DBACLD-175710
    if [[ $table_storage_location_prop != "<Optional>" && $table_storage_location_prop != "" ]]; then
        if [[ $db_type == "oracle" ]]; then
            table_storage_location_prop="${os_db_name}${table_storage_location_prop}"
        else
            table_storage_location_prop="${os_db_name}_${table_storage_location_prop}"
        fi
        if [[ $db_type == "postgresql" ]]; then
            table_storage_location_prop=$(echo $table_storage_location_prop | tr '[:upper:]' '[:lower:]')
        fi
        ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$os_datasource_number].oc_cpe_obj_store_table_storage_location = \"$table_storage_location_prop\"" ${CP4A_PATTERN_FILE_TMP}
    fi

    if [[ $index_storage_location_prop != "<Optional>" && $index_storage_location_prop != "" ]]; then
        if [[ $db_type == "oracle" ]]; then
            index_storage_location_prop="${os_db_name}${index_storage_location_prop}"
        else
            index_storage_location_prop="${os_db_name}_${index_storage_location_prop}"
        fi
        if [[ $db_type == "postgresql" ]]; then
           index_storage_location_prop=$(echo $index_storage_location_prop | tr '[:upper:]' '[:lower:]')
        fi
        ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$os_datasource_number].oc_cpe_obj_store_index_storage_location = \"$index_storage_location_prop\"" ${CP4A_PATTERN_FILE_TMP}

    fi
    if [[ $lob_storage_location_prop != "<Optional>" && $lob_storage_location_prop != "" ]]; then
        if [[ $db_type == "oracle" ]]; then
            lob_storage_location_prop="${os_db_name}${lob_storage_location_prop}"
        else
            lob_storage_location_prop="${os_db_name}_${lob_storage_location_prop}"
        fi
        if [[ $db_type == "postgresql" ]]; then
            lob_storage_location_prop=$(echo $lob_storage_location_prop | tr '[:upper:]' '[:lower:]')
        fi
        ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$os_datasource_number].oc_cpe_obj_store_lob_storage_location = \"$lob_storage_location_prop\"" ${CP4A_PATTERN_FILE_TMP}
    fi
}

# Function that will delete certain cpfs operand requests that have not been removed after a deployment upgraded from 21.0.3
# The problematic operand requests are "iaf-system" and "operandrequest-kafkauser-iaf-system"
# We need to delete these operand requests before the operators are scaled up so they do not cause any impact during the upgrade of other required components
# In 24.0.0 there might be an IFIX where we are using a new version of events operator and these two operand requests try to use an older version which will interfere with a successful upgrade
# https://jsw.ibm.com/browse/DBACLD-178674
function delete_cpfs_operand_requests(){
    local project_name=$1
    to_delete_operand_requests=("iaf-system" "operandrequest-kafkauser-iaf-system")
    current_operand_requests=($(${CLI_CMD} get operandrequests -n $project_name -o custom-columns=NAME:.metadata.name --no-headers))
    # Loop through each operand request
    for req in "${current_operand_requests[@]}"; do
        delete=false

        for to_delete_operand_request in "${to_delete_operand_requests[@]}"; do
            if [[ "$req" == "$to_delete_operand_request" ]]; then
            delete=true
            break
            fi
        done

        if [[ $delete == "true" ]]; then
            echo
            info "The operand request $req is no longer required in the CP4BA $CP4BA_RELEASE_BASE stream.To prevent any disruption in the upgrade, the script will delete the $req operand request."
            info "Deleting operand request $req .. "
            ${CLI_CMD} delete operandrequest "$req" -n $project_name --ignore-not-found
            echo
        fi
    done
}

# Helper function that removes return characters from property and sql files
# https://jsw.ibm.com/browse/DBACLD-179824
function remove_return_characters(){
    local file_name="$1"
    #<https://jsw.ibm.com/browse/DBACLD-170488> Remove the return character that sometimes gets added on a linux machine
    #tmp_file=$(mktemp)
    #sed $'s/\r//g' "$file_name" > "$tmp_file" && mv "$tmp_file" "$file_name"
    ${SED_COMMAND} $'s/\r//g' "$file_name"

}

# Function that loops over all SQL files generated and removes any potential ^M return characters from any of the SQL files generated by the script
# https://jsw.ibm.com/browse/DBACLD-179824
function remove_carriage_returns_from_sql_files() {
    local dir_path="$1"

    if [[ ! -d "$dir_path" ]]; then
        echo "Directory not found: $dir_path"
    else
        find "$dir_path" -type f -name "*.sql" | while IFS= read -r file; do
            #echo "Cleaning: $file"
            remove_return_characters "$file"
        done
    fi
}

# Helper function for (validate_ssl_certificates) to check a single SSL certificate
# check type -> either certificate or key as the validation command for both are different
# config_name -> the configuration for which we are doing the check for i.e LDAP or DB etc
# cert_path -> full cert path including the required name of the cert to check for
# missing_msg -> display message if the cert is not found
# invalid_msg -> display message if the cert is invalid
# valid_msg -> display message if the cert is valid
function check_ssl_cert() {
    local check_type="$1"
    local config_name="$2"
    local cert_path="$3"
    local missing_msg="$4"
    local invalid_msg="$5"
    local valid_msg="$6"

    
    if [[ ! -f "$cert_path" ]]; then
        MISSING_CERTS+=("$config_name|$cert_path")
        error "$missing_msg"
    else
        # If we are checking for a certificate the open ssl command is different from that of private key
        if [[ "$check_type" == "certificate" ]]; then
            if openssl x509 -in "$cert_path" -noout -text >/dev/null 2>&1; then
                success "$valid_msg"
            else
                error "$invalid_msg"
                FAILING_CERTS+=("$config_name|$cert_path")
            fi
        else
            #https://jsw.ibm.com/browse/DBACLD-194329
            # Updated command that will tackle all types of formats of a private key
            if openssl rsa -in "$cert_path" -check -noout >/dev/null 2>&1 || openssl ec -in "$cert_path" -check -noout >/dev/null 2>&1 || openssl pkcs8 -in "$cert_path" -inform PEM -nocrypt -noout >/dev/null 2>&1; then
                success "$valid_msg"
            else
                error "$invalid_msg"
                FAILING_CERTS+=("$config_name|$cert_path")
            fi
        fi
    fi
    
}

# Helper function for (validate_ssl_certificates) to print summary of cert check results
function print_cert_summary() {
    if [[ ${#MISSING_CERTS[@]} -gt 0 ]]; then
        error "The following SSL certificates are missing or incorrectly named. Please ensure these files are present and correctly named before proceeding:\n"
        printf "%-28s | %-80s\n" "Configuration" "Missing Certificate Path"
        printf -- "-----------------------------------------------------------------------------------------------------------------------------------------------\n"
        for entry in "${MISSING_CERTS[@]}"; do
            IFS="|" read -r config path <<< "$entry"
            printf "%-28s | %-80s\n" "$config" "$path"
        done
    fi
    if [[ ${#FAILING_CERTS[@]} -gt 0 ]]; then
        error "The following SSL certificates are present but failed validation. Please check the certificate files and replace them if necessary:\n"
        printf "%-28s | %-80s\n" "Configuration" "Invalid Certificate Path"
        printf -- "-----------------------------------------------------------------------------------------------------------------------------------------------\n"
        for entry in "${FAILING_CERTS[@]}"; do
            IFS="|" read -r config path <<< "$entry"
            printf "%-28s | %-80s\n" "$config" "$path"
        done
    fi
    if [[ ${#MISSING_CERTS[@]} -gt 0 || ${#FAILING_CERTS[@]} -gt 0 ]]; then
        error "Resolve the above SSL certificate issues before continuing with the \"generate\" mode of the cp4a-prerequisites.sh script."
        SSL_CERT_ERROR_TAG=true
    else
        success "All required Database and LDAP SSL certificates are present and valid."
        SSL_CERT_ERROR_TAG=false
    fi
}

# Validates the presence and format of required DB and LDAP SSL certificates.
# Logs status for each cert, and prints a summary table of any missing or invalid ones before exiting.
# https://jsw.ibm.com/browse/DBACLD-180201
function validate_ssl_certificates() {
    INFO "Checking if all Database and LDAP certificates have been copied and are in a valid format"

    SSL_CERT_ERROR_TAG=false

    MISSING_CERTS=()
    FAILING_CERTS=()

    # Build the list of DB aliases from DB_SERVER_LIST
    tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$tmp_db_array"
    IFS=$OIFS

    # Read LDAP SSL flag
    ldap_ssl_enabled=$(prop_ldap_property_file LDAP_SSL_ENABLED | tr '[:upper:]' '[:lower:]')

    # Determine if any DB has SSL enabled
    db_ssl_any="false"
    for db_alias in "${db_server_array[@]}"; do
        flag=$(prop_db_server_property_file "${db_alias}.DATABASE_SSL_ENABLE" | tr '[:upper:]' '[:lower:]')
        if [[ "$flag" == "true" ]]; then
            db_ssl_any="true"
            break
        fi
    done

    # Early exit if LDAP is SSL-enabled
    if [[ "$ldap_ssl_enabled" != "true" ]]; then
        info "Skipping SSL certificate validation for the selected LDAP, as SSL is not enabled in the current LDAP configuration."
        #SSL_CERT_ERROR_TAG=false
    else 
        # LDAP cert check
        check_ssl_cert \
        "certificate" \
        "LDAP" \
        "${LDAP_SSL_CERT_FOLDER}/ldap-cert.crt" \
        "SSL certificate for the LDAP is missing." \
        "SSL certificate for the LDAP is invalid." \
        "SSL certificate for the LDAP is valid."
    fi

    # Early exit if DB is SSL-enabled
    if [[ "$db_ssl_any" != "true" ]]; then
        info "Skipping SSL certificate validation for the chosen database, as either SSL is not enabled in the current Database configuration or EDB Postgres (deployed by the CP4BA Operator) has been chosen in the current Database configuration. "
        #SSL_CERT_ERROR_TAG=false
    else
        # DB cert checks
        for db_alias in "${db_server_array[@]}"; do
            db_ssl_enabled=$(prop_db_server_property_file "${db_alias}.DATABASE_SSL_ENABLE" |
            tr '[:upper:]' '[:lower:]')
            db_type=$(prop_db_server_property_file "${db_alias}.DATABASE_TYPE" |
            tr '[:upper:]' '[:lower:]')
            # If the DB type is postgres-edb then we do not check for SSL certificate as there no requirement for it
            if [[ "$db_type" != "postgresql-edb" ]]; then
                # IF the DB type is postgresql then the user can have client side SSL enabled or not and if so there are different number of certificates and the naming is also different
                if [[ "$db_type" == "postgresql" ]]; then
                    client_server_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $db_alias.POSTGRESQL_SSL_CLIENT_SERVER)")
                    client_server_ssl_flag=$(echo $client_server_ssl_flag | tr '[:upper:]' '[:lower:]')
                    # if the client side SSL is disabled , there is only SSL certificate expected and just like other DBs it must be named db-cert
                    # The reason for this requirement is when we generate the SSL secrets we have specify the full path and that is hardcoded
                    if [[ $client_server_ssl_flag == "no" || $client_server_ssl_flag == "false" || $client_server_ssl_flag == "" || -z $client_server_ssl_flag ]]; then
                        check_ssl_cert \
                        "certificate" \
                        "Database Server - $db_alias" \
                        "${DB_SSL_CERT_FOLDER}/${db_alias}/db-cert.crt" \
                        "SSL certificate for Database server \"$db_alias\" is missing." \
                        "SSL certificate for Database server \"$db_alias\" is invalid." \
                        "SSL certificate for Database server \"$db_alias\" is valid."
                    # if the client side SSL is enabled , there 3 certificates are expected client.key, client.crt and root.crt
                    # The reason for this requirement is when we generate the SSL secrets we have specify the full path and that is hardcoded
                    else
                        check_ssl_cert \
                        "certificate" \
                        "Database Server - $db_alias" \
                        "${DB_SSL_CERT_FOLDER}/${db_alias}/client.crt" \
                        "Client SSL certificate for Database server \"$db_alias\" is missing." \
                        "Client SSL certificate for Database server \"$db_alias\" is invalid." \
                        "Client SSL certificate for Database server \"$db_alias\" is valid."

                        check_ssl_cert \
                        "key" \
                        "Database Server - $db_alias" \
                        "${DB_SSL_CERT_FOLDER}/${db_alias}/client.key" \
                        "Client Key for Database server \"$db_alias\" is missing." \
                        "Client Key for Database server \"$db_alias\" is invalid." \
                        "Client Key for Database server \"$db_alias\" is valid."

                        check_ssl_cert \
                        "certificate" \
                        "Database Server - $db_alias" \
                        "${DB_SSL_CERT_FOLDER}/${db_alias}/root.crt" \
                        "SSL certificate for Database server \"$db_alias\" is missing." \
                        "SSL certificate for Database server \"$db_alias\" is invalid." \
                        "SSL certificate for Database server \"$db_alias\" is valid."
                    fi
                # For other DB types other than postgres and postgres-edb
                else
                    check_ssl_cert \
                    "certificate" \
                    "Database Server - $db_alias" \
                    "${DB_SSL_CERT_FOLDER}/${db_alias}/db-cert.crt" \
                    "SSL certificate for Database server \"$db_alias\" is missing." \
                    "SSL certificate for Database server \"$db_alias\" is invalid." \
                    "SSL certificate for Database server \"$db_alias\" is valid."
                fi
            fi
        done
    fi



    # External PostgreSQL cert checks for IM, ZEN, BTS
    for ext_db in IM ZEN BTS; do
        flag_var="EXTERNAL_POSTGRESDB_FOR_${ext_db}_FLAG"
        external_flag=$(prop_tmp_property_file "$flag_var" \
                        | tr -d '"' \
                        | tr '[:upper:]' '[:lower:]')

        # If the flag is true, we must have a valid cert
        # External postgres DB for BTS/IM/ZEN if enabled should have three certs root.crt, client.crt and client.key
        if [[ "$external_flag" == "true" ]]; then

            cert_folder_var="${ext_db}_DB_SSL_CERT_FOLDER"
            cert_folder="${!cert_folder_var}"
            server_cert_path="${cert_folder}/root.crt"
            clientkey_cert_path="${cert_folder}/client.key"
            client_cert_path="${cert_folder}/client.crt"

            check_ssl_cert \
            "certificate" \
            "External Postgres for $ext_db" \
            "$server_cert_path" \
            "SSL certificate for the external database to be used by $ext_db is missing." \
            "SSL certificate for the external database to be used by $ext_db is invalid." \
            "SSL certificate for the external database to be used by $ext_db is valid."
            
            check_ssl_cert \
            "key" \
            "External Postgres for $ext_db" \
            "$clientkey_cert_path" \
            "Client Key for the external database to be used by $ext_db is missing." \
            "Client Key for the external database to be used by $ext_db is invalid." \
            "Client Key for the external database to be used by $ext_db is valid."
            
            check_ssl_cert \
            "certificate" \
            "External Postgres for $ext_db" \
            "$client_cert_path" \
            "Client SSL certificate for the external database to be used by $ext_db is missing." \
            "Client SSL certificate for the external database to be used by $ext_db is invalid." \
            "Client SSL certificate for the external database to be used by $ext_db is valid."

        else
            info "Skipping SSL certificate validation for external Postgres for ${ext_db}, as external Postgres for ${ext_db} is not enabled in the current setup."
        fi
    done

    print_cert_summary
}

# Fixes: https://jsw.ibm.com/browse/DBACLD
# Validates that all required fields in a property file have valid values.
# Marks all entries in "OPTIONAL_PARAMETERS_LIST" as optional by appending them to the TEMPORARY_PROPERTY_FILE under "OPTIONAL_PARAMETERS:"
# These optional parameters are skipped in validate_property_file_required_fields()
function mark_optional() {
  if grep -q '^OPTIONAL_PARAMETERS:' "$TEMPORARY_PROPERTY_FILE"; then
    # Get the existing line and remove SSL parameters from it
    local existing_line=$(grep '^OPTIONAL_PARAMETERS:' "$TEMPORARY_PROPERTY_FILE")
    local existing_params=$(echo "$existing_line" | sed 's/^OPTIONAL_PARAMETERS://')
    
    # Remove SSL parameters from existing params
    local cleaned_params=$(echo "$existing_params" | sed 's/,LDAP_SSL_SECRET_NAME//g' | sed 's/LDAP_SSL_SECRET_NAME,//g' | sed 's/LDAP_SSL_SECRET_NAME//g')
    cleaned_params=$(echo "$cleaned_params" | sed 's/,LDAP_SSL_CERT_FILE_FOLDER//g' | sed 's/LDAP_SSL_CERT_FILE_FOLDER,//g' | sed 's/LDAP_SSL_CERT_FILE_FOLDER//g')
    cleaned_params=$(echo "$cleaned_params" | sed 's/,EXT_LDAP_SSL_SECRET_NAME//g' | sed 's/EXT_LDAP_SSL_SECRET_NAME,//g' | sed 's/EXT_LDAP_SSL_SECRET_NAME//g')
    cleaned_params=$(echo "$cleaned_params" | sed 's/,EXT_LDAP_SSL_CERT_FILE_FOLDER//g' | sed 's/EXT_LDAP_SSL_CERT_FILE_FOLDER,//g' | sed 's/EXT_LDAP_SSL_CERT_FILE_FOLDER//g')
    
    # Remove database SSL parameters from existing params (using regex to match any database alias)
    cleaned_params=$(echo "$cleaned_params" | sed 's/,[^,]*\.DATABASE_SSL_SECRET_NAME//g' | sed 's/^[^,]*\.DATABASE_SSL_SECRET_NAME,//g' | sed 's/^[^,]*\.DATABASE_SSL_SECRET_NAME$//g')
    cleaned_params=$(echo "$cleaned_params" | sed 's/,[^,]*\.DATABASE_SSL_CERT_FILE_FOLDER//g' | sed 's/^[^,]*\.DATABASE_SSL_CERT_FILE_FOLDER,//g' | sed 's/^[^,]*\.DATABASE_SSL_CERT_FILE_FOLDER$//g')
    cleaned_params=$(echo "$cleaned_params" | sed 's/,[^,]*\.POSTGRESQL_SSL_CLIENT_SERVER//g' | sed 's/^[^,]*\.POSTGRESQL_SSL_CLIENT_SERVER,//g' | sed 's/^[^,]*\.POSTGRESQL_SSL_CLIENT_SERVER$//g')
    
    # Remove the old line
    sed -i '/^OPTIONAL_PARAMETERS:/d' "$TEMPORARY_PROPERTY_FILE"
    
    # Add new parameters to the cleaned list
    local final_params="$cleaned_params"
    for key in "${OPTIONAL_PARAMETERS_LIST[@]}"; do
      if [[ -n "$final_params" ]]; then
        final_params="$final_params,$key"
      else
        final_params="$key"
      fi
    done
    
    # Remove leading/trailing commas and write the new line
    final_params=$(echo "$final_params" | sed 's/^,//' | sed 's/,$//')
    if [[ -n "$final_params" ]]; then
      printf 'OPTIONAL_PARAMETERS:%s\n' "$final_params" >> "$TEMPORARY_PROPERTY_FILE"
    fi
  else
    if [[ ${#OPTIONAL_PARAMETERS_LIST[@]} -gt 0 ]]; then
      local joined_keys
      joined_keys=$(printf '%s,' "${OPTIONAL_PARAMETERS_LIST[@]}")
      joined_keys=${joined_keys%,}
      printf 'OPTIONAL_PARAMETERS:%s\n' "$joined_keys" >> "$TEMPORARY_PROPERTY_FILE"
    fi
  fi
}

# Empty values, single commas, {Base64}, and {xor} are considered invalid.
# For comma-separated values, each part must be non-empty.
function validate_property_file_required_fields() {

    local property_file="$1"

    # Load optional parameters from file
    local optional_line
    optional_line=$(grep '^OPTIONAL_PARAMETERS:' "$TEMPORARY_PROPERTY_FILE" | sed 's/^OPTIONAL_PARAMETERS://')
    
    # Split into array
    local OPTIONAL_PARAMETERS=()
    if [[ -n "$optional_line" ]]; then
        local IFS=','
        for param in $optional_line; do
            OPTIONAL_PARAMETERS+=("$param")
        done
    fi

    # Find all non-comment, non-blank property keys that are empty and not optional
    local missing_required=()

    while IFS='=' read -r key value; do
        # Remove whitespace and quotes
        key=$(echo "$key" | sed -e 's/^ *//' -e 's/ *$//')
        value=$(echo "$value" | sed -e 's/^ *//' -e 's/"//g' -e 's/ *$//')

        # Skip comments and blank lines
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue

        # Skip if key is in OPTIONAL_PARAMETERS
        local is_optional=false
        for optional_param in "${OPTIONAL_PARAMETERS[@]}"; do
            if [[ "$optional_param" == "$key" ]]; then
                is_optional=true
                break
            fi
        done
        
        if [[ "$is_optional" == true ]]; then
            continue
        fi

        # Fail early if value is <Required>, <youruser1>, <yourpassword>
        if [[ "$value" == "<Required>" || "$value" == "<youruser1>" || "$value" == "<yourpassword>" ]]; then
            MISSING_REQUIRED_PARAMETERS=true
            break
        fi

        # Consider as empty: empty, ",...", "...,", "{Base64}", or "{xor}" (case-insensitive, with or without quotes, and only if value is exactly those tokens)
        # Also, if value contains commas, any empty or whitespace only entry is invalid
        val_lc="${value,,}"
        local invalid=0
        if [[ -z "$val_lc" || "$val_lc" == "," || "$val_lc" == "{base64}" || "$val_lc" == "{xor}" ]]; then
            invalid=1
        elif [[ "$value" == *","* ]]; then
            local IFS=','
            local parts=()
            for part in $value; do
                parts+=("$part")
            done
            for part in "${parts[@]}"; do
                local part_trimmed="${part}"
                # Trim whitespace using parameter expansion
                part_trimmed="${part_trimmed#"${part_trimmed%%[![:space:]]*}"}"
                part_trimmed="${part_trimmed%"${part_trimmed##*[![:space:]]}"}"
                if [[ -z "$part_trimmed" ]]; then
                    invalid=1
                    break
                fi
            done
        fi

        if [[ $invalid -eq 1 ]]; then
            missing_required+=("$key")
        fi
    done < "$property_file"

    if [[ "$MISSING_REQUIRED_PARAMETERS" != true ]]; then
        if (( ${#missing_required[@]} )); then
            local uniq_missing=()
            local temp_file="/tmp/validate_temp.$$"
            printf "%s\n" "${missing_required[@]}" | sort -u > "$temp_file"
            while IFS= read -r line; do
                uniq_missing+=("$line")
            done < "$temp_file"
            rm -f "$temp_file"
            
            error "The following required properties are missing values in $property_file:"
            INFO "Parameter Name"
            for param in "${uniq_missing[@]}"; do
                printf "$param\n"
            done
            error "Please provide a non-empty value for each of the above parameters."
            MISSING_REQUIRED_PARAMETERS=true
        else
            success "All required properties in $property_file have valid values."
        fi
    fi
}

# This function is to patch the kafka strimzi podset for an upgrade to a version having Events Operator 5.2 or higher
# The function checks if events operator subscription is on channel 5.2 and if so gets the kafka strimzi podset and replaces an annotation which will allow the zen upgrade to complete
# The subscription for events operator is updated after the new CR is applied and the cp4a-operator/foundation-operator applies the new operand request, so this function is called during upgradeDeploymentStatus
# For https://jsw.ibm.com/browse/DBACLD-199163 https://jsw.ibm.com/browse/DBACLD-199093
function patch_strimzi_podset(){
    local operator_namespace=$1
    local services_namespace=$2

    echo "Checking ibm-events-operator subscription and channel..."
    # Check if the subscription exists
    events_operator_subscription_exists=$(${CLI_CMD} get subscription.operators.coreos.com ibm-events-operator -n $operator_namespace -o name --no-headers 2>/dev/null || echo "")

    if [[ -z "$events_operator_subscription_exists" ]]; then
        echo "Subscription 'ibm-events-operator' not found, skipping"
        strimzi_patched=true
        return
    fi

    # Get the subscription channel
    events_operator_channel=$(${CLI_CMD} get subscription.operators.coreos.com ibm-events-operator -n $operator_namespace -o yaml | ${YQ_CMD} '.spec.channel')

    echo "Current channel: $events_operator_channel"

    #if [[ "$events_operator_channel" =~ ^v5\.[3-9]$ || "$events_operator_channel" =~ ^v[6-9] || "$events_operator_channel" =~ ^v[1-9][0-9] ]]; then
    #    # This handles v5.3-v5.9, v6-v9, and v10+ versions
    #    echo "Channel is $events_operator_channel (v5.3 or newer), setting patch flag to true"
    #    strimzi_patched=true
    #    return 0
    #fi
    # Check if channel is v5.2
    if [[ "$events_operator_channel" == "v5.2" ]]; then
        echo "Events Operator Channel is v5.2, proceeding to check if the events operator is running..."

        # Find the operator pod that starts with ibm-events-operator-v5.2
        events_operator_pod=$(${CLI_CMD} get pods --no-headers -n $operator_namespace -o custom-columns=":metadata.name" | grep "^ibm-events-operator-v5.2" || echo "")

        if [[ -z "$events_operator_pod" ]]; then
            echo "'ibm-events-operator-v5.2' pod is not found"
            return
        fi

        echo "Found operator pod: $events_operator_pod"

        # Check if the pod is in Ready state
        events_operator_pod_ready=$(${CLI_CMD} get pod "$events_operator_pod" -n $operator_namespace -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

        if [[ "$events_operator_pod_ready" != "True" ]]; then
            echo "Operator pod '$events_operator_pod' is not in Ready state"
            return
        fi

        # Get the StrimziPodSet resource
        kafka_podset_exists=$(${CLI_CMD} get strimzipodset iaf-system-kafka -n $services_namespace -o name --no-headers 2>/dev/null || echo "")

        if [[ -z "$kafka_podset_exists" ]]; then
            echo "StrimziPodSet 'iaf-system-kafka' not found"
            return
        fi

        echo "Found StrimziPodSet 'iaf-system-kafka'"

        # Get the current kafka version from the annotation
        kafka_annotation_value=$(${CLI_CMD} get strimzipodset iaf-system-kafka -n $services_namespace -o yaml | ${YQ_CMD} '.metadata.annotations."strimzi.io/kafka-version"')

        if [[ -z "$kafka_annotation_value" || "$kafka_annotation_value" == "null" ]]; then
            strimzi_patched=true
            return
        fi

        echo "Current kafka version: $kafka_annotation_value"

        # Apply the patch directly
        echo "Applying patch to update annotations..."
        ${CLI_CMD} patch strimzipodset iaf-system-kafka -n $services_namespace --type=merge -p "{\"metadata\":{\"annotations\":{\"strimzi.io/kafka-version\":null,\"ibmevents.ibm.com/kafka-version\":\"$kafka_annotation_value\"}}}"

        echo "Successfully updated annotations:"
        echo "- Removed: strimzi.io/kafka-version"
        echo "- Added: ibmevents.ibm.com/kafka-version: $kafka_annotation_value"
        strimzi_patched=true
    else
        echo "Events operator is not at channel v5.2"
    fi
}