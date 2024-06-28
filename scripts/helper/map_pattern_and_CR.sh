#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

#################debug##########################
# PATTERNS_SELECTED=("FileNet Content Manager,Operational Decision Manager,Automation Decision Services,Business Automation Application,Business Automation Workflow, Workflow Runtime,Automation Workstream Services,IBM Automation Document Processing, Runtime Environment")
#################debug###d######################
function map_pattern_and_CR(){
  i=0
  IFS=$','
  array=(${PATTERNS_SELECTED})
  for item in ${array[@]}
  do
    if [[ "${item}" =~ "FileNet Content Manager" ]]; then
      cr_file_name[${#cr_file_name[*]}]="content"
    elif [[ "${item}" =~ "Operational Decision Manager" ]]; then
      cr_file_name[${#cr_file_name[*]}]="decisions"
    elif [[ "${item}" =~ "Automation Decision Services" ]]; then
      cr_file_name[${#cr_file_name[*]}]="decisions_ads"
    elif [[ "${item}" =~ "Business Automation Application" ]]; then
      cr_file_name[${#cr_file_name[*]}]="application"
    elif [[ "${item}" =~ "Workflow Authoring" ]]; then
      cr_file_name[${#cr_file_name[*]}]="workflow_authoring"
    elif [[ "${item}" =~ "Workflow Runtime" ]]; then
      cr_file_name[${#cr_file_name[*]}]="workflow"
    elif [[ "${item}" =~ "Automation Workstream Services" ]]; then
      cr_file_name[${#cr_file_name[*]}]="workstreams"
    elif [[ "${item}" =~ "Automation Document Processing" ]]; then
      cr_file_name[${#cr_file_name[*]}]="document_processing"
    fi
  done
}
map_pattern_and_CR

# for item in ${cr_file_name[@]}
# do
#   echo $item
# done