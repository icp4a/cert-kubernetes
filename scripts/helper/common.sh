#!/bin/bash

export LC_ALL=C
export LC_CTYPE=C

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

# Open file descriptor 3 for suppressing output
exec 3>/dev/null

# Deployment Pattern Mapping: CR names to Display names
# This associative array provides the pattern name mappings.
# TODO: To avoid duplication, we can investigate using this to replace the separate pattern mappings that are defined in:
# - "helper/select_pattern.sh": in vars "deployment_pattern_names/deployment_pattern_cr_names"
# - "cp4a-prerequisites.sh": in vars "options/options_cr_val"
# - "helper/update-selected-components/update-selected-components.sh": in vars "deployment_pattern_names/deployment_pattern_cr_names"
declare -A PATTERN_DISPLAY_NAMES=(
    ["content"]="Content Cortex Standard Edition"
    ["decisions"]="Operational Decision Manager"
    ["decisions_ads"]="Decision Intelligence Client Managed Software"
    ["application"]="Business Automation Application"
    ["workflow"]="Business Automation Workflow"
    ["workflow-authoring"]="(a) Workflow Authoring"
    ["workflow-runtime"]="(b) Workflow Runtime"
    ["workstreams"]="Automation Workstream Services"
    ["document_processing"]="IBM Automation Document Processing"
    ["document_processing_designer"]="(a) Development Environment"
    ["document_processing_runtime"]="(b) Runtime Environment"
    ["workflow-process-service"]="Workflow Process Service Authoring"
)

# Helper function to get pattern display name from CR name
function get_pattern_display_name() {
    local cr_name="$1"
    echo "${PATTERN_DISPLAY_NAMES[$cr_name]:-$cr_name}"
}

# Deployment Pattern to Foundation Components Mapping
# Maps each pattern to its required foundation components 
# Source: scripts/helper/select_pattern.sh lines 77-90
# IMPORTANT: this mapping is specific to Production deploy on platform OCP (not "other")
declare -A PATTERN_FOUNDATION_COMPONENTS=(
    ["content"]="BAN RR"
    ["decisions"]="BAN RR"
    ["decisions_ads"]="BAN RR"
    ["application"]="BAN RR AE"
    ["workflow"]="BAN RR"
    ["workflow-authoring"]="BAN RR BAS AE"
    ["workflow-runtime"]="BAN RR AE"
    ["workstreams"]="BAN RR AE"
    ["document_processing"]="BAN RR"
    ["document_processing_designer"]="BAN RR AE BAS"
    ["document_processing_runtime"]="BAN RR AE"
)

# Helper function to get foundation components for a pattern
function get_pattern_foundation_components() {
    local cr_name="$1"
    echo "${PATTERN_FOUNDATION_COMPONENTS[$cr_name]:-}"
}

# CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

TEMP_FOLDER=${CUR_DIR}/.tmp

# Define the required Java version based on CP4BA release
REQUIRED_JAVA_MAJOR_VERSION=17  # Semeru 17 is required for CP4BA 25.x


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
FINAL_CR_FOLDER=${CUR_DIR}/generated-cr/project/$1

SSL_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert
LDAP_SSL_CERT_FOLDER=${SSL_CERT_FOLDER}/ldap
EXT_LDAP_SSL_CERT_FOLDER=${SSL_CERT_FOLDER}/external_ldap
DB_SSL_CERT_FOLDER=${SSL_CERT_FOLDER}/db
ZEN_DB_SSL_CERT_FOLDER=${SSL_CERT_FOLDER}/zen_external_db
IM_DB_SSL_CERT_FOLDER=${SSL_CERT_FOLDER}/im_external_db
BTS_DB_SSL_CERT_FOLDER=${SSL_CERT_FOLDER}/bts_external_db
CP4BA_TLS_ISSUER_CERT_FOLDER=${SSL_CERT_FOLDER}/cp4ba_tls_issuer
AE_REDIS_SSL_CERT_FOLDER=${DB_SSL_CERT_FOLDER}/redis-ae
PLAYBACK_REDIS_SSL_CERT_FOLDER=${DB_SSL_CERT_FOLDER}/redis-playback
ADP_GIT_SSL_CERT_FOLDER=${SSL_CERT_FOLDER}/adp_git
ADP_CDRA_CERT_FOLDER=${SSL_CERT_FOLDER}/adp_cdra
ROOT_CA_CERT_FOLDER=${SSL_CERT_FOLDER}/root_ca
EXTERNAL_TLS_CERT_FOLDER=${SSL_CERT_FOLDER}/external_tls
TRUSTED_CERT_FOLDER=${SSL_CERT_FOLDER}/trusted_cert_list

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
FNCM_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/content-cortex
BAN_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/ban
ODM_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/odm
BAS_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/bas
ADP_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/adp
ADS_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/dicms
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

FNCM_SECRET_FOLDER=${SECRET_FILE_FOLDER}/content-cortex
FNCM_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-content-cortex-secret.yaml

FNCM_ICC_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-content-cortex-icc-secret.yaml
FNCM_ICCSAP_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-content-cortex-iccsap-secret.yaml
FNCM_IER_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-content-cortex-ier-secret.yaml
FNCM_DB_SSL_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-content-cortex-db-ssl-cert-secret.sh



# AI Services secret file related variables
AI_SERVICES_SECRET_FOLDER=${SECRET_FILE_FOLDER}/aiservices
AI_SERVICES_SECRET_FILE=${AI_SERVICES_SECRET_FOLDER}/ibm-providers-config-secret.yaml
AI_SERVICES_SSL_SECRET_NAME="watsonx-lwe-ssl-secret"	
AI_SERVICES_SSL_SECRET_FILE=${AI_SERVICES_SECRET_FOLDER}/${AI_SERVICES_SSL_SECRET_NAME}.sh
# AI services property file location
AI_SERVICES_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/cp4ba_ai_services.property
WATSONX_SSL_CERT_FOLDER=${SSL_CERT_FOLDER}/aiservices

# AI services CR file locations
CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_content_cortex_ai_services_cr_final_tmp.yaml
CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_FINAL=$FINAL_CR_FOLDER/content-cortex-ai-services/ibm_content_cortex_ai_services_cr_final.yaml
CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE=${PARENT_DIR}/descriptors/patterns/content-cortex-ai-services/ibm_cp4a_cr_production_content_cortex_ai_services.yaml


BAN_SECRET_FOLDER=${SECRET_FILE_FOLDER}/ban
BAN_SECRET_FILE=${BAN_SECRET_FOLDER}/ibm-ban-secret.yaml
BAN_DB_SSL_SECRET_FILE=${BAN_SECRET_FOLDER}/ibm-ban-db-ssl-cert-secret.sh

ODM_SECRET_FOLDER=${SECRET_FILE_FOLDER}/odm
ODM_SECRET_FILE=${ODM_SECRET_FOLDER}/ibm-odm-db-secret.yaml
ODM_KEYSTORE_SECRET_FILE=${ODM_SECRET_FOLDER}/ibm-odm-keystore-secret.yaml
ODM_DB_SSL_SECRET_FILE=${ODM_SECRET_FOLDER}/ibm-odm-db-ssl-cert-secret.sh

ADP_SECRET_FOLDER=${SECRET_FILE_FOLDER}/adp
ADP_BASE_DB_SECRET_FILE=${ADP_SECRET_FOLDER}/ibm-aca-db-secret.sh
ADP_BASE_DB_SECRET_YAML_FILE=${ADP_SECRET_FOLDER}/ibm-aca-db-secret.yaml
ADP_GIT_SSL_SECRET_FILE=${ADP_SECRET_FOLDER}/ibm-adp-git-connection-secret.sh
ADP_CDRA_SSL_SECRET_FILE=${ADP_SECRET_FOLDER}/ibm-adp-cdra-ssl-secret.sh
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

#add DICMS varibles
ADS_SECRET_FOLDER=${SECRET_FILE_FOLDER}/dicms
ADS_SECRET_FILE=${ADS_SECRET_FOLDER}/ibm-dba-ads-mongo-secret.yaml
ADS_DB_SSL_SECRET_FILE=${ADS_SECRET_FOLDER}/ibm-dba-ads-mongo-db-ssl-cert-secret.sh
ADS_DESIGNER_FILE=${ADS_SECRET_FOLDER}/ibm-ads-designer-database.yaml
ADS_RUNTIME_FILE=${ADS_SECRET_FOLDER}/ibm-ads-runtime-database.yaml

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
CP4BA_RELEASE_BASE="26.0.0"
# CP4BA_RELEASE_BASE_MAJOR_VERSION is used in certain checks where we used to hardcode to see if a upgrade is not ifix to ifix,change this only for major release
CP4BA_RELEASE_BASE_MAJOR_VERSION="26.0"
CP4BA_PATCH_VERSION="GA"
# CP4BA_CSV_VERSION is for checking CP4BA operator upgrade status, need to update for each IFIX
CP4BA_CSV_VERSION="v26.0.0"
# CP4BA_CHANNEL_VERSION is for switch CP4BA operator upgrade status, need to update for major release
CP4BA_CHANNEL_VERSION="v26.0"
# Storage Validation prerequisites versions
STORAGE_MINIMUM_ANSIBLE_VERSION="2.15"
STORAGE_K8S_CORE_VERSION="6.2.0"

# CS_OPERATOR_VERSION is for checking CPFS operator upgrade status, need to update for each IFIX
CS_OPERATOR_VERSION="v4.18.1"
# CS_CHANNEL_VERSION is for for CPFS script -c option, need to update for each IFIX
CS_CHANNEL_VERSION="v4.18"
# CS CHANNEL VERSION that is used in the KC
CS_CHANNEL_KC="4.x_cd"
# CERT_LICENSE_CHANNEL_VERSION is for for IBM cert-manager/licensing script -c option, need to update for each IFIX
CERT_LICENSE_CHANNEL_VERSION="v4.2"
# CS_CATALOG_VERSION is for CPFS script -s option, need to update for each IFIX
CS_CATALOG_VERSION="ibm-cs-install-catalog-v4-18-0"
# ZEN_OPERATOR_VERSION is for checking ZenService operator upgrade status, need to update for each IFIX
ZEN_OPERATOR_VERSION="v6.4.7"
# BTS_CHANNEL_VERSION is for for BTS, need to update for each IFIX
BTS_CHANNEL_VERSION="v3.35"
# BTS_CATALOG_VERSION is for BTS 3.35.11.
BTS_CATALOG_VERSION="ibm-bts-operator-catalog-v3-35"
# REQUIREDVER_BTS is for checking bts operator upgrade status before run removal_iaf.sh, need to update for each IFIX
REQUIREDVER_BTS="3.35.11"
# REQUIREDVER_POSTGRESQL is for checking postgresql operator upgrade status before run removal_iaf.sh, need to update for each IFIX
REQUIREDVER_POSTGRESQL="1.25.6"
# EVENTS_OPERATOR_VERSION is for checking IBM Events operator upgrade status, need to update for each IFIX
EVENTS_OPERATOR_VERSION="v5.2.1"
#This is the list where we further restricted the versions that are supported for upgrade to $CP4BA_CSV_VERSION.  
#This should change with each new version of CP4BA.  For example, if the next version is 25.0.1, we need to update this list to include the minimum version that is supported for upgrade to 25.0.1 such as 25.0.0.
# 24.1.2 means the customer must have 24.1.2 installed to upgrade to 25.0.0.
# When setting to an empty array, only fresh installation is supported.
# In 26.0.0, we will only support upgrade from 25.0.4, 25.1.1, and 24.0.9, which means if the customer is on 24.1.x, they need to first upgrade to 25.0.4 before upgrading to 26.0.0.
MINIMUM_SUPPORTED_UPGRADE_VERSIONS=(24.0.9 25.0.4 25.1.1)

# UMS Related Variables

# UMS_CHANNEL_VERSION is for UMS, need to update for each IFIX
UMS_CHANNEL_VERSION="v1.0"
# UMS_CSV_VERSION is for UMS, need to update for each IFIX
UMS_CSV_VERSION="v1.0.6"
# UMS_CATALOG_VERSION is the current UMS catalog name.
UMS_CATALOG_VERSION="ibm-usage-metering-catalog"
# UMS connection point secret name
UMS_CONNECTION_POINT_SECRET_NAME="cp4ba-ums-secret"
# UMS OPERATOR subscription template location
UMS_OLM_SUBSCRIPTION=${PARENT_DIR}/descriptors/op-olm/cp4ba-metrics/subscription.yaml
# UMS static CR location
UMS_STATIC_CR_LOCATION="${PARENT_DIR}/descriptors/patterns/cp4ba-metrics"
# UMS Connection Point Static CR location
UMS_CONNECTION_POINT_STATIC_CR_LOCATION="${PARENT_DIR}/descriptors/patterns/cp4ba-metrics/software-central-connection"


#VPC metrics Related Variables

# Connection connection point secret name
ILS_CONNECTION_POINT_SECRET_NAME="cp4ba-ils-secret"

# Zen metastore EDB configmap name
ZEN_EDB_CFG="ibm-zen-metastore-edb-cm"
CERT_MANAGER_PROJECT="ibm-cert-manager"
#Cert manager owner.
CERT_MANAGER_V1ALPHA1_OWNER="operator.ibm.com/v1alpha1"
CERT_MANAGER_V1_OWNER="operator.ibm.com/v1"
LICENSE_MANAGER_PROJECT="ibm-licensing"
DEDICATED_CS_PROJECT="cs-control"
# Directory for upgrade operator and prerequisites
UPGRADE_TEMP_FOLDER=${TEMP_FOLDER}/upgrade
UPGRADE_PREREQUISITE_FOLDER=${UPGRADE_TEMP_FOLDER}/prerequisites
UPGRADE_CERT_MANAGER_FILE=${UPGRADE_PREREQUISITE_FOLDER}/cert_manager_operator.yaml
UPGRADE_IBM_LICENSE_FILE=${UPGRADE_PREREQUISITE_FOLDER}/license_operator.yaml
UPGRADE_OPERATOR_GROUP=${UPGRADE_PREREQUISITE_FOLDER}/operator_group.yaml

# Check CS is dedicated or shared
# COMMON_SERVICES_CM_NAMESPACE="kube-public"
# COMMON_SERVICES_CM_DEDICATED_NAME="common-service-maps"
# COMMON_SERVICES_CM_SHARED_NAME="ibm-common-services-status"
COMMON_SERVICES_NAME="IBM Cloud Pak foundational services"
COMMON_SERVICES_CM_DEDICATE_FILE_NAME_UPDATE="common-service-maps-update.yaml"
COMMON_SERVICES_CM_DEDICATE_FILE_NAME="common-service-maps.yaml"
COMMON_SERVICES_CM_DEDICATE_FILE="${PARENT_DIR}/descriptors/${COMMON_SERVICES_CM_DEDICATE_FILE_NAME}"
COMMON_SERVICES_CM_DEDICATE_FILE_UPDATE="${PARENT_DIR}/descriptors/${COMMON_SERVICES_CM_DEDICATE_FILE_NAME_UPDATE}"

#List of operators to be scale up or down
CP4BA_OPERATOR_LIST="ibm-cp4a-operator ibm-content-operator icp4a-foundation-operator  ibm-ads-operator  ibm-ccx-ai-services-operator ibm-cp4a-wfps-operator ibm-dpe-operator ibm-insights-engine-operator ibm-odm-operator ibm-pfs-operator ibm-workflow-operator"

# CP4BA EDB default instance name
EDB_INSTANCE_CP4BA_NAME="postgres-cp4ba"

# Becomes true if any SSL certificate validation fails (Used in the validate_ssl_certificates function and it's helper functions)
SSL_CERT_ERROR_TAG=false

# Becomes true if any required parameters are null or empty (Used in validate_property_file_required_fields)
MISSING_REQUIRED_PARAMETERS=false

#DBACLD-222678: This variable is used to specify the version that will skip EDB and Starter deployment option. It should be in the format of ${CP4BA_RELEASE_BASE}_${CP4BA_PATCH_VERSION}
# For 26.0.0_GA we will remove the Starter option and EDB option.
VERSION_TO_SKIP_EDB="26.0.0_GA"

# Global array to store all optional parameter keys
OPTIONAL_PARAMETERS_LIST=()

# set CLI_CMD var
if which oc >/dev/null 2>&1; then
    CLI_CMD=oc
elif which kubectl >/dev/null 2>&1; then
    CLI_CMD=kubectl
else
    printf '%b\n'  "\x1B[1;31mUnable to locate Kubernetes CLI or OpenShift CLI. You must install it to run this script.\x1B[0m" && \
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

function prop_content_cortex_ai_services_property_file() {
    grep "^${1}=" ${AI_SERVICES_PROPERTY_FILE}|cut -d'"' -f2
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
        BASE64_DECODE='base64 --decode'
        YQ_CMD=${CUR_DIR}/helper/yq/yq_darwin_amd64
        CPFS_YQ_PATH=$COMMON_SERVICES_SCRIPT_YQ_FOLDER/macos/yq
        COPY_CMD=/bin/cp
    else
        SED_COMMAND='sed -i'
        SED_COMMAND_FORMAT='sed -i s/\r//g'
        BASE64_DECODE='base64 -w 0 --decode'
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
            read -erp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                install_timeout_cli
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                printf '%b\n' "You do not accept, exiting...\n"
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
        printf '%s' "Installing timeout..."; brew install coreutils >/dev/null 2>&1; sudo ln -s /usr/local/bin/gtimeout /usr/local/bin/timeout >/dev/null 2>&1; echo "done.";
    fi
    printf "\n"
}

function install_yq_cli(){
    if [[ ${machine} = "Linux" ]]; then
        printf '%s' "Downloading..."; curl -LO https://github.com/mikefarah/yq/releases/download/3.2.1/yq_linux_amd64  >/dev/null 2>&1; echo "done.";
        printf '%s' "Installing yq..."; sudo chmod +x yq_linux_amd64 >/dev/null; sudo mv yq_linux_amd64 /usr/local/bin/yq >/dev/null; echo "done.";
    else
        printf '%s' "Installing yq..."; brew install yq >/dev/null; echo "done.";
    fi
    printf "\n"
}

function install_kubectl_cli(){
    if [[ ${machine} = "Linux" ]]; then
        printf '%s' "Downloading..."
        if [[ $(uname -m) == 'x86_64' ]]; then
            PLATFORM_ARCH='amd64'
        elif [[ $(uname -m) == 'ppc64le' ]]; then
            PLATFORM_ARCH='ppc64le'
        elif [[ $(uname -m) == 's390x' ]]; then
            PLATFORM_ARCH='s390x'
        fi
        curl -o /tmp/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${PLATFORM_ARCH}/kubectl" >/dev/null 2>&1; echo "done."
        printf '%s' "Installing Kubectl CLI..."; sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl >/dev/null; echo "done.";
    elif [[ ${machine} = "Mac" ]]; then
        printf '%s' "Downloading..."; curl -o /tmp/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl" >/dev/null 2>&1; echo "done.";
        printf '%s' "Installing Kubectl CLI..."; chmod +x /tmp/kubectl >/dev/null; sudo mv /tmp/kubectl /usr/local/bin/kubectl >/dev/null; sudo chown root: /usr/local/bin/kubectl; echo "done.";
    fi
    printf "\n"
}

function install_openssl(){
    if [[ ${machine} = "Linux" ]]; then
        printf '%s' "Installing OpenSSL..."; sudo yum install openssl -y >/dev/null; echo "done.";
    elif [[ ${machine} = "Mac" ]]; then
        printf '%s' "Installing OpenSSL..."; sudo brew install openssl >/dev/null; echo 'export PATH="/usr/local/opt/openssl/bin:$PATH"' >> ~/.bash_profile; source ~/.bash_profile; echo "done.";
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
BOLD_TEXT=`tput bold`
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

  printf '%b' "\x1B[1;31m[NEXT ACTIONS]\x1B[0m${1}\n"

}

function warning() {

  msg "\33[33m[✗] ${1}\33[0m"

}



function error() {

  msg "\33[31m[✘] ${1}\33[0m"

}


function msgRed() {

  printf '%b' "\x1B[1;31m[*] ${1}\x1B[0m\n"

}

function fail() {

  msg "\33[31m[FAILED] ${1}\33[0m"

}



function title() {

  msg "\33[1m ($step) ${1}\33[0m"
  step=$((step + 1))

}



