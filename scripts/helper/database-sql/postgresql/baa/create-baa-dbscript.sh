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
function create_baa_app_engine_db_postgresql_sql_file(){
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

    # use dbuser as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema=$dbuser 
    fi

    mkdir -p $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_app_engine_db.sql
cat << EOF > $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_app_engine_db.sql
-- create a new user
CREATE USER ${dbuser} WITH PASSWORD '${dbuserpwd}';
-- create database ${dbname}
CREATE DATABASE ${dbname} OWNER ${dbuser};
-- The following grant is used for databases
GRANT ALL PRIVILEGES ON DATABASE ${dbname} TO ${dbuser};
EOF
}


function create_ae_playback_db_postgresql_sql_file(){
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

    # use dbuser as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema=$dbuser 
    fi

    mkdir -p $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ae_playback_db.sql
cat << EOF > $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ae_playback_db.sql
-- create a new user
CREATE USER ${dbuser} WITH PASSWORD '${dbuserpwd}';
-- create database ${dbname}
CREATE DATABASE ${dbname} OWNER ${dbuser};
-- The following grant is used for databases
GRANT ALL PRIVILEGES ON DATABASE ${dbname} TO ${dbuser};
EOF
}