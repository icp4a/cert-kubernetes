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
# CUR_DIR set to full path to scripts folder
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

kubectl delete -f ${CUR_DIR}/../descriptors/operator.yaml
kubectl delete -f ${CUR_DIR}/../descriptors/role_binding.yaml
kubectl delete -f ${CUR_DIR}/../descriptors/role.yaml
kubectl delete -f ${CUR_DIR}/../descriptors/service_account.yaml


echo "All descriptors have been successfully deleted."
