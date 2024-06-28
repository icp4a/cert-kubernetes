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

# function for creating the db sql statement file for ODM
function create_odm_db2_sql_file(){
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

    mkdir -p $ODM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $ODM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createODMDB.sql
cat << EOF > $ODM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createODMDB.sql
-- Creating DB named: ${dbname}
CREATE DATABASE ${dbname} AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY US PAGESIZE 32 K;

-- connect to the created database:
CONNECT TO ${dbname};

-- Create bufferpool and tablespaces
CREATE BUFFERPOOL ${dbname}_BP32K SIZE 2000 PAGESIZE 32K;
CREATE TABLESPACE ${dbname}_RESDWTS PAGESIZE 32K BUFFERPOOL ${dbname}_BP32K;
CREATE SYSTEM TEMPORARY TABLESPACE ${dbname}_RESDWTMPTS PAGESIZE 32K BUFFERPOOL ${dbname}_BP32K;

GRANT CONNECT ON DATABASE TO USER ${dbuser}; 
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};

CONNECT RESET;
EOF
}