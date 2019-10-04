@echo off
SETLOCAL

set /p base_db_name= Enter the name of the Base BACA database. If nothing is entered, we will use the following default value 'CABASEDB': 
IF NOT DEFINED base_db_name SET "base_db_name=CABASEDB"

set /p base_db_user= Enter the name of the database user for the Base BACA database. If nothing is entered, we will use the following default value 'CABASEUSER' : 
IF NOT DEFINED base_db_user SET "base_db_user=CABASEUSER"

set /P c=Are you sure you want to continue[Y/N]?
if /I "%c%" EQU "Y" goto :DOCREATE
if /I "%c%" EQU "N" goto :DOEXIT

:DOCREATE
	echo "Running the db script"
	db2 CREATE DATABASE %base_db_name% AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY DEFAULT COLLATE USING SYSTEM PAGESIZE 32768
	db2 CONNECT TO %base_db_name%
	db2 GRANT CONNECT,DATAACCESS ON DATABASE TO USER %base_db_user%
	db2 GRANT USE OF TABLESPACE USERSPACE1 TO USER %base_db_user%
	db2 CONNECT RESET
	db2 CONNECT TO %base_db_name%
	db2 SET SCHEMA %base_db_user%
	db2 CREATE TABLE TENANTINFO (tenantid varchar(128) NOT NULL, ontology varchar(128) not null,tenanttype smallint not null with default, rdbmsengine varchar(128)  not null, bacaversion varchar(1024) not null, rdbmsconnection  varchar(1024) for bit data default null,mongoconnection varchar(1024)  for bit data default null,mongoadminconnection varchar(1024) for bit data default null,CONSTRAINT tenantinfo_pkey PRIMARY KEY (tenantid, ontology))
	db2 CONNECT RESET
	goto END
:DOEXIT
	echo "Exited on user input"
	goto END
:END
	echo "END"

ENDLOCAL