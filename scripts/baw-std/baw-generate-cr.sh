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

# Import variables for BAW STD configurations
source ${CUR_DIR}/baw-property.sh

function func_sync_profile_size_into_cr() {
    profile_size=$(echo $PROFILE_TYPE | tr '[:upper:]' '[:lower:]')

    # set sc_deployment_profile_size
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_profile_size $profile_size

    case "$profile_size" in
    "small")
        ban_footprint_profile=( "${BAN_FOOTPRINT_PROFILE_SMALL[@]}" )
        fncm_cpe_footprint_profile=( "${FNCM_CPE_FOOTPRINT_PROFILE_SMALL[@]}" )
        fncm_cmis_footprint_profile=( "${FNCM_CMIS_FOOTPRINT_PROFILE_SMALL[@]}" )
        fncm_graphql_footprint_profile=( "${FNCM_GRAPHQL_FOOTPRINT_PROFILE_SMALL[@]}" )
        rr_footprint_profile=( "${RR_FOOTPRINT_PROFILE_SMALL[@]}" )
        ae_footprint_profile=( "${AE_FOOTPRINT_PROFILE_SMALL[@]}" )
        baw_std_footprint_profile=( "${BAW_STD_FOOTPRINT_PROFILE_SMALL[@]}" )
        pfs_footprint_profile=( "${PFS_FOOTPRINT_PROFILE_SMALL[@]}" )
        es_footprint_profile=( "${ES_FOOTPRINT_PROFILE_SMALL[@]}" )
        ;;
    "medium")
        ban_footprint_profile=( "${BAN_FOOTPRINT_PROFILE_MEDIUM[@]}" )
        fncm_cpe_footprint_profile=( "${FNCM_CPE_FOOTPRINT_PROFILE_MEDIUM[@]}" )
        fncm_cmis_footprint_profile=( "${FNCM_CMIS_FOOTPRINT_PROFILE_MEDIUM[@]}" )
        fncm_graphql_footprint_profile=( "${FNCM_GRAPHQL_FOOTPRINT_PROFILE_MEDIUM[@]}" )
        rr_footprint_profile=( "${RR_FOOTPRINT_PROFILE_MEDIUM[@]}" )
        ae_footprint_profile=( "${AE_FOOTPRINT_PROFILE_MEDIUM[@]}" )
        baw_std_footprint_profile=( "${BAW_STD_FOOTPRINT_PROFILE_MEDIUM[@]}" )
        pfs_footprint_profile=( "${PFS_FOOTPRINT_PROFILE_MEDIUM[@]}" )
        es_footprint_profile=( "${ES_FOOTPRINT_PROFILE_MEDIUM[@]}" )
        ;;
    "large")
        ban_footprint_profile=( "${BAN_FOOTPRINT_PROFILE_LARGE[@]}" )
        fncm_cpe_footprint_profile=( "${FNCM_CPE_FOOTPRINT_PROFILE_LARGE[@]}" )
        fncm_cmis_footprint_profile=( "${FNCM_CMIS_FOOTPRINT_PROFILE_LARGE[@]}" )
        fncm_graphql_footprint_profile=( "${FNCM_GRAPHQL_FOOTPRINT_PROFILE_LARGE[@]}" )
        rr_footprint_profile=( "${RR_FOOTPRINT_PROFILE_LARGE[@]}" )
        ae_footprint_profile=( "${AE_FOOTPRINT_PROFILE_LARGE[@]}" )
        baw_std_footprint_profile=( "${BAW_STD_FOOTPRINT_PROFILE_LARGE[@]}" )
        pfs_footprint_profile=( "${PFS_FOOTPRINT_PROFILE_LARGE[@]}" )
        es_footprint_profile=( "${ES_FOOTPRINT_PROFILE_LARGE[@]}" )
        ;;
    *)
        ban_footprint_profile=( "${BAN_FOOTPRINT_PROFILE_SMALL[@]}" )
        fncm_cpe_footprint_profile=( "${FNCM_CPE_FOOTPRINT_PROFILE_SMALL[@]}" )
        fncm_cmis_footprint_profile=( "${FNCM_CMIS_FOOTPRINT_PROFILE_SMALL[@]}" )
        fncm_graphql_footprint_profile=( "${FNCM_GRAPHQL_FOOTPRINT_PROFILE_SMALL[@]}" )
        rr_footprint_profile=( "${RR_FOOTPRINT_PROFILE_SMALL[@]}" )
        ae_footprint_profile=( "${AE_FOOTPRINT_PROFILE_SMALL[@]}" )
        baw_std_footprint_profile=( "${BAW_STD_FOOTPRINT_PROFILE_SMALL[@]}" )
        pfs_footprint_profile=( "${PFS_FOOTPRINT_PROFILE_SMALL[@]}" )
        es_footprint_profile=( "${ES_FOOTPRINT_PROFILE_SMALL[@]}" )
       ;;
    esac

    # set BAN resources according profile size
    ban_configuration==`cat $BAW_STD_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.navigator_configuration`
    if [[ -n "${ban_configuration}" ]]; then
        for profile in "${ban_footprint_profile[@]}"; do
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} ${profile%%:*} ${profile#*:}
        done
    fi

    # set FNCM - CPE resources according profile size
    cpe_configuration=`cat $BAW_STD_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.ecm_configuration.cpe`
    if [[ -n "${cpe_configuration}" ]]; then
        for profile in "${fncm_cpe_footprint_profile[@]}"; do
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} ${profile%%:*} ${profile#*:}
        done
    fi

    # set FNCM - CMIS resources according profile size
    cmis_configuration=`cat $BAW_STD_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.ecm_configuration.cmis`
    if [[ -n "${cmis_configuration}" ]]; then
        for profile in "${fncm_cmis_footprint_profile[@]}"; do
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} ${profile%%:*} ${profile#*:}
        done
    fi

    # set FNCM - GRAPHQL resources according profile size
    graphql_configuration=`cat $BAW_STD_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.ecm_configuration.graphql`
    if [[ -n "${graphql_configuration}" ]]; then
        for profile in "${fncm_graphql_footprint_profile[@]}"; do
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} ${profile%%:*} ${profile#*:}
        done
    fi

    # set RR resources according profile size
    rr_configuration=`cat $BAW_STD_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.resource_registry_configuration`
    if [[ -n "${rr_configuration}" ]]; then
        for profile in "${rr_footprint_profile[@]}"; do
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} ${profile%%:*} ${profile#*:}
        done
    fi

    # set AE resources according profile size
    ae_configuration=`cat $BAW_STD_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.application_engine_configuration`
    if [[ -n "${ae_configuration}" ]]; then
        for profile in "${ae_footprint_profile[@]}"; do
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} ${profile%%:*} ${profile#*:}
        done
    fi

    # set BAW STD resources according profile size
    baw_configuration=`cat $BAW_STD_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.baw_configuration`
    if [[ -n "${baw_configuration}" ]]; then
        for profile in "${baw_std_footprint_profile[@]}"; do
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} ${profile%%:*} ${profile#*:}
        done
    fi

    # set PFS resources according profile size
    pfs_configuration=`cat $BAW_STD_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.pfs_configuration`
    if [[ -n "${pfs_configuration}" ]]; then
        for profile in "${pfs_footprint_profile[@]}"; do
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} ${profile%%:*} ${profile#*:}
        done
    fi

    # set Elasticsearch resources according profile size
    es_configuration=`cat $BAW_STD_PATTERN_FILE_TMP | ${YQ_CMD} r - spec.elasticsearch_configuration`
    if [[ -n "${es_configuration}" ]]; then
        for profile in "${es_footprint_profile[@]}"; do
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} ${profile%%:*} ${profile#*:}
        done
    fi
}

