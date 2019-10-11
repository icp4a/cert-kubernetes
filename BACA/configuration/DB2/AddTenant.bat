@echo off

SETLOCAL
echo Enter '1' to add new tenant and an ontology.
echo Enter '2' to add an ontology for an existing tenant database.
echo Enter anything to abort

set /p choice="Type input: "

set /p tenant_id= Enter the tenant ID for the new tenant: (eg. t4900) :

set /p tenant_db_name= Enter the name of the new BACA tenant database to create: (eg. t4900) :

set /p baca_database_server_ip= Enter the host/IP of the tenant database server.   :  

set /p baca_database_port= Enter the port of the tenant database server : 

set /p tenant_db_user= Please enter the name of tenant database user. If no value is entered we will use the following default value 'tenantuser' : 
IF NOT DEFINED tenant_db_user SET "tenant_db_user=tenantuser"

set /p tenant_db_pwd= Enter the password for the tenant database user: 

set /p tenant_ontology= Enter the tenant ontology name. If nothing is entered, the default name will be used 'default' : 
IF NOT DEFINED tenant_ontology SET "tenant_ontology=default"

set /p base_db_name= Enter the name of the Base BACA database with the TENANTINFO Table. If nothing is entered, we will use the following default value 'CABASEDB': 
IF NOT DEFINED base_db_name SET "base_db_name=CABASEDB"

set /p base_db_user= Enter the name of the database user for the Base BACA database. If nothing is entered, we will use the following default value 'CABASEUSER' : 
IF NOT DEFINED base_db_user SET "base_db_user=CABASEUSER"

set /p tenant_company= Please enter the company name for the initial BACA user : 

set /p tenant_first_name= Please enter the first name for the initial BACA user : 

set /p tenant_last_name= Please enter the last name for the initial BACA user : 

set /p tenant_email= Please enter a valid email address for the initial BACA user : 

set /p tenant_user_name= Please enter the login name for the initial BACA user : 

set /p ssl= Please enter the login name for the initial BACA user : 

echo "-- Please confirm these are the desired settings:"
echo " - tenant ID: %tenant_id%"
echo " - tenant database name: %tenant_db_name%"
echo " - database server hostname/IP: %baca_database_server_ip%"
echo " - database server port: %baca_database_port%"
echo " - tenant database user: %tenant_db_user%"
echo " - ontology name: %tenant_ontology%"
echo " - base database: %base_db_name%"
echo " - base database user: %base_db_user%"
echo " - tenant company name: %tenant_company%"
echo " - tenant first name: %tenant_first_name%"
echo " - tenant last name: %tenant_last_name%"
echo " - tenant email address: %tenant_email%"
echo " - tenant login name: %tenant_user_name%"

set /P c=Are you sure you want to continue[Y/N]?
if /I "%c%" EQU "Y" goto :DOCREATE
if /I "%c%" EQU "N" goto :DOEXIT

:DOCREATE
	echo "Running the db script"
	REM adding new teneant db need to create db first
	IF "%choice%"=="1" (
		echo "Creating db on user input"
		db2 CREATE DATABASE %tenant_db_name% AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY DEFAULT COLLATE USING SYSTEM PAGESIZE 32768
		db2 CONNECT TO %tenant_db_name%
		db2 GRANT CONNECT,DATAACCESS ON DATABASE TO USER %tenant_db_user%
		db2 GRANT USE OF TABLESPACE USERSPACE1 TO USER %tenant_db_user%
		db2 CONNECT RESET
	)

	REM create schema
	echo "Connecting to db and creating schema"
	db2 CONNECT TO %tenant_db_name%
	db2 CREATE SCHEMA %tenant_ontology%
	db2 SET SCHEMA %tenant_ontology%

	REM create tables
	echo "creating schema tables"
	db2 -stvf sql\CreateBacaTables.sql

	REM table permissions to tenant user
	echo "Giving  permissions on tables"
	db2 GRANT ALTER ON TABLE DOC_CLASS TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE DOC_ALIAS TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE KEY_CLASS TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE KEY_ALIAS TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE CWORD TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE HEADING TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE HEADING_ALIAS TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE USER_DETAIL TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE INTEGRATION TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE IMPORT_ONTOLOGY TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE API_INTEGRATIONS_OBJECTSSTORE TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE SMARTPAGES_OPTIONS TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE FONTS TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE FONTS_TRANSID TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE DB_BACKUP TO USER %tenant_db_user%

	REM load the tenant Db
	echo "Loading default data into tables"
	db2 load from CSVFiles\doc_class.csv of del modified by identityoverride insert into doc_class
	db2 load from CSVFiles\key_class.csv of del modified by identityoverride insert into key_class
	db2 load from CSVFiles\doc_alias.csv of del modified by identityoverride insert into doc_alias
	db2 load from CSVFiles\key_alias.csv of del modified by identityoverride insert into key_alias
	db2 load from CSVFiles\cword.csv of del modified by identityoverride insert into cword
	db2 load from CSVFiles\heading.csv of del modified by identityoverride insert into heading
	db2 load from CSVFiles\heading_alias.csv of del modified by identityoverride insert into heading_alias
	db2 load from CSVFiles\key_class_dc.csv of del modified by identityoverride insert into key_class_dc
	db2 load from CSVFiles\doc_alias_dc.csv of del modified by identityoverride insert into doc_alias_dc
	db2 load from CSVFiles\key_alias_dc.csv of del modified by identityoverride insert into key_alias_dc
	db2 load from CSVFiles\key_alias_kc.csv of del modified by identityoverride insert into key_alias_kc
	db2 load from CSVFiles\heading_dc.csv of del modified by identityoverride insert into heading_dc
	db2 load from CSVFiles\heading_alias_dc.csv of del modified by identityoverride insert into heading_alias_dc
	db2 load from CSVFiles\heading_alias_h.csv of del modified by identityoverride insert into heading_alias_h
	db2 load from CSVFiles\cword_dc.csv of del modified by identityoverride insert into cword_dc
	db2 connect reset
		
	REM Insert InsertTenant
	echo "Connecting to base database to insert tenant info"
	db2 connect to %base_db_name%
	db2 set schema %base_db_user%
	db2 insert into TENANTINFO (tenantid,ontology,tenanttype,rdbmsengine,bacaversion,rdbmsconnection) values ( '%tenant_id%', '%tenant_ontology%', 0, 'DB2', '1.1',  encrypt('DATABASE=%tenant_db_name%;HOSTNAME=%baca_database_server_ip%;PORT=%baca_database_port%;PROTOCOL=TCPIP;UID=%tenant_db_user%;PWD=%tenant_db_pwd%;','AES_KEY'))
	db2 connect reset
	
	REM Insert InsertUser
	echo "Connecting to tenant database to insert initial userinfo"
	db2 connect to %tenant_db_name%
	db2 set schema %tenant_ontology%
	db2 insert into user_detail (email,first_name,last_name,user_name,company,expire) values ('%tenant_email%','%tenant_first_name%','%tenant_last_name%','%tenant_user_name%','%tenant_company%',10080)
	db2 insert into login_detail (user_id,role,status,logged_in) select user_id,'Admin','1',0 from user_detail where email='%tenant_email%'
	db2 connect reset
	goto END
:DOEXIT
	echo "Exited on user input"
	goto END
:END
	echo "END"
	
ENDLOCAL
