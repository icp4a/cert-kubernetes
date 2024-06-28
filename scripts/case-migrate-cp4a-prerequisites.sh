#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2022. All Rights Reserved.
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

	#Import & exeute cp4a-prerequisites
	#source ${CUR_DIR}/cp4a-prerequisites.sh

# Migration
JDBC_DRIVER_DIR=${CUR_DIR}/jdbc
MIG_ANS="No"
TOS_NUM=1
CASE_MIGRATION_PROPERTY_FILE=${PROPERTY_FILE_FOLDER}/cp4ba_case_migration.property
#CASE_MIGRATION_PROPERTY_FILE_JSON=${PROPERTY_FILE_FOLDER}/cp4ba_migration.json
#MULTI_TOS_PROPERTY_FILE_TEMP=${PROPERTY_FILE_FOLDER}/.multi_tos.property
#FOUNDATION_MIGRATION_FILE=${PARENT_DIR}/descriptors/cp4ba_icm_migration.property
CP4A_PATTERN_FILE_BAK_TEMP=$FINAL_CR_FOLDER/.ibm_cp4a_cr_final_temp.yaml
CP4A_PATTERN_FILE_BAK_TEMP_JSON=$FINAL_CR_FOLDER/.ibm_cp4a_cr_final_temp.json

#Migration
# To Create Property file for Migration
function create_case_migration_property_file() {


    # Save TOS OS Count
    echo "TOS_NUM=$TOS_NUM" >> ${TEMPORARY_PROPERTY_FILE}

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

    if [[ $pattern_list == *"workflow-authoring"* ]];
    then 
        #Updating BAS APPDB AAEDB ODMDB
        db_user_list+=",$(echo "$(prop_db_name_user_property_file STUDIO_DB_USER_NAME)" | sed 's/"//g')"
        db_user_pwd_list+=",$(echo "$(prop_db_name_user_property_file STUDIO_DB_USER_PASSWORD)" | sed 's/"//g')"
        db_name_list+=",$(echo "$(prop_db_name_user_property_file STUDIO_DB_NAME)" | sed 's/"//g')"
        

        option_component_list="$(prop_tmp_property_file OPTION_COMPONENT_LIST)"
        if [[ $option_component_list == *"app_designer"* ]];
        then 
            #db_user_list+=",$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)"
            db_user_list+=",$(echo "$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)" | sed 's/"//g')"
            db_user_pwd_list+=",$(echo "$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_PASSWORD)" | sed 's/"//g')"
            #db_user_pwd_list+=",$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_PASSWORD)"
            db_name_list+=",$(echo "$(prop_db_name_user_property_file APP_PLAYBACK_DB_NAME)" | sed 's/"//g')"
            #db_name_list+=",$(prop_db_name_user_property_file APP_PLAYBACK_DB_NAME)"

            #db_user_list+=",$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
            db_user_list+=",$(echo "$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)" | sed 's/"//g')"
            db_user_pwd_list+=",$(echo "$(prop_db_name_user_property_file APP_ENGINE_DB_USER_PASSWORD)" | sed 's/"//g')"
            #db_user_pwd_list+=",$(prop_db_name_user_property_file APP_ENGINE_DB_USER_PASSWORD)"
            #db_name_list+=",$(prop_db_name_user_property_file APP_ENGINE_DB_NAME)"
            db_name_list+=",$(echo "$(prop_db_name_user_property_file APP_ENGINE_DB_NAME)" | sed 's/"//g')"
        fi
    elif [[ $pattern_list == *"workflow-runtime"* ]];
    then 
        db_user_list+=",$(echo "$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)" | sed 's/"//g')"
        db_user_pwd_list+=",$(echo "$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_PASSWORD)" | sed 's/"//g')"
        db_name_list+=",$(echo "$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)" | sed 's/"//g')"

        db_user_list+=",$(echo "$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)" | sed 's/"//g')"
        db_user_pwd_list+=",$(echo "$(prop_db_name_user_property_file APP_ENGINE_DB_USER_PASSWORD)" | sed 's/"//g')"
        #db_user_pwd_list+=",$(prop_db_name_user_property_file APP_ENGINE_DB_USER_PASSWORD)"
        #db_name_list+=",$(prop_db_name_user_property_file APP_ENGINE_DB_NAME)"
        db_name_list+=",$(echo "$(prop_db_name_user_property_file APP_ENGINE_DB_NAME)" | sed 's/"//g')"

    fi

    option_component_list="$(prop_tmp_property_file PATTERN_NAME_LIST)"
    if [[ $option_component_list == *"Operational Decision Manager"* ]];
    then         
        db_user_list+=",$(echo "$(prop_db_name_user_property_file ODM_DB_USER_NAME)" | sed 's/"//g')"
        #db_user_list+=",$(prop_db_name_user_property_file ODM_DB_USER_NAME)"
        #db_user_pwd_list+=",$(prop_db_name_user_property_file ODM_DB_USER_PASSWORD)"
        db_user_pwd_list+=",$(echo "$(prop_db_name_user_property_file ODM_DB_USER_PASSWORD)" | sed 's/"//g')"
        #db_name_list+=",$(prop_db_name_user_property_file ODM_DB_NAME)"
        db_name_list+=",$(echo "$(prop_db_name_user_property_file ODM_DB_NAME)" | sed 's/"//g')"
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
            error "Not found secret name in YAML file: \"$item\"!  check and fix it"
            exit 1
        else
            secret_exists=`kubectl get secret $secret_name_tmp --ignore-not-found | wc -l`  >/dev/null 2>&1
            if [ "$secret_exists" -ne 2 ] ; then
                error "Not found secret \"$secret_name_tmp\" in Kubernetes cluster! create it firstly before deployment CP4BA"
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
            error "Not found secret name in shell script file: \"$item\"! check and fix it"
            exit 1
        else
            secret_name_tmp=$(sed -e 's/^"//' -e 's/"$//' <<<"$secret_name_tmp")
            secret_exists=`kubectl get secret $secret_name_tmp --ignore-not-found | wc -l`  >/dev/null 2>&1
            if [ "$secret_exists" -ne 2 ] ; then
                error "Not found secret \"$secret_name_tmp\" in Kubernetes cluster! create it firstly before deployment CP4BA"
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


