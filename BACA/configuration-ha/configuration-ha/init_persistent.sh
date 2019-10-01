#!/usr/bin/env bash

#
# Licensed Materials - Property of IBM
# 6949-68N
#
# © Copyright IBM Corp. 2018 All Rights Reserved
#

. ./common.sh


cat sppersistent.yaml | sed s/\$NFS_IP/"$NFS_IP"/ | sed s/\$KUBE_NAME_SPACE/"$KUBE_NAME_SPACE"/ | sed s/\$DATAPVC/"$DATAPVC"/ | sed s/\$LOGPVC/"$LOGPVC"/ | sed s/\$CONFIGPVC/"$CONFIGPVC"/ |kubectl apply -f -

