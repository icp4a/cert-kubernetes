#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2022, 2023. All Rights Reserved.
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

LICENSE_BAW_URL="https://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-MVWM-ZKAC6A"
LICENSE_CP4A_URL="https://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-FNHF-F9RU7N"


######################################### Migration
JDBC_DRIVER_DIR=${CUR_DIR}/jdbc
MIG_ANS="No"
TOS_NUM=1
CASE_MIGRATION_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/baw_case_migration.property
#CASE_MIGRATION_PROPERTY_FILE_JSON=${PROPERTY_FILE_FOLDER}/cp4ba_migration.json
#MULTI_TOS_PROPERTY_FILE_TEMP=${PROPERTY_FILE_FOLDER}/.multi_tos.property
#FOUNDATION_MIGRATION_FILE=${PARENT_DIR}/descriptors/cp4ba_icm_migration.property
BAW_PATTERN_FILE_BAK=$FINAL_CR_FOLDER/ibm_cp4a_cr_production_FC_workflow-standalone_final.yaml
BAW_PATTERN_FILE_BAK_TEMP=$FINAL_CR_FOLDER/.ibm_cp4a_cr_production_FC_workflow-standalone_final.yaml
BAW_PATTERN_FILE_BAK_TEMP_JSON=$FINAL_CR_FOLDER/.ibm_cp4a_cr_production_FC_workflow-standalone_final.json
########################################

function show_help() {     
    echo -e "\nUsage: case-migrate-baw-prerequisites.sh -m [modetype]\n"     
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


# Migration 
# To replace parameters in cr file
function case_migration_replace(){
    local param_in1=$1
    local param_out1=$2
    local param_q1=$3

    local MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} $param_in1)
    #echo -e $MIG_PROP_TEMP
    if [ "$param_q1" = "q" ] ;
    then 
        if [ "$MIG_PROP_TEMP" = "*" ] ; then 
            ${YQ_CMD} w -i ${BAW_PATTERN_FILE_BAK_TEMP} $param_out1 --style=double "*"
        else 
            ${YQ_CMD} w -i ${BAW_PATTERN_FILE_BAK_TEMP} $param_out1 --style=double "${MIG_PROP_TEMP}"
        fi
    else 
        ${YQ_CMD} w -i  ${BAW_PATTERN_FILE_BAK_TEMP} $param_out1 "${MIG_PROP_TEMP}" 
    fi
    
}

