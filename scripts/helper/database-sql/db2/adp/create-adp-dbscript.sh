#!/bin/bash
# set -x

###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2022. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
###############################################################################

ACA_DB_SCRIPT_PATH="../ACA/configuration-ha/DB2/sql"

# function for creating the db sql statement file for ADP Base Database
function create_adp_basedb_sql(){
    dbname=$1
    dbuser=$2
    dbserver=$3
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")

    mkdir -p $ADP_DB_SCRIPT_FOLDER/$DB_TYPE/${dbserver} >/dev/null 2>&1

    ADP_DB_SCRIPT_FULL_PATH=${ADP_DB_SCRIPT_FOLDER}/${DB_TYPE}/${dbserver}/1a_createADPBaseDB.sql
    
    # use template "CreateBaseDB.sql.template"
    rm -rf ${ADP_DB_SCRIPT_FULL_PATH}
    cp ${ACA_DB_SCRIPT_PATH}/CreateBaseDB.sql.template ${ADP_DB_SCRIPT_FULL_PATH}

    ${SED_COMMAND} s/\$base_db_name/"$dbname"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$base_db_user/"$dbuser"/ ${ADP_DB_SCRIPT_FULL_PATH}
}

# function for granting permissions for ADP Base Database
function grant_perms_adp_basedb_sql(){
    dbname=$1
    dbuser=$2
    dbserver=$3
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")

    mkdir -p $ADP_DB_SCRIPT_FOLDER/$DB_TYPE/${dbserver} >/dev/null 2>&1

    ADP_DB_SCRIPT_FULL_PATH=${ADP_DB_SCRIPT_FOLDER}/${DB_TYPE}/${dbserver}/1b_grantPerms_ADPBaseDB.sql
    
    # use template "GrantPermissionsBaseDB.sql.template"
    rm -rf ${ADP_DB_SCRIPT_FULL_PATH}
    cp ${ACA_DB_SCRIPT_PATH}/GrantPermissionsBaseDB.sql.template ${ADP_DB_SCRIPT_FULL_PATH}

    ${SED_COMMAND} s/\$base_db_name/"$dbname"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$base_db_user/"$dbuser"/ ${ADP_DB_SCRIPT_FULL_PATH}
}

function create_adp_basedb_tables_sql(){
    dbname=$1
    dbuser=$2
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")

    mkdir -p $ADP_DB_SCRIPT_FOLDER/$DB_TYPE/${dbserver} >/dev/null 2>&1

    ADP_DB_SCRIPT_FULL_PATH=${ADP_DB_SCRIPT_FOLDER}/${DB_TYPE}/${dbserver}/2_createADPBaseTable.sql

    # use template "CreateBaseTable.sql.template
    rm -rf ${ADP_DB_SCRIPT_FULL_PATH}
    cp ${ACA_DB_SCRIPT_PATH}/CreateBaseTable.sql.template ${ADP_DB_SCRIPT_FULL_PATH}

    ${SED_COMMAND} s/\$base_db_name/"$dbname"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$base_db_user/"$dbuser"/ ${ADP_DB_SCRIPT_FULL_PATH}
}


function create_adp_tenantdb_sql(){
    dbname=$1
    dbuser=$2
    dbserver=$3
    number=$4
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    number=$(sed -e 's/^"//' -e 's/"$//' <<<"$number")
 
    mkdir -p $ADP_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    
    ADP_DB_SCRIPT_FULL_PATH=${ADP_DB_SCRIPT_FOLDER}/${DB_TYPE}/${dbserver}/3a_createADPProject${number}_DB.sql

    # use template "CreateDB.sql.template"
    rm -rf ${ADP_DB_SCRIPT_FULL_PATH}
    cp ${ACA_DB_SCRIPT_PATH}/CreateDB.sql.template ${ADP_DB_SCRIPT_FULL_PATH}

    ${SED_COMMAND} s/\${tenant_db_name}/"$dbname"/ ${ADP_DB_SCRIPT_FULL_PATH}
    # need to repeat sed for this script because there is a line in SQL template in which the string appears twice
    ${SED_COMMAND} s/\${tenant_db_name}/"$dbname"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$tenant_db_user/"$dbuser"/ ${ADP_DB_SCRIPT_FULL_PATH}
}

function grant_perms_adp_tenantdb_sql(){
    dbname=$1
    dbuser=$2
    dbserver=$3
    number=$4
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    number=$(sed -e 's/^"//' -e 's/"$//' <<<"$number")
 
    mkdir -p $ADP_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    
    ADP_DB_SCRIPT_FULL_PATH=${ADP_DB_SCRIPT_FOLDER}/${DB_TYPE}/${dbserver}/3b_grantPerms_ADPProject${number}_DB.sql

    # use template "GrantPermissionsDB.sql.template"
    rm -rf ${ADP_DB_SCRIPT_FULL_PATH}
    cp ${ACA_DB_SCRIPT_PATH}/GrantPermissionsDB.sql.template ${ADP_DB_SCRIPT_FULL_PATH}

    ${SED_COMMAND} s/\${tenant_db_name}/"$dbname"/ ${ADP_DB_SCRIPT_FULL_PATH}
    # need to repeat sed for this script because there is a line in SQL template in which the string appears twice
    ${SED_COMMAND} s/\${tenant_db_name}/"$dbname"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$tenant_db_user/"$dbuser"/ ${ADP_DB_SCRIPT_FULL_PATH}
}

