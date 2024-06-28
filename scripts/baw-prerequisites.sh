#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2022, 2024. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Import common utilities and environment variables
source ${CUR_DIR}/helper/common.sh

# Import verification func
source ${CUR_DIR}/helper/cp4a-verification.sh

# Import variables for property file
source ${CUR_DIR}/helper/cp4ba-property.sh

# Import function for secret
source ${CUR_DIR}/helper/cp4ba-secret.sh

TEMP_FOLDER=${CUR_DIR}/.tmp
BAK_FOLDER=${CUR_DIR}/.bak

PREREQUISITES_FOLDER=${CUR_DIR}/baw-prerequisites
PREREQUISITES_FOLDER_BAK=${CUR_DIR}/baw-prerequisites-backup
PROPERTY_FILE_FOLDER=${PREREQUISITES_FOLDER}/propertyfile
PROPERTY_FILE_FOLDER_BAK=${PREREQUISITES_FOLDER_BAK}/propertyfile

FINAL_CR_FOLDER=${PREREQUISITES_FOLDER}/generated-cr
CREATE_SECRET_SCRIPT_FILE=$PREREQUISITES_FOLDER/create_secret.sh

LDAP_SSL_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert/ldap
EXT_LDAP_SSL_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert/external_ldap
DB_SSL_CERT_FOLDER=${PROPERTY_FILE_FOLDER}/cert/db

TEMPORARY_PROPERTY_FILE=${TEMP_FOLDER}/.TEMPORARY.property
LDAP_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/baw_LDAP.property
EXTERNAL_LDAP_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/baw_external_LDAP.property

DB_NAME_USER_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/baw_db_name_user.property
DB_SERVER_INFO_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/baw_db_server.property
USER_PROFILE_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/baw_user_profile.property

BAW_STD_OS_ARR=("BAWDOCS" "BAWDOS" "BAWTOS")

# Directory and script file for DB Script
DB_SCRIPT_FOLDER=${PREREQUISITES_FOLDER}/dbscript
FNCM_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/fncm
BAN_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/ban
AE_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/ae
BAW_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/baw-std
UMS_DB_SCRIPT_FOLDER=${DB_SCRIPT_FOLDER}/ums

# Directory and template file for secret YAML template 
SECRET_FILE_FOLDER=${PREREQUISITES_FOLDER}/secret_template

DB_SSL_SECRET_FOLDER=${SECRET_FILE_FOLDER}/cp4ba_db_ssl_secret
LDAP_SSL_SECRET_FOLDER=${SECRET_FILE_FOLDER}/cp4ba_ldap_ssl_secret

CP4A_DB_SSL_SECRET_FILE=${DB_SSL_SECRET_FOLDER}/ibm-cp4ba-db-ssl-cert-secret.sh
CP4A_LDAP_SSL_SECRET_FILE=${LDAP_SSL_SECRET_FOLDER}/ibm-cp4ba-ldap-ssl-cert-secret.sh
CP4A_EXT_LDAP_SSL_SECRET_FILE=${LDAP_SSL_SECRET_FOLDER}/ibm-cp4ba-external-ldap-ssl-cert-secret.sh


LDAP_SECRET_FILE=${SECRET_FILE_FOLDER}/ibm-ldap-bind-secret.yaml
EXT_LDAP_SECRET_FILE=${SECRET_FILE_FOLDER}/ibm-external-ldap-bind-secret.yaml

FNCM_SECRET_FOLDER=${SECRET_FILE_FOLDER}/fncm
FNCM_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-fncm-secret.yaml

FNCM_ICC_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-fncm-icc-secret.yaml
FNCM_ICCSAP_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-fncm-iccsap-secret.yaml
FNCM_IER_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-fncm-ier-secret.yaml
FNCM_DB_SSL_SECRET_FILE=${FNCM_SECRET_FOLDER}/ibm-fncm-db-ssl-cert-secret.sh

BAN_SECRET_FOLDER=${SECRET_FILE_FOLDER}/ban
BAN_SECRET_FILE=${BAN_SECRET_FOLDER}/ibm-ban-secret.yaml
BAN_DB_SSL_SECRET_FILE=${BAN_SECRET_FOLDER}/ibm-ban-db-ssl-cert-secret.sh

UMS_SECRET_FOLDER=${SECRET_FILE_FOLDER}/ums
UMS_SECRET_FILE=${UMS_SECRET_FOLDER}/ibm-ums-db-secret.yaml
UMS_DB_SSL_SECRET_FILE=${UMS_SECRET_FOLDER}/ibm-ums-db-ssl-cert-secret.sh

BAW_SECRET_FOLDER=${SECRET_FILE_FOLDER}/baw
BAW_SECRET_FILE=${BAW_SECRET_FOLDER}/ibm-baw-db-secret.yaml
BAW_DB_SSL_SECRET_FILE=${BAW_SECRET_FOLDER}/ibm-baw-authoring-db-ssl-cert-secret.sh

BAW_AWS_SECRET_FOLDER=${SECRET_FILE_FOLDER}/baw-std
BAW_RUNTIME_SECRET_FILE=${BAW_AWS_SECRET_FOLDER}/ibm-baw-db-secret.yaml
ICP4A_ENCRYPTION_KEY_SECRET_FILE=${BAW_AWS_SECRET_FOLDER}/icp4a-shared-encryption-key-secret.yaml

APP_ENGINE_SECRET_FOLDER=${SECRET_FILE_FOLDER}/ae
APP_ENGINE_SECRET_FILE=${APP_ENGINE_SECRET_FOLDER}/ibm-aae-app-engine-secret.yaml
APP_ENGINE_PLAYBACK_SECRET_FILE=${APP_ENGINE_SECRET_FOLDER}/ibm-playback-server-admin-secret.yaml
APP_ENGINE_DB_SSL_SECRET_FILE=${APP_ENGINE_SECRET_FOLDER}/ibm-aae-app-engine-db-ssl-cert-secret.sh
APP_ORACLE_SSO_SSL_SECRET_FILE=${DB_SSL_SECRET_FOLDER}/ibm-ae-oracle-sso-cert-secret.sh

# BAW stanalone CR file
BAW_STD_PATTERN_FILE=$PARENT_DIR/descriptors/patterns/ibm_cp4a_cr_production_FC_workflow-standalone.yaml
BAW_STD_PATTERN_FILE_TMP=$TEMP_FOLDER/.ibm_cp4a_cr_production_FC_workflow-standalone_tmp.yaml
BAW_STD_PATTERN_FILE_GENERATED=$FINAL_CR_FOLDER/ibm_cp4a_cr_production_FC_workflow-standalone_final.yaml

JDBC_DRIVER_DIR=${CUR_DIR}/jdbc
PLATFORM_SELECTED=""
PATTERN_SELECTED=""
COMPONENTS_SELECTED=""
OPT_COMPONENTS_CR_SELECTED=""
OPT_COMPONENTS_SELECTED=()
LDAP_TYPE=""
TARGET_PROJECT_NAME=""
CP4BA_JDBC_URL=""

FOUNDATION_CR_SELECTED=""
optional_component_arr=()
optional_component_cr_arr=()
foundation_component_arr=()

LICENSE_USER="user"
LICENSE_NON_PRODUCTION="non-production"
LICENSE_PRODUCTION="production"

PURCHASED_PRODUCT_BAW="BAW"
PURCHASED_PRODUCT_CP4A="CP4A"

LICENSE_BAW_URL="https://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-UEJG-Z2937H"
LICENSE_CP4A_URL="https://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-FNHF-F9RU7N"

function show_help() {     
    echo -e "\nUsage: baw-prerequisites.sh -m [modetype]\n"     
    echo "Options:"     
    echo "  -h  Display help"     
    echo "  -m  The valid mode types are [property], [generate], [validate], or [generate-cr]"
    echo "      STEP1: Run the script in [property] mode to create the user property files (DB/LDAP property files) with default values (database name/user)."
    echo "      STEP2: Modify the DB/LDAP/User property files with your values."
    echo "      STEP3: Run the script in [generate] mode to generate the DB SQL statement files and YAML template for the secrets, based on the values in the property files."     
    echo "      STEP4: Create the databases and secrets manually based on the modified DB SQL statement file and YAML templates for the secret."     
    echo "      STEP5: Run the script in [validate] mode to check that the databases and secrets are created before you deploy Business Automation Workflow."     
    echo "      STEP6: Run the script in [generate-cr] mode to generate the Business Automation Workflow custom resources based on the property files." 
} 

function prompt_license(){
    get_purchased_product
    retVal_baw=$?

    if [[ $retVal_baw -eq 0 ]]; then
        echo -e "\x1B[1;31mIMPORTANT: Review the IBM Business Automation Workflow license information here: \n\x1B[0m"
        echo -e "\x1B[1;31m${LICENSE_BAW_URL}\n\x1B[0m"
    fi

    if [[ $retVal_baw -eq 1 ]]; then
        echo -e "\x1B[1;31mIMPORTANT: Review the IBM Cloud Pak for Business Automation license information here: \n\x1B[0m"
        echo -e "\x1B[1;31m${LICENSE_CP4A_URL}\n\x1B[0m"
    fi

    read -rsn1 -p"Press any key to continue";echo

    # Accept license
    printf "\n"
    while true; do
        if [[ $retVal_baw -eq 0 ]]; then
            prompt_message="Do you accept the IBM Business Automation Workflow license (Yes/No, default: No): "
        elif [[ $retVal_baw -eq 1 ]]; then
            prompt_message="Do you accept the IBM Cloud Pak for Business Automation license (Yes/No, default: No): "
        fi

        printf "\x1B[1m${prompt_message}\x1B[0m"

        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            printf "\n"
            IBM_LICENS="Accept"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            echo -e "Exiting...\n"
            exit 0
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function get_purchased_product(){
    product_mode=$(grep -w "^CP4BA.PURCHASED_PRODUCT" "${USER_PROFILE_PROPERTY_FILE}" | cut -d'=' -f2 | tr -d '"')

    if [[ "${product_mode}" == "${PURCHASED_PRODUCT_BAW}" ]]; then 
        return 0
    elif [[ "${product_mode}" == "${PURCHASED_PRODUCT_CP4A}" ]]; then 
        return 1
    fi
}

function get_deploy_license() {
    # select purchased license (BAW / CP4BA)
    PURCHASED_PRODUCT="BAW"
    printf "\n"
    echo -e "\x1B[1mWhich production license have you purchased? (1: ${PURCHASED_PRODUCT_BAW}, 2: ${PURCHASED_PRODUCT_CP4A}): \x1B[0m"

    options=("${PURCHASED_PRODUCT_BAW}" "${PURCHASED_PRODUCT_CP4A}")
    PS3='Enter a valid option [1 to 2]: '

    select opt in "${options[@]}"
    do
        case $opt in
            "${PURCHASED_PRODUCT_BAW}")
                PURCHASED_PRODUCT="${PURCHASED_PRODUCT_BAW}"
                break
                ;;
            "${PURCHASED_PRODUCT_CP4A}")
                PURCHASED_PRODUCT="${PURCHASED_PRODUCT_CP4A}"
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done

    success "Selected purchased license: ${PURCHASED_PRODUCT}"

    # sc_deployment_baw_license
    # - PURCHASED_PRODUCT=BAW   -> SC_DEPLOYMENT_BAW_LICENSE values: non-production, non-production
    # - PURCHASED_PRODUCT=CP4BA -> SC_DEPLOYMENT_BAW_LICENSE values: user, non-production, non-production
    select_baw_license

    # sc_deployment_fncm_license
    SC_DEPLOYMENT_FNCM_LICENSE="${LICENSE_PRODUCTION}"
    printf "\n"
    echo -e  "\x1B[1mWhich deployment license for IBM FileNet Content Manager do you want to install? (1: user, 2: non-production, 3: production): \x1B[0m\n"

    options=("${LICENSE_USER}" "${LICENSE_NON_PRODUCTION}" "${LICENSE_PRODUCTION}")
    PS3='Enter a valid option [1 to 3]: '

    select opt in "${options[@]}"
    do
        case $opt in
            "${LICENSE_USER}")
                SC_DEPLOYMENT_FNCM_LICENSE="${LICENSE_USER}"
                break
                ;;
            "${LICENSE_NON_PRODUCTION}")
                SC_DEPLOYMENT_FNCM_LICENSE="${LICENSE_NON_PRODUCTION}"
                break
                ;;
            "${LICENSE_PRODUCTION}")
                SC_DEPLOYMENT_FNCM_LICENSE="${LICENSE_PRODUCTION}"
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done

    success "Selected deployment license for IBM FileNet Content Manager: ${SC_DEPLOYMENT_FNCM_LICENSE}"

    # Only select for CP4BA
    if [[ "${PURCHASED_PRODUCT}" == "${PURCHASED_PRODUCT_CP4A}" ]]; then
        # sc_deployment_license
        SC_DEPLOYMENT_LICENSE="${LICENSE_PRODUCTION}"
        printf "\n"
        echo -e  "\x1B[1mWhich deployment license for IBM Cloud Pak for Business Automation do you want to install? (1: non-production, 2: production): \x1B[0m\n"
        
        options=("${LICENSE_NON_PRODUCTION}" "${LICENSE_PRODUCTION}")
        PS3='Enter a valid option [1 to 2]: '

        select opt in "${options[@]}"
        do
            case $opt in
                "${LICENSE_NON_PRODUCTION}")
                    SC_DEPLOYMENT_LICENSE="${LICENSE_NON_PRODUCTION}"
                    break
                    ;;
                "${LICENSE_PRODUCTION}")
                    SC_DEPLOYMENT_LICENSE="${LICENSE_PRODUCTION}"
                    break
                    ;;
                *) echo "Invalid option $REPLY";;
            esac
        done

        success "Selected deployment license for IBM Cloud Pak for Business Automation: ${SC_DEPLOYMENT_LICENSE}"
    fi
}

function select_baw_license() {
    # sc_deployment_baw_license
    SC_DEPLOYMENT_BAW_LICENSE="${LICENSE_PRODUCTION}"

    if [[ "${PURCHASED_PRODUCT}" == "${PURCHASED_PRODUCT_CP4A}" ]]; then
        printf "\n"
        echo -e "\x1B[1mWhich deployment license for IBM Business Automation Workflow do you want to install? (1: user, 2: non-production, 3: production): \x1B[0m"

        options=("${LICENSE_USER}" "${LICENSE_NON_PRODUCTION}" "${LICENSE_PRODUCTION}")
        PS3='Enter a valid option [1 to 3]: '

        select opt in "${options[@]}"
        do
            case $opt in
                "${LICENSE_USER}")
                    SC_DEPLOYMENT_BAW_LICENSE="${LICENSE_USER}"
                    break
                    ;;
                "${LICENSE_NON_PRODUCTION}")
                    SC_DEPLOYMENT_BAW_LICENSE="${LICENSE_NON_PRODUCTION}"
                    break
                    ;;
                "${LICENSE_PRODUCTION}")
                    SC_DEPLOYMENT_BAW_LICENSE="${LICENSE_PRODUCTION}"
                    break
                    ;;
                *) echo "Invalid option $REPLY";;
            esac
        done
    fi

    if [[ "${PURCHASED_PRODUCT}" == "${PURCHASED_PRODUCT_BAW}" ]]; then
        printf "\n"
        echo -e "\x1B[1mWhich deployment license for IBM Business Automation Workflow do you want to install? (1: : non-production, 2: production): \x1B[0m"

        options=("${LICENSE_NON_PRODUCTION}" "${LICENSE_PRODUCTION}")
        PS3='Enter a valid option [1 to 2]: '

        select opt in "${options[@]}"
        do
            case $opt in
                "${LICENSE_NON_PRODUCTION}")
                    SC_DEPLOYMENT_BAW_LICENSE="${LICENSE_NON_PRODUCTION}"
                    break
                    ;;
                "${LICENSE_PRODUCTION}")
                    SC_DEPLOYMENT_BAW_LICENSE="${LICENSE_PRODUCTION}"
                    break
                    ;;
                *) echo "Invalid option $REPLY";;
            esac
        done
    fi

    success "Selected deployment license for IBM Business Automation Workflow: ${SC_DEPLOYMENT_BAW_LICENSE}"
}

function select_platform(){
    printf "\n"
    echo -e "\x1B[1mSelect the cloud platform to deploy: \x1B[0m"

    options=("Openshift Container Platform (OCP) - Private Cloud" "Other ( Certified Kubernetes Cloud Platform / CNCF)")
    PS3='Enter a valid option [1 to 2]: '

    select opt in "${options[@]}"
    do
        case $opt in
            "Openshift Container Platform (OCP) - Private Cloud")
                PLATFORM_SELECTED="OCP"
                use_entitlement="yes"
                break
                ;;
            "Other ( Certified Kubernetes Cloud Platform / CNCF)")
                PLATFORM_SELECTED="other"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

    success "Selected platform: $PLATFORM_SELECTED"
}