#Migration
# To Create Property file for Migration
function create_case_migration_property_file() {


    # Save TOS OS Count
    echo "TOS_NUM=$TOS_NUM" >> ${TEMPORARY_PROPERTY_FILE}

    echo "EVENT_EMITTER_ENABLED=$EVENT_EMITTER_ENABLED" >> ${TEMPORARY_PROPERTY_FILE}

    local MIG_PROP_TEMP="<Required>"
    local MIG_COMMENT_TEMP="#"
    touch ${CASE_MIGRATION_PROPERTY_FILE}
    #${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "shared_configuration.sc_content_initialization" "false"
    #ICN details
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_icn_datasource.dc_icn_database_type" --style=double $DB_TYPE
    
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_icn_datasource.dc_common_icn_datasource_name" --style=double ${MIG_PROP_TEMP}
    ${SED_COMMAND}  -e "/dc_common_icn_datasource_name: \"$MIG_PROP_TEMP\"/s/^/    #  ####Provide the name of the Datasource for the ICN required by BAW authoring or BAW Runtime\n/" ${CASE_MIGRATION_PROPERTY_FILE}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_icn_datasource.dc_icn_database_servername" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_icn_datasource.dc_icn_database_name" --style=double "ICNDB"
    MIG_COMMENT_TEMP="#### For Oracle database_name and database_username should be same. For example:  ICNDB"
    ${SED_COMMAND}  -e "/dc_icn_database_name: \"ICNDB\"/s/^/    #  $MIG_COMMENT_TEMP\n/" ${CASE_MIGRATION_PROPERTY_FILE}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_icn_datasource.dc_icn_database_port" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_icn_datasource.dc_icn_database_username" --style=double "ICNDB"
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_icn_datasource.dc_icn_database_password" --style=double ${MIG_PROP_TEMP}
    if [[ $DB_TYPE == *"oracle"* ]];
    then 
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_icn_datasource.dc_icn_oracle_os_jdbc_url" --style=double "jdbc:oracle:thin:@//<oracle_server>:1521/orcl"
    fi 
    
    #GCD details
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_gcd_datasource.dc_gcd_database_type" --style=double $DB_TYPE
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_gcd_datasource.dc_common_gcd_datasource_name" --style=double ${MIG_PROP_TEMP}
    ${SED_COMMAND}  -e "/dc_common_gcd_datasource_name: \"$MIG_PROP_TEMP\"/s/^/    #  ####Provide the name of the Datasource for the GCD required by BAW authoring or BAW Runtime\n/" ${CASE_MIGRATION_PROPERTY_FILE}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_gcd_datasource.dc_common_gcd_xa_datasource_name" --style=double ${MIG_PROP_TEMP}
    ${SED_COMMAND}  -e "/dc_common_gcd_xa_datasource_name: \"$MIG_PROP_TEMP\"/s/^/    #  ####Provide the name of the Datasource for the GCD XA required by BAW authoring or BAW Runtime\n/" ${CASE_MIGRATION_PROPERTY_FILE}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_gcd_datasource.dc_gcd_database_servername" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_gcd_datasource.dc_gcd_database_name" --style=double "GCDDB"
    MIG_COMMENT_TEMP="#### For Oracle database_name and database_username should be same. For example:  GCDDB"
    ${SED_COMMAND}  -e "/dc_gcd_database_name: \"GCDDB\"/s/^/    #  $MIG_COMMENT_TEMP\n/" ${CASE_MIGRATION_PROPERTY_FILE}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_gcd_datasource.dc_gcd_database_port" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_gcd_datasource.dc_gcd_database_username" --style=double "GCDDB"
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_gcd_datasource.dc_gcd_database_password" --style=double ${MIG_PROP_TEMP}
    if [[ $DB_TYPE == *"oracle"* ]];
    then 
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_gcd_datasource.dc_gcd_oracle_os_jdbc_url" --style=double "jdbc:oracle:thin:@//<oracle_server>:1521/orcl"
    fi 

    #os datasource :
    #bawdocs
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_database_type" --style=double $DB_TYPE
    MIG_COMMENT_TEMP="#### Provide the name of the Datasource for the object store required by BAW authoring or BAW Runtime. For example: "BAWDOCS""
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_os_label" --style=double "BAWDOCS"
    ${SED_COMMAND}  -e "/dc_bawdocs_os_label: \"BAWDOCS\"/s/^/    #  $MIG_COMMENT_TEMP\n/" ${CASE_MIGRATION_PROPERTY_FILE}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_common_os_datasource_name" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_common_os_xa_datasource_name" --style=double ${MIG_PROP_TEMP}

    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_database_servername" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_database_name" --style=double "BAWDOCS"
    MIG_COMMENT_TEMP="#### For Oracle database_name and database_username should be same. For example:  BAWDOCS"
    ${SED_COMMAND}  -e "/dc_bawdocs_database_name: \"BAWDOCS\"/s/^/    #  $MIG_COMMENT_TEMP\n/" ${CASE_MIGRATION_PROPERTY_FILE}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_database_port" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_database_username" --style=double "BAWDOCS"
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_database_password" --style=double ${MIG_PROP_TEMP}
    if [[ $DB_TYPE == *"oracle"* ]];
    then 
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_oracle_os_jdbc_url" --style=double "jdbc:oracle:thin:@//<oracle_server>:1521/orcl"
    fi 


    #bawdos
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_database_type" --style=double $DB_TYPE
    MIG_COMMENT_TEMP="#### Provide the name of the Datasource for the Design object store required by BAW authoring or BAW Runtime. For example: "BAWDOS""
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_os_label" --style=double "BAWDOS"
    ${SED_COMMAND}  -e "/dc_bawdos_os_label: \"BAWDOS\"/s/^/    #  $MIG_COMMENT_TEMP\n/" ${CASE_MIGRATION_PROPERTY_FILE}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_common_os_datasource_name" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_common_os_xa_datasource_name" --style=double ${MIG_PROP_TEMP}

    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_database_servername" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_database_name" --style=double "BAWDOS"
    MIG_COMMENT_TEMP="#### For Oracle database_name and database_username should be same. For example:  BAWDOS"
    ${SED_COMMAND}  -e "/dc_bawdos_database_name: \"BAWDOS\"/s/^/    #  $MIG_COMMENT_TEMP\n/" ${CASE_MIGRATION_PROPERTY_FILE}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_database_port" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_database_username" --style=double "BAWDOS"
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_database_password" --style=double ${MIG_PROP_TEMP}
    if [[ $DB_TYPE == *"oracle"* ]];
    then 
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_oracle_os_jdbc_url" --style=double "jdbc:oracle:thin:@//<oracle_server>:1521/orcl"
    fi 


    #bawtos
    for ((i=2;i<$TOS_NUM+2;i++))
        do 
            #MIG_COMMENT_TEMP="Target Object Store Number " $((i-1))
            #echo "$DB_SERVER_PREFIX.APP_ENGINE_DB_NAME=\"AAEDB\"" >> ${DB_NAME_USER_PROPERTY_FILE}
            
            if [[ $TOS_NUM -gt 1 ]];
            then
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos$((i-1))_database_type" --style=double $DB_TYPE
                MIG_COMMENT_TEMP="#### Provide the name of the Datasource for the Target object store required by BAW authoring or BAW Runtime. For example:  BAWTOS$((i-1))"
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos$((i-1))_os_label" --style=double "BAWTOS$((i-1))"
                ${SED_COMMAND}  -e "/dc_bawtos$((i-1))_os_label: \"BAWTOS$((i-1))\"/s/^/    #  $MIG_COMMENT_TEMP\n/" ${CASE_MIGRATION_PROPERTY_FILE}
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos$((i-1))_common_os_datasource_name" --style=double ${MIG_PROP_TEMP}
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos$((i-1))_common_os_xa_datasource_name" --style=double ${MIG_PROP_TEMP}

                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos$((i-1))_database_servername" --style=double ${MIG_PROP_TEMP}
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos$((i-1))_database_name" --style=double "BAWTOS$((i-1))"
                MIG_COMMENT_TEMP="#### For Oracle database_name and database_username should be same. For example:  BAWDOS"
                ${SED_COMMAND}  -e "/dc_bawtos$((i-1))_database_name: \"BAWTOS$((i-1))\"/s/^/    #  $MIG_COMMENT_TEMP\n/" ${CASE_MIGRATION_PROPERTY_FILE}
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos$((i-1))_database_port" --style=double ${MIG_PROP_TEMP}
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos$((i-1))_database_username" --style=double "BAWTOS$((i-1))"
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos$((i-1))_database_password" --style=double ${MIG_PROP_TEMP}
                
                if [[ $DB_TYPE == *"oracle"* ]];
                then 
                    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos$((i-1))_oracle_os_jdbc_url" --style=double "jdbc:oracle:thin:@//<oracle_server>:1521/orcl"
                fi
            else
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos_database_type" --style=double $DB_TYPE
                MIG_COMMENT_TEMP="#### Provide the name of the Datasource for the Target object store required by BAW authoring or BAW Runtime. For example: BAWTOS"
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos_os_label" --style=double "BAWTOS"
                ${SED_COMMAND}  -e "/dc_bawtos_os_label: \"BAWTOS$((i-1))\"/s/^/    #  $MIG_COMMENT_TEMP\n/" ${CASE_MIGRATION_PROPERTY_FILE}
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos_common_os_datasource_name" --style=double ${MIG_PROP_TEMP}
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos_common_os_xa_datasource_name" --style=double ${MIG_PROP_TEMP}

                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos_database_servername" --style=double ${MIG_PROP_TEMP}
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos_database_name" --style=double "BAWTOS"
                MIG_COMMENT_TEMP="#### For Oracle database_name and database_username should be same. For example:  BAWTOS"
                ${SED_COMMAND}  -e "/dc_bawtos_database_name: \"BAWTOS\"/s/^/    #  $MIG_COMMENT_TEMP\n/" ${CASE_MIGRATION_PROPERTY_FILE}
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos_database_port" --style=double ${MIG_PROP_TEMP}
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos_database_username" --style=double "BAWTOS"
                ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos_database_password" --style=double ${MIG_PROP_TEMP}
                if [[ $DB_TYPE == *"oracle"* ]];
                then 
                    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_bawtos_oracle_os_jdbc_url" --style=double "jdbc:oracle:thin:@//<oracle_server>:1521/orcl"
                fi         
            fi           
        done

    #aeos data sources
    option_component_list="$(prop_tmp_property_file OPTION_COMPONENT_LIST)"
    if [[ $option_component_list == *"ae_data_persistence"* ]];
    then 
        i=$((TOS_NUM+2))
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_database_type" --style=double $DB_TYPE
        MIG_COMMENT_TEMP="#### Provide the name of the Datasource for the  object store required by BAW authoring or BAW Runtime. For example:  AEOS"
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_os_label" --style=double "AEOS"
        ${SED_COMMAND}  -e "/dc_aeos_os_label: \"AEOS\"/s/^/    #  $MIG_COMMENT_TEMP\n/" ${CASE_MIGRATION_PROPERTY_FILE}
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_common_os_datasource_name" --style=double ${MIG_PROP_TEMP}
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_common_os_xa_datasource_name" --style=double ${MIG_PROP_TEMP}
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_database_servername" --style=double ${MIG_PROP_TEMP}
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_database_name" --style=double "AEOS"
        MIG_COMMENT_TEMP="#### For Oracle database_name and database_username should be same. For example:  AEOS"
        ${SED_COMMAND}  -e "/dc_aeos_database_name: \"AEOS\"/s/^/    #  $MIG_COMMENT_TEMP\n/" ${CASE_MIGRATION_PROPERTY_FILE}
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_database_port" --style=double ${MIG_PROP_TEMP}
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_database_username" --style=double "AEOS"
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_database_password" --style=double ${MIG_PROP_TEMP}
        if [[ $DB_TYPE == *"oracle"* ]];
        then 
            ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_oracle_os_jdbc_url" --style=double "jdbc:oracle:thin:@//<oracle_server>:1521/orcl"
        fi    
        
    fi

    #cpe datasource 
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_database_type" --style=double $DB_TYPE
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_os_label" --style=double ${MIG_PROP_TEMP}
    ${SED_COMMAND}  -e "/dc_os_label: \"$MIG_PROP_TEMP\"/s/^/    #  ####Provide the Details for CPE required by BAW authoring or BAW Runtime\n/" ${CASE_MIGRATION_PROPERTY_FILE}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_common_cpe_datasource_name" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_common_cpe_xa_datasource_name" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_database_servername" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_database_name" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_database_port" --style=double ${MIG_PROP_TEMP}

    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_database_username" --style=double "CHOS"
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_database_password" --style=double ${MIG_PROP_TEMP}
    if [[ $DB_TYPE == *"oracle"* ]];
    then 
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_oracle_os_jdbc_url" --style=double "jdbc:oracle:thin:@//<oracle_server>:1521/orcl"
    fi  
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_common_conn_name" --style=double ${MIG_PROP_TEMP}


    #navigator_configuration
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "navigator_configuration.icn_production_setting.icn_jndids_name" --style=double ${MIG_PROP_TEMP}
    ${SED_COMMAND}  -e "/icn_jndids_name: \"$MIG_PROP_TEMP\"/s/^/    #  ####Provide the Details for Navigator required by BAW authoring or BAW Runtime\n/" ${CASE_MIGRATION_PROPERTY_FILE}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "navigator_configuration.icn_production_setting.icn_schema" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "navigator_configuration.icn_production_setting.icn_table_space" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "navigator_configuration.icn_production_setting.icn_admin" --style=double ${MIG_PROP_TEMP}


    #content_integration
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "content_integration.domain_name" --style=double ${MIG_PROP_TEMP}
    ${SED_COMMAND}  -e "/domain_name: \"$MIG_PROP_TEMP\"/s/^/    #  ####Provide the Details for Content Integration required by BAW authoring or BAW Runtime\n/" ${CASE_MIGRATION_PROPERTY_FILE}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "content_integration.object_store_name" --style=double ${MIG_PROP_TEMP}

    #case
    ${SED_COMMAND} -e "/object_store_name: \"$MIG_PROP_TEMP\"/a    #  ####Provide the Details for Case required by BAW authoring or BAW Runtime" ${CASE_MIGRATION_PROPERTY_FILE} 
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "case.domain_name" --style=double ${MIG_PROP_TEMP}
    ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "case.object_store_name_dos" --style=double ${MIG_PROP_TEMP}
    #tos_list
    
    for ((i=0;i<$TOS_NUM;i++))
    do
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "case.tos_list[$i].object_store_name" --style=double ${MIG_PROP_TEMP}
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "case.tos_list[$i].connection_point_name" --style=double ${MIG_PROP_TEMP}
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "case.tos_list[$i].desktop_id" --style=double ${MIG_PROP_TEMP}
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "case.tos_list[$i].target_environment_name" --style=double ${MIG_PROP_TEMP}
        ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "case.tos_list[$i].is_default"  ${MIG_PROP_TEMP}
    done

    
    if [[ "$EVENT_EMITTER_ENABLED" = true ]]; then
        for ((i=0;i<$TOS_NUM;i++))
        do
            ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "event_emitter[$i].tos_name" --style=double ${MIG_PROP_TEMP}
            ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "event_emitter[$i].connection_point_name" --style=double ${MIG_PROP_TEMP}
            ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "event_emitter[$i].date_sql" --style=double ${MIG_PROP_TEMP}
            ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "event_emitter[$i].logical_unique_id" --style=double ${MIG_PROP_TEMP}
            ${YQ_CMD} w -i ${CASE_MIGRATION_PROPERTY_FILE} "event_emitter[$i].solution_list" --style=double "*"
        done
    fi
}


