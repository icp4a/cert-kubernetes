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
function create_odm_oracle_sql_file(){
    dbuser=$1
    dbuserpwd=$2
    dbserver=$3
    # remove quotes from beginning and end of string
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuser=$(echo $dbuser | tr '[:lower:]' '[:upper:]')
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")

    mkdir -p $ODM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $ODM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createODMDB.sql
cat << EOF > $ODM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createODMDB.sql
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
GRANT CREATE TRIGGER TO ${dbuser};

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