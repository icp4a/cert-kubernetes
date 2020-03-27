@echo off
SETLOCAL

IF NOT DEFINED skip_create_base_db (
	set skip_create_base_db=false
)

IF "%skip_create_base_db%"=="true" (
    echo --
    echo This script will initialize an existing DB2 database for use as a BACA base database. 
	echo --
) ELSE (
    echo --
    echo This script will create and initialize a new DB2 database for use as a BACA base database. An existing database user must exist.
	echo --
)

	
set /p base_db_name= Enter the name of the Base BACA database. If nothing is entered, we will use the following default value 'CABASEDB': 
IF NOT DEFINED base_db_name SET "base_db_name=CABASEDB"

set /p base_db_user= Enter the name of the database user for the Base BACA database. If nothing is entered, we will use the following default value 'CABASEUSER' : 
IF NOT DEFINED base_db_user SET "base_db_user=CABASEUSER"

set /P c=Are you sure you want to continue[Y/N]?
if /I "%c%" EQU "N" goto :DOEXIT

IF "%skip_create_base_db%"=="true" (
    goto :DOCREATETABLE
) ELSE (
    goto :DOCREATE
)

:DOCREATE
	echo "Creating a database...."
	db2 CREATE DATABASE %base_db_name% AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY DEFAULT COLLATE USING SYSTEM PAGESIZE 32768
	db2 CONNECT TO %base_db_name%
	db2 GRANT CONNECT,DATAACCESS ON DATABASE TO USER %base_db_user%
	db2 GRANT USE OF TABLESPACE USERSPACE1 TO USER %base_db_user%
	db2 CONNECT RESET
	goto DOCREATETABLE
:DOCREATETABLE
	db2 CONNECT TO %base_db_name%
	db2 SET SCHEMA %base_db_user%
	echo "Creating table TENANTINFO...."
	db2 CREATE TABLE TENANTINFO  (tenantid varchar(128) NOT NULL,ontology varchar(128) not null,tenanttype smallint not null with default,dailylimit smallint not null with default 0,rdbmsengine varchar(128)  not null,dbname varchar(255) not null,dbuser varchar(255) not null,bacaversion varchar(1024) not null,rdbmsconnection  varchar(1024) for bit data default null,mongoconnection varchar(1024)  for bit data default null,mongoadminconnection varchar(1024) for bit data default null,featureflags bigint not null with default 0,tenantdbversion varchar(255),CONSTRAINT tenantinfo_pkey PRIMARY KEY (tenantid, ontology) )
	db2 CONNECT RESET
	goto END
:DOEXIT
	echo "Exited on user input"
	goto END
:END
    set skip_create_base_db=
	echo "END"

ENDLOCAL