#Migration
#Function to update Multi TOS db user & password into fncm secret yaml
create_secret_multi_tos() {
    local MIG_PROP_TEMP=""
    local MIG_PROP_KEY_TEMP=""
    local db_name_list=""
    local db_user_list=""
    local db_user_pwd_list=""
    local MIG_OS_TEMP=""
    
    ${YQ_CMD} d -i ${FNCM_SECRET_FILE} "stringData.aeosDBUsername"
    ${YQ_CMD} d -i ${FNCM_SECRET_FILE} "stringData.aeosDBPassword"
    ${YQ_CMD} d -i ${FNCM_SECRET_FILE} "stringData.bawdosDBUsername"
    ${YQ_CMD} d -i ${FNCM_SECRET_FILE} "stringData.bawdosDBPassword"
    ${YQ_CMD} d -i ${FNCM_SECRET_FILE} "stringData.bawdocsDBUsername"
    ${YQ_CMD} d -i ${FNCM_SECRET_FILE} "stringData.bawdocsDBPassword"
    ${YQ_CMD} d -i ${FNCM_SECRET_FILE} "stringData.bawtosDBUsername"
    ${YQ_CMD} d -i ${FNCM_SECRET_FILE} "stringData.bawtosDBPassword"
    
    #Updating GCD DB Username and Password
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_gcd_datasource.dc_gcd_database_username")
    ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.gcdDBUsername" --style=double ${MIG_PROP_TEMP}
    db_user_list=$MIG_PROP_TEMP
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_gcd_datasource.dc_gcd_database_password")
    echo  " ssl enabled : $tmp_postgresql_client_flag"
    db_user_pwd_list=$MIG_PROP_TEMP

    if [[ "${MIG_PROP_TEMP:0:8}" == "{Base64}"  ]]; then
        MIG_PROP_TEMP=$(echo "$MIG_PROP_TEMP" | sed -e "s/^{Base64}//" | base64 --decode)
    fi

    if [[ $DB_TYPE == *postgresql* ]]; then
        if [[ $tmp_postgresql_client_flag == "false" || $tmp_postgresql_client_flag == "no" || $tmp_postgresql_client_flag == "n" ]]; then
            ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.gcdDBPassword" --style=double ${MIG_PROP_TEMP}
        fi
    else 
        ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.gcdDBPassword" --style=double ${MIG_PROP_TEMP}
    fi
    
    db_name_list=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_gcd_datasource.dc_gcd_database_name")
    
    #OS details
    content_os_number="$(prop_tmp_property_file CONTENT_OS_NUMBER)"
    if [[ -n $content_os_number ]];
    then 
        for ((j=0;j<$content_os_number;j++))      
        do 
            db_user_list+=",$(echo "$(prop_db_name_user_property_file OS$((j+1))_DB_USER_NAME)" | sed 's/"//g')"
            db_user_pwd_list+=",$(echo "$(prop_db_name_user_property_file OS$((j+1))_DB_USER_PASSWORD)" | sed 's/"//g')"
            db_name_list+=",$(echo "$(prop_db_name_user_property_file OS$((j+1))_DB_NAME)" | sed 's/"//g')"
        done

    fi 

    #Updating ICN DB Username and Password
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_icn_datasource.dc_icn_database_username")
    db_user_list+=",$MIG_PROP_TEMP"
    ${YQ_CMD} w -i ${BAN_SECRET_FILE} "stringData.navigatorDBUsername" --style=double ${MIG_PROP_TEMP}
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_icn_datasource.dc_icn_database_password")
    db_user_pwd_list+=",$MIG_PROP_TEMP"

    if [[ "${MIG_PROP_TEMP:0:8}" == "{Base64}"  ]]; then
        MIG_PROP_TEMP=$(echo "$MIG_PROP_TEMP" | sed -e "s/^{Base64}//" | base64 --decode)
    fi
    if [[ $DB_TYPE == *postgresql* ]]; then
        
        if [[ $tmp_postgresql_client_flag == "false" || $tmp_postgresql_client_flag == "no" || $tmp_postgresql_client_flag == "n" ]]; then
            ${YQ_CMD} w -i ${BAN_SECRET_FILE} "stringData.navigatorDBPassword" --style=double ${MIG_PROP_TEMP}
        fi
    else 
        ${YQ_CMD} w -i ${BAN_SECRET_FILE} "stringData.navigatorDBPassword" --style=double ${MIG_PROP_TEMP}
    fi
    
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_icn_datasource.dc_icn_database_name")
    db_name_list+=",$MIG_PROP_TEMP"
    ${YQ_CMD} w -i ${BAN_SECRET_FILE} "metadata.labels.db-name" --style=double ${MIG_PROP_TEMP}

    
    #Updating BAWDOCS DB Username and Password
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_database_username")
    db_user_list+=",$MIG_PROP_TEMP"
    
    MIG_OS_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_os_label")
    #echo -e "Docs  is $MIG_OS_TEMP . "stringData.${MIG_OS_TEMP}DBUsername""
    ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBUsername" --style=double ${MIG_PROP_TEMP}
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_database_password")
    db_user_pwd_list+=",$MIG_PROP_TEMP"

    if [[ "${MIG_PROP_TEMP:0:8}" == "{Base64}"  ]]; then
        MIG_PROP_TEMP=$(echo "$MIG_PROP_TEMP" | sed -e "s/^{Base64}//" | base64 --decode)
    fi

    if [[ $DB_TYPE == *postgresql* ]]; then

        if [[ $tmp_postgresql_client_flag == "false" || $tmp_postgresql_client_flag == "no" || $tmp_postgresql_client_flag == "n" ]]; then
            ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
        fi
    else
        ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
    fi 

    
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[0].dc_bawdocs_database_name")
    db_name_list+=",$MIG_PROP_TEMP"

    #Updating BAWDOS DB Username and Password
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_database_username")
    db_user_list+=",$MIG_PROP_TEMP"

    MIG_OS_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_os_label")
    ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBUsername" --style=double ${MIG_PROP_TEMP}
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_database_password")
    db_user_pwd_list+=",$MIG_PROP_TEMP"

    if [[ "${MIG_PROP_TEMP:0:8}" == "{Base64}"  ]]; then
        MIG_PROP_TEMP=$(echo "$MIG_PROP_TEMP" | sed -e "s/^{Base64}//" | base64 --decode)
    fi

    if [[ $DB_TYPE == *postgresql* ]]; then
        if [[ $tmp_postgresql_client_flag == "false" || $tmp_postgresql_client_flag == "no" || $tmp_postgresql_client_flag == "n" ]]; then
            ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
        fi
    else 
        ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
    fi
    
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[1].dc_bawdos_database_name")
    db_name_list+=",$MIG_PROP_TEMP"

    #Updating TOS DB names in secret
    TOS_NUM="$(prop_tmp_property_file TOS_NUM)"
        
    if [[ $TOS_NUM -eq 1 ]];
    then 
        MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[2].dc_bawtos_database_username")
        db_user_list+=",$MIG_PROP_TEMP"
        MIG_OS_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[2].dc_bawtos_os_label")

        ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBUsername" --style=double ${MIG_PROP_TEMP}
        MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[2].dc_bawtos_database_password")
        db_user_pwd_list+=",$MIG_PROP_TEMP"

        if [[ "${MIG_PROP_TEMP:0:8}" == "{Base64}"  ]]; then
            MIG_PROP_TEMP=$(echo "$MIG_PROP_TEMP" | sed -e "s/^{Base64}//" | base64 --decode)
        fi

        if [[ $DB_TYPE == *postgresql* ]]; then
            if [[ $tmp_postgresql_client_flag == "false" || $tmp_postgresql_client_flag == "no" || $tmp_postgresql_client_flag == "n" ]]; then
                ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
            fi
        else 
            ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
        fi
        #${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
        MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[2].dc_bawtos_database_name")
        db_name_list+=",$MIG_PROP_TEMP"
    elif [[ $TOS_NUM -gt 1 ]];
    then
       
        for ((i=1;i<$TOS_NUM+1;i++))                
        do
            MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$((i+1))].dc_bawtos$((i))_database_username")
            
            MIG_PROP_KEY_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$((i+1))].dc_bawtos$((i))_os_label")
            MIG_PROP_KEY_TEMP="stringData."$MIG_PROP_KEY_TEMP"DBUsername"
            db_user_list+=",$MIG_PROP_TEMP"
            ${YQ_CMD} w -i ${FNCM_SECRET_FILE} ${MIG_PROP_KEY_TEMP} --style=double ${MIG_PROP_TEMP}

            
            MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$((i+1))].dc_bawtos$((i))_database_password")
            #echo -e "$MIG_PROP_TEMP"
            MIG_PROP_KEY_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$((i+1))].dc_bawtos$((i))_os_label")
            MIG_PROP_KEY_TEMP="stringData."$MIG_PROP_KEY_TEMP"DBPassword"
            db_user_pwd_list+=",$MIG_PROP_TEMP"

            if [[ "${MIG_PROP_TEMP:0:8}" == "{Base64}"  ]]; then
                MIG_PROP_TEMP=$(echo "$MIG_PROP_TEMP" | sed -e "s/^{Base64}//" | base64 --decode)
            fi
            if [[ $DB_TYPE == *postgresql* ]]; then
                if [[ $tmp_postgresql_client_flag == "false" || $tmp_postgresql_client_flag == "no" || $tmp_postgresql_client_flag == "n" ]]; then
                    ${YQ_CMD} w -i ${FNCM_SECRET_FILE} ${MIG_PROP_KEY_TEMP} --style=double ${MIG_PROP_TEMP}
                fi
            else
                ${YQ_CMD} w -i ${FNCM_SECRET_FILE} ${MIG_PROP_KEY_TEMP} --style=double ${MIG_PROP_TEMP}
            fi
            
            #${YQ_CMD} w -i ${FNCM_SECRET_FILE} ${MIG_PROP_KEY_TEMP} --style=double ${MIG_PROP_TEMP}

            MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$((i+1))].dc_bawtos$((i))_database_name")
            db_name_list+=",$MIG_PROP_TEMP"
            
        done
    fi
    

    #Updating cpe details    
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_database_username")
    db_user_list+=",$MIG_PROP_TEMP"
    MIG_OS_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_os_label")

    ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBUsername" --style=double ${MIG_PROP_TEMP}
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_database_password")
    db_user_pwd_list+=",$MIG_PROP_TEMP"

    if [[ "${MIG_PROP_TEMP:0:8}" == "{Base64}"  ]]; then
        MIG_PROP_TEMP=$(echo "$MIG_PROP_TEMP" | sed -e "s/^{Base64}//" | base64 --decode)
    fi
    if [[ $DB_TYPE == *postgresql* ]]; then
        if [[ $tmp_postgresql_client_flag == "false" || $tmp_postgresql_client_flag == "no" || $tmp_postgresql_client_flag == "n" ]]; then
            ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
        fi
    else 
        ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
    fi

    #${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
    MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_cpe_datasources[0].dc_database_name")
    db_name_list+=",$MIG_PROP_TEMP"

    #aeos data sources
    option_component_list="$(prop_tmp_property_file OPTION_COMPONENT_LIST)"
    if [[ $option_component_list == *"ae_data_persistence"* ]];
    then 
        i=$((TOS_NUM+2))
        MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_database_username")
        db_user_list+=",$MIG_PROP_TEMP"
        MIG_OS_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_os_label")

        ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBUsername" --style=double ${MIG_PROP_TEMP}
        MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_database_password")
        db_user_pwd_list+=",$MIG_PROP_TEMP"

        if [[ "${MIG_PROP_TEMP:0:8}" == "{Base64}"  ]]; then
            MIG_PROP_TEMP=$(echo "$MIG_PROP_TEMP" | sed -e "s/^{Base64}//" | base64 --decode)
        fi

        if [[ $DB_TYPE == *postgresql* ]]; then

            if [[ $tmp_postgresql_client_flag == "false" || $tmp_postgresql_client_flag == "no" || $tmp_postgresql_client_flag == "n" ]]; then
                ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
            fi
        else 
            ${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
        fi 
        #${YQ_CMD} w -i ${FNCM_SECRET_FILE} "stringData.${MIG_OS_TEMP}DBPassword" --style=double ${MIG_PROP_TEMP}
        MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "datasource_configuration.dc_os_datasources[$i].dc_aeos_database_name")
        db_name_list+=",$MIG_PROP_TEMP"
    fi

    ${SED_COMMAND} '/'"DB_USER_LIST"'/d' ${TEMPORARY_PROPERTY_FILE}
    ${SED_COMMAND} '/'"DB_USER_PWD_LIST"'/d' ${TEMPORARY_PROPERTY_FILE}

    if [[ "$DB_TYPE" != "oracle" ]];
    then 
        ${SED_COMMAND} '/'"DB_NAME_LIST"'/d' ${TEMPORARY_PROPERTY_FILE}
        echo "DB_NAME_LIST=$db_name_list" >> ${TEMPORARY_PROPERTY_FILE}
    fi
    echo "DB_USER_LIST=$db_user_list" >> ${TEMPORARY_PROPERTY_FILE}
    echo "DB_USER_PWD_LIST=$db_user_pwd_list" >> ${TEMPORARY_PROPERTY_FILE}
    #echo -e "$db_name_list"


}



