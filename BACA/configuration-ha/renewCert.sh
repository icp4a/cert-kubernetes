#!/usr/bin/env bash
#
# Licensed Materials - Property of IBM
# 6949-68N
#
# © Copyright IBM Corp. 2018 All Rights Reserved
#

. ./common.sh
. ./bashfunctions.sh
. ./createSSLCert.sh


today=`date +%Y-%m-%d.%H:%M:%S`
echo $today

  
# confirm they want to delete
echo
echo -e "\x1B[1;31mThis script will RENEW all the certificates for IBM Business Automation Content Analyzer in $KUBE_NAME_SPACE \x1B[0m"
echo
echo -e "\x1B[1;31mThe script will delete ALL the  IBM Business Automation Content Analyzer pods in $KUBE_NAME_SPACE.  Therefore, you must make sure to backup your ontology,etc... and make sure there are no activities on the system \x1B[0m"
echo
ls -al *.pem > /dev/null
if [[ $? == "0" ]]; then
    echo -e "\x1B[1;31mBased on the PEM files in the $PWD, the expirations date for them are: \x1B[0m"

    for pem in ./*.pem; do
       printf '%s: %s\n' \
           "$pem expries on" \
          "$(date --date="$(openssl x509 -enddate -noout -in "$pem"|cut -d= -f 2)" --iso-8601)"
    done
else
    echo -e "\x1B[1;31mWe could not find any existing PMR files in $PWD \x1B[0m"
fi

while [[  $renewConfirm != "y" && $renewConfirm != "n" && $renewConfirm != "yes" && $renewConfirm != "no" ]] # While deleteconfirm is not y or n...
do
    echo -e "\x1B[1;31mWould you like to continue (Y/N):\x1B[0m"
    read renewConfirm
    renewConfirm=$(echo "$renewConfirm" | tr '[:upper:]' '[:lower:]')
done


if [[ $renewConfirm == "n" || $renewConfirm == "no" ]]
then
    exit
else
    loginToCluster
    createSSLCert
    createSecret
    echo  -e "\x1B[1;31m Deleting all Content Analyzer's pods ...  "
    kubectl -n sp delete --all pods --force --grace-period=0
fi