# Applying value in GCDDB property file into final CR
function func_sync_gcd_ds_property_into_cr(){
    tmp_gcd_db_servername="$(prop_db_name_user_property_file_for_server_name GCD_DB_USER_NAME)"
    tmp_gcd_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_gcd_db_servername")

    if [[ $DB_TYPE == "oracle" ]]; then
        tmp_gcd_db_name="$(prop_db_name_user_property_file GCD_DB_USER_NAME)"
    else
        tmp_gcd_db_name="$(prop_db_name_user_property_file GCD_DB_NAME)"
    fi
    tmp_gcd_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_gcd_db_name")
    if [[ $DB_TYPE == "postgresql" ]]; then
        tmp_gcd_db_name=$(echo $tmp_gcd_db_name | tr '[:upper:]' '[:lower:]')
    fi

    for i in "${!GCDDB_CR_MAPPING[@]}"; do
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} "${GCDDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_gcd_db_servername.${GCDDB_COMMON_PROPERTY[i]})\""
    done

    # remove database_name if oracle
    if [[ $DB_TYPE == "oracle" ]]; then
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.datasource_configuration.dc_gcd_datasource.database_name "\"<Remove>\"" 
    else
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.datasource_configuration.dc_gcd_datasource.database_name "\"$tmp_gcd_db_name\""
    fi
}

# Apply value in FNCM OS required by BAW runtime property file into final CR
function func_sync_os_ds_property_into_cr(){
    
    BAW_RUNTIME_OS_ARR_IN_PROP=("BAWDOCS" "BAWTOS" "BAWDOS" )
    BAW_RUNTIME_OS_ARR_IN_CR=("BAWINS1DOCS" "BAWINS1TOS" "BAWINS1DOS" )
    
    for i in "${!BAW_RUNTIME_OS_ARR_IN_CR[@]}"; do
        OS_DATASOURCE_NUMBER=$(grep "^      dc_common_os_datasource_name: " ${BAW_STD_PATTERN_FILE_TMP} | grep -Fn ${BAW_RUNTIME_OS_ARR_IN_CR[i]}|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            
            tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name ${BAW_RUNTIME_OS_ARR_IN_PROP[i]}_DB_USER_NAME)"
            tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")
            
            if [[ $DB_TYPE == "oracle" ]]; then
                tmp_os_db_name="$(prop_db_name_user_property_file ${BAW_RUNTIME_OS_ARR_IN_PROP[i]}_DB_USER_NAME)"
            else
                tmp_os_db_name="$(prop_db_name_user_property_file ${BAW_RUNTIME_OS_ARR_IN_PROP[i]}_DB_NAME)"
            fi
            tmp_os_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_name")
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_os_db_name=$(echo $tmp_os_db_name | tr '[:upper:]' '[:lower:]')
            fi

            for j in "${!OSDB_CR_MAPPING[@]}"; do
                ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} "spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[j]}" "\"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[j]})\""
            done

            tmp_label=$(echo ${BAW_RUNTIME_OS_ARR_IN_PROP[i]} | tr '[:upper:]' '[:lower:]')
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_os_label "\"$tmp_label\""
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name $tmp_os_db_name
        fi
    done
}

