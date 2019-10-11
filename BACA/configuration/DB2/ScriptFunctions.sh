#!/usr/bin/env bash

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