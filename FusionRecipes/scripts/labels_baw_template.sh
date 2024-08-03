#!/bin/bash 

## fncm

./scripts/labels_fncm.sh

## BAW

oc label secret ibm-iaws-shared-key-secret custom-label=cp4ba-ibm-iaws-shared-key-secret

oc label secret icp4adeploy-cpe-oidc-secret custom-label=cpe-oidc-secret 

oc label secret ibm-bts-cnpg-$REPLACE_NAMESPACE-cp4ba-bts-app custom-label=cp4ba-bts-app
