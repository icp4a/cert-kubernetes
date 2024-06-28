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

# function for creating the db sql statement file for fncm GCDDB
function create_fncm_gcddb_oracle_sql_file(){
    dbuser=$1
    dbuserpwd=$2
    dbserver=$3
    # remove quotes from beginning and end of string
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuser=$(echo $dbuser | tr '[:lower:]' '[:upper:]')
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")

    mkdir -p $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createGCDDB.sql
cat << EOF > $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createGCDDB.sql
-- Please ensure you already have existing oracle instance or pluggable database (PDB). If not, please create one first

-- create tablespace
-- Please make sure you change the DATAFILE and TEMPFILE to your Oracle database.
CREATE TABLESPACE ${dbuser}DATATS DATAFILE '/home/oracle/orcl/${dbuser}DATATS.dbf' SIZE 200M REUSE AUTOEXTEND ON NEXT 20M EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO ONLINE PERMANENT;
CREATE TEMPORARY TABLESPACE ${dbuser}DATATSTEMP TEMPFILE '/home/oracle/orcl/${dbuser}DATATSTEMP.dbf' SIZE 200M REUSE AUTOEXTEND ON NEXT 20M EXTENT MANAGEMENT LOCAL;

-- create a new user for GCDDB
CREATE USER ${dbuser} PROFILE DEFAULT IDENTIFIED BY "${dbuserpwd}" DEFAULT TABLESPACE ${dbuser}DATATS TEMPORARY TABLESPACE ${dbuser}DATATSTEMP ACCOUNT UNLOCK;
-- provide quota on all tablespaces with GCD tables
ALTER USER ${dbuser} QUOTA UNLIMITED ON ${dbuser}DATATS;
ALTER USER ${dbuser} DEFAULT TABLESPACE ${dbuser}DATATS;
ALTER USER ${dbuser} TEMPORARY TABLESPACE ${dbuser}DATATSTEMP;

-- allow the user to connect to the database
GRANT CONNECT TO ${dbuser};
GRANT ALTER session TO ${dbuser};

-- grant privileges to create database objects
GRANT CREATE SESSION TO ${dbuser};
GRANT CREATE TABLE TO ${dbuser};
GRANT CREATE VIEW TO ${dbuser};
GRANT CREATE SEQUENCE TO ${dbuser};

-- grant access rights to resolve XA related issues
GRANT SELECT on pending_trans$ TO ${dbuser};
GRANT SELECT on dba_2pc_pending TO ${dbuser};
GRANT SELECT on dba_pending_transactions TO ${dbuser};
GRANT SELECT on DUAL TO ${dbuser};
GRANT SELECT on product_component_version TO ${dbuser};
GRANT SELECT on USER_INDEXES TO ${dbuser};
GRANT EXECUTE ON DBMS_XA TO ${dbuser};
EXIT;
EOF
}

# function for creating the db sql statement file for fncm OSDB
function create_fncm_osdb_oracle_sql_file(){
    dbuser=$1
    dbuserpwd=$2
    dbserver=$3
    osdb_num=$4
    tablespace=$5
    # remove quotes from beginning and end of string
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuser=$(echo $dbuser | tr '[:lower:]' '[:upper:]')
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    tablespace=$(sed -e 's/^"//' -e 's/"$//' <<<"$tablespace")
    mkdir -p $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    if [ -z $4 ]; then
        FNCM_OSDB_SCRIPT_FILE=$FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create$dbuser.sql
    else
        FNCM_OSDB_SCRIPT_FILE=$FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createOS${osdb_num}DB.sql
    fi

    if [ -z $5 ]; then
        tablespace="${dbuser}DATATS"
    fi

    rm -rf $FNCM_OSDB_SCRIPT_FILE
cat << EOF > $FNCM_OSDB_SCRIPT_FILE
-- Please ensure you already have existing oracle instance or pluggable database (PDB). If not, please create one first

-- create tablespace
-- Change DATAFILE/TEMPFILE as required by your configuration
CREATE TABLESPACE ${tablespace} DATAFILE '/home/oracle/orcl/${tablespace}.dbf' SIZE 200M REUSE AUTOEXTEND ON NEXT 20M EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO ONLINE PERMANENT;
CREATE TEMPORARY TABLESPACE ${dbuser}DATATSTEMP TEMPFILE '/home/oracle/orcl/${dbuser}DATATSTEMP.dbf' SIZE 200M REUSE AUTOEXTEND ON NEXT 20M EXTENT MANAGEMENT LOCAL;

-- create a new user for ${dbuser}
CREATE USER ${dbuser} PROFILE DEFAULT IDENTIFIED BY "${dbuserpwd}" DEFAULT TABLESPACE ${tablespace} TEMPORARY TABLESPACE ${dbuser}DATATSTEMP ACCOUNT UNLOCK;

-- provide quota on all tablespaces with BPM tables
ALTER USER ${dbuser} QUOTA UNLIMITED ON ${tablespace};
ALTER USER ${dbuser} DEFAULT TABLESPACE ${tablespace};
ALTER USER ${dbuser} TEMPORARY TABLESPACE ${dbuser}DATATSTEMP;

-- allow the user to connect to the database
GRANT CONNECT TO ${dbuser};
GRANT ALTER session TO ${dbuser};

-- grant privileges to create database objects
GRANT CREATE SESSION TO ${dbuser};
GRANT CREATE TABLE TO ${dbuser};
GRANT CREATE VIEW TO ${dbuser};
GRANT CREATE SEQUENCE TO ${dbuser};
GRANT CREATE PROCEDURE TO ${dbuser};

-- grant access rights to resolve XA related issues
GRANT SELECT on pending_trans$ TO ${dbuser};
GRANT SELECT on dba_2pc_pending TO ${dbuser};
GRANT SELECT on dba_pending_transactions TO ${dbuser};
GRANT SELECT on DUAL TO ${dbuser};
GRANT SELECT on product_component_version TO ${dbuser};
GRANT SELECT on USER_INDEXES TO ${dbuser};
GRANT EXECUTE ON DBMS_XA TO ${dbuser};
EXIT;
EOF
}