# Apply value in FNCM OS required by AE data persistent property file into final CR
function func_sync_ae_os_ds_property_into_cr(){
    OS_DATASOURCE_NUMBER=$(grep "^      dc_common_os_datasource_name: " ${BAW_STD_PATTERN_FILE_TMP} | grep -Fn 'AEOS'|cut -d':' -f1)
    if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
        OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
        
        tmp_os_db_servername="$(prop_db_name_user_property_file_for_server_name AEOS_DB_USER_NAME)"
        tmp_os_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_servername")

        if [[ $DB_TYPE == "oracle" ]]; then
            tmp_os_db_name="$(prop_db_name_user_property_file AEOS_DB_USER_NAME)"
        else
            tmp_os_db_name="$(prop_db_name_user_property_file AEOS_DB_NAME)"
        fi
        tmp_os_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_os_db_name")
        if [[ $DB_TYPE == "postgresql" ]]; then
            tmp_os_db_name=$(echo $tmp_os_db_name | tr '[:upper:]' '[:lower:]')
        fi

        for i in "${!OSDB_CR_MAPPING[@]}"; do
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} "spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].${OSDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_os_db_servername.${OSDB_COMMON_PROPERTY[i]})\""
        done
        
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].dc_os_label "\"aeos\""
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.datasource_configuration.dc_os_datasources.[$OS_DATASOURCE_NUMBER].database_name $tmp_os_db_name
    fi
}

# Applying value in ICNDB property file into final CR
function func_sync_icn_ds_property_into_cr(){
    tmp_icn_db_servername="$(prop_db_name_user_property_file_for_server_name ICN_DB_USER_NAME)"
    tmp_icn_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_icn_db_servername")

    if [[ $DB_TYPE == "oracle" ]]; then
        tmp_icn_db_name="$(prop_db_name_user_property_file ICN_DB_USER_NAME)"
    else
        tmp_icn_db_name="$(prop_db_name_user_property_file ICN_DB_NAME)"
    fi
    tmp_icn_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_icn_db_name")
    if [[ $DB_TYPE == "postgresql" ]]; then
        tmp_icn_db_name=$(echo $tmp_icn_db_name | tr '[:upper:]' '[:lower:]')
    fi

    for i in "${!ICNDB_CR_MAPPING[@]}"; do
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} "${ICNDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_icn_db_servername.${ICNDB_COMMON_PROPERTY[i]})\""
    done
    
    # remove database_name if oracle
    if [[ $DB_TYPE == "oracle" ]]; then
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.datasource_configuration.dc_icn_datasource.database_name "\"<Remove>\"" 
    else
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.datasource_configuration.dc_icn_datasource.database_name $tmp_icn_db_name
    fi
}

# Applying value in UMS property file into final CR
function func_sync_ums_ds_property_into_cr(){

    # Handle UMS oauth db
    tmp_ums_oauth_db_servername="$(prop_db_name_user_property_file_for_server_name UMS_DB_USER_NAME)"
    tmp_ums_oauth_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ums_oauth_db_servername")

    if [[ $DB_TYPE == "oracle" ]]; then
        tmp_ums_oauth_db_name="$(prop_db_name_user_property_file UMS_DB_SID)"
    else
        tmp_ums_oauth_db_name="$(prop_db_name_user_property_file UMS_DB_NAME)"
    fi
    tmp_ums_oauth_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ums_oauth_db_name")
    if [[ $DB_TYPE == "postgresql" ]]; then
        tmp_ums_oauth_db_name=$(echo $tmp_ums_oauth_db_name | tr '[:upper:]' '[:lower:]')
    fi

    for i in "${!UMSDB_OAUTH_CR_MAPPING[@]}"; do
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} "${UMSDB_OAUTH_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_ums_oauth_db_servername.${UMSDB_OAUTH_COMMON_PROPERTY[i]})\""
    done
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ums_datasource.dc_ums_oauth_name "\"$tmp_ums_oauth_db_name\""

    if [[ $DB_TYPE == "oracle" ]]; then
        tmp_ums_oauth_oracle_service_name="$(prop_db_name_user_property_file UMS_DB_SERVICE_NAME)"
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ums_datasource.dc_ums_oauth_oracle_service_name "$tmp_ums_oauth_oracle_service_name"
    fi

    # Handle UMS teamserver db
    tmp_ums_ts_db_servername="$(prop_db_name_user_property_file_for_server_name UMS_DB_USER_NAME)"
    tmp_ums_ts_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ums_ts_db_servername")

    if [[ $DB_TYPE == "oracle" ]]; then
        tmp_ums_ts_db_name="$(prop_db_name_user_property_file UMS_DB_SID)"
    else
        tmp_ums_ts_db_name="$(prop_db_name_user_property_file UMS_DB_NAME)"
    fi
    tmp_ums_ts_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ums_ts_db_name")
    if [[ $DB_TYPE == "postgresql" ]]; then
        tmp_ums_ts_db_name=$(echo $tmp_ums_ts_db_name | tr '[:upper:]' '[:lower:]')
    fi

    for i in "${!UMSDB_TS_CR_MAPPING[@]}"; do
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} "${UMSDB_TS_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_ums_oauth_db_servername.${UMSDB_TS_COMMON_PROPERTY[i]})\""
    done
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ums_datasource.dc_ums_teamserver_name "\"$tmp_ums_ts_db_name\""

    if [[ $DB_TYPE == "oracle" ]]; then
        tmp_ums_oauth_oracle_service_name="$(prop_db_name_user_property_file UMS_DB_SERVICE_NAME)"
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.datasource_configuration.dc_ums_datasource.dc_ums_teamserver_oracle_service_name "$tmp_ums_oauth_oracle_service_name"
    fi
}

 # Applying value in LDAP property file into final CR
