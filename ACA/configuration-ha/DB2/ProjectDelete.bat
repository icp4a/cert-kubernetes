::
:: Licensed Materials - Property of IBM
:: 5737-I23
:: Copyright IBM Corp. 2018 - 2022. All Rights Reserved.
:: U.S. Government Users Restricted Rights:
:: Use, duplication or disclosure restricted by GSA ADP Schedule
:: Contract with IBM Corp.
::
@echo off

SETLOCAL EnableDelayedexpansion

Title Delete ADP Project Databases that are marked for deletion

@echo:
@echo:
echo -------------------------------------------------------------------------------
@echo:
echo This script will delete all ADP project databases that are marked for deletion.
@echo:
echo -------------------------------------------------------------------------------
@echo:

set validArgs[1]=Y
set validArgs[2]=y
set validArgs[3]=Yes
set validArgs[4]=N
set validArgs[5]=n
set validArgs[6]=No

:CONFIRMLOOP1
  set /P confirm1=Are you sure you want to continue[Y/N]?
  REM Check if the response is valid or not
  for /L %%i in (1,1,6) do if /I "%confirm1%" equ "!validArgs[%%i]!" goto :PROCESSLOOP1 
  REM if not a valid response, ask again
  goto :CONFIRMLOOP1
:PROCESSLOOP1
if /I "%confirm1%" EQU "N" goto :DOEXIT
if /I "%confirm1%" EQU "n" goto :DOEXIT
if /I "%confirm1%" EQU "No" goto :DOEXIT


@echo:
echo - This script will query the DPE Base database to determine if which project databases (if any) are marked for deletion...
@echo:
set /p base_db_name= "Enter the name of the DPE Base database. If nothing is entered, we will use the default value 'CABASEDB': "
IF NOT DEFINED base_db_name SET "base_db_name=CABASEDB"

@echo:
set /p base_db_user= "Enter the name of the database user for DPE Base database. If nothing is entered, we will use the default value 'CABASEUSER' : "
IF NOT DEFINED base_db_user SET "base_db_user=CABASEUSER"


Set DBListFile=db_list_to_delete.txt
If exist "%DBListFile%" Del "%DBListFile%"
If exist "%DBListFile%".trim Del "%DBListFile%".trim
If exist "%DBListFile%".trim.csv Del "%DBListFile%".trim.csv

@echo:
@echo:
echo - Checking the Base database for project databases marked for deletion

@echo:
echo Login to DPE Base database %base_db_name%
db2 connect to %base_db_name%
IF %ERRORLEVEL% NEQ 0 (
  @echo:
  echo ----- ERROR ----
  echo DB2 connection to %base_db_name% failed. Please confirm if the name is correct and you are running as user with DB2 admin privileges
  goto :END
)
echo Setting schema to %base_db_user%
db2 set schema %base_db_user%
db2 -x "select dbname,dbuser,tenantid,project_guid from tenantinfo where dbstatus=2" > %DBListFile%
IF %ERRORLEVEL% NEQ 0 (
   @echo:
   @echo:
   echo -- No databases found that are marked for deletion [dbstatus=2].
   echo Check the file '%DBListFile%'  
   echo - If there is an error in the file, please confirm if the database name and username/schema name are correct.
   echo - If the file is empty, the query did no find any databases marked for deletion [dbstatus=2]
   goto :END
)

@echo:
echo Logout DB2 database
db2 connect reset

powershell -Command "Get-Content %DBListFile% | Foreach {$_.TrimEnd()} | Set-Content -encoding ascii %DBListFile%.trim"

If not exist "%DBListFile%".trim (
  @echo:
  echo No databases found that were marked for deletion [dbstatus=2] 
  goto :END
)

REM Convert the list to comma-separted list to make it easier to parse
powershell -Command "Get-Content %DBListFile%.trim | Foreach {$_ -split '\s+',4,\"RegexMatch\" -join ','} | Set-Content -encoding ascii %DBListFile%.trim.csv"

set /a DBCOUNT=0
for /F "tokens=1-4 delims=," %%A in (%DBListFile%.trim.csv) do (
    set /a DBCOUNT+=1
    set dbname[!DBCOUNT!]=%%~A
    set dbuser[!DBCOUNT!]=%%~B
    set tenantid[!DBCOUNT!]=%%~C
    set project_guid[!DBCOUNT!]=%%~D
)

@echo:
echo -- %DBCOUNT% total project databases found marked for deletion (where db2status=2)

if %DBCOUNT% GTR 0 (
  @echo:
  echo ---------------------------------------------------------------------------------------------------
  echo IMPORTANT: The following project databases will be deleted.  Please verify this is what you want: 
  echo ---------------------------------------------------------------------------------------------------
)

