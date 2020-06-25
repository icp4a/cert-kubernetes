#!/usr/bin/env bash

# @---lm_copyright_start
# 5737-I23, 5900-A30
# Copyright IBM Corp. 2018 - 2020. All Rights Reserved.
# U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#@---lm_copyright_end

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