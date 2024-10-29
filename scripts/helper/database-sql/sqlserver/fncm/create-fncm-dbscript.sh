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

# function for creating the db sql statement file for fncm ${dbname}
function create_fncm_gcddb_sqlserver_sql_file(){
    dbname=$1
    dbuser=$2
    dbuserpwd=$3
    dbserver=$4
    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")

    mkdir -p $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1
    rm -rf $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createGCDDB.sql
cat << EOF > $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createGCDDB.sql
-- create Content Platform Engine GCD database, you could update FILENAME as your requirement.
-- Please make sure you change the drive and path to your MSSQL database.
CREATE DATABASE ${dbname}
ON PRIMARY
(  NAME = ${dbname}_DATA,
   FILENAME = 'C:\MSSQL_DATABASE\\${dbname}_DATA.mdf',
   SIZE = 400MB,
   FILEGROWTH = 128MB ),

FILEGROUP ${dbname}SA_DATA_FG
(  NAME = ${dbname}SA_DATA,
   FILENAME = 'C:\MSSQL_DATABASE\\${dbname}SA_DATA.ndf',
   SIZE = 300MB,
   FILEGROWTH = 128MB),

FILEGROUP ${dbname}SA_IDX_FG
(  NAME = ${dbname}SA_IDX,
   FILENAME = 'C:\MSSQL_DATABASE\\${dbname}SA_IDX.ndf',
   SIZE = 300MB,
   FILEGROWTH = 128MB)

LOG ON
(  NAME = '${dbname}_LOG',
   FILENAME = 'C:\MSSQL_DATABASE\\${dbname}_LOG.ldf',
   SIZE = 160MB,
   FILEGROWTH = 50MB )
GO

ALTER DATABASE ${dbname} SET RECOVERY SIMPLE
GO

ALTER DATABASE ${dbname} SET AUTO_CREATE_STATISTICS ON
GO

ALTER DATABASE ${dbname} SET AUTO_UPDATE_STATISTICS ON
GO

ALTER DATABASE ${dbname} SET READ_COMMITTED_SNAPSHOT ON
GO

-- create a SQL Server login account for the database user of each of the databases and update the master database to grant permission for XA transactions for the login account
USE MASTER
GO
-- when using SQL authentication
CREATE LOGIN ${dbuser} WITH PASSWORD='${dbuserpwd}'
-- when using Windows authentication:
-- CREATE LOGIN [domain\user] FROM WINDOWS
GO
CREATE USER ${dbuser} FOR LOGIN ${dbuser} WITH DEFAULT_SCHEMA=${dbuser}
GO
EXEC sp_addrolemember N'SqlJDBCXAUser', N'${dbuser}';
GO

-- Creating users and schemas for Content Platform Engine GCD database
USE ${dbname}
GO
CREATE USER ${dbuser} FOR LOGIN ${dbuser} WITH DEFAULT_SCHEMA=${dbuser}
GO
CREATE SCHEMA ${dbuser} AUTHORIZATION ${dbuser}
GO
EXEC sp_addrolemember 'db_ddladmin', ${dbuser};
EXEC sp_addrolemember 'db_datareader', ${dbuser};
EXEC sp_addrolemember 'db_datawriter', ${dbuser};
GO
EOF
}