function load_case_migrate_property_before_generate(){
    if [[ ! -f $TEMPORARY_PROPERTY_FILE || ! -f $CASE_MIGRATION_PROPERTY_FILE || ! -f $DB_NAME_USER_PROPERTY_FILE || ! -f $DB_SERVER_INFO_PROPERTY_FILE || ! -f $LDAP_PROPERTY_FILE ]]; then
        fail "Not Found existing property file under \"$PROPERTY_FILE_FOLDER\""
        exit 1
    fi

    TOS_NUM="$(prop_tmp_property_file TOS_NUM)"
    # load pattern into pattern_cr_arr
    pattern_list="$(prop_tmp_property_file PATTERN_LIST)"
    optional_component_list="$(prop_tmp_property_file OPTION_COMPONENT_LIST)"
    foundation_list="$(prop_tmp_property_file FOUNDATION_LIST)"
    OIFS=$IFS
    IFS=',' read -ra pattern_cr_arr <<< "$pattern_list"
    IFS=',' read -ra optional_component_cr_arr <<< "$optional_component_list"
    IFS=',' read -ra foundation_component_arr <<< "$foundation_list"
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

    # load LDAP/DB required flag for wfps
    LDAP_WFPS_AUTHORING=$(prop_tmp_property_file LDAP_WFPS_AUTHORING_FLAG)
    EXTERNAL_DB_WFPS_AUTHORING=$(prop_tmp_property_file EXTERNAL_DB_WFPS_AUTHORING_FLAG)
}



