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
function create_baw_db_oracle_sql_file(){
    dbuser=$1
    dbuserpwd=$2
    dbserver=$3
    # remove quotes from beginning and end of string
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuser=$(echo $dbuser | tr '[:lower:]' '[:upper:]')
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")

    mkdir -p $BAW_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $BAW_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_baw_db.sql
cat << EOF > $BAW_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_baw_db.sql
-- Please ensure you already have existing oracle instance or pluggable database (PDB). If not, please create one first

-- create a new user
CREATE USER ${dbuser} IDENTIFIED BY "${dbuserpwd}";

-- allow the user to connect to the database
GRANT CONNECT TO ${dbuser};

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
 
ALTER USER ${dbuser}
     DEFAULT TABLESPACE ${dbuser}TS
     TEMPORARY TABLESPACE ${dbuser}TS_TEMP;

-- Grant the privileges to create database objects.
GRANT  CREATE TABLE TO ${dbuser};
GRANT  CREATE PROCEDURE TO ${dbuser};
GRANT  CREATE SEQUENCE TO ${dbuser};
GRANT  CREATE VIEW TO ${dbuser};

-- grant access rights to resolve lock issues
GRANT EXECUTE ON DBMS_LOCK TO ${dbuser};

-- grant access rights to resolve XA related issues:
GRANT SELECT ON PENDING_TRANS$ TO ${dbuser};
GRANT SELECT ON DBA_2PC_PENDING TO ${dbuser};
GRANT SELECT ON DBA_PENDING_TRANSACTIONS TO ${dbuser};
GRANT EXECUTE ON DBMS_XA TO ${dbuser};
EXIT;
EOF
}