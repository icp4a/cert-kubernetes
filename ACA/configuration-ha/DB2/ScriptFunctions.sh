#!/usr/bin/env bash

##
## Licensed Materials - Property of IBM
## 5737-I23
## Copyright IBM Corp. 2018 - 2021. All Rights Reserved.
## U.S. Government Users Restricted Rights:
## Use, duplication or disclosure restricted by GSA ADP Schedule
## Contract with IBM Corp.
##

function askForConfirmation(){
  while [[  $confirmation != "y" && $confirmation != "n" && $confirmation != "yes" && $confirmation != "no" ]] # While confirmation is not y or n...
  do
    echo
    echo -e "Would you like to continue (Y/N):"
    read confirmation
    confirmation=$(echo "$confirmation" | tr '[:upper:]' '[:lower:]')
  done

  if [[ $confirmation == "n" || $confirmation == "no" ]]
    then
      exit
  fi
}