function validate_case_migrate_prerequisites(){
    # Validate license input from user_profile property
    INFO "Checking license required by CP4BA"
    tmp_license_cp4ba=$(prop_user_profile_property_file CP4BA.CP4BA_LICENSE | tr '[:upper:]' '[:lower:]')
    tmp_license_fncm=$(prop_user_profile_property_file CP4BA.FNCM_LICENSE | tr '[:upper:]' '[:lower:]')
    tmp_license_baw=$(prop_user_profile_property_file CP4BA.BAW_LICENSE | tr '[:upper:]' '[:lower:]')

    if [[ ! ($tmp_license_cp4ba == "non-production" || $tmp_license_cp4ba == "production") ]]; then
        error "CP4BA.CP4BA_LICENSE must be defined and must be in [non-production, production] in ${USER_PROFILE_PROPERTY_FILE}."
        exit 1
    fi
    success "The license for the CP4A deployment: ${tmp_license_cp4ba}"

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

    # Validate Secret for CP4BA
    validate_secret_in_cluster

    # Validate LDAP connection for CP4BA
    INFO "Checking LDAP connection required by CP4BA" 
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
        # Validate External LDAP connection for CP4BA
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

    #prop_db_name_migration_property "datasource_configuration.dc_gcd_datasource.dc_gcd_database_name"

    tmp_dbname=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_gcd_datasource.dc_gcd_database_name)
    
    # Check DB connection for ssl/nonssl
    if [[ $DB_TYPE == "oracle" ]]; then
        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        #echo "Current tmp_dbusername = $tmp_dbusername"
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


    #bawdocs            
    #tmp_dbserver=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[0].dc_bawdocs_database_servername)
    #tmp_dbserver=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[0].dc_bawdocs_database_username)
    tmp_label=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[0].dc_bawdocs_os_label)
    tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBUsername | base64 --decode`
    tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBPassword | base64 --decode`        
    tmp_dbname=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[0].dc_bawdocs_database_name)

    if [[ $DB_TYPE == "oracle" ]]; then
        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    else
        verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    fi  
    
    
    #bawdos
    #tmp_dbserver=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[1].dc_bawdos_database_username)
    tmp_label=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[1].dc_bawdos_os_label)
    tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBUsername | base64 --decode`
    tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBPassword | base64 --decode`        

    #echo "Show tmp_dbusername = $tmp_dbusername"
    
    tmp_dbname=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[1].dc_bawdos_database_name)

    if [[ $DB_TYPE == "oracle" ]]; then
        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    else
        verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    fi  
    

    
    #bawtos
    TOS_NUM="$(prop_tmp_property_file TOS_NUM)"
    if [[ $TOS_NUM -eq 1 ]];
    then 
        tmp_label=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[2].dc_bawtos1_os_label)
        tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBUsername | base64 --decode`
        tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBPassword | base64 --decode`        
        #echo "Show tmp_dbusername = $tmp_dbusername"
        
        tmp_dbname=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[2].dc_bawtos_database_name)

        if [[ $DB_TYPE == "oracle" ]]; then
            verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        else
            verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        fi  
        
    elif [[ $TOS_NUM -gt 1 ]];
    then
        for ((i=1;i<$TOS_NUM+1;i++))                
        do
            tmp_label=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[$((i+1))].dc_bawtos$((i))_os_label)
            tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBUsername | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBPassword | base64 --decode`        
            #echo "Show tmp_dbusername = $tmp_dbusername"
            
            tmp_dbname=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[$((i+1))].dc_bawtos$((i))_database_name)
            echo "tmp_dbname value is $tmp_dbname"
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            fi  

        done
    fi

    
    
    # check db connection for case history

    #tmp_dbserver="$(prop_db_name_user_property_file_for_server_name CHOS_DB_USER_NAME)"
    
    #check_dbserver_name_valid $tmp_dbserver "CHOS_DB_USER_NAME"
    # tmp_label=$(echo ${BAW_AUTH_OS_ARR[i]}| tr '[:upper:]' '[:lower:]')
    tmp_label=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_cpe_datasources[0].dc_os_label)
    tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBUsername | base64 --decode`
    tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBPassword | base64 --decode`        
    
    
    tmp_dbname=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_cpe_datasources[0].dc_database_name)
    # Check DB non-SSL and SSL
    if [[ $DB_TYPE == "oracle" ]]; then
        verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    else
        verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    fi
    

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
   
    info "If all prerequisites check PASSED, you can run cp4a-deployment to deploy CP4BA. Otherwise, check configuration again."

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

    if [[ ! ( "${input_servername}" == \#* ) ]]; then
        if [[ ! (" ${tmp_db_array[@]}" =~ "${input_servername}") ]]; then
            error "The prefix \"$input_servername\" in front of \"$parameter_name\" is not in the definition DB_SERVER_LIST=\"${temp}\", Check the following example to configure"
            echo -e "***************** example *****************"
            echo -e "if DB_SERVER_LIST=\"DBSERVER1\""
            echo -e "You need to change"
            echo -e "<DB_SERVER_NAME>.GCD_DB_NAME=\"GCDDB\""
            echo -e "to"
            echo -e "DBSERVER1.GCD_DB_NAME=\"GCDDB\""
            echo -e "***************** example *****************"
            exit 1
        fi
    fi
}

function prop_db_name_migration_property() {

    tmp_dbname="$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} $1)"
    
}

function validate_secret_in_cluster(){
    INFO "Checking the Kubernetes secret required by CP4BA existing in cluster or not" 
    local files=()
    SECRET_CREATE_PASSED="true"
    files=($(find $SECRET_FILE_FOLDER -name '*.yaml'))
    for item in ${files[*]}
    do
        secret_name_tmp=`cat $item | ${YQ_CMD} r - metadata.name`
        if [ -z "$secret_name_tmp" ]; then
            error "Not found secret name in YAML file: \"$item\"! Check and fix it"
            exit 1
        else
            secret_exists=`kubectl get secret $secret_name_tmp --ignore-not-found | wc -l`  >/dev/null 2>&1
            if [ "$secret_exists" -ne 2 ] ; then
                error "Not found secret \"$secret_name_tmp\" in Kubernetes cluster! Create it firstly before deployment CP4BA"
                SECRET_CREATE_PASSED="false"
            else
                success "Found secret \"$secret_name_tmp\" in Kubernetes cluster, PASSED!"              
            fi
        fi
    done
    
    files=($(find $SECRET_FILE_FOLDER -name '*.sh'))
    for item in ${files[*]}
    do
        if [[ "$machine" == "Mac" ]]; then
            secret_name_tmp=`grep ' create secret generic' $item | tail -1 | cut -d'"' -f2`

            # for DPE secret format specially
            if [ -z "$secret_name_tmp" ]; then
                secret_name_tmp=`grep ' create secret generic' $item | tail -1 | cut -d'"' -f2`
            fi
        else
            secret_name_tmp=`cat $item | grep -oP '(?<=generic ).*?(?= --from-file)'`

            # for DPE secret format specially
            if [ -z "$secret_name_tmp" ]; then
                secret_name_tmp=`cat $item | grep -oP '(?<=generic ).*?(?= \\\\)' | tail -1`
            fi

        fi
        if [ -z "$secret_name_tmp" ]; then
            error "Not found secret name in shell script file: \"$item\"! Check and fix it"
            exit 1
        else
            secret_name_tmp=$(sed -e 's/^"//' -e 's/"$//' <<<"$secret_name_tmp")
            secret_exists=`kubectl get secret $secret_name_tmp --ignore-not-found | wc -l`  >/dev/null 2>&1
            if [ "$secret_exists" -ne 2 ] ; then
                error "Not found secret \"$secret_name_tmp\" in Kubernetes cluster! Create it firstly before deployment CP4BA"
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



function containsElement(){
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

function validate_utility_tool_for_validation(){
    which kubectl &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e  "\x1B[1;31mUnable to locate Kubernetes CLI. You must install it to run this script.\x1B[0m" && \
        while true; do
            printf "\x1B[1mDo you want install the Kubernetes CLI by the cp4a-prerequisites.sh script? (Yes/No): \x1B[0m"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                install_kubectl_cli
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                info "Must install the Kubernetes CLI to continue the next validation"
                exit 1
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    fi
    which java &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e  "\x1B[1;31mUnable to locate java. You must install it to run this script.\x1B[0m" && \
        while true; do
            printf "\x1B[1mDo you want install the IBM JRE by the cp4a-prerequisites.sh script? (Yes/No): \x1B[0m"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                install_ibm_jre
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                info "Must install the IBM JRE or other JRE to continue the next validation"
                exit 1
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    else
        java -version &>/dev/null
        if [[ $? -ne 0 ]]; then
            echo -e  "\x1B[1;31mUnable to locate a Java Runtime. You must install JRE to run this script.\x1B[0m" && \
            while true; do
                printf "\x1B[1mDo you want install the IBM JRE by the cp4a-prerequisites.sh script? (Yes/No): \x1B[0m"
                read -rp "" ans
                case "$ans" in
                "y"|"Y"|"yes"|"Yes"|"YES")
                    install_ibm_jre
                    break
                    ;;
                "n"|"N"|"no"|"No"|"NO")
                    info "Must install the IBM JRE or other JRE to continue next validation"
                    exit 1
                    ;;
                *)
                    echo -e "Answer must be \"Yes\" or \"No\"\n"
                    ;;
                esac
            done    
        fi
    fi
    which keytool &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e  "\x1B[1;31mUnable to locate keytool. You must add it in \"\$PATH\" to run this script.\x1B[0m" && \
        exit 1
    else
        keytool -help &>/dev/null
        if [[ $? -ne 0 ]]; then
            echo -e  "\x1B[1;31mUnable to locate keytool. You must install the IBM JRE or other JRE and add keytool in \"\$PATH\" to run this script\x1B[0m" && \
            exit 1     
        fi
    fi

    which openssl &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e  "\x1B[1;31mUnable to locate openssl. You must install it to run this script.\x1B[0m" && \
        while true; do
            printf "\x1B[1mDo you want install the OpenSSL by the cp4a-prerequisites.sh script? (Yes/No): \x1B[0m"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                install_openssl
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                info "Must install the OpenSSL to continue next validation"
                exit 1
                ;;
            *)
                echo -e "Answer must be \"Yes\" or \"No\"\n"
                ;;
            esac
        done
    fi
}





# Migration 
# Begin - Modify the Genrated CR for Migration
function case_migration_apply_pattern_cr() {

    local os_num_cr=0
    local os_num_prop=0
    local initial_os_cr=0
    local content_os_number=0

    if [ -e $BAW_PATTERN_FILE_BAK ] ; 
    then  
        ${COPY_CMD} -rf "${BAW_PATTERN_FILE_BAK}" "${BAW_PATTERN_FILE_BAK_TEMP}"
        #echo -e "Temp file created"
    else 
        error "CR Generation Failed"
        exit 1
    fi

    #Retrieve TO OS Number 
    TOS_NUM="$(prop_tmp_property_file TOS_NUM)"
    #echo -e "Tos Number fromn file is : $TOS_NUM"
    ## Removing the initialize_configuration Section from CR 
    ## This section is not needed because you are reusing the existing FileNet domain, Object stores, and LDAP.
    ${YQ_CMD} d -i ${BAW_PATTERN_FILE_BAK_TEMP} spec.initialize_configuration
    
    # Updating icn datasource value 
    ${SED_COMMAND_FORMAT} ${CASE_MIGRATION_PROPERTY_FILE}
    #sc_content_initialization
    ${YQ_CMD} w -i  ${BAW_PATTERN_FILE_BAK_TEMP} "spec.shared_configuration.sc_content_initialization" "false" 
    #case_migration_replace "shared_configuration.sc_content_initialization" "spec.shared_configuration.sc_content_initialization"

    #icn datasource
    case_migration_replace "datasource_configuration.dc_icn_datasource.dc_icn_database_type" "spec.datasource_configuration.dc_icn_datasource.dc_database_type" "q"
    case_migration_replace "datasource_configuration.dc_icn_datasource.dc_common_icn_datasource_name" "spec.datasource_configuration.dc_icn_datasource.dc_common_icn_datasource_name" "q"
    case_migration_replace "datasource_configuration.dc_icn_datasource.dc_icn_database_servername" "spec.datasource_configuration.dc_icn_datasource.database_servername" "q"
    case_migration_replace "datasource_configuration.dc_icn_datasource.dc_icn_database_name" "spec.datasource_configuration.dc_icn_datasource.database_name" "q"
    case_migration_replace "datasource_configuration.dc_icn_datasource.dc_icn_database_port" "spec.datasource_configuration.dc_icn_datasource.database_port" "q"
    if [[ $DB_TYPE == *"oracle"* ]];
    then 
        case_migration_replace "datasource_configuration.dc_icn_datasource.dc_icn_oracle_os_jdbc_url" "spec.datasource_configuration.dc_icn_datasource.dc_oracle_icn_jdbc_url" "q"
    fi


    #GCD datasource
    case_migration_replace "datasource_configuration.dc_gcd_datasource.dc_gcd_database_type" "spec.datasource_configuration.dc_gcd_datasource.dc_database_type" "q"
    case_migration_replace "datasource_configuration.dc_gcd_datasource.dc_common_gcd_datasource_name" "spec.datasource_configuration.dc_gcd_datasource.dc_common_gcd_datasource_name" "q"
    case_migration_replace "datasource_configuration.dc_gcd_datasource.dc_common_gcd_xa_datasource_name" "spec.datasource_configuration.dc_gcd_datasource.dc_common_gcd_xa_datasource_name" "q"
    case_migration_replace "datasource_configuration.dc_gcd_datasource.dc_gcd_database_servername" "spec.datasource_configuration.dc_gcd_datasource.database_servername" "q"
    case_migration_replace "datasource_configuration.dc_gcd_datasource.dc_gcd_database_name" "spec.datasource_configuration.dc_gcd_datasource.database_name" "q"
    case_migration_replace "datasource_configuration.dc_gcd_datasource.dc_gcd_database_port" "spec.datasource_configuration.dc_gcd_datasource.database_port" "q"
    if [[ $DB_TYPE == *"oracle"* ]];
    then 
        case_migration_replace "datasource_configuration.dc_gcd_datasource.dc_gcd_oracle_os_jdbc_url" "spec.datasource_configuration.dc_gcd_datasource.dc_oracle_gcd_jdbc_url" "q"
    fi 

    

    content_os_number="$(prop_tmp_property_file CONTENT_OS_NUMBER)"
    #echo -e "Total content_os_number Objects in CR : $content_os_number"
    os_num_cr=$((os_num_cr + content_os_number + TOS_NUM + 2 ))
    initial_os_cr=$((initial_os_cr + content_os_number ))
    os_num_prop=$((os_num_prop + TOS_NUM +2 ))
    #echo -e "Total os_num_prop Objects in CR : $os_num_prop"

    local prop_flag=false    
    #echo -e "Total OS Objects in CR : $os_num_cr"
    #echo -e "Total OS Objects in Property File : $os_num_prop"
    local os_count=$initial_os_cr
    for ((j=0;j<${os_num_prop};j++))
        do
            
            if [[ $j -eq 0 ]];
            then 
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdocs_database_type" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_database_type" "q"
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdocs_os_label" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_os_label" "q"
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdocs_common_os_datasource_name" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_common_os_datasource_name" "q"
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdocs_common_os_xa_datasource_name" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_common_os_xa_datasource_name" "q"
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdocs_database_servername" "spec.datasource_configuration.dc_os_datasources[$os_count].database_servername" "q"
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdocs_database_name" "spec.datasource_configuration.dc_os_datasources[$os_count].database_name" "q"
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdocs_database_port" "spec.datasource_configuration.dc_os_datasources[$os_count].database_port" "q"
                if [[ $DB_TYPE == *"oracle"* ]];
                then 
                    case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdocs_oracle_os_jdbc_url" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_oracle_os_jdbc_url" "q"
                fi
                ((os_count++))
            elif [[ $j -eq 1 ]];
            then 
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdos_database_type" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_database_type" "q"
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdos_os_label" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_os_label" "q"
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdos_common_os_datasource_name" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_common_os_datasource_name" "q"
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdos_common_os_xa_datasource_name" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_common_os_xa_datasource_name" "q"
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdos_database_servername" "spec.datasource_configuration.dc_os_datasources[$os_count].database_servername" "q"
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdos_database_name" "spec.datasource_configuration.dc_os_datasources[$os_count].database_name" "q"
                case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdos_database_port" "spec.datasource_configuration.dc_os_datasources[$os_count].database_port" "q"
                if [[ $DB_TYPE == *"oracle"* ]];
                then 
                    case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawdos_oracle_os_jdbc_url" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_oracle_os_jdbc_url" "q"
                fi

                ((os_count++))
            else 
                if [[ $TOS_NUM -eq 1 ]] && [[ $j -eq 2 ]];
                then 
                    case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos_database_type" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_database_type" "q"
                    case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos_os_label" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_os_label" "q"
                    case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos_common_os_datasource_name" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_common_os_datasource_name" "q"
                    case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos_common_os_xa_datasource_name" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_common_os_xa_datasource_name" "q"
                    case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos_database_servername" "spec.datasource_configuration.dc_os_datasources[$os_count].database_servername" "q"
                    case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos_database_name" "spec.datasource_configuration.dc_os_datasources[$os_count].database_name" "q"
                    case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos_database_port" "spec.datasource_configuration.dc_os_datasources[$os_count].database_port" "q"
                    if [[ $DB_TYPE == *"oracle"* ]];
                    then
                        case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos_oracle_os_jdbc_url" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_oracle_os_jdbc_url" "q"
                    fi
                    ((os_count++))
                else 
                    if [[ "$prop_flag" = false ]] && [[ $TOS_NUM -gt 1 ]];
                    then
                        ${YQ_CMD} w -i ${BAW_PATTERN_FILE_BAK_TEMP} "spec.datasource_configuration.dc_os_datasources[$os_count].dc_database_type" --style=double "BAWTOS_START"
                        
                        for ((i=1;i<$TOS_NUM;i++))
                        do
                            #rm -rf $MULTI_TOS_PROPERTY_FILE_TEMP
                            #touch $MULTI_TOS_PROPERTY_FILE_TEMP

                            content_start="$(grep -n "BAWTOS_START" ${BAW_PATTERN_FILE_BAK_TEMP} |  head -n 1 | cut -d: -f1)"
                            #content_tmp="$(tail -n +$content_start < ${BAW_PATTERN_FILE_BAK_TEMP} | grep -n "dc_os_datasources:" | head -n1 | cut -d: -f1)"
                            content_tmp=$(( $content_start - 1))
                            content_tmp="$(tail -n +$content_start < ${BAW_PATTERN_FILE_BAK_TEMP} | grep -n "dc_hadr_max_retries_for_client_reroute:" | head -n1 | cut -d: -f1)"
                            content_stop=$(( $content_start + $content_tmp - 1))
                            #echo -e "Content Start Line : ${content_start} And Content End Line : ${content_stop}"
                            vi ${BAW_PATTERN_FILE_BAK_TEMP} -c ':'"${content_start}"','"${content_stop}"' copy '"${content_stop}"'' -c ':wq' >/dev/null 2>&1
                        done
                        prop_flag=true
                    fi
                    if [[ "$prop_flag" = true ]];
                    then
                        case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos$((j-1))_database_type" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_database_type" "q"
                        case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos$((j-1))_os_label" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_os_label" "q"
                        case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos$((j-1))_common_os_datasource_name" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_common_os_datasource_name" "q"
                        case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos$((j-1))_common_os_xa_datasource_name" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_common_os_xa_datasource_name" "q"
                        case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos$((j-1))_database_servername" "spec.datasource_configuration.dc_os_datasources[$os_count].database_servername" "q"
                        case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos$((j-1))_database_name" "spec.datasource_configuration.dc_os_datasources[$os_count].database_name" "q"
                        case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos$((j-1))_database_port" "spec.datasource_configuration.dc_os_datasources[$os_count].database_port" "q"
                        if [[ $DB_TYPE == *"oracle"* ]];
                        then
                            case_migration_replace "datasource_configuration.dc_os_datasources[$j].dc_bawtos$((j-1))_oracle_os_jdbc_url" "spec.datasource_configuration.dc_os_datasources[$os_count].dc_oracle_os_jdbc_url" "q"
                        fi
                        ((os_count++))
                    fi
                fi

            fi
        done            

    #Cpe Database
    case_migration_replace "datasource_configuration.dc_cpe_datasources[0].dc_database_type" "spec.datasource_configuration.dc_cpe_datasources[0].dc_database_type" "q"
    case_migration_replace "datasource_configuration.dc_cpe_datasources[0].dc_os_label" "spec.datasource_configuration.dc_cpe_datasources[0].dc_os_label" "q"
    case_migration_replace "datasource_configuration.dc_cpe_datasources[0].dc_common_cpe_datasource_name" "spec.datasource_configuration.dc_cpe_datasources[0].dc_common_cpe_datasource_name" "q"
    case_migration_replace "datasource_configuration.dc_cpe_datasources[0].dc_common_cpe_xa_datasource_name" "spec.datasource_configuration.dc_cpe_datasources[0].dc_common_cpe_xa_datasource_name" "q"
    case_migration_replace "datasource_configuration.dc_cpe_datasources[0].dc_database_servername" "spec.datasource_configuration.dc_cpe_datasources[0].database_servername" "q"
    case_migration_replace "datasource_configuration.dc_cpe_datasources[0].dc_database_name" "spec.datasource_configuration.dc_cpe_datasources[0].database_name" "q"
    case_migration_replace "datasource_configuration.dc_cpe_datasources[0].dc_database_port" "spec.datasource_configuration.dc_cpe_datasources[0].database_port" "q"
    case_migration_replace "datasource_configuration.dc_cpe_datasources[0].dc_common_conn_name" "spec.datasource_configuration.dc_cpe_datasources[0].dc_common_conn_name" "q"
    if [[ $DB_TYPE == *"oracle"* ]];
    then
        case_migration_replace "datasource_configuration.dc_cpe_datasources[0].dc_oracle_os_jdbc_url" "spec.datasource_configuration.dc_cpe_datasources[0].dc_oracle_os_jdbc_url" "q"
    fi

    #Updating jdbc url if db type is oracle for icn ,gcd , bawaeos , cpe
    

    #Navigator Configuration
    case_migration_replace "navigator_configuration.icn_production_setting.icn_jndids_name" "spec.navigator_configuration.icn_production_setting.icn_jndids_name" "q"
    case_migration_replace "navigator_configuration.icn_production_setting.icn_schema" "spec.navigator_configuration.icn_production_setting.icn_schema" "q"
    case_migration_replace "navigator_configuration.icn_production_setting.icn_table_space" "spec.navigator_configuration.icn_production_setting.icn_table_space" "q"
    case_migration_replace "navigator_configuration.icn_production_setting.icn_admin" "spec.navigator_configuration.icn_production_setting.icn_admin" "q"




    #content_integration
    case_migration_replace "content_integration.domain_name" "spec.baw_configuration[0].content_integration.domain_name" "q"
    case_migration_replace "content_integration.object_store_name" "spec.baw_configuration[0].content_integration.object_store_name" "q"

    #Case
    case_migration_replace "case.domain_name" "spec.baw_configuration[0].case.domain_name" "q"
    case_migration_replace "case.object_store_name_dos" "spec.baw_configuration[0].case.object_store_name_dos" "q"
    
    #case_migration_replace "case.object_store_name_tos" "spec.baw_configuration.case.object_store_name_tos" "q"
    #case_migration_replace "case.connection_point_name_tos" "spec.baw_configuration.case.connection_point_name_tos" "q"
    #tos_list
    prop_flag=false
    local temp_flag=false

    for ((j=0;j<$TOS_NUM;j++))
    do
        case_migration_replace "case.tos_list[$j].object_store_name" "spec.baw_configuration[0].case.tos_list[$j].object_store_name" "q"
        case_migration_replace "case.tos_list[$j].connection_point_name" "spec.baw_configuration[0].case.tos_list[$j].connection_point_name" "q"
        case_migration_replace "case.tos_list[$j].desktop_id" "spec.baw_configuration[0].case.tos_list[$j].desktop_id" "q"
        case_migration_replace "case.tos_list[$j].target_environment_name" "spec.baw_configuration[0].case.tos_list[$j].target_environment_name" "q"
        case_migration_replace "case.tos_list[$j].is_default" "spec.baw_configuration[0].case.tos_list[$j].is_default" 

        local temp_flag=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} "case.tos_list[$j].is_default")

        if [[ "$temp_flag" = true ]]; then
           case_migration_replace "case.tos_list[$j].object_store_name" "spec.verify_configuration.vc_cpe_verification.vc_cpe_folder[0].folder_cpe_obj_store_name" "q" 
           case_migration_replace "case.tos_list[$j].object_store_name" "spec.verify_configuration.vc_cpe_verification.vc_cpe_document[0].doc_cpe_obj_store_name" "q" 
           case_migration_replace "case.tos_list[$j].object_store_name" "spec.verify_configuration.vc_cpe_verification.vc_cpe_cbr[0].cbr_cpe_obj_store_name" "q" 
           case_migration_replace "case.tos_list[$j].connection_point_name" "spec.verify_configuration.vc_cpe_verification.vc_cpe_workflow[0].workflow_cpe_connection_point" "q" 

           case_migration_replace "case.tos_list[$j].object_store_name" "spec.baw_configuration[0].federation_config.case_manager[0].object_store_name" "q" 

           prop_flag=true
           temp_flag=false
        fi 
    done
    

    if [[ "$prop_flag" = false ]]; then
        
        ${YQ_CMD} w -i ${BAW_PATTERN_FILE_BAK_TEMP} "spec.baw_configuration[0].case.tos_list[0].is_default" "true"
        case_migration_replace "case.tos_list[0].object_store_name" "spec.verify_configuration.vc_cpe_verification.vc_cpe_folder[0].folder_cpe_obj_store_name" "q" 
        case_migration_replace "case.tos_list[0].object_store_name" "spec.verify_configuration.vc_cpe_verification.vc_cpe_document[0].doc_cpe_obj_store_name" "q" 
        case_migration_replace "case.tos_list[0].object_store_name" "spec.verify_configuration.vc_cpe_verification.vc_cpe_cbr[0].cbr_cpe_obj_store_name" "q" 
        case_migration_replace "case.tos_list[0].connection_point_name" "spec.verify_configuration.vc_cpe_verification.vc_cpe_workflow[0].workflow_cpe_connection_point" "q" 
        case_migration_replace "case.tos_list[0].object_store_name" "spec.baw_configuration[0].federation_config.case_manager[0].object_store_name" "q" 
    fi


    EVENT_EMITTER_ENABLED="$(prop_tmp_property_file EVENT_EMITTER_ENABLED)"

    if [[ "$EVENT_EMITTER_ENABLED" = true ]];then
        for ((j=0;j<$TOS_NUM;j++))
        do  
            case_migration_replace "event_emitter[$j].tos_name" "spec.baw_configuration[0].case.event_emitter[$j].tos_name" "q"
            case_migration_replace "event_emitter[$j].connection_point_name" "spec.baw_configuration[0].case.event_emitter[$j].connection_point_name" "q"
            case_migration_replace "event_emitter[$j].date_sql" "spec.baw_configuration[0].case.event_emitter[$j].date_sql" "q"
            case_migration_replace "event_emitter[$j].logical_unique_id" "spec.baw_configuration[0].case.event_emitter[$j].logical_unique_id" "q"
            #MIG_PROP_TEMP=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} event_emitter[$j].solution_list)
            case_migration_replace "event_emitter[$j].solution_list" ""spec.baw_configuration[0].case.event_emitter[$j].solution_list"" "q"
        done
    fi

    ## Copying the Final CR after Modifications for Migration
    ${COPY_CMD} -rf "${BAW_PATTERN_FILE_BAK_TEMP}" "${BAW_PATTERN_FILE_BAK}"
    rm -rf "${BAW_PATTERN_FILE_BAK_TEMP}"
    ${SED_COMMAND_FORMAT} ${BAW_PATTERN_FILE_BAK}


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

    #Import & exeute baw-prerequisites
    source ${CUR_DIR}/baw-prerequisites.sh

    #input_information
    #create_property_file
    #clean_up_temp_file
    if [ -e $CASE_MIGRATION_PROPERTY_FILE ] ; 
    then 
        rm -rf $CASE_MIGRATION_PROPERTY_FILE
    fi

    valid_int=false
    while [ "$valid_int" = false ]; do
        printf "\x1B[1mProvide Number of Target Object Stores \x1B[0m \x1B[33m[Minimum 1] \x1B[0m :"
        read -rp "" TOS_NUM
        
        if [[ $TOS_NUM -ge 1 ]];
        then 
            valid_int=true
            success "Number of Target Object Stores provided : ${TOS_NUM}"
            create_case_migration_property_file
            ${SED_COMMAND_FORMAT} ${CASE_MIGRATION_PROPERTY_FILE}
            echo -e  "\x1B[33;5m* [baw_case_migration.property]:\x1B[0m"
            echo -e "  - Update the property file ${CASE_MIGRATION_PROPERTY_FILE} and rerun the migration with generate"
        else 
            echo -e "\x1B[1;31mProvide a valid input for Number of Target Object Stores\x1B[0m"
            
        fi
    done 

fi
if [[ $RUNTIME_MODE == "generate" ]]; then
   if [ -e $CASE_MIGRATION_PROPERTY_FILE ] ; 
        then  
            value_empty=0

            #Validate the property file for all Required Fields
            #value_empty=`grep "<Required>" "${CASE_MIGRATION_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
            value_empty=$(grep "<Required>" "${CASE_MIGRATION_PROPERTY_FILE}" 2>/dev/null | wc -l)
            if [ $value_empty -ne 0 ] ; 
            then
                error "Found invalid value(s) \"<Required>\" in property file \"${CASE_MIGRATION_PROPERTY_FILE}\", Input the correct value and rerun"
                exit 1
            fi
            #Validate the property file for Syntax errors
            if ! ${YQ_CMD} validate $CASE_MIGRATION_PROPERTY_FILE ;
            then 
                error "Invalid Property File Syntax (YAML): \"${CASE_MIGRATION_PROPERTY_FILE}\", Correct the synatx and rerun"
                exit 1
            fi 
        #Import & exeute baw-prerequisites
        source ${CUR_DIR}/baw-prerequisites.sh
        create_secret_multi_tos   
    else 
        error "Migration property file : \"${CASE_MIGRATION_PROPERTY_FILE}\" not found , Rerun the migration with -m property"
        exit 1
    fi
