#!/usr/bin/env bash

###############################################################################
# @---lm_copyright_start
# Licensed Materials - Property of IBM
# 5737-I23, 5900-A30
# Copyright IBM Corp. 2018 - 2021. All Rights Reserved.
# U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#@---lm_copyright_end
###############################################################################

# This script is used to collect the IBM Business Automation Document Processing engine logs
# Updated 10/18/2022 for version 22.0.2 - RW

export TMP_DIR="/tmp/aca"
export MY_NAMESPACE=$(oc project --short=true)
export META_NAME=$(oc get icp4aclusters -o name | awk -F "/" {'print $2'})
export CA_CONTAINERS=$(oc get deploy,sts -lapp.kubernetes.io/name=$META_NAME-aca -oname | awk -F / {'print $2'} |grep -v redis-ha-server |sort)
export CP4BA_OP_POD=$(oc get po --no-headers |grep ibm-cp4a-operator | awk {'print $1'})
export LOG_OUTPUT=$(oc extract configmap/$META_NAME-aca-ini --to=- --keys=ibm_ca.ini 2>/dev/null|grep LOG_OUTPUT| awk -F "= " {'print $2'})

#To get the rabbitmq logs, change to true.
export INCLUDE_RABBITMQ="false"

echo "======================================="

echo -e "\x1B[1;31mThis is a utility script to collect the IBM Business Automation Document Processing engine logs along with the Operator's logs. The logs are in the $TMP_DIR directory.  You must be logged on to your cluster and associated to the namespace where CP4BA is deployed before running this script.. \x1B[0m"

echo "======================================="

function confirmInfo(){
  # Confirm information is correct
  while [[  $confirm != "n" && $confirm != "y" && $confirm != "yes" && $confirm != "no" ]]
  do
    echo
    echo -e "\x1B[1;31mNamespace/Project  = $MY_NAMESPACE\x1B[0m"
    echo -e "\x1B[1;31mCP4BA deployment   = $META_NAME\x1B[0m"
    echo -e "\x1B[1;31mLog ouput type     = $LOG_OUTPUT\x1B[0m"
    echo -e "\x1B[1;31mInclude RabbitMQ   = $INCLUDE_RABBITMQ\x1B[0m"
    echo -e "\x1B[1;31mWould you like to continue (y/n):\x1B[0m"
    read confirm
    confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
  done

  if [[ $confirm == "n" || $confirm == "no" ||  $confirm == "N" || $confirm == "No" ]]; then
    echo "Exiting...."
    exit 1
  fi
}

