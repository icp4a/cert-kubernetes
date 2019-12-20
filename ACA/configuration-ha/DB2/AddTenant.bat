@echo off

SETLOCAL

IF NOT DEFINED skip_create_tenant_db (
	set skip_create_tenant_db=false
)

IF "%skip_create_tenant_db%"=="true" (
    echo --
    echo This script will initialize an existing DB2 database for use as a BACA tenant database and add an ontology.
	set choice="2"
	echo --
) ELSE (
    echo --
	echo Enter '1' to create an new DB2 database and initialize the database as a tenant DB and create an ontology. An existing database user must exist.
	echo Enter '2' to add an ontology for an existing tenant database.
	echo Enter '3' to abort.

	set /p choice="Type input: "
)


if /I "%choice%" EQU "3" goto :DOEXIT

set /p tenant_id= Enter the tenant ID for the new tenant: (eg. t4900) :

IF NOT "%skip_create_tenant_db%"=="true" (
  set /p tenant_db_name= "Enter the name of the new DB2 database to create for the BACA tenant. Please follow the DB2 naming rules :"
) ELSE (
  set /p tenant_db_name= "Enter the name of the existing DB2 database to use for the BACA tenant database (eg. t4900) :"
)
set tenant_dsn_name=%tenant_db_name%

set /p baca_database_server_ip= "Enter the host/IP of the DB2 database server for the tenant database.   :"  

set /p baca_database_port= "Enter the port of the DB2 database server for the tenant database :" 

set /p tenant_db_user= "Please enter the name of tenant database user. If no value is entered we will use the following default value 'tenantuser' :" 
IF NOT DEFINED tenant_db_user SET "tenant_db_user=tenantuser"

REM Use powershell to mask password 
set "psCommand=powershell -Command "$pword = read-host 'Enter the password for the tenant database user:' -AsSecureString ; ^
    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pword); ^
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)""
for /f "usebackq delims=" %%p in (`%psCommand%`) do set tenant_db_pwd=%%p
REM Alternative way to prompt for pwd without masking
REM set /p tenant_db_pwd= "Enter the password for the tenant database user:"

set /p tenant_ontology= "Enter the tenant ontology name. If nothing is entered, the default name will be used 'default' :" 
IF NOT DEFINED tenant_ontology SET "tenant_ontology=default"

set /p base_db_name= "Enter the name of the DB2 BACA Base database with the TENANTINFO Table. If nothing is entered, we will use the following default value 'CABASEDB': "
IF NOT DEFINED base_db_name SET "base_db_name=CABASEDB"

set /p base_db_user= "Enter the name of the database user for the Base BACA database. If nothing is entered, we will use the following default value 'CABASEUSER' : "
IF NOT DEFINED base_db_user SET "base_db_user=CABASEUSER"

set /p tenant_company= "Please enter the company name for the initial BACA user :" 

set /p tenant_first_name= "Please enter the first name for the initial BACA user :"

set /p tenant_last_name= "Please enter the last name for the initial BACA user :"

set /p tenant_email= "Please enter a valid email address for the initial BACA user : "

set /p tenant_user_name= "Please enter the login name for the initial BACA user (IMPORTANT: if you are using LDAP, you must use the LDAP user name):" 

IF NOT DEFINED rdbmsconnection SET "rdbmsconnection=DSN=%tenant_dsn_name%;UID=%tenant_db_user%;PWD=%tenant_db_pwd%;"
set /p ssl= "Please enter if database is enabled for SSL default is false [Y/N] :"
if /I "%ssl%" EQU "Y" (
	SET rdbmsconnection=%rdbmsconnection%Security=SSL;
)
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
echo " - tenant ssl: %ssl%"

set /P c=Are you sure you want to continue[Y/N]?
if /I "%c%" EQU "Y" goto :DOCREATE
if /I "%c%" EQU "N" goto :DOEXIT

:DOCREATE
	echo "Running the db script"
	REM adding new teneant db need to create db first
	IF "%choice%"=="1" (
		echo "Creating database"
		db2 CREATE DATABASE %tenant_db_name% AUTOMATIC STORAGE YES USING CODESET UTF-8 TERRITORY DEFAULT COLLATE USING SYSTEM PAGESIZE 32768
		db2 CONNECT TO %tenant_db_name%
		db2 GRANT CONNECT,DATAACCESS ON DATABASE TO USER %tenant_db_user%
		db2 GRANT USE OF TABLESPACE USERSPACE1 TO USER %tenant_db_user%
		db2 CONNECT RESET
	)

	REM create schema
	echo --
	echo "Connecting to db and creating schema"
	db2 CONNECT TO %tenant_db_name%
	db2 CREATE SCHEMA %tenant_ontology%
	db2 SET SCHEMA %tenant_ontology%

	REM create tables
	echo --
	echo "Creating BACA tables"
	db2 -stvf sql\CreateBacaTables.sql

	REM table permissions to tenant user
	echo --
	echo "Giving permissions on tables"
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
	db2 GRANT ALTER ON TABLE PATTERN TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE DOCUMENT TO USER %tenant_db_user%
	db2 GRANT ALTER ON TABLE TRAINING_LOG TO USER %tenant_db_user%

	REM load the tenant Db
	echo "Loading default data into tables"
	db2 load from CSVFiles\doc_class.csv of del insert into doc_class
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

    echo --
	echo "SET INTEGRITY ..."
	db2 set integrity for key_class_dc immediate checked
	db2 set integrity for doc_alias_dc immediate checked
	db2 set integrity for key_alias_dc immediate checked
	db2 set integrity for key_alias_kc immediate checked
	db2 set integrity for heading_dc immediate checked
	db2 set integrity for heading_alias_dc immediate checked
	db2 set integrity for heading_alias_h immediate checked
	db2 set integrity for cword_dc immediate checked

    echo --
	echo "ALTER TABLE ..."
	db2 alter table doc_class alter column doc_class_id restart with 10
	db2 alter table doc_alias alter column doc_alias_id restart with 11
	db2 alter table key_class alter column key_class_id restart with 202
	db2 alter table key_alias alter column key_alias_id restart with 239
	db2 alter table cword alter column cword_id restart with 76
	db2 alter table heading alter column heading_id restart with 3
	db2 alter table heading_alias alter column heading_alias_id restart with 3 

	db2 connect reset

	REM Insert InsertTenant
	echo --
	echo "Connecting to base database to insert tenant info"
	db2 connect to %base_db_name%
	db2 set schema %base_db_user%
	db2 insert into TENANTINFO (tenantid,ontology,tenanttype,dailylimit,rdbmsengine,bacaversion,rdbmsconnection,dbname,dbuser,tenantdbversion) values ( '%tenant_id%', '%tenant_ontology%', 0, 0, 'DB2', '1.3',  encrypt('%rdbmsconnection%','AES_KEY'),'%tenant_db_name%','%tenant_db_user%','1.3')
	db2 connect reset
	
	REM Insert InsertUser
	echo --
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
    SET skip_create_tenant_db=
	echo "END"
	
ENDLOCAL