fi
if [[ $RUNTIME_MODE == "validate" ]]; then
    #Import & exeute baw-prerequisites
    #source ${CUR_DIR}/baw-prerequisites.sh
    #exit 1
    echo  "*****************************************************"
    echo  "Validating the prerequisites before you install CP4BA"
    echo  "*****************************************************"
    validate_utility_tool_for_validation
    load_case_migrate_property_before_generate
    validate_case_migrate_prerequisites
fi
if [[ $RUNTIME_MODE == "generate-cr" ]]; then
    source ${CUR_DIR}/baw-prerequisites.sh
    if [ -e $CASE_MIGRATION_PROPERTY_FILE ] ; 
    then  
        value_empty=0

        #Validate the property file for all Required Fields
        value_empty=`grep "<Required>" "${CASE_MIGRATION_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
        if [ $value_empty -ne 0 ] ; 
        then
            error "Found invalid value(s) \"<Required>\" in property file \"${CASE_MIGRATION_PROPERTY_FILE}\", input the correct value and rerun the migration"
            exit 1
        fi
        #Validate the property file for Syntax errors
        if ! ${YQ_CMD} validate $CASE_MIGRATION_PROPERTY_FILE ;
        then 
            error "Invalid Property File Syntax (YAML): \"${CASE_MIGRATION_PROPERTY_FILE}\", Correct the synatx and rerun the migration"
            exit 1
        fi 
    else 
        error "Migration Property File not Found: \"${CASE_MIGRATION_PROPERTY_FILE}\", Rerun the case-migrate-baw-prerequisites.sh to create the file"   
        exit 1
    fi
            
        
    ##########################################
    # Migration Function to do changes on cr based on migration requirement
    case_migration_apply_pattern_cr  
    echo -e "Generated CR is $BAW_PATTERN_FILE_BAK"
    ##########################################
    ##########################################
    ##########################################

fi
################################################
#### End - Main step for generate property and secrets and dbscripts and validation ####
################################################