function create_adp_tenantdb_tables_sql(){
    dbname=$1
    dbuser=$2
    ontology=$3
    dbserver=$4
    number=$5
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    ontology=$(sed -e 's/^"//' -e 's/"$//' <<<"$ontology")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    number=$(sed -e 's/^"//' -e 's/"$//' <<<"$number")

    mkdir -p $ADP_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1

    # --- Create script for creating schema and creating tables ---
    ADP_DB_SCRIPT_FULL_PATH=${ADP_DB_SCRIPT_FOLDER}/${DB_TYPE}/${dbserver}/4_createADPProject${number}_Tables.sql

    # Use template "CreateBacaSchema.sql.template"
    rm -rf ${ADP_DB_SCRIPT_FULL_PATH}
    cp ${ACA_DB_SCRIPT_PATH}/CreateBacaSchema.sql.template ${ADP_DB_SCRIPT_FULL_PATH}
  
    echo "" >> ${ADP_DB_SCRIPT_FULL_PATH}
    echo "-- Create tables " >> ${ADP_DB_SCRIPT_FULL_PATH}
    echo "" >> ${ADP_DB_SCRIPT_FULL_PATH}
    
    # Append CreateBacaTables.sql to the script
    cat ${ACA_DB_SCRIPT_PATH}/CreateBacaTables.sql >> ${ADP_DB_SCRIPT_FULL_PATH}

    ${SED_COMMAND} s/\$tenant_db_name/"$dbname"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$tenant_db_user/"$dbuser"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$tenant_ontology/"$ontology"/ ${ADP_DB_SCRIPT_FULL_PATH}

    echo "" >> ${ADP_DB_SCRIPT_FULL_PATH}
    echo "CONNECT RESET; " >> ${ADP_DB_SCRIPT_FULL_PATH}

    # --- Create script for setting table permissions ----
    ADP_DB_SCRIPT_FULL_PATH=${ADP_DB_SCRIPT_FOLDER}/${DB_TYPE}/$dbserver/5_createADPProject${number}_TablePerms.sql
 
     # Use template "TablePermissions.sql.template"
    rm -rf ${ADP_DB_SCRIPT_FULL_PATH}
    cp ${ACA_DB_SCRIPT_PATH}/TablePermissions.sql.template ${ADP_DB_SCRIPT_FULL_PATH}

    ${SED_COMMAND} s/\$tenant_db_name/"$dbname"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$tenant_db_user/"$dbuser"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$tenant_ontology/"$ontology"/ ${ADP_DB_SCRIPT_FULL_PATH}

}


# Create script to insert tenant into base DB
function create_adp_insert_tenant_sql() {
    base_db_name=$1
    base_db_user=$2
    tenant_db_name=$3
    tenant_db_user=$4
    ontology=$5
    dbserver=$6
    db_ssl_enable=$7
    number=$8

    # remove quotes from beginning and end of string
    base_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$base_db_name")
    base_db_user=$(sed -e 's/^"//' -e 's/"$//' <<<"$base_db_user")
    tenant_db_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$tenant_db_name")
    tenant_db_user=$(sed -e 's/^"//' -e 's/"$//' <<<"$tenant_db_user")
    ontology=$(sed -e 's/^"//' -e 's/"$//' <<<"$ontology")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    db_ssl_enable=$(sed -e 's/^"//' -e 's/"$//' <<<"$db_ssl_enable")
    number=$(sed -e 's/^"//' -e 's/"$//' <<<"$number")

    # make scripts folder if it doesn't exist yet
    mkdir -p $ADP_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1

    ADP_DB_SCRIPT_FULL_PATH=${ADP_DB_SCRIPT_FOLDER}/${DB_TYPE}/${dbserver}/6_insertADPProject${number}.sql

    # use template "InsertTenant.sql.template"
    rm -rf ${ADP_DB_SCRIPT_FULL_PATH}
    cp ${ACA_DB_SCRIPT_PATH}/InsertTenant.sql.template ${ADP_DB_SCRIPT_FULL_PATH}

    rdbmsconnection="DSN=$tenant_db_name;UID=$tenant_db_user;"
    if [[ "$db_ssl_enable" == "true" || "$db_ssl_enable" == "yes" || "$db_ssl_enable" == "y" ]]; then
        rdbmsconnection+="Security=SSL;"
    fi

    ${SED_COMMAND} s/\$base_db_name/"$base_db_name"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$base_db_user/"$base_db_user"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$tenant_id/"$tenant_db_name"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$tenant_ontology/"$ontology"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$tenant_db_name/"$tenant_db_name"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$tenant_db_user/"$tenant_db_user"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$tenant_type/"0"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$daily_limit/"0"/ ${ADP_DB_SCRIPT_FULL_PATH}
    ${SED_COMMAND} s/\$rdbmsconnection/"$rdbmsconnection"/ ${ADP_DB_SCRIPT_FULL_PATH}
}
