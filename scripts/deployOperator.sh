#!/bin/bash
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2019. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

function show_help {
    echo -e "\nUsage: deployOperator.sh -i operator_image [-p 'secret_name']\n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -i  Operator image name"
    echo "      For example: cp.icr.io/cp/icp4a-operator:19.03 or registry_url/icp4a-operator:version"
    echo "  -p  Optional: Pull secret to use to connect to the registry"
}

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?i:p:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        i)  IMAGEREGISTRY=$OPTARG
            ;;
        p)  PULLSECRET=$OPTARG
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            show_help
            exit -1
            ;;
        esac
    done
fi

echo "Using the operator image $IMAGEREGISTRY."
[ -f ./deployoperator.yaml ] && rm ./deployoperator.yaml
cp ./descriptors/operator.yaml ./deployoperator.yaml
if [ ! -z ${IMAGEREGISTRY} ]; then
  # Change the location of the image
  echo "Using the operator image name: $IMAGEREGISTRY"
  sed -e "s|image: .*|image: \"$IMAGEREGISTRY\" |g" ./deployoperator.yaml > ./deployoperatorsav.yaml ;  mv ./deployoperatorsav.yaml ./deployoperator.yaml
fi

# Change the pullSecrets if needed
if [ ! -z ${PULLSECRET} ]; then
    echo "Setting pullSecrets to $PULLSECRET"
    sed -e "s|admin.registrykey|$PULLSECRET|g" ./deployoperator.yaml > ./deployoperatorsav.yaml ;  mv ./deployoperatorsav.yaml ./deployoperator.yaml
else
    sed -e '/imagePullSecrets:/{N;d;}' ./deployoperator.yaml > ./deployoperatorsav.yaml ; mv ./deployoperatorsav.yaml ./deployoperator.yaml
fi

kubectl apply -f ./descriptors/ibm_cp4a_crd.yaml --validate=false
kubectl apply -f ./descriptors/service_account.yaml --validate=false
kubectl apply -f ./descriptors/role.yaml --validate=false
kubectl apply -f ./descriptors/role_binding.yaml --validate=false
kubectl apply -f ./deployoperator.yaml --validate=false
echo "All descriptors have been successfully applied. Monitor the pod status with 'oc get pods -w' in the namespace $NAMESPACE."