function func_sync_ldap_property_into_cr(){
    for i in "${!LDAP_COMMON_CR_MAPPING[@]}"; do
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} "${LDAP_COMMON_CR_MAPPING[i]}" "\"$(prop_ldap_property_file ${LDAP_COMMON_PROPERTY[i]})\""
    done

    if [[ $LDAP_TYPE == "AD" ]]; then
        for i in "${!AD_LDAP_CR_MAPPING[@]}"; do
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} "${AD_LDAP_CR_MAPPING[i]}" "\"$(prop_ldap_property_file ${AD_LDAP_PROPERTY[i]})\""
        done
    else
        for i in "${!TDS_LDAP_CR_MAPPING[@]}"; do
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} "${TDS_LDAP_CR_MAPPING[i]}" "\"$(prop_ldap_property_file ${TDS_LDAP_PROPERTY[i]})\""
        done
    fi
}

 # Applying value in BAW runtime property file into final CR
function func_sync_baw_std_property_file_into_cr(){
    tmp_baw_runtime_db_servername="$(prop_db_name_user_property_file_for_server_name BAW_RUNTIME_DB_USER_NAME)"
    tmp_baw_runtime_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_servername")

    if [[ $DB_TYPE == "oracle" ]]; then
        tmp_baw_runtime_db_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_USER_NAME)"
    else
        tmp_baw_runtime_db_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_NAME)"
    fi
    tmp_baw_runtime_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_name")

    for i in "${!BAW_RUNTIME_CR_MAPPING[@]}"; do
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} "${BAW_RUNTIME_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_baw_runtime_db_servername.${BAW_RUNTIME_COMMON_PROPERTY[i]})\""
    done

    #tmp_secret_name=`kubectl get secret -l db-name=${tmp_baw_runtime_db_name} -o yaml | ${YQ_CMD} r - items.[0].metadata.name`

    # set baw_configuration
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.secret_name ibm-baw-wfs-server-db-secret
    if [[ $DB_TYPE == "postgresql" ]]; then
        tmp_baw_runtime_db_name=$(echo $tmp_baw_runtime_db_name | tr '[:upper:]' '[:lower:]')
    fi
    
    # set current schema name for db2 and postgresql
    if [[ $DB_TYPE == "postgresql" || $DB_TYPE == "db2" ]]; then
        tmp_baw_runtime_db_current_schema_name="$(prop_db_name_user_property_file BAW_RUNTIME_DB_CURRENT_SCHEMA)"
        tmp_baw_runtime_db_current_schema_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_current_schema_name")
        if [[ $tmp_baw_runtime_db_current_schema_name != "<Optional>" && $tmp_baw_runtime_db_current_schema_name != ""  ]]; then
            if [[ $DB_TYPE == "postgresql" ]]; then
                tmp_baw_runtime_db_current_schema_name=$(echo $tmp_baw_runtime_db_current_schema_name | tr '[:upper:]' '[:lower:]')
            fi

            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.current_schema "\"$tmp_baw_runtime_db_current_schema_name\""
        fi
    fi

    # remove database_name if oracle
    if [[ $DB_TYPE == "oracle" ]]; then
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.database_name "\"\""
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.server_name "\"\""
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.port "\"\""
    else
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.database_name "\"$tmp_baw_runtime_db_name\""      
    fi

    if [[ $DB_TYPE == "oracle" ]]; then
        tmp_baw_runtime_db_jdbc_url="$(prop_db_server_property_file $tmp_baw_runtime_db_servername.ORACLE_JDBC_URL)"
        tmp_baw_runtime_db_jdbc_url=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_baw_runtime_db_jdbc_url")
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.jdbc_url "\"$tmp_baw_runtime_db_jdbc_url\""
    else
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.jdbc_url "\"<Remove>\""
        ${SED_COMMAND} "s|jdbc_url: '\"<Remove>\"'|# jdbc_url: '\"\"'|g" ${BAW_STD_PATTERN_FILE_TMP}
    fi
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].database.custom_jdbc_pvc "\"<Remove>\""
    ${SED_COMMAND} "s|custom_jdbc_pvc: '\"<Remove>\"'|# custom_jdbc_pvc: '\"\"'|g" ${BAW_STD_PATTERN_FILE_TMP}

    # Applying user profile for BAW runtime
    tmp_baw_runtime_admin="$(prop_user_profile_property_file BAW_RUNTIME.ADMIN_USER)"
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].admin_user "\"$tmp_baw_runtime_admin\""

    # Set event emitter configuartions
    tmp_date_sql="$(prop_user_profile_property_file BAW_RUNTIME.EVENT_EMITTER_DATE_SQL)"
    tmp_date_sql=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_date_sql")

    tmp_logical_unique_id="$(prop_user_profile_property_file BAW_RUNTIME.EVENT_EMITTER_LOGICAL_UNIQUE_ID)"
    tmp_logical_unique_id=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_logical_unique_id")

    tmp_conn_point_name=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_PE_CONN_POINT_NAME)
    tmp_conn_point_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_conn_point_name")

    if [ -n "$tmp_date_sql" ] && [ -n "$tmp_logical_unique_id" ]; then
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].case.event_emitter.[0].date_sql "\"$tmp_date_sql\""
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].case.event_emitter.[0].logical_unique_id "\"$tmp_logical_unique_id\""

        # Set connection point name
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].case.event_emitter.[0].connection_point_name "\"$tmp_conn_point_name\""
    
    else
        ${YQ_CMD} d -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].case.event_emitter
    fi

    # Set connection point name
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.baw_configuration.[0].case.tos_list.[0].connection_point_name "\"$tmp_conn_point_name\""
}

 # Applying value in Application Engine property file into final CR
