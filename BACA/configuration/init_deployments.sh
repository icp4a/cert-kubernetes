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

# Login (if necessary)
loginToCluster

#Creating psp and clusterrole for BACA



# Create Kube namespace
echo "\x1B[1;32mCreating  $KUBE_NAME_SPACE namespace \x1B[0m"
if [[ $ICP_VERSION == "3.1.0" || $ICP_VERSION == "3.1.2" ]]; then   
    kubectl create namespace $KUBE_NAME_SPACE
fi    

if [[ $OCP_VERSION == "3.11" ]]; then
    oc new-project  $KUBE_NAME_SPACE
    oc project $KUBE_NAME_SPACE
fi

if [[ $ICP_VERSION == "3.1.2" ]]; then
    checkPsp=$(kubectl get psp |grep baca |wc -l)

    if [[ $checkPsp == "0" ]]; then

        echo -e "\x1B[1;32mCreating psp and clusterrole for BACA\x1B[0m"
        kubectl -n $KUBE_NAME_SPACE apply -f ./baca-psp.yaml
        echo -e "\x1B[1;32mCreating rolebinding for BACA\x1B[0m"
        kubectl -n $KUBE_NAME_SPACE create rolebinding baca-clusterrole-rolebinding --clusterrole=baca-anyuid-clusterrole --group=system:serviceaccounts:$KUBE_NAME_SPACE

    fi
fi

if [[ $OCP_VERSION == "3.11" ]]; then
    # Allows images to run as the root UID if no USER in specified in the Dockerfile.
    oc adm policy add-scc-to-group anyuid system:authenticated
fi

#label nodes
if [[ ($LABEL_NODE == "y" || $LABEL_NODE == "Y") ]]; then
    customLabelNodes
else
    echo -e "\x1B[1;32mLABEL_NODE and LABEL_NODE_BY_PARAM parameters are not defined.  Therefore, you must label your nodes accordingly\x1B[0m"
fi


# Create nfs, and pv/pvc
#getNFSServer

#Check and rename DB2 cert to db2-cert.arm when DB_SSL=y
if [[ ($DB_SSL == "y" || $DB_SSL == "Y") && ($DB_CRT_NAME != 'db2-cert.arm') ]]; then
        echo "renaming DB2 Cert name from $DB_CRT_NAME to db2-cert.arm"
        cp  $DB_CRT_NAME db2-cert.arm
fi

#Create SSL cert and secret
createSSLCert
createSecret
createMongoSecrets
createLDAPSecret
createBaseDbSecret
createRabbitmaSecret
createRedisSecret
if [[ $PVCCHOICE == "1" ]]; then
    echo -e "\x1B[1;32mSetting up PV/PVC storage\x1B[0m"
    getNFSServer
    ./init_persistent.sh
fi


#Helm client download and initialization
if [[ $USING_HELM == "y" || $USING_HELM == "yes" ]]; then
    if [[ -z $HELM_INIT_BEFORE || $HELM_INIT_BEFORE == "n" || $HELM_INIT_BEFORE == "no" ]]; then

      # setup helm client
      downloadHelmClient

      # setup helm on cluster
      helmSetup

      # ensure tiller-deploy is successful on cluster
      checkHelm
    fi
fi

