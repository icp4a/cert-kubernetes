#!/usr/bin/env bash

# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2023. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product.
# Please refer to that particular license for additional information.

# ---------- CLI Compatibility Functions ----------#
#
# This file provides compatibility wrappers for oc/kubectl commands
# to allow scripts to work with both OpenShift (oc) and Kubernetes (kubectl)
#

# Get the currently logged-in user
# Usage: get_current_user "$OC"
# Returns: username string
function get_current_user() {
    local cli=$1
    
    if [[ "${cli}" == *"kubectl"* ]]; then
        # kubectl doesn't have 'whoami', use config view instead
        ${cli} config view --minify -o jsonpath='{.contexts[0].context.user}' 2>/dev/null
    else
        # oc has native whoami command
        ${cli} whoami 2>/dev/null
    fi
}

# Get the current namespace/project
# Usage: get_current_namespace "$OC"
# Returns: namespace/project name string
function get_current_namespace() {
    local cli=$1
    
    if [[ "${cli}" == *"kubectl"* ]]; then
        # kubectl uses 'config view' to get current namespace
        ${cli} config view --minify -o jsonpath='{.contexts[0].context.namespace}' 2>/dev/null
    else
        # oc has native project command
        ${cli} project --short 2>/dev/null
    fi
}

# Check if user is logged into the cluster
# Usage: check_cluster_login "$OC"
# Returns: 0 if logged in, 1 if not
function check_cluster_login() {
    local cli=$1
    local user
    
    user=$(get_current_user "$cli")
    
    if [ -z "$user" ] || [ $? -ne 0 ]; then
        return 1
    else
        return 0
    fi
}

# Made with Bob
