.PHONY: labels
labels:
	echo "Label licensing configmaps"
	./backup/licensing/label-licensing-configmaps.sh
	echo "Label cert-manager resources"
	./backup/cert-manager/label-cert-manager.sh
	echo "Catalog Source labels"
	oc label catalogsource ibm-operator-catalog foundationservices.cloudpak.ibm.com=catalog -n openshift-marketplace --overwrite=true
	echo "Operator Group"
	oc label operatorgroup foundationservices.cloudpak.ibm.com=operatorgroup --all --overwrite=true -n ibm-common-services
	echo "Subcription labels"
	# oc label subscription operand-deployment-lifecycle-manager-app foundationservices.cloudpak.ibm.com=subscription --overwrite=true -n ibm-common-services
	# oc label subscription ibm-namespace-scope-operator foundationservices.cloudpak.ibm.com=subscription --overwrite=true -n ibm-common-services
	oc label subscription ibm-common-service-operator foundationservices.cloudpak.ibm.com=subscription --overwrite=true -n ibm-common-services
	echo "Common Service"
	oc label commonservices common-service foundationservices.cloudpak.ibm.com=commonservice --overwrite=true -n ibm-common-services
	echo "Operand Requests"
	oc label operandrequests common-service foundationservices.cloudpak.ibm.com=operand --overwrite=true -n ibm-common-services
	oc label operandconfig common-service foundationservices.cloudpak.ibm.com=operand --overwrite=true -n ibm-common-services
	echo "Entitlement Key"
	oc label secret ibm-entitlement-key foundationservices.cloudpak.ibm.com=entitlementkey --overwrite=true -n ibm-common-services
	echo "Pull Secret"
	oc label secret pull-secret -n openshift-config foundationservices.cloudpak.ibm.com=pull-secret --overwrite=true
	echo "Namespace"
	oc label namespace ibm-common-services foundationservices.cloudpak.ibm.com=namespace --overwrite=true
	echo "ADD foundationservices.cloudpak.ibm.com=zen label to your Zen Services and Zen Operand Request"
