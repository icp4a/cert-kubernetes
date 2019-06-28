#!/usr/bin/env bash
#
# Licensed Materials - Property of IBM
# 6949-68N
#
# © Copyright IBM Corp. 2018 All Rights Reserved
#
. ./bashfunctions.sh
. ./common.sh

echo -e "\x1B[1;32mThis will generate recommended values for setting memory resources in Business Automation Content Analyzer (CA) product.\x1B[0m"
echo -e "\x1B[1;32mUse \"distributed\" flag when you have an distribute environment where mongo DB, mongo-admin DB, and CA processing components are their own nodes.  Otherwise, use \"limited\" flag \x1B[0m"
echo -e "\x1B[1;32mThese values may need to be adjusted depending on your workload\x1B[0m"


if [[ -z $1 ]]; then
    echo -e "\x1B[1;31mYou need to pass in either \"distributed\" or \"limited\" to use this script\x1B[0m"
    exit 1
fi


if [[ $1 == "distributed" ]]; then
    calMemoryLimitedDist
    calNumOfContainers
elif [[ $1 == "limited" ]]; then
    calMemoryLimitedShared
    calNumOfContainers
fi