function select_profile_type(){
    printf "\n"
    COLUMNS=12
    echo -e "\x1B[1mSelect the deployment profile (default: small).  See the IBM Business Automation Workflow documentation for details.\x1B[0m"
    options=("small" "medium" "large")

    PS3='Enter a valid option [1 to 3]: '
    select opt in "${options[@]}"
    do
        case $opt in
            "small")
                PROFILE_TYPE="small"
                break
                ;;
            "medium")
                PROFILE_TYPE="medium"
                break
                ;;
            "large")
                PROFILE_TYPE="large"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

    success "Selected profile: $PROFILE_TYPE"
}

function validate_kube_oc_cli(){
    which kubectl &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e  "\x1B[1;31mUnable to locate Kubernetes CLI. You must install it to run this script.\x1B[0m" && \
        exit 1
    fi
    which java &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e  "\x1B[1;31mUnable to locate Java. You must install it to run this script.\x1B[0m" && \
        exit 1
    # else
    #     java -version | grep "Runtime Environment"
    #     if [[ $? -ne 0 ]]; then
    #         echo -e  "\x1B[1;31mUnable to locate java, You must install it to run this script.\x1B[0m" && \
    #         exit 1     
    #     fi
    fi
    which keytool &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e  "\x1B[1;31mUnable to locate keytool. You must add it in \"$PATH\" to run this script.\x1B[0m" && \
        exit 1
    fi

    which openssl &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e  "\x1B[1;31mUnable to locate openssl. You must install it to run this script.\x1B[0m" && \
        exit 1
    fi
}

