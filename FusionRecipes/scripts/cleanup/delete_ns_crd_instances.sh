#!/bin/bash 

NAMESPACE=$1
echo Cleaning up CRDs intance for $NAMESPACE

# Check if NAMESPACE is empty
if [ -z "$NAMESPACE" ]; then
    echo "NAMESPACE is empty. Exiting."
    exit 1
fi

for i in $(oc get operandrequest --no-headers -n $NAMESPACE | awk '{print $1}'); do
	oc patch operandrequest/$i -p '{"metadata":{"finalizers":[]}}' --type=merge -n $NAMESPACE
	oc delete operandrequest $i --ignore-not-found=true --wait=true -n $NAMESPACE
done

for i in $(oc get zenextension --no-headers -n $NAMESPACE | awk '{print $1}'); do
	oc patch zenextension/$i -p '{"metadata":{"finalizers":[]}}' --type=merge -n $NAMESPACE
	oc delete zenextension $i --ignore-not-found=true --wait=true -n $NAMESPACE 
done

for i in $(oc get operandbindinfo --no-headers -n $NAMESPACE | awk '{print $1}'); do
	oc patch operandbindinfo/$i -p '{"metadata":{"finalizers":[]}}' --type=merge -n $NAMESPACE
	oc delete operandbindinfo $i --ignore-not-found=true --wait=true -n $NAMESPACE
done

for i in $(oc get clients.oidc.security.ibm.com --no-headers -n $NAMESPACE | awk '{print $1}'); do
	oc patch clients.oidc.security.ibm.com/$i -p '{"metadata":{"finalizers":[]}}' --type=merge -n $NAMESPACE
	oc delete clients.oidc.security.ibm.com $i --ignore-not-found=true --wait=true -n $NAMESPACE
done

for i in $(oc get authentications.operator.ibm.com --no-headers -n $NAMESPACE | awk '{print $1}'); do
	oc patch authentications.operator.ibm.com/$i -p '{"metadata":{"finalizers":[]}}' --type=merge -n $NAMESPACE
	oc delete authentications.operator.ibm.com $i --ignore-not-found=true --wait=true -n $NAMESPACE
done


