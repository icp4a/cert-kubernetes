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

# function for creating the db sql statement file for BAN
function create_ban_db2_sql_file(){
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

    mkdir -p $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createICNDB.sql
cat << EOF > $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createICNDB.sql
-- Creating DB named: ${dbname}
CREATE DATABASE ${dbname} AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY US PAGESIZE 32 K;
CONNECT TO ${dbname};
CREATE Bufferpool ${dbname}_BP IMMEDIATE SIZE AUTOMATIC PAGESIZE 32K;
CREATE Bufferpool ${dbname}_TEMPBP IMMEDIATE SIZE 200 PAGESIZE 32K;

-- The default table space name is "ICNDB".
-- If use default table space name "ICNDB", you do not need to input the value for spec.navigator_configuration.icn_production_setting.icn_table_space.
-- If change table space name, you need to use same value for spec.navigator_configuration.icn_production_setting.icn_table_space in custom resource.
CREATE REGULAR TABLESPACE ICNDB PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE AUTORESIZE YES INITIALSIZE 20 M INCREASESIZE 20 M BUFFERPOOL ${dbname}_BP;
GRANT USE OF TABLESPACE ICNDB TO user ${dbuser};

CREATE USER TEMPORARY TABLESPACE ${dbname}_TEMP PAGESIZE 32K MANAGED BY AUTOMATIC STORAGE BUFFERPOOL ${dbname}_TEMPBP;
GRANT USE OF TABLESPACE ${dbname}_TEMP TO user ${dbuser};

GRANT CONNECT ON DATABASE TO USER ${dbuser}; 
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};

CONNECT RESET;
EOF
}