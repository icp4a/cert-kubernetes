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

# function for creating the db2 rds sql statement file for BAA APP_ENGINE_DB
# DBACLD-163779
function create_baa_app_engine_db_db2rds_sql_file(){
    dbname=$1
    dbuser=$2
    dbserver=$3
    dbschema=$4
    dbpassword=$5
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    dbschema=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbschema")
    dbpassword=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbpassword")

    # use dbuser as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema=$dbuser
    fi

    mkdir -p $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_app_engine_db.sql
cat << EOF > $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_app_engine_db.sql
-- Creating DB named: ${dbname} 
CALL rdsadmin.create_database('${dbname}',32768,'UTF-8','US' );

--- Comment out all SQL stored procedures below when you are creating the database.
--- Once the database is created, comment out the create_database stored procedure statement and uncomment the below statements and execute them.
--- Creation of the Database can take some time, Please wait for a few minutes before executing the statements below.

-- Create bufferpool 
CALL rdsadmin.create_bufferpool('${dbname}','DBASBBP',1024,'Y','Y',32768,0,32);

-- Create table spaces
CALL rdsadmin.create_tablespace( '${dbname}', 'AAEENG_TS', 'DBASBBP', 32768, NULL, NULL, 'U', 'AUTOMATIC');
CALL rdsadmin.create_tablespace( '${dbname}', 'AAEENG_TEMP_TS', 'DBASBBP', 32768, NULL, NULL, 'T', 'AUTOMATIC');

-- Create role for the database with the role name of BAA
CALL rdsadmin.create_role('${dbname}','BAA');
-- Create a user
CALL rdsadmin.add_user('${dbuser}','${dbpassword}',null);
CALL rdsadmin.grant_role(?,'${dbname}','BAA','USER ${dbuser}','N');
CALL rdsadmin.dbadm_grant(?,'${dbname}','DBADM','USER ${dbuser}'); 

--- Execute the below statement after the admin user is connected to the newly created Database
GRANT SELECT ON SYSIBM.SYSVERSIONS TO USER ${dbuser};
GRANT SELECT ON SYSCAT.DATATYPES TO USER ${dbuser};
GRANT SELECT ON SYSCAT.INDEXES TO USER ${dbuser};
GRANT SELECT ON SYSIBM.SYSDUMMY1 TO USER ${dbuser};
GRANT USAGE ON WORKLOAD SYSDEFAULTUSERWORKLOAD TO USER ${dbuser};
GRANT IMPLICIT_SCHEMA ON DATABASE TO USER ${dbuser};
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};
GRANT EXECUTE ON PACKAGE NULLID.SYSSH200 TO USER ${dbuser};

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

# function for creating the db2 rds sql statement file for BAA AE_Playback
# DBACLD-163779
function create_ae_playback_db_db2rds_sql_file(){
    dbname=$1
    dbuser=$2
    dbserver=$3
    dbschema=$4
    dbpassword=$5
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    dbschema=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbschema")
    dbpassword=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbpassword")

    # use dbuser as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema=$dbuser
    fi

    mkdir -p $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ae_playback_db.sql
cat << EOF > $AE_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create_ae_playback_db.sql
-- Creating DB named: ${dbname} 
CALL rdsadmin.create_database('${dbname}',32768,'UTF-8','US' );

--- Creation of the Database can take some time,Please wait for a few minutes before executing the statements below.

-- Create bufferpool 
CALL rdsadmin.create_bufferpool('${dbname}','DBASBBP',1024,'Y','Y',32768,0,32);

-- Create table spaces
CALL rdsadmin.create_tablespace( '${dbname}', 'APPENG_TS', 'DBASBBP', 32768, NULL, NULL, 'U', 'AUTOMATIC');
CALL rdsadmin.create_tablespace( '${dbname}', 'APPENG_TEMP_TS', 'DBASBBP', 32768, NULL, NULL, 'T', 'AUTOMATIC');

-- Create role for the database with the role name of BAA
CALL rdsadmin.create_role('${dbname}','BAA');
-- Create a user
CALL rdsadmin.add_user('${dbuser}','${dbpassword}',null);
CALL rdsadmin.grant_role(?,'${dbname}','BAA','USER ${dbuser}','Y');
CALL rdsadmin.dbadm_grant(?,'${dbname}','DBADM','USER ${dbuser}'); 

--- Execute the below statement after the admin user is connected to the newly created Database
GRANT CONNECT ON DATABASE TO USER ${dbuser};
GRANT SELECT ON SYSIBM.SYSVERSIONS TO USER ${dbuser};
GRANT SELECT ON SYSCAT.DATATYPES TO USER ${dbuser};
GRANT SELECT ON SYSCAT.INDEXES TO USER ${dbuser};
GRANT SELECT ON SYSIBM.SYSDUMMY1 TO USER ${dbuser};
GRANT USAGE ON WORKLOAD SYSDEFAULTUSERWORKLOAD TO USER ${dbuser};
GRANT IMPLICIT_SCHEMA ON DATABASE TO USER ${dbuser};
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};
GRANT EXECUTE ON PACKAGE NULLID.SYSSH200 TO USER ${dbuser};

-- Done creating and tuning DB named: ${dbname}

EOF
}