# function for creating the db sql statement file for fncm OSDB
function create_fncm_osdb_sqlserver_sql_file(){
    dbname=$1
    dbuser=$2
    dbuserpwd=$3
    dbserver=$4
    osdb_num=$5
    tablespace=$6
    tablespace_table=$7
    tablespace_index=$8
    tablespace_lob=$9

    # remove quotes from beginning and end of string
    dbname=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbname")
    dbuser=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuser")
    dbuserpwd=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbuserpwd")
    dbserver=$(sed -e 's/^"//' -e 's/"$//' <<<"$dbserver")
    tablespace=$(sed -e 's/^"//' -e 's/"$//' <<<"$tablespace")
    tablespace_table=$(sed -e 's/^"//' -e 's/"$//' <<<"$tablespace_table")
    tablespace_index=$(sed -e 's/^"//' -e 's/"$//' <<<"$tablespace_index")
    tablespace_lob=$(sed -e 's/^"//' -e 's/"$//' <<<"$tablespace_lob")

    mkdir -p $FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver >/dev/null 2>&1

    if [ -z $5 ]; then
        FNCM_OSDB_SCRIPT_FILE=$FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/create$dbname.sql
    else
        FNCM_OSDB_SCRIPT_FILE=$FNCM_DB_SCRIPT_FOLDER/$DB_TYPE/$dbserver/createOS${osdb_num}DB.sql
    fi

    if [ -z $6 ]; then
        tablespace="PRIMARY"
    else
        tablespace=$(echo $tablespace | tr '[:lower:]' '[:upper:]')
    fi

    if [[ $tablespace_table != "" ]]; then
       tablespace_table=$(echo $tablespace_table | tr '[:lower:]' '[:upper:]')
       tablespace_table_filegroup="
FILEGROUP $tablespace_table
(  NAME = ${tablespace_table},
   FILENAME = 'C:\MSSQL_DATABASE\\${tablespace_table}.ndf',
   SIZE = 400MB,
   FILEGROWTH = 128MB),
"
    fi
    if [[ $tablespace_index != "" ]]; then
       tablespace_index=$(echo $tablespace_index | tr '[:lower:]' '[:upper:]')
       tablespace_index_filegroup="
FILEGROUP $tablespace_index
(  NAME = ${tablespace_index},
   FILENAME = 'C:\MSSQL_DATABASE\\${tablespace_index}.ndf',
   SIZE = 300MB,
   FILEGROWTH = 128MB),
"
    fi
    if [[ $tablespace_lob != "" ]]; then
       tablespace_lob=$(echo $tablespace_lob | tr '[:lower:]' '[:upper:]')
       tablespace_lob_filegroup="
FILEGROUP $tablespace_lob
(  NAME = ${tablespace_lob},
   FILENAME = 'C:\MSSQL_DATABASE\\${tablespace_lob}.ndf',
   SIZE = 300MB,
   FILEGROWTH = 128MB),
"
    fi


    rm -rf $FNCM_OSDB_SCRIPT_FILE
cat << EOF > $FNCM_OSDB_SCRIPT_FILE
-- create ${dbname} object store database, you could update FILENAME as your requirement.
-- Please make sure you change the drive and path to your MSSQL database.
CREATE DATABASE ${dbname}
ON ${tablespace}
(  NAME = ${dbname}_DATA,
   FILENAME = 'C:\MSSQL_DATABASE\\${dbname}_DATA.mdf',
   SIZE = 400MB,
   FILEGROWTH = 128MB ),

FILEGROUP ${dbname}SA_DATA_FG
(  NAME = ${dbname}SA_DATA,
   FILENAME = 'C:\MSSQL_DATABASE\\${dbname}SA_DATA.ndf',
   SIZE = 300MB,
   FILEGROWTH = 128MB),
${tablespace_table_filegroup}
${tablespace_index_filegroup}
${tablespace_lob_filegroup}
FILEGROUP ${dbname}SA_IDX_FG
(  NAME = ${dbname}SA_IDX,
   FILENAME = 'C:\MSSQL_DATABASE\\${dbname}SA_IDX.ndf',
   SIZE = 300MB,
   FILEGROWTH = 128MB)

LOG ON
(  NAME = '${dbname}_LOG',
   FILENAME = 'C:\MSSQL_DATABASE\\${dbname}_LOG.ldf',
   SIZE = 160MB,
   FILEGROWTH = 50MB )
GO

ALTER DATABASE ${dbname} SET RECOVERY SIMPLE
GO

ALTER DATABASE ${dbname} SET AUTO_CREATE_STATISTICS ON
GO

ALTER DATABASE ${dbname} SET AUTO_UPDATE_STATISTICS ON
GO

ALTER DATABASE ${dbname} SET READ_COMMITTED_SNAPSHOT ON
GO

-- create a SQL Server login account for the database user of each of the databases and update the master database to grant permission for XA transactions for the login account
USE MASTER
GO
-- when using SQL authentication
CREATE LOGIN ${dbuser} WITH PASSWORD='${dbuserpwd}'
-- when using Windows authentication:
-- CREATE LOGIN [domain\user] FROM WINDOWS
GO
CREATE USER ${dbuser} FOR LOGIN ${dbuser} WITH DEFAULT_SCHEMA=${dbuser}
GO
EXEC sp_addrolemember N'SqlJDBCXAUser', N'${dbuser}';
GO

-- Creating users and schemas for object store database
USE ${dbname}
GO
CREATE USER ${dbuser} FOR LOGIN ${dbuser} WITH DEFAULT_SCHEMA=${dbuser}
GO
CREATE SCHEMA ${dbuser} AUTHORIZATION ${dbuser}
GO
EXEC sp_addrolemember 'db_ddladmin', ${dbuser};
EXEC sp_addrolemember 'db_datareader', ${dbuser};
EXEC sp_addrolemember 'db_datawriter', ${dbuser};
EXEC sp_addrolemember 'db_securityadmin', ${dbuser};
EXEC sp_addsrvrolemember ${dbuser}, 'bulkadmin';
GO
EOF
}