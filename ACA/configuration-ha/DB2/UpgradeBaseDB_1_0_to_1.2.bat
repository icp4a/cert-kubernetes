@echo off

SETLOCAL

set /p base_db_name= Please enter a valid value for the base database name :
set /p base_db_user= Please enter a valid value for the base database user name :


echo
echo "-- Please confirm these are the desired settings:"
echo " - Base database name: %base_db_name%"
echo " - Base database user name: %base_db_user%"

set /P c=Are you sure you want to continue[Y/N]?
if /I "%c%" EQU "Y" goto :DOCREATE
if /I "%c%" EQU "N" goto :DOEXIT

:DOCREATE
	echo "Connecting to db and schema"
	db2 CONNECT TO %base_db_name%
	db2 SET SCHEMA %base_db_user%
	db2 alter table tenantinfo add column dailylimit bigint not null with default 0
    db2 alter table tenantinfo add column dbname varchar(255)
    db2 alter table tenantinfo add column dbuser varchar(255)
    db2 alter table tenantinfo add column featureflags bigint not null with default 0
    db2 alter table tenantinfo add column tenantdbversion varchar(255)
    db2 update tenantinfo set bacaversion='1.2'
    db2 update tenantinfo set tenantdbversion='1.2'
    db2 reorg table tenantinfo
	db2 connect reset
	goto END
:DOEXIT
	echo "Exited on user input"
	goto END
:END
	echo "END"

ENDLOCAL