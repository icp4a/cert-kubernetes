#!/BIN/BASH

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

# function for creating the db sql statement file for UMS database
function create_ums_db_db2_sql_file(){
    dbname=$1
    dbuser=$2
    dbserver=$3
    dbschema=$4
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    dbschema=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbschema")

    # use dbuser as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema=$dbuser 
    fi

    mkdir -p $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ums_db.sql
cat << EOF > $UMS_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ums_db.sql
-- Creating DB named: ${dbname} 
CREATE DATABASE ${dbname} USING CODESET UTF8 TERRITORY US;

GRANT CONNECT ON DATABASE TO USER ${dbuser}; 
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};
EOF
}