function func_sync_aae_property_file_into_cr() {
    tmp_ae_db_servername="$(prop_db_name_user_property_file_for_server_name APP_ENGINE_DB_USER_NAME)"
    tmp_ae_db_servername=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ae_db_servername")
    if [[ $DB_TYPE == "oracle" ]]; then
        tmp_ae_db_name="$(prop_db_name_user_property_file APP_ENGINE_DB_USER_NAME)"
    else
        tmp_ae_db_name="$(prop_db_name_user_property_file APP_ENGINE_DB_NAME)"
    fi
    tmp_ae_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ae_db_name")

    for i in "${!AEDB_CR_MAPPING[@]}"; do
        if [[ $DB_TYPE == "oracle" ]]; then
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} "${AEDB_CR_MAPPING[i]}" "\"$(prop_db_oracle_server_property_file $tmp_ae_db_servername.${AEDB_COMMON_PROPERTY[i]})\""
        else
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} "${AEDB_CR_MAPPING[i]}" "\"$(prop_db_server_property_file $tmp_ae_db_servername.${AEDB_COMMON_PROPERTY[i]})\""
        fi
    done

    #tmp_secret_name=`kubectl get secret -l db-name=${tmp_ae_db_name} -o yaml | ${YQ_CMD} r - items.[0].metadata.name`

    # set application_engine_configuration
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].admin_secret_name icp4adeploy-workspace-aae-app-engine-admin-secret
    if [[ $DB_TYPE == "postgresql" ]]; then
        tmp_ae_db_name=$(echo $tmp_ae_db_name | tr '[:upper:]' '[:lower:]')
    fi
    
    # remove database_name if oracle
    if [[ $DB_TYPE == "oracle" ]]; then
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.host "\"\""
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.port "\"\""
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.name "\"\""
    else
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.name "\"$tmp_ae_db_name\""
    fi

    if [[ $DB_TYPE != "oracle" ]]; then
        ${YQ_CMD} d -i ${BAW_STD_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.oracle_url_without_wallet_directory
        ${YQ_CMD} d -i ${BAW_STD_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.oracle_url_with_wallet_directory
        ${YQ_CMD} d -i ${BAW_STD_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].database.oracle_sso_wallet_secret_name
    fi

    # Applying user profile for AE
    tmp_ae_admin="$(prop_user_profile_property_file APP_ENGINE.ADMIN_USER)"
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.application_engine_configuration.[0].admin_user "\"$tmp_ae_admin\""
}

# Handle properties under the spec.elasticsearch_configuration 
function func_set_elaticsearch_configuration_in_cr() {
    # when spec.elasticsearch_configuration.privileged set to false, do not need to input the service account, will create default sa for it. 
    es_privileged=`cat ${BAW_STD_PATTERN_FILE_TMP} | ${YQ_CMD} r - spec.elasticsearch_configuration.privileged`
    
    if [[ $es_privileged == "false" ]]; then
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.elasticsearch_configuration.service_account "\"\""
    fi
}

# Handle properties under the spec.initialize_configuration
function func_set_initialize_configuration_in_cr() {
    # Applying user profile for CONTENT INITIONLIZATION
    tmp_init_flag="$(prop_user_profile_property_file CONTENT_INITIALIZATION.ENABLE | tr '[:upper:]' '[:lower:]' )"
    tmp_init_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_init_flag")

    if [[ $tmp_init_flag == "yes" || $tmp_init_flag == "y" || $tmp_init_flag == "true" ]]; then
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.shared_configuration.sc_content_initialization "true"

        # Set initialize_configuration.ic_ldap_creation
        tmp_ldap_admin_user_name=$(prop_user_profile_property_file CONTENT_INITIALIZATION.LDAP_ADMIN_USER_NAME)
        tmp_ldap_admin_user_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldap_admin_user_name")

        tmp_ldap_admins_groups_name=$(prop_user_profile_property_file CONTENT_INITIALIZATION.LDAP_ADMINS_GROUPS_NAME)
        tmp_ldap_admins_groups_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_ldap_admins_groups_name")

        OIFS=$IFS
        IFS=',' read -ra ldap_admin_user_name_array <<< "$tmp_ldap_admin_user_name"
        IFS=',' read -ra ldap_admins_groups_name_array <<< "$tmp_ldap_admins_groups_name"
        IFS=$OIFS

        for num in "${!ldap_admin_user_name_array[@]}"; do
            local tmp_admin_user_name=$(sed -e 's/^[[:space:]]*//' <<< "${ldap_admin_user_name_array[num]}" )
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.initialize_configuration.ic_ldap_creation.ic_ldap_admin_user_name.[$((num))] "\"${tmp_admin_user_name}\""
        done

        for num in "${!ldap_admins_groups_name_array[@]}"; do
            local tmp_admins_groups_name=$(sed -e 's/^[[:space:]]*//' <<< "${ldap_admins_groups_name_array[num]}" )
            ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.initialize_configuration.ic_ldap_creation.ic_ldap_admins_groups_name.[$((num))] "\"${tmp_admins_groups_name}\""
        done

        # apply oc_cpe_obj_store_admin_user_groups for FNCM OS used by BAW runtime
        BAW_RUNTIME_OS_ARR=("BAWINS1DOCS" "BAWINS1DOS" "BAWINS1TOS")
        for i in "${!BAW_RUNTIME_OS_ARR[@]}"; do
            OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${BAW_STD_PATTERN_FILE_TMP} | grep -Fn ${BAW_RUNTIME_OS_ARR[i]}|cut -d':' -f1)
            if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
                OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
                tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
                tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
                OIFS=$IFS
                IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
                IFS=$OIFS

                for num in "${!admin_user_group_array[@]}"; do
                    local tmp_admin_user_group_name=$(sed -e 's/^[[:space:]]*//' <<< "${admin_user_group_array[num]}" )
                    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups.[$((num))]  "\"${tmp_admin_user_group_name}\""
                done
            fi
            # apply property for workflow initionlization into final cr
            if [[ "${BAW_RUNTIME_OS_ARR[i]}" == "BAWINS1TOS" ]]; then
                tmp_workflow_flag=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ENABLE_WORKFLOW | tr '[:upper:]' '[:lower:]' )
                tmp_workflow_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_workflow_flag")

                if [[ $tmp_workflow_flag == "yes" || $tmp_workflow_flag == "y" || $tmp_workflow_flag == "true" ]]; then
                    tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_DATA_TBL_SPACE)
                    tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")

                    if [[ $DB_TYPE == "postgresql" ]]; then
                        tmp_val=$(echo $tmp_val | tr '[:upper:]' '[:lower:]')
                    elif [[ $DB_TYPE == "oracle" ]]; then
                        tmp_val=$(echo $tmp_val | tr '[:lower:]' '[:upper:]')
                    fi

                    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_enable_workflow  "true"
                    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_data_tbl_space  "\"$tmp_val\""

                    tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_ADMIN_GROUP)
                    tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_admin_group  "\"$tmp_val\""

                    tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_CONFIG_GROUP)
                    tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_config_group  "\"$tmp_val\""

                    tmp_val=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_WORKFLOW_PE_CONN_POINT_NAME)
                    tmp_val=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_val")
                    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_pe_conn_point_name  "\"$tmp_val\""
                else
                    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_enable_workflow  "false"
                    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_workflow_data_tbl_space  "\"\""
                fi
            fi
        done

        # apply oc_cpe_obj_store_admin_user_groups for FNCM OS used by AE data persistent
        OS_DATASOURCE_NUMBER=$(grep "^          dc_os_datasource_name: " ${BAW_STD_PATTERN_FILE_TMP} | grep -Fn 'AEOS'|cut -d':' -f1)
        if [[ -n $OS_DATASOURCE_NUMBER && $OS_DATASOURCE_NUMBER -gt 0 ]]; then
            OS_DATASOURCE_NUMBER=$(( OS_DATASOURCE_NUMBER - 1 ))
            tmp_user_group=$(prop_user_profile_property_file CONTENT_INITIALIZATION.CPE_OBJ_STORE_ADMIN_USER_GROUPS)
            tmp_user_group=$(sed -e 's/^"//' -e 's/"$//' <<<"$tmp_user_group")
            OIFS=$IFS
            IFS=',' read -ra admin_user_group_array <<< "$tmp_user_group"
            IFS=$OIFS

            for num in "${!admin_user_group_array[@]}"; do
                local tmp_admin_user_group_name=$(sed -e 's/^[[:space:]]*//' <<< "${admin_user_group_array[num]}" )
                ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.initialize_configuration.ic_obj_store_creation.object_stores.[$OS_DATASOURCE_NUMBER].oc_cpe_obj_store_admin_user_groups.[$((num))]  "\"${tmp_admin_user_group_name}\""
            done
        fi
    else
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.shared_configuration.sc_content_initialization "false"
    fi
}

