##!/usr/bin/env bash

# Get all issuers in all namespaces and add foundationservices.cloudpak.ibm.com=cert-manager
CURRENT_ISSUERS=($(oc get Issuers --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True))
i=0
len=${#CURRENT_ISSUERS[@]}
while [ $i -lt $len ];
do
    NAME=${CURRENT_ISSUERS[$i]}
    let i++
    NAMESPACE=${CURRENT_ISSUERS[$i]}
    let i++
    echo $NAME
    echo $NAMESPACE
    echo "---"
    oc label issuer $NAME -n $NAMESPACE foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
done

# Get all certificates in all namespaces and add foundationservices.cloudpak.ibm.com=cert-manager
CURRENT_CERTIFICATES=($(oc get certificates --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True))
i=0
len=${#CURRENT_CERTIFICATES[@]}
while [ $i -lt $len ];
do
    NAME=${CURRENT_CERTIFICATES[$i]}
    let i++
    NAMESPACE=${CURRENT_CERTIFICATES[$i]}
    let i++
    echo $NAME
    echo $NAMESPACE
    echo "---"
    oc label certificates $NAME -n $NAMESPACE foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
done

# Get all secrets with label operator.ibm.com/watched-by-cert-manager="" and add foundationservices.cloudpak.ibm.com=cert-manager
CURRENT_SECRETS=($(oc get secrets -l operator.ibm.com/watched-by-cert-manager="" --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True))
i=0
len=${#CURRENT_SECRETS[@]}
while [ $i -lt $len ];
do
    NAME=${CURRENT_SECRETS[$i]}
    let i++
    NAMESPACE=${CURRENT_SECRETS[$i]}
    let i++
    echo $NAME
    echo $NAMESPACE
    echo "---"
    oc label secret $NAME -n $NAMESPACE foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
done

CURRENT_CRD_ISSUERS=($(oc get crd | grep issuer | cut -d ' ' -f1))
i=0
len=${#CURRENT_CRD_ISSUERS[@]}
while [ $i -lt $len ];
do
    NAME=${CURRENT_CRD_ISSUERS[$i]}
    let i++
    echo $NAME
    echo "---"
    oc label crd $NAME foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
done

CURRENT_CRD_CERTIFICATES=($(oc get crd | grep certificates | cut -d ' ' -f1))
i=0
len=${#CURRENT_CRD_CERTIFICATES[@]}
while [ $i -lt $len ];
do
    NAME=${CURRENT_CRD_CERTIFICATES[$i]}
    let i++
    echo $NAME
    echo "---"
    oc label crd $NAME foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
done
