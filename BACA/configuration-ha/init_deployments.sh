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
export HA_ENABLE=true


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
        kubectl -n $KUBE_NAME_SPACE create rolebinding baca-clusterrole-rolebinding --clusterrole=baca-clusterrole --group=system:serviceaccounts:$KUBE_NAME_SPACE

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

echo -e "\x1B[1;32mCalling pre-setup scripts to setup pvc for Mongo and Mongo-admin\x1B[0m"
cd mongo && ./pre-setup.sh
cd ..
cd mongoadmin && ./pre-setup.sh
cd ..


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

