source "${check_cpfs_workdir}"/output.sh

function check_oc_login() {
    # Checking oc command logged in
    user=$(oc whoami 2> /dev/null)
    if [ $? -ne 0 ]; then
        append_check "eus_installer" "check oc login" "failed" "You must be logged into the OpenShift Cluster from the oc command line" ""
        error "You must be logged into the OpenShift Cluster from the oc command line"
    else
        append_check "eus_installer" "check oc login" "ok" "oc command logged in as ${user}" ""
        success "oc command logged in as ${user}"
    fi
}

# check if subscriptions in operator namespace are in correct version
function check_subscriptions() { 
    title "Checking subscriptions status in namespace: ${OPERATOR_NS}"
    rc=0
    oc get subscription.operators.coreos.com -n ${OPERATOR_NS}
    oc get subscription.operators.coreos.com -n ${OPERATOR_NS} -o=jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.state}{"\n"}{end}' | while read -r line; do
        sub=$(echo $line | awk '{print $1}')
        state=$(echo $line | awk '{print $2}')
        if [[ "$state" != "AtLatestKnown" ]]; then
            error "Subscription: ${sub} in namespace: ${OPERATOR_NS} not in Succeeded status"
            append_check "eus_installer" "check subscription:${sub}" "failed" "Subscription: ${sub} in namespace: ${OPERATOR_NS} not in Succeeded status" ""
            rc=1
            # oc get subscription.operators.coreos.com ${sub} -n ${OPERATOR_NS} -oyaml | tee -a $logfile
        fi
    done

    if [ $rc -eq 0 ]; then
        success "All Subscriptions in namespace: ${OPERATOR_NS} in Succeeded status"
        append_check "eus_installer" "check subscription" "ok" "All Subscriptions in namespace: ${OPERATOR_NS} in Succeeded status" ""
    fi
}

# check if cert-manager, IAM, ODLM, CS-Operator subscriptions in ibm-common-services namespace are in correct version
function check_sub_version(){
    title "Checking subscriptions version in namespace: ${OPERATOR_NS}"
    cs_operator_channel=$(oc get subscription.operators.coreos.com ibm-common-service-operator -n ${OPERATOR_NS} --ignore-not-found -o yaml | yq ".spec.channel")
    iam_operator_channel=$(oc get subscription.operators.coreos.com ibm-iam-operator -n ${OPERATOR_NS} --ignore-not-found -o yaml | yq ".spec.channel")
    odlm_channel=$(oc get subscription.operators.coreos.com operand-deployment-lifecycle-manager-app -n ${OPERATOR_NS} --ignore-not-found -o yaml | yq ".spec.channel")
    cert_manager_channel=$(oc get subscription.operators.coreos.com ibm-cert-manager-operator -n ${OPERATOR_NS} --ignore-not-found -o yaml | yq ".spec.channel")
    
    # if not found cs-operator sub in operator namespace, check openshift-operators
    if [[ "$cs_operator_channel" == "" ]]; then
        cs_operator_channel=$(oc get subscription.operators.coreos.com ibm-common-service-operator -n openshift-operators --ignore-not-found -o yaml | yq ".spec.channel")
    fi
    # if not found cert-manager sub in operator namespace, check cs-control namespace
    if [[ "$cert_manager_channel" == "" ]]; then
        cert_manager_channel=$(oc get subscription.operators.coreos.com ibm-cert-manager-operator -n cs-control --ignore-not-found -o yaml | yq ".spec.channel")
    fi

    if [[ "$iam_operator_channel" == "stable-v1" ]] && [[ "$odlm_channel" == "stable-v1" ]] && [[ "$cs_operator_channel" == "stable-v1" ]] && [[ "$cert_manager_channel" == "stable-v1" ]]; then
        success "cert-manager, IAM, ODLM and CS-Operator subscriptions are all in correct channel stable-v1 for EUS"
        append_check "eus_installer" "check subscription channel" "ok" "cert-manager, IAM, ODLM and CS-Operator subscriptions are all in correct channel stable-v1 for EUS" ""
    else
        error "operators may not in correct channel, please check"
        append_check "eus_installer" "check subscription channel" "failed" "cert-manager:${cert_manager_channel}, IAM:${ibm_iam_operator_channel}, ODLM:${odlm_channel} and CS-Operator:${cs_operator_channel} subscriptions may not in correct channel" ""
        msg "ibm-common-service-operator channel: ${cs_operator_channel}"
        msg "ibm-iam-operator channel: ${ibm_iam_operator_channel}"
        msg "operand-deployment-lifecycle-manager channel: ${odlm_channel}"
        msg "ibm-cert-manager-operator channel: ${cert_manager_channel}"
    fi

}

# check if all the CSV in ibm-common-services namespace are in succeeded status
function check_csv() { 
    title "Checking CSV status in namespace: ${OPERATOR_NS}"
    oc get csv -n ${OPERATOR_NS}
    failed_csv=$(oc get clusterserviceversion.operators.coreos.com -n ${OPERATOR_NS} -o=jsonpath='{.items[?(@.status.phase != "Succeeded")].metadata.name}')
    if [[ "X$failed_csv" != "X" ]]; then
        for csv in $(echo $failed_csv)
        do 
            # oc get csv ${csv} -n ${OPERATOR_NS} -oyaml
            error "Clusterserviceversion: ${csv} in namespace: ${OPERATOR_NS} not in Succeeded status"
            append_check "eus_installer" "check csv:${csv}" "failed" "Clusterserviceversion: ${csv} in namespace: ${OPERATOR_NS} not in Succeeded status" ""
        done
    else
        success "All Clusterserviceversion in namespace: ${OPERATOR_NS} in Succeeded status"
        append_check "eus_installer" "check csv" "ok" "All Clusterserviceversion in namespace: ${OPERATOR_NS} in Succeeded status" ""
    fi
}