function validate_case_migrate_prerequisites(){
    # validate the storage class
    INFO "Checking Slow/Medium/Fast/Block storage class required by CP4BA" 
    tmp_storage_classname=$(prop_user_profile_property_file CP4BA.SLOW_FILE_STORAGE_CLASSNAME)
    sample_pvc_name="cp4ba-test-slow-pvc-$RANDOM"
    verify_storage_class_valid $tmp_storage_classname "ReadWriteMany" $sample_pvc_name

    tmp_storage_classname=$(prop_user_profile_property_file CP4BA.MEDIUM_FILE_STORAGE_CLASSNAME)
    sample_pvc_name="cp4ba-test-medium-pvc-$RANDOM"
    verify_storage_class_valid $tmp_storage_classname "ReadWriteMany" $sample_pvc_name

    tmp_storage_classname=$(prop_user_profile_property_file CP4BA.FAST_FILE_STORAGE_CLASSNAME)
    sample_pvc_name="cp4ba-test-fase-pvc-$RANDOM"
    verify_storage_class_valid $tmp_storage_classname "ReadWriteMany" $sample_pvc_name

    tmp_storage_classname=$(prop_user_profile_property_file CP4BA.BLOCK_STORAGE_CLASS_NAME)
    sample_pvc_name="cp4ba-test-block-pvc-$RANDOM"
    verify_storage_class_valid $tmp_storage_classname "ReadWriteOnce" $sample_pvc_name

    if [[ $verification_sc_passed == "No" ]]; then
        kubectl delete pvc -l cp4ba=test-only >/dev/null 2>&1
        exit 0
    fi
    # Validate Secret for CP4BA
    validate_secret_in_cluster

    # Validate LDAP connection for CP4BA
    if [[ ! ("${#pattern_cr_arr[@]}" -eq "1" && "${pattern_cr_arr[@]}" =~ "workflow-process-service" && $LDAP_WFPS_AUTHORING == "No") ]]; then
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
            msgB "Checking the External LDAP connection.." 
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
    fi

    # Validate DB connection for CP4BA
    INFO "Checking DB connection required by CP4BA" 

    # check db connection for GCDDB
    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" || " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || " ${pattern_cr_arr[@]}" =~ "content" || " ${pattern_cr_arr[@]}" =~ "document_processing" || "${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
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
        if [[ " ${pattern_cr_arr[@]}" =~ "workflow-authoring" || (" ${pattern_cr_arr[@]}" =~ "workflow-runtime" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams")) || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then

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
            
        fi

        # check db connection for AWSDocs objectstore used by AWS only or BAW+AWS
        if [[ (" ${pattern_cr_arr[@]}" =~ "workstreams" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams")) || " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
            # tmp_dbserver=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
            tmp_dbserver="$(prop_db_name_user_property_file_for_server_name AWSDOCS_DB_USER_NAME)"
            check_dbserver_name_valid $tmp_dbserver "AWSDOCS_DB_USER_NAME"
            tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.awsdocsDBUsername | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.awsdocsDBPassword | base64 --decode`        

            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.AWSDOCS_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.AWSDOCS_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            fi
        fi

        # check db connection for objectstore used by AE data persistent
        if [[ " ${optional_component_cr_arr[@]}" =~ "ae_data_persistence" ]]; then
            i=$((TOS_NUM+2))
            tmp_label=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[$i].dc_aeos_os_label)

        
            # tmp_dbserver=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
            tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBUsername | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_label}DBPassword | base64 --decode`        

            tmp_dbname=$(${YQ_CMD} r ${CASE_MIGRATION_PROPERTY_FILE} datasource_configuration.dc_os_datasources[$i].dc_aeos_database_name)
            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            fi   
            
        fi

        # check db connection for objectstore used by ADP
        if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
            # tmp_dbserver=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.os-db-server`
            tmp_dbserver="$(prop_db_name_user_property_file_for_server_name DEVOS_DB_USER_NAME)"
            check_dbserver_name_valid $tmp_dbserver "DEVOS_DB_USER_NAME"
            tmp_dbusername=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.devos1DBUsername | base64 --decode`
            tmp_dbuserpassword=`kubectl get secret -l db-name=ibm-fncm-secret -o yaml | ${YQ_CMD} r - items.[0].data.devos1DBPassword | base64 --decode`        
 
            if [[ $DB_TYPE != "oracle" ]]; then
                tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.DEVOS_DB_NAME)"
            else
                tmp_dbname="$(prop_db_name_user_property_file $tmp_dbserver.DEVOS_DB_USER_NAME)"
            fi
            tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
            # Check DB non-SSL and SSL
            if [[ $DB_TYPE == "oracle" ]]; then
                verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            else
                verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
            fi
        fi
    fi

    # check db connection for ICN
    if [[ " ${foundation_component_arr[@]}" =~ "BAN" ]]; then
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
    fi

    # check db connection for ODM
    containsElement "decisions" "${pattern_cr_arr[@]}"
    odm_Val=$?
    if [[ $odm_Val -eq 0 ]]; then
        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file ODM_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file ODM_DB_USER_NAME)"
        fi
        tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

        tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
        tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.db-user | base64 --decode`
        tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.db-password | base64 --decode`        

        # Check DB non-SSL and SSL
        if [[ $DB_TYPE == "oracle" ]]; then
            verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        else
            verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        fi
    fi

    # check db connection for DPE Base DB
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_USER_NAME)"
        fi
        tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

        tmp_dbserver=`kubectl get secret -l base-db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.base-db-server`
        tmp_dbusername=`kubectl get secret -l base-db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.BASE_DB_USER | base64 --decode`
        tmp_dbuserpassword=`kubectl get secret -l base-db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.BASE_DB_CONFIG | base64 --decode`        

        # Check DB non-SSL and SSL
        if [[ $DB_TYPE == "oracle" ]]; then
            verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        else
            verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        fi
    fi

    # check db connection for DPE Project DB
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" ]]; then
        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_base_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_NAME)"
        else
            tmp_base_dbname="$(prop_db_name_user_property_file ADP_BASE_DB_USER_NAME)"
        fi
        tmp_base_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_base_dbname")

        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file ADP_PROJECT_DB_NAME)"
            tmp_dbusername="$(prop_db_name_user_property_file ADP_PROJECT_DB_USER_NAME)"
        else
            tmp_dbusername="$(prop_db_name_user_property_file ADP_PROJECT_DB_USER_NAME)"
        fi
        tmp_dbserver="$(prop_db_name_user_property_file ADP_PROJECT_DB_SERVER)"
        tmp_dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbserver")
        tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")
        tmp_dbusername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbusername")

        local db_name_array=()
        local db_user_array=()
        local db_server_array=()

        OIFS=$IFS
        IFS=',' read -ra db_name_array <<< "$tmp_dbname"
        IFS=',' read -ra db_user_array <<< "$tmp_dbusername"
        IFS=',' read -ra db_server_array <<< "$tmp_dbserver"
        IFS=$OIFS

        # tmp_dbserver=`kubectl get secret -l base-db-name=${tmp_base_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.base-db-server`
        # tmp_dbusername=`kubectl get secret -l base-db-name=${tmp_base_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.BASE_DB_USER | base64 --decode`

        if [[ ${#db_name_array[@]} != ${#db_user_array[@]} || ${#db_user_array[@]} != ${#db_server_array[@]} ]]; then
            fail "The number of values of: ADP_PROJECT_DB_NAME, ADP_PROJECT_DB_USER_NAME, ADP_PROJECT_DB_SERVER must all be equal. Exit ..."
        else
            # check connection for proj db 
            projs_max_index=${#db_name_array[@]}-1
           
            for num in "${!db_name_array[@]}"; do
                tmp_dbname=${db_name_array[num]}
                tmp_dbname=$(echo $tmp_dbname | tr '[:lower:]' '[:upper:]')
                tmp_dbusername=${db_user_array[num]}
                # tmp_dbuserpassword=${db_userpwd_array[num]}
                tmp_dbuserpassword=`kubectl get secret -l base-db-name=${tmp_base_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.${tmp_dbname}_DB_CONFIG | base64 --decode`
                tmp_dbserver=${db_server_array[num]}

                # Check DB non-SSL and SSL and SSL
                if [[ $DB_TYPE == "oracle" ]]; then
                    verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                else
                    verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
                fi
            done
        fi
    fi

    # check db connection for AE database
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing" || " ${pattern_cr_arr[@]}" =~ "application" ]]; then
        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file APP_ENGINE_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
        fi
        tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

        tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
        tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.AE_DATABASE_USER | base64 --decode`
        tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.AE_DATABASE_PWD | base64 --decode`        

        # Check DB non-SSL and SSL and SSL
        if [[ $DB_TYPE == "oracle" ]]; then
            verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        else
            verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        fi
    fi


    # # check db connection for BAW Authoring database
    # if [[ " ${pattern_cr_arr[@]}" =~ "workflow-authoring" ]]; then
    #     if [[ $DB_TYPE != "oracle" ]]; then
    #         tmp_dbname="$(prop_db_name_user_property_file AUTHORING_DB_NAME)"
    #     else
    #         tmp_dbname="$(prop_db_name_user_property_file AUTHORING_DB_USER_NAME)"
    #     fi
    #     tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

    #     tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
    #     tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.dbUser | base64 --decode`
    #     tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.password | base64 --decode`        

    #     # Check DB non-SSL and SSL
    #     if [[ $DB_TYPE == "oracle" ]]; then
    #         verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    #     else
    #         verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
    #     fi
    # fi

    # check db connection for BAW+AWS/BAW runtime/AWS

    if [[ " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ]]; then
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

        # check aws
        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file AWS_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
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
    elif [[ (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams") && " ${pattern_cr_arr[@]}" =~ "workstreams" ]]; then
        # check db connection for workflows
        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file AWS_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file AWS_DB_USER_NAME)"
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
    elif [[ " ${pattern_cr_arr[@]}" =~ "workflow-runtime" && (! " ${pattern_cr_arr[@]}" =~ "workflow-workstreams" ) ]]; then
        # check db connection for baw runtime
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
    fi

    # check db connection for Application Engine Playback database
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then
        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file APP_PLAYBACK_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file APP_PLAYBACK_DB_USER_NAME)"
        fi
        tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

        tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
        tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.AE_DATABASE_USER | base64 --decode`
        tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.AE_DATABASE_PWD | base64 --decode`        

        # Check DB non-SSL and SSL
        if [[ $DB_TYPE == "oracle" ]]; then
            verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        else
            verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        fi
    fi

    # check db connection for BAS
    if [[ " ${pattern_cr_arr[@]}" =~ "document_processing_designer" || "${pattern_cr_arr[@]}" =~ "workflow-authoring" || ("${pattern_cr_arr[@]}" =~ "workflow-process-service" && $EXTERNAL_DB_WFPS_AUTHORING == "Yes") || " ${optional_component_cr_arr[@]}" =~ "app_designer" || " ${optional_component_cr_arr[@]}" =~ "ads_designer" ]]; then 
        if [[ $DB_TYPE != "oracle" ]]; then
            tmp_dbname="$(prop_db_name_user_property_file STUDIO_DB_NAME)"
        else
            tmp_dbname="$(prop_db_name_user_property_file STUDIO_DB_USER_NAME)"
        fi
        tmp_dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_dbname")

        tmp_dbserver=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].metadata.labels.db-server`
        tmp_dbusername=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.dbUsername | base64 --decode`
        tmp_dbuserpassword=`kubectl get secret -l db-name=${tmp_dbname} -o yaml | ${YQ_CMD} r - items.[0].data.dbPassword | base64 --decode`
        # Check DB non-SSL and SSL
        if [[ $DB_TYPE == "oracle" ]]; then
            verify_db_connection "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        else
            verify_db_connection "${tmp_dbname}" "${tmp_dbusername}" "${tmp_dbuserpassword}" "${tmp_dbserver}"
        fi
    fi
  
    info "If all prerequisites check PASSED, you can run cp4a-deployment to deploy CP4BA. Otherwise, check configuration again."
    info "After CP4BA is deployed, refer to documentation for post-deployment steps."
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

function show_help() {
    echo -e "\nUsage: case-migrate-cp4a-prerequisites.sh -m [modetype]\n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -m  The valid mode types are: [property], [generate], or [validate]"
    echo "      STEP1: Run the script in [property] mode. Creates property files (DB/LDAP property file) with default values (database name/user)."
    echo "      STEP2: Modify the DB/LDAP/user property files with your values."
    echo "      STEP3: Run the script in [generate] mode. Generates the DB SQL statement files and YAML templates for the secrets based on the values in the property files."
    echo "      STEP4: Create the databases and secrets by using the modified DB SQL statement files and YAML templates for the secrets."
    echo "      STEP5: Run the script in [validate] mode. Checks whether the databases and the secrets are created before you install CP4BA."
}

################################################
#### Begin - Main step for install operator ####
################################################
# select_script_option2
# prompt_license

IBM_LICENS="Accept"
INSTALL_BAW_ONLY="No"

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
            if [[ $RUNTIME_MODE == "property" || $RUNTIME_MODE == "generate" || $RUNTIME_MODE == "validate" ]]; then
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

    #Import & exeute cp4a-prerequisites
    source ${CUR_DIR}/cp4a-prerequisites.sh

    if [ -e $CASE_MIGRATION_PROPERTY_FILE ] ; 
    then 
        rm -rf $CASE_MIGRATION_PROPERTY_FILE
    fi

    valid_int=false
    while [ "$valid_int" = false ]; do
        printf "\x1B[1mProvide Number of Target Object Stores \x1B[0m \x1B[33m[Minimum 1] \x1B[0m :"
        read -rp "" TOS_NUM
        #if [[ $TOS_NUM =~ ^[1-9]+$ ]];
        if [[ $TOS_NUM -ge 1 ]];
        then 
            valid_int=true
            success "Number of Target Object Stores provided : ${TOS_NUM}"
            create_case_migration_property_file
            ${SED_COMMAND_FORMAT} ${CASE_MIGRATION_PROPERTY_FILE}
            echo -e "Update the property file ${CASE_MIGRATION_PROPERTY_FILE} and rerun the migration with generate"
        else 
            echo -e "\x1B[1;31mProvide a valid input for Number of Target Object Stores\x1B[0m"
        fi
    done 

elif [[ $RUNTIME_MODE == "generate" ]]; then
    if [ -e $CASE_MIGRATION_PROPERTY_FILE ] ; 
        then  
            value_empty=0

            #Validate the property file for all Required Fields
            #value_empty=`grep "<Required>" "${CASE_MIGRATION_PROPERTY_FILE}" | wc -l`  >/dev/null 2>&1
            value_empty=$(grep "<Required>" "${CASE_MIGRATION_PROPERTY_FILE}" 2>/dev/null | wc -l)
            if [ $value_empty -ne 0 ] ; 
            then
                error "Found invalid value(s) \"<Required>\" in property file \"${CASE_MIGRATION_PROPERTY_FILE}\", input the correct value and rerun"
                exit 1
            fi
            #Validate the property file for Syntax errors
            if ! ${YQ_CMD} validate $CASE_MIGRATION_PROPERTY_FILE ;
            then 
                error "Invalid Property File Syntax (YAML): \"${CASE_MIGRATION_PROPERTY_FILE}\", correct the synatx and rerun"
                exit 1
            fi 
        #Import & exeute cp4a-prerequisites
        source ${CUR_DIR}/cp4a-prerequisites.sh
        create_secret_multi_tos    
        

    else 
        error "Migration property file : \"${CASE_MIGRATION_PROPERTY_FILE}\" not found , rerun the migration with -m property"
        exit 1
    fi
    ##########################################
    # Migration Function to do changes on cr based on migration requirement
    #migration_apply_pattern_cr  
    #echo -e "Generated CR is $CP4A_PATTERN_FILE_BAK"
    ##########################################


elif [[ $RUNTIME_MODE == "validate" ]]; then
    #exit 1
    echo  "*****************************************************"
    echo  "Validating the prerequisites before you install CP4BA"
    echo  "*****************************************************"
    validate_utility_tool_for_validation
    load_case_migrate_property_before_generate
    validate_case_migrate_prerequisites
fi

################################################
#### End - Main step for install operator ####
################################################
