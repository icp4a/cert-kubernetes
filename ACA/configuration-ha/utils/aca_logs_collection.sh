#!/usr/bin/env bash

###############################################################################
# @---lm_copyright_start
# Licensed Materials - Property of IBM
# 5737-I23, 5900-A30
# Copyright IBM Corp. 2018 - 2020. All Rights Reserved.
# U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#@---lm_copyright_end
###############################################################################


#This script is used to collect logs for IBM Business Automation Content Analyzer.

export CA_CONTAINERS="frontend,backend,callerapi,ocr-extraction,pdfprocess,setup,classifyprocess-classify,processing-extraction,postprocessing,updatefiledetail,utf8process"
export TMP_DIR="/tmp/aca"
echo "======================================="

echo -e "\x1B[1;31mThis is a utility script to collect the logs for all ACA pods and the logs will saved in $TMP_DIR directory .  You must logon to your cluster and associate to the namespace where ACA is being deployed before running this script.. \x1B[0m"

echo "======================================="

while [[  $confirm != "n" && $confirm != "y" && $confirm != "yes" && $confirm != "no" ]]
do
    echo -e "\x1B[1;31mWould you like to continue (y/n):\x1B[0m"
    read confirm
    confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
done

if [[ $confirm == "n" || $confirm == "no" ||  $confirm == "N" || $confirm == "No" ]]
then
    echo "Exiting...."
    exit 1
fi

if [[ ! -d $TMP_DIR ]]; then
    echo "Cannot find $TMP_DIR. Creating $TMP_DIR...."
    mkdir -p $TMP_DIR
fi

if [[ $? -ne 0 ]]; then
    echo -e "\x1B[1;31mFailed to create $TMP_DIR.  Please make sure you have permission to create sub-directories in /tmp\x1B[0m"
    echo "Exiting...."
    exit 1
fi

echo "About to get ACA logs from $(kubectl config current-context | awk -F '/' {'print $1'} ) namespace"


for c in $(echo $CA_CONTAINERS | sed "s/,/ /g")
do
    if [[ $c == "frontend" ||  $c == "backend" ]]; then
        echo "======================================="
        echo "Get the first pod for $c"
        aca=$(kubectl get po |grep $c | head -1 | awk {'print $1'})
        echo "Tar up logs in $aca"
        kubectl exec $aca -- tar -cf /var/www/app/current/$c.tar /var/log/$c
        echo "Copy log from $aca to $TMP_DIR/$c"
        kubectl cp $aca:/var/www/app/current/$c.tar $TMP_DIR/$c.tar
    else
        echo "======================================="
        echo "Get the first pod for $c"
        aca=$(kubectl get po |grep $c | head -1 | awk {'print $1'})
        echo "Tar up logs in $aca"
        kubectl exec  $aca -- tar -cf /app/$c.tar /var/log/$c
        echo "Copy log from $aca to $TMP_DIR/$c"
        kubectl cp $aca:/app/$c.tar $TMP_DIR/$c.tar
    fi

done

echo -e "\x1B[1;31mThe logs are located at $TMP_DIR \x1B[0m"