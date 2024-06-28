##!/usr/bin/env bash

POSSIBLE_CONFIGMAPS=("ibm-licensing-config"
"ibm-licensing-annotations"
"ibm-licensing-products"
"ibm-licensing-products-vpc-hour"
"ibm-licensing-cloudpaks"
"ibm-licensing-products-groups"
"ibm-licensing-cloudpaks-groups"
"ibm-licensing-cloudpaks-metrics"
"ibm-licensing-products-metrics"
"ibm-licensing-products-metrics-groups"
"ibm-licensing-cloudpaks-metrics-groups"
"ibm-licensing-services"
)

COMMON_SERVICE_NAMESPACE="ibm-common-services"

CURRENT_CONFIGMAPS=$(oc get configmaps -n $COMMON_SERVICE_NAMESPACE | grep licensing | cut -d ' ' -f1)
for configmap in ${CURRENT_CONFIGMAPS[@]};
do
  if [[ " ${POSSIBLE_CONFIGMAPS[@]} " =~ " ${configmap} " ]]
  then
    echo "labeling $configmap"
    oc label configmap $configmap -n $COMMON_SERVICE_NAMESPACE foundationservices.cloudpak.ibm.com=licensing --overwrite=true
  fi
done
