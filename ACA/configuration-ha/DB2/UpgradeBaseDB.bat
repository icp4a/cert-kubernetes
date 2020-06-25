@echo off
REM ************************************************************************************
REM * @---lm_copyright_start
REM * 5737-I23, 5900-A30
REM * Copyright IBM Corp. 2018 - 2020. All Rights Reserved.
REM * U.S. Government Users Restricted Rights:
REM * Use, duplication or disclosure restricted by GSA ADP Schedule
REM * Contract with IBM Corp.
REM * @---lm_copyright_end
REM ************************************************************************************

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
	db2 alter table tenantinfo add column last_job_run_time BIGINT not null with default 0
	db2 alter table tenantinfo add column dbstatus smallint not null with default 0
	db2 update tenantinfo set bacaversion = 1.5
	db2 connect reset
	goto END
:DOEXIT
	echo "Exited on user input"
	goto END
:END
	echo "END"

ENDLOCAL