function msgB() {

  printf '%b\n' "\x1B[1m${1}\x1B[0m\n"

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
    printf '%b\n' "\x1B[1${PREFIX}${MSG}\x1B[0m"
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
    currentver=$(${CLI_CMD} get nodes | awk 'NR==2{print $5}')
    requiredver="v1.17.1"
    if [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" = "$requiredver" ]; then
        PLATFORM_VERSION="4.4OrLater"
    else
        # PLATFORM_VERSION="3.11"
        PLATFORM_VERSION="4.4OrLater"
        printf '%b\n' "\x1B[1;31mIMPORTANT: Only support OCp4.4 or Later, exit...\n\x1B[0m"
        exit 1
    fi
}

## <https://jsw.ibm.com/browse/DBACLD-161428> - Create a common function to check cluster login for all related scripts.
## <https://jsw.ibm.com/browse/DBACLD-187651> - Simplified check_cluster_login()
#############################
# Check Cluster Login
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
    printf '%b\n' "\x1B[1mApplying the persistent volumes for the Cloud Pak operator by using the storage classname: ${STORAGE_CLASS_NAME}...\x1B[0m"

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
        printf '%b\n' "\x1B[1mDone\x1B[0m"
    else
        printf '%b\n' "\x1B[1;31mFailed\x1B[0m"
    fi
   # Check Operator Persistent Volume status every 5 seconds (max 10 minutes) until allocate.
    ATTEMPTS=0
    TIMEOUT=60
    printf "\n"
    printf '%b\n' "\x1B[1mWaiting for the persistent volumes to be ready...\x1B[0m"
    until ${CLI_CMD} get pvc | grep cp4a-shared-log-pvc | grep -q -m 1 "Bound" || [ $ATTEMPTS -eq $TIMEOUT ]; do
        ATTEMPTS=$((ATTEMPTS + 1))
        printf '%b\n' "......"
        sleep 10
        if [ $ATTEMPTS -eq $TIMEOUT ] ; then
            printf '%b\n' "\x1B[1;31mFailed to allocate the persistent volumes!\x1B[0m"
            printf '%b\n' "\x1B[1;31mRun the following command to check the claim '${CLI_CMD} describe pvc operator-shared-pvc'\x1B[0m"
            exit 1
        fi
    done
    if [ $ATTEMPTS -lt $TIMEOUT ] ; then
            printf '%b\n' "\x1B[1mDone\x1B[0m"
    fi
}

function save_log(){
    local LOG_DIR="$CUR_DIR/$1"
    LOG_FILE="$LOG_DIR/$2_$(date +'%Y%m%d%H%M%S').log"
    local output_to_stderr="${3:-false}"  # Optional 3rd parameter

    if [[ ! -d $LOG_DIR ]]; then
        mkdir -p "$LOG_DIR"
    fi
    
    # Output LOGFILE to stderr BEFORE redirecting (for FastAPI integration)
    if [[ "$output_to_stderr" == "true" ]]; then
        echo "LOGFILE:$LOG_FILE" >&2
    fi
    
    # Redirect output to log-file
    exec > >(tee -a "$LOG_FILE") 2>&1
    
    # Open fd 3 directly to log file
    exec 3>> "$LOG_FILE"
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
    echo "$encoded"
  fi
}

# Function to decode Base64-encoded password if it has {Base64} prefix otherwise returns original value
# Usage: decoded_pwd=$(decode_base64_password "$password_value")
# Returns: decoded password if {Base64} prefix exists, otherwise returns original value
function decode_base64_password() {
    local password_value="$1"
    
    # Check if password starts with {Base64} prefix
    if [[ "${password_value:0:8}" == "{Base64}" ]]; then
        # Remove {Base64} prefix and decode
        echo "$password_value" | sed -e "s/^{Base64}//" | base64 --decode
    else
        # Return original value if no {Base64} prefix
        echo "$password_value"
    fi
}

# Function to encode the certificate contents to a base64 string
function encode_crt_file_to_base64() {
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
            temp_val=$(printf '%s' "$password_value" | base64 -w 0 )
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

    openssl rand -base64 64 | tr -dc "$pwd_charset" | head -c "$pwd_length"

    echo
}


# All inputs were made to lowercase, default was set to false if no input was given and a message is displayed before the script actually exits
# For https://jsw.ibm.com/browse/DBACLD-201592
function prompt_to_continue() {
    while true; do
        printf "\x1B[1mPlease confirm that you are ready to continue.  Enter Yes to continue or No to exit (Yes/No, default: No): \x1B[0m"
        read -erp "" ans
        ans=$(echo "$ans" | tr '[:upper:]' '[:lower:]')
        if [ -z "$ans" ]; then
            ans="no"
        fi
        case "$ans" in
        "y"|"yes")
            break
            ;;
        "n"|"no")
            info "The script will now exit...\n"
            exit
            ;;
        *)
            printf '%b\n' "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

# Function that retrieves the networktype and network cidr range
# This function is used in the cp4a-clusteradmin-setup.sh for fresh install ( mode is "fresh_install")
# This function is used in the cp4a-deployment script in upgradeDeployment mode for upgrade ( mode is "upgrade")
# https://jsw.ibm.com/browse/DBACLD-173602
function retrieve_network_details(){
    local mode=$1
    local namespace=$2
    network_type=""
    network_cidr=""
    if ! network_configuration_output=$(${CLI_CMD} get network cluster -o yaml 2>/dev/null) ; then
        printf "${YELLOW_TEXT}[IMPORTANT]${RESET_TEXT}"
        printf "\n"
        printf "The user does not have sufficient permissions to retrieve cluster network details. As a result, the \"ibm-cp4a-common-configmap\" ConfigMap must be manually updated with the correct network CIDR and network type. This step is required before applying the custom resource file."
        printf "\n"
        printf "${YELLOW_TEXT}[NOTE]:${RESET_TEXT} In OCP or ROKS, this information can be obtained by querying the Network resource \"${CLI_CMD} get network cluster -o yaml\" or by retrieving the details from the OCP Console."
        printf "Then update the 'ibm-cp4ba-common-config' configMap in the namespace where CP4BA is deployed with the following command: \" ${CLI_CMD} patch configmap ibm-cp4ba-common-config -n <CP4BA-namespace> --type merge -p \"{ \"data\": { \"network_cidr\": \"<cidr range from command>\", \"network_type\": \"<networkType from command>\" } } \" where the values being patched are the CIDR range and networkType that you obtained from the command above respectively."
        printf "\n"
    else
        network_cidr=$(${YQ_CMD} '.spec.clusterNetwork[0].cidr // ""' - <<< "$network_configuration_output")
        network_type=$(${YQ_CMD} '.spec.networkType // ""' - <<< "$network_configuration_output")
    fi

    if [[ "$mode" == "upgrade" && ( ! -z $network_cidr ) && ( ! -z $network_type )  ]]; then
        printf "\n"
        info " Patching the ibm-cp4ba-common-config configMap with the Cluster Network details... "
        printf "\n"
        if ${CLI_CMD} get configMap ibm-cp4ba-common-config -n $namespace >/dev/null 2>&1; then
            ${CLI_CMD} patch configmap ibm-cp4ba-common-config -n $namespace --type merge -p "{ \"data\": { \"network_cidr\": \"${network_cidr}\", \"network_type\": \"${network_type}\" } }"
        fi
    fi


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
            table_storage_location_prop=$(echo "$table_storage_location_prop" | tr '[:upper:]' '[:lower:]')
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
           index_storage_location_prop=$(echo "$index_storage_location_prop" | tr '[:upper:]' '[:lower:]')
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
            lob_storage_location_prop=$(echo "$lob_storage_location_prop" | tr '[:upper:]' '[:lower:]')
        fi
        ${YQ_CMD} -i ".spec.initialize_configuration.ic_obj_store_creation.object_stores.[$os_datasource_number].oc_cpe_obj_store_lob_storage_location = \"$lob_storage_location_prop\"" ${CP4A_PATTERN_FILE_TMP}
    fi
}


# Function that will delete certain cpfs operand requests that have not been removed after a deployment upgraded from 21.0.3
# The problematic operand requests are "iaf-system" and "operandrequest-kafkauser-iaf-system"
# We need to delete these operand requests before the operators are scaled up so they do not cause any impact during the upgrade of other required components
# In 25.0.0 we are using a new version of events operator and these two operand requests try to use an older version which will interfere with a successful upgrade
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