function check_db2_name_valid(){
    local dbname=$1
    local dbserver=$2
    local keyname=$3
    local num=$4
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    keyname=$(sed -e 's/^"//' -e 's/"$//' <<<"$keyname")

    if [ ${#dbname} -gt 8 ]; then
        if [[ $keyname == "ADP_PROJECT_DB_NAME" ]]; then
            error "The length of DB2 database name: \"dbname\" in the number[$num] of the parameter: \"ADP_PROJECT_DB_NAME\" is more than 8 characters. Input a valid value for it, exiting ..."
        else
            error "The length of DB2 database name: \"dbname\" for the parameter: \"$dbserver.$keyname\" is more than 8 characters. Input a valid value for it, exiting ..."
        fi
        eixt 1
    fi
}

function check_dbserver_name_valid(){
    # check server name is valid or not
    local temp
    local tmp_db_array=()
    local input_servername=$1
    local parameter_name=$2
    input_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$input_servername")
    # get db alias server from DB_SERVER_LIST
    temp=$(prop_db_server_property_file DB_SERVER_LIST)
    temp=$(sed -e 's/^"//' -e 's/"$//' <<<"$temp")
    OIFS=$IFS
    IFS=',' read -ra tmp_db_array <<< "$temp"
    IFS=$OIFS

    if [[ ! (" ${tmp_db_array[@]}" =~ "${input_servername}") ]]; then
        error "The prefix \"$input_servername\" in front of \"$parameter_name\" is not in the definition DB_SERVER_LIST=\"${temp}\". Check the following example to configure"
        echo -e "***************** example *****************"
        echo -e "if DB_SERVER_LIST=\"DBSERVER1\""
        echo -e "You need to change"
        echo -e "<DB_SERVER_NAME>.GCD_DB_NAME=\"GCDDB\""
        echo -e "to"
        echo -e "DBSERVER1.GCD_DB_NAME=\"GCDDB\""
        echo -e "***************** example *****************"
        exit 1
    fi
}

function check_property_file(){
    local empty_value_tag=0

    # check baw_user_profile.property
    value_empty=`grep '="<Required>"' "${USER_PROFILE_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found invalid value(s) \"<Required>\" in property file \"${USER_PROFILE_PROPERTY_FILE}\". Input the correct value."
        empty_value_tag=1
    fi

    # check baw_db_server.property
    value_empty=`grep '="<Required>"' "${DB_SERVER_INFO_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found invalid value(s) \"<Required>\" in property file \"${DB_SERVER_INFO_PROPERTY_FILE}\". Input the correct value."
        empty_value_tag=1
    fi

    # check baw_db_name_user.property
    value_empty=`grep '^<DB_SERVER_NAME>.' "${DB_NAME_USER_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Change prefix \"<DB_SERVER_NAME>\" to assign the database used by the component to a specific database server or instance in the property file \"${DB_NAME_USER_PROPERTY_FILE}\"."
        empty_value_tag=1
    fi

    # check DB_SERVER_LIST contains doc char
    tmp_dbservername=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
    value_empty=`echo "${tmp_dbservername}" | grep '\.' | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found dot character(.) from the value of \"DB_SERVER_LIST\" parameter in property file \"${DB_SERVER_INFO_PROPERTY_FILE}\"."
        empty_value_tag=1
    fi

    # check ADP_PROJECT_DB_SERVER contain <DB_SERVER_NAME>
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        tmp_dbserver="$(prop_db_name_user_property_file ADP_PROJECT_DB_SERVER)"
        tmp_dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbserver")
        value_empty=`echo $tmp_dbserver | grep '<DB_SERVER_NAME>' | wc -l`  >/dev/null 2>&1
        if [ $value_empty -ne 0 ] ; then
            error "Change \"<DB_SERVER_NAME>\" for \"ADP_PROJECT_DB_SERVER\" parameter to assign the database used by the component to a specific database server or instance in the property file \"${DB_NAME_USER_PROPERTY_FILE}\"."
            empty_value_tag=1
        fi
    fi

    value_empty=`grep '="<Required>"' "${DB_NAME_USER_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found invalid value(s) \"<Required>\" in property file \"${DB_NAME_USER_PROPERTY_FILE}\". Input the correct value."
        empty_value_tag=1
    fi

    value_empty=`grep '="<yourpassword>"' "${DB_NAME_USER_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found invalid value(s) \"<yourpassword>\" in property file \"${DB_NAME_USER_PROPERTY_FILE}\". Input the correct value."
        empty_value_tag=1
    fi

    value_empty=`grep '="<youruser1>"' "${DB_NAME_USER_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found invalid value(s) \"<youruser1>\" in property file \"${DB_NAME_USER_PROPERTY_FILE}\". Input the correct value."
        empty_value_tag=1
    fi

    value_empty=`grep '="<Required>"' "${LDAP_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
    if [ $value_empty -ne 0 ] ; then
        error "Found invalid value(s) \"<Required>\" in property file \"${LDAP_PROPERTY_FILE}\". Input the correct value."
        empty_value_tag=1
    fi

    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        value_empty=`grep '="<Required>"' "${EXTERNAL_LDAP_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
        if [ $value_empty -ne 0 ] ; then
            error "Found invalid value(s) \"<Required>\" in property file \"${EXTERNAL_LDAP_PROPERTY_FILE}\". Input the correct value."
            empty_value_tag=1
        fi
    fi

    # check prefix in db property is correct element of DB_SERVER_LIST
    tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$tmp_db_array"
    IFS=$OIFS

    # check DB_NAME_USER_PROPERTY_FILE
    prefix_array=($(grep '=\"' ${DB_NAME_USER_PROPERTY_FILE} | cut -d'=' -f1 | cut -d'.' -f1 | grep -Ev 'ADP_PROJECT_DB_NAME|ADP_PROJECT_DB_SERVER|ADP_PROJECT_DB_USER_NAME|ADP_PROJECT_DB_USER_PASSWORD|ADP_PROJECT_ONTOLOGY'))
    for item in ${prefix_array[*]}
    do
        if [[ ! (" ${db_server_array[@]}" =~ "${item}") ]]; then
            error "The prefix \"$item\" is not in the definition DB_SERVER_LIST=\"${tmp_db_array}\". Check the following example to configure \"${DB_NAME_USER_PROPERTY_FILE}\" again."
            echo -e "***************** example *****************"
            echo -e "if DB_SERVER_LIST=\"DBSERVER1\""
            echo -e "You need to change"
            echo -e "<DB_SERVER_NAME>.GCD_DB_NAME=\"GCDDB\""
            echo -e "to"
            echo -e "DBSERVER1.GCD_DB_NAME=\"GCDDB\""
            echo -e "***************** example *****************"
            empty_value_tag=1
            break
        fi
    done

    # check DB_SERVER_INFO_PROPERTY_FILE
    prefix_array=($(grep '=\"' ${DB_SERVER_INFO_PROPERTY_FILE} | cut -d'=' -f1 | cut -d'.' -f1 | tail -n +2))
    for item in ${prefix_array[*]}
    do
        if [[ ! (" ${db_server_array[@]}" =~ "${item}") ]]; then
            error "The prefix \"$item\" is not in the definition DB_SERVER_LIST=\"${tmp_db_array}\". Check the following example to configure \"${DB_SERVER_INFO_PROPERTY_FILE}\" again."
            echo -e "********************* example *********************"
            echo -e "if DB_SERVER_LIST=\"DBSERVER1\""
            echo -e "You need to change"
            echo -e "<DB_SERVER_NAME>.DATABASE_SERVERNAME=\"samplehost\""
            echo -e "to"
            echo -e "DBSERVER1.DATABASE_SERVERNAME=\"samplehost\""
            echo -e "********************* example *********************"
            empty_value_tag=1
            break
        fi
    done

    # check BAN.LTPA_PASSWORD same as CONTENT.LTPA_PASSWORD
    content_tmp_ltpapwd="$(prop_user_profile_property_file CONTENT.LTPA_PASSWORD)"
    ban_tmp_ltpapwd="$(prop_user_profile_property_file BAN.LTPA_PASSWORD)"
    content_tmp_ltpapwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$content_tmp_ltpapwd")
    ban_tmp_ltpapwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$ban_tmp_ltpapwd")

    if [[ (! -z "$content_tmp_ltpapwd") && (! -z "$ban_tmp_ltpapwd") ]]; then
        if [[ "$ban_tmp_ltpapwd" != "$content_tmp_ltpapwd" ]]; then
            fail "The CONTENT.LTPA_PASSWORD: \"$content_tmp_ltpapwd\" is NOT equal to BAN.LTPA_PASSWORD: \"$ban_tmp_ltpapwd\"."
            echo "The value of CONTENT.LTPA_PASSWORD must be equal to the value of BAN.LTPA_PASSWORD."
            empty_value_tag=1
        fi
    else
        if [[ -z "$content_tmp_ltpapwd" ]]; then
            fail "The CONTENT.LTPA_PASSWORD is empty, it is required one valid value."
            empty_value_tag=1
        fi
        if [[ -z "$ban_tmp_ltpapwd" ]]; then
            fail "The BAN.LTPA_PASSWORD is empty, it is required one valid value."
            empty_value_tag=1
        fi
    fi

    if [[ "$empty_value_tag" == "1" ]]; then
        exit -1
    fi
}

function create_prerequisites() {
    rm -rf $SECRET_FILE_FOLDER
    INFO "Generating YAML template for secret required by BAW on containers deployment based on property file"
    printf "\n"
    wait_msg "Creating YAML template for secret"

    # Create LDAP bind secret
    create_ldap_secret_template
    #  replace ldap user
    tmp_dbuser="$(prop_ldap_property_file LDAP_BIND_DN)"
    ${SED_COMMAND} "s|\"<LDAP_BIND_DN>\"|\"$tmp_dbuser\"|g" ${LDAP_SECRET_FILE}

    tmp_dbuserpwd="$(prop_ldap_property_file LDAP_BIND_DN_PASSWORD)"
    ${SED_COMMAND} "s|\"<LDAP_PASSWORD>\"|\"$tmp_dbuserpwd\"|g" ${LDAP_SECRET_FILE}

    # Create LDAP bind secret for external share
    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        create_ext_ldap_secret_template
        #  replace ldap user
        tmp_dbuser="$(prop_ext_ldap_property_file LDAP_BIND_DN)"
        ${SED_COMMAND} "s|\"<LDAP_BIND_DN>\"|\"$tmp_dbuser\"|g" ${EXT_LDAP_SECRET_FILE}

        tmp_dbuserpwd="$(prop_ext_ldap_property_file LDAP_BIND_DN_PASSWORD)"
        ${SED_COMMAND} "s|\"<LDAP_PASSWORD>\"|\"$tmp_dbuserpwd\"|g" ${EXT_LDAP_SECRET_FILE}
    fi

    # Create FNCM secret
    wait_msg "Creating ibm-fncm-secret secret YAML template"
    # get server/instance for GCD
    tmp_gcd_db_servername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"
    check_dbserver_name_valid $tmp_gcd_db_servername "GCD_DB_USER_NAME"
    
    if [[ $DB_TYPE != "oracle" ]]; then
        tmp_dbname="$(prop_db_name_user_property_file GCD_DB_NAME)"
    else
        tmp_dbname="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
    fi

    create_fncm_secret_template $tmp_gcd_db_servername

    # replace appLoginUsername/appLoginPassword for FNCM secret
    tmp_appuser="$(prop_user_profile_property_file CONTENT.APPLOGIN_USER)"
    tmp_apppwd="$(prop_user_profile_property_file CONTENT.APPLOGIN_PASSWORD)"
    ${SED_COMMAND} "s|appLoginUsername:.*|appLoginUsername: \"$tmp_appuser\"|g" ${FNCM_SECRET_FILE}
    ${SED_COMMAND} "s|appLoginPassword:.*|appLoginPassword: \"$tmp_apppwd\"|g" ${FNCM_SECRET_FILE}

    # replace ltpaPassword/keystorePassword for FNCM secret
    tmp_ltpapwd="$(prop_user_profile_property_file CONTENT.LTPA_PASSWORD)"
    tmp_kestorepwd="$(prop_user_profile_property_file CONTENT.KEYSTORE_PASSWORD)"
    ${SED_COMMAND} "s|ltpaPassword:.*|ltpaPassword: \"$tmp_ltpapwd\"|g" ${FNCM_SECRET_FILE}
    ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: \"$tmp_kestorepwd\"|g" ${FNCM_SECRET_FILE}

    #  replace gcddb user
    tmp_dbuser="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
    ${SED_COMMAND} "s|\"<GCD_DB_USER_NAME>\"|$tmp_dbuser|g" ${FNCM_SECRET_FILE}

    # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
    if [[ $DB_TYPE = "postgresql" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_gcd_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
        tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    fi

    if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
        ${SED_COMMAND} '/^  gcdDBPassword/d' ${FNCM_SECRET_FILE}
    else
        tmp_dbuserpwd="$(prop_db_name_user_property_file GCD_DB_USER_PASSWORD)"
        ${SED_COMMAND} "s|\"<GCD_DB_USER_PASSWORD>\"|$tmp_dbuserpwd|g" ${FNCM_SECRET_FILE}
    fi

    nl=$'\n' # fix sed issue on Mac, DO NOT change the script format
   
    # Add baw runtime OS
    for i in "${!BAW_STD_OS_ARR[@]}"; do
        # get server/instance for OS
        tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name ${BAW_STD_OS_ARR[i]}_DB_USER_NAME)"
        tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
        check_dbserver_name_valid $tmp_os_db_servername "${BAW_STD_OS_ARR[i]}_DB_USER_NAME"

        # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
        if [[ $DB_TYPE = "postgresql" ]]; then
            tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_os_db_servername.POSTGRESQL_SSL_CLIENT_SERVER)")
            tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        fi

        tmp_dbuser="$(prop_db_name_user_property_file ${BAW_STD_OS_ARR[i]}_DB_USER_NAME)"
        tmp_val=$(echo ${BAW_STD_OS_ARR[i]} | tr '[:upper:]' '[:lower:]')
        tmp_dbuserpwd="$(prop_db_name_user_property_file ${BAW_STD_OS_ARR[i]}_DB_USER_PASSWORD)"
        
        if [[ "$machine" == "Mac" ]]; then
            # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
            if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
            ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  ${tmp_val}DBPassword: $tmp_dbuserpwd\\${nl}" ${FNCM_SECRET_FILE}
            fi
            ${SED_COMMAND} "/^  osDBPassword: .*/a\ 
  ${tmp_val}DBUsername: $tmp_dbuser\\${nl}" ${FNCM_SECRET_FILE}
        else
            # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
            if [[ ! ($tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y") ]]; then
            ${SED_COMMAND} "/^  osDBPassword: .*/a\  ${tmp_val}DBPassword: $tmp_dbuserpwd" ${FNCM_SECRET_FILE}
            fi
            ${SED_COMMAND} "/^  osDBPassword: .*/a\  ${tmp_val}DBUsername: $tmp_dbuser" ${FNCM_SECRET_FILE}
        fi
    done
       
    ${SED_COMMAND} '/^  osDBUsername/d' ${FNCM_SECRET_FILE}
    ${SED_COMMAND} '/^  osDBPassword/d' ${FNCM_SECRET_FILE}
    success "Created ibm-fncm-secret secret YAML template\n"

    # Create BAN secret
    wait_msg "Creating ibm-ban-secret secret YAML template"

    # get server/instance for ICN
    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ICN_DB_USER_NAME)"
    tmp_dbservername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbservername")
    check_dbserver_name_valid $tmp_dbservername "ICN_DB_USER_NAME"

    # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
    if [[ $DB_TYPE = "postgresql" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
        tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    fi

    if [[ $DB_TYPE != "oracle" ]]; then
        tmp_dbname="$(prop_db_name_user_property_file ICN_DB_NAME)"
    else
        tmp_dbname="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
    fi

    create_ban_secret_template $tmp_dbname $tmp_dbservername

    # replace appLoginUsername/appLoginPassword for BAN secret
    tmp_appuser="$(prop_user_profile_property_file BAN.APPLOGIN_USER)"
    tmp_apppwd="$(prop_user_profile_property_file BAN.APPLOGIN_PASSWORD)"
    ${SED_COMMAND} "s|appLoginUsername:.*|appLoginUsername: \"$tmp_appuser\"|g" ${BAN_SECRET_FILE}
    ${SED_COMMAND} "s|appLoginPassword:.*|appLoginPassword: \"$tmp_apppwd\"|g" ${BAN_SECRET_FILE}

    # replace ltpaPassword/keystorePassword for BAN secret
    tmp_ltpapwd="$(prop_user_profile_property_file BAN.LTPA_PASSWORD)"
    tmp_kestorepwd="$(prop_user_profile_property_file BAN.KEYSTORE_PASSWORD)"
    ${SED_COMMAND} "s|ltpaPassword:.*|ltpaPassword: \"$tmp_ltpapwd\"|g" ${BAN_SECRET_FILE}
    ${SED_COMMAND} "s|keystorePassword:.*|keystorePassword: \"$tmp_kestorepwd\"|g" ${BAN_SECRET_FILE}

    # replace jmailUserName/jmailPassword for BAN secret
    tmp_jmailuser="$(prop_user_profile_property_file BAN.JMAIL_USER_NAME)"
    tmp_jmailpwd="$(prop_user_profile_property_file BAN.JMAIL_USER_PASSWORD)"

    tmp_jmailuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_jmailuser")
    tmp_jmailpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_jmailpwd")

    if [[ ! ($tmp_jmailuser == "<Optional>" || $tmp_jmailpwd == "<Optional>") ]]; then
        ${SED_COMMAND} "s|jMailUsername:.*|jMailUsername: \"$tmp_jmailuser\"|g" ${BAN_SECRET_FILE}
        ${SED_COMMAND} "s|jMailPassword:.*|jMailPassword: \"$tmp_jmailpwd\"|g" ${BAN_SECRET_FILE}
    else
        ${SED_COMMAND} "s|jMailUsername:.*|jMailUsername: \"\"|g" ${BAN_SECRET_FILE}
        ${SED_COMMAND} "s|jMailPassword:.*|jMailPassword: \"\"|g" ${BAN_SECRET_FILE}
    fi

    #  replace icndb user
    tmp_dbuser="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
    ${SED_COMMAND} "s|\"<ICN_DB_USER_NAME>\"|$tmp_dbuser|g" ${BAN_SECRET_FILE}

    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
    if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
        ${SED_COMMAND} '/^  navigatorDBPassword/d' ${BAN_SECRET_FILE}
    else
        tmp_dbuserpwd="$(prop_db_name_user_property_file ICN_DB_USER_PASSWORD)"
        ${SED_COMMAND} "s|\"<ICNDB_PASSWORD>\"|$tmp_dbuserpwd|g" ${BAN_SECRET_FILE}
    fi

    success "Created ibm-ban-secret secret YAML template\n"

    # create baw-std secret 
    # get server/instance for baw-std
    if [[ $DB_TYPE != "oracle" ]]; then
        tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
        check_dbserver_name_valid $tmp_dbservername "BAW_RUNTIME_DB_USER_NAME"
        tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
    else
        tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
    fi
    create_baw_runtime_secret_template $tmp_dbname $tmp_dbservername

    # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
    if [[ $DB_TYPE = "postgresql" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
        tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    fi

    #  replace baw db user
    tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
    ${SED_COMMAND} "s|dbUser: .*|dbUser: $tmp_dbuser|g" ${BAW_RUNTIME_SECRET_FILE}

    tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
    ${SED_COMMAND} "s|password: .*|password: $tmp_dbuserpwd|g" ${BAW_RUNTIME_SECRET_FILE}

    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
    if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
        ${SED_COMMAND} '/^  password/d' ${BAW_RUNTIME_SECRET_FILE}
    else
        tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
        ${SED_COMMAND} "s|password: .*|password: $tmp_dbuserpwd|g" ${BAW_RUNTIME_SECRET_FILE}
    fi

    # Create ums secret 
    # get server/instance for ums
    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name UMS_DB_USER_NAME)"
    check_dbserver_name_valid $tmp_dbservername "UMS_DB_USER_NAME"
    if [[ $DB_TYPE != "oracle" ]]; then
        tmp_dbname="$(prop_db_name_user_property_file UMS_DB_NAME)"
    else
        tmp_dbname="$(prop_db_name_user_property_file UMS_DB_USER_NAME)"
    fi 
    create_ums_secret_template $tmp_dbname $tmp_dbservername

    # Get PostgreSQL POSTGRESQL_SSL_CLIENT_SERVER
    if [[ $DB_TYPE = "postgresql" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $tmp_dbservername.POSTGRESQL_SSL_CLIENT_SERVER)")
        tmp_postgresql_client_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    fi

    #  replace ums oauth db user
    tmp_dbuser="$(prop_db_name_user_property_file UMS_DB_USER_NAME)"
    ${SED_COMMAND} "s|oauthDBUser: .*|oauthDBUser: $tmp_dbuser|g" ${UMS_SECRET_FILE}

    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
    if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
        ${SED_COMMAND} '/^  oauthDBPassword/d' ${UMS_SECRET_FILE}
    else
        tmp_dbuserpwd="$(prop_db_name_user_property_file UMS_DB_USER_PASSWORD)"
        ${SED_COMMAND} "s|oauthDBPassword: .*|oauthDBPassword: $tmp_dbuserpwd|g" ${UMS_SECRET_FILE}
    fi

    #  replace ums teamworks db user
    tmp_dbuser="$(prop_db_name_user_property_file UMS_DB_USER_NAME)"
    ${SED_COMMAND} "s|tsDBUser: .*|tsDBUser: $tmp_dbuser|g" ${UMS_SECRET_FILE}

    tmp_dbuserpwd="$(prop_db_name_user_property_file UMS_DB_USER_PASSWORD)"
    ${SED_COMMAND} "s|tsDBPassword: .*|tsDBPassword: $tmp_dbuserpwd|g" ${UMS_SECRET_FILE}

    # when POSTGRESQL_SSL_CLIENT_SERVER is true, remove pwd from secret
    if [[ $tmp_postgresql_client_flag == "true" || $tmp_postgresql_client_flag == "yes" || $tmp_postgresql_client_flag == "y" ]]; then
        ${SED_COMMAND} '/^  tsDBPassword/d' ${UMS_SECRET_FILE}
    else
        tmp_dbuserpwd="$(prop_db_name_user_property_file UMS_DB_USER_PASSWORD)"
        ${SED_COMMAND} "s|tsDBPassword: .*|tsDBPassword: $tmp_dbuserpwd|g" ${UMS_SECRET_FILE}
    fi

    tmp_admuser="$(prop_user_profile_property_file UMS.ADMIN_USER)"
    tmp_admpwd="$(prop_user_profile_property_file UMS.ADMIN_PASSWORD)"
    ${SED_COMMAND} "s|adminUser:.*|adminUser: \"$tmp_admuser\"|g" ${UMS_SECRET_FILE}
    ${SED_COMMAND} "s|adminPassword:.*|adminPassword: \"$tmp_admpwd\"|g" ${UMS_SECRET_FILE}   

    # Create secret for DB SSL enabled
    # Put DB server/instance into array
    tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$tmp_db_array"
    IFS=$OIFS

    for item in "${db_server_array[@]}"; do

        # DB SSL Enabled
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SSL_ENABLE)")
        tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        while true; do
            case "$tmp_flag" in
            "true"|"yes"|"y")
                create_cp4a_db_ssl_template $item

                #  replace secret name
                tmp_name="$(prop_db_server_property_file $item.DATABASE_SSL_SECRET_NAME)"
                tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
                ${SED_COMMAND} "s|<cp4a-db-ssl-secret-name>|$tmp_name|g" ${CP4A_DB_SSL_SECRET_FILE}

                #  replace secret file folder
                tmp_name="$(prop_db_server_property_file $item.DATABASE_SSL_CERT_FILE_FOLDER)"
                if [[ -z $tmp_name || -n $tmp_name || $tmp_name == "" ]]; then
                    tmp_name=$DB_SSL_CERT_FOLDER/$item
                fi
                ${SED_COMMAND} "s|<cp4a-db-crt-file-in-local>|$tmp_name|g" ${CP4A_DB_SSL_SECRET_FILE}
                
                # create oracle-wallet-sso-secret-for-$item for AE/APP
                if [[ $DB_TYPE == "oracle" && (" ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "application" || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer") ]]; then
                    create_app_engine_oracle_sso_secret_template $item
                    #  replace secret name
                    tmp_name="$(prop_db_server_property_file $item.ORACLE_SSO_WALLET_SECRET_NAME)"
                    tmp_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_name")
                    ${SED_COMMAND} "s|<your-oracle-sso-secret-name>|$tmp_name|g" ${APP_ORACLE_SSO_SSL_SECRET_FILE}

                    #  replace secret file folder
                    tmp_name="$(prop_db_server_property_file $item.ORACLE_SSO_WALLET_CERT_FOLDER)"
                    if [[ -z $tmp_name || -n $tmp_name || $tmp_name == "" ]]; then
                        tmp_name=$DB_SSL_CERT_FOLDER/$item
                    fi
                    ${SED_COMMAND} "s|<your-oracle-sso-wallet-file-path>|$tmp_name|g" ${APP_ORACLE_SSO_SSL_SECRET_FILE}
                fi
                break
                ;;
            "false"|"no"|"n"|"")
                break
                ;;
            esac
        done
    done

    # LDAP SSL Enabled
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ldap_property_file LDAP_SSL_ENABLED)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
    
    while true; do
        case "$tmp_flag" in
        "true"|"yes"|"y")
            create_cp4a_ldap_ssl_secret_template
            #  replace ldap secret name
            tmp_ldap_secret_name="$(prop_ldap_property_file LDAP_SSL_SECRET_NAME)"
            tmp_ldap_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldap_secret_name")
            if [[ -z $tmp_ldap_secret_name || -n $tmp_ldap_secret_name || $tmp_ldap_secret_name != "" ]]; then
                ${SED_COMMAND} "s|<cp4a-ldap_ssl_secret_name>|$tmp_ldap_secret_name|g" ${CP4A_LDAP_SSL_SECRET_FILE}
            fi

            #  replace secret file folder
            tmp_name="$(prop_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
            if [[ -z $tmp_name || -n $tmp_name || $tmp_name == "" ]]; then
                tmp_name=$LDAP_SSL_CERT_FOLDER
            fi
            ${SED_COMMAND} "s|<cp4a-ldap-crt-file-in-local>|$tmp_name|g" ${CP4A_LDAP_SSL_SECRET_FILE}
            break
            ;;
        "false"|"no"|"n"|"")
            break
            ;;
        esac
    done
    
    # External LDAP SSL Enabled
    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ext_ldap_property_file LDAP_SSL_ENABLED)")
        tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        
        while true; do
            case "$tmp_flag" in
            "true"|"yes"|"y")
                create_cp4a_ext_ldap_ssl_secret_template
                #  replace ldap secret name
                tmp_ldap_secret_name="$(prop_ext_ldap_property_file LDAP_SSL_SECRET_NAME)"
                tmp_ldap_secret_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldap_secret_name")
                if [[ -z $tmp_ldap_secret_name || -n $tmp_ldap_secret_name || $tmp_ldap_secret_name != "" ]]; then
                    ${SED_COMMAND} "s|<cp4a-ldap_ssl_secret_name>|$tmp_ldap_secret_name|g" ${CP4A_EXT_LDAP_SSL_SECRET_FILE}
                fi

                #  replace secret file folder
                tmp_name="$(prop_ext_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
                if [[ -z $tmp_name || -n $tmp_name || $tmp_name == "" ]]; then
                    tmp_name=$EXT_LDAP_SSL_CERT_FOLDER
                fi
                ${SED_COMMAND} "s|<cp4a-ldap-crt-file-in-local>|$tmp_name|g" ${CP4A_EXT_LDAP_SSL_SECRET_FILE}
                break
                ;;
            "false"|"no"|"n"|"")
                break
                ;;
            esac
        done
    fi
    tips ""
    msgB "* Enter the <Required> values in the YAML templates for the secrets under $SECRET_FILE_FOLDER"

    # Show which certificate file should be copied into which folder 
    tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$tmp_db_array"
    IFS=$OIFS

    for item in "${db_server_array[@]}"; do
        # DB SSL Enabled
        tmp_ssl_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SSL_ENABLE)")
        tmp_ssl_flag=$(echo $tmp_ssl_flag | tr '[:upper:]' '[:lower:]')
        # echo "tmp_flag: $tmp_flag"; sleep 10
        while true; do
            case "$tmp_ssl_flag" in
            "true"|"yes"|"y")
                tmp_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SSL_CERT_FILE_FOLDER)")
                if [[ $DB_TYPE == "oracle" ]]; then
                    tmp_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_oracle_server_property_file $item.ORACLE_JDBC_URL)")
                else
                    tmp_dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SERVERNAME)")
                fi
                if [[ $DB_TYPE == "postgresql" ]]; then
                    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.POSTGRESQL_SSL_CLIENT_SERVER)")
                    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
                    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
                        msgB "* You enabled PostgreSQL database with both server and client authentication. Get \"<your-server-certification: server.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from your local or remote database server \"$tmp_dbserver\", and copy them into folder \"$tmp_folder\" before you create the secret for the PostgreSQL database SSL"
                    elif [[ $tmp_flag == "false" || $tmp_flag == "no" || $tmp_flag == "n" || $tmp_flag == "" ]]; then
                        msgB "* You enabled PostgreSQL database with server-only authentication. Get \"<your-server-certification: db-cert.crt>\" from the remote database server \"$tmp_dbserver\", and copy it into the folder \"$tmp_folder\" before you create the secret for the PostgreSQL database SSL"
                    fi
                else
                    if [[ $DB_TYPE == "oracle" ]]; then
                        msgB "* Get the certificate file \"db-cert.crt\" from the remote database server that uses the JDBC URL: \"$tmp_db_jdbc_url\", and copy it into the folder \"$tmp_folder\" before you create the Kubernetes secret for the database SSL"
                    else
                        msgB "* Get the certificate file \"db-cert.crt\" from the remote database server \"$tmp_dbserver\", and copy it into the folder \"$tmp_folder\" before you create the Kubernetes secret for the database SSL"
                    fi
                fi
                # check AE/APP for oracle
                if [[ $DB_TYPE == "oracle" && (" ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "application" || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer") ]]; then
                    tmp_folder=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.ORACLE_SSO_WALLET_CERT_FOLDER)")
                    if [[ ! -z $tmp_folder || $tmp_folder != "" ]]; then
                        msgB "* Get the wallet SSO file \"cwallet.sso\" from your local or remote database server that uses the JDBC URL: \"$tmp_db_jdbc_url\", and copy this wallet SSO file into the folder \"$tmp_folder\" before you create the secret for the oracle database SSL"
                    fi
                fi
                break
                ;;
            "false"|"no"|"n"|"")
                break
                ;;
            esac
        done
    done

    # LDAP: Show which certificate file should be copy into which folder 
    tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ldap_property_file LDAP_SSL_ENABLED)")
    tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')

    if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
        tmp_folder="$(prop_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
        tmp_ldapserver="$(prop_ldap_property_file LDAP_SERVER)"
        msgB "* Get the \"ldap-cert.crt\" from the remote LDAP server \"$tmp_ldapserver\", and copy it into the folder \"$tmp_folder\" before create the Kubernetes secret for the LDAP SSL"
    fi

    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        tmp_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_ext_ldap_property_file LDAP_SSL_ENABLED)")
        tmp_flag=$(echo $tmp_flag | tr '[:upper:]' '[:lower:]')
        if [[ $tmp_flag == "true" || $tmp_flag == "yes" || $tmp_flag == "y" ]]; then
            tmp_folder="$(prop_ext_ldap_property_file LDAP_SSL_CERT_FILE_FOLDER)"
            tmp_ldapserver="$(prop_ext_ldap_property_file LDAP_SERVER)"
            msgB "* You enabled external LDAP SSL, so get the \"external-ldap-cert.crt\" from the remote LDAP server \"$tmp_ldapserver\", and copy it into the folder \"$tmp_folder\" before you create the secret for the external LDAP SSL"
        fi
    fi

    # show postgresql ssl setting tip for db secret
    if [[ $DB_TYPE == "postgresql" ]]; then
        tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
        tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
        OIFS=$IFS
        IFS=',' read -ra db_server_array <<< "$tmp_db_array"
        IFS=$OIFS

        for item in "${db_server_array[@]}"; do
            postgresql_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.POSTGRESQL_SSL_CLIENT_SERVER)")
            postgresql_server=$(sed -e 's/^"//' -e 's/"$//' <<<"$(prop_db_server_property_file $item.DATABASE_SERVERNAME)")
            tmp_flag=$(echo $postgresql_flag | tr '[:upper:]' '[:lower:]')
            if [[ $tmp_flag == "yes" || $tmp_flag == "true" || $tmp_flag == "y"  ]]; then
                CP4A_DB_SSL_SECRET_FILE_TMP=${DB_SSL_SECRET_FOLDER}/$item/ibm-cp4ba-db-ssl-cert-secret-for-${item}.sh
                msgB "* Found \"POSTGRESQL_SSL_CLIENT_SERVER\" is \"$postgresql_flag\" for database server \"$postgresql_server\" in property file \"${DB_SERVER_INFO_PROPERTY_FILE}\".\n  Set the \"sslmode\" parameter in the script \"${CP4A_DB_SSL_SECRET_FILE_TMP}\" to select which sslmode=[require|verify-ca|verify-full] that you want it."
            fi
        done
    fi

    msgB "* You can use this shell script to create the secret automatically: $CREATE_SECRET_SCRIPT_FILE"
    msgB "* Create the databases and Kubernetes secrets manually based on your modified \"DB SQL statement file\" and \"YAML template for secret\".\n* And then run \"baw-prerequisites.sh -m validate\" command to verify that the databases and secrets are created correctly"
}

function create_temp_property_file(){

    # Keep pattern_joined value in temp property file
    mkdir -p $TEMP_FOLDER >/dev/null 2>&1
    > $TEMPORARY_PROPERTY_FILE
    
    # save platform
    echo "PLATFORM_SELECTED=$PLATFORM_SELECTED" >> ${TEMPORARY_PROPERTY_FILE}

    # save ldap type
    echo "LDAP_TYPE=$LDAP_TYPE" >> ${TEMPORARY_PROPERTY_FILE}
    
    # save db type
    echo "DB_TYPE=$DB_TYPE" >> ${TEMPORARY_PROPERTY_FILE}
    # save content_os_number
    # msgB "$content_os_number"; sleep 300
    if (( content_os_number > 0 )); then
        echo "CONTENT_OS_NUMBER=$content_os_number" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "CONTENT_OS_NUMBER=" >> ${TEMPORARY_PROPERTY_FILE}
    fi
    # save content_os_number db_server_number
    if (( db_server_number > 0 )); then
        echo "DB_SERVER_NUMBER=$db_server_number" >> ${TEMPORARY_PROPERTY_FILE}
    else
        echo "DB_SERVER_NUMBER=" >> ${TEMPORARY_PROPERTY_FILE}
    fi
    # save external ldap flag
    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        echo "EXTERNAL_LDAP_ENABLED=Yes" >> ${TEMPORARY_PROPERTY_FILE}
    fi
}

function create_property_file(){
    if [[ $DB_TYPE == "oracle" ]]; then
        local DB_SERVER_PREFIX="<DB_INSTANCE_NAME>"
    else
        local DB_SERVER_PREFIX="<DB_SERVER_NAME>"
    fi
    printf "\n"

    if [[ -d "$PROPERTY_FILE_FOLDER" ]]; then
        tmp_property_file_dir="${PROPERTY_FILE_FOLDER_BAK}_$(date +%Y-%m-%d-%H:%M:%S)"
        mkdir -p "$tmp_property_file_dir" >/dev/null 2>&1
        ${COPY_CMD} -rf "${PROPERTY_FILE_FOLDER}" "${tmp_property_file_dir}"
    fi

    rm -rf $PROPERTY_FILE_FOLDER >/dev/null 2>&1
    mkdir -p $PROPERTY_FILE_FOLDER >/dev/null 2>&1
    mkdir -p $LDAP_SSL_CERT_FOLDER >/dev/null 2>&1
    mkdir -p $DB_SSL_CERT_FOLDER >/dev/null 2>&1
    INFO "Creating database and LDAP property files"

    wait_msg "Creating DB Server property file"
    # Assumption: all FNCM DB use same database server in phase1
    > ${DB_SERVER_INFO_PROPERTY_FILE}

    # For mutiple db server/instance in phase2
    # get value from db_server_array for db server/instance 
    delim=""
    db_server_joined=""
    for ((j=0;j<${db_server_number};j++)); do
        db_server_joined="$db_server_joined$delim${db_server_array[j]}"
        delim=","
    done
    tip="## Input the value for the multiple database server/instance name. This key supports comma-separated lists. ##"
    echo $tip >> ${DB_SERVER_INFO_PROPERTY_FILE}
    tip="## (NOTES: The value (CAN NOT CONTAIN DOT CHARACTER) is the alias name for the database server/instance; it is not the real database server/instance host name.) ##"
    echo $tip >> ${DB_SERVER_INFO_PROPERTY_FILE}
    echo "DB_SERVER_LIST=\"$db_server_joined\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
    echo "" >> ${DB_SERVER_INFO_PROPERTY_FILE}

    # Put DB server/instance into array
    tmp_db_array=$(prop_db_server_property_file DB_SERVER_LIST)
    tmp_db_array=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_db_array")
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$tmp_db_array"
    IFS=$OIFS

    for item in "${db_server_array[@]}"; do
        item_tmp=$(echo $item| tr '[:upper:]' '[:lower:]')
        mkdir -p "${DB_SSL_CERT_FOLDER}/$item" >/dev/null 2>&1
        echo "#####################################################################################################" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "## Property for Database Server \"$item\" required by Business Automation Workflow on ${DB_TYPE}  ##" >> ${DB_SERVER_INFO_PROPERTY_FILE}
        echo "#####################################################################################################" >> ${DB_SERVER_INFO_PROPERTY_FILE}

        for i in "${!GCDDB_COMMON_PROPERTY[@]}"; do
            if [[ $DB_TYPE == "db2" && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_USER_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "ORACLE_JDBC_URL" ]]; then
                echo "${GCDDB_PROPERTY_COMMENTS[i]}" >> ${DB_SERVER_INFO_PROPERTY_FILE}
                echo "$item.${GCDDB_COMMON_PROPERTY[i]}=\"\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
                echo "" >> "${DB_SERVER_INFO_PROPERTY_FILE}"
            elif [[ $DB_TYPE == "oracle" && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_USER_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "DATABASE_SERVERNAME" && ${GCDDB_COMMON_PROPERTY[i]} != "DATABASE_PORT" && ${GCDDB_COMMON_PROPERTY[i]} != "HADR_STANDBY_SERVERNAME" && ${GCDDB_COMMON_PROPERTY[i]} != "HADR_STANDBY_PORT" ]]; then
                echo "${GCDDB_PROPERTY_COMMENTS[i]}" >> ${DB_SERVER_INFO_PROPERTY_FILE}
                echo "$item.${GCDDB_COMMON_PROPERTY[i]}=\"\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
                echo "" >> "${DB_SERVER_INFO_PROPERTY_FILE}"
            elif [[ ($DB_TYPE == "postgresql"  || $DB_TYPE == "sqlserver") && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "GCD_DB_USER_NAME" && ${GCDDB_COMMON_PROPERTY[i]} != "HADR_STANDBY_SERVERNAME" && ${GCDDB_COMMON_PROPERTY[i]} != "HADR_STANDBY_PORT" && ${GCDDB_COMMON_PROPERTY[i]} != "ORACLE_JDBC_URL" ]]; then
                echo "${GCDDB_PROPERTY_COMMENTS[i]}" >> ${DB_SERVER_INFO_PROPERTY_FILE}
                echo "$item.${GCDDB_COMMON_PROPERTY[i]}=\"\"" >> ${DB_SERVER_INFO_PROPERTY_FILE}
                echo "" >> "${DB_SERVER_INFO_PROPERTY_FILE}"
            fi
        done
        # set default value
        ${SED_COMMAND} "s|$item.DATABASE_TYPE=\"\"|$item.DATABASE_TYPE=\"${DB_TYPE}\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        ${SED_COMMAND} "s|$item.DATABASE_SSL_CERT_FILE_FOLDER=\"\"|$item.DATABASE_SSL_CERT_FILE_FOLDER=\"${DB_SSL_CERT_FOLDER}/$item\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        ${SED_COMMAND} "s|<DB_SSL_CERT_FOLDER>|${DB_SSL_CERT_FOLDER}/$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        ${SED_COMMAND} "s|$item.DATABASE_SSL_ENABLE=\"\"|$item.DATABASE_SSL_ENABLE=\"True\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        ${SED_COMMAND} "s|$item.DATABASE_SSL_SECRET_NAME=\"\"|$item.DATABASE_SSL_SECRET_NAME=\"ibm-cp4ba-db-ssl-secret-for-${item_tmp}\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}

        # set postgreSQL client and server authentication by default for 22.0.2 (All components support client/server auth)
        if [[ $DB_TYPE == "postgresql" ]]; then
            # fix sed issue on Mac, DO NOT format code
            nl=$'\n' # fix sed issue on Mac, DO NOT change the script format
            if [[ "$machine" == "Mac" ]]; then
                ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE=.*/a\ 
element_val.POSTGRESQL_SSL_CLIENT_SERVER=\"True\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE=.*/a\ 
## Whether your PostgreSQL database enables server only or both server and client authentication. Default value is \"True\" for enabling both server and client authentication, \"False\" is for enabling server-only authentication.\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
            else
                ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE=.*/a\element_val.POSTGRESQL_SSL_CLIENT_SERVER=\"True\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE=.*/a\## Whether your PostgreSQL database enables server only or both server and client authentication. Default value is \"True\" for enabling both server and client authentication, \"False\" is for enabling server-only authentication." ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.DATABASE_SSL_ENABLE=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}
            fi
            ${SED_COMMAND} "s|element_val|$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
        fi
        # insert comment for DATABASE_SSL_CERT_FILE_FOLDER when POSTGRESQL_SSL_CLIENT_SERVER=Yes
        if [[ $DB_TYPE == "postgresql" ]]; then
            # fix sed issue on Mac, DO NOT format code
            nl=$'\n' # fix sed issue on Mac, DO NOT change the script format
            if [[ "$machine" == "Mac" ]]; then
                ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER=.*/i\ 
## If POSTGRESQL_SSL_CLIENT_SERVER is \"True\" and DATABASE_SSL_ENABLE is \"True\", get \"<your-server-certification: server.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from server and client, and copy into this directory.Default value is \"${DB_SSL_CERT_FOLDER}/$item\".\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER=.*/i\ 
## If POSTGRESQL_SSL_CLIENT_SERVER is \"False\" and DATABASE_SSL_ENABLE is \"True\", get the SSL certificate file (rename db-cert.crt) from server and then copy into this directory.Default value is \"${DB_SSL_CERT_FOLDER}/$item\".\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
            else
                ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER=.*/i\## If POSTGRESQL_SSL_CLIENT_SERVER is \"True\" and DATABASE_SSL_ENABLE is \"True\", get \"<your-server-certification: server.crt>\" \"<your-client-certification: client.crt>\" \"<your-client-key: client.key>\" from server and client, and copy into this directory.Default value is \"${DB_SSL_CERT_FOLDER}/$item\"." ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.DATABASE_SSL_CERT_FILE_FOLDER=.*/i\## If POSTGRESQL_SSL_CLIENT_SERVER is \"False\" and DATABASE_SSL_ENABLE is \"True\", get the SSL certificate file (rename db-cert.crt) from server and then copy into this directory.Default value is \"${DB_SSL_CERT_FOLDER}/$item\"." ${DB_SERVER_INFO_PROPERTY_FILE}
            fi
            ${SED_COMMAND} "s|element_val|$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            ${SED_COMMAND} '/## If enabled DB SSL/d' ${DB_SERVER_INFO_PROPERTY_FILE}
        fi

        # set oracle_url_without_wallet_directory for AE/APP
        if [[ $DB_TYPE == "oracle" ]]; then
            # fix sed issue on Mac, DO NOT format code
            nl=$'\n' # fix sed issue on Mac, DO NOT change the script format
            if [[ "$machine" == "Mac" ]]; then
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
element_val.ORACLE_SSO_WALLET_CERT_FOLDER=\"${DB_SSL_CERT_FOLDER}//$item\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
## Get the wallet SSO file cwallet.sso on your local or remote database server. Copy this wallet SSO file to \"${DB_SSL_CERT_FOLDER}//$item\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
element_val.ORACLE_SSO_WALLET_SECRET_NAME=\"oracle-wallet-sso-secret-for-$item_tmp\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
## Secret name for wallet SSO file, only for Application Engine or Playback Server with oracle database and ssl enabled.\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
element_val.ORACLE_URL_WITH_WALLET_DIRECTORY=\"(DESCRIPTION=(ADDRESS=(PROTOCOL=tcps)(HOST=<your-oracle-database-hostname>)(PORT=2484))(CONNECT_DATA=(SERVICE_NAME=<your-oracle-database-service-name>))(SECURITY=(SSL_SERVER_DN_MATCH=FALSE)(MY_WALLET_DIRECTORY=/shared/resources/oracle/wallet)))\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
## Required only by Application Engine or Application Playback Server when type is Oracle and SSL is enabled. The format must be purely oracle descriptor like: (DESCRIPTION=(ADDRESS=(PROTOCOL=tcps)(HOST=<your-oracle-database-hostname>)(PORT=2484))(CONNECT_DATA=(SERVICE_NAME=<your-oracle-database-service-name>))(SECURITY=(SSL_SERVER_DN_MATCH=FALSE)(MY_WALLET_DIRECTORY=/shared/resources/oracle/wallet)))\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
element_val.ORACLE_URL_WITHOUT_WALLET_DIRECTORY=\"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=<your database host/IP>)(PORT=<your database port>))(CONNECT_DATA=(SERVICE_NAME=<your oracle service name>)))\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
## Required only by Application Engine or Application Playback Server when type is Oracle, both ssl and non-ssl. The format must be purely oracle descriptor like: (DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=<your database host/IP>)(PORT=<your database port>))(CONNECT_DATA=(SERVICE_NAME=<your oracle service name>)))\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "s|element_val|$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            else
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\element_val.ORACLE_SSO_WALLET_CERT_FOLDER=\"${DB_SSL_CERT_FOLDER}/$item\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\## Get the wallet SSO file cwallet.sso on your local or remote database server. Copy this wallet SSO file to \"${DB_SSL_CERT_FOLDER}/$item\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\element_val.ORACLE_SSO_WALLET_SECRET_NAME=\"oracle-wallet-sso-secret-for-$item_tmp\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\## Secret name for wallet SSO file, only for Application Engine or Playback Server with oracle database and ssl enabled." ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\element_val.ORACLE_URL_WITH_WALLET_DIRECTORY=\"(DESCRIPTION=(ADDRESS=(PROTOCOL=tcps)(HOST=<your-oracle-database-hostname>)(PORT=2484))(CONNECT_DATA=(SERVICE_NAME=<your-oracle-database-service-name>))(SECURITY=(SSL_SERVER_DN_MATCH=FALSE)(MY_WALLET_DIRECTORY=/shared/resources/oracle/wallet)))\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\## Required only by Application Engine or Application Playback Server when type is Oracle and SSL is enabled. The format must be purely oracle descriptor like: (DESCRIPTION=(ADDRESS=(PROTOCOL=tcps)(HOST=<your-oracle-database-hostname>)(PORT=2484))(CONNECT_DATA=(SERVICE_NAME=<your-oracle-database-service-name>))(SECURITY=(SSL_SERVER_DN_MATCH=FALSE)(MY_WALLET_DIRECTORY=/shared/resources/oracle/wallet)))" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\element_val.ORACLE_URL_WITHOUT_WALLET_DIRECTORY=\"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=<your database host/IP>)(PORT=<your database port>))(CONNECT_DATA=(SERVICE_NAME=<your oracle service name>)))\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\## Required only by Application Engine or Application Playback Server when type is Oracle, both ssl and non-ssl. The format must be purely oracle descriptor like: (DESCRIPTION=(ADDRESS=(PROTOCOL=TCPS)(HOST=<your database host/IP>)(PORT=<your database port>))(CONNECT_DATA=(SERVICE_NAME=<your oracle service name>)))" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "s|element_val|$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            fi
        fi

        # set DB servername / port for UMS when db type is oracle
        if [[ $DB_TYPE == "oracle" ]]; then
            # fix sed issue on Mac, DO NOT format code
            nl=$'\n' # fix sed issue on Mac, DO NOT change the script format
            if [[ "$machine" == "Mac" ]]; then
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
element_val.DATABASE_PORT=\"1521\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
## Required only by UMS when database type is Oracle. If you are not using UMS in this database server, comment out this line. Provide the database server port.\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
element_val.DATABASE_SERVERNAME=\"\"\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
## Required only by UMS when database type is Oracle. If you are not using UMS in this database server, comment out this line. Provide the database server name or IP address of the database server.\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ 
\\${nl}" ${DB_SERVER_INFO_PROPERTY_FILE}
                
                ${SED_COMMAND} "s|element_val|$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            else
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\element_val.DATABASE_PORT=\"1521\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\## Required only by UMS when database type is Oracle. If you are not using UMS in this database server, comment out this line. Provide the database server port.\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\element_val.DATABASE_SERVERNAME=\"\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\## Required only by UMS when database type is Oracle. If you are not using UMS in this database server, comment out this line. Provide the database server name or IP address of the database server.\"" ${DB_SERVER_INFO_PROPERTY_FILE}
                ${SED_COMMAND} "/^$item.ORACLE_JDBC_URL=.*/a\ " ${DB_SERVER_INFO_PROPERTY_FILE}

                ${SED_COMMAND} "s|element_val|$item|g" ${DB_SERVER_INFO_PROPERTY_FILE}
            fi
        fi
    done
    success "Created the DB Server property file\n"

    wait_msg "Creating LDAP Server property file"
    > ${LDAP_PROPERTY_FILE}

    echo "####################################" >> ${LDAP_PROPERTY_FILE}
    echo "## Property file for ${LDAP_TYPE} ##" >> ${LDAP_PROPERTY_FILE}
    echo "#####################################" >> ${LDAP_PROPERTY_FILE}
    for i in "${!LDAP_COMMON_PROPERTY[@]}"; do
        echo "${COMMENTS_LDAP_PROPERTY[i]}" >> ${LDAP_PROPERTY_FILE}
        echo "${LDAP_COMMON_PROPERTY[i]}=\"\"" >> ${LDAP_PROPERTY_FILE}
        echo "" >> ${LDAP_PROPERTY_FILE}
    done
    if [[ $LDAP_TYPE == "AD" ]]; then
        ${SED_COMMAND} "s|LDAP_TYPE=\"\"|LDAP_TYPE=\"Microsoft Active Directory\"|g" ${LDAP_PROPERTY_FILE}
        for i in "${!AD_LDAP_PROPERTY[@]}"; do
            echo "${COMMENTS_AD_LDAP_PROPERTY[i]}" >> ${LDAP_PROPERTY_FILE}
            echo "${AD_LDAP_PROPERTY[i]}=\"\"" >> ${LDAP_PROPERTY_FILE}
            echo "" >> ${LDAP_PROPERTY_FILE}
        done
    else
        ${SED_COMMAND} "s|LDAP_TYPE=\"\"|LDAP_TYPE=\"IBM Security Directory Server\"|g" ${LDAP_PROPERTY_FILE}
        for i in "${!TDS_LDAP_PROPERTY[@]}"; do
            echo "${COMMENTS_TDS_LDAP_PROPERTY[i]}" >> ${LDAP_PROPERTY_FILE}
            echo "${TDS_LDAP_PROPERTY[i]}=\"\"" >> ${LDAP_PROPERTY_FILE}
            echo "" >> ${LDAP_PROPERTY_FILE}
        done
    fi
    # Set default value
    ${SED_COMMAND} "s|LDAP_SSL_ENABLED=\"\"|LDAP_SSL_ENABLED=\"True\"|g" ${LDAP_PROPERTY_FILE}
    ${SED_COMMAND} "s|LDAP_SSL_SECRET_NAME=\"\"|LDAP_SSL_SECRET_NAME=\"ibm-cp4ba-ldap-ssl-secret\"|g" ${LDAP_PROPERTY_FILE}
    ${SED_COMMAND} "s|LDAP_SSL_CERT_FILE_FOLDER=\"\"|LDAP_SSL_CERT_FILE_FOLDER=\"${LDAP_SSL_CERT_FOLDER}\"|g" ${LDAP_PROPERTY_FILE}
    ${SED_COMMAND} "s|<LDAP_SSL_CERT_FOLDER>|\"${LDAP_SSL_CERT_FOLDER}\"|g" ${LDAP_PROPERTY_FILE}
    success "Created the LDAP Server property file for BAW on containers\n"

    # Create external LDAP property file
    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        wait_msg "Creating external LDAP property file for BAW on containers"
        mkdir -p $EXT_LDAP_SSL_CERT_FOLDER >/dev/null 2>&1 
        > ${EXTERNAL_LDAP_PROPERTY_FILE}
        tip="## Property file for External LDAP ##"
        echo "#####################################" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
        echo $tip >> ${EXTERNAL_LDAP_PROPERTY_FILE}
        echo "#####################################" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
        for i in "${!LDAP_COMMON_PROPERTY[@]}"; do
            echo "${COMMENTS_LDAP_PROPERTY[i]}" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
            echo "${LDAP_COMMON_PROPERTY[i]}=\"\"" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
            echo "" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
        done
        if [[ $LDAP_TYPE == "AD" ]]; then
            # ${SED_COMMAND} "s|LDAP_TYPE=\"\"|LDAP_TYPE=\"Microsoft Active Directory\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            for i in "${!AD_LDAP_PROPERTY[@]}"; do
                echo "${COMMENTS_AD_LDAP_PROPERTY[i]}" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
                echo "${AD_LDAP_PROPERTY[i]}=\"\"" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
                echo "" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
            done
        else
            # ${SED_COMMAND} "s|LDAP_TYPE=\"\"|LDAP_TYPE=\"IBM Security Directory Server\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
            for i in "${!TDS_LDAP_PROPERTY[@]}"; do
                echo "${COMMENTS_TDS_LDAP_PROPERTY[i]}" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
                echo "${TDS_LDAP_PROPERTY[i]}=\"\"" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
                echo "" >> ${EXTERNAL_LDAP_PROPERTY_FILE}
            done
        fi
        # set default vaule
        ${SED_COMMAND} "s|LDAP_SSL_ENABLED=\"\"|LDAP_SSL_ENABLED=\"True\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|LDAP_SSL_SECRET_NAME=\"\"|LDAP_SSL_SECRET_NAME=\"ibm-cp4ba-ext-ldap-ssl-secret\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|LDAP_SSL_CERT_FILE_FOLDER=\"\"|LDAP_SSL_CERT_FILE_FOLDER=\"${EXT_LDAP_SSL_CERT_FOLDER}\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|<LDAP_SSL_CERT_FOLDER>|\"${EXT_LDAP_SSL_CERT_FOLDER}\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        ${SED_COMMAND} "s|ldap-cert.crt|\external-ldap-cert.crt|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
        success "Created the external LDAP property file for BAW on containers\n"
    else
        rm -rf ${EXTERNAL_LDAP_PROPERTY_FILE} >/dev/null 2>&1
    fi
    # msgB "After done, press any key to next!"
    # read -rsn1 -p"Press any key to continue";echo


    INFO "Creating property file for user profile required by BAW on containers"
    # Add global property into user_profile
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "##     USER Property for Shared Configuration     ##" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}

    wait_msg "Creating user profile for the shared configuration"

    # license
    echo "## Use this parameter to specify the production license you have purchased and" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## the possible values are: ${PURCHASED_PRODUCT_BAW} and ${PURCHASED_PRODUCT_CP4A}." >> ${USER_PROFILE_PROPERTY_FILE}        
    echo "CP4BA.PURCHASED_PRODUCT=\"${PURCHASED_PRODUCT}\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}


    if [[ "${PURCHASED_PRODUCT}" == "${PURCHASED_PRODUCT_CP4A}" ]]; then
        echo "## Use this parameter to specify the license for the CP4A deployment and" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## the possible values are: non-production and production and if not set, the license will" >> ${USER_PROFILE_PROPERTY_FILE}        
        echo "## be defaulted to production.  This value could be different from the other licenses in the CR." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "CP4BA.CP4BA_LICENSE=\"${SC_DEPLOYMENT_LICENSE}\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Business Automation Workflow (BAW) license and possible values are: user, non-production, and production." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## This value could be different from the other licenses in the CR." >> ${USER_PROFILE_PROPERTY_FILE}        
        echo "CP4BA.BAW_LICENSE=\"${SC_DEPLOYMENT_BAW_LICENSE}\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    fi

    if [[ "${PURCHASED_PRODUCT}" == "${PURCHASED_PRODUCT_BAW}" ]]; then
        echo "## Business Automation Workflow (BAW) license and possible values are: non-production, and production." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## This value could be different from the other licenses in the CR." >> ${USER_PROFILE_PROPERTY_FILE}        
        echo "CP4BA.BAW_LICENSE=\"${SC_DEPLOYMENT_BAW_LICENSE}\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    fi

    echo "## FileNet Content Manager (FNCM) license and possible values are: user, non-production, and production." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## This value could be different from the rest of the licenses." >> ${USER_PROFILE_PROPERTY_FILE}        
    echo "CP4BA.FNCM_LICENSE=\"${SC_DEPLOYMENT_FNCM_LICENSE}\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    echo "## You would provide the different storage classes for the slow, medium and fast storage parameters below.  " >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## If you only have 1 storage class defined, then you can use that 1 storage class for all 3 parameters." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.SLOW_FILE_STORAGE_CLASSNAME=\"$SC_SLOW_FILE_STORAGE_CLASSNAME\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.MEDIUM_FILE_STORAGE_CLASSNAME=\"$SC_MEDIUM_FILE_STORAGE_CLASSNAME\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.FAST_FILE_STORAGE_CLASSNAME=\"$SC_FAST_FILE_STORAGE_CLASSNAME\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    echo "## Enable or disable egress access to external systems (default value is \"false\")." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## true: All CP4A pods will not have access to any external systems unless custom, curated egress network policy or polices with specific 'matchLabels' are created. See the documentation for more detail." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## false: All CP4A pods will have access to any external systems with no restriction." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CP4BA.ENABLE_RESTRICTED_INTERNET_ACCESS=\"$RESTRICTED_INTERNET_ACCESS\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    success "Created user profile for the shared configuration\n"

    # Add property into user_profile for FNCM
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "##           USER Property for FNCM               ##" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}

    wait_msg "Creating user profile for IBM FileNet Content Manager"
    
    # appLoginUsername/appLoginPassword for FNCM
    echo "## Provide the user name for P8Domain. For example: \"CEAdmin\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT.APPLOGIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## Provide the user password for P8Domain." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT.APPLOGIN_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    
    # ltpaPassword/keystorePassword for FNCM
    echo "## Provide LTPA key password for FNCM deployment. (NOTES: CONTENT.LTPA_PASSWORD must same as BAN.LTPA_PASSWORD)" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT.LTPA_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## Provide keystore password for FNCM deployment." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT.KEYSTORE_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    success "Created user profile for IBM FileNet Content Manager\n"

    # user profile for content initialization
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "##    USER Property for Content initialization    ##" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}

    wait_msg "Creating user profile for IBM FileNet Content Manager Object Stores"

    echo "## Enable/disable ECM (FNCM) / BAN initialization (e.g., creation of P8 domain, creation/configuration of object stores)" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## The default valuse is \"Yes\", set \"No\" to disable." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT_INITIALIZATION.ENABLE=\"Yes\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    echo "## user name for P8 domain admin, for example, \"CEAdmin\". This parameter accepts comma-separated lists (without spacing), for example, \"CEAdmin1,CEAdmin2\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT_INITIALIZATION.LDAP_ADMIN_USER_NAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    echo "## group name for P8 domain admin, for example, \"P8Administrators\". This parameter accepts comma-separated lists (without spacing), for example, \"P8Group1,P8Group2\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT_INITIALIZATION.LDAP_ADMINS_GROUPS_NAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    echo "## user name and group name for object store admin, for example, \"CEAdmin\" or \"P8Administrators\". This parameter accepts comma-separated lists (without spacing), for example, \"P8Group1,P8Group2\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    # property for oc_cpe_obj_store_enable_workflow
    echo "## Specify whether to enable workflow for the object store, the default vaule is \"Yes\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_ENABLE_WORKFLOW=\"Yes\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    # property for oc_cpe_obj_store_workflow_data_tbl_space
    echo "## Specify a table space for the workflow data" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    # property for oc_cpe_obj_store_workflow_admin_group
    echo "## Designate an LDAP group for the workflow admin group." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_ADMIN_GROUP=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    # property for oc_cpe_obj_store_workflow_config_group
    echo "## Designate an LDAP group for the workflow config group" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_CONFIG_GROUP=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    # property for oc_cpe_obj_store_workflow_pe_conn_point_name
    echo "## Provide a name for the connection point" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_PE_CONN_POINT_NAME=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    success "Created user profile for IBM FileNet Content Manager Object Stores\n"

    # user profile for content initialization
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "##              USER Property for BAN             ##" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    
    wait_msg "Creating user profile for IBM Business Automation Navigator"

    # appLoginUsername/appLoginPassword for BAN
    echo "## Provide the user name for BAN. For example: \"BANAdmin\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "BAN.APPLOGIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## Provide the user password for BAN." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "BAN.APPLOGIN_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    
    # ltpaPassword/keystorePassword for BAN
    echo "## Provide LTPA key password for BAN deployment. (NOTES: BAN.LTPA_PASSWORD must same as CONTENT.LTPA_PASSWORD)" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "BAN.LTPA_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## Provide keystore password for BAN deployment." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "BAN.KEYSTORE_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    # jMailUsername/jMailPassword for BAN
    echo "## Provide the user name for jMail used by BAN. For example: \"jMailAdmin\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "BAN.JMAIL_USER_NAME=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## Provide the user password for jMail used by BAN." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "BAN.JMAIL_USER_PASSWORD=\"<Optional>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    success "Created user profile for IBM Business Automation Navigator\n"

    # Add user property into user_profile for BAW runtime
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "##           USER Property for BAW                ##" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    
    wait_msg "Creating user profile for IBM Business Automation Workflow"

    # BAW runtime profile
    echo "## Designate an existing LDAP user for the Workflow Server admin user." >> ${USER_PROFILE_PROPERTY_FILE}
    echo "BAW_RUNTIME.ADMIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    if [[ $EVENT_EMITTER_ENABLED == "true" ]]; then 
        echo "## The event emitter settings if you want to enable Case Event Emitter." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## Creation date of the events. For example, \"20200630T002840Z\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "BAW_RUNTIME.EVENT_EMITTER_DATE_SQL=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}

        echo "## Logical unique id. An 8-character alphanumeric string without underscores, for example, \"bawinst1\"." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "## While processing, the emitter tracks the events that are processed by using the Content Engine Audit Processing Bookmark with a display name that is based on this value." >> ${USER_PROFILE_PROPERTY_FILE}
        echo "BAW_RUNTIME.EVENT_EMITTER_LOGICAL_UNIQUE_ID=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
        echo "" >> ${USER_PROFILE_PROPERTY_FILE}
    fi

    success "Created user profile for IBM Business Automation Workflow\n"

    # Add user property into user_profile for UMS
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "##           USER Property for UMS                ##" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "####################################################" >> ${USER_PROFILE_PROPERTY_FILE}
    
    wait_msg "Creating user profile for User Management Services"

    # adminUser / adminPassword
    echo "## Specify the user and password values for an internal UMS admin user that will be created in a local user registry. " >> ${USER_PROFILE_PROPERTY_FILE}
    echo "## This user must be unique and not exist in the LDAP user registry. " >> ${USER_PROFILE_PROPERTY_FILE}
    echo "UMS.ADMIN_USER=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "UMS.ADMIN_PASSWORD=\"<Required>\"" >> ${USER_PROFILE_PROPERTY_FILE}
    echo "" >> ${USER_PROFILE_PROPERTY_FILE}

    success "Created user profile for User Management Services\n"

    # create property file for database name and user
    INFO "Creating property file for database name and user"
    > ${DB_NAME_USER_PROPERTY_FILE}
    echo "==================================================================================================================" >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "NOTES: Change the \"$DB_SERVER_PREFIX\" variable to assign each database to a database server or instance." >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "       The \"$DB_SERVER_PREFIX\" must be in [${db_server_array[*]}]" >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "==================================================================================================================" >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
   
    # Create DBNAME/DBUSER property file for GCDDB 
    wait_msg "Creating Property file for IBM FileNet Content Manager GCD"
    tip="## FNCM GCD database required properties on ${DB_TYPE} ##"
    echo "###########################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
    echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "###########################################################" >> ${DB_NAME_USER_PROPERTY_FILE}

    if [[ $DB_TYPE != "oracle" ]]; then
        echo "## Provide the name of the database for the GCD of P8Domain. For example: \"GCDDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.GCD_DB_NAME=\"GCDDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    fi
    
    if [[ $DB_TYPE != "oracle" ]]; then
        echo "## Provide the user name of the database for the GCD of P8Domain. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.GCD_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    else
        echo "## Provide the user name of the database for the GCD of P8Domain. For example: \"GCDDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.GCD_DB_USER_NAME=\"GCDDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    fi
    
    echo "## Provide the password of the database user for the GCD of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "$DB_SERVER_PREFIX.GCD_DB_USER_PASSWORD=\"<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
    success "Created Property file for IBM FileNet Content Manager GCD\n"

    # Create DBNAME/DBUSER property file for Object store
    # INFO "Creating Property file for IBM FileNet Content Manager Object Store"
    tip="## FNCM Object Stores database required properties on ${DB_TYPE} ##"

    echo "###########################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
    echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "###########################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
    
    if (( content_os_number > 0 )); then
        for ((j=0;j<${content_os_number};j++))
        do
            if [[ $DB_TYPE != "oracle" ]]; then
                echo "## Provide the name of the database for the Object Store of P8Domain. For example: \"OS$((j+1))DB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_NAME=\"OS$((j+1))DB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "## Provide the user name of the database for the Object Store of P8Domain. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}                        
            else
                echo "## Provide the user name of the database for the Object Store of P8Domain. For example: \"OS$((j+1))DB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
                echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_NAME=\"OS$((j+1))DB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            fi

            echo "## Provide the password of the database user for the Object Store of P8Domain. " >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.OS$((j+1))_DB_USER_PASSWORD=\"<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
        done
    fi

    # generate property for Object store required by BAW Runtime
    wait_msg "Creating Property file for IBM FileNet Content Manager Object Stores"
    for i in "${!BAW_STD_OS_ARR[@]}"; do
        if [[ $DB_TYPE != "oracle" ]]; then
            echo "## Provide the name of the database for the object store. For example: \"${BAW_STD_OS_ARR[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.${BAW_STD_OS_ARR[i]}_DB_NAME=\"${BAW_STD_OS_ARR[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## Provide the user name for the object store database. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.${BAW_STD_OS_ARR[i]}_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        else
            echo "## Provide the user name for the object store database. For example: \"${BAW_STD_OS_ARR[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.${BAW_STD_OS_ARR[i]}_DB_USER_NAME=\"${BAW_STD_OS_ARR[i]}\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
        echo "## Provide the password for the user of Object Store of P8Domain." >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.${BAW_STD_OS_ARR[i]}_DB_USER_PASSWORD=\"<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
    done

    success "Created Property file for IBM FileNet Content Manager Object Stores\n"
            
    echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
    # INFO "Created Property file for IBM FileNet Content Manager Object Store"

    # Create DBNAME/DBUSER property file for ICNDB
    wait_msg "Creating Property file for IBM Business Automation Navigator"
    
    tip="## Navigator database required properties on ${DB_TYPE} ##"

    echo "###########################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
    echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "###########################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
    if [[ $DB_TYPE != "oracle" ]]; then
        echo "## Provide the name of the database for ICN (Navigator). For example: \"ICNDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.ICN_DB_NAME=\"ICNDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    fi
    if [[ $DB_TYPE != "oracle" ]]; then
        echo "## Provide the user name of the database for ICN (Navigator). For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.ICN_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    else
        echo "## Provide the user name of the database for ICN (Navigator). For example: \"ICNDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.ICN_DB_USER_NAME=\"ICNDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    fi
    echo "## Provide the password of the database user for ICN (Navigator). " >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "$DB_SERVER_PREFIX.ICN_DB_USER_PASSWORD=\"<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "" >> ${DB_NAME_USER_PROPERTY_FILE}
    success "Created Property file for IBM Business Automation Navigator\n"

    # generate property for BAW runtime
    wait_msg "Creating Property file for IBM Business Automation Workflow"

    tip="## Business Automation Workflow required properties on ${DB_TYPE} ##"

    echo "###########################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
    echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "###########################################################" >> ${DB_NAME_USER_PROPERTY_FILE}

    if [[ $DB_TYPE != "oracle" ]]; then
        echo "## Provide the user name of the database for Business Automation Workflow. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "## Provide the password for the user of database for Business Automation Workflow ." >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_PASSWORD=\"<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "## Provide the database name for Business Automation Workflow. For example: \"BAWDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_NAME=\"BAWDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}

        # To support customize database schema for postgresql and db2
        if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
            echo "## Provide the schema name that is used to qualify unqualified database objects in dynamically prepared SQL statements when" >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "## the schema name is different from the user name of the database for Business Automation Workflow." >> ${DB_NAME_USER_PROPERTY_FILE}
            echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_CURRENT_SCHEMA=\"<Optional>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        fi
    else
        echo "## Provide the database name for Business Automation Workflow. For example: \"BAWDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_NAME=\"BAWDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "## Provide the password for the user of database required by Business Automation Workflow Runtime." >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.BAW_RUNTIME_DB_USER_PASSWORD=\"<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    fi
    echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

    success "Created Property file for IBM Business Automation Workflow\n"

    # generate property for UMS
   
    wait_msg "Creating Property file for User Management Services"

    tip="## User Management Services required properties on ${DB_TYPE} ##"

    echo "###########################################################" >> ${DB_NAME_USER_PROPERTY_FILE}
    echo $tip >> ${DB_NAME_USER_PROPERTY_FILE}
    echo "###########################################################" >> ${DB_NAME_USER_PROPERTY_FILE}

    if [[ $DB_TYPE != "oracle" ]]; then
        echo "## Provide the user name of the database for UMS. For example: \"dbuser1\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.UMS_DB_USER_NAME=\"<youruser1>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "## Provide the password for the user of database for UMS ." >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.UMS_DB_USER_PASSWORD=\"<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "## Provide the database name for UMS. For example: \"UMSDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.UMS_DB_NAME=\"UMSDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}        
    else
        echo "## Provide the database name for UMS. For example: \"UMSDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.UMS_DB_USER_NAME=\"UMSDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "## Provide the password for the user of database required by UMS." >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.UMS_DB_USER_PASSWORD=\"<yourpassword>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "## Provide the SID for UMS. If service name should be used instead of SID, leave it empty. For example: \"umsSID\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.UMS_DB_SID=\"<umsSID>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "## Provide the service name for UMS if you want to connect by service name instead of SID. For example: \"umsServiceName\"" >> ${DB_NAME_USER_PROPERTY_FILE}
        echo "$DB_SERVER_PREFIX.UMS_DB_SERVICE_NAME=\"<umsServiceName>\"" >> ${DB_NAME_USER_PROPERTY_FILE}
    fi
    echo "" >> ${DB_NAME_USER_PROPERTY_FILE}

    success "Created Property file for User Management Services\n"
    
    # Add <Required> in each mandatory value
    ${SED_COMMAND} "s|=\"\"|=\"<Required>\"|g" ${DB_NAME_USER_PROPERTY_FILE}
    ${SED_COMMAND} "s|=\"\"|=\"<Required>\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
    ${SED_COMMAND} "s|=\"\"|=\"<Required>\"|g" ${LDAP_PROPERTY_FILE}
    #set DB2 HADR as optional
    ${SED_COMMAND} "s|HADR_STANDBY_SERVERNAME=\"<Required>\"|HADR_STANDBY_SERVERNAME=\"<Optional>\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
    ${SED_COMMAND} "s|HADR_STANDBY_PORT=\"<Required>\"|HADR_STANDBY_PORT=\"<Optional>\"|g" ${DB_SERVER_INFO_PROPERTY_FILE}
    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        ${SED_COMMAND} "s|=\"\"|=\"<Required>\"|g" ${EXTERNAL_LDAP_PROPERTY_FILE}
    fi

    INFO "Created all property files"
    
    # Show some tips for property file
    tips 
    echo -e  "Enter the <Required> values in the below property files under $PROPERTY_FILE_FOLDER"
    msgRed   "The key name in the property file is created by the baw-prerequisites.sh and is NOT EDITABLE."
    msgRed   "The values in the property files must be within double quotes."
    msgRed   "The value for User/Password in [baw_db_name_user.property] [baw_user_profile.property] file should NOT include special characters \"=\" \".\" \"\\\""
    msgRed   "The value in [baw_LDAP.property] or [baw_user_profile.property] file should NOT include special character '\"'"
    echo -e  ""
    echo -e  "\x1B[33;5m* [baw_db_server.property]:\x1B[0m"
    echo -e  "  - Properties for the database server used by BAW on containers, such as DATABASE_SERVERNAME/DATABASE_PORT/DATABASE_SSL_ENABLE.\n"
    echo -e  "  - The value of \"<DB_SERVER_LIST>\" is an alias for the database servers. The key supports comma-separated lists.\n"
    
    echo -e  "\x1B[33;5m* [baw_db_name_user.property]:\x1B[0m"
    echo -e  "  - Properties for database name and user name required by each components of by BAW on containers deployment, such as GCD_DB_NAME/GCD_DB_USER_NAME/GCD_DB_USER_PASSWORD.\n"
    echo -e  "  - Change the prefix \"<DB_SERVER_NAME>\" to assign which database is used by the component.\n"
    echo -e  "  - The value of \"<DB_SERVER_NAME>\" must match with the value of <DB_SERVER_LIST> which defined in \"<DB_SERVER_LIST>\" of \"baw_db_server.property\".\n"
    
    echo -e  "\x1B[33;5m* [baw_LDAP.property]:\x1B[0m"
    echo -e  "  - Properties for the LDAP server that is used by the Business Automation Workflow on containers, such as LDAP_SERVER/LDAP_PORT/LDAP_BASE_DN/LDAP_BIND_DN/LDAP_BIND_DN_PASSWORD.\n"
    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        echo -e  "\x1B[33;5m* [baw_external_LDAP.property]:\x1B[0m"
        echo -e  "  - Properties for the External LDAP server that is used by External Share, such as LDAP_SERVER/LDAP_PORT/LDAP_BASE_DN/LDAP_BIND_DN/LDAP_BIND_DN_PASSWORD.\n"
    fi

    echo -e  "\x1b[33;5m* [baw_user_profile.property]:\x1B[0m"
    echo -e  "  - Properties for the global value used by the deployment, such as \"sc_deployment_license\".\n"
    echo -e  "  - properties for the value used by each component of Business Automation Workflow on containers, such as <APPLOGIN_USER>/<APPLOGIN_PASSWORD>\n"
}

function load_property_before_generate(){
    if [[ ! -f $TEMPORARY_PROPERTY_FILE || ! -f $DB_NAME_USER_PROPERTY_FILE || ! -f $DB_SERVER_INFO_PROPERTY_FILE || ! -f $LDAP_PROPERTY_FILE ]]; then
        fail "Not Found existing property file under \"$PROPERTY_FILE_FOLDER\""
        exit 1
    fi

    # load pattern into pattern_cr_arr
    pattern_list="$(prop_tmp_property_file PATTERN_LIST)"
    optional_component_list="$(prop_tmp_property_file OPTION_COMPONENT_LIST)"
    OIFS=$IFS
    IFS=',' read -ra pattern_cr_arr <<< "$pattern_list"
    IFS=',' read -ra optional_component_cr_arr <<< "$optional_component_list"
    IFS=$OIFS

    # load db_name_full_array and db_user_full_array
    db_name_list="$(prop_tmp_property_file DB_NAME_LIST)"
    db_user_list="$(prop_tmp_property_file DB_USER_LIST)"
    db_user_pwd_list="$(prop_tmp_property_file DB_USER_PWD_LIST)"

    OIFS=$IFS
    IFS=',' read -ra db_name_full_array <<< "$db_name_list"
    IFS=',' read -ra db_user_full_array <<< "$db_user_list"
    IFS=',' read -ra db_user_pwd_full_array <<< "$db_user_pwd_list"
    IFS=$OIFS

    # load db ldap type
    LDAP_TYPE="$(prop_tmp_property_file LDAP_TYPE)"
    DB_TYPE="$(prop_tmp_property_file DB_TYPE)"

    # load CONTENT_OS_NUMBER
    content_os_number=$(prop_tmp_property_file CONTENT_OS_NUMBER)
    # msgB "$content_os_number"; sleep 300

    # load DB_SERVER_NUMBER
    db_server_number=$(prop_tmp_property_file DB_SERVER_NUMBER)

    # load external ldap flag
    SET_EXT_LDAP=$(prop_tmp_property_file EXTERNAL_LDAP_ENABLED)

    # load platform selected
    PLATFORM_SELECTED=$(prop_tmp_property_file PLATFORM_SELECTED)
}

function create_db_script(){
    local db_name_full_array=()
    local db_user_full_array=()
    local db_user_pwd_full_array=()
    INFO "Generating DB SQL Statement file required by BAW on containers based on property file"
    # Generate db2 sql statement file for FNCM
    rm -rf $DB_SCRIPT_FOLDER
    printf "\n"

   
    wait_msg "Creating the DB SQL statement file for Content Platform Engine global configuration database (GCD)"
    while true; do
        case "$DB_TYPE" in
        "db2"|"sqlserver"|"postgresql")
            tmp_dbname="$(prop_db_name_user_property_file GCD_DB_NAME)"
            tmp_dbuser="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
            tmp_dbuserpwd="$(prop_db_name_user_property_file GCD_DB_USER_PASSWORD)"
            tmp_dbservername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"
            check_dbserver_name_valid $tmp_dbservername "GCD_DB_USER_NAME"
            db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
            db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
            db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

            if [[ $DB_TYPE == "sqlserver" ]]; then
                create_fncm_gcddb_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
            elif [[ $DB_TYPE == "postgresql" ]]; then
                create_fncm_gcddb_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
            elif [[ $DB_TYPE == "db2" ]]; then
                check_db2_name_valid $tmp_dbname $tmp_dbservername "GCD_DB_NAME"
                create_fncm_gcddb_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername
            fi
            break
            ;;
        "oracle")
            tmp_dbuser="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
            tmp_dbuserpwd="$(prop_db_name_user_property_file GCD_DB_USER_PASSWORD)"
            tmp_dbservername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"
            check_dbserver_name_valid $tmp_dbservername "GCD_DB_USER_NAME"
            db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
            db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

            create_fncm_gcddb_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
            break
            ;;
        esac
    done

    # ${SED_COMMAND} "s|\"||g" $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/createGCDDB.sql
    success "Created the DB SQL statement file for Content Platform Engine global configuration database (GCD) \n"


   # Generate DB SQL for Objectstore
    if (( content_os_number > 0 )); then
        for ((j=1;j<=${content_os_number};j++))
        do
            wait_msg "Creating the DB SQL statement file for FNCM Object store database: os${j}db"
            while true; do
                case "$DB_TYPE" in
                "db2"|"sqlserver"|"postgresql")
                    tmp_dbname="$(prop_db_name_user_property_file OS${j}_DB_NAME)"
                    tmp_dbuser="$(prop_db_name_user_property_file OS${j}_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file OS${j}_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name OS${j}_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "OS${j}_DB_USER_NAME"
                    db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        create_fncm_osdb_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername ${j}
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        create_fncm_osdb_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername ${j}
                    elif [[ $DB_TYPE == "db2" ]]; then
                        check_db2_name_valid $tmp_dbname $tmp_dbservername "OS${j}_DB_NAME"
                        create_fncm_osdb_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername ${j}
                    fi
                    break
                    ;;
                "oracle")
                    tmp_dbuser="$(prop_db_name_user_property_file OS${j}_DB_USER_NAME)"
                    tmp_dbuserpwd="$(prop_db_name_user_property_file OS${j}_DB_USER_PASSWORD)"
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name OS${j}_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "OS${j}_DB_USER_NAME"
                    db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

                    create_fncm_osdb_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername ${j}
                    break
                    ;;
                esac
            done            

            # ${SED_COMMAND} "s|\"||g" $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/createOS${j}DB.sql
            success "Created the DB SQL statement file for FNCM Object store database: os${j}db\n"
        done
    fi

    # Generate DB SQL for ICN
    # if [[ " ${pattern_cr_arr[@]}" =~ "workflow" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
    wait_msg "Creating the DB SQL statement file for IBM Business Automation Navigator database"
    while true; do
        case "$DB_TYPE" in
        "db2"|"sqlserver"|"postgresql")
            tmp_dbname="$(prop_db_name_user_property_file ICN_DB_NAME)"
            tmp_dbuser="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
            tmp_dbuserpwd="$(prop_db_name_user_property_file ICN_DB_USER_PASSWORD)"
            tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ICN_DB_USER_NAME)"
            check_dbserver_name_valid $tmp_dbservername "ICN_DB_USER_NAME"
            db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
            db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
            db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
            if [[ $DB_TYPE == "sqlserver" ]]; then
                create_ban_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
            elif [[ $DB_TYPE == "postgresql" ]]; then
                create_ban_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
            elif [[ $DB_TYPE == "db2" ]]; then
                check_db2_name_valid $tmp_dbname $tmp_dbservername "ICN_DB_NAME"
                create_ban_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername
            fi
            break
            ;;
        "oracle")
            tmp_dbuser="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
            tmp_dbuserpwd="$(prop_db_name_user_property_file ICN_DB_USER_PASSWORD)"
            tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ICN_DB_USER_NAME)"
            check_dbserver_name_valid $tmp_dbservername "ICN_DB_USER_NAME"
            db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
            db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)
            create_ban_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
            break
            ;;
        esac
    done
    success "Created the DB SQL statement file for IBM Business Automation Navigator database\n"
    # fi

    while true; do
        case "$DB_TYPE" in
        "oracle")
                for i in "${!BAW_STD_OS_ARR[@]}"; do
                    tmp_dbuser=$(prop_db_name_user_property_file ${BAW_STD_OS_ARR[i]}_DB_USER_NAME)
                    tmp_dbuserpwd=$(prop_db_name_user_property_file ${BAW_STD_OS_ARR[i]}_DB_USER_PASSWORD)
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ${BAW_STD_OS_ARR[i]}_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "${BAW_STD_OS_ARR[i]}_DB_USER_NAME"
                    db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

                    # echo "$tmp_dbuser"; sleep 3
                    wait_msg "Creating the DB SQL statement file for Business Automation Workflow: ${BAW_STD_OS_ARR[i]}"
                    if [[ "${BAW_STD_OS_ARR[i]}" == "BAWTOS" ]]; then
                        tmp_tablespace=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                        create_fncm_osdb_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername "" $tmp_tablespace
                    else
                        create_fncm_osdb_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                    fi
                    success "Created the DB SQL statement file for Business Automation Workflow: ${BAW_STD_OS_ARR[i]}\n"
                done
            
            break
            ;;
        "db2"|"sqlserver"|"postgresql")
                for i in "${!BAW_STD_OS_ARR[@]}"; do
                    tmp_dbuser=$(prop_db_name_user_property_file ${BAW_STD_OS_ARR[i]}_DB_USER_NAME)
                    tmp_dbname=$(prop_db_name_user_property_file ${BAW_STD_OS_ARR[i]}_DB_NAME)
                    tmp_dbuserpwd=$(prop_db_name_user_property_file ${BAW_STD_OS_ARR[i]}_DB_USER_PASSWORD)
                    tmp_dbservername="$(prop_db_name_user_property_file_for_server_name ${BAW_STD_OS_ARR[i]}_DB_USER_NAME)"
                    check_dbserver_name_valid $tmp_dbservername "${BAW_STD_OS_ARR[i]}_DB_USER_NAME"
                    
                    db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                    db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                    db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

                    # echo "$tmp_dbname"; sleep 300
                    wait_msg "Creating the DB SQL statement file for Business Automation Workflow: ${BAW_STD_OS_ARR[i]}"
                    if [[ $DB_TYPE == "sqlserver" ]]; then
                        if [[ "${BAW_STD_OS_ARR[i]}" == "BAWTOS" ]]; then
                            tmp_tablespace=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                            create_fncm_osdb_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername "" $tmp_tablespace
                        else
                            create_fncm_osdb_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                        fi
                    elif [[ $DB_TYPE == "postgresql" ]]; then
                        if [[ "${BAW_STD_OS_ARR[i]}" == "BAWTOS" ]]; then
                            tmp_tablespace=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                            create_fncm_osdb_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername "" $tmp_tablespace
                        else
                            create_fncm_osdb_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                        fi
                    elif [[ $DB_TYPE == "db2" ]]; then
                        check_db2_name_valid $tmp_dbname $tmp_dbservername "${BAW_STD_OS_ARR[i]}_DB_NAME"

                        if [[ "${BAW_STD_OS_ARR[i]}" == "BAWTOS" ]]; then
                            tmp_tablespace=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                            create_fncm_osdb_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername "" $tmp_tablespace
                        else
                            create_fncm_osdb_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername
                        fi
                    fi
                    success "Created the DB SQL statement file for Business Automation Workflow: ${BAW_STD_OS_ARR[i]}\n"
                done
            break
            ;;
        esac           
    done

    while true; do
        case "$DB_TYPE" in
        "db2"|"sqlserver"|"postgresql")
                tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
                tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
                tmp_dbschema=""
                if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
                    tmp_baw_runtime_db_current_schema_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_CURRENT_SCHEMA)"
                    tmp_baw_runtime_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_current_schema_name")
                    if [[ $tmp_baw_runtime_db_current_schema_name != "<Optional>" &&  $tmp_baw_runtime_db_current_schema_name != "" ]]; then
                        if [[ $DB_TYPE == "postgresql" ]]; then
                            tmp_baw_runtime_db_current_schema_name=$(echo $tmp_baw_runtime_db_current_schema_name | tr '[:upper:]' '[:lower:]')
                        fi
                        tmp_dbschema=$tmp_baw_runtime_db_current_schema_name
                    fi
                fi

                check_dbserver_name_valid $tmp_dbservername "BAW_RUNTIME_DB_USER_NAME"

                db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

                wait_msg "Creating the DB SQL statement file for Business Automation Workflow database instance1"
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_baw_db_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_baw_db_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername $tmp_dbschema
                elif [[ $DB_TYPE == "db2" ]]; then
                    check_db2_name_valid $tmp_dbname $tmp_dbservername "BAW_RUNTIME_DB_NAME"
                    create_baw_db_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername $tmp_dbschema
                fi
                success "Created the DB SQL statement file for Business Automation Workflow database instance1\n"
            break
            ;;
        "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbservername "BAW_RUNTIME_DB_USER_NAME"

                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

                wait_msg "Creating the DB SQL statement file for Business Automation Workflow database instance1"
                create_baw_db_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                success "Created the DB SQL statement file for Business Automation Workflow database instance1\n"
            break
            ;;
        esac
    done

    # Generate DB SQL for UMS DB for UMS
    while true; do
        case "$DB_TYPE" in
        "db2"|"sqlserver"|"postgresql")
            
                tmp_dbuser="$(prop_db_name_user_property_file UMS_DB_USER_NAME)"
                tmp_dbname="$(prop_db_name_user_property_file UMS_DB_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file UMS_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name UMS_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbservername "UMS_DB_USER_NAME"

                db_name_full_array=(${db_name_full_array[@]} $tmp_dbname)
                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

                wait_msg "Creating the DB SQL statement file for User Management Services"
                if [[ $DB_TYPE == "sqlserver" ]]; then
                    create_ums_db_sqlserver_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                elif [[ $DB_TYPE == "postgresql" ]]; then
                    create_ums_db_postgresql_sql_file $tmp_dbname $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                elif [[ $DB_TYPE == "db2" ]]; then
                    check_db2_name_valid $tmp_dbname $tmp_dbservername "UMS_DB_NAME"
                    create_ums_db_db2_sql_file $tmp_dbname $tmp_dbuser $tmp_dbservername
                fi
                success "Created the DB SQL statement file for User Management Services\n"


            break
            ;;
        "oracle")
                tmp_dbuser="$(prop_db_name_user_property_file UMS_DB_USER_NAME)"
                tmp_dbuserpwd="$(prop_db_name_user_property_file UMS_DB_USER_PASSWORD)"
                tmp_dbservername="$(prop_db_name_user_property_file_for_server_name UMS_DB_USER_NAME)"
                check_dbserver_name_valid $tmp_dbservername "UMS_DB_USER_NAME"

                db_user_full_array=(${db_user_full_array[@]} $tmp_dbuser)
                db_user_pwd_full_array=(${db_user_pwd_full_array[@]} $tmp_dbuserpwd)

                wait_msg "Creating the DB SQL statement file for User Management Services"
                create_ums_db_oracle_sql_file $tmp_dbuser $tmp_dbuserpwd $tmp_dbservername
                success "Created the DB SQL statement file for User Management Services\n"
            break
            ;;
        esac
    done

    tips ""
    msgB "* The DB SQL statement files were created under directory ${DB_SCRIPT_FOLDER}. You can modify them or use the default settings to create the database.\n(NOTES: DO NOT CHANGE DBNAME/DBUSER/DBPASSWORD DIRECTLY in the DB SQL statement files. PLEASE CHANGE THEM IN THE PROPERTY FILES IF NEEDED)"

    # Convert db name/user array to list by common
    delim=""
    db_name_joined=""
    for item in "${db_name_full_array[@]}"; do
        item=$(sed -e 's/^"//' -e 's/"$//' <<<"$item")
        db_name_joined="$db_name_joined$delim$item"
        delim=","
    done

    delim=""
    db_user_joined=""
    for item in "${db_user_full_array[@]}"; do
        item=$(sed -e 's/^"//' -e 's/"$//' <<<"$item")
        db_user_joined="$db_user_joined$delim$item"
        delim=","
    done

    delim=""
    db_user_pwd_joined=""
    for item in "${db_user_pwd_full_array[@]}"; do
        item=$(sed -e 's/^"//' -e 's/"$//' <<<"$item")
        db_user_pwd_joined="$db_user_pwd_joined$delim$item"
        delim=","
    done

    ${SED_COMMAND} '/DB_NAME_LIST/d' ${TEMPORARY_PROPERTY_FILE}
    ${SED_COMMAND} '/DB_USER_LIST/d' ${TEMPORARY_PROPERTY_FILE}
    ${SED_COMMAND} '/DB_USER_PWD_LIST/d' ${TEMPORARY_PROPERTY_FILE}

    echo "DB_NAME_LIST=$db_name_joined" >> ${TEMPORARY_PROPERTY_FILE}
    echo "DB_USER_LIST=$db_user_joined" >> ${TEMPORARY_PROPERTY_FILE}
    echo "DB_USER_PWD_LIST=$db_user_pwd_joined" >> ${TEMPORARY_PROPERTY_FILE}
}

function select_ldap_type(){
    printf "\n"
    COLUMNS=12
    echo -e "\x1B[1mWhat is the LDAP type that is used for this deployment? \x1B[0m"
    options=("Microsoft Active Directory" "IBM Tivoli Directory Server / Security Directory Server")
    PS3='Enter a valid option [1 to 2]: '
    select opt in "${options[@]}"
    do
        case $opt in
            "Microsoft Active Directory")
                LDAP_TYPE="AD"
                local tmp_ldap_type=$opt
                break
                ;;
            "IBM Tivoli"*)
                LDAP_TYPE="TDS"
                local tmp_ldap_type=$opt
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

    success "Selected LDAP type used for this deployment: ${tmp_ldap_type}"
    printf "\n"
    msgRed "You can change the parameter \"LDAP_SSL_ENABLED\" in property file \"$LDAP_PROPERTY_FILE\" later. \"LDAP_SSL_ENABLED\" is \"TRUE\" by default."
}

function select_db_type(){
    printf "\n"
    COLUMNS=12
    echo -e "\x1B[1mWhat is the database type used for this deployment? \x1B[0m"
    if [[ " ${PATTERNS_CR_SELECTED[@]} " =~ "document_processing" ]]; then
        options=("IBM Db2 Database")
        PS3='Enter a valid option [1 to 1]: '
    else
        options=("IBM Db2 Database" "Oracle" "Microsoft SQL Server" "PostgreSQL")
        PS3='Enter a valid option [1 to 4]: '
    fi
    select opt in "${options[@]}"
    do
        case $opt in
            "IBM Db2 Database")
                DB_TYPE="db2"
                local tmp_db_type=$opt
                break
                ;;
            "Oracle")
                DB_TYPE="oracle"
                local tmp_db_type=$opt
                break
                ;;
            "Microsoft SQL Server")
                DB_TYPE="sqlserver"
                local tmp_db_type=$opt
                break
                ;;
            "PostgreSQL")
                DB_TYPE="postgresql"
                local tmp_db_type=$opt
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

    success "Selected database type used for this deployment: ${tmp_db_type}"
    printf "\n"
    msgRed "You can change the parameter \"DATABASE_SSL_ENABLE\" in property file \"$DB_SERVER_INFO_PROPERTY_FILE\" later. \"DATABASE_SSL_ENABLE\" is \"TRUE\" by default."

    if [[ $DB_TYPE == "postgresql" ]]; then
        msgRed "You can change the parameter \"POSTGRESQL_SSL_CLIENT_SERVER\" in property file \"$DB_SERVER_INFO_PROPERTY_FILE\" later. \"POSTGRESQL_SSL_CLIENT_SERVER\" is \"TRUE\" by default"
        msgRed "- POSTGRESQL_SSL_CLIENT_SERVER=\"True\": For a PostgreSQL database with both server and client authentication"
        msgRed "- POSTGRESQL_SSL_CLIENT_SERVER=\"False\": For a PostgreSQL database with server-only authentication"
    fi
}

function select_enable_event_emitter() {
    printf "\n"
    while true; do
        printf "\x1B[1mDo you want to enable Case Event Emitter with this deployment? (Yes/No, default: No): "
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            EVENT_EMITTER_ENABLED="true"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO"|"")
            EVENT_EMITTER_ENABLED="false"
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

function set_external_ldap(){
    printf "\n"

    while true; do
        printf "\x1B[1mWill an external LDAP be used as part of the configuration?: \x1B[0m"

        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES")
            SET_EXT_LDAP="Yes"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            SET_EXT_LDAP="No"
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done

}

function get_storage_class_name() {
    slow_file_storage_classname=""
    medium_file_storage_classname=""
    fast_file_storage_classname=""

    printf "\n"

    # To get slow storage clase name
    printf "\x1B[1mTo provision the persistent volumes and volume claims\n\x1B[0m"
    while [[ $slow_file_storage_classname == "" ]] 
    do
        printf "\x1B[1mEnter the file storage classname for slow storage(RWX): \x1B[0m"
        read -rp "" slow_file_storage_classname
        if [ -z "$slow_file_storage_classname" ]; then
            echo -e "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
        fi
    done

    # To get medium storage clase name
    while [[ $medium_file_storage_classname == "" ]] 
    do
        printf "\x1B[1mEnter the file storage classname for medium storage(RWX): \x1B[0m"
        read -rp "" medium_file_storage_classname
        if [ -z "$medium_file_storage_classname" ]; then
            echo -e "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
        fi
    done

    # To get fast storage clase name
    while [[ $fast_file_storage_classname == "" ]] 
    do
        printf "\x1B[1mEnter the file storage classname for fast storage(RWX): \x1B[0m"
        read -rp "" fast_file_storage_classname
        if [ -z "$fast_file_storage_classname" ]; then
            echo -e "\x1B[1;31mEnter a valid file storage classname(RWX)\x1B[0m"
        fi
    done

    SC_SLOW_FILE_STORAGE_CLASSNAME=${slow_file_storage_classname}
    SC_MEDIUM_FILE_STORAGE_CLASSNAME=${medium_file_storage_classname}
    SC_FAST_FILE_STORAGE_CLASSNAME=${fast_file_storage_classname}
 
    success "Collected file storage classname(RWX)"
    printf '%b\n' "   * Slow:   ${SC_SLOW_FILE_STORAGE_CLASSNAME}"
    printf '%b\n' "   * Medium: ${SC_MEDIUM_FILE_STORAGE_CLASSNAME}"
    printf '%b\n' "   * Fast:   ${SC_FAST_FILE_STORAGE_CLASSNAME}"
}

function get_deployment_hostname_suffix() {
    deploy_hostname_suffix=""

    printf "\n"

    while [[ $deploy_hostname_suffix == "" ]] 
    do
        printf "\x1B[1mEnter the deployment hostname suffix: \x1B[0m"
        read -rp "" deploy_hostname_suffix
        if [ -z "$deploy_hostname_suffix" ]; then
            echo -e "\x1B[1;31mEnter a valid deploy_hostname_suffix\x1B[0m"
        fi
    done

    success "Collected the deployment hostname suffix: $deploy_hostname_suffix"

    SC_DEPLOYMENT_HOSTNAME_SUFFIX=${deploy_hostname_suffix}
}

function input_information(){
    EXISTING_OPT_COMPONENT_ARR=()
    EXISTING_PATTERN_ARR=()
    rm -rf $TEMPORARY_PROPERTY_FILE >/dev/null 2>&1
    DEPLOYMENT_TYPE="production"
    PLATFORM_SELECTED="OCP"
    
    select_platform
    get_deploy_license
    select_ldap_type
    select_db_type
    get_db_server_list
    get_storage_class_name
    select_enable_event_emitter
        
    select_restricted_internet_access

    create_temp_property_file
}

function get_db_server_list(){
    local db_server_list_input=""
    while true; do
        printf "\n"
        printf "\x1B[1mEnter the alias name(s) for database server(s)/instance(s) to be used by Business Automation Workflow on containers.\x1B[0m\n"
        echo -e "\x1B[1;31m(NOTE: NOT the host name of database server, and CANNOT include a dot[.] character)\x1B[0m"
        echo -e "\x1B[1;31m(NOTE: This key supports comma-separated lists (for example: dbserver1,dbserver2,dbserver3)\x1B[0m"
        
        read -rp "The alias name(s): " db_server_list_input
        value_empty=`echo "${db_server_list_input}" | grep '\.' | wc -l`  >/dev/null 2>&1
        if [ $value_empty -ne 0 ] ; then
            error "Found dot character(.) in your input value. Do not include dot character(.)!"
            db_server_list_input=""
        else
            if [ -z $db_server_list_input ]; then
                error "Input valid value."
                db_server_list_input=""
            else
                break
            fi
        fi
    done

    # get db alias server from db_server_list_input
    OIFS=$IFS
    IFS=',' read -ra db_server_array <<< "$db_server_list_input"
    IFS=$OIFS

    db_server_number=${#db_server_array[@]}
}

function select_restricted_internet_access(){
    printf "\n"
    echo ""
    while true; do
        printf "\x1B[1mDo you want to restrict network egress to unknown external destinations for this deployment?\x1B[0m ${YELLOW_TEXT}\x1B[1;31m(NOTE: Business Automation Workflow $CP4BA_RELEASE_BASE prevents all network egress to unknown destinations by default. You can either (1) enable all egress or (2) accept the new default and create network policies to allow your specific communication targets as documented in the Workflow documentation.)\x1B[0m${RESET_TEXT} (Yes/No, default: Yes): "
        read -rp "" ans
        case "$ans" in
        "y"|"Y"|"yes"|"Yes"|"YES"|"")
            RESTRICTED_INTERNET_ACCESS="true"
            break
            ;;
        "n"|"N"|"no"|"No"|"NO")
            RESTRICTED_INTERNET_ACCESS="false"
            break
            ;;
        *)
            echo -e "Answer must be \"Yes\" or \"No\"\n"
            ;;
        esac
    done
}

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

function generate_create_secret_script(){
    local files=()
    local CREATE_SECRET_SCRIPT_FILE_TMP=$TEMP_FOLDER/create_secret.sh
    > ${CREATE_SECRET_SCRIPT_FILE_TMP}
    > ${CREATE_SECRET_SCRIPT_FILE}
    files=($(find $SECRET_FILE_FOLDER -name '*.yaml'))
    for item in ${files[*]}
    do
        echo "echo \"****************************************************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "echo \"******************************* START **************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "echo \"[INFO] Applying YAML template file: $item\"">> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "kubectl apply -f \"$item\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
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
        echo "echo \"[INFO] Executing shell script: $item\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "$item" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "echo \"******************************** END ***************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "echo \"****************************************************************************\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "printf \"\\n\"" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
        echo "" >> ${CREATE_SECRET_SCRIPT_FILE_TMP}
    done
    ${COPY_CMD} -rf ${CREATE_SECRET_SCRIPT_FILE_TMP} ${CREATE_SECRET_SCRIPT_FILE}
    chmod 755 $CREATE_SECRET_SCRIPT_FILE
}


function validate_secret_in_cluster(){
    INFO "Checking the Kubernetes secret required by IBM Business Automation Workflow on containers existing in cluster or not" 
    local files=()
    SECRET_CREATE_PASSED="true"
    files=($(find $SECRET_FILE_FOLDER -name '*.yaml'))
    for item in ${files[*]}
    do
        secret_name_tmp=`cat $item | ${YQ_CMD} r - metadata.name`
        if [ -z "$secret_name_tmp" ]; then
            error "Secret name not found in YAML file: \"$item\"! Check and fix it"
            exit 1
        else
            secret_exists=`kubectl get secret $secret_name_tmp --ignore-not-found | wc -l`  >/dev/null 2>&1
            if [ "$secret_exists" -ne 2 ] ; then
                error "Secret \"$secret_name_tmp\" not found in Kubernetes cluster! You must create it firstly before you deploy"
                SECRET_CREATE_PASSED="false"
            else
                success "Found secret \"$secret_name_tmp\" in Kubernetes cluster, PASSED!"              
            fi
        fi
    done
    
    files=($(find $SECRET_FILE_FOLDER -name '*.sh'))
    for item in ${files[*]}
    do
        secret_name_tmp=`cat $item | grep -oP '(?<=generic ).*?(?= --from-file)'`

        # for ACA secret format specially
        if [ -z "$secret_name_tmp" ]; then
            secret_name_tmp=`cat $item | grep -oP '(?<=generic ).*?(?= \\\\)' | tail -1`
        fi
        if [ -z "$secret_name_tmp" ]; then
            error "Secret name not found in shell script file: \"$item\"! Check and fix it"
            exit 1
        else
            secret_name_tmp=$(sed -e 's/^"//' -e 's/"$//' <<<"$secret_name_tmp")
            secret_exists=`kubectl get secret $secret_name_tmp --ignore-not-found | wc -l`  >/dev/null 2>&1
            if [ "$secret_exists" -ne 2 ] ; then
                error "Secret \"$secret_name_tmp\" not found in Kubernetes cluster! You must create it firstly before you deploy"
                SECRET_CREATE_PASSED="false"
            else
                success "Found secret \"$secret_name_tmp\" in Kubernetes cluster, PASSED!"              
            fi
        fi
    done
    if [[ $SECRET_CREATE_PASSED == "false" ]]; then
        info "Create secret in Kubernetes cluster correctly, exiting..."
        exit 1
    else
        INFO "All secrets created in Kubernetes cluster, PASSED!"
    fi
}

function validate_prerequisites(){
    # Validate license input from user_profile property
    INFO "Checking license required by BAW on containers"
    tmp_license_cp4ba=$(prop_user_profile_property_file CP4BA.CP4BA_LICENSE | tr '[:upper:]' '[:lower:]')
    tmp_license_fncm=$(prop_user_profile_property_file CP4BA.FNCM_LICENSE | tr '[:upper:]' '[:lower:]')
    tmp_license_baw=$(prop_user_profile_property_file CP4BA.BAW_LICENSE | tr '[:upper:]' '[:lower:]')

    if [[ -n "$tmp_license_cp4ba" ]]; then
        if [[ ! ($tmp_license_cp4ba == "non-production" || $tmp_license_cp4ba == "production") ]]; then
            error "CP4BA.CP4BA_LICENSE must be defined and must be in [non-production, production] in ${USER_PROFILE_PROPERTY_FILE}."
            exit 1
        fi
        success "The license for the CP4A deployment: ${tmp_license_cp4ba}"
    fi

    if [[ ! ($tmp_license_baw == "non-production" || $tmp_license_baw == "production" || $tmp_license_baw == "user") ]]; then
        error "CP4BA.BAW_LICENSE must be defined and must be in [user, non-production, production] in ${USER_PROFILE_PROPERTY_FILE}."
        exit 1
    fi
    success "The license for IBM Business Automation Workflow (BAW): ${tmp_license_cp4ba}"

    if [[ ! ($tmp_license_fncm == "non-production" || $tmp_license_fncm == "production" || $tmp_license_fncm == "user") ]]; then
        error "CP4BA.FNCM_LICENSE must be defined and must be in [user, non-production, production] in ${USER_PROFILE_PROPERTY_FILE}."
        exit 1
    fi
    success "The license for FileNet Content Manager (FNCM): ${tmp_license_cp4ba}"

    # Validate Secret for BAW on containers
    validate_secret_in_cluster

    # Validate LDAP connection for BAW on containers
    INFO "Checking LDAP connection required by BAW on containers" 
    tmp_servername="$(prop_ldap_property_file LDAP_SERVER)"
    tmp_serverport="$(prop_ldap_property_file LDAP_PORT)"
    tmp_basdn="$(prop_ldap_property_file LDAP_BASE_DN)"
    tmp_ldapssl="$(prop_ldap_property_file LDAP_SSL_ENABLED)"
    tmp_user=`kubectl get secret -l name=ldap-bind-secret -o yaml | ${YQ_CMD} r - items.[0].data.ldapUsername | base64 --decode`
    tmp_userpwd=`kubectl get secret -l name=ldap-bind-secret -o yaml | ${YQ_CMD} r - items.[0].data.ldapPassword | base64 --decode`

    tmp_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_servername")
    tmp_serverport=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_serverport")
    tmp_basdn=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_basdn")
    tmp_ldapssl=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldapssl")
    tmp_ldapssl=$(echo $tmp_ldapssl | tr '[:upper:]' '[:lower:]')
    tmp_user=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user")
    tmp_userpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_userpwd")

    verify_ldap_connection "$tmp_servername" "$tmp_serverport" "$tmp_basdn" "$tmp_user" "$tmp_userpwd" "$tmp_ldapssl"

    if [[ $SET_EXT_LDAP == "Yes" ]]; then
        # Validate External LDAP connection for BAW on containers
        msgB "Checking External LDAP connection.." 
        tmp_servername="$(prop_ext_ldap_property_file LDAP_SERVER)"
        tmp_serverport="$(prop_ext_ldap_property_file LDAP_PORT)"
        tmp_basdn="$(prop_ext_ldap_property_file LDAP_BASE_DN)"
        tmp_ldapssl="$(prop_ext_ldap_property_file LDAP_SSL_ENABLED)"
        tmp_user=`kubectl get secret -l name=ext-ldap-bind-secret -o yaml | ${YQ_CMD} r - items.[0].data.ldapUsername | base64 --decode`
        tmp_userpwd=`kubectl get secret -l name=ext-ldap-bind-secret -o yaml | ${YQ_CMD} r - items.[0].data.ldapPassword | base64 --decode`

        tmp_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_servername")
        tmp_serverport=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_serverport")
        tmp_basdn=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_basdn")
        tmp_ldapssl=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldapssl")
        tmp_ldapssl=$(echo $tmp_ldapssl | tr '[:upper:]' '[:lower:]')
        tmp_user=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user")
        tmp_userpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_userpwd")

        verify_ldap_connection "$tmp_servername" "$tmp_serverport" "$tmp_basdn" "$tmp_user" "$tmp_userpwd" "$tmp_ldapssl"

    fi

    # Validate DB connection
    INFO "Checking DB connection" 

    # check db connection for GCDDB
   
    # check DBNAME/DBUSER for GCDDB
    tmp_dbserver=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.gcd-db-server`
    tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.gcdDBUsername | base64 --decode`
    tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.gcdDBPassword | base64 --decode`        

    if [[ $DB_TYPE != "oracle" ]]; then
        tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.GCD_DB_NAME)"
    else
        tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.GCD_DB_USER_NAME)"
    fi
    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

    # Check DB connection for ssl/nonssl
    if [[ $DB_TYPE == "oracle" ]]; then
        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    else
        verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    fi

    # check db connection for FNCM ObjectStore
    if (( content_os_number > 0 )); then
        for ((j=0;j<${content_os_number};j++))
        do
            # tmp_dbserver=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
            tmp_dbserver="$(prop_db_name_user_property_file_for_server_name OS$((j+1))_DB_USER_NAME)"
            check_dbserver_name_valid $tmp_dbserver "OS$((j+1))_DB_USER_NAME"
            tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.os$((j+1))DBUsername | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.os$((j+1))DBPassword | base64 --decode`        

            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.OS$((j+1))_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.OS$((j+1))_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            fi
        done
    fi

    # check db connection for objectstore used by BAW authoring/BAW Runtime/BAW+AWS
    for i in "${!BAW_STD_OS_ARR[@]}"; do
        # tmp_dbserver=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
        tmp_dbserver="$(prop_db_name_user_property_file_for_server_name ${BAW_STD_OS_ARR[i]}_DB_USER_NAME)"
        check_dbserver_name_valid $tmp_dbserver "${BAW_STD_OS_ARR[i]}_DB_USER_NAME"
        tmp_label=$(echo ${BAW_STD_OS_ARR[i]}| tr '[:upper:]' '[:lower:]')
        tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBUsername | base64 --decode`
        tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBPassword | base64 --decode`        

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.${BAW_STD_OS_ARR[i]}_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.${BAW_STD_OS_ARR[i]}_DB_USER_NAME)"
        fi
        tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
        # Check DB non-SSL and SSL
        if [[ $DB_TYPE == "oracle" ]]; then
            verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        else
            verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        fi   
    done
    
    # check db connection for ICN
    if [[ $DB_TYPE != "oracle" ]]; then
        tmp_dbname="$(prop_db_name_user_property_file ICN_DB_NAME)"
    else
        tmp_dbname="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
    fi
    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

    tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
    tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.navigatorDBUsername | base64 --decode`
    tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.navigatorDBPassword | base64 --decode`        

    # Check DB non-SSL and SSL
    if [[ $DB_TYPE == "oracle" ]]; then
        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    else
        verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    fi

    # check db connection for BAW runtime
    # check baw runtime
    if [[ $DB_TYPE != "oracle" ]]; then
        tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
    else
        tmp_dbname="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
    fi
    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

    tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
    tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.dbUser | base64 --decode`
    tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.password | base64 --decode`        

    # Check DB non-SSL and SSL
    if [[ $DB_TYPE == "oracle" ]]; then
        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    else
        verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    fi
 
    # check db connection for UMSDB
    if [[ $DB_TYPE != "oracle" ]]; then
        tmp_dbname="$(prop_db_name_user_property_file UMS_DB_NAME)"
    else
        tmp_dbname="$(prop_db_name_user_property_file UMS_DB_USER_NAME)"
    fi
    tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

    tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
    tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.oauthDBUser | base64 --decode`
    tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.oauthDBPassword | base64 --decode`        

    # Check DB non-SSL and SSL
    if [[ $DB_TYPE == "oracle" ]]; then
        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    else
        verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    fi

    info "If all prerequisites check PASSED, you can run cp4a-deployment to deploy CP4BA. Otherwise, check your configuration again."
}
################################################
#### Begin - Main step for generate property and secrets and dbscripts and validation ####
################################################
# select_script_option2
# prompt_license
IBM_LICENS="Accept"


if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?i:p:n:t:a:m:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        m)  RUNTIME_MODE=$OPTARG
            if [[ $RUNTIME_MODE == "property" || $RUNTIME_MODE == "generate" || $RUNTIME_MODE == "validate" ||  $RUNTIME_MODE == "generate-cr" ]]; then
                echo
            else
                msg "Use a valid value: -m [property] or [generate] or [validate]"
                exit -1
            fi
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            show_help
            exit -1
            ;;
        esac
    done
fi

clear

if [[ $RUNTIME_MODE == "property" ]]; then
    input_information
    create_property_file
    clean_up_temp_file
fi
if [[ $RUNTIME_MODE == "generate" ]]; then
    # reload db type and OS number
    load_property_before_generate

    # Import function for DB Script
    source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/fncm/create-fncm-dbscript.sh

    # Import function for DB Script
    source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/baa/create-baa-dbscript.sh

    # Import function for DB Script
    source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/ban/create-ban-dbscript.sh

    # Import function for DB Script
    source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/baw-std/create-baw-dbscript.sh

    # Import function for DB Script
    source ${CUR_DIR}/helper/database-sql/${DB_TYPE}/ums/create-ums-dbscript.sh
    
    # check whether user already input value for the <Required>
    check_property_file
    create_db_script
    create_prerequisites
    clean_up_temp_file
    generate_create_secret_script
fi
if [[ $RUNTIME_MODE == "validate" ]]; then
    echo  "*****************************************************"
    echo  "Validating the prerequisites before you install BAW"
    echo  "*****************************************************"
    validate_kube_oc_cli
    load_property_before_generate
    validate_prerequisites
fi
if [[ $RUNTIME_MODE == "generate-cr" ]]; then
    # Import function for cr genration
    source ${CUR_DIR}/baw-std/baw-generate-cr.sh

    load_property_before_generate

    # User interaction, collect input 
    prompt_license
    select_profile_type
    get_deployment_hostname_suffix
    
    # Generate CR file
    generate_baw_std_cr_file
fi
################################################
#### End - Main step for generate property and secrets and dbscripts and validation ####
################################################