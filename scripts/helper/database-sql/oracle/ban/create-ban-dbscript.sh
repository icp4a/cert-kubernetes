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
function create_ban_oracle_sql_file(){
    dbuser=$1
    dbuserpwd=$2
    dbserver=$3
    # remove quotes from beginning and end of string
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuser=$(echo $dbuser | tr '[:lower:]' '[:upper:]')
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    mkdir -p $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createICNDB.sql
cat << EOF > $BAN_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createICNDB.sql
-- Please ensure you already have existing oracle instance or pluggable database (PDB). If not, please create one first

-- create a new user
CREATE USER ${dbuser} IDENTIFIED BY "${dbuserpwd}";

-- allow the user to connect to the database
GRANT CONNECT TO ${dbuser};

-- provide quota on all tablespaces with tables
GRANT UNLIMITED TABLESPACE TO ${dbuser};

-- grant privileges to create database objects:
GRANT RESOURCE TO ${dbuser};
GRANT CREATE VIEW TO ${dbuser};

-- grant access rights to resolve lock issues
GRANT EXECUTE ON DBMS_LOCK TO ${dbuser};

-- grant access rights to resolve XA related issues:
GRANT SELECT ON PENDING_TRANS$ TO ${dbuser};
GRANT SELECT ON DBA_2PC_PENDING TO ${dbuser};
GRANT SELECT ON DBA_PENDING_TRANSACTIONS TO ${dbuser};
GRANT EXECUTE ON DBMS_XA TO ${dbuser};

-- Create tablespaces
-- Please make sure you change the DATAFILE and TEMPFILE to your Oracle database.
CREATE TABLESPACE ${dbuser}TS
    DATAFILE '/home/oracle/orcl/${dbuser}TS.dbf' SIZE 200M REUSE
    AUTOEXTEND ON NEXT 20M
    EXTENT MANAGEMENT LOCAL
    SEGMENT SPACE MANAGEMENT AUTO
    ONLINE
    PERMANENT
;

CREATE TEMPORARY TABLESPACE ${dbuser}TSTEMP
    TEMPFILE '/home/oracle/orcl/${dbuser}TSTEMP.dbf' SIZE 200M REUSE
    AUTOEXTEND ON NEXT 20M
    EXTENT MANAGEMENT LOCAL
;


-- Alter existing schema

ALTER USER ${dbuser}
    DEFAULT TABLESPACE ${dbuser}TS 
    TEMPORARY TABLESPACE ${dbuser}TSTEMP;

GRANT CONNECT, RESOURCE to ${dbuser};
GRANT UNLIMITED TABLESPACE TO ${dbuser};
GRANT CREATE TRIGGER TO ${dbuser};
EXIT;
EOF
}