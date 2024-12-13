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
function create_baa_app_engine_db_oracle_sql_file(){
    dbuser=$1
    dbuserpwd=$2
    dbserver=$3
    # remove quotes from beginning and end of string
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuser=$(echo $dbuser | tr '[:lower:]' '[:upper:]')
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    mkdir -p $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_app_engine_db.sql
cat << EOF > $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_app_engine_db.sql
-- Please ensure you already have existing oracle instance or pluggable database (PDB). If not, please create one first

-- create a new user
CREATE USER ${dbuser} IDENTIFIED BY "${dbuserpwd}";

-- grant privileges to system and objects
GRANT CREATE SESSION TO ${dbuser};
GRANT ALTER SESSION TO ${dbuser};
GRANT CREATE TABLE TO ${dbuser};
-- Note:
-- 1. /home/oracle/orcl is a folder in the PV.
-- 2. You must specify the DATAFILE or TEMPFILE clause unless you have enabled Oracle Managed Files by setting a value for the DB_CREATE_FILE_DEST initialization parameter. 
CREATE TABLESPACE ${dbuser}TS
   DATAFILE '/home/oracle/orcl/${dbuser}TS.dbf' SIZE 200M REUSE
   AUTOEXTEND ON NEXT 20M
   EXTENT MANAGEMENT LOCAL
   SEGMENT SPACE MANAGEMENT AUTO
   ONLINE
   PERMANENT
 ;
CREATE TEMPORARY TABLESPACE ${dbuser}TS_TEMP
   TEMPFILE '/home/oracle/orcl/${dbuser}TS_TEMP.dbf' SIZE 200M REUSE
   AUTOEXTEND ON NEXT 20M
   EXTENT MANAGEMENT LOCAL
;
ALTER USER ${dbuser} QUOTA UNLIMITED ON ${dbuser}TS;
ALTER USER ${dbuser} DEFAULT TABLESPACE ${dbuser}TS TEMPORARY TABLESPACE ${dbuser}TS_TEMP;
GRANT SELECT ANY TABLE TO ${dbuser};
GRANT UPDATE ANY TABLE TO ${dbuser};
GRANT INSERT ANY TABLE TO ${dbuser};
GRANT DROP ANY TABLE TO ${dbuser};
EXIT;
EOF
}


function create_ae_playback_db_oracle_sql_file(){
    dbuser=$1
    dbuserpwd=$2
    dbserver=$3
    # remove quotes from beginning and end of string
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuser=$(echo $dbuser | tr '[:lower:]' '[:upper:]')
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    mkdir -p $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ae_playback_db.sql
cat << EOF > $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ae_playback_db.sql
-- Please ensure you already have existing oracle instance or pluggable database (PDB). If not, please create one first

-- create a new user
CREATE USER ${dbuser} IDENTIFIED BY "${dbuserpwd}";

-- grant privileges to system and objects
GRANT CREATE SESSION TO ${dbuser};
GRANT ALTER SESSION TO ${dbuser};
GRANT CREATE TABLE TO ${dbuser};
-- Note:
-- 1. /home/oracle/orcl is a folder in the PV.
-- 2. You must specify the DATAFILE or TEMPFILE clause unless you have enabled Oracle Managed Files by setting a value for the DB_CREATE_FILE_DEST initialization parameter. 
CREATE TABLESPACE ${dbuser}TS
   DATAFILE '/home/oracle/orcl/${dbuser}TS.dbf' SIZE 200M REUSE
   AUTOEXTEND ON NEXT 20M
   EXTENT MANAGEMENT LOCAL
   SEGMENT SPACE MANAGEMENT AUTO
   ONLINE
   PERMANENT
 ;
CREATE TEMPORARY TABLESPACE ${dbuser}TS_TEMP
   TEMPFILE '/home/oracle/orcl/${dbuser}TS_TEMP.dbf' SIZE 200M REUSE
   AUTOEXTEND ON NEXT 20M
   EXTENT MANAGEMENT LOCAL
;
ALTER USER ${dbuser} QUOTA UNLIMITED ON ${dbuser}TS;
ALTER USER ${dbuser} DEFAULT TABLESPACE ${dbuser}TS TEMPORARY TABLESPACE ${dbuser}TS_TEMP;

GRANT SELECT ANY TABLE TO ${dbuser};
GRANT UPDATE ANY TABLE TO ${dbuser};
GRANT INSERT ANY TABLE TO ${dbuser};
GRANT DROP ANY TABLE TO ${dbuser};
EXIT;
EOF
}