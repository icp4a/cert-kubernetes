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

# function for creating the db sql statement file for Business Automation Workflow database
function create_baw_db_db2_sql_file(){
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

    mkdir -p $BAW_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $BAW_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_baw_db.sql
cat << EOF > $BAW_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_baw_db.sql
-- Creating DB named: ${dbname} 
CREATE DATABASE ${dbname} AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY US PAGESIZE 32768;
-- connect to the created database:
CONNECT TO ${dbname};

-- A user temporary tablespace is required to support stored procedures in BPM.
CREATE USER TEMPORARY TABLESPACE USRTMPSPC1;

UPDATE DB CFG FOR ${dbname} USING LOGFILSIZ 16384 DEFERRED;
UPDATE DB CFG FOR ${dbname} USING LOGSECOND 64 IMMEDIATE;

GRANT CONNECT ON DATABASE TO USER ${dbuser}; 
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};

GRANT CREATETAB ON DATABASE TO USER ${dbuser};
GRANT USE OF TABLESPACE USRTMPSPC1 TO USER ${dbuser};

CONNECT RESET;
-- Done creating and tuning DB named: ${dbname}
EOF
}