function generate_baw_std_cr_file(){
    printf "\n"
    
    wait_msg "Applying value in property file into final CR"
    sleep 2

    rm -rf $BAW_STD_PATTERN_FILE_TMP >/dev/null 2>&1

    ${COPY_CMD} -rf "${BAW_STD_PATTERN_FILE}" "${BAW_STD_PATTERN_FILE_TMP}"

    # Sync GCD datasource configuration (spec.datasource_configuration.dc_gcd_datasource.*)
    func_sync_gcd_ds_property_into_cr

    # Sync ICN datasource configuration (spec.datasource_configuration.dc_icn_datasource.*)
    func_sync_icn_ds_property_into_cr

    # Sync UMS datasource configuration (spec.datasource_configuration.dc_ums_datasource.*)
    func_sync_ums_ds_property_into_cr

    # Sync OS datasource configuration (spec.datasource_configuration.dc_os_datasources.*)
    func_sync_os_ds_property_into_cr
    
    # Sync AE OS datasource configuration (spec.datasource_configuration.dc_os_datasources.* - AEOS)
    func_sync_ae_os_ds_property_into_cr

    # sync LDAP configuration (spec.ldap_configuration.*)
    func_sync_ldap_property_into_cr

    # sync BAW configuration (spec.baw_configuration.*)
    func_sync_baw_std_property_file_into_cr

    # # sync Application engine configuration (spec.application_engine_configuration.*)
    # func_sync_aae_property_file_into_cr
    
    # set elasticsearch_configuration section in cr
    # func_set_elaticsearch_configuration_in_cr

    # set resources according profile size in cr
    func_sync_profile_size_into_cr

    # set initializeconfiguration section in cr
    func_set_initialize_configuration_in_cr

    # convert license
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.ibm_license accept

    # generate shared_configration section
    tmp_license_cp4ba=$(prop_user_profile_property_file CP4BA.CP4BA_LICENSE | tr '[:upper:]' '[:lower:]')
    tmp_license_fncm=$(prop_user_profile_property_file CP4BA.FNCM_LICENSE | tr '[:upper:]' '[:lower:]')
    tmp_license_baw=$(prop_user_profile_property_file CP4BA.BAW_LICENSE | tr '[:upper:]' '[:lower:]')
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_baw_license $tmp_license_baw
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_fncm_license $tmp_license_fncm
    if [[ -n "$tmp_license_cp4ba" ]]; then
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_license $tmp_license_cp4ba
    else
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_license "\"production\""
    fi
    
    # Set sc_deployment_context
    tmp_deployment_context=$(prop_user_profile_property_file CP4BA.PURCHASED_PRODUCT | tr '[:lower:]' '[:upper:]')
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_context "\"$tmp_deployment_context\""

    # Set sc_deployment_platform
    ${SED_COMMAND} "s|sc_deployment_platform:.*|sc_deployment_platform: \"$PLATFORM_SELECTED\"|g" ${BAW_STD_PATTERN_FILE_TMP}
   
    # Set sc_deployment_hostname_suffix
    ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.shared_configuration.sc_deployment_hostname_suffix "\"${SC_DEPLOYMENT_HOSTNAME_SUFFIX}\""

    # Set sc_dynamic_storage_classname
    tmp_storage_class_slow=$(prop_user_profile_property_file CP4BA.SLOW_FILE_STORAGE_CLASSNAME)
    tmp_storage_class_medium=$(prop_user_profile_property_file CP4BA.MEDIUM_FILE_STORAGE_CLASSNAME)
    tmp_storage_class_fast=$(prop_user_profile_property_file CP4BA.FAST_FILE_STORAGE_CLASSNAME)
    ${SED_COMMAND} "s|sc_slow_file_storage_classname:.*|sc_slow_file_storage_classname: \"${tmp_storage_class_slow}\"|g" ${BAW_STD_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s|sc_medium_file_storage_classname:.*|sc_medium_file_storage_classname: \"${tmp_storage_class_medium}\"|g" ${BAW_STD_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s|sc_fast_file_storage_classname:.*|sc_fast_file_storage_classname: \"${tmp_storage_class_fast}\"|g" ${BAW_STD_PATTERN_FILE_TMP}

    # load restricted access flag and set sc_restricted_internet_access
    restricted_flag="$(prop_user_profile_property_file CP4BA.ENABLE_RESTRICTED_INTERNET_ACCESS)"
    restricted_flag=$(sed -e 's/^"//' -e 's/"$//' <<<"$restricted_flag")
    restricted_flag=$(echo $restricted_flag | tr '[:upper:]' '[:lower:]')
    if [[ (! -z $restricted_flag) && $restricted_flag == "true" ]]; then
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access "true"
    else
        ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.shared_configuration.sc_egress_configuration.sc_restricted_internet_access "false"
    fi

    # Comment out sc_ingress_tls_secret_name if OCP platform
    if [[ $PLATFORM_SELECTED == "OCP" ]]; then
        ${SED_COMMAND} "s/sc_ingress_tls_secret_name: /# sc_ingress_tls_secret_name: /g" ${BAW_STD_PATTERN_FILE_TMP}
    fi

    # Handle CNCF deployment when deployment platform is other
    # - set sc_ingress_enable to true 
    # - set sc_deployment_platform to other
    # - comment out sc_ingress_tls_secret_name
    # - set service_type to Ingress
    # - keep elasticsearch_configuration.service_type as ClusterIP
    if [[ $PLATFORM_SELECTED == "other" ]]; then
        ${SED_COMMAND} "s|sc_ingress_enable:.*|sc_ingress_enable: true|g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s|sc_deployment_platform:.*|sc_deployment_platform: other|g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s|sc_ingress_tls_secret_name:.*|# sc_ingress_tls_secret_name: |g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s|service_type:.*|service_type: Ingress|g" ${BAW_STD_PATTERN_FILE_TMP}
        # ${YQ_CMD} w -i ${BAW_STD_PATTERN_FILE_TMP} spec.elasticsearch_configuration.service_type "ClusterIP"
    fi

    # comment out the database_servername/database_port/database_name/HADR if the db is oracle
    if [[ $DB_TYPE == "oracle" ]]; then
        ${SED_COMMAND} "s/database_servername:/# database_servername:/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/database_port:/# database_port:/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/database_name: \"<Remove>\"/# database_name: \"\"/g" ${BAW_STD_PATTERN_FILE_TMP}

        ${SED_COMMAND} "s/alternative_host:/# alternative_host:/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/alternative_port:/# alternative_port:/g" ${BAW_STD_PATTERN_FILE_TMP}

        ${SED_COMMAND} "s/server_name: \"<Remove>\"/# server_name: \"\"/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/port: \"<Remove>\"/# port: \"\"/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/host: \"<Remove>\"/# host: \"\"/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/name: \"<Remove>\"/# name: \"\"/g" ${BAW_STD_PATTERN_FILE_TMP}

        ${SED_COMMAND} "s/dc_hadr_standby_servername:/# dc_hadr_standby_servername:/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/dc_hadr_standby_port:/# dc_hadr_standby_port:/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/dc_hadr_retry_interval_for_client_reroute:/# dc_hadr_retry_interval_for_client_reroute:/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/dc_hadr_max_retries_for_client_reroute:/# dc_hadr_max_retries_for_client_reroute:/g" ${BAW_STD_PATTERN_FILE_TMP}

        # ums oauth / teamserver
        ${SED_COMMAND} "s/dc_ums_oauth_alternate_hosts:/# dc_ums_oauth_alternate_hosts:/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/dc_ums_oauth_alternate_ports:/# dc_ums_oauth_alternate_ports:/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/dc_ums_oauth_retry_interval_for_client_reroute:/# dc_ums_oauth_retry_interval_for_client_reroute:/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/dc_ums_oauth_max_retries_for_client_reroute:/# dc_ums_oauth_max_retries_for_client_reroute:/g" ${BAW_STD_PATTERN_FILE_TMP}

        ${SED_COMMAND} "s/dc_ums_teamserver_alternate_hosts:/# dc_ums_teamserver_alternate_hosts:/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/dc_ums_teamserver_alternate_ports:/# dc_ums_teamserver_alternate_ports:/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/dc_ums_teamserver_retry_interval_for_client_reroute:/# dc_ums_teamserver_retry_interval_for_client_reroute:/g" ${BAW_STD_PATTERN_FILE_TMP}
        ${SED_COMMAND} "s/dc_ums_teamserver_max_retries_for_client_reroute:/# dc_ums_teamserver_max_retries_for_client_reroute:/g" ${BAW_STD_PATTERN_FILE_TMP}
    fi

    # Others convert
    ${YQ_CMD} d -i ${BAW_STD_PATTERN_FILE_TMP} null
    ${SED_COMMAND} "s|'\"|\"|g" ${BAW_STD_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s|\"'|\"|g" ${BAW_STD_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"<Optional>\"/: \"\"/g" ${BAW_STD_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"True\"/: true/g" ${BAW_STD_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"False\"/: false/g" ${BAW_STD_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"true\"/: true/g" ${BAW_STD_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"false\"/: false/g" ${BAW_STD_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"Yes\"/: true/g" ${BAW_STD_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"yes\"/: true/g" ${BAW_STD_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"No\"/: false/g" ${BAW_STD_PATTERN_FILE_TMP}
    ${SED_COMMAND} "s/: \"no\"/: false/g" ${BAW_STD_PATTERN_FILE_TMP}
    
    mkdir -p $FINAL_CR_FOLDER

    ${COPY_CMD} -rf ${BAW_STD_PATTERN_FILE_TMP} ${BAW_STD_PATTERN_FILE_GENERATED}
    
    rm -rf ${BAW_STD_PATTERN_FILE_TMP}* >/dev/null 2>&1
    
    success "Applied value in property file into final CR under $FINAL_CR_FOLDER\n"
    tips ""
    msgB "Confirm final custom resource is under $FINAL_CR_FOLDER"
    msgB "Then, press any key to continue!"
    read -rsn1 -p"Press any key to continue";echo
}