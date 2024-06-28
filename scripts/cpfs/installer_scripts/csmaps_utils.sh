#!/usr/bin/env bash
#
# Copyright 2022 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -o nounset

OC=oc
YQ=yq
CM_NAME="mock-cs-maps"
CONTROL_NS="cs-control"

# update_cs_maps Updates the common-service-maps with the given yaml. Note that
# the given yaml should have the right indentation/padding, minimum 2 spaces per
# line. If there are multiple lines in the yaml, ensure that each line has
# correct indentation.
function update_cs_maps() {
    local yaml=$1

    local object="$(
        cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: "$CM_NAME"
  namespace: kube-public
data:
  common-service-maps.yaml: |
${yaml}
EOF
)"
    echo "$object" | oc apply -f -
}

# create_empty_csmaps Creates a new common-service-maps configmap and inserts
# an empty common-service-maps.yaml field.
#
# If the common-service-maps already exists, then will error
function create_empty_csmaps() {
    title " Creating empty common-service-maps configmap "
    local isExists=$("${OC}" get configmap --ignore-not-found -n kube-public "$CM_NAME")
    if [ ! -z "$isExists" ]; then
        info "The $CM_NAME already exists, skipping"
        return
    fi
    update_cs_maps ""
    success "Empty common-service-maps configmap created in kube-public namespace"
}

# insert_control_ns Insert the controlNamespace field into the configmap if it
# does not exist
function insert_control_ns() {
    local current_yaml=$("${OC}" get -n kube-public cm "$CM_NAME" -o yaml | "${YQ}" '.data.["common-service-maps.yaml"]')

    current=$(echo "$current_yaml" | "${YQ}" '.controlNamespace')
    if [[ "$current" != "$CONTROL_NS" && "$current" != "" && "$current" != "null" ]]; then
        error "The controlNamespace field in common-service-maps is already set to: $current, and cannot be changed"
    fi

    local updated_yaml=$(echo "$current_yaml" | "${YQ}" '.controlNamespace = "'$CONTROL_NS'"')
    local padded_yaml=$(echo "$updated_yaml" | awk '$0="    "$0')
    update_cs_maps "$padded_yaml"
}

# read_tenant_from_csmaps Gets the list in requested-from-namespace for a given
# map_to_cs_ns and prints it out. If map_to_cs_ns does not exist, then output is
# empty
function read_tenant_from_csmaps() {
    local map_to_cs_ns=$1
    local current_yaml=$("${OC}" get -n kube-public cm "$CM_NAME" -o yaml | "${YQ}" '.data.["common-service-maps.yaml"]')
    local tenant_ns_list=$(echo "$current_yaml" | "${YQ}" eval '.namespaceMapping[] | select(.map-to-common-service-namespace == "'${map_to_cs_ns}'").requested-from-namespace' | awk '{ print $2 }')
    echo "$tenant_ns_list"
}

# update_tenant Updates an entire tenant in common-service-maps. The tenant is
# identified by map_to_cs_ns, and will be updated with the given list of
# namespaces which must be space delimited.
#
# If tenant does not exist, then it will be added.
# The map_to_cs_ns will always be added to the requested-from-namespace list.
# Before the common-service-maps is updated, the requested-from-namespace list
# will be made unique, so that there are no duplicates
function update_tenant() {
    local map_to_cs_ns=$1
    shift
    local namespaces=$@

    local current_yaml=$("${OC}" get -n kube-public cm "$CM_NAME" -o yaml | "${YQ}" '.data.["common-service-maps.yaml"]')
    local updated_yaml="$current_yaml"

    local isExists=$(echo "$current_yaml" | "${YQ}" '.namespaceMapping[] | select(.map-to-common-service-namespace == "'$map_to_cs_ns'")')
    if [ -z "$isExists" ]; then
        info "The provided map-to-common-service-namespace: $map_to_cs_ns, does not exist in common-service-maps"
        info "Adding new map-to-commn-service-namespace"
        updated_yaml=$(echo "$current_yaml" | "${YQ}" eval 'with(.namespaceMapping; . += [{"map-to-common-service-namespace": "'$map_to_cs_ns'"}])')
    fi

    local tmp="\"$map_to_cs_ns\","

    for ns in $namespaces; do
        tmp="$tmp\"$ns\","
    done
    local ns_delimited="${tmp:0:-1}" # substring from 0 to length - 1

    updated_yaml=$(echo "$updated_yaml" | "${YQ}" eval 'with(.namespaceMapping[]; select(.map-to-common-service-namespace == "'$map_to_cs_ns'").requested-from-namespace = ['$ns_delimited'])')
    updated_yaml=$(echo "$updated_yaml" | "${YQ}" eval 'with(.namespaceMapping[]; select(.map-to-common-service-namespace == "'$map_to_cs_ns'").requested-from-namespace |= unique)')
    local padded_yaml=$(echo "$updated_yaml" | awk '$0="    "$0')
    update_cs_maps "$padded_yaml"
}

function msg() {
    printf '%b\n' "$1"
}

function success() {
    msg "\33[32m[✔] ${1}\33[0m"
}

function warning() {
    msg "\33[33m[✗] ${1}\33[0m"
}

function error() {
    msg "\33[31m[✘] ${1}\33[0m"
    exit 1
}

function title() {
    msg "\33[34m# ${1}\33[0m"
}

function info() {
    msg "[INFO] ${1}"
}

# create_empty_csmaps

# insert_control_ns

# update_tenant "tenant1"
# echo "List of namespaces in tenant1: "
# read_tenant_from_csmaps "tenant1"

# update_tenant "tenant1" "ns1 ns2"
# echo "List of namespaces in tenant1: "
# read_tenant_from_csmaps "tenant1"

# update_tenant "tenant2" "ns3"
# echo "List of namespaces in tenant2: "
# read_tenant_from_csmaps "tenant2"
