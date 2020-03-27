#!/bin/bash
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2020. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
kubectl delete -f descriptors/operator.yaml
kubectl delete -f descriptors/role_binding.yaml
kubectl delete -f descriptors/role.yaml
kubectl delete -f descriptors/service_account.yaml

kubectl patch crd/icp4aclusters.icp4a.ibm.com -p '{"metadata":{"finalizers":[]}}' --type=merge
kubectl delete crd icp4aclusters.icp4a.ibm.com
echo "All descriptors have been successfully deleted."
