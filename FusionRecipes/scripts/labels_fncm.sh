#!/bin/bash 

oc label secret htpass-secret custom-label=cp4ba  -n openshift-config 

oc label configmap cp4ba-fips-status custom-label=cp4ba

oc label secret ibm-entitlement-key custom-label=cp4ba-ibm-entitlement-key 

oc label secret ibm-cp4ba-db-ssl-secret-for-dbserver1 custom-label=cp4ba-ssl-secret

oc label secret ibm-cp4ba-ldap-ssl-secret custom-label=cp4ba-ssl-secret

oc label secret platform-auth-ldaps-ca-cert custom-label=cp4ba-platform-auth-ldaps-ca-cert

# if mongo base common service are installed
oc label secret icp-mongodb-client-cert custom-label=cp4ba-mongo-cert

oc label secret mongodb-root-ca-cert custom-label=cp4ba-mongo-cert

