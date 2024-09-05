#!/usr/bin/env bash

# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2023. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product. 
# Please refer to that particular license for additional information.

# JSON_FILE=""

function create_json() {
    JSON_FILE=$1
    export JSON_FILE=$1
    jq -n '[]' > "$JSON_FILE"
}

function create_group() {
    local name=$1

    if [ ! -e "$JSON_FILE" ]; then
        echo "Output JSON file: $JSON_FILE, is missing"
        return 1
    fi

    local group_exists=$(jq --arg name "$name" -r '.[] | select(.groupName==$name) | .groupName' "$JSON_FILE")

    # TODO: determine if this condition can be handled by jq instead
    if [ "$group_exists" == "$name" ]; then
        echo "Group: $name, already created, skipping"
        return 0
    fi
    
    local json=$(
        jq --arg name "$name" '
            . |= .+ [{"groupName": $name, "status": {"overall": "running checks", "checks": []}}]
        ' "$JSON_FILE"
    )

    if [ "$json" != "" ]; then
        echo "$json" > "$JSON_FILE"
    fi
}

function append_check() {
    local group=$1
    local check=$2
    local status=$3
    local reason=$4
    local extras=$5

    if [ ! -e "$JSON_FILE" ]; then
        echo "Output JSON file: $JSON_FILE, is missing"
        return 1
    fi

    local check_exists=$(
        jq --arg group "$group" \
           --arg check "$check" \
           -r '
            map(select(.groupName==$group).status.checks[] | select(.checkName==$check))
        ' "$JSON_FILE"
    )
    
    if [ "$check_exists" == "[]" ]; then
        local json=$(
            jq --arg group "$group" \
            --arg check "$check" \
            --arg status "$status" \
            --arg reason "$reason" \
            --arg extras "$extras" '
                ( .[] | select(.groupName==$group).status.checks ) |= .+ [{"checkName": $check, "status": $status, "reason": $reason, "extras": $extras}]
            ' "$JSON_FILE"
        )
    else
        local json=$(
            jq --arg group "$group" \
            --arg check "$check" \
            --arg status "$status" \
            --arg reason "$reason" \
            --arg extras "$extras" '
                ( .[] | select(.groupName==$group).status.checks[] | select(.checkName==$check) ) |= .+ {"status": $status, "reason": $reason, "extras": $extras}
            ' "$JSON_FILE"
        )
    fi

    if [ "$json" != "" ]; then
        echo "$json" > "$JSON_FILE"
    fi
}

function update_overall() {
    local group=$1
    local status="ok"

    local is_failed=$(jq --arg group "$group" '.[] | select(.groupName==$group).status.checks | any(.status=="failed")' $JSON_FILE)
    if [ "$is_failed" == "true" ]; then
        status="failed"
    fi
    
    if [ ! -e "$JSON_FILE" ]; then
        echo "Output JSON file: $JSON_FILE, is missing"
    fi

    local group_exists=$(jq --arg group "$group" -r '.[] | select(.groupName==$group) | .groupName' "$JSON_FILE")

    if [ -z "$group_exists" ]; then
        echo "Failed to update group status. Group: $group, missing"
        return 1
    fi

    local json=$(
        jq --arg group "$group" \
        --arg status "$status" '
            ( .[] | select(.groupName==$group).status.overall ) |= $status
        ' "$JSON_FILE"
    )

    if [ "$json" != "" ]; then
        echo "$json" > "$JSON_FILE"
    fi
}

function success() {
  msg "\33[32m[✔] ${1}\33[0m"
}

function error() {
  msg "\33[31m[✘] ${1}\33[0m"
}

function msg() {
    printf '%b\n' "${1}"
}

function title() {
  msg "\33[1m# ${1}\33[0m"
  echo "============================================================================================================"
}