# Function that cleans up temporary files created during the execution of a specific script
# Moved this function to the common.sh so it can be used by cp4a-content-assistant.sh script and cp4a-prerequisites.sh  -> https://jsw.ibm.com/browse/DBACLD-185712
function clean_up_temp_file(){
    local files=()
    files=($(find $PREREQUISITES_FOLDER -name '*.*""'))
    for item in ${files[*]}
    do
        rm -rf $item >/dev/null 2>&1
    done

    files=($(find $TEMP_FOLDER -name '*.*""'))
    for item in ${files[*]}
    do
        rm -rf $item >/dev/null 2>&1
    done
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

# Same as function "check_ssl_cert" above, but allow for empty file as a backdoor, in case the 
# user prefers to provide cert directly in their secret template instead of as file.
#
# Helper function for (validate_ssl_certificates) to check a single SSL certificate
# check type -> either certificate or key as the validation command for both are different
# config_name -> the configuration for which we are doing the check for i.e LDAP or DB etc
# cert_path -> full cert path including the required name of the cert to check for
# missing_msg -> display message if the cert is not found
# invalid_msg -> display message if the cert is invalid
# valid_msg -> display message if the cert is valid
function check_ssl_cert_allow_empty() {
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
        file_content=$(<"$cert_path")
 
        # Check if files are empty
        if [[ -z "$file_content" ]]; then
            warning "The file at $cert_path is empty. The secret template will be created with a placeholder that you need to replace with the correct value later."
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
        success "All required SSL certificates are present and valid."
        SSL_CERT_ERROR_TAG=false
        echo
    fi
}

# Validates the presence and format of required DB and LDAP SSL certificates.
# Logs status for each cert, and prints a summary table of any missing or invalid ones before exiting.
# https://jsw.ibm.com/browse/DBACLD-180201
function validate_ssl_certificates() {
    INFO "Checking if all required SSL certificates have been copied and are in a valid format"

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
            db_ssl_enabled=$(prop_db_server_property_file "${db_alias}.DATABASE_SSL_ENABLE" | tr '[:upper:]' '[:lower:]')
            db_type=$(prop_db_server_property_file "${db_alias}.DATABASE_TYPE" | tr '[:upper:]' '[:lower:]')
            # If the DB type is postgres-edb then we do not check for SSL certificate as there no requirement for it
            if [[ "$db_type" != "postgresql-edb" ]]; then
                # IF the DB type is postgresql then the user can have client side SSL enabled or not and if so there are different number of certificates and the naming is also different
                if [[ "$db_type" == "postgresql" ]]; then
                    client_server_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $db_alias.POSTGRESQL_SSL_CLIENT_SERVER)")
                    client_server_ssl_flag=$(echo "$client_server_ssl_flag" | tr '[:upper:]' '[:lower:]')
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

    # If vault is enabled, use special check for shared secrets (root_ca_secret, external_tls_certificate, ...)
    if [[ $vault_enabled == 'true' ]]; then
        root_ca_secret="$(prop_user_profile_property_file CP4BA.ROOT_CA_SECRET 2>/dev/null || echo '')"
        if [[ -n "$root_ca_secret" && "$root_ca_secret" != "<Optional>" ]]; then
            # check "tls.crt" file
            check_ssl_cert_allow_empty \
            "certificate" \
            "Root CA certificate" \
            "${ROOT_CA_CERT_FOLDER}/tls.crt" \
            "Root CA certificate file at \"${ROOT_CA_CERT_FOLDER}/tls.crt\" is missing. If you do not want to customize root CA certificate, unset CP4BA.ROOT_CA_SECRET property. If you do not want to provide the file, create empty file at the location and rerun. A placeholder will be used in the template." \
            "Root CA certificate file at \"${ROOT_CA_CERT_FOLDER}/tls.crt\" is invalid. If you do not want to customize root CA certificate, unset CP4BA.ROOT_CA_SECRET property. If you do not want to provide the file, create empty file at the location and rerun. A placeholder will be used in the template." \
            "Root CA certificate file at \"${ROOT_CA_CERT_FOLDER}/tls.crt\" is valid."
        
            # check "tls.key" file
            check_ssl_cert_allow_empty \
            "key" \
            "Root CA certificate private key" \
            "${ROOT_CA_CERT_FOLDER}/tls.key" \
            "Root CA certificate key file at \"${ROOT_CA_CERT_FOLDER}/tls.key\" is missing. If you do not want to customize root CA certificate, unset CP4BA.ROOT_CA_SECRET property. If you do not want to provide the file, create empty file at the location and rerun. A placeholder will be used in the template." \
            "Root CA certificate key file at \"${ROOT_CA_CERT_FOLDER}/tls.key\" is invalid. If you do not want to customize root CA certificate, unset CP4BA.ROOT_CA_SECRET property. If you do not want to provide the file, create empty file at the location and rerun. A placeholder will be used in the template." \
            "Root CA certificate key file at \"${ROOT_CA_CERT_FOLDER}/tls.key\" is valid."
        fi
        
        # Generate external TLS certificate secret template if user has customized it
        external_tls_cert_secret="$(prop_user_profile_property_file CP4BA.EXTERNAL_TLS_CERTIFICATE_SECRET 2>/dev/null || echo '')"
        if [[ -n "$external_tls_cert_secret" && "$external_tls_cert_secret" != "<Optional>" ]]; then
            # check "tls.crt" file
            check_ssl_cert_allow_empty \
            "certificate" \
            "External TLS certificate" \
            "${EXTERNAL_TLS_CERT_FOLDER}/tls.crt" \
            "External TLS certificate file at \"${EXTERNAL_TLS_CERT_FOLDER}/tls.crt\" is missing. If you do not want to customize external TLS certificate, unset CP4BA.EXTERNAL_TLS_CERTIFICATE_SECRET property. If you do not want to provide the file, create empty file at the location and rerun. A placeholder will be used in the template." \
            "External TLS certificate file at \"${EXTERNAL_TLS_CERT_FOLDER}/tls.crt\" is invalid. If you do not want to customize external TLS certificate, unset CP4BA.EXTERNAL_TLS_CERTIFICATE_SECRET property. If you do not want to provide the file, create empty file at the location and rerun. A placeholder will be used in the template." \
            "External TLS certificate file at \"${EXTERNAL_TLS_CERT_FOLDER}/tls.crt\" is valid."
        
            # check "tls.key" file
            check_ssl_cert_allow_empty \
            "key" \
            "External TLS certificate private key" \
            "${EXTERNAL_TLS_CERT_FOLDER}/tls.key" \
            "External TLS certificate key file at \"${EXTERNAL_TLS_CERT_FOLDER}/tls.key\" is missing. If you do not want to customize external TLS certificate, unset CP4BA.EXTERNAL_TLS_CERTIFICATE_SECRET property. If you do not want to provide the file, create empty file at the location and rerun. A placeholder will be used in the template." \
            "External TLS certificate key file at \"${EXTERNAL_TLS_CERT_FOLDER}/tls.key\" is invalid. If you do not want to customize external TLS certificate, unset CP4BA.EXTERNAL_TLS_CERTIFICATE_SECRET property. If you do not want to provide the file, create empty file at the location and rerun. A placeholder will be used in the template." \
            "External TLS certificate key file at \"${EXTERNAL_TLS_CERT_FOLDER}/tls.key\" is valid."
        fi
        
        # Validate trusted certificate list if user has specified them
        trusted_cert_list="$(prop_user_profile_property_file CP4BA.TRUSTED_CERTIFICATE_LIST 2>/dev/null || echo '')"
        if [[ -n "$trusted_cert_list" && "$trusted_cert_list" != "<Optional>" ]]; then
            # Remove any spaces and split by comma
            trusted_cert_list=$(echo "$trusted_cert_list" | tr -d ' ')
            IFS=',' read -ra cert_array <<< "$trusted_cert_list"
            
            for cert_name in "${cert_array[@]}"; do
                if [[ -n "$cert_name" ]]; then
                    # Check the certificate file for each trusted certificate
                    check_ssl_cert_allow_empty \
                    "certificate" \
                    "Trusted certificate: ${cert_name}" \
                    "${TRUSTED_CERT_FOLDER}/${cert_name}.crt" \
                    "Trusted certificate file \"${cert_name}.crt\" is missing at \"${TRUSTED_CERT_FOLDER}/\". If you do not want to include this certificate, remove it from CP4BA.TRUSTED_CERTIFICATE_LIST property. If you do not want to provide the file, create empty file at the location and rerun. A placeholder will be used in the template." \
                    "Trusted certificate file \"${cert_name}.crt\" is invalid at \"${TRUSTED_CERT_FOLDER}/\". If you do not want to include this certificate, remove it from CP4BA.TRUSTED_CERTIFICATE_LIST property. If you do not want to provide the file, create empty file at the location and rerun. A placeholder will be used in the template." \
                    "Trusted certificate file \"${cert_name}.crt\" is valid at \"${TRUSTED_CERT_FOLDER}/\"."
                fi
            done
        fi
    fi

    # AI Services cert check for multi-provider configuration
    # Check SSL certificates for WatsonX LWE providers with SSL enabled
    # Note: PARSED_PROVIDERS array is populated by parse_multi_provider_property_file()
    # which is called in cp4a-prerequisites.sh before validate_ssl_certificates()
    if [[ -f "$AI_SERVICES_PROPERTY_FILE" && "$SETUP_CONTENT_CORTEX_AI_SERVICES" == "true" ]]; then
        # Check if PARSED_PROVIDERS array exists and has data
        if [[ ${#PARSED_PROVIDERS[@]} -gt 0 ]]; then
            local has_lwe_ssl=false
            local provider_count=0
            
            # Count providers
            for key in "${!PARSED_PROVIDERS[@]}"; do
                if [[ "$key" =~ ^([0-9]+)_PROVIDER_ID$ ]]; then
                    provider_count=$((provider_count + 1))
                fi
            done
            
            # Check each provider for LWE with SSL enabled
            for ((i=1; i<=provider_count; i++)); do
                local provider_name="${PARSED_PROVIDERS[${i}_PROVIDER_NAME]}"
                local provider_enabled="${PARSED_PROVIDERS[${i}_ENABLED]}"
                local ssl_enabled="${PARSED_PROVIDERS[${i}_SSL_ENABLED]}"
                
                if [[ "$provider_enabled" == "true" ]] && [[ "$provider_name" == "watsonx_lightweightengine" ]] && [[ "$ssl_enabled" == "true" ]]; then
                    has_lwe_ssl=true
                    local provider_id="${PARSED_PROVIDERS[${i}_PROVIDER_ID]}"
                    local tls_cert_location="${PARSED_PROVIDERS[${i}_TLS_CERT_LOCATION]}"
                    local cert_file="$tls_cert_location/lwe.crt"
                    
                    check_ssl_cert \
                        "certificate" \
                        "WatsonX LWE ($provider_id)" \
                        "$cert_file" \
                        "SSL certificate for WatsonX Lightweight Engine provider '$provider_id' is missing at: $cert_file" \
                        "SSL certificate for WatsonX Lightweight Engine provider '$provider_id' is invalid at: $cert_file" \
                        "SSL certificate for WatsonX Lightweight Engine provider '$provider_id' is valid."
                fi
            done
            
            if [[ "$has_lwe_ssl" == "false" ]]; then
                info "Skipping SSL certificate validation for AI Services - no WatsonX LWE providers with SSL enabled"
            fi
        else
            info "Skipping SSL certificate validation for AI Services - property file not yet parsed"
        fi
    fi

    print_cert_summary
}

#DBACLD-203586: Check if PostgreSQL client authentication is enabled
# Returns 0 (true) when POSTGRESQL_SSL_CLIENT_SERVER and DATABASE_SSL_ENABLE are both set to `true`
# Returns 1 (false) otherwise
function is_pg_client_auth() {
    # Build the list of DB aliases from DB_SERVER_LIST
    local tmp_pg_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_pg_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_pg_array")
    
    local OIFS=$IFS
    local db_server_array
    IFS=',' read -ra db_server_array <<< "$tmp_pg_array"
    IFS=$OIFS

    # Check each database server
    for db_alias in "${db_server_array[@]}"; do
        local db_ssl_enabled=$(prop_db_server_property_file "${db_alias}.DATABASE_SSL_ENABLE" | tr '[:upper:]' '[:lower:]')
        
        # Check if this is PostgreSQL with SSL enabled
        if [[ "$db_ssl_enabled" == "true" ]]; then
            local client_server_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $db_alias.POSTGRESQL_SSL_CLIENT_SERVER)")
            client_server_ssl_flag=$(echo $client_server_ssl_flag | tr '[:upper:]' '[:lower:]')
            
            # If client-server SSL is enabled, return true
            if [[ "$client_server_ssl_flag" == "yes" || "$client_server_ssl_flag" == "true" ]]; then
                return 0
            fi
        fi
    done
    
    # No PostgreSQL databases with client auth found
    return 1
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
    
    # Remove database password parameters from existing params (using regex to match DB password fields specifically)
    # Match patterns like: postgres.XXX_DB_USER_PASSWORD or ADP_PROJECT_DB_USER_PASSWORD
    cleaned_params=$(echo "$cleaned_params" | sed 's/,[^,]*_DB_USER_PASSWORD//g' | sed 's/^[^,]*_DB_USER_PASSWORD,//g' | sed 's/^[^,]*_DB_USER_PASSWORD$//g')
    
    # Remove LC_AD_GC_HOST and LC_AD_GC_PORT to prevent duplicates
    cleaned_params=$(echo "$cleaned_params" | sed 's/,LC_AD_GC_HOST//g' | sed 's/LC_AD_GC_HOST,//g' | sed 's/^LC_AD_GC_HOST$//g')
    cleaned_params=$(echo "$cleaned_params" | sed 's/,LC_AD_GC_PORT//g' | sed 's/LC_AD_GC_PORT,//g' | sed 's/^LC_AD_GC_PORT$//g')
    
    # Remove the old line
    ${SED_COMMAND} '/^OPTIONAL_PARAMETERS:/d' "$TEMPORARY_PROPERTY_FILE"
    
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
        #val_lc="${value,,}"
        val_lc=$(echo "$value" | tr '[:upper:]' '[:lower:]')
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


#DBACLD-187443: Skip the creation of `ibm-cert-manager` project if cert-manager is already installed
# This function will detect if there's an existing cert-manager (eg: Redhat Openshift cert-manger or Helm cert-manager) installed in the cluster.  If it is, we'll skip creating the ibm-cert-manager ns.
# this function should return 0 if cert-manager is found, 1 otherwise
function is_cert_manager_installed(){

    info "Checking to see if any cert-manager is installed\n"
    $CLI_CMD get subscriptions -A |grep  "cert-manager"  >  /dev/null 2>&1 # this will catch the packagenames of all cert-manager-operators
    if [ $? -eq 0 ]; then
        warning "There is a cert-manager Subscription already existed\n"
    fi

    local webhook_ns=$($CLI_CMD get deployments -A | grep cert-manager-webhook | cut -d ' ' -f1)
    if [ ! -z "$webhook_ns" ]; then
        warning "There is a cert-manager-webhook pod Running, so most likely another cert-manager is already installed\n"
        info "Continue to check further\n"
        
        # Check if the cert-manager-webhook is owned by ibm-cert-manager-operator
        local api_version=$($CLI_CMD get deployments -n "$webhook_ns" cert-manager-webhook -o jsonpath='{.metadata.ownerReferences[*].apiVersion}' --ignore-not-found)
        if [ ! -z "$api_version" ]; then
            if [ "$api_version" == "$CERT_MANAGER_V1ALPHA1_OWNER" ]; then
                error "Cluster has not deactivated LTSR ibm-cert-manager-operator yet.  Please do so before proceeding."
                return 0
                exit 1
            fi

            if [ "$api_version" != "$CERT_MANAGER_V1_OWNER" ]; then
                warning "Cluster has a non ibm-cert-manager-operator already installed, skipping"
                return 0
            fi

            # IBM cert-manager is installed (regardless of namespace)
            if [[ "$webhook_ns" != "$CERT_MANAGER_PROJECT" ]]; then
                warning "IBM cert-manager is installed but in namespace: $webhook_ns (expected: $CERT_MANAGER_PROJECT)"
            else
                info "IBM cert-manager is already installed in the correct namespace: $webhook_ns"
            fi
            return 0
        else
            warning "Cluster has a RedHat cert-manager or Helm cert-manager, skipping"
            return 0
        fi
    else
        info "There is no cert-manager-webhook pod running\n"
        return 1
    fi
}
#DBACLD-187443: Skip the creation of `ibm-cert-manager` project if cert-manager is already installed
# This function will remove the any catalog entry out of the catalog source list if it exists
# There are three parameters:
# 1. input_file: The input YAML file containing the catalog sources
# 2. output_file: The output YAML file to write the modified catalog sources
# 3. name_to_be_removed: The name of the catalog source to be removed. (eg: ibm-cert-manager-catalog)
function remove_item_from_cs() {
    local input_file="$1"
    local output_file="$2"
    local name_to_be_removed="$3"

    
    # Create an empty output file
    > "$output_file"

    # Process documents one by one (yq v3.3.0 approach)
    doc_index=0
    first_doc=true
    
    while true; do
        # Try to read the document at current index
        doc_content=$($YQ_CMD 'select(documentIndex == '"$doc_index"')' "$input_file" 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$doc_content" ]; then
            break
        fi
        
        # Get the catalog name
        catalog_name=$($YQ_CMD 'select(documentIndex == '"$doc_index"').metadata.name' "$input_file" 2>/dev/null)
        
        # If this is not the cert-manager catalog, include it
        if [ "$catalog_name" != "$name_to_be_removed" ]; then
            if [ "$first_doc" = true ]; then
                echo "$doc_content" >> "$output_file"
                first_doc=false
            else
                echo "---" >> "$output_file"
                echo "$doc_content" >> "$output_file"
            fi
        fi
        
        ((doc_index++))
    done
}

# Function that checks if there are any missing quotes in any property files after the user updates the property files
# Moved this function to the common.sh so it can be used by cp4a-content-assistant.sh script and cp4a-prerequisites.sh  -> https://jsw.ibm.com/browse/DBACLD-185712
function check_missing_quotes(){
    missing_quotes=0
    property_files=("${USER_PROFILE_PROPERTY_FILE}" "${DB_SERVER_INFO_PROPERTY_FILE}" "${DB_NAME_USER_PROPERTY_FILE}" "${LDAP_PROPERTY_FILE}" "${EXTERNAL_LDAP_PROPERTY_FILE}")
    for input_file in "${property_files[@]}"; do
        # Check if the property file exists
        if [ ! -f "$input_file" ]; then
            continue
        fi
        #<https://jsw.ibm.com/browse/DBACLD-170488> Remove the return character that sometimes gets added on a linux machine
        remove_return_characters "$input_file"
        # Array to store incorrect entries
        incorrect_values=()

        while IFS= read -r line || [ -n "$line" ]; do
            # Skip comment lines or empty lines
            if [[ $line =~ ^[[:space:]]*# ]] || [[ -z $line ]]; then
                continue
            fi

            # Skip lines that are completely empty or contain only whitespace
            if [[ "$line" =~ ^[[:space:]]*$ ]]; then
                continue
            fi

            # Ensure the line contains '=' before processing
            if [[ $line != *"="* ]]; then
                continue
            fi

            # Extract the key and value
            key=$(echo "$line" | cut -d'=' -f1)
            value=$(echo "$line" | cut -d'=' -f2-)

            # Check if the value is enclosed in quotes
            if [[ ! $value =~ ^\".*\"$ ]]; then
                # Add to the list of incorrect values
                incorrect_values+=("$key")
            fi
        done < "$input_file"

        # Output results
        if [ ! ${#incorrect_values[@]} -eq 0 ]; then
            missing_quotes=1
            error "Validation failed: The following values in the property file located at \"${input_file}\" are not enclosed in quotes:"
            printf "\n"
            echo "---------------------------------------------------------------"
            for entry in "${incorrect_values[@]}"; do
                echo "  - $entry"
            done
            echo "---------------------------------------------------------------"

        fi
    done
    if [[ "$missing_quotes" == 1 ]] ; then
        info "[NEXT_STEPS]: Reference the table above and ensure all values in all property files are enclosed in quotes and  cp4a-prerequisites.sh script in generate mode."
        exit 1
    fi
}

## -- https://jsw.ibm.com/browse/DBACLD-172803 - Function created to improve code
# Function to check for unfilled <Required> parameters, takes two arguments:
# 1) The style of <Required> filed, e.g. {Base}<Required>, {xor}<Required>
# 2) The property file name to check.
# Moved this function to the common.sh so it can be used by cp4a-content-assistant.sh script and cp4a-prerequisites.sh  -> https://jsw.ibm.com/browse/DBACLD-185712

function check_required_values(){
    required_field=$1
    property_file=$2
    search_text="=\"${required_field}\""
    value_empty=$(grep "${search_text}" "${property_file}" | wc -l)
    if [ $value_empty -ne 0 ] ; then
        #Extract ALL the parameter names and include them in a comma separated list to the error message when the parameters are not properly filled out.
        parameter_name=$(grep "${search_text}" "${property_file}" | awk -F'=' '{print $1}'  | tr -d ' ' | paste -sd ',' -)
        
        # Skip WATSONX_SPACE_ID and WATSONX_PROJECT_ID for AI Services (they have either/or validation)
        parameter_name=$(echo "$parameter_name" | tr ',' '\n' | grep -v "^WATSONX_SPACE_ID$" | grep -v "^WATSONX_PROJECT_ID$" | paste -sd ',' -)
        
        # Only report error if there are parameters left after filtering
        if [[ -n "$parameter_name" ]]; then
            error "Found invalid value(s) \"$required_field\" for parameter \"$parameter_name\" in property file \"${property_file}\", please input the correct value."
            empty_value_tag=1
        fi
    fi
}

# Function that generates the create_secret.sh script
# Moved this function to the common.sh so it can be used by cp4a-content-assistant.sh script and cp4a-prerequisites.sh  -> https://jsw.ibm.com/browse/DBACLD-185712
function generate_create_secret_script(){
    local files=()
    local CREATE_SECRET_SCRIPT_FILE_TMP=$TEMP_FOLDER/create_secret.sh
    > ${CREATE_SECRET_SCRIPT_FILE_TMP}
    > ${CREATE_SECRET_SCRIPT_FILE}

    # Check if secret_template folder is created
    if [ -d $SECRET_FILE_FOLDER ]; then
        files=($(find $SECRET_FILE_FOLDER -name '*.yaml'))

        
        for item in ${files[*]}
        do
            echo "echo \"****************************************************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "echo \"******************************* START **************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "echo \"[INFO] Applying YAML template file:$item\"">> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "${CLI_CMD} apply -f \"$item\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "echo \"******************************** END ***************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "echo \"****************************************************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "printf \"\\n\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        done

        files=($(find $SECRET_FILE_FOLDER -name '*.sh'))

        
        for item in ${files[*]}
        do
            echo "echo \"****************************************************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "echo \"******************************* START **************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "echo \"[INFO] Executing shell script:$item\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "$item" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "echo \"******************************** END ***************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "echo \"****************************************************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "printf \"\\n\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
            echo "" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        done
        ${COPY_CMD} -rf ${CREATE_SECRET_SCRIPT_FILE_TMP} ${CREATE_SECRET_SCRIPT_FILE}
        chmod 755 $CREATE_SECRET_SCRIPT_FILE
    else
        success "No secret is needed for the selected configuration. Skipping this step."
        rm -f $CREATE_SECRET_SCRIPT_FILE
    fi  
}

# Validate custom IAM Admin user using deployment script and change automatically if there is a conflict
# https://jsw.ibm.com/browse/DBACLD-189095

is_valid_username() {
  local u="$1"

  [[ -n "$u" ]] || { warning "Invalid username: value cannot be empty."; return 1; }

  u="$(printf '%s' "$u" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  local len=${#u}
  if (( len == 0 || len > 255 )); then
    warning "Invalid username: length must be between 1 and 255 characters."
    return 1
  fi

  local cleaned
  cleaned="$(printf '%s' "$u" | sed -E 's/[-A-Za-z0-9 =.,:@()_\\&]//g')"

  if [[ -n "$cleaned" ]]; then
    local sample
    sample="$(printf '%s' "$cleaned" | sed -n '1s/^\(.\{1,8\}\).*/\1/p')"
    warning "Invalid username: contains disallowed character(s), for example '${sample}'."
    warning "Allowed characters: letters (a-z, A-Z), digits (0-9), spaces, and = . , - : @ ( ) _ \\ &"
    return 1
  fi

  if ! printf '%s' "$u" | grep -qE '[A-Za-z0-9]'; then
    warning "Invalid username: must contain at least one letter (a-z, A-Z) or digit (0-9)."
    return 1
  fi

  if ! printf '%s' "$u" | grep -qE '^[A-Za-z0-9]'; then
    warning "Invalid username: must begin with a letter (a-z, A-Z) or digit (0-9). Usernames cannot start with a special character."
    return 1
  fi

  return 0
}

iam_user_validation() {
  local username="$1"
  local _host _port _base_dn _bind_dn _bind_pwd _ssl _user_filter
  _host="$(prop_ldap_property_file LDAP_SERVER)"
  _port="$(prop_ldap_property_file LDAP_PORT)"
  _base_dn="$(prop_ldap_property_file LDAP_BASE_DN)"
  _bind_dn="$(prop_ldap_property_file LDAP_BIND_DN)"
  _bind_pwd="$(prop_ldap_property_file LDAP_BIND_DN_PASSWORD)"
  _ssl="$(prop_ldap_property_file LDAP_SSL_ENABLED)"
  _user_filter="$(prop_ldap_property_file LC_USER_FILTER 2>/dev/null)"
  
  #DBACLD-197724 - updating IAM logic to accept base64 password
  if [[ "$_bind_pwd" =~ ^\{[Bb][Aa][Ss][Ee]64\}(.*)$ ]]; then
    local b64_payload="${BASH_REMATCH[1]}"
    local decoded_pwd
    decoded_pwd="$(printf '%s' "$b64_payload" | base64 --decode 2>/dev/null || true)"
    if [[ -n "$decoded_pwd" ]]; then
      _bind_pwd="$decoded_pwd"
    else
      warning "Failed to decode Base64 LDAP bind password — using raw value"
      _bind_pwd="$b64_payload"
    fi
  else
    _bind_pwd="${_bind_pwd#\"}"
    _bind_pwd="${_bind_pwd%\"}"
  fi   

  if [[ -z "$LDAP_PROPERTY_FILE" || -z "$_host" || -z "$_port" || -z "$_base_dn" || -z "$_bind_dn" || -z "$_bind_pwd" ]]; then
    error "Missing LDAP properties. Check LDAP_PROPERTY_FILE=$LDAP_PROPERTY_FILE"
    return 2
  fi

  _base_dn="$(echo "$_base_dn" | tr '[:upper:]' '[:lower:]')"

  local proto="ldap"
  # DBACLD-202948: remove -Dsemeru.fips option from all java commands for connection verification
  local java_opts=""

  if [[ "$(echo "$_ssl" | tr '[:lower:]' '[:upper:]')" == "TRUE" ]]; then
    proto="ldaps"

    local ldap_truststore_pass
    ldap_truststore_pass="$(generate_truststore_password)"
    local tmp_cert_folder
    tmp_cert_folder="$(prop_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER 2>/dev/null || true)"
    local truststore_path="/tmp/ldap-truststore.jks"

    if [[ -z "$tmp_cert_folder" || ! -f "${tmp_cert_folder}/ldap-cert.crt" ]]; then
      echo "iam_user_validation: Not found required certificate file \"ldap-cert.crt\" under \"$tmp_cert_folder\", exit..." >&2
      return 2
    fi

    rm -f /tmp/ldap.der -- "$truststore_path" 2>/dev/null || true

    if ! openssl x509 -outform der -in "${tmp_cert_folder}/ldap-cert.crt" -out /tmp/ldap.der 2>/dev/null; then
      echo "iam_user_validation: failed to convert ${tmp_cert_folder}/ldap-cert.crt to DER" >&2
      return 2
    fi

    if ! "$KEYTOOL_CMD" -import -alias cp4baLdapCerts -keystore "$truststore_path" -file /tmp/ldap.der -storepass "$ldap_truststore_pass" -storetype JKS -noprompt >/dev/null 2>&1; then
      echo "iam_user_validation: keytool failed importing cert into $truststore_path" >&2
      return 2
    fi

    java_opts="$java_opts -Djavax.net.ssl.trustStore=$truststore_path -Djavax.net.ssl.trustStorePassword=$ldap_truststore_pass"
  fi

  local base_dir="${CUR_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  local ldap_jar="${base_dir}/helper/verification/ldap/LdapTest.jar"
  if [[ ! -f "$ldap_jar" ]]; then
    echo "iam_user_validation: LdapTest.jar not found at $ldap_jar" >&2
    return 2
  fi

  local username_b64
  username_b64="$(printf '%s' "$username" | base64 | tr -d '\n')"
  local upl_value="username:${username_b64},password:;"
  local uf
  if [[ -n "$_user_filter" ]]; then
    uf="$_user_filter"
  else
    uf="(&(cn=%v)(objectclass=person))"
  fi

  local -a cmd_arr=(
    "java"
    $java_opts
    "-jar" "$ldap_jar"
    "-u" "$proto://$_host:$_port"
    "-b" "$_base_dn"
    "-D" "$_bind_dn"
    "-w" "$_bind_pwd"
    "-additionalvalidation"
    "-gdn" ""
    "-upl" "$upl_value"
    "-gl" ""
    "-uf" "$uf"
    "-gf" ""
  )

  local output
  output="$("${cmd_arr[@]}" 2>&1)" || true


  if echo "$output" | grep -q "The User ${username} is a valid User"; then
    return 0
  fi

  if echo "$output" | grep -q "The User ${username} is not a valid User"; then
    return 1
  fi
}

# DBACLD-198782: check if Java runtime is available and meets the minimum version requirement
# Parameters:
# $1 - Required major version of Java (e.g., 17)
# Consolidated function to validate Java runtime and set JAVA_CMD/KEYTOOL_CMD
# $1 - (Optional) Custom Java path
function validate_java_runtime() {
    local CUSTOM_JAVA_PATH=$1
    
    # Step 1: Set JAVA_CMD and KEYTOOL_CMD based on CUSTOM_JAVA_PATH
    if [[ -n "$CUSTOM_JAVA_PATH" ]]; then
        # Normalize path - ensure it points to bin directory
        if [[ "$CUSTOM_JAVA_PATH" != */bin ]]; then
            CUSTOM_JAVA_PATH="${CUSTOM_JAVA_PATH}/bin"
        fi
        
        JAVA_CMD="${CUSTOM_JAVA_PATH}/java"
        KEYTOOL_CMD="${CUSTOM_JAVA_PATH}/keytool"
        
        # Verify the custom Java path exists and is executable
        if [[ ! -x "$JAVA_CMD" ]]; then
            printf '%b\n' "\x1B[1;31mError: Java executable not found at specified path: $JAVA_CMD\x1B[0m"
            printf '%b\n' "\x1B[1;31mPlease provide a valid path to Java (JRE) $REQUIRED_JAVA_MAJOR_VERSION or higher installation.\x1B[0m"
            exit 1
        fi
        
        # Verify keytool exists and is executable
        if [[ ! -x "$KEYTOOL_CMD" ]]; then
            printf '%b\n' "\x1B[1;31mError: keytool executable not found at specified path: $KEYTOOL_CMD\x1B[0m"
            printf '%b\n' "\x1B[1;31mPlease provide a valid path to Java (JRE) installation.\x1B[0m"
            exit 1
        fi
    else
        JAVA_CMD="java"
        KEYTOOL_CMD="keytool"
        
        # Verify that default Java is available
        if ! command -v java &> /dev/null; then
            printf '%b\n' "\x1B[1;31mUnable to locate a Java Runtime. Java (JRE)$REQUIRED_JAVA_MAJOR_VERSION or higher must be installed to run this script.\x1B[0m"
            printf '%b\n' "\x1B[1;31mPlease install Java (JRE) $REQUIRED_JAVA_MAJOR_VERSION or higher manually before continuing.\x1B[0m"
            printf '%b\n' "\x1B[1;33mInstallation instructions:\x1B[0m"
            printf '%b\n' "  - Install any compatible Java (JRE) $REQUIRED_JAVA_MAJOR_VERSION or higher distribution (e.g., IBM Semeru, Oracle JDK, or OpenJDK)"
            printf '%b\n' "  - Ensure the new Java version is added to your PATH environment variable"
            printf '%b\n' "  - Re-run this script"
            printf '%b\n' "\x1B[1;33mAlternatively, you can specify the path to an existing Java (JRE) $REQUIRED_JAVA_MAJOR_VERSION or higher installation:\x1B[0m"
            printf '%b\n' " - Re-run this script with the Java (JRE)path parameter, using --java-path <path_to_java>; e.g., $0 -m validate -n $TARGET_PROJECT_NAME --java-path=/custom/java/path"
            exit 1
        fi
        
        # Verify that default keytool is available
        if ! command -v keytool &> /dev/null; then
            printf '%b\n' "\x1B[1;31mUnable to locate keytool. Java (JRE) $REQUIRED_JAVA_MAJOR_VERSION or higher must be installed to run this script.\x1B[0m"
            printf '%b\n' "\x1B[1;31mPlease install Java (JRE) $REQUIRED_JAVA_MAJOR_VERSION or higher manually before continuing.\x1B[0m"
            exit 1
        fi
    fi
    
    # Step 2: Validate Java version
    "$JAVA_CMD" -version &>/dev/null
    if [[ $? -ne 0 ]]; then
        printf '%b\n' "\x1B[1;31mUnable to execute Java. Please check your Java (JRE) installation.\x1B[0m"
        exit 1
    fi
    
    # Extract the full version string
    local CURRENT_JAVA_VERSION=$("$JAVA_CMD" -version 2>&1 | grep -i version | head -n 1 | awk -F '"' '{print $2}')
    
    # Extract just the major version for comparison
    local CURRENT_MAJOR_VERSION=$(echo "$CURRENT_JAVA_VERSION" | awk -F '.' '{print $1}')
    
    # If version starts with "1.", use the second number (e.g., 1.8 -> 8)
    if [[ "$CURRENT_JAVA_VERSION" == 1.* ]]; then
        CURRENT_MAJOR_VERSION=$(echo "$CURRENT_JAVA_VERSION" | awk -F '.' '{print $2}')
    fi
    
    # Check if current version is less than the required version
    if [[ -n "$CURRENT_MAJOR_VERSION" && "$CURRENT_MAJOR_VERSION" -lt "$REQUIRED_JAVA_MAJOR_VERSION" ]]; then
        printf '%b\n' "\x1B[1;31mJava version $CURRENT_JAVA_VERSION is installed but does not meet the minimum requirement (version $REQUIRED_JAVA_MAJOR_VERSION).\x1B[0m"
        printf '%b\n' "\x1B[1;31mPlease upgrade to Java (JRE) $REQUIRED_JAVA_MAJOR_VERSION or higher manually before continuing.\x1B[0m"
        printf '%b\n' "\x1B[1;33mJava (JRE) $REQUIRED_JAVA_MAJOR_VERSION or higher upgrade instructions:\x1B[0m"
        printf '%b\n' "  - Install any compatible Java (JRE) $REQUIRED_JAVA_MAJOR_VERSION or higher distribution (e.g., IBM Semeru, Oracle JDK, or OpenJDK)"
        printf '%b\n' "  - Ensure the new Java version is added to your PATH environment variable"
        printf '%b\n' "  - Re-run this script"
        printf '%b\n' "\x1B[1;33mAlternatively, you can specify the path to an existing Java (JRE) $REQUIRED_JAVA_MAJOR_VERSION or higher installation:\x1B[0m"
        printf '%b\n' " - Re-run this script with the Java (JRE) path parameter, using --java-path <path_to_java>; e.g., $0 -m validate -n $TARGET_PROJECT_NAME --java-path=/custom/java/path"
        exit 1
    fi
    
    info "Using Java version: $CURRENT_JAVA_VERSION located at: $(command -v "$JAVA_CMD")"
    
    # Step 3: Validate keytool
    "$KEYTOOL_CMD" -help &>/dev/null
    if [[ $? -ne 0 ]]; then
        printf '%b\n' "\x1B[1;31mUnable to execute keytool. Keytool is required and should be part of your Java (JRE) installation.\x1B[0m"
        printf '%b\n' "\x1B[1;31mPlease ensure you have a complete Java (JRE) $REQUIRED_JAVA_MAJOR_VERSION or higher installation that includes keytool.\x1B[0m"
        exit 1
    fi
    
    # Step 4: Export the commands so they're available to child scripts
    export JAVA_CMD
    export KEYTOOL_CMD
}

#DBCALD-185209.  The below function is being called in create_fncm_secret_vault_template function cp4ba-secret.sh 
function add_content_os_dynamically() {
    local is_vault_enabled=${1:-false}
    local os_number=${2}
    local vault_path=${3}
    local secret_name=${4}
		# local fncm_secret_file=${5}
    local os_sections=""
    local os_secretprovider_sections=""
    # content_os_number=$(prop_tmp_property_file CONTENT_OS_NUMBER)
  nl=$'\n'
  # Add content OS databases dynamically
  if (( os_number > 0 )); then
    for ((j=0;j<$((os_number));j++))
    do
      # get server/instance for OS
      tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name OS$((j+1))_DB_USER_NAME)"
      tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
      
      # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
      local tmp_postgresql_client_flag=""
      if [[ $DB_TYPE = "postgresql" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
        tmp_postgresql_client_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
      fi
      
      if [[ $DB_TYPE = "postgresql-edb" ]]; then
        tmp_postgresql_client_flag="true"
      fi
      
      tmp_dbuser="$(prop_db_name_user_property_file OS$((j+1))_DB_USER_NAME)"
      tmp_dbuserpwd="$(prop_db_name_user_property_file OS$((j+1))_DB_USER_PASSWORD)"
      
      # Always add username
	  if [[ $is_vault_enabled == "true" ]]; then
            os_sections="$os_sections,
  \"os$((j+1))DBUsername\": \"$tmp_dbuser\""
            
            # Always add username to SecretProviderClass
            os_secretprovider_sections="$os_secretprovider_sections
      - secretPath: \"$vault_path/$secret_name\"
        objectName: \"os$((j+1))DBUsername\"
        secretKey: \"os$((j+1))DBUsername\""
            
            # Only add password if PostgreSQL SSL client authentication is not enabled
            if [[ (! ("$tmp_postgresql_client_flag" == "true" || "$tmp_postgresql_client_flag" == "yes" || "$tmp_postgresql_client_flag" == "y")) || $DB_TYPE == "postgresql-edb" ]]; then
                os_sections="$os_sections,
  \"os$((j+1))DBPassword\": \"$tmp_dbuserpwd\""
                
                # Add password to SecretProviderClass
                os_secretprovider_sections="$os_secretprovider_sections
      - secretPath: \"$vault_path/$secret_name\"
        objectName: \"os$((j+1))DBPassword\"
        secretKey: \"os$((j+1))DBPassword\""
            fi
				else # Non-Vault implementation
					# when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret. Except EDB, we will keep the password in secret even POSTGRESQL_SSL_CLIENT_SERVER is true because EDB needs password to connect.
					if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") || $DB_TYPE == "postgresql-edb" ]]; then
							# For https://jsw.ibm.com/browse/DBACLD-157020
							# Function that updates the secret template with the base64 password
							update_secret_template_passwords "$tmp_dbuserpwd" "osDBPassword" "$FNCM_SECRET_FILE" "os$((j+1))DBPassword"
					fi

					${YQ_CMD} -i ".stringData.os$((j+1))DBUsername = \"$tmp_dbuser\"" "${FNCM_SECRET_FILE}"
        fi # End of vault enabled check
        done # End of for loop
		
		# Only output delimiter sections when in vault mode
		if [[ $is_vault_enabled == "true" ]]; then
			# Output both sections with a unique delimiter that won't appear in the content
			echo "###OS_SECTIONS_START###"
			printf "%s" "$os_sections"
			echo ""
			echo "###OS_SECTIONS_END###"
			echo "###OS_SECRETPROVIDER_SECTIONS_START###"
			printf "%s" "$os_secretprovider_sections"
			echo ""
			echo "###OS_SECRETPROVIDER_SECTIONS_END###"
		fi
	fi
}

#DBACLD-194974: Version to remove EDB and skip Starter deployment option for CP4BA 25.0.1 by checking the version $CP4BA_PATCH_VERSION and $CP4BA_RELEASE_BASE
#Update the version and patch here to skip EDB and Starter deployment option.  
function skip_edb() {
    local _existing_cp4ba_version=${CP4BA_RELEASE_BASE}_${CP4BA_PATCH_VERSION}
    local _version_to_skip="$VERSION_TO_SKIP_EDB"

    if [[ "$_existing_cp4ba_version" == "$_version_to_skip" ]]; then
        return 0  # Skip EDB
    else
        return 1  # Do not skip EDB
    fi
}

#DBACLD-222678: Function to check whether EDB is detected
function is_edb_detected(){
    local ns=$1
    is_edb=$($CLI_CMD get cluster.postgresql.k8s.enterprisedb.io -n $ns --no-headers --ignore-not-found 2>/dev/null | awk {'print $1'} || echo "")
    if [[ ! -z $is_edb ]]; then
        info "The following EDB instances are found: \n$is_edb"
        return 0
    else
        return 1
    fi
}

# DBACLD-238578: Function to create ODM keystore password secret for upgrade
# This function checks if the secret already exists or is referenced in the CR before creating it
function create_odm_keystore_secret_for_upgrade() {
    local namespace=$1
    local cr_file=$2
    local secret_name="ibm-odm-keystore-secret"
    
    # Check if passwordSecretRef is already defined in the CR
    local password_secret_ref=$(${YQ_CMD} '.spec.odm_configuration.dba.passwordSecretRef' "$cr_file" 2>/dev/null)
    
    if [[ -n "$password_secret_ref" && "$password_secret_ref" != "null" ]]; then
        info "ODM keystore password secret reference already exists in CR: $password_secret_ref. Skipping secret creation."
        return 0
    fi
    
    # Check if the secret already exists in the namespace
    local secret_exists=$(${CLI_CMD} get secret "$secret_name" -n "$namespace" --ignore-not-found 2>/dev/null)
    
    if [[ -n "$secret_exists" ]]; then
        info "ODM keystore password secret '$secret_name' already exists in namespace '$namespace'. Skipping secret creation."
        return 0
    fi
    
    # Generate a random 16-character password
    local password=$(openssl rand -hex 8)
    
    # Create the secret using kubectl create secret generic with --from-literal
    ${CLI_CMD} create secret generic "${secret_name}" \
        --from-literal=keystorePassword="${password}" \
        -n "${namespace}" >/dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        # Add the label to the secret
        ${CLI_CMD} label secret "${secret_name}" \
            cp4ba.ibm.com/backup-type=mandatory \
            -n "${namespace}" >/dev/null 2>&1
        
        success "Successfully created ODM keystore password secret '${secret_name}' in namespace '${namespace}'"
    else
        step_num=1
        warning "Failed to automatically create ODM keystore password secret '${secret_name}'. Please create it manually."
        echo
        echo "  - STEP ${step_num} ${RED_TEXT}(Required)${RESET_TEXT} Starting with CP4BA release 26.0.0, deployments that include the Operational Decision Manager (ODM) pattern require a secret named \"ibm-odm-keystore-secret\" to be created before applying the upgraded Custom Resource file."
        echo
        echo "    This secret must contain a 'keystorePassword' field. If this secret already exists in your namespace, no action is required."
        echo
        echo "    To create the secret, follow these sub-steps:"
        echo
        echo "      ${step_num}.a Check if the secret already exists:"
        echo "      ${GREEN_TEXT} # ${CLI_CMD} get secret ibm-odm-keystore-secret -n ${namespace}${RESET_TEXT}"
        echo
        echo "      ${step_num}.b Create the secret with the required label using the following command:"
        echo "      ${GREEN_TEXT} # ${CLI_CMD} create secret generic ibm-odm-keystore-secret --from-literal=keystorePassword=\"\${KEYSTORE_PASSWORD}\" -n ${namespace} ${RESET_TEXT}"
        echo
        echo "      ${step_num}.c Add the required label to the secret:"
        echo "      ${GREEN_TEXT} # ${CLI_CMD} label secret ibm-odm-keystore-secret \"cp4ba.ibm.com/backup-type=mandatory\" -n ${namespace} ${RESET_TEXT}"
        echo
        echo "      ${step_num}.d Verify the secret was created successfully with the correct label:"
        echo "      ${GREEN_TEXT} # ${CLI_CMD} get secret ibm-odm-keystore-secret -n ${namespace} --show-labels ${RESET_TEXT}"
        echo
        echo "    ${YELLOW_TEXT}Note:${RESET_TEXT} For more information, refer to: https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/${CP4BA_RELEASE_BASE}?topic=automation-upgrading"
        echo
    fi
}

# This function is to patch the kafka strimzi podset for an upgrade to a version having Events Operator 5.2 or higher

# DBACLD-240347: Function to copy ibm-workflow-operator-sa service account from operator namespace to services namespace
# This function is needed for CP4BA 26.0.0-GA to ensure the workflow operator service account exists in the services namespace
# Arguments:
#   $1 - operator_ns: The namespace where operators are deployed
#   $2 - services_ns: The namespace where services are deployed
function copy_workflow_operator_sa() {
    local operator_ns=$1
    local services_ns=$2
    
    # Check if the service account exists in the operator namespace
    local sa_exists_in_operator_ns=$(${CLI_CMD} get serviceaccount ibm-workflow-operator-sa -n "$operator_ns" --ignore-not-found 2>/dev/null)
    
    if [[ -n "$sa_exists_in_operator_ns" ]]; then
        # Check if it already exists in the services namespace
        local sa_exists_in_services_ns=$(${CLI_CMD} get serviceaccount ibm-workflow-operator-sa -n "$services_ns" --ignore-not-found 2>/dev/null)
        
        if [[ -z "$sa_exists_in_services_ns" ]]; then
            info "Copying service account 'ibm-workflow-operator-sa' from namespace '$operator_ns' to '$services_ns'"
            
            # Create a temporary file for the service account
            local temp_sa_file=$(mktemp)
            
            # Get the service account from operator namespace and update namespace using yq
            ${CLI_CMD} get serviceaccount ibm-workflow-operator-sa -n "$operator_ns" -o yaml > "$temp_sa_file"
            
            # Update namespace to services namespace
            ${YQ_CMD} -i ".metadata.namespace = \"$services_ns\"" "${temp_sa_file}"
            
            # Remove Kubernetes-managed metadata fields that would cause conflicts
            ${YQ_CMD} -i "del(.metadata.resourceVersion)" "${temp_sa_file}"
            ${YQ_CMD} -i "del(.metadata.uid)" "${temp_sa_file}"
            ${YQ_CMD} -i "del(.metadata.creationTimestamp)" "${temp_sa_file}"
            ${YQ_CMD} -i "del(.metadata.ownerReferences)" "${temp_sa_file}"
            
            # Apply the service account to services namespace
            ${CLI_CMD} apply -f "${temp_sa_file}" -n "$services_ns"
            
            # Verify the service account was created successfully
            local sa_created=$(${CLI_CMD} get serviceaccount ibm-workflow-operator-sa -n "$services_ns" --ignore-not-found 2>/dev/null)
            
            if [[ -n "$sa_created" ]]; then
                success "Successfully copied service account 'ibm-workflow-operator-sa' to namespace '$services_ns'"
            else
                warning "Failed to copy service account 'ibm-workflow-operator-sa' to namespace '$services_ns'"
            fi
            
            # Clean up temporary file
            rm -f "$temp_sa_file"
        else
            info "Service account 'ibm-workflow-operator-sa' already exists in namespace '$services_ns'. Skipping copy."
        fi
    fi
}
# The function checks if events operator subscription is on channel 5.2 and if so gets the kafka strimzi podset and replaces an annotation which will allow the zen upgrade to complete
# The subscription for events operator is updated after the new CR is applied and the cp4a-operator/foundation-operator applies the new operand request, so this function is called during upgradeDeploymentStatus
# For https://jsw.ibm.com/browse/DBACLD-199163 https://jsw.ibm.com/browse/DBACLD-199093
function patch_strimzi_podset(){
    local operator_namespace=$1
    local services_namespace=$2

    echo "Checking the ibm-events-operator subscription and channel..."
    # Check if the events operator subscription exists and get its actual name. we found sometimes the subscription gets created with the channel appended to the name.
    events_operator_subscription_name=$(${CLI_CMD} get subscription.operators.coreos.com -n $operator_namespace --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep "ibm-events-operator" | head -n 1 || echo "")

    if [[ -z "$events_operator_subscription_name" ]]; then
        echo "Subscription matching 'ibm-events-operator' not found, skipping"
        strimzi_patched=true
        return
    fi

    echo "Found subscription: $events_operator_subscription_name"

    # Get the subscription channel using the actual subscription name
    events_operator_channel=$(${CLI_CMD} get subscription.operators.coreos.com "$events_operator_subscription_name" -n $operator_namespace -o yaml 2>/dev/null | ${YQ_CMD} '.spec.channel')

    if [[ -z "$events_operator_channel" || "$events_operator_channel" == "null" ]]; then
        echo "Could not retrieve channel for subscription '$events_operator_subscription_name'"
        return
    fi

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
        kafka_podset_exists=$(${CLI_CMD} get strimzipodsets.core.ibmevents.ibm.com iaf-system-kafka -n $services_namespace -o name --no-headers 2>/dev/null || echo "")

        if [[ -z "$kafka_podset_exists" ]]; then
            echo "StrimziPodSet 'iaf-system-kafka' not found"
            return
        fi

        echo "Found StrimziPodSet 'iaf-system-kafka'"

        # Get the current kafka version from the annotation
        kafka_annotation_value=$(${CLI_CMD} get strimzipodsets.core.ibmevents.ibm.com iaf-system-kafka -n $services_namespace -o yaml | ${YQ_CMD} '.metadata.annotations."strimzi.io/kafka-version"')

        if [[ -z "$kafka_annotation_value" || "$kafka_annotation_value" == "null" ]]; then
            strimzi_patched=true
            return
        fi

        echo "Current kafka version: $kafka_annotation_value"

        # Apply the patch directly
        echo "Applying patch to update annotations..."
        ${CLI_CMD} patch strimzipodsets.core.ibmevents.ibm.com iaf-system-kafka -n $services_namespace --type=merge -p "{\"metadata\":{\"annotations\":{\"strimzi.io/kafka-version\":null,\"ibmevents.ibm.com/kafka-version\":\"$kafka_annotation_value\"}}}"

        echo "Successfully updated annotations:"
        echo "- Removed: strimzi.io/kafka-version"
        echo "- Added: ibmevents.ibm.com/kafka-version: $kafka_annotation_value"
        strimzi_patched=true
    else
        echo "Events operator is not at channel v5.2"
    fi
}


# Function to check if the deployment is SaaS 
# We detect if sc_deploy_zen_with_iaf is explicitly set to false in the CR 
# Returns: "true" if sc_deploy_zen_with_iaf is false, "false" otherwise
# Parameters:
#   $1 - namespace
#   $2 - CR kind (e.g., ICP4ACluster, Content, etc.)
#   $3 - CR name
function check_saas_deployment() {
    local cr_kind="$1"
    local cr_name="$2"
    local namespace="$3"

    # Get the CR and extract sc_deploy_zen_with_iaf value (defaults to true if not set)
    local zen_iaf_value
    zen_iaf_value=$(${CLI_CMD} get "$cr_kind" "$cr_name" -n "$namespace" -o yaml 2>/dev/null | \
        ${YQ_CMD} eval '.spec.shared_configuration.sc_deploy_zen_with_iaf' -)

    # Check if kubectl/yq command failed
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Return true only if value is false, otherwise return false
    # If the value is false that means the deployment is SaaS
    if [[ "$zen_iaf_value" == "false" ]]; then
        return 0
    else
        return 1
    fi
}

function validate_zen_upgrade_status(){
    zen_service_name=$(${CLI_CMD} get zenService --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS |awk '{print $1}')
    if [[ ! -z "$zen_service_name" ]]; then
        clear
        maxRetry=360
        for ((retry=0;retry<=${maxRetry};retry++)); do
            # As workaround for https://github.ibm.com/IBMPrivateCloud/roadmap/issues/64207
            # update secret postgresql-operator-controller-manager-config in <cp4ba> namespace and/or ibm-common-services namespace and add this annotation ibm-bts/skip-updates: "true"
            if ${CLI_CMD} get secret -n $CP4BA_SERVICES_NS --no-headers --ignore-not-found | grep postgresql-operator-controller-manager-config >/dev/null 2>&1; then
                ${CLI_CMD} patch secret postgresql-operator-controller-manager-config -n $CP4BA_SERVICES_NS -p '{"metadata": {"annotations": {"ibm-bts/skip-updates": "true"}}}' >/dev/null 2>&1
            fi

            zenservice_version=$(${CLI_CMD} get zenService $zen_service_name --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o jsonpath='{.status.currentVersion}')
            isCompleted=$(${CLI_CMD} get zenService $zen_service_name --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o jsonpath='{.status.zenStatus}')
            isProgressDone=$(${CLI_CMD} get zenService $zen_service_name --no-headers --ignore-not-found -n $CP4BA_SERVICES_NS -o jsonpath='{.status.progress}')

            if [[ "$isCompleted" != "Completed" || "$isProgressDone" != "100%" || "$zenservice_version" != "${ZEN_OPERATOR_VERSION//v/}" ]]; then
                clear
                CP4BA_DEPLOYMENT_STATUS="Waiting for the zenService to be ready (could take up to 120 minutes) before upgrade the CP4BA capabilities..."
                printf '%s %s\n' "$(date)" "[refresh interval: 60s]"
                printf '%b' "[Press Ctrl+C to exit] \t\t"
                printf "\n"
                echo "${YELLOW_TEXT}$CP4BA_DEPLOYMENT_STATUS${RESET_TEXT}"
                printHeaderMessage "CP4BA Upgrade Status"
                if [[ "$zenservice_version" == "${ZEN_OPERATOR_VERSION//v/}" ]]; then
                    echo "zenService Version (Expected - ${ZEN_OPERATOR_VERSION//v/})       : ${GREEN_TEXT}$zenservice_version${RESET_TEXT}"
                else
                    echo "zenService Version (Expected - ${ZEN_OPERATOR_VERSION//v/})       : ${RED_TEXT}$zenservice_version${RESET_TEXT}"
                fi
                if [[ "$isCompleted" == "Completed" && "$zenservice_version" == "${ZEN_OPERATOR_VERSION//v/}" ]]; then
                    echo "zenService Status (Expected - Completed)    : ${GREEN_TEXT}$isCompleted${RESET_TEXT}"
                else
                    echo "zenService Status (Expected - Completed)    : ${RED_TEXT}$isCompleted${RESET_TEXT}"
                fi

                if [[ "$isProgressDone" == "100%" && "$zenservice_version" == "${ZEN_OPERATOR_VERSION//v/}" ]]; then
                    echo "zenService Progress (Expected - 100%)       : ${GREEN_TEXT}$isProgressDone${RESET_TEXT}"
                else
                    echo "zenService Progress (Expected - 100%)       : ${RED_TEXT}$isProgressDone${RESET_TEXT}"
                fi
                sleep 60
            elif [[ "$isCompleted" == "Completed" && "$isProgressDone" == "100%" && "$zenservice_version" == "${ZEN_OPERATOR_VERSION//v/}" ]]; then
                break
            elif [[ $retry -eq ${maxRetry} ]]; then
                printf "\n"
                warning "Timeout waiting for the Zen Service to start"
                printf '%b\n' "\x1B[1mCheck the status of the Zen Service\x1B[0m"
                printf "\n"
                exit 1
            fi
        done
        clear
        # success "The Zen Service (${ZEN_OPERATOR_VERSION//v/}) is ready for CP4BA"
        CP4BA_DEPLOYMENT_STATUS="The Zen Service (${ZEN_OPERATOR_VERSION//v/}) is ready for CP4BA"
        printf '%s %s\n' "$(date)" "[refresh interval: 30s]"
        printf '%b' "[Press Ctrl+C to exit] \t\t"
        printf "\n"
        echo "${YELLOW_TEXT}$CP4BA_DEPLOYMENT_STATUS${RESET_TEXT}"
        info "Starting all CP4BA Operators to upgrade CP4BA capabilities"
        printHeaderMessage "CP4BA Upgrade Status"
        if [[ "$zenservice_version" == "${ZEN_OPERATOR_VERSION//v/}" ]]; then
            echo "zenService Version        : ${GREEN_TEXT}$zenservice_version${RESET_TEXT}"
        else
            echo "zenService Version        : ${RED_TEXT}$zenservice_version${RESET_TEXT}"
        fi
        if [[ "$isCompleted" == "Completed" ]]; then
            echo "zenService Status         : ${GREEN_TEXT}$isCompleted${RESET_TEXT}"
        else
            echo "zenService Status         : ${RED_TEXT}$isCompleted${RESET_TEXT}"
        fi

        if [[ "$isProgressDone" == "100%" && "$zenservice_version" == "${ZEN_OPERATOR_VERSION//v/}" ]]; then
            echo "zenService Progress       : ${GREEN_TEXT}$isProgressDone${RESET_TEXT}"
        else
            echo "zenService Progress       : ${RED_TEXT}$isProgressDone${RESET_TEXT}"
        fi
    else
        fail "ZenService not found in the project \"$CP4BA_SERVICES_NS\", exiting..."
        echo "****************************************************************************"
        exit 1
    fi
}
# DBACLD-189643: Function to retrieve all existing CSV from a given namespace (input) and save to a file at a given directory (input)
function get_existing_csvs() {
    # Usage: get_existing_csvs <namespace> <output_dir> <sub_name>
    # Reads the installedCSV from the given subscription and saves its YAML to <output_dir>/<csv_name>.yaml
    local namespace="$1"
    local output_dir="$2"
    local sub_name="$3"

    if [[ -z "$namespace" || -z "$output_dir" || -z "$sub_name" ]]; then
        warning "Namespace, output directory, and subscription name must be provided."
        return 1
    fi

    mkdir -p "$output_dir" >/dev/null 2>&1

    # Extract the installedCSV name from the subscription status, e.g. ibm-ads-operator.v25.1.1
    local csv_name
    csv_name=$(${CLI_CMD} get subscription.operators.coreos.com "$sub_name" -n "$namespace" \
        --no-headers --ignore-not-found -o 'jsonpath={.status.installedCSV}') >&3 2>&3
    if [[ -z "$csv_name" ]]; then
        warning "No installedCSV found for subscription \"$sub_name\" in namespace \"$namespace\", skipping."
        return 0
    fi

    local output_file="${output_dir}/${csv_name}.yaml"
    # If the file already exists, rename it with a timestamp suffix before writing a new one
    if [[ -e "$output_file" ]]; then
        local ts
        ts=$(date +'%Y%m%d%H%M%S')
        mv "$output_file" "${output_file%.yaml}_${ts}.yaml_bak"
        info "Existing backup renamed to \"${output_file%.yaml}_${ts}.yaml_bak\""
    fi
    ${CLI_CMD} get csv "$csv_name" -n "$namespace" --ignore-not-found -o yaml > "$output_file" 2>&3
    if [[ $? -eq 0 && -s "$output_file" ]]; then
        info "Backed up CSV \"$csv_name\" to \"$output_file\""
    else
        warning "Failed to back up CSV \"$csv_name\" from namespace \"$namespace\"."
    fi
    return 0
}



#############################################################
##### Functions to install IBM Usage Metering Operator ######
#############################################################


# Function to apply Subscription for the UMS Operator
# https://jsw.ibm.com/browse/DBACLD-216413
# https://jsw.ibm.com/browse/DBACLD-225399
function apply_subscription() {
    local namespace="$1"
    local channel="$2"
    local catalog_name="$3"
    local catalog_namespace="$4"
    UMS_OLM_SUBSCRIPTION_TMP=${TEMP_FOLDER}/.ums_subscription.yaml

    info "Creating IBM Usage Metering Subscription in namespace: $namespace"

    if [ ! -f "$UMS_OLM_SUBSCRIPTION" ]; then
        TMP_MESSAGE="IBM Usage Metering Installation failed as the IBM Usage Metering Installation Operator Subscription creation failed"
        displayClusterAdminMessage "$TMP_MESSAGE" "$CP4BA_RELEASE_BASE-$CP4BA_PATCH_VERSION"
        exit 1
    fi
    
    # Copy template to temp file
    cp "$UMS_OLM_SUBSCRIPTION" "$UMS_OLM_SUBSCRIPTION_TMP"
    
    # Replace REPLACE_NAMESPACE with actual namespace using yq
    ${YQ_CMD} eval '(.. | select(. == "REPLACE_NAMESPACE")) = "'"$namespace"'"' -i "$UMS_OLM_SUBSCRIPTION_TMP"
    
    # Replace REPLACE_CHANNEL with actual channel using yq
    ${YQ_CMD} eval '(.. | select(. == "REPLACE_CHANNEL")) = "'"$channel"'"' -i "$UMS_OLM_SUBSCRIPTION_TMP"
    
    # Set sourceNamespace
    ${YQ_CMD} eval ".spec.sourceNamespace = \"$catalog_namespace\"" -i "$UMS_OLM_SUBSCRIPTION_TMP"
    
    # Set source (catalog name)
    ${YQ_CMD} eval ".spec.source = \"$catalog_name\"" -i "$UMS_OLM_SUBSCRIPTION_TMP"

    ${CLI_CMD} apply -f ${UMS_OLM_SUBSCRIPTION_TMP}
    if [ $? -eq 0 ]
        then
        success "UMS Operator Subscription Created!"
    else
        TMP_MESSAGE="IBM Usage Metering Installation failed as the IBM Usage Metering Installation Operator Subscription creation failed"
        displayClusterAdminMessage "$TMP_MESSAGE" "$CP4BA_RELEASE_BASE-$CP4BA_PATCH_VERSION"
        exit 1
    fi
}


# Function to create the ibm usage metering connection point secret
# It uses the Entitlement key to generate a secret named cp4ba-ums-secret/cp4ba-ils-secret based on the function calling it.
# In the future the entitlement key secret already created would be used
# https://jsw.ibm.com/browse/DBACLD-216413
# https://jsw.ibm.com/browse/DBACLD-225399
function create_connection_point_secret(){
    local secret_name=$1
    local services_namespace=$2
    local entitlement_key=$3
    # Use a variable to detect if the connection point creation passed
    connection_point_secret_creation="false"

    if ${CLI_CMD} get secret "$secret_name" -n "${services_namespace}" >/dev/null 2>&1; then
        success "Secret $secret_name already exists in namespace $services_namespace, skipping recreation."
        connection_point_secret_creation="true"
        return 0
    fi
    
    info "Creating the $secret_name secret using the Entitlement key which will be used for configuring the connection point in the project $services_namespace..."
    echo
    
    if ${CLI_CMD} create secret generic "$secret_name" \
        --from-literal="token=$entitlement_key" \
        -n "$services_namespace"; then
        success "Secret $secret_name has been successfully created"
        connection_point_secret_creation="true"
    else
        fail "Failed to create the secret $secret_name."
    fi
        
}

# Function to process and apply IBMServiceMeterDefinition YAMLs
# Parameters:
#   $1 - namespace
#   $2 - file location (directory containing YAML files)
# https://jsw.ibm.com/browse/DBACLD-216413
function apply_service_meter_definitions() {
    local namespace="$1"
    local file_location="$2"
    
    
    if [[ -z "$file_location" ]]; then
        error "File location parameter is required"
        return 1
    fi
    
    if [[ ! -d "$file_location" ]]; then
        error "Directory '$file_location' does not exist"
        return 1
    fi
    
    info "Processing IBMServiceMeterDefinition YAMLs in: $file_location"
    info "Target namespace for the YAMLs to be applied in: $namespace"
    
    # Process each YAML file in the directory
    for yaml_file in "$file_location"/*.yaml "$file_location"/*.yml; do
        # Skip if no files match
        [[ -e "$yaml_file" ]] || continue
        
        local filename=$(basename "$yaml_file")
        
        # Check if the file is of kind IBMServiceMeterDefinition
        local kind=$(${YQ_CMD} eval '.kind' "$yaml_file" 2>/dev/null)
        
        if [[ "$kind" != "IBMServiceMeterDefinition" ]]; then
            #echo "Skipping $filename - not an IBMServiceMeterDefinition (kind: $kind)"
            continue
        fi
        
        # Create a temporary file for modifications
        local temp_file="${TEMP_FOLDER}/${filename}"
        cp "$yaml_file" "$temp_file"
        
        # Update namespace
        ${YQ_CMD} eval ".metadata.namespace = \"$namespace\"" -i "$temp_file"
        
        # If flag is set, rename componentId to productId and componentName to productName
        # This is a temporary block that will be removed once UMS pushes a fix in their next release
        #if [[ "$RENAME_COMPONENT_FIELDS" == "true" ]]; then
        #    
        #    # Check if componentId exists directly under data and rename to productId
        #    local component_id=$(${YQ_CMD} eval ".spec.data.componentId" "$temp_file" 2>/dev/null)
        #    if [[ "$component_id" != "null" && -n "$component_id" ]]; then
        #        ${YQ_CMD} eval ".spec.data.productId = .spec.data.componentId | del(.spec.data.componentId)" -i "$temp_file"
        #    fi

            # Check if componentName exists directly under data and rename to productName
        #    local component_name=$(${YQ_CMD} eval ".spec.data.componentName" "$temp_file" 2>/dev/null)
        #    if [[ "$component_name" != "null" && -n "$component_name" ]]; then
        #        ${YQ_CMD} eval ".spec.data.productName = .spec.data.componentName | del(.spec.data.componentName)" -i "$temp_file"
        #    fi
            
            # Process sources array - rename componentId and componentName in each source
        #    local sources_count=$(${YQ_CMD} eval '.spec.sources | length' "$temp_file" 2>/dev/null)
        #    if [[ "$sources_count" != "null" && "$sources_count" != "0" ]]; then
        #        # Rename all componentId to productId in sources array
        #        ${YQ_CMD} eval '(.spec.sources[] | select(has("componentId"))) |= (.productId = .componentId | del(.componentId))' -i "$temp_file"
                
                # Rename all componentName to productName in sources array
        #        ${YQ_CMD} eval '(.spec.sources[] | select(has("componentName"))) |= (.productName = .componentName | del(.componentName))' -i "$temp_file"
        #        
        #    fi
            
        #fi
        
        # Apply the modified YAML
        info "  - Applying $filename to namespace $namespace"
        if ${CLI_CMD} apply -f "$temp_file" -n "$namespace"; then
            success "Successfully applied $filename"
        else
            error "Failed to apply $filename"
        fi
        
        # Clean up temp file
        rm -f "$temp_file"
        echo ""
    done
    
    success "All IBMServiceMeterDefinition Static CRs for the Usage Metering Service have been applied."
    echo
}


# Function to process and apply IBMUsageMetering YAMLs. As of right now there is only 1 yaml to be applied but function can handle multiple
# Parameters:
#   $1 - namespace (replaces REPLACE_NAMESPACE)
#   $2 - secret name (replaces REPLACE_SECRET_NAME)
#   $3 - file location (directory containing YAML files)
#   $4 - mode parameter which will tell us if the user is deploying with the dev mode. If the user did not use the dev flag, this parameter will be empty and if not the sanbox:true will be patched into the UsageMetering CR.
# https://jsw.ibm.com/browse/DBACLD-216413
# https://jsw.ibm.com/browse/DBACLD-225399
function apply_usage_metering_definition () {
    local namespace="$1"
    local secret_name="$2"
    local file_location="$3"
    local mode="$4"
    local airgap_mode="$5"
    
    
    if [[ -z "$file_location" ]]; then
        error "File location parameter is required"
        return 1
    fi
    
    if [[ ! -d "$file_location" ]]; then
        error "Directory '$file_location' does not exist"
        return 1
    fi

    if [[ "$mode" == "dev" ]]; then
        info "Usage Metering mode is dev, setting sandbox=true"
    fi
    
    # Create temp folder if it doesn't exist
    mkdir -p "$TEMP_FOLDER"
    
    info "Processing IBMUsageMetering YAMLs in: $file_location"
    info "Target namespace: $namespace"
    
    # Process each YAML file in the directory
    for yaml_file in "$file_location"/*.yaml "$file_location"/*.yml; do
        # Skip if no files match
        [[ -e "$yaml_file" ]] || continue
        
        local filename=$(basename "$yaml_file")
        
        # Check if the file is of kind IBMUsageMetering
        local kind=$(${YQ_CMD} eval '.kind' "$yaml_file" 2>/dev/null)
        
        if [[ "$kind" != "IBMUsageMetering" ]]; then
            echo "Skipping $filename - not an IBMUsageMetering (kind: $kind)"
            continue
        fi
        
        
        # Create a temporary file for modifications
        local temp_file="${TEMP_FOLDER}/${filename}"
        cp "$yaml_file" "$temp_file"
        
        # Check and replace namespace if it contains REPLACE_NAMESPACE
        local current_namespace=$(${YQ_CMD} eval '.metadata.namespace' "$temp_file" 2>/dev/null)
        if [[ "$current_namespace" == "REPLACE_NAMESPACE" ]]; then
            ${YQ_CMD} eval ".metadata.namespace = \"$namespace\"" -i "$temp_file"
        fi
        
        if [[ "$airgap_mode" == "true" || "$airgap_mode" == "yes" || "$airgap_mode" == "Yes" ]]; then
            #info "Airgap mode detected, removing .spec.sender.softwareCentral from $filename"
            ${YQ_CMD} eval 'del(.spec.sender.softwareCentral)' -i "$temp_file"
        else
            # Check and replace secret name if it contains REPLACE_SECRET_NAME
            local current_secret=$(${YQ_CMD} eval '.spec.sender.softwareCentral.entitlementKeySecret' "$temp_file" 2>/dev/null)
            if [[ "$current_secret" == "REPLACE_SECRET_NAME" ]]; then
                ${YQ_CMD} eval ".spec.sender.softwareCentral.entitlementKeySecret = \"$secret_name\"" -i "$temp_file"
            fi

            # If mode is dev, set sandbox to true
            # https://jsw.ibm.com/browse/DBACLD-225399
            if [[ "$mode" == "dev" ]]; then
                ${YQ_CMD} eval '.spec.sender.softwareCentral.sandbox = true' -i "$temp_file"
            fi
        fi
        
        # Apply the modified YAML
        info "  - Applying $filename to namespace $namespace"
        if ${CLI_CMD} apply -f "$temp_file" -n "$namespace"; then
            success "Successfully applied $filename"
        else
            error "Failed to apply $filename"
        fi
        
        # Clean up temp file
        rm -f "$temp_file"
        echo ""
    done
    
    success "All IBM Usage Metering Static CRs for the Usage Metering Service have been applied."
    echo
}

# Function to patch UMS subscription with new channel
function patch_ums_subscription() {
    local operator_namespace=$1
    local channel=$2
    local catalog_namespace=$3
    
    # Find subscription with "ibm-usage-metering" in the name
    local subscription_name=$(${CLI_CMD} get subscription -n "$operator_namespace" --no-headers 2>/dev/null | grep "ibm-usage-metering" | awk '{print $1}' | head -n 1)
    
    if [ -z "$subscription_name" ]; then
        error "No subscription containing 'ibm-usage-metering' found in namespace '$operator_namespace'"
        return 1
    fi
    
    info "Found subscription: '$subscription_name'"
    info "Patching subscription with channel '$channel'..."
    ${CLI_CMD} patch subscription "$subscription_name" -n "$operator_namespace" \
        --type='json' \
        -p="[{'op': 'replace', 'path': '/spec/channel', 'value': '$channel'}]"
    
    if [ $? -eq 0 ]; then
        success "Subscription '$subscription_name' patched successfully with channel '$channel'"
        return 0
    else
        error "Failed to patch subscription '$subscription_name'"
        return 1
    fi
    
    info "Patching subscription with sourcenamespace '$catalog_namespace'..."
    ${CLI_CMD} patch subscription "$subscription_name" -n "$operator_namespace" \
        --type='json' \
        -p="[{'op': 'replace', 'path': '/spec/sourceNamespace', 'value': '$catalog_namespace'}]"
    
    if [ $? -eq 0 ]; then
        success "Subscription '$subscription_name' patched successfully with sourcenamespace '$catalog_namespace'"
        return 0
    else
        error "Failed to patch subscription '$subscription_name'"
        return 1
    fi      
}

# Function to extract entitlement key password from a dockerconfigjson secret.
#
# Lookup order:
#   1. Secret passed in as $1 in the namespace passed in as $2
#   2. pull-secret in openshift-config namespace
#
# Registry lookup order inside the dockerconfigjson:
#   1. cp.icr.io
#   2. cp.stg.icr.io
#
# The function reads the registry "auth" field, decodes it from base64,
# and extracts the password/token portion from the "username:password" value.
#
# Arguments:
#   $1 - secret name to check first, typically ibm-entitlement-key
#   $2 - namespace where the secret should exist
#
# Output:
#   Sets global variable: entitlement_key
#
# Return:
#   0 on success
#   1 if the entitlement key could not be extracted
function get_entitlement_key_from_secret() {
    local secret_name="$1"
    local namespace="$2"
    local dockerconfigjson=""
    local auth_value=""
    local decoded_auth=""
    local source_secret_name=""
    local source_namespace=""

    info "Extracting entitlement key from secret '$secret_name' in namespace '$namespace'..."

    # Step 1: Check whether the requested secret exists in the provided namespace.
    # If it exists, use it as the primary source.
    if ${CLI_CMD} get secret "$secret_name" -n "$namespace" &>/dev/null; then
        source_secret_name="$secret_name"
        source_namespace="$namespace"
        info "Found secret '$source_secret_name' in namespace '$source_namespace'"
    else
        warning "Secret '$secret_name' not found in namespace '$namespace'. Checking 'pull-secret' in namespace 'openshift-config'..."

        # Step 2: If the original secret is not present, fall back to the cluster pull-secret.
        if ${CLI_CMD} get secret pull-secret -n openshift-config &>/dev/null; then
            source_secret_name="pull-secret"
            source_namespace="openshift-config"
            info "Found fallback secret '$source_secret_name' in namespace '$source_namespace'"
        else
            error "Neither secret '$secret_name' in namespace '$namespace' nor secret 'pull-secret' in namespace 'openshift-config' was found. Failed to extract the entitlement-key from the cluster."
            return 1
        fi
    fi

    # Step 3: Extract and decode the dockerconfigjson payload from the selected secret.
    dockerconfigjson=$(${CLI_CMD} get secret "$source_secret_name" -n "$source_namespace" -o yaml | \
        ${YQ_CMD} eval '.data[".dockerconfigjson"]' - | \
        ${BASE64_DECODE})

    if [[ -z "$dockerconfigjson" ]] || [[ "$dockerconfigjson" == "null" ]]; then
        error "Failed to extract the entitlement-key from secret '$source_secret_name' in namespace '$source_namespace'."
        return 1
    fi

    # Step 4: Try cp.icr.io first by reading the auth field.
    auth_value=$(printf '%s' "$dockerconfigjson" | ${YQ_CMD} eval '.auths."cp.icr.io".auth' -)

    # Step 5: If cp.icr.io is not present, try cp.stg.icr.io.
    if [[ -z "$auth_value" ]] || [[ "$auth_value" == "null" ]]; then
        auth_value=$(printf '%s' "$dockerconfigjson" | ${YQ_CMD} eval '.auths."cp.stg.icr.io".auth' -)
    fi

    # Step 6: If both registry auth entries are missing, handle it the same as empty password.
    if [[ -z "$auth_value" ]] || [[ "$auth_value" == "null" ]]; then
        error "Failed to extract password from dockerconfigjson (tried cp.icr.io and cp.stg.icr.io)"
        return 1
    fi

    # Step 7: Decode the auth entry. It should be in the form username:password
    decoded_auth=$(printf '%s' "$auth_value" | ${BASE64_DECODE})

    if [[ -z "$decoded_auth" ]] || [[ "$decoded_auth" == "null" ]]; then
        error "Failed to decode auth field from dockerconfigjson"
        return 1
    fi

    # Step 8: Extract the password/token portion after the first colon.
    entitlement_key=$(printf '%s' "$decoded_auth" | sed 's/^[^:]*://')

    # Step 9: If the extracted password is empty, handle it as failure.
    if [[ -z "$entitlement_key" ]] || [[ "$entitlement_key" == "$decoded_auth" ]]; then
        error "Failed to extract password from decoded auth field"
        return 1
    fi

    return 0
}


# Main installation function for UMS for either fresh install or upgrade
# based on argument 3 the function is able to perform the required steps for either of those scenarios
# $1 Operator namespace
# $2 Services namespace
# $3 scenario i.e fresh_install or upgrade
# $4 entitlement_key which is the key used to generate the connection point secret
# $5 runtime mode that tells the script if it is being used in dev mode and if so the sandbox setting is enabled
# $6 catalog namespace incase the user is going to deploy 26.0.0 GA with global catalog
# $7 airgap mode which makes sure that the connection point CR is created without the softwareCentral section
# https://jsw.ibm.com/browse/DBACLD-216413
function install_ibm_usage_metering() {
    local operator_namespace=$1
    local services_namespace=$2
    local scenario=$3
    local entitlement_key=$4
    local runtime_mode=$5
    local catalog_namespace=$6
    local airgap_mode=$7
    local create_secret_and_resources="true"
    echo ""
    echo "=========================================="
    echo "IBM Usage Metering Operator Installation"
    echo "=========================================="
    echo ""

    # Step 1: Check if CatalogSource exists
    if ! ${CLI_CMD} get catalogsource "$UMS_CATALOG_VERSION" -n "$catalog_namespace" &>/dev/null; then
        error "CatalogSource '$UMS_CATALOG_VERSION' not found in namespace '$catalog_namespace'"
        echo ""
        return 1
    fi

    # Wait for CatalogSource to be ready
    echo "Waiting for IBM Usage Metering Catalog Source to be ready..."
    local timeout=300
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local state=$(${CLI_CMD} get catalogsource "$UMS_CATALOG_VERSION" -n "$catalog_namespace" -o jsonpath='{.status.connectionState.lastObservedState}' 2>/dev/null)
        if [ "$state" = "READY" ]; then
            info "IBM Usage Metering Catalog Source is ready."
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done

    if [ $elapsed -ge $timeout ]; then
        TMP_MESSAGE="IBM Usage Metering Installation failed due to Catalog source not being ready"
        if [[ "$scenario" == "upgrade" ]]; then
            displayUpgradeOperatorMessage "$TMP_MESSAGE" $services_namespace $cp4a_operator_csv_version
        else
            displayClusterAdminMessage "$TMP_MESSAGE" "$CP4BA_RELEASE_BASE-$CP4BA_PATCH_VERSION"
        fi
        exit 1
    fi
    echo ""


    # Step 2: Handle Subscription based on scenario
    if [[ "$scenario" == "fresh_install" ]]; then
        
        info "Creating the IBM Usage Metering Subscription..."
        apply_subscription "$operator_namespace" "$UMS_CHANNEL_VERSION" "$UMS_CATALOG_VERSION" "$catalog_namespace"
        echo ""
    # For upgrade scenario we might have to apply a new subscription or patch it based on the version the user is already on.
    elif [[ "$scenario" == "upgrade" ]]; then
        info "Checking for existing IBM Usage Metering Subscription..."
        
        # Check if any subscription with "ibm-usage-metering" exists
        local subscription_exists=$(${CLI_CMD} get subscription -n "$operator_namespace" --no-headers 2>/dev/null | grep "ibm-usage-metering" | wc -l)
        
        if [ "$subscription_exists" -gt 0 ]; then
            patch_ums_subscription "$operator_namespace" "$UMS_CHANNEL_VERSION" "$catalog_namespace"
            if [ $? -ne 0 ]; then
                TMP_MESSAGE="IBM Usage Metering Installation failed as patching the IBM Usage Metering Installation Operator Subscription failed."
                displayUpgradeOperatorMessage "$TMP_MESSAGE" $services_namespace $cp4a_operator_csv_version
                exit 1
            fi
        else
            info "No IBM Usage Metering subscription found. Creating new subscription..."
            
            apply_subscription "$operator_namespace" "$UMS_CHANNEL_VERSION" "$UMS_CATALOG_VERSION" "$catalog_namespace"
        fi
        echo ""
    fi

    # Step 3: Wait for UMS operator to be ready
    echo "Waiting for the IBM Usage Metering operator to be ready and in running state"
    timeout=600
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if ${CLI_CMD} get csv -n "$operator_namespace" 2>/dev/null | grep -q "ibm-usage-metering.*Succeeded"; then
            success "IBM Usage Metering operator is ready"
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        echo "  Waiting... (${elapsed}s/${timeout}s)"
    done

    if [ $elapsed -ge $timeout ]; then
        TMP_MESSAGE="IBM Usage Metering Installation failed as IBM Usage Metering operator did not become ready in time."
        if [[ "$scenario" == "upgrade" ]]; then
            displayUpgradeOperatorMessage "$TMP_MESSAGE" $services_namespace $cp4a_operator_csv_version
        else
            displayClusterAdminMessage "$TMP_MESSAGE" "$CP4BA_RELEASE_BASE-$CP4BA_PATCH_VERSION"
        fi
        exit 1
    fi
    echo ""

    # This block makes sure the UMS operator pod is running
    timeout=300
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if ${CLI_CMD} get pods -n "$operator_namespace" -l app.kubernetes.io/name=ibm-usage-metering-operator --field-selector=status.phase=Running 2>/dev/null | grep -q Running; then
            info "IBM Usage Metering operator pod is running"
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done

    if [ $elapsed -ge $timeout ]; then
        warning "Operator pod not running yet, but continuing..."
    fi
    echo ""

    # This is the flag that helps modify the static CRs to apply. Right now this flag is needed but once UMS pushes a fix it can be removed
    #RENAME_COMPONENT_FIELDS="true"
    
    # Step 4: Applying the service metering definition static CRs from the descriptors folder
    apply_service_meter_definitions "$services_namespace" "$UMS_STATIC_CR_LOCATION"
    
    # Step 5 which is to create the the connection point secret and connection point CR
    # Step 5(a) For airgap deployments, do not create the UMS secret and apply the UsageMetering CR without the softwareCentral section.
    # Step 5(b) For non-airgap deployments, create the secret only when needed and only apply the CR if the secret exists or was created successfully.
    if [[ "$airgap_mode" == "true" || "$airgap_mode" == "yes" || "$airgap_mode" == "Yes" ]]; then
        info "Airgap mode detected. Skipping creation of secret '$UMS_CONNECTION_POINT_SECRET_NAME' and applying UsageMetering CR."
        apply_usage_metering_definition "$services_namespace" "$UMS_CONNECTION_POINT_SECRET_NAME" "$UMS_CONNECTION_POINT_STATIC_CR_LOCATION" "$runtime_mode" "$airgap_mode"
    else
        if ${CLI_CMD} get secret "$UMS_CONNECTION_POINT_SECRET_NAME" -n "$services_namespace" >/dev/null 2>&1; then
            success "UMS connection point secret '$UMS_CONNECTION_POINT_SECRET_NAME' already exists in namespace '$services_namespace', skipping the creation of the secret."
            create_secret_and_resources="true"
            connection_point_secret_creation="true"
        else
            info "UMS connection point secret '$UMS_CONNECTION_POINT_SECRET_NAME' not found in namespace '$services_namespace', the script will now proceed to creating it using the entitlement key."

            # For upgrade non-airgap, if the entitlement key was not passed in, retrieve it from an existing secret.
            if [[ -z "$entitlement_key" && "$scenario" == "upgrade" ]]; then
                get_entitlement_key_from_secret "ibm-entitlement-key" "$services_namespace"
                if [ $? -ne 0 ]; then
                    warning "Failed to extract entitlement key from secret.Refer to https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE for more information on how to create the $UMS_CONNECTION_POINT_SECRET_NAME secret and the UsageMetering connection point custom resource file."
                    create_secret_and_resources="false"
                fi
            fi

            # For fresh install non-airgap, entitlement key is expected to be passed in. If not present, do not create the secret or CR.
            if [[ -z "$entitlement_key" ]]; then
                warning "[IMPORTANT]The IBM Entitlement key is not available, so the $UMS_CONNECTION_POINT_SECRET_NAME secret and the UsageMetering connection point Custom Resource file will not be created.Refer to https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE for more information on how to create the $UMS_CONNECTION_POINT_SECRET_NAME secret and the UsageMetering connection point Custom Resource file."
                create_secret_and_resources="false"
            fi
        fi

        # Step 6: Creating the connection point secret and UsageMetering CR only if we were able to retrieve or were passed the entitlement key
        if [[ "$create_secret_and_resources" == "true" ]]; then
            create_connection_point_secret "$UMS_CONNECTION_POINT_SECRET_NAME" "$services_namespace" "$entitlement_key"
            if [[ "$connection_point_secret_creation" == "true" ]]; then
                apply_usage_metering_definition "$services_namespace" "$UMS_CONNECTION_POINT_SECRET_NAME" "$UMS_CONNECTION_POINT_STATIC_CR_LOCATION" "$runtime_mode" "$airgap_mode"
            else
                warning "[IMPORTANT]Since the $UMS_CONNECTION_POINT_SECRET_NAME could not be created, the UsageMetering connection point Custom Resource file will not be created.Refer to https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE for more information on how to create the $UMS_CONNECTION_POINT_SECRET_NAME secret and the UsageMetering connection point Custom Resource file."
            fi
        fi
    fi

    echo "================================================="
    echo "Usage Metering Operator Installation Complete!"
    echo "================================================="
    echo ""
    
}


# Patch an existing IBMLicensing resource to configure Software Central uploads.
# Arguments:
#   $1 - secret name to set in spec.sender.softwareCentral.entitlementKeySecret
#   $2 - IBMLicensing resource name
#   $3 - runtime mode; if "dev", sandbox=true is added
function patch_ils_instance() {
    local secret_name="$1"
    local licensing_name="$2"
    local mode="$3"
    local patch_payload=""

    # Build the default merge patch payload
    patch_payload=$(cat <<EOF
{
  "spec": {
      "softwareCentral": {
        "enable": true,
        "frequency": "5 0 * * *",
        "entitlementKeySecret": "$secret_name"
      }
    }
}
EOF
)

    # Add sandbox only in dev mode
    if [[ "$mode" == "dev" ]]; then
        info "Runtime mode is dev, setting spec.softwareCentral.sandbox=true"
        patch_payload=$(cat <<EOF
{
  "spec": {
      "softwareCentral": {
        "enable": true,
        "frequency": "5 0 * * *",
        "entitlementKeySecret": "$secret_name",
        "sandbox": true
      }
  }
}
EOF
)
    fi

    # Patch the IBMLicensing custom resource
    info "Patching IBMLicensing resource \"$licensing_name\""
    if ${CLI_CMD} patch IBMLicensing "$licensing_name" --type=merge -p "$patch_payload"; then
        success "Successfully patched IBMLicensing resource \"$licensing_name\""
        return 0
    else
        error "Failed to patch IBMLicensing resource \"$licensing_name\""
        return 1
    fi
}


# Configure Software Central integration for an existing IBMLicensing resource.
#
# Flow:
#   1. Check whether an IBMLicensing resource exists.
#   2. If no IBMLicensing resource exists, skip the configuration.
#   3. Check whether the ILS connection point secret already exists.
#   4. If the secret does not exist:
#      - use the provided entitlement key if available
#      - otherwise, for upgrade scenario only, try to retrieve it from ibm-entitlement-key
#      - if no entitlement key can be obtained, skip secret creation and CR patching
#      - if entitlement key is available, create the secret
#   5. Patch the IBMLicensing resource to enable Software Central uploads.
#   6. In dev mode, also set sandbox=true.
#
# Arguments:
#   $1 - namespace where the ILS connection point secret should exist
#   $2 - services namespace where ibm-entitlement-key may exist
#   $3 - entitlement key value; may be empty during upgrade
#   $4 - scenario value such as "upgrade" or "fresh_install"
#   $5 - runtime mode such as "dev" or "prod"
function setup_ils_configuration_for_vpc_metrics() {
    local licensing_namespace="$1"
    local services_namespace="$2"
    local entitlement_key="$3"
    local scenario="$4"
    local mode="$5"
    local licensing_name=""
    local mode_lower=""
    local create_secret_and_resources="true"

    # Normalize runtime mode to lowercase for comparison
    mode_lower=$(echo "$mode" | tr '[:upper:]' '[:lower:]')

    # Step 1: Check whether an IBMLicensing resource exists
    info "Checking for IBMLicensing resource..."
    licensing_name=$(${CLI_CMD} get IBMLicensing --no-headers --ignore-not-found 2>/dev/null | awk 'NR==1{print $1}')

    if [[ -z "$licensing_name" ]]; then
        warning "No IBMLicensing resource found. Skipping ILS Software Central configuration."
        return 0
    fi

    success "Found IBMLicensing resource: $licensing_name"

    # Step 2: Check whether the ILS connection point secret already exists
    if ${CLI_CMD} get secret "$ILS_CONNECTION_POINT_SECRET_NAME" -n "$licensing_namespace" >/dev/null 2>&1; then
        success "ILS connection point secret '$ILS_CONNECTION_POINT_SECRET_NAME' already exists in namespace '$licensing_namespace'."

        # Step 3: Patch the IBMLicensing resource even if the secret already exists
        patch_ils_instance "$ILS_CONNECTION_POINT_SECRET_NAME" "$licensing_name" "$mode_lower"
        return $?
    fi

    info "ILS connection point secret '$ILS_CONNECTION_POINT_SECRET_NAME' not found in namespace '$licensing_namespace'. The script will attempt to create it."

    # Step 4: If no entitlement key was passed and this is an upgrade, try retrieving it
    if [[ -z "$entitlement_key" && "$scenario" == "upgrade" ]]; then
        info "Entitlement key was not passed in upgrade scenario. Attempting to retrieve it from secret \"ibm-entitlement-key\" in namespace \"$services_namespace\"."

        get_entitlement_key_from_secret "ibm-entitlement-key" "$services_namespace"
        if [ $? -ne 0 ]; then
            warning "Failed to extract entitlement key from secret. Refer to https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE for more information on how to create the $ILS_CONNECTION_POINT_SECRET_NAME secret and update the IBMLicensing custom resource."
            create_secret_and_resources="false"
        fi
    fi

    # Step 5: If entitlement key is still empty, do not create the secret or patch the CR
    if [[ -z "$entitlement_key" ]]; then
        warning "Entitlement key is empty. Skipping creation of secret '$ILS_CONNECTION_POINT_SECRET_NAME' and the script will skip the patch of IBMLicensing."
        return 0
    fi

    # Step 6: Create the secret only if allowed
    if [[ "$create_secret_and_resources" == "true" ]]; then
        info "Creating ILS connection point secret '$ILS_CONNECTION_POINT_SECRET_NAME' in namespace '$licensing_namespace'"
        create_connection_point_secret "$ILS_CONNECTION_POINT_SECRET_NAME" "$licensing_namespace" "$entitlement_key"

        if [[ "$connection_point_secret_creation" == "true" ]]; then
            # Step 7: Patch the IBMLicensing resource after secret creation
            patch_ils_instance "$ILS_CONNECTION_POINT_SECRET_NAME" "$licensing_name" "$mode_lower"
            return $?
        else
            warning "[IMPORTANT]Since the $ILS_CONNECTION_POINT_SECRET_NAME could not be created, the IBMLicensing instance will not be patched by the script.Refer to https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation/$CP4BA_RELEASE_BASE for more information on how to create the $ILS_CONNECTION_POINT_SECRET_NAME secret and patch the IBMLicensing Instance."
        fi
    fi

    return 0
}

# Function to get the total reconcile count for a CP4BA operator pod.
# Sets the global variable OPERATOR_RECONCILE_COUNT to a numeric value.
# Returns:
#   0 when reconcile artifact count was found and parsed
#   1 when the artifact count could not be found
function get_cp4ba_operator_reconcile_count() {
    local operator_namespace="$1"
    local operator_pod_name="$2"
    local top_level_cr_kind="$3"
    local top_level_cr_name="$4"
    local cr_kind_path=""
    local reconcile_count=""

    OPERATOR_RECONCILE_COUNT=0

    if [[ -z "$operator_namespace" || -z "$operator_pod_name" || -z "$top_level_cr_kind" || -z "$top_level_cr_name" || -z "$CP4BA_SERVICES_NS" ]]; then
        return 1
    fi

    if [[ "$top_level_cr_kind" == "content" ]]; then
        cr_kind_path="Content"
    else
        cr_kind_path="ICP4ACluster"
    fi

    reconcile_count=$(${CLI_CMD} -n "$operator_namespace" exec "$operator_pod_name" -- sh -c "
        ls /tmp/ansible-operator/runner/icp4a.ibm.com/v1/${cr_kind_path}/${CP4BA_SERVICES_NS}/${top_level_cr_name}/artifacts/ 2>/dev/null | grep -c '^[0-9]'
    " 2>/dev/null)

    if [[ $? -eq 0 && "$reconcile_count" =~ ^[0-9]+$ ]]; then
        OPERATOR_RECONCILE_COUNT="$reconcile_count"
        return 0
    fi

    return 1
}


# Function to check if all components are ready
# This function parses the components status variable array defined in upgradeDeploymentStatus and checks for "Done" status
# This is used as a part of upgrade
# Check if all CP4BA components have completed upgrade
# Returns: 0 if all installed components show "Done", 1 otherwise
function check_if_all_components_are_ready() {
    # Check all component status values in the array
    for status_value in "${CP4BA_COMPONENT_STATUS_VALUES[@]}"; do
        
        # Skip if empty or whitespace only
        if [[ -z "$status_value" ]] || [[ "$status_value" =~ ^[[:space:]]*$ ]]; then
            continue
        fi

        # Skip if "Not Installed"
        if [[ "$status_value" =~ "Not Installed" ]]; then
            continue
        fi
        
        # Check for non-ready states
        if [[ "$status_value" =~ "In Progress" ]] || \
           [[ "$status_value" =~ "Not Ready" ]] || \
           [[ "$status_value" =~ "Failed" ]] || \
           [[ "$status_value" =~ "Pending" ]] || \
           [[ "$status_value" =~ "Upgrading" ]]; then
            return 1  # Not ready
        fi
        
        # Must contain "Done" or "Ready"
        if [[ ! "$status_value" =~ "Done" ]] && [[ ! "$status_value" =~ "Ready" ]]; then
            return 1  # Not ready
        fi
    done
    
    return 0  # All components ready
}


# Retrieve CR details
# This function takes 1 argument i.e the services namespace
# This function is defined in the common.sh script and the function find the top level CR kind and name
# Top level CR kind and name are stored in the variables top_level_cr_type and top_level_cr_name
# The function also stores the name of the icp4acluster and content CR names in the variables icp4acluster_cr_name,content_cr_name
function retrieve_custom_resource_details(){
    local cr_namespace=$1
    local icp4acluster_cr_details_location=$2
    local content_cr_details_location=$3
    top_level_cr_kind=""
    top_level_cr_name=""
    top_level_cr_details_location=""
    top_level_cr_details_backup_location=""
    content_cr_name=""
    icp4acluster_cr_name=""
    content_cr_present="false"
    icp4acluster_cr_present="false"

    #Logic that detects what the top level CR is in the deployment
    # If the content CR does not have an owner reference , it is the top level CR otherwise the top level CR is the ICP4ACLuster CR
    ${CLI_CMD} get crd |grep contents.icp4a.ibm.com >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        content_cr_name=$(${CLI_CMD} get content -n $cr_namespace --no-headers --ignore-not-found | awk '{print $1}')
        if [[ ! -z $content_cr_name ]]; then
            owner_ref=$(${CLI_CMD} get content $content_cr_name -n $cr_namespace -o yaml | ${YQ_CMD} '.metadata.ownerReferences.[0].kind' -)
            # Store the Content CR contents in a certain file location
            ${CLI_CMD} get content $content_cr_name -n $cr_namespace -o yaml > ${content_cr_details_location}
            if [[ ${owner_ref} != "ICP4ACluster" ]]; then
                top_level_cr_kind="content"
                top_level_cr_name="$content_cr_name"
                top_level_cr_details_location="${content_cr_details_location}" 
                top_level_cr_details_backup_location="${UPGRADE_DEPLOYMENT_CONTENT_CR_BAK}"              
            fi
        fi
    fi

    if [[ -z "$top_level_cr_kind" ]]; then
        icp4acluster_cr_name=$(${CLI_CMD} get icp4acluster -n $cr_namespace --no-headers --ignore-not-found | awk '{print $1}')
        if [[ ! -z $icp4acluster_cr_name ]]; then
            # Store the Content CR contents in a certain file location
            ${CLI_CMD} get icp4acluster $icp4acluster_cr_name -n $cr_namespace -o yaml > ${icp4acluster_cr_details_location}
            top_level_cr_kind="icp4acluster"
            top_level_cr_name="$icp4acluster_cr_name"
            top_level_cr_details_location="${icp4acluster_cr_details_location}" 
            top_level_cr_details_backup_location="${UPGRADE_DEPLOYMENT_ICP4ACLUSTER_CR_BAK}" 
        fi
    fi

    if [[ -z "$top_level_cr_kind" || -z "$top_level_cr_name" ]]; then
        error "Could not find a IC4ACluster Kind Custom Resource file or a Content Kind Custom Resource file in the $cr_namespace namespace. The script will now exit."
        exit
    fi

    # Retrieve the CR info and store it in a certain file location defined

    # Display Custom Resource Details
    echo ""
    echo "================================================================================"
    echo "${YELLOW_TEXT}Custom Resource Details - Namespace: ${cr_namespace}${RESET_TEXT}"
    echo "================================================================================"
    
    # Display ICP4ACluster CR
    if [[ ! -z "$icp4acluster_cr_name" ]]; then
        echo "ICP4ACluster CR : ${GREEN_TEXT}${icp4acluster_cr_name}${RESET_TEXT}"
    else
        echo "ICP4ACluster CR : Not found"
    fi
    
    # Display Content CR
    if [[ ! -z "$content_cr_name" ]]; then
        echo "Content CR      : ${GREEN_TEXT}${content_cr_name}${RESET_TEXT}"
    else
        echo "Content CR      : Not found"
    fi

    echo ""
    echo "========================================================================================================================"
    echo "Top Level CR Kind   : ${YELLOW_TEXT}${top_level_cr_kind}${RESET_TEXT}"
    echo "Top Level CR Name   : ${GREEN_TEXT}${top_level_cr_name}${RESET_TEXT}"
    echo "Top Level CR Stored at : ${GREEN_TEXT}${top_level_cr_details_location}${RESET_TEXT}"
    echo "========================================================================================================================"
    echo ""
}

#create a YAML file for the ibm-cp4ba-shared-info ConfigMap
#used to store shared information related to the CP4BA deployment, such as operator versions and last reconciliation details
# Function is called in populate_shared_info_configmap based on the top level CR kind
function create_ibm_cp4ba_shared_info_cm_yaml(){
    mkdir -p ${UPGRADE_DEPLOYMENT_CR}
cat << EOF > ${UPGRADE_ICP4A_SHARED_INFO_CM_FILE}
kind: ConfigMap
apiVersion: v1
metadata:
  name: ibm-cp4ba-shared-info
  namespace: <cp4a_namespace>
  labels:
    app.kubernetes.io/managed-by: Operator
    app.kubernetes.io/name: ibm-cp4ba-shared-info
    app.kubernetes.io/version: <cr_version>
    release: <cr_version>
  ownerReferences:
    - apiVersion: icp4a.ibm.com/v1
      kind: ICP4ACluster
      name: <cr_metaname>
      uid: <cr_uid>
data:
  ads_operator_of_last_reconcile: <csv_version>
  cp4ba_operator_of_last_reconcile: <csv_version>
  odm_operator_of_last_reconcile: <csv_version>
  baw_operator_of_last_reconcile: <csv_version>
EOF
}

#create a YAML file for the ibm-cp4ba-shared-info ConfigMap
#used to store shared information related to the CP4BA deployment, such as operator versions and last reconciliation details
# Function is called in populate_shared_info_configmap based on the top level CR kind
function create_ibm_cp4ba_content_shared_info_cm_yaml(){
    mkdir -p ${UPGRADE_DEPLOYMENT_CR}
cat << EOF > ${UPGRADE_ICP4A_CONTENT_SHARED_INFO_CM_FILE}
kind: ConfigMap
apiVersion: v1
metadata:
  name: ibm-cp4ba-content-shared-info
  namespace: <content_namespace>
  labels:
    app.kubernetes.io/managed-by: Operator
    app.kubernetes.io/name: ibm-cp4ba-shared-info
    app.kubernetes.io/version: <cr_version>
    release: <cr_version>
  ownerReferences:
    - apiVersion: icp4a.ibm.com/v1
      kind: Content
      name: <cr_metaname>
      uid: <cr_uid>
data:
  content_operator_of_last_reconcile: <csv_version>
EOF
}

# This is a common function that can create the shared info configmap or patch it with required values.
# The function replaces code that was essentially repeating with the only differences being the name of the configmap based on the top level CR
# The function takes in 4 parameters
# 1. The name of the configmap
# 2. The current details of that configmap
# 3. The namespace to check for the configmap
# 4. The temporary file location that is used to as a template yaml to create the configmap if it is not present
# 5. The top level CR kind
# Variables like $cr_metaname, $cr_uid , $cp4a_operator_csv_version , $cr_version are already set at this point in time
function populate_shared_info_configmap(){
    local configmap_name=$1
    local current_shared_info_configmap_details=$2
    local namespace=$3
    local temp_configmap_details_location=$4
    local cr_kind=$5
    if [[ -z $current_shared_info_configmap_details ]]; then
        info "$configmap_name configMap could not be found,the script will now create it."
        if [[ "$cr_kind" == "icp4acluster" ]]; then
            create_ibm_cp4ba_shared_info_cm_yaml
        elif [[ "$cr_kind" == "content" ]]; then
            create_ibm_cp4ba_content_shared_info_cm_yaml
        else
            fail "No top level CP4BA custom resource found on this cluster in the project \"$namespace\"."
            exit 1
        fi
        ${SED_COMMAND} "s|<cp4a_namespace>|$namespace|g" ${temp_configmap_details_location}
        ${SED_COMMAND} "s|<cr_metaname>|$cr_metaname|g" ${temp_configmap_details_location}
        ${SED_COMMAND} "s|<cr_uid>|$cr_uid|g" ${temp_configmap_details_location}
        ${SED_COMMAND} "s|<csv_version>|$cp4a_operator_csv_version|g" ${temp_configmap_details_location}
        ${SED_COMMAND} "s|<cr_version>|$cr_version|g" ${temp_configmap_details_location}

        ${CLI_CMD} apply -f $temp_configmap_details_location  >&3 2>&3
        if [ $? -eq 0 ]; then
            success "$configmap_name configMap has been created in the project \"$namespace\"!"
            ${CLI_CMD} patch configmap $configmap_name -n $namespace --type=json -p="[{'op': 'add', 'path': '/data/cp4ba_original_csv_ver_for_upgrade_script', 'value': '$(echo "$cp4a_operator_csv_version")'}]" >&3 2>&3
            ${CLI_CMD} patch configmap $configmap_name -n $namespace --type=json -p="[{'op': 'add', 'path': '/data/cpfs_original_csv_ver_for_upgrade_script', 'value': '$(echo "$cpfs_operator_csv_version")'}]" >&3 2>&3
            cp4ba_original_csv_ver_for_upgrade_script=$cp4a_operator_csv_version
        else
            fail "Failed to create $configmap_name configMap in the project \"$namespace\"!"
        fi
    else
        success "$configmap_name configMap was found in namespace \"$namespace\"!"
        ${CLI_CMD} patch configmap $configmap_name -n $namespace --type=json -p="[{'op': 'add', 'path': '/data/cp4ba_original_csv_ver_for_upgrade_script', 'value': '$(echo "$cp4a_operator_csv_version")'}]" >&3 2>&3
        ${CLI_CMD} patch configmap $configmap_name -n $namespace --type=json -p="[{'op': 'add', 'path': '/data/cpfs_original_csv_ver_for_upgrade_script', 'value': '$(echo "$cpfs_operator_csv_version")'}]" >&3 2>&3
        cp4ba_original_csv_ver_for_upgrade_script=$cp4a_operator_csv_version
    fi
}


# Function to extract and set BAI recovery path for a component
# Parameters: $1 = component name (e.g., "event-forwarder", "content", "icm", etc.)
function set_bai_recovery_path() {
    local component_name="$1"
    local search_pattern="bai-${component_name}"
    local tmp_recovery_path=""
    
    # Extract recovery path based on platform
    if [[ "$machine" == "Mac" ]]; then
        tmp_recovery_path=$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json | jq '.[].location' | grep "$search_pattern")
    else
        tmp_recovery_path=$(grep -Po '"location":.*?[^\\]"' ${UPGRADE_DEPLOYMENT_CR}/bai.json | grep "$search_pattern" | cut -d':' -f2)
    fi
    
    # Clean up quotes
    tmp_recovery_path=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_recovery_path")
    
    # Set recovery path if found
    if [ ! -z "$tmp_recovery_path" ]; then
        ${YQ_CMD} -i ".spec.bai_configuration.${component_name}.recovery_path = \"${tmp_recovery_path}\"" ${UPGRADE_DEPLOYMENT_BAI_TMP}
        success "Merged Flink savepoint for ${component_name^^}: \"$tmp_recovery_path\""
        info "When running \"cp4a-deployment -m upgradeDeployment\", this savepoint will be auto-filled into spec.bai_configuration.${component_name}.recovery_path."
    fi
}

#######################################################
# Get BAI Management URL from ZenExtension
# Sets the MANAGEMENT_URL variable directly
# 
# Parameters:
#   $1 - namespace: Namespace to search for ZenExtension
# Returns:
#   0 on success, 1 on failure
#######################################################
function get_bai_management_url_from_zenextension() {
    local namespace="$1"
    local zen_extension_name=""
    
    # Find ZenExtension ending with insights-engine-zen-extension-cr
    zen_extension_name=$(${CLI_CMD} get zenextension -n "${namespace}" --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null | grep 'insights-engine-zen-extension-cr$' | head -n 1)
    
    if [[ -z "$zen_extension_name" ]]; then
        error "No ZenExtension ending with 'insights-engine-zen-extension-cr' found in namespace ${namespace}"
        return 1
    fi
    
    # Get the ZenExtension as YAML and extract proxy_pass URL from nginx.conf
    local zen_yaml=$(${CLI_CMD} get zenextension "${zen_extension_name}" -n "${namespace}" -o yaml 2>/dev/null)
    
    if [[ -z "$zen_yaml" ]]; then
        error "Failed to retrieve ZenExtension ${zen_extension_name}"
        return 1
    fi
    
    # Extract nginx.conf and find proxy_pass URL for /bai-management/
    MANAGEMENT_URL=$(echo "$zen_yaml" | ${YQ_CMD} '.spec."nginx.conf"' | awk '/location \/bai-management\// {found=1} found && /proxy_pass/ {print; exit}' | sed -n 's/.*proxy_pass \(https:\/\/[^;]*\).*/\1/p')
    
    if [[ -z "$MANAGEMENT_URL" ]]; then
        error "Failed to extract proxy_pass URL from location /bai-management/ in ZenExtension ${zen_extension_name}"
        return 1
    fi
    
    # Remove trailing slash if present
    MANAGEMENT_URL="${MANAGEMENT_URL%/}"
    
    return 0
}



# FUnction to create BAI Savepoints
# This function is only called when BAI is an optional component and it is an n-1 to n upgrade
# the function takes 4 parameters
# 1. The services namespace, 
# 2. the CR contents location that was retrieved at the beginning of the mode
# 3. the CR contents back up location.

# There was repetitive code for each different BAI component for which flink jobs exist and that has been converted to a dynamic function called set_bai_recovery_path
# The script also had the same savepoint logic repeating once for a ICP4ACluster CR and once for a Content CR, where it would first try to check if BAI was enabled and then do the savepoint creation. 
# Since we now determine if BAI is enabled before entering the function and also already know the top level CR which helps us identify if BAI is an optional components, the code has become leaner

function create_bai_savepoints(){
    local namespace=$1
    local cr_contents_location=$2
    local cr_contents_backup_location=$3
    
    # Backup existing top level CR
    mkdir -p ${cr_contents_backup_location} >/dev/null 2>&1
    ${COPY_CMD} -rf ${cr_contents_location} ${cr_contents_backup_location}
    
    mkdir -p ${TEMP_FOLDER} >/dev/null 2>&1
    # Check the jq install on MacOS
    if [[ "$machine" == "Mac" ]]; then
        which jq &>/dev/null
        [[ $? -ne 0 ]] && \
        printf '%b\n'  "\x1B[1;31mUnable to locate the jq CLI. You must install it to run this script on macOS.\x1B[0m" && \
        exit 1
    fi

    info "Create the BAI savepoints for recovery path which will be referenced when the new custom resource file is generated as a part of the upgradeDeployment mode."
    ${CLI_CMD} get crd |grep insightsengines.icp4a.ibm.com >&3 2>&3
    if [ $? -eq 0 ]; then
        INSIGHTS_ENGINE_CR=$(${CLI_CMD} get insightsengines.icp4a.ibm.com --no-headers --ignore-not-found -n ${namespace} -o name)
    fi
    if [[ -z $INSIGHTS_ENGINE_CR ]]; then
        INSIGHTS_ENGINE_CR=$(${CLI_CMD} get insightsengines.insightsengine.automation.ibm.com --no-headers --ignore-not-found -n ${namespace} -o name)
        if [[ -z $INSIGHTS_ENGINE_CR ]]; then
            error "An InsightsEngine kind custom resource was not found in the project \"${namespace}\"."
            return 1
        fi
    fi
    if [[ ! -z $INSIGHTS_ENGINE_CR ]]; then
        
        if [[ "$SKIP_FOR_API" == "true" ]]; then
            info "Upgrade is being executed via API endpoints, retrieving Management URL from ZenExtension..."
            get_bai_management_url_from_zenextension "${namespace}"
            if [[ $? -ne 0 || -z "$MANAGEMENT_URL" ]]; then
                error "Failed to retrieve Management URL from ZenExtension"
                return 1
            fi
            info "Retrieved Management URL from ZenExtension: ${MANAGEMENT_URL}"
        else
            MANAGEMENT_URL=$(${CLI_CMD} get ${INSIGHTS_ENGINE_CR} --no-headers --ignore-not-found -n ${namespace} -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].uri}')
            info "Retrieved Management URL from InsightsEngine CR: ${MANAGEMENT_URL}"
        fi
        MANAGEMENT_AUTH_SECRET=$(${CLI_CMD} get ${INSIGHTS_ENGINE_CR} --no-headers --ignore-not-found -n ${namespace} -o jsonpath='{.status.components.management.endpoints[?(@.scope=="External")].authentication.secret.secretName}')
        MANAGEMENT_USERNAME=$(${CLI_CMD} get secret ${MANAGEMENT_AUTH_SECRET} --no-headers --ignore-not-found -n ${namespace} -o jsonpath='{.data.username}' | base64 -d)
        MANAGEMENT_PASSWORD=$(${CLI_CMD} get secret ${MANAGEMENT_AUTH_SECRET} --no-headers --ignore-not-found -n ${namespace} -o jsonpath='{.data.password}' | base64 -d)
        if [[ -z "$MANAGEMENT_URL" || -z "$MANAGEMENT_AUTH_SECRET" || -z "$MANAGEMENT_USERNAME" || -z "$MANAGEMENT_PASSWORD" ]]; then
            error "Can not create the BAI savepoints for recovery path."
            return 1
        else
            # Ensure output directory exists
            mkdir -p ${UPGRADE_DEPLOYMENT_CR} >/dev/null 2>&1
            touch ${UPGRADE_DEPLOYMENT_BAI_TMP} >/dev/null 2>&1
            if [[ -e ${UPGRADE_DEPLOYMENT_CR}/bai.json ]]; then
                [ "$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json)" != "[]" ] && mkdir -p ${UPGRADE_DEPLOYMENT_CR}/bai-json-backup && cp ${UPGRADE_DEPLOYMENT_CR}/bai.json ${UPGRADE_DEPLOYMENT_CR}/bai-json-backup/bai_$(date +'%Y%m%d%H%M%S').json
            fi
            curl -X POST -k -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} "${MANAGEMENT_URL}/api/v1/processing/jobs/savepoints" -o ${UPGRADE_DEPLOYMENT_CR}/bai.json >&3 2>&3

            json_file_content="[]"
            if [ "$json_file_content" == "$(cat ${UPGRADE_DEPLOYMENT_CR}/bai.json)" ] ;then
                fail "None return in \"${UPGRADE_DEPLOYMENT_CR}/bai.json\" when request BAI savepoint through REST API: curl -X POST -k -u ${MANAGEMENT_USERNAME}:${MANAGEMENT_PASSWORD} \"${MANAGEMENT_URL}/api/v1/processing/jobs/savepoints\" "
                warning "Fetch Flink job savepoints for the recovery path using above REST API manually, then place the JSON file (bai.json) under the directory \"${TEMP_FOLDER}/\""
                if [[ "$SKIP_FOR_API" != "true" ]]; then
                    prompt_press_any_key_to_continue
                fi
            fi
            ##########################################################################################################################
            ## In 24.0.1 and later, we'll only support n-1 upgrade therefore we're back to the old way of saving content event-forwarder savepoint and bai-content savepoint UNLESS the ALLOW_DIRECT_UPGRADE == 1 .
            ##########################################################################################################################
            # Process savepoints for different components
            # For n-1 upgrade (not direct upgrade), process event-forwarder and content
            if [[ "$ALLOW_DIRECT_UPGRADE" != 1 ]]; then
                set_bai_recovery_path "event-forwarder"
                set_bai_recovery_path "content"
            fi
            
            # Process other components (always)
            set_bai_recovery_path "icm"
            set_bai_recovery_path "odm"
            set_bai_recovery_path "bawadv"
            set_bai_recovery_path "bpmn"
            set_bai_recovery_path "navigator"
            set_bai_recovery_path "ads"
        fi
    fi
}


# Helper function to scale operators for upgradeDeploymentStatus
function scale_operator() {
    local operator_name=$1
    local operator_label=$2
    
    info "Scaling up \"$operator_label\" operator"
    ${CLI_CMD} scale --replicas=1 deployment $operator_name -n $CP4BA_OPERATOR_NS >&3 2>&3
    if [ $? -eq 0 ]; then
        sleep 1
    else
        fail "Failed to scale up \"$operator_label\" operator"
    fi
}

# Generic helper function to set PostgreSQL client flag for a given database
# Parameters:
#   $1: DB user name property key (e.g., "ADP_GG_DB_USER_NAME", "AEOS_DB_USER_NAME", "DEVOS_DB_USER_NAME")
#   $2: Output variable name (e.g., "adpgg_postgresql_client_flag", "aeos_postgresql_client_flag", "devos_postgresql_client_flag")
#   $3: (Optional) Use server-specific DB_TYPE instead of global $DB_TYPE (default: "false")
function get_postgresql_client_flag() {
    local db_user_property_key="$1"
    local output_var_name="$2"
    local use_server_db_type="${3:-false}"
    
    # Get DB server name
    local tmp_dbservername
    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name "$db_user_property_key")"
    tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
    check_dbserver_name_valid "$tmp_dbservername" "$db_user_property_key"
    
    # Determine which DB_TYPE to use
    local db_type_to_check
    if [[ "$use_server_db_type" == "true" ]]; then
        # Get DB type from server properties (for ADP GG)
        db_type_to_check="$(prop_db_server_property_file "$tmp_dbservername.DATABASE_TYPE")"
        db_type_to_check=$(sed -e 's/^"//' -e 's/"$//' <<<"$db_type_to_check")
        db_type_to_check=$(echo "$db_type_to_check" | tr '[:upper:]' '[:lower:]')
    else
        # Use global DB_TYPE (for AEOS and DEVOS)
        db_type_to_check="$DB_TYPE"
    fi
    
    # Get PostgreSQL SSL client flag
    local result_flag=""
    if [[ "$db_type_to_check" == "postgresql" ]]; then
        local tmp_flag
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file "$tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER")")
        result_flag=$(echo "$tmp_flag" | tr '[:upper:]' '[:lower:]')
    elif [[ "$db_type_to_check" == "postgresql-edb" ]]; then
        result_flag="true"
    elif [[ "$use_server_db_type" == "true" ]]; then
        # For non-PostgreSQL databases when using server-specific type (ADP GG case)
        result_flag="true"
    fi
    
    # Set the output variable dynamically
    eval "$output_var_name=\"$result_flag\""
}

#DBACLD-231157: This function will display messages about external PG when the customer selects ADP GG or ADS with database type other than external PG.
# The function will take 3 parameters:
# 1. mode: Depending on the mode (property, generate, deployment), the message will be different.
# 2. component: The component for which the message is being displayed such as ADP GG or ADS
# 3. update_property_file: Whether to update the property file (default: false)
function adp_ads_ext_pg_message() {
    local mode="$1"
    local component="${2:-Decision Intelligence Client Managed Software and/or IBM Automation Document Processing}"
    local update_property_file="${3:-false}"
    
    #Display during -m property mode when customer selecting ADP/ADS with DB type other than external PG. The message will be a notice about the requirement of external PG for these components and that more information will be provided in later modes
    if [[ "$mode" == "property" ]]; then
        if [[ "$update_property_file" == "true" ]]; then
            # We need to remove the line of note="## If you select the ${DB_TYPE} type database then the operator will deploy the Postgres EDB instance, so you won't need to provide DB service/server details and create a database ##" from the generated properties file since it is not relevant when DB type is not external PostgreSQL and it is causing confusion for customers who are selecting ADP GG or ADS capabilities with a DB type other than external PostgreSQL
            ${SED_COMMAND} "/## If you select the ${DB_TYPE} type database then the operator will deploy the Postgres EDB instance, so you won't need to provide DB service\/server details and create a database ##/d" ${DB_NAME_USER_PROPERTY_FILE} >&3 2>&3
        
        else
            info "${YELLOW_TEXT}[IMPORTANT]: External Postgresql must be used since $component capabilities are selected.  More detail information will be provided in later modes. ${RESET_TEXT}"
            # add new line
            echo ""
        fi
    fi
    # Displaying during -m generate mode
    if [[ "$mode" == "generate" ]]; then
        info "${YELLOW_TEXT}[IMPORTANT]: Since $component capabilities are selected and database type is not selected as external PostgreSQL. Please follow the instructions in ADP_DICMS_PG.md to setup the external PostgreSQL databases for these components before running validate mode. ${RESET_TEXT}"
        # add new line
        echo ""
    fi
    # Displaying during cp4a-deployment -n <namespace>
    if [[ "$mode" == "deployment" ]]; then
        info "${YELLOW_TEXT}[IMPORTANT]: Since $component capabilities are selected and database type is not selected as external PostgreSQL. Please follow the instructions in ADP_DICMS_PG.md to update the CR YAML before applying it to the cluster. ${RESET_TEXT}"
        # add new line
        echo ""
    fi
}



# Function to update BTS datastore configuration for tls.key to tls.pk8 migration
# This function checks for the ConfigMap 'ibm-bts-config-extension' and Secret 'bts-datastore-edb-secret'
# and updates tls.key references to tls.pk8 where needed.
#
# Usage: update_bts_datastore_resources $services_namespace
#
# Parameters:
#   $1 - namespace: The CP4BA namespace to check

function update_bts_datastore_resources() {
    local namespace="$1"
    local bts_configmap_name="ibm-bts-config-extension"
    local bts_secret_name="bts-datastore-edb-secret"
    
    info "Checking if the current deployment has the Secret '$bts_secret_name' and ConfigMap '$bts_configmap_name' created in the namespace: $namespace"
    echo
    # Check if ConfigMap exists
    local cm_exists=false
    if ${CLI_CMD} get configmap "$bts_configmap_name" -n "$namespace" &> /dev/null; then
        cm_exists=true
        info "ConfigMap '$bts_configmap_name' found in namespace '$namespace'"
    else
        info "ConfigMap '$bts_configmap_name' not found in namespace '$namespace'"
    fi
    
    # Check if Secret exists
    local secret_exists=false
    if ${CLI_CMD} get secret "$bts_secret_name" -n "$namespace" &> /dev/null; then
        secret_exists=true
        info "Secret '$bts_secret_name' found in namespace '$namespace'"
    else
        info "Secret '$bts_secret_name' not found in namespace '$namespace'"
    fi
    
    # Exit if neither resource exists
    if [[ "$cm_exists" == "false" && "$secret_exists" == "false" ]]; then
        info "Neither ConfigMap '$bts_configmap_name' nor Secret '$bts_secret_name' exist in this deployment. Skipping the resource updates as they are not required."
        return 0
    fi
    echo
    # Process Secret if it exists
    if [[ "$secret_exists" == "true" ]]; then
        info "Processing Secret '$bts_secret_name' to check for 'tls.key' field..."
        
        # Check if secret has tls.key using jsonpath
        local has_tls_key=$(${CLI_CMD} get secret "$bts_secret_name" -n "$namespace" -o jsonpath='{.data.tls\.key}' 2>/dev/null)
        
        if [[ -n "$has_tls_key" ]]; then
            warning "Found 'tls.key' field in Secret '$bts_secret_name'. This field needs to be renamed to 'tls.pk8' for compatibility with the latest BTS version."
            info "Applying patch to rename 'tls.key' to 'tls.pk8' in Secret '$bts_secret_name'..."
            
            # Create a patch to rename tls.key to tls.pk8
            ${CLI_CMD} patch secret "$bts_secret_name" -n "$namespace" --type=json -p="[
                {\"op\": \"add\", \"path\": \"/data/tls.pk8\", \"value\": \"$has_tls_key\"},
                {\"op\": \"remove\", \"path\": \"/data/tls.key\"}
            ]"
            
            if [[ $? -eq 0 ]]; then
                success "Successfully renamed 'tls.key' to 'tls.pk8' in Secret '$bts_secret_name'"
            else
                error "Failed to update Secret '$bts_secret_name'. Please check the secret permissions and try again."
                return 1
            fi
        else
            # Check if tls.pk8 already exists
            local has_tls_pk8=$(${CLI_CMD} get secret "$bts_secret_name" -n "$namespace" -o jsonpath='{.data.tls\.pk8}' 2>/dev/null)
            if [[ -n "$has_tls_pk8" ]]; then
                info "Secret '$bts_secret_name' already has 'tls.pk8' field. No changes needed."
            fi
        fi
    fi
    
    # Process ConfigMap if it exists
    if [[ "$cm_exists" == "true" ]]; then
        info "Processing ConfigMap '$bts_configmap_name' to check for 'tls.key' file path references..."
        
        # Get all keys from ConfigMap data section
        local all_keys=$(${CLI_CMD} get configmap "$bts_configmap_name" -n "$namespace" -o jsonpath='{.data}' 2>/dev/null)
        
        if [[ -z "$all_keys" || "$all_keys" == "{}" ]]; then
            warning "No data found in ConfigMap '$bts_configmap_name'. ConfigMap appears to be empty."
        else
            # Find all customPropertyName keys and check for sslKey value
            local ssl_key_num=""
            local custom_prop_names=$(${CLI_CMD} get configmap "$bts_configmap_name" -n "$namespace" -o json | grep -o '"customPropertyName[0-9]*"' | tr -d '"')
            
            if [[ -z "$custom_prop_names" ]]; then
                info "No 'customPropertyName' keys found in ConfigMap '$bts_configmap_name'. No SSL key configuration to update."
            else
                # Check each customPropertyName to find sslKey
                while IFS= read -r key; do
                    if [[ -n "$key" ]]; then
                        local value=$(${CLI_CMD} get configmap "$bts_configmap_name" -n "$namespace" -o jsonpath="{.data.$key}" 2>/dev/null)
                        
                        if [[ "$value" == "sslKey" ]]; then
                            # Extract the number from customPropertyNameX
                            ssl_key_num=$(echo "$key" | grep -o '[0-9]*$')
                            info "Found 'sslKey' property at '$key'"
                            break
                        fi
                    fi
                done <<< "$custom_prop_names"
                
                if [[ -n "$ssl_key_num" ]]; then
                    # Check the corresponding customPropertyValue
                    local custom_prop_value_key="customPropertyValue$ssl_key_num"
                    local current_value=$(${CLI_CMD} get configmap "$bts_configmap_name" -n "$namespace" -o jsonpath="{.data.$custom_prop_value_key}" 2>/dev/null)
                    
                    if [[ -n "$current_value" ]]; then
                        
                        # Check if the path ends with tls.key
                        if [[ "$current_value" == *"tls.key" ]]; then
                            local new_value="${current_value%tls.key}tls.pk8"
                            warning "File path ends with 'tls.key' which needs to be updated to 'tls.pk8' for compatibility with the latest BTS version."
                            info "Applying patch to update '$custom_prop_value_key' from '$current_value' to '$new_value'..."
                            
                            # Patch the ConfigMap
                            ${CLI_CMD} patch configmap "$bts_configmap_name" -n "$namespace" --type=json -p="[
                                {\"op\": \"replace\", \"path\": \"/data/$custom_prop_value_key\", \"value\": \"$new_value\"}
                            ]"
                            
                            if [[ $? -eq 0 ]]; then
                                success "Successfully updated the '$custom_prop_value_key' key in ConfigMap '$bts_configmap_name'"
                            else
                                error "Failed to update ConfigMap '$bts_configmap_name'. Please check the configmap '$bts_configmap_name' permissions and try again."
                                return 1
                            fi
                        elif [[ "$current_value" == *"tls.pk8" ]]; then
                            info "File path already ends with 'tls.pk8'. No changes needed."
                        else
                            echo
                        fi
                    else
                        warning "Property '$custom_prop_value_key' not found or is empty in ConfigMap '$bts_configmap_name'."
                        warning "Expected to find the SSL key file path at this property."
                    fi
                else
                    info "No 'sslKey' property found in ConfigMap '$bts_configmap_name'."
                    info "Please verify the '$bts_configmap_name' configmap before proceeding with next steps."
                fi
            fi
        fi
    fi
    
    success "BTS Datasource resources are compatible with the latest BTS version."
    return 0
}

# Function to replace "ADS_" string with "DICMS_" in the prop file DB_NAME_USER_PROPERTY_FILE
# In the future, we might need to add more prop files, but currently I only see ADS properties in DB_NAME_USER_PROPERTY_FILE
# This is useful for case when we are migrating prop files from a prior version of CP4BA where the props were named "ADS"
# In CP4BA 26.0.0, we renamed ADS to DICMS
function update_ads_name_to_dicms_in_prop_file(){
    if [[ -z "${DB_NAME_USER_PROPERTY_FILE}" ]]; then
        error "DB_NAME_USER_PROPERTY_FILE variable is not set. Cannot update property file."
        return 1
    fi
    
    if [[ ! -f "${DB_NAME_USER_PROPERTY_FILE}" ]]; then
        error "Property file '${DB_NAME_USER_PROPERTY_FILE}' does not exist."
        return 1
    fi
    
    info "Updating property file: ${DB_NAME_USER_PROPERTY_FILE}"
    info "Renaming all variables named 'ADS_' to 'DICMS_' because ADS has been renamed to DICMS ..."
    
    # Create a backup of the original file
    local backup_file="${DB_NAME_USER_PROPERTY_FILE}.bak_ads_to_dicms"
    ${COPY_CMD} "${DB_NAME_USER_PROPERTY_FILE}" "${backup_file}"
    
    if [[ $? -ne 0 ]]; then
        error "Failed to create backup of property file."
        return 1
    fi
    
    # Replace all instances of ADS_ with DICMS_ in the file
    ${SED_COMMAND} 's/ADS_/DICMS_/g' ${DB_NAME_USER_PROPERTY_FILE}
    
    if [[ $? -eq 0 ]]; then
        success "Successfully renamed 'ADS_' variables to 'DICMS_' in ${DB_NAME_USER_PROPERTY_FILE}"
        # Remove backup ${backup_file}
        rm -f "${backup_file}" 2>/dev/null
        # Clean up any sed backup files with "" suffix
        rm -f "${DB_NAME_USER_PROPERTY_FILE}\"\"" 2>/dev/null
        return 0
    else
        error "Failed to update property file. Restoring from backup..."
        ${COPY_CMD} "${backup_file}" "${DB_NAME_USER_PROPERTY_FILE}"
        return 1
    fi
}

#
# Function to add DICMS properties to property files that are needed specifically in the Vault scenario
# (originally in "cp4a-prerequisites.sh", moved to this helper function so it can be reused in multiple scenarios)
#
function add_dicms_props_for_vault() {
    # DICMS is chosen as a component and whatever database is used, if vault mode is enabled we need more user properties
    # NOTE: Properties are only added if they don't already exist (to avoid duplication)
    if [[ " ${pattern_cr_arr[@]} " =~ " decisions_ads " && "$VAULT_ENABLED" == "true" ]]; then
        if [[ " ${optional_component_cr_arr[@]} " =~ " ads_designer " ]]; then
            tip="##       USER Properties for DICMS Designer       ##"
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            # DI Designer user profile
            if ! grep -q "^DICMS_DESIGNER_ENCRYPTION_KEYS=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
                echo "## Choose an encryption keys in JSON format." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "DICMS_DESIGNER_ENCRYPTION_KEYS=\"{\\\"activeKey\\\": \\\"key1\\\", \\\"secretKeyList\\\": [ {\\\"secretKeyId\\\": \\\"key1\\\", \\\"value\\\": \\\"<Required>\\\"} ] }\"" >> ${USER_PROFILE_PROPERTY_FILE}
                echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
            if ! grep -q "^DICMS_DESIGNER_SSL_KEYSTORE_PASSWORD=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
                echo "## Choose a SSL keystore password." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "DICMS_DESIGNER_SSL_KEYSTORE_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
                echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
        fi   
        if [[ " ${optional_component_cr_arr[@]} " =~ " ads_runtime " ]]; then
            tip="##      USER Properties for DICMS Runtime         ##"
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
            echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
            # DI Designer user profile
            echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            if ! grep -q "^DICMS_RUNTIME_DEPLOYMENT_SPACE_MANAGER_USERNAME=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
                echo "## IMPORTANT: You must use distinct user names for each DICMS_RUNTIME_*_USERNAME property as they are used to map to distinct application roles." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "## Choose a deployment space manager username." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "DICMS_RUNTIME_DEPLOYMENT_SPACE_MANAGER_USERNAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
                echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
            if ! grep -q "^DICMS_RUNTIME_DEPLOYMENT_SPACE_MANAGER_PASSWORD=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
                echo "## Choose a deployment space manager password." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "DICMS_RUNTIME_DEPLOYMENT_SPACE_MANAGER_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
                echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
            if ! grep -q "^DICMS_RUNTIME_DECISION_SERVICE_USERNAME=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
                echo "## Choose a decision service username." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "DICMS_RUNTIME_DECISION_SERVICE_USERNAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
                echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
            if ! grep -q "^DICMS_RUNTIME_DECISION_SERVICE_PASSWORD=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
                echo "## Choose a decision service password." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "DICMS_RUNTIME_DECISION_SERVICE_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
                echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
            if ! grep -q "^DICMS_RUNTIME_DECISION_SERVICE_MANAGER_USERNAME=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
                echo "## Choose a decision service manager username." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "DICMS_RUNTIME_DECISION_SERVICE_MANAGER_USERNAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
                echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
            if ! grep -q "^DICMS_RUNTIME_DECISION_SERVICE_MANAGER_PASSWORD=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
                echo "## Choose a decision service manager password." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "DICMS_RUNTIME_DECISION_SERVICE_MANAGER_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
                echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
            if ! grep -q "^DICMS_RUNTIME_DECISION_RUNTIME_MONITOR_USERNAME=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
                echo "## Choose a decision runtime monitor username." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "DICMS_RUNTIME_DECISION_RUNTIME_MONITOR_USERNAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
                echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
            if ! grep -q "^DICMS_RUNTIME_DECISION_RUNTIME_MONITOR_PASSWORD=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
                echo "## Choose a decision runtime monitor password." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "DICMS_RUNTIME_DECISION_RUNTIME_MONITOR_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
                echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
            if ! grep -q "^DICMS_RUNTIME_ENCRYPTION_KEYS=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
                echo "## Choose encryption keys in JSON format." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "DICMS_RUNTIME_ENCRYPTION_KEYS=\"{\\\"activeKey\\\": \\\"key1\\\", \\\"secretKeyList\\\": [ {\\\"secretKeyId\\\": \\\"key1\\\", \\\"value\\\": \\\"<Required>\\\"} ] }\"" >> ${USER_PROFILE_PROPERTY_FILE}
                echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
            if ! grep -q "^DICMS_RUNTIME_SSL_KEYSTORE_PASSWORD=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
                echo "## Choose a SSL keystore password." >> ${USER_PROFILE_PROPERTY_FILE}
                echo "DICMS_RUNTIME_SSL_KEYSTORE_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
                echo "" >> ${USER_PROFILE_PROPERTY_FILE}
            fi
        fi

        success "Extra properties for Decision Intelligence Client Managed Software in vault mode have been added\n"
    fi
}

#
# Function to add ODM properties to property files 
# (originally in "cp4a-prerequisites.sh", moved to this helper function so it can be reused in multiple scenarios)
# No longer needed https://jsw.ibm.com/browse/DBACLD-238578?focusedId=30084545&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-30084545
function add_odm_props() {

    if ! grep -q "^ODM.KEYSTORE_PASSWORD=" ${USER_PROFILE_PROPERTY_FILE} 2>/dev/null; then
        # user property section for ODM which for now has just a keystorePassword field
        # https://jsw.ibm.com/browse/DBACLD-238578
        tip="##       USER Property for ODM   ##"
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "$tip" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
        # Adding a new property for the keystore password required for generating the ibm-odm-keystore-secret
        # https://jsw.ibm.com/browse/DBACLD-238578
        echo "## Provide a string for keystorePassword in the ibm-odm-keystore-secret that will be used when creating the keystore." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## If password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text. (NOTES: ODM.KEYSTORE_PASSWORD must exceed 16 characters when fips enabled.)" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Note: If you enable external Vault feature, enter your password in plain text, regardless of whether it contains special characters." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "ODM.KEYSTORE_PASSWORD=\"{Base64}<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
        success "Property file has been updated with IBM Operational Decision Manager properties.\n"
    fi
}