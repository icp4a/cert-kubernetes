#!/bin/bash 

# CP4BA_NAMESPACE=$(oc project -q)
# CPFS_SHARED_NAMESPACE="ibm-common-services"
# CPFS_CONTROL_NAMESPACE="cs-control"
# IBM_CERT_MANAGER_NAMESPACE="ibm-cert-manager"
# IBM_LICENSING_NAMESPACE="ibm-licensing"
# ALL_NAMESPACE="openshift-operators"


# for i in $(oc get operandrequest --no-headers | awk '{print $1}'); do
# 	oc patch operandrequest/$i -p '{"metadata":{"finalizers":[]}}' --type=merge
# 	oc delete operandrequest $i --ignore-not-found=true --wait=true
# done

# for i in $(oc get zenextension --no-headers | awk '{print $1}'); do
# 	oc patch zenextension/$i -p '{"metadata":{"finalizers":[]}}' --type=merge
# 	oc delete zenextension $i --ignore-not-found=true --wait=true
# done

# for i in $(oc get operandbindinfo --no-headers | awk '{print $1}'); do
# 	oc patch operandbindinfo/$i -p '{"metadata":{"finalizers":[]}}' --type=merge
# 	oc delete operandbindinfo $i --ignore-not-found=true --wait=true
# done

# for i in $(oc get clients.oidc.security.ibm.com --no-headers | awk '{print $1}'); do
# 	oc patch clients.oidc.security.ibm.com/$i -p '{"metadata":{"finalizers":[]}}' --type=merge
# 	oc delete clients.oidc.security.ibm.com $i --ignore-not-found=true --wait=true
# done

# for i in $(oc get authentications.operator.ibm.com --no-headers | awk '{print $1}'); do
# 	oc patch authentications.operator.ibm.com/$i -p '{"metadata":{"finalizers":[]}}' --type=merge
# 	oc delete authentications.operator.ibm.com $i --ignore-not-found=true --wait=true
# done

./delete_ns_crd_instances.sh

echo "Delete catalog sources from openshift-marketplace"
oc delete catalogsource ibm-db2u-operator -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource ibm-db2uoperator-catalog -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource abp-operators -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource iaf-operators -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource iaf-core-operators -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource abp-demo-cartridge -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource iaf-demo-cartridge -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource ibm-cp-data-operator-catalog -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource ibm-cp4a-operator-catalog -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource ibm-operator-catalog -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource ibm-fncm-operator-catalog -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource bts-operator -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource cloud-native-postgresql-catalog -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource ibm-automation-foundation-core-catalog -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource ibm-cp-automation-foundation-catalog -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource insight-engine-operator -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource insight-engine-operators -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource ibm-cs-elastic-operator-catalog -n openshift-marketplace --ignore-not-found=true --wait=true
oc delete catalogsource ibm-cs-flink-operator-catalog -n openshift-marketplace --ignore-not-found=true --wait=true
# oc delete catalogsource ibm-cert-manager-catalog -n openshift-marketplace --ignore-not-found=true --wait=true
# oc delete catalogsource ibm-licensing-catalog -n openshift-marketplace --ignore-not-found=true --wait=true

oc delete crd contentrequests.icp4a.ibm.com                                     
oc delete crd contents.icp4a.ibm.com                                            
oc delete crd federatedsystems.icp4a.ibm.com                                    
oc delete crd foundationrequests.icp4a.ibm.com                                  
oc delete crd foundations.icp4a.ibm.com                                         
oc delete crd icp4aautomationdecisionservices.icp4a.ibm.com                     
oc delete crd icp4aclusters.icp4a.ibm.com                                       
oc delete crd icp4adocumentprocessingengines.icp4a.ibm.com                      
oc delete crd icp4aoperationaldecisionmanagers.icp4a.ibm.com                    
oc delete crd insightsengines.icp4a.ibm.com                                     
oc delete crd processfederationservers.icp4a.ibm.com                            
oc delete crd wfpsruntimes.icp4a.ibm.com                                        