for /l %%i in (1,1,%DBCOUNT%) do (
  echo  [%%i] Project ID: !project_guid[%%i]!  tenant ID: !tenantid[%%i]!  database name: !dbname[%%i]!
)

@echo:
:CONFIRMLOOP2
  set /P confirm2=Are you sure you want to continue[Y/N]?
  REM Check if the response is valid or not
  for /L %%i in (1,1,6) do (if /I "%confirm2%" equ "!validArgs[%%i]!" goto :PROCESSLOOP2)
  REM if not a valid response, ask again
  goto :CONFIRMLOOP2
:PROCESSLOOP2
  if /I "%confirm2%" EQU "N" goto :DOEXIT
  if /I "%confirm2%" EQU "n" goto :DOEXIT
  if /I "%confirm2%" EQU "No" goto :DOEXIT


REM For loop to process each database to delete

for /l %%j in (1,1,%DBCOUNT%) do (
  @echo:
  echo --- Preparing to delete database:  Project ID: !project_guid[%%j]!  tenant ID: !tenantid[%%j]!  database name: !dbname[%%j]!
  @echo:

  REM ----------- DEACTIVATE DB -----------
  echo - Deactivate database !dbname[%%j]!  
  db2 "deactivate db !dbname[%%j]!"
  @echo:
  
  echo connect to !dbname[%%j]!
  db2 "connect to !dbname[%%j]!"
  IF %ERRORLEVEL% NEQ 0 (
    @echo:
    echo ----- ERROR ----
    echo DB2 connection to !dbname[%%j]! failed. Please confirm the database exists and you are running as user with DB2 admin privileges
    goto :END
  )
  
  REM ----------- QUIESCE DB -----------    
  @echo:
  echo - Quiesce database !dbname[%%j]!
  db2 -x "QUIESCE DATABASE IMMEDIATE FORCE CONNECTIONS" > db2_quiesce_result.txt
  
  REM Check result of command for errors
  powershell -Command "(Select-String -Path db2_quiesce_result.txt -Pattern 'DB20000I|SQL1371W' -Quiet )" > db2_quiesce_result_code.txt
  for /f %%A in (db2_quiesce_result_code.txt) do set cmdresult=%%A
  If not "!cmdresult!"=="True" (
    @echo:
    echo ----- ERROR ----
    echo Quiesce database !dbname[%%j]! failed. Check the message in file db2_quiesce_result.txt
    echo db2 connect reset
    db2 connect reset
    goto :END
  )
  
  @echo:
  echo - Unquiesce database !dbname[%%j]!
  db2 "unquiesce database"
  db2 "connect reset"

  REM ----------- DROP DB -----------    
  @echo:
  echo - Drop database !dbname[%%j]!
  db2 -x "drop db !dbname[%%j]!" > db2_drop_result.txt
  
  REM Check result of command for errors
  powershell -Command "(Select-String -Path db2_drop_result.txt -Pattern 'DB20000I' -Quiet )" > db2_drop_result_code.txt
  for /f %%A in (db2_drop_result_code.txt) do set cmdresult=%%A
  if NOT "!cmdresult!"=="True" (
     @echo:
     echo ----- ERROR ----
     echo Drop database !dbname[%%j]! failed. Check the message in file db2_drop_result.txt
     goto :END
  )
  
  @echo:
  echo - Database !dbname[%%j]! has been dropped
  
  REM ----------- REMOVE tenant from TENANTINFO in BASE DB ----------
  @echo:
  echo Connecting to Base DB %base_db_name% to remove project DB !dbname[%%j]! , tenantid !tenantid[%%j]!
  db2 "connect to %base_db_name%"
  db2 "set schema %base_db_user%"
  
  @echo:
  echo - Deleting row from TENANTINFO table where dbname='!dbname[%%j]!'
  db2 -x "delete from tenantinfo where dbname='!dbname[%%j]!'"  > db2_delete_result.txt
  
  @echo:
  echo db2 connect reset
  db2 connect reset
     
  REM Check result of command for errors
  powershell -Command "(Select-String -Path db2_delete_result.txt -Pattern 'DB20000I|SQL0100W' -Quiet )" > db2_delete_result_code.txt
  for /f %%A in (db2_delete_result_code.txt) do set cmdresult=%%A
  if NOT "!cmdresult!"=="True" (
     @echo:
     echo ----- ERROR ----
     echo Delete database !dbname[%%j]! from TENANTINFO table in Base DB failed. Check the message in file db2_delete_result.txt
     goto :END
  )
  
  @echo:
  echo --- Deleted database:  Project ID: !project_guid[%%j]!  tenant ID: !tenantid[%%j]!  database name: !dbname[%%j]!

)

goto :END
    
:DOEXIT
    echo Exited on user input
    goto :END
:END
    @echo:
    echo End of script
  
ENDLOCAL
