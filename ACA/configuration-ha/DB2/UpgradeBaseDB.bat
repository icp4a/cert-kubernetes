::
:: Licensed Materials - Property of IBM
:: 5737-I23
:: Copyright IBM Corp. 2018 - 2022. All Rights Reserved.
:: U.S. Government Users Restricted Rights:
:: Use, duplication or disclosure restricted by GSA ADP Schedule
:: Contract with IBM Corp.
::
@echo off

powershell -ExecutionPolicy RemoteSigned -Command ". .\ScriptFunctions.ps1 ; Run-UpgradeBaseDB"
