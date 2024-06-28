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
function create_fncm_gcddb_postgresql_sql_file(){
    dbname=$1
    dbuser=$2
    dbuserpwd=$3
    dbserver=$4
    dbschema=$5
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    dbschema=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbschema")
    # convert to lowercase for postgreSQL dbname
    dbname=$(echo $dbname | tr '[:upper:]' '[:lower:]')
    dbschema=$(echo $dbschema | tr '[:upper:]' '[:lower:]')

    tablespace="${dbname}_tbs"

    # use dbuser as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema=$dbuser 
    fi

    mkdir -p $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createGCDDB.sql
cat << EOF > $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createGCDDB.sql
-- create user ${dbuser}
CREATE ROLE ${dbuser} WITH INHERIT LOGIN ENCRYPTED PASSWORD '${dbuserpwd}';

-- please modify location follow your requirement
create tablespace ${tablespace} owner ${dbuser} location '/pgsqldata/${dbname}';
grant create on tablespace ${tablespace} to ${dbuser};  

-- create database ${dbname}
create database ${dbname} owner ${dbuser} tablespace ${tablespace} template template0 encoding UTF8 ;
-- Connect to your database and create schema
\c ${dbname};
CREATE SCHEMA IF NOT EXISTS ${dbschema} AUTHORIZATION ${dbuser};
GRANT ALL ON schema ${dbschema} to ${dbuser};

-- create a schema for ${dbname} and set the default
-- connect to the respective database before executing the below commands
SET ROLE ${dbuser};
ALTER DATABASE ${dbname} SET search_path TO ${dbschema};
revoke connect on database ${dbname} from public;
EOF
}

# function for creating the db sql statement file for fncm OSDB
function create_fncm_osdb_postgresql_sql_file(){
    dbname=$1
    dbuser=$2
    dbuserpwd=$3
    dbserver=$4
    osdb_num=$5
    tablespace=$6
    dbschema=$7
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    tablespace=$(sed -e 's/^"//' -e 's/"$//' <<<"$tablespace")
    dbschema=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbschema")

    # convert to lowercase for postgreSQL dbname
    dbfile_name=$dbname
    dbname=$(echo $dbname | tr '[:upper:]' '[:lower:]')
    dbschema=$(echo $dbschema | tr '[:upper:]' '[:lower:]')

    # use dbuser as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema=$dbuser 
    fi

    mkdir -p $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    if [ -z $5 ]; then
        FNCM_OSDB_SCRIPT_FILE=$FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create$dbfile_name.sql
    else
        FNCM_OSDB_SCRIPT_FILE=$FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createOS${osdb_num}DB.sql
    fi
    if [ -z $6 ]; then
        tablespace="${dbname}_tbs"
    else
        tablespace=$(echo $tablespace | tr '[:upper:]' '[:lower:]')
    fi
    rm -rf $FNCM_OSDB_SCRIPT_FILE
cat << EOF > $FNCM_OSDB_SCRIPT_FILE
-- create user ${dbuser}
CREATE ROLE ${dbuser} WITH INHERIT LOGIN ENCRYPTED PASSWORD '${dbuserpwd}';

-- please modify location follow your requirement
create tablespace ${tablespace} owner ${dbuser} location '/pgsqldata/${dbname}';
grant create on tablespace ${tablespace} to ${dbuser};  

-- create database ${dbname}
create database ${dbname} owner ${dbuser} tablespace ${tablespace} template template0 encoding UTF8 ;

-- Connect to your database and create schema
\c ${dbname};

CREATE SCHEMA IF NOT EXISTS ${dbschema} AUTHORIZATION ${dbuser};
GRANT ALL ON schema ${dbschema} to ${dbuser};

-- create a schema for ${dbname} and set the default
-- connect to the respective database before executing the below commands
SET ROLE ${dbuser};
ALTER DATABASE ${dbname} SET search_path TO ${dbschema};
revoke connect on database ${dbname} from public;
EOF
}