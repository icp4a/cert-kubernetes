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

# function for creating the db sql statement file for BAA APP_ENGINE_DB
function create_baa_app_engine_db_db2_sql_file(){
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

    mkdir -p $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_app_engine_db.sql
cat << EOF > $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_app_engine_db.sql
-- Creating DB named: ${dbname} 
CREATE DATABASE ${dbname} AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY US PAGESIZE 32768;

-- connect to the created database:
CONNECT TO ${dbname};

-- Create bufferpool and tablespaces
CREATE BUFFERPOOL DBASBBP IMMEDIATE SIZE 1024 PAGESIZE 32K;
CREATE REGULAR TABLESPACE AAEENG_TS PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE DROPPED TABLE RECOVERY ON BUFFERPOOL DBASBBP;
CREATE USER TEMPORARY TABLESPACE AAEENG_TEMP_TS PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE BUFFERPOOL DBASBBP;

-- grant access rights to the tablespaces
GRANT USE OF TABLESPACE AAEENG_TS TO user ${dbuser};
GRANT USE OF TABLESPACE AAEENG_TEMP_TS TO user ${dbuser};

-- The following grant is used for databases without enhanced security.
-- For more information, review the IBM documentation for enhancing security for DB2.
GRANT DBADM ON DATABASE TO USER ${dbuser};

CONNECT RESET;
-- Done creating and tuning DB named: ${dbname}
EOF
}


function create_ae_playback_db_db2_sql_file(){
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

    mkdir -p $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ae_playback_db.sql
cat << EOF > $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ae_playback_db.sql
-- Creating DB named: ${dbname} 
CREATE DATABASE ${dbname} AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY US PAGESIZE 32768;

-- connect to the created database:
CONNECT TO ${dbname};

-- Create bufferpool and tablespaces
CREATE BUFFERPOOL DBASBBP IMMEDIATE SIZE 1024 PAGESIZE 32K;
CREATE REGULAR TABLESPACE APPENG_TS PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE DROPPED TABLE RECOVERY ON BUFFERPOOL DBASBBP;
CREATE USER TEMPORARY TABLESPACE APPENG_TEMP_TS PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE BUFFERPOOL DBASBBP;

-- grant access rights to the tablespaces
GRANT USE OF TABLESPACE APPENG_TS TO USER ${dbuser};
GRANT USE OF TABLESPACE APPENG_TEMP_TS TO USER ${dbuser};

GRANT DBADM ON DATABASE TO USER ${dbuser};

CONNECT RESET;
-- Done creating and tuning DB named: ${dbname}
EOF
}