function createDir(){
  if [[ ! -d $TMP_DIR ]]; then
    echo "$TMP_DIR does not yet exist. Creating $TMP_DIR...."
    mkdir -p $TMP_DIR
  fi

  if [[ $? -ne 0 ]]; then
    echo -e "\x1B[1;31mFailed to create $TMP_DIR.  Please make sure you have permission to create sub-directories in $TMP_DIR\x1B[0m"
    echo "Exiting...."
    exit 1
  else
    echo  "Clear old logs from $TMP_DIR"
    rm -f $TMP_DIR/*.tar $TMP_DIR/*.log $TMP_DIR/aca.tar.gz 2> /dev/null
  fi
}

function getOpLog(){
  echo "Starting ICP4BA Operator log collection"
  if [[ -n $CP4BA_OP_POD ]]; then
    currentTS=$(date "+%Y%m%d%H%M")
    echo "Found $CP4BA_OP_POD"
    echo "Tar up logs in $CP4BA_OP_POD"
    oc exec $CP4BA_OP_POD -- tar -cf /tmp/operator-$currentTS.tar /logs/$CP4BA_OP_POD/ansible-operator/runner/icp4a.ibm.com/v1/ICP4ACluster/$MY_NAMESPACE/$META_NAME/artifacts 2>/dev/null
    echo "Copy operator-$currentTS.tar to $TMP_DIR then remove it from /tmp/operator-$currentTS.tar"
    oc cp $CP4BA_OP_POD:/tmp/operator-$currentTS.tar $TMP_DIR/operator-$currentTS.tar && oc exec $CP4BA_OP_POD -- rm -f /tmp/operator-$currentTS.tar 2>/dev/null
  else
    echo "Cannot find Operator pod.  Will skip collecting Operator's logs"
  fi
}

function getCAConfig(){
  echo "Getting Document Processing Engine's configmap"
  oc get cm $META_NAME-aca-config -oyaml > $TMP_DIR/CA-configmap.yaml
}

function getCALogfilesystem(){
  echo
  echo "Starting log collection"
  echo

  for c in $(echo $CA_CONTAINERS | sed "s/,/ /g")
  do
    if [[ $c == "$META_NAME-rabbitmq-ha" ]]; then
      if [[ $INCLUDE_RABBITMQ == "true" ]]; then
	    echo "======================================="
        echo "Get the first pod for $c"
        aca=$(oc get po |grep $c | head -1 | awk {'print $1'})
        echo "Tar up logs in $aca"
        oc exec $aca -- tar -cf /tmp/$c.tar /var/log/rabbitmq 2>/dev/null
        echo "Copy log from $aca to $TMP_DIR/$c then remove it from /tmp/$c.tar"
        oc cp $aca:/tmp/$c.tar $TMP_DIR/$c.tar && oc exec $aca -- rm -f /tmp/$c.tar 2>/dev/null
	    fi
    else
      echo "======================================="
      echo "Get the first pod for $c"
      aca=$(oc get po |grep $c |grep -v "rr-" | head -1 | awk {'print $1'})
      echo "Tar up logs in $aca"
      oc exec $aca -- tar -cf /tmp/$c.tar /var/log/$c 2>/dev/null
      echo "Copy log from $aca to $TMP_DIR/$c then remove it from /tmp/$c.tar"
      oc cp $aca:/tmp/$c.tar $TMP_DIR/$c.tar && oc exec $aca -- rm -f /tmp/$c.tar 2>/dev/null
    fi
  done
  echo "======================================="
}

function getCALogstdout(){
  echo
  echo "Starting log collection"
  echo
  
  for c in $(echo $CA_CONTAINERS| sed "s/,/ /g")
  do
    if [[ $c == "$META_NAME-rabbitmq-ha" ]]; then
      if [[ $INCLUDE_RABBITMQ == "true" ]]; then
        echo "======================================="
        echo "Get pod list for $c"
        export POD_LIST=$(oc get po |grep $c | awk {'print $1'})
        for d in $(echo $POD_LIST| sed "s/,/ /g")
        do
          echo "---------------------------------------"
          echo "Copy log from $d to $TMP_DIR/$d.log"
          oc logs $d > $TMP_DIR/$d.log
        done
      fi    
    else
      echo "======================================="
      echo "Get pod list for $c"
      export POD_LIST=$(oc get po |grep $c | awk {'print $1'})
      for d in $(echo $POD_LIST| sed "s/,/ /g")
      do
        echo "---------------------------------------"
        echo "Copy log from $d to $TMP_DIR/$d.log"
        oc logs $d > $TMP_DIR/$d.log
      done
    fi
  done
  echo "======================================="
}

function compressLog(){
  echo
  echo "Compressing log files"
  if [[ $LOG_OUTPUT == "stdout" ]]; then
    cd $TMP_DIR && XZ_OPT=-9 tar -Jcvf ./aca.tar.gz ./*.tar ./*.log ./CA-configmap.yaml --remove-files
  else
    cd $TMP_DIR && XZ_OPT=-9 tar -Jcvf ./aca.tar.gz ./*.tar ./CA-configmap.yaml --remove-files
  fi
  echo
  echo -e "\x1B[1;31mCreated compressed file $TMP_DIR/aca.tar.gz \x1B[0m"
}

# Main
confirmInfo
createDir
getOpLog
getCAConfig
if [[ $LOG_OUTPUT == "filesystem" ]]; then
  getCALogfilesystem
else
  getCALogstdout
fi
compressLog
