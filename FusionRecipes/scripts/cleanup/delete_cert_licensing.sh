#!/bin/bash 


oc delete catalogsource ibm-cert-manager-catalog -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource ibm-licensing-catalog -n openshift-marketplace --ignore-not-found=true --wait=true