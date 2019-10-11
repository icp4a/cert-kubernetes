#!/usr/bin/env bash
#
# Licensed Materials - Property of IBM
# 6949-68N
#
# © Copyright IBM Corp. 2018 All Rights Reserved
#

. ./common.sh
. ./bashfunctions.sh

today=`date +%Y-%m-%d.%H:%M:%S`
echo $today

if [ -z "$KUBE_NAME_SPACE" ]
then 
  echo -e "\x1B[1;31mThe KUBE_NAME_SPACE is not set.  The script will exit.  To delete everything in the IBM Business Automation Content Analyzer namespace, set the KUBE_NAME_SPACE variable to the name of the namespace where IBM Business Automation Content Analyzer is deployed and rerun. :\x1B[0m"
  exit
fi

if [ $KUBE_NAME_SPACE == "default" ]
then 
  echo -e "\x1B[1;31mThe KUBE_NAME_SPACE is set to default.  The script will exit.  We cannot delete all resources from the default namespace.  To delete everything in the IBM Business Automation Content Analyzer namespace, set the KUBE_NAME_SPACE variable to the name of the namespace where IBM Business Automation Content Analyzer is deployed and rerun. :\x1B[0m"
  exit
fi
  
# confirm they want to delete
echo
echo -e "\x1B[1;31mThis script will DELETE all the resources, including services, deployments, and pvc, in the namespace : $KUBE_NAME_SPACE .  And then delete the namespace $KUBE_NAME_SPACE \x1B[0m"
echo
echo -e "\x1B[1;31mPlease only execute if you are SURE you want to DELETE everything from your namespace $KUBE_NAME_SPACE . \x1B[0m"
echo
echo -e "\x1B[1;31mWARNING: Please note that on ICP this script may not be able to successfully remove all the pods.  The pods and the namespace might be left in 'terminating' state . \x1B[0m"
echo

while [[  $deleteconfirm != "y" && $deleteconfirm != "n" && $deleteconfirm != "yes" && $deleteconfirm != "no" ]] # While deleteconfirm is not y or n...
do
    echo -e "\x1B[1;31mWould you like to continue (Y/N):\x1B[0m"
    read deleteconfirm
    deleteconfirm=$(echo "$deleteconfirm" | tr '[:upper:]' '[:lower:]')
done


if [[ $deleteconfirm == "n" || $deleteconfirm == "no" ]]
then
    exit
fi

#Logon to kubectl
loginToCluster


echo "----- Deleting Celery ..."
cwd=$(pwd)

#export HELM="./helm-chart/baca-celery"
#export HELM1="./helm-chart/baca-userportal"
#echo
#echo "cd ${HELM}"
#cd ${HELM}

echo
if [[ $ICP_VERSION == "3.1.2" ]]; then
echo "helm delete celery${KUBE_NAME_SPACE} --purge --tls"
helm delete celery${KUBE_NAME_SPACE} --purge --tls
fi
if [[ $OCP_VERSION == "3.11" ]]; then
echo "helm delete celery${KUBE_NAME_SPACE} --purge "
helm delete celery${KUBE_NAME_SPACE} --purge
fi

echo
echo "sleep for 120 secs to wait for celery pods to complete termination...."

sleep 120
#
#echo
#echo "return to previous directory: ${cwd}"
#cd ${cwd}

echo ----- Deleting all BACA resources from namespace : $KUBE_NAME_SPACE
set +e
kubectl delete -n $KUBE_NAME_SPACE --all deploy,svc,pvc,pods --force --grace-period=0
kubectl delete -n $KUBE_NAME_SPACE  secret baca-ingress-secret baca-secrets$KUBE_NAME_SPACE baca-userportal-ingress-secret baca-mongo baca-mongo-admin baca-ldap baca-basedb baca-rabbitmq baca-redis
if [[ $ICP_VERSION == "3.1.2" ]]; then
    kubectl delete -n $KUBE_NAME_SPACE rolebinding baca-clusterrole-rolebinding
    kubectl delete -n $KUBE_NAME_SPACE clusterrole baca-clusterrole
    kubectl delete -n $KUBE_NAME_SPACE psp baca-psp
fi
set -e




# only delete PVC for internal/dev env.
if [[ $PVCCHOICE == "1" ]]; then
    echo ---- Deleting persistent volumes.
    count=`kubectl -n $KUBE_NAME_SPACE get pv | awk {'print $1'}| grep ^sp-.*${KUBE_NAME_SPACE}|wc | awk {'print $1'}`
    if [[ $count != "0" ]]; then
        kubectl -n $KUBE_NAME_SPACE delete pv `kubectl -n $KUBE_NAME_SPACE get pv | awk {'print $1'}| grep ^sp-.*${KUBE_NAME_SPACE}`
    fi
    echo ---Clean up all pvc subdirectories.  You need to run setup.sh or init_deployment.sh again to have these directories re-created.
#    ssh root@$NFS_IP rm -rf /exports/smartpages/$KUBE_NAME_SPACE/*
    if [ -z "$SSH_USER" ]; then
       export SSH_USER="root"
    fi

    if [ "$SSH_USER" == "root" ]; then
       export SUDO_CMD=""
    else
       export SUDO_CMD="sudo "
    fi
    ssh $SSH_USER@$NFS_IP "$SUDO_CMD rm -rf /exports/smartpages/$KUBE_NAME_SPACE/*"


fi

