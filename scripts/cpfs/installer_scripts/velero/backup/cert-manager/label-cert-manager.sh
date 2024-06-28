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

CURRENT_ISSUERS=($(oc get issuers.cert-manager.io --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True))
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

CURRENT_CERTIFICATES=($(oc get certificates.cert-manager.io --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True))
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

#ensure zenservice custom route secrets are labeled
zen_namespace_list=$(oc get zenservice -A | awk '{if (NR!=1) {print $1}}' || echo "fail")
if [[ $zen_namespace_list != "fail" ]]; then 
    for zen_namespace in $zen_namespace_list
    do
        zenservice_list=$(oc get zenservice -n $zen_namespace | awk '{if (NR!=1) {print $1}}')
        for zenservice in $zenservice_list
        do
            zen_secret_name=$(oc get zenservice $zenservice -n $zen_namespace -o=jsonpath='{.spec.zenCustomRoute.route_secret}')
            echo $zen_secret_name
            echo $zen_namespace
            echo "---"
            oc label secret $zen_secret_name -n $zen_namespace foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
        done
    done
else
    echo "[INFO] No zenservices found on cluster, skipping labeling zen custom route secrets..."
fi

#ensure iam custom route secrets are labeled
cm_namespace_list=$(oc get configmap -A | grep cs-onprem-tenant-config | awk '{if (NR!=1) {print $1}}' || echo "fail")
if [[ $cm_namespace_list != "fail" ]]; then
    for tenant_config_namespace in $cm_namespace_list
    do
        iam_secret_name=$(oc get configmap cs-onprem-tenant-config -n $tenant_config_namespace -o=jsonpath='{.data.custom_host_certificate_secret}')
        echo $iam_secret_name
        echo $tenant_config_namespace
        echo "---"
        oc label secret $iam_secret_name -n $tenant_config_namespace foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
    done
else
    echo "[INFO] Configmap cs-onprem-tenant-config not found, skipping copying custom secrets..."
fi

#grab default admin credentials
auth_namespace_list=$(oc get secret -A | grep platform-auth-idp-credentials | grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " " || echo "none")
if [[ $auth_namespace_list != "none" ]]; then
    for auth_namespace in $auth_namespace_list
    do
        echo "platform-auth-idp-credentials"
        echo $auth_namespace
        echo "---"
        oc label secret platform-auth-idp-credentials -n $auth_namespace foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
    done
else
    echo "[INFO] Secret platform-auth-idp-credentials not present in namespace $auth_namespace. Skipping..."
fi

#grab default scim credentials
scim_secret_namespace_list=$(oc get secret -A | grep platform-auth-scim-credentials | grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " " || echo "none")
if [[ $scim_secret_namespace_list != "none" ]]; then
    for scim_namespace in $scim_secret_namespace_list
    do
        echo "platform-auth-scim-credentials"
        echo $scim_namespace
        echo "---"
        oc label secret platform-auth-scim-credentials -n $scim_namespace foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
    done
else
    echo "[INFO] Secret platform-auth-scim-credentials not present in namespace $scim_namespace. Skipping..."
fi

#grab LDAP TLS certificate
ldaps_secret_namespace_list=$(oc get secret -A | grep platform-auth-ldaps-ca-cert | grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " " || echo "none")
if [[ $ldaps_secret_namespace_list != "none" ]]; then
    for ldaps_namespace in $ldaps_secret_namespace_list
    do
        echo "platform-auth-ldaps-ca-cert"
        echo $ldaps_namespace
        echo "---"
        oc label secret platform-auth-ldaps-ca-cert -n $ldaps_namespace foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
    done
else
    echo "[INFO] Secret platform-auth-ldaps-ca-cert not present in namespace $ldaps_namespace. Skipping..."
fi

#grab icp service id apikey (if it exists)
icp_serviceid_apikey_secret_namespace_list=$(oc get secret -A | grep icp-serviceid-apikey-secret | grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " " || echo "none")
if [[ $icp_serviceid_apikey_secret_namespace_list != "none" ]]; then
    for icp_serviceid_namespace in $icp_serviceid_apikey_secret_namespace_list
    do
        echo "icp-serviceid-apikey"
        echo $icp_serviceid_namespace
        echo "---"
        oc label secret icp-serviceid-apikey-secret -n $icp_serviceid_namespace foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
    done
else
    echo "[INFO] Secret icp-serviceid-apikey-secret not present in namespace $icp_serviceid_namespace. Skipping..."
fi

#grab zen service id apikey (if it exists)
zen_serviceid_apikey_secret_namespace_list=$(oc get secret -A | grep zen-serviceid-apikey-secret| grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " " || echo "none")
if [[ $zen_serviceid_apikey_secret_namespace_list != "none" ]]; then
    for zen_serviceid_namespace in $zen_serviceid_apikey_secret_namespace_list
    do
        echo "zen-serviceid-apikey-secret"
        echo $zen_serviceid_namespace
        echo "---"
        oc label secret zen-serviceid-apikey-secret -n $zen_serviceid_namespace foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
    done
else
    echo "[INFO] Secret zen-serviceid-apikey-secret not present in namespace $zen_serviceid_namespace. Skipping..."
fi