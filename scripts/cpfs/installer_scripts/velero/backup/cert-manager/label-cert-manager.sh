##!/usr/bin/env bash
# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2024. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product.
# Please refer to that particular license for additional information.

set -o errtrace

NAMESPACES=""

function main(){
    parse_arguments "$@"
    # Checking oc command logged in
    user=$(oc whoami 2> /dev/null)
    if [ $? -ne 0 ]; then
        error "You must be logged into the OpenShift Cluster from the oc command line"
    else
        success "oc command logged in as ${user}"
    fi
    label_all_resources
}

function print_usage(){
    script_name=`basename ${0}`
    echo "Usage: ${script_name} [OPTIONS]"
    echo ""
    echo "Label Cert Manager resources (ie certificates, secrets, and issuers) to prepare for Backup."
    echo "If specifying namespaces, make sure to include the operator, services, and all tethered namespaces. If no namespaces are specified, default is all namespaces."
    echo "This script assumes the following:"
    echo "    * An existing CPFS instance installed in the namespaces entered as parameters."
    echo "    * Existing permissions in the specified namespaces."
    echo ""
    echo "Options:"
    echo "   --namespaces                   Optional. Comma-delimited list of namespaces where cert manager resources will be labeled. Default is all namespaces."
    echo "   -h, --help                     Print usage information"
    echo ""
}

function parse_arguments(){
    script_name=`basename ${0}`
    info "All arguments passed into the ${script_name}: $@"
    echo ""

    # process options
    while [[ "$@" != "" ]]; do
        case "$1" in
        --namespaces)
            shift
            NAMESPACES=$1
            ;;
        -h | --help)
            print_usage
            exit 1
            ;;
        *)
            error "Entered option $1 not supported. Run ./${script_name} -h for script usage info."
            ;;
        esac
        shift
    done
    echo ""
}

function label_resource(){
    resource=$1
    current_list=$2
    IFS=',' read -ra name_list <<< "$current_list"
    namespace=$3
    i=0
    len=${#name_list[@]}
    for ((i=0;i<$len;i++));
    do
        NAME=${name_list[$i]}
        info "Labeling $resource $NAME in namespace $namespace..."
        oc label $resource $NAME -n $namespace foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
        echo "---"
    done
}

function label_resource_allns(){
    resource=$1
    names=$2
    IFS=',' read -ra name_list <<< "$names"
    namespaces=$3
    IFS=',' read -ra ns_list <<< "$namespaces"
    i=0
    len=${#name_list[@]}
    for ((i=0;i<$len;i++));
    do
        NAME=${name_list[$i]}
        NAMESPACE=${ns_list[$i]}
        info "Labeling $resource $NAME in namespace $NAMESPACE..."
        oc label $resource $NAME -n $NAMESPACE foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
        echo "---"
    done
}

function label_specified_secret(){
    namespace=$1
    secret_name=$2
    info "Labeling secret $secret_name in namespace $namespace..."
    oc label secret $secret_name -n $namespace foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
    echo "---"
}

function label_all_resources(){

    # Get all issuers in all namespaces and add foundationservices.cloudpak.ibm.com=cert-manager
    if [[ $NAMESPACES != "" ]]; then
        NAMESPACES=$(echo "$NAMESPACES" | tr ',' ' ')
        info "NAMESPACES: $NAMESPACES"
        for namespace in $NAMESPACES
        do
            info "Labeling resources in namespace $namespace"
            CURRENT_ISSUERS=($(oc get Issuers -n $namespace -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | awk '{print $1}'  | tr "\n" ","))
            if [[ $CURRENT_ISSUERS != "" ]]; then
                label_resource Issuers $CURRENT_ISSUERS $namespace
            fi
            CURRENT_ISSUERS=($(oc get issuers.cert-manager.io -n $namespace -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | awk '{print $1}'  | tr "\n" ","))
            if [[ $CURRENT_ISSUERS != "" ]]; then
                label_resource issuers.cert-manager.io $CURRENT_ISSUERS $namespace
            fi
            CURRENT_CERTIFICATES=($(oc get certificates -n $namespace -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | awk '{print $1}'  | grep cs-ca-certificate | tr "\n" ","))
            if [[ $CURRENT_CERTIFICATES != "" ]]; then
                label_resource certificates $CURRENT_CERTIFICATES $namespace
            fi
            CURRENT_CERTIFICATES=($(oc get certificates.cert-manager.io -n $namespace -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | awk '{print $1}' | grep cs-ca-certificate | tr "\n" ","))
            if [[ $CURRENT_CERTIFICATES != "" ]]; then
                label_resource certificates.cert-manager.io $CURRENT_CERTIFICATES $namespace
            fi
            CURRENT_SECRET=($(oc get secret -n $namespace -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | grep cs-ca-certificate | awk '{print $1}' | tr "\n" ","))
            if [[ $CURRENT_SECRET != "" ]]; then
                label_specified_secret $namespace cs-ca-certificate-secret
            fi
            
            #zen custom secret and ca-cert-secret
            zen_in_namespace=$(oc get zenservice -n $namespace --ignore-not-found | awk '{if (NR!=1) {print $1}}')
            if [[ $zen_in_namespace != "" ]]; then 
                zen_secret_name=$(oc get zenservice $zen_in_namespace -n $namespace -o=jsonpath='{.spec.zenCustomRoute.route_secret}')
                if [[ $zen_secret_name != "" ]]; then
                    label_specified_secret $namespace $zen_secret_name
                else
                    info "No custom zen secret in namespace $namespace, skipping..."
                fi
            else
                info "No zenservices found in namespace $namespace, skipping labeling zen custom route secrets..."
            fi

            zen_ca_secret_present=$(oc get secret zen-ca-cert-secret -n $namespace --ignore-not-found | awk '{if (NR!=1) {print $1}}')
            if [[ $zen_ca_secret_present != "" ]]; then
                label_specified_secret $namespace zen-ca-cert-secret
            fi

            #cs on prem config
            cm_namespace_list=$(oc get configmap -n $namespace | grep cs-onprem-tenant-config | awk '{if (NR!=1) {print $1}}')
            if [[ $cm_namespace_list != "" ]]; then
                iam_secret_name=$(oc get configmap cs-onprem-tenant-config -n $namespace -o=jsonpath='{.data.custom_host_certificate_secret}')
                label_specified_secret $namespace $iam_secret_name
            else
                info "Configmap cs-onprem-tenant-config not found in namespace $namespace, skipping copying custom secrets..."
            fi

            #grab default admin credentials
            auth_namespace_list=$(oc get secret -n $namespace | grep platform-auth-idp-credentials | grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " ")
            if [[ $auth_namespace_list != "" ]]; then
                label_specified_secret $namespace platform-auth-idp-credentials
            else
                info "Secret platform-auth-idp-credentials not present in namespace $namespace. Skipping..."
            fi

            #grab default scim credentials
            scim_secret_namespace_list=$(oc get secret -n $namespace | grep platform-auth-scim-credentials | grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " ")
            if [[ $scim_secret_namespace_list != "" ]]; then
                label_specified_secret $namespace platform-auth-scim-credentials
            else
                info "Secret platform-auth-scim-credentials not present in namespace $namespace. Skipping..."
            fi

            #grab LDAP TLS certificate
            ldaps_secret_namespace_list=$(oc get secret -n $namespace | grep platform-auth-ldaps-ca-cert | grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " ")
            if [[ $ldaps_secret_namespace_list != "" ]]; then
                label_specified_secret $namespace platform-auth-ldaps-ca-cert
            else
                info "Secret platform-auth-ldaps-ca-cert not present in namespace $namespace. Skipping..."
            fi

            #grab icp service id apikey (if it exists)
            icp_serviceid_apikey_secret_namespace_list=$(oc get secret -n $namespace | grep icp-serviceid-apikey-secret | grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " ")
            if [[ $icp_serviceid_apikey_secret_namespace_list != "" ]]; then
                label_specified_secret $namespace icp-serviceid-apikey-secret
            else
                info "Secret icp-serviceid-apikey-secret not present in namespace $namespace. Skipping..."
            fi

            #grab zen service id apikey (if it exists)
            zen_serviceid_apikey_secret_namespace_list=$(oc get secret -n $namespace | grep zen-serviceid-apikey-secret| grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " ")
            if [[ $zen_serviceid_apikey_secret_namespace_list != "" ]]; then
                label_specified_secret $namespace zen-serviceid-apikey-secret
            else
                info "Secret zen-serviceid-apikey-secret not present in namespace $namespace. Skipping..."
            fi

            #add labels to iaf-system-automation-aui-zen-cert elasticsearch cert/secret
            auto_zen_cert_ns_list=$(oc get certificate -n $namespace --no-headers | grep iaf-system-automationui-aui-zen-cert | awk '{print $1}' | tr "\n" " ")
            if [[ $auto_zen_cert_ns_list != "" ]]; then
                secret_name=$(oc get certificate -n $ns iaf-system-automationui-aui-zen-cert -o jsonpath='{.spec.secretName}')
                label_specified_secret $namespace $secret_name
                oc label certificate iaf-system-automationui-aui-zen-cert -n $namespace foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
            fi

            #add labels to elasticsearch cert/secret
            elasticsearch_cert_ns_list=$(oc get certificate -n $namespace --no-headers | grep iaf-system-elasticsearch-es-client-cert | awk '{print $1}' | tr "\n" " ")
            if [[ $elasticsearch_cert_ns_list != "" ]]; then
                    oc label certificate iaf-system-elasticsearch-es-client-cert -n $ns foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
                    label_specified_secret $namespace iaf-system-elasticsearch-es-client-cert-kp
            fi

            #remove label from metastore-edb certificate and secret
            metastore_secret_ns_list=$(oc get secret -n $namespace --no-headers | grep  ibm-zen-metastore-edb-secret | awk '{print $1}' | tr "\n" " ")
            if [[ $metastore_secret_ns_list != "" ]]; then
                info "removing label from zen-metastore-edb-secret and certificate."
                for ns in $metastore_secret_ns_list
                do
                    oc label secret ibm-zen-metastore-edb-secret -n $namespace foundationservices.cloudpak.ibm.com-
                    oc label certificate ibm-zen-metastore-edb-certificate -n $namespace foundationservices.cloudpak.ibm.com-
                done
            fi
        done
    else
        #CRDS
        oc label crd certificates.cert-manager.io foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
        oc label crd issuers.cert-manager.io foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true

        issuer_names=$(oc get Issuers --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | awk '{print $1}' | tr "\n" ",")
        issuer_ns=$(oc get Issuers --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | awk '{print $2}' | tr "\n" ",")
        label_resource_allns Issuers $issuer_names $issuer_ns

        issuer_names=$(oc get issuers.cert-manager.io  --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | awk '{print $1}' | tr "\n" ",")
        issuer_ns=$(oc get issuers.cert-manager.io  --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | awk '{print $2}' | tr "\n" ",")
        label_resource_allns issuers.cert-manager.io $issuer_names $issuer_ns

        # Label all cs-ca-certificates
        cert_names=($(oc get certificates --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | grep cs-ca-certificate | awk '{print $1}' | tr "\n" ","))
        cert_ns=($(oc get certificates --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | grep cs-ca-certificate | awk '{print $2}' | tr "\n" ","))
        label_resource_allns certificates $cert_names $cert_ns

        #cover the different api for certificates
        CURRENT_CERTIFICATES=($(oc get certificates.cert-manager.io --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | grep cs-ca-certificate | tr "\n" ","))
        cert_names=($(oc get certificates.cert-manager.io --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | grep cs-ca-certificate | awk '{print $1}' | tr "\n" ","))
        cert_ns=($(oc get certificates.cert-manager.io --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | grep cs-ca-certificate | awk '{print $2}' | tr "\n" ","))
        label_resource_allns certificates.cert-manager.io $cert_names $cert_ns

        cs_ca_name=($(oc get secret --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | grep cs-ca-certificate-secret | awk '{print $1}' | tr "\n" ","))
        cs_ca_ns=($(oc get secret --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | grep cs-ca-certificate-secret | awk '{print $2}' | tr "\n" ","))
        label_resource_allns secret $cs_ca_name $cs_ca_ns

        zen_cs_ca_name=($(oc get secret --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | grep zen-ca-cert-secret | awk '{print $1}' | tr "\n" ","))
        zen_cs_ca_ns=($(oc get secret --all-namespaces -o custom-columns=NAME:.metadata.name,NAMESPACE:metadata.namespace --no-headers=True | grep zen-ca-cert-secret | awk '{print $2}' | tr "\n" ","))
        label_resource_allns secret $zen_cs_ca_name $zen_cs_ca_ns

        #ensure zenservice custom route secrets are labeled
        zen_namespace_list=$(oc get zenservice -A | awk '{if (NR!=1) {print $1}}')
        if [[ $zen_namespace_list != "" ]]; then 
            for zen_namespace in $zen_namespace_list
            do
                zenservice_list=$(oc get zenservice -n $zen_namespace | awk '{if (NR!=1) {print $1}}')
                for zenservice in $zenservice_list
                do
                    zen_secret_name=$(oc get zenservice $zenservice -n $zen_namespace -o=jsonpath='{.spec.zenCustomRoute.route_secret}')
                    if [[ $zen_secret_name != "" ]]; then
                        label_specified_secret $zen_namespace $zen_secret_name
                    else
                        info "No custom zen secret in namespace $zen_namespace, skipping..."
                    fi
                done
            done
        else
            info "No zenservices found on cluster, skipping labeling zen custom route secrets..."
        fi

        #ensure iam custom route secrets are labeled
        cm_namespace_list=$(oc get configmap -A | grep cs-onprem-tenant-config | awk '{if (NR!=1) {print $1}}')
        if [[ $cm_namespace_list != "" ]]; then
            for tenant_config_namespace in $cm_namespace_list
            do
                iam_secret_name=$(oc get configmap cs-onprem-tenant-config -n $tenant_config_namespace -o=jsonpath='{.data.custom_host_certificate_secret}')
                label_specified_secret $tenant_config_namespace $iam_secret_name
            done
        else
            info "Configmap cs-onprem-tenant-config not found, skipping copying custom secrets..."
        fi

        #grab default admin credentials
        auth_namespace_list=$(oc get secret -A | grep platform-auth-idp-credentials | grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " ")
        if [[ $auth_namespace_list != "" ]]; then
            for auth_namespace in $auth_namespace_list
            do
                label_specified_secret $auth_namespace platform-auth-idp-credentials
            done
        else
            info "Secret platform-auth-idp-credentials not present in namespace $auth_namespace. Skipping..."
        fi

        #grab default scim credentials
        scim_secret_namespace_list=$(oc get secret -A | grep platform-auth-scim-credentials | grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " ")
        if [[ $scim_secret_namespace_list != "" ]]; then
            for scim_namespace in $scim_secret_namespace_list
            do
                label_specified_secret $scim_namespace platform-auth-scim-credentials
            done
        else
            info "Secret platform-auth-scim-credentials not present in namespace $scim_namespace. Skipping..."
        fi

        #grab LDAP TLS certificate
        ldaps_secret_namespace_list=$(oc get secret -A | grep platform-auth-ldaps-ca-cert | grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " ")
        if [[ $ldaps_secret_namespace_list != "" ]]; then
            for ldaps_namespace in $ldaps_secret_namespace_list
            do
                label_specified_secret $ldaps_namespace platform-auth-ldaps-ca-cert
            done
        else
            info "Secret platform-auth-ldaps-ca-cert not present in namespace $ldaps_namespace. Skipping..."
        fi

        #grab icp service id apikey (if it exists)
        icp_serviceid_apikey_secret_namespace_list=$(oc get secret -A | grep icp-serviceid-apikey-secret | grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " ")
        if [[ $icp_serviceid_apikey_secret_namespace_list != "" ]]; then
            for icp_serviceid_namespace in $icp_serviceid_apikey_secret_namespace_list
            do
                label_specified_secret $icp_serviceid_namespace icp-serviceid-apikey
            done
        else
            info "Secret icp-serviceid-apikey-secret not present in namespace $icp_serviceid_namespace. Skipping..."
        fi

        #grab zen service id apikey (if it exists)
        zen_serviceid_apikey_secret_namespace_list=$(oc get secret -A | grep zen-serviceid-apikey-secret| grep -v "bindinfo" |  awk '{print $1}' | tr "\n" " ")
        if [[ $zen_serviceid_apikey_secret_namespace_list != "" ]]; then
            for zen_serviceid_namespace in $zen_serviceid_apikey_secret_namespace_list
            do
                label_specified_secret $zen_serviceid_namespace zen-serviceid-apikey-secret
            done
        else
            info "Secret zen-serviceid-apikey-secret not present in namespace $zen_serviceid_namespace. Skipping..."
        fi

        #add labels to iaf-system-automation-aui-zen-cert elasticsearch cert/secret
        auto_zen_cert_ns_list=$(oc get certificate -A --no-headers | grep iaf-system-automationui-aui-zen-cert | awk '{print $1}' | tr "\n" " ")
        if [[ $auto_zen_cert_ns_list != "" ]]; then
            for ns in $auto_zen_cert_ns_list
            do
                secret_name=$(oc get certificate -n $ns iaf-system-automationui-aui-zen-cert -o jsonpath='{.spec.secretName}')
                label_specified_secret $ns $secret_name
                oc label certificate iaf-system-automationui-aui-zen-cert -n $ns foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
            done
        fi

        #add labels to elasticsearch cert/secret
        elasticsearch_cert_ns_list=$(oc get certificate -A --no-headers | grep iaf-system-elasticsearch-es-client-cert | awk '{print $1}' | tr "\n" " ")
        if [[ $elasticsearch_cert_ns_list != "" ]]; then
            for ns in $elasticsearch_cert_ns_list
            do
                oc label certificate iaf-system-elasticsearch-es-client-cert -n $ns foundationservices.cloudpak.ibm.com=cert-manager --overwrite=true
                label_specified_secret $ns iaf-system-elasticsearch-es-client-cert-kp
            done
        fi

        #remove label from metastore-edb certificate and secret
        metastore_secret_ns_list=$(oc get secret -A --no-headers | grep  ibm-zen-metastore-edb-secret | awk '{print $1}' | tr "\n" " ")
        if [[ $metastore_secret_ns_list != "" ]]; then
            info "removing label from zen-metastore-edb-secret and certificate."
            for ns in $metastore_secret_ns_list
            do
                oc label secret ibm-zen-metastore-edb-secret -n $ns foundationservices.cloudpak.ibm.com-
                oc label certificate ibm-zen-metastore-edb-certificate -n $ns foundationservices.cloudpak.ibm.com-
            done
        fi
    fi

    success "Certificates and secrets successfully labeled in namespaces $NAMESPACES."
}

# ---------- Info functions ----------#

function msg() {
    printf '%b\n' "$1"
}

function success() {
    msg "\33[32m[✔] ${1}\33[0m"
}

function error() {
    msg "\33[31m[✘] ${1}\33[0m"
    exit 1
}

function title() {
    msg "\33[34m# ${1}\33[0m"
}

function info() {
    msg "[INFO] ${1}"
}

function warning() {
    msg "\33[33m[✗] ${1}\33[0m"
}

main $*