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
function create_fncm_gcddb_db2_sql_file(){
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

    mkdir -p $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createGCDDB.sql
cat << EOF > $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createGCDDB.sql
-- Creating DB named: ${dbname} 
CREATE DATABASE ${dbname} AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY US PAGESIZE 32 K;

CONNECT TO ${dbname};

-- Create bufferpool 
CREATE BUFFERPOOL ${dbname}_1_32K IMMEDIATE SIZE 1024 PAGESIZE 32K;
CREATE BUFFERPOOL ${dbname}_2_32K IMMEDIATE SIZE 1024 PAGESIZE 32K;

-- Create table spaces
CREATE REGULAR TABLESPACE GCDDATA_TS PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE BUFFERPOOL ${dbname}_1_32K;

CREATE USER TEMPORARY TABLESPACE ${dbname}_TMP_TBS PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE BUFFERPOOL ${dbname}_2_32K;

-- Grant permissions to DB user
GRANT CREATETAB,CONNECT ON DATABASE TO user ${dbuser};
GRANT USE OF TABLESPACE GCDDATA_TS TO user ${dbuser};
GRANT USE OF TABLESPACE ${dbname}_TMP_TBS TO user ${dbuser};
GRANT SELECT ON SYSIBM.SYSVERSIONS to user ${dbuser};
GRANT SELECT ON SYSCAT.DATATYPES to user ${dbuser};
GRANT SELECT ON SYSCAT.INDEXES to user ${dbuser};
GRANT SELECT ON SYSIBM.SYSDUMMY1 to user ${dbuser};
GRANT USAGE ON WORKLOAD SYSDEFAULTUSERWORKLOAD to user ${dbuser};
GRANT IMPLICIT_SCHEMA ON DATABASE to user ${dbuser};
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};

-- Apply DB tunings
UPDATE DB CFG FOR ${dbname} USING LOCKTIMEOUT 30;
UPDATE DB CFG FOR ${dbname} USING APPLHEAPSZ 2560;

CONNECT RESET;

-- Notes: After DB be created, please set below setting.
-- db2set DB2_WORKLOAD=FILENET_CM
-- db2set DB2_MINIMIZE_LISTPREFETCH=YES

-- Done creating and tuning DB named: ${dbname}
EOF
}

# function for creating the db sql statement file for fncm OSDB
function create_fncm_osdb_db2_sql_file(){
    dbname=$1
    dbuser=$2
    dbserver=$3
    osdb_num=$4
    tablespace=$5
    dbschema=$6
    
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    tablespace=$(sed -e 's/^"//' -e 's/"$//' <<<"$tablespace")
    dbschema=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbschema")

    # use dbuser as schema when schema is empty
    if [[ $dbschema == "" ]]; then
       dbschema=$dbuser 
    fi

if [ -z $4 ]; then
    FNCM_OSDB_SCRIPT_FILE=$FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create$dbname.sql
else
    FNCM_OSDB_SCRIPT_FILE=$FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createOS${osdb_num}DB.sql
fi

if [ -z $5 ]; then
    tablespace="VWDATA_TS"
fi

mkdir -p $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
rm -rf $FNCM_OSDB_SCRIPT_FILE
cat << EOF > $FNCM_OSDB_SCRIPT_FILE
-- Creating DB named: $dbname
CREATE DATABASE ${dbname} AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY US PAGESIZE 32 K;

CONNECT TO ${dbname};

-- Create bufferpool
CREATE BUFFERPOOL ${dbname}_1_32K IMMEDIATE SIZE 1024 PAGESIZE 32K;
CREATE BUFFERPOOL ${dbname}_2_32K IMMEDIATE SIZE 1024 PAGESIZE 32K;
CREATE BUFFERPOOL ${dbname}_3_32K IMMEDIATE SIZE 1024 PAGESIZE 32K;

-- Create table spaces
CREATE LARGE TABLESPACE OSDATA_TS PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE BUFFERPOOL ${dbname}_1_32K;
CREATE LARGE TABLESPACE ${tablespace} PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE BUFFERPOOL ${dbname}_2_32K;
CREATE USER TEMPORARY TABLESPACE ${dbname}_TMP_TBS PAGESIZE 32 K MANAGED BY AUTOMATIC STORAGE BUFFERPOOL ${dbname}_3_32K;

-- Grant permissions to DB user
GRANT CREATETAB,CONNECT ON DATABASE TO USER ${dbuser};
GRANT USE OF TABLESPACE OSDATA_TS TO USER ${dbuser};
GRANT USE OF TABLESPACE ${tablespace} TO USER ${dbuser};
GRANT USE OF TABLESPACE ${dbname}_TMP_TBS TO USER ${dbuser};
GRANT SELECT ON SYSIBM.SYSVERSIONS TO USER ${dbuser};
GRANT SELECT ON SYSCAT.DATATYPES TO USER ${dbuser};
GRANT SELECT ON SYSCAT.INDEXES TO USER ${dbuser};
GRANT SELECT ON SYSIBM.SYSDUMMY1 TO USER ${dbuser};
GRANT USAGE ON WORKLOAD SYSDEFAULTUSERWORKLOAD TO USER ${dbuser};
GRANT IMPLICIT_SCHEMA ON DATABASE TO USER ${dbuser};
CREATE SCHEMA ${dbschema} AUTHORIZATION ${dbuser};

-- Apply DB tunings
UPDATE DB CFG FOR ${dbname} USING LOCKTIMEOUT 30;
UPDATE DB CFG FOR ${dbname} USING LOGFILSIZ 6000; 

-- Notes: Please verify below environment configuration settings were applied to the Db2 server.
-- db2set DB2_WORKLOAD=FILENET_CM
-- db2set DB2_MINIMIZE_LISTPREFETCH=YES

CONNECT RESET;

-- Done creating and tuning DB named: ${dbname}
EOF
}