# check the status of CSCR
function check_CSCR(){
    title "Checking CommonService CR status in namespace: ${OPERATOR_NS}"
    local phase=$(oc get commonservice common-service -o jsonpath='{.status.phase}' -n ${OPERATOR_NS})
    if [[ "${phase}" != "Succeeded" ]]; then
        error "CommonService CR in namespace: ${OPERATOR_NS} not in Succeeded status"
        append_check "eus_installer" "check CommonService CR" "failed" "CommonService CR in namespace: ${OPERATOR_NS} not in Succeeded status" ""
    else
        success "CommonService CR in namespace: ${OPERATOR_NS} in Succeeded status"
        append_check "eus_installer" "check CommonService CR" "ok" "CommonService CR in namespace: ${OPERATOR_NS} in Succeeded status" ""
    fi
}

# check the status of all the operandRequest
function check_opreq(){
    title "Checking OperandRequest status in namespace: ${OPERATOR_NS}"
    oc get operandrequest -n ${OPERATOR_NS}
    failed_opreqs=$(oc get OperandRequest -n ${OPERATOR_NS} -o=jsonpath='{.items[?(@.status.phase != "Running")].metadata.name}')
    if [[ "X$failed_opreqs" != "X" ]]; then
        for opreq in $(echo $failed_opreqs)
        do 
            error "OperandRequest: ${opreq} in namespace: ${OPERATOR_NS} not in Running status"
            append_check "eus_installer" "check operandRequest:${opreq}" "failed" "OperandRequest: ${opreq} in namespace: ${OPERATOR_NS} not in Running status" ""
        done
    else
        success "All OperandRequest in namespace: ${OPERATOR_NS} in Running status"
        append_check "eus_installer" "check operandRequest" "ok" "All OperandRequest in namespace: ${OPERATOR_NS} in Running status" ""
    fi

}


# use smoke test to verify if cert-manager is working
function check_certmanager(){
    title "Checking cert-manager"
    # Create the Self signed issuer
    cat << EOF | oc apply -n ${OPERATOR_NS} -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
metadata:
  name: hello-myself-tls
spec:
  selfSigned: {}
EOF
    # Check the issuers
    _ssi_status=$(oc get issuer.v1alpha1.certmanager.k8s.io -n ${OPERATOR_NS} --no-headers --ignore-not-found hello-myself-tls -o jsonpath={.status.conditions[0].status})
    if [[ $_ssi_status -eq 'True' ]]; then
        success "Cert manager in namespace: ${OPERATOR_NS} in running status"
        append_check "eus_installer" "check cert manager" "ok" "Cert manager in namespace: ${OPERATOR_NS} is running" ""
    else
        error "Cert manager in namespace: ${OPERATOR_NS} is not running"
        append_check "eus_installer" "check cert manager" "fail" "Cert manager in namespace: ${OPERATOR_NS} is not running" ""
    fi
    oc delete issuer.v1alpha1.certmanager.k8s.io -n ${OPERATOR_NS} --ignore-not-found hello-myself-tls
}

# check if all certificate are in True status
function check_certificate(){
    title "Checking Certificate status in namespace: ${OPERATOR_NS}"
    oc get certificate -n ${OPERATOR_NS}
    failed_cert_v1a1=$(oc get certificates.v1alpha1.certmanager.k8s.io -n ${OPERATOR_NS} --no-headers --ignore-not-found -o=jsonpath='{.items[?(@.status.conditions[0].status != "True")].metadata.name}')
    failed_cert_v1=$(oc get certificates -n ${OPERATOR_NS} --no-headers --ignore-not-found -o=jsonpath='{.items[?(@.status.conditions[0].status != "True")].metadata.name}')
    if [[ "X$failed_cert_v1a1" != "X" ]]; then
        for cert in $(echo $failed_cert_v1a1)
        do 
            # oc get csv ${csv} -n ${OPERATOR_NS} -oyaml
            error "v1alpha1 certificate: ${cert} in namespace: ${OPERATOR_NS} not in True status"
            append_check "eus_installer" "check v1alpha1 cert:${cert}" "failed" "v1alpha1 certificate: ${cert} in namespace: ${OPERATOR_NS} not in True status" ""
        done
    else
        success "All v1alpha1 certificate in namespace: ${OPERATOR_NS} in Succeeded status"
        append_check "eus_installer" "check v1alpha1 certificate" "ok" "All v1alpha1 certificate in namespace: ${OPERATOR_NS} in Succeeded status" ""
    fi

    if [[ "X$failed_cert_v1" != "X" ]]; then
        for cert in $(echo $failed_cert_v1)
        do 
            # oc get csv ${csv} -n ${OPERATOR_NS} -oyaml
            error "v1 certificate: ${cert} in namespace: ${OPERATOR_NS} not in True status"
            append_check "eus_installer" "check v1 cert:${cert}" "failed" "v1 certificate: ${cert} in namespace: ${OPERATOR_NS} not in True status" ""
        done
    else
        success "All v1 certificate in namespace: ${OPERATOR_NS} in Succeeded status"
        append_check "eus_installer" "check v1 certificate" "ok" "All v1 certificate in namespace: ${OPERATOR_NS} in Succeeded status" ""
    fi



}

# TODO: if any Subscriptions or CSVs are stuck, check for signs of common OLM issues
function error_check(){
    echo ""
}


# this is the main function
create_group "eus_installer"
check_oc_login
check_subscriptions
check_sub_version
check_csv
check_CSCR
check_opreq
check_certmanager
check_certificate
update_overall "eus_installer"