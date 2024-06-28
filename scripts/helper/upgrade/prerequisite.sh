#!/BIN/BASH

###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2023. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
###############################################################################

# function for install prerequisite for Cloud Pak 3.0
function install_ibm_cert_manager(){
    local install_plan_approval=$1
    if [ -z $1 ]; then
    install_plan_approval="Automatic"
    fi
    wait_msg "Installing IBM Cert-manager Operator..."
    mkdir -p $UPGRADE_PREREQUISITE_FOLDER >/dev/null 2>&1
    oc new-project ibm-cert-manager >/dev/null 2>&1
    install_plan_approval_flag=$(echo $install_plan_approval | tr '[:upper:]' '[:lower:]')
    if [[ $install_plan_approval_flag == "automatic" ]]; then
        install_plan_approval="Automatic"
    elif [[ $install_plan_approval_flag == "manual" ]]; then
        install_plan_approval="Manual"
    fi

cat << EOF > ${UPGRADE_OPERATOR_GROUP}
# operator group YAML for IBM Cert-manager Operator
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ibm-cert-manager-operator
  namespace: ibm-cert-manager
spec: {}
EOF
    isOperatorGrp=$(kubectl get operatorgroup -n ibm-cert-manager --no-headers --ignore-not-found | grep ibm-cert-manager)
    if [[ -z "$isOperatorGrp" ]]; then
        kubectl apply -f ${UPGRADE_OPERATOR_GROUP}
    fi

cat << EOF > ${UPGRADE_CERT_MANAGER_FILE}
# Subscription YAML for IBM Cert-manager Operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/ibm-cert-manager-operator.ibm-cert-manager: ''
  name: ibm-cert-manager-operator
  namespace: ibm-cert-manager
spec:
  channel: v4.0
  installPlanApproval: Automatic
  name: ibm-cert-manager-operator
  source: ibm-cert-manager-catalog
  sourceNamespace: openshift-marketplace
  startingCSV: ibm-cert-manager-operator.v4.0.0
EOF
    kubectl apply -f ${UPGRADE_CERT_MANAGER_FILE}

    local maxRetry=30
    info "Checking the IBM Cert-manager Operator ready or not"
    for ((retry=0;retry<=${maxRetry};retry++)); do
        isReadyWebhook=$(kubectl get pod -l=app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=ibm-cert-manager-webhook -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready' --all-namespaces --no-headers| grep 'Running' | grep 'true' | awk '{print $1}')
        isReadyCertmanager=$(kubectl get pod -l=app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=ibm-cert-manager-controller -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready' --all-namespaces --no-headers| grep 'Running' | grep 'true' | awk '{print $1}')
        isReadyCainjector=$(kubectl get pod -l=app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=ibm-cert-manager-cainjector -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready' --all-namespaces --no-headers| grep 'Running' | grep 'true' | awk '{print $1}')
        isReadyCertmanagerOperator=$(kubectl get pod -l=app.kubernetes.io/name=cert-manager,app.kubernetes.io/instance=ibm-cert-manager-operator -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready' --all-namespaces --no-headers| grep 'Running' | grep 'true' | awk '{print $1}')

        # if [[ -z $isReadyCertmanagerOperator ]]; then
        if [[ -z $isReadyWebhook || -z $isReadyCertmanager || -z $isReadyCainjector || -z $isReadyCertmanagerOperator ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then
                echo "Timeout waiting for IBM Cert-manager Operator to start"
                echo -e "\x1B[1mPlease check the status of Pod by issue cmd: \x1B[0m"
                if [[ -z $isReadyWebhook ]]; then
                    echo "kubectl describe pod $(kubectl get pod -l=app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=ibm-cert-manager-webhook --all-namespaces --no-headers|awk '{print $1}') --all-namespaces"
                fi
                if [[ -z $isReadyCertmanager ]]; then
                    echo "kubectl describe pod $(kubectl get pod -l=app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=ibm-cert-manager-controller --all-namespaces --no-headers|awk '{print $1}') --all-namespaces"
                fi
                if [[ -z $isReadyCainjector ]]; then
                    echo "kubectl describe pod $(kubectl get pod -l=app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=ibm-cert-manager-cainjector --all-namespaces --no-headers|awk '{print $1}') --all-namespaces"
                fi
                if [[ -z $isReadyCertmanagerOperator ]]; then
                    echo "kubectl describe pod $(kubectl get pod -l=app.kubernetes.io/name=cert-manager,app.kubernetes.io/instance=ibm-cert-manager-operator --all-namespaces --no-headers|awk '{print $1}') --all-namespaces"
                fi
                exit 1
            else
                sleep 10
                echo -n "..."
                continue
            fi
        else
            success "IBM Cert-manager Operator is running: "
            info "Pod: $isReadyCertmanager"
            # info "Pod: $isReadyCertmanagerOperator"
            echo "            $isReadyWebhook"
            echo "            $isReadyCainjector"
            echo "            $isReadyCertmanagerOperator"
            break
        fi
    done
    success "Installed IBM Cert-manager Operator\n"
}


# function install_ibm_license_operator(){
#     local project_name=$1
#     local install_plan_approval=$2
#     if [ -z $2 ]; then
#     install_plan_approval="Automatic"
#     fi

#     install_plan_approval_flag=$(echo $install_plan_approval | tr '[:upper:]' '[:lower:]')
#     if [[ $install_plan_approval_flag == "automatic" ]]; then
#         install_plan_approval="Automatic"
#     elif [[ $install_plan_approval_flag == "manual" ]]; then
#         install_plan_approval="Manual"
#     fi
#     # remove quotes from beginning and end of string
#     project_name=$(sed -e 's/^"//' -e 's/"$//' <<<"$project_name")
#     wait_msg "Installing IBM Licensing Operator..."
#     mkdir -p $UPGRADE_PREREQUISITE_FOLDER >/dev/null 2>&1

# cat << EOF > ${UPGRADE_OPERATOR_GROUP}
# # Subscription YAML for Operator Group
# ---
# apiVersion: operators.coreos.com/v1alpha2
# kind: OperatorGroup
# metadata:
#   name: ibm-cp4a-operator-catalog-group
#   namespace: ${project_name}
# spec:
#   targetNamespaces:
#   - ${project_name}
# EOF

# cat << EOF > ${UPGRADE_IBM_LICENSE_FILE}
# # Subscription YAML for IBM Licensing Operator
# ---
# apiVersion: operators.coreos.com/v1alpha1
# kind: Subscription
# metadata:
#   labels:
#     operators.coreos.com/ibm-licensing-operator-app.${project_name}: ''
#   name: ibm-licensing-operator-app
#   namespace: ${project_name}
# spec:
#   channel: v4.0
#   installPlanApproval: ${install_plan_approval}
#   name: ibm-licensing-operator-app
#   source: opencloud-operators
#   sourceNamespace: openshift-marketplace
#   startingCSV: ibm-licensing-operator.v4.0.0
# EOF
#     kubectl apply -f ${UPGRADE_OPERATOR_GROUP}
#     kubectl apply -f ${UPGRADE_IBM_LICENSE_FILE}

#     local maxRetry=20
#     info "Checking the IBM Licensing Operator for Cloud Pak 3.0 ready or not"
#     for ((retry=0;retry<=${maxRetry};retry++)); do
        

#         isReadyibmlicenseOperator=$(kubectl get pod -l=app.kubernetes.io/name=ibm-licensing,app.kubernetes.io/instance=ibm-licensing-operator -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready' -n $project_name --no-headers| grep 'Running' | grep 'true' | awk '{print $1}')
#         isReadyibmlicenseInstance=$(kubectl get pod -l=app.kubernetes.io/name=ibm-licensing-service-instance,app.kubernetes.io/instance=ibm-licensing-service -o 'custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready' -n $project_name --no-headers| grep 'Running' | grep 'true' | awk '{print $1}')

#         if [[ -z $isReadyibmlicenseOperator || -z $isReadyibmlicenseInstance ]]; then
#             if [[ $retry -eq ${maxRetry} ]]; then
#                 echo "Timeout waiting for IBM Licensing Operator to start"
#                 echo -e "\x1B[1mPlease check the status of Pod by issue cmd: \x1B[0m"
#                 if [[ -z $isReadyibmlicenseOperator ]]; then
#                     echo "kubectl describe pod $(kubectl get pod -l=app.kubernetes.io/name=ibm-licensing,app.kubernetes.io/instance=ibm-licensing-operator -n $project_name --no-headers|awk '{print $1}') -n $project_name"
#                 fi
#                 if [[ -z $isReadyibmlicenseInstance ]]; then
#                     echo "kubectl describe pod $(kubectl get pod -l=app.kubernetes.io/name=ibm-licensing-service-instance,app.kubernetes.io/instance=ibm-licensing-service -n $project_name --no-headers|awk '{print $1}') -n $project_name"
#                 fi
#                 exit 1
#             else
#                 sleep 20
#                 echo -n "..."
#                 continue
#             fi
#         else
#             success "IBM Licensing Operator is running: "
#             info "Pod: $isReadyibmlicenseOperator"
#             echo "            $isReadyibmlicenseInstance"
#             break
#         fi
#     done
#     success "Installed IBM Licensing Operator\n"
# }

