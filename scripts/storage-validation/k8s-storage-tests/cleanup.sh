#!/usr/bin/env sh
################################################################################
# Copyright 2022 IBM
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# 		http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

# Global Definitions

HELP="
USAGE:
  cleanup.sh --namespace <namespace> [--delete-namespace]

FLAGS:
  -n | --namespace:         This is the namespace where the storage test was executed in
  -d | --delete-namespace:  When present will delete the namespace as part of cleanup
"
NAMESPACE=
DELETE_NAMESPACE="0"

# Function Definitions

log() {
  prefix=""
  case "${1}" in
  info)
    prefix="[INFO ]"
    ;;
  debug)
    prefix="[DEBUG]"
    ;;
  error)
    prefix="[ERROR]"
    ;;
  *)
    prefix=""
    ;;
  esac
  echo "${prefix} ${2}"
}

print_usage() {
  log noop "${HELP}"
}

run() {

  if [ -z "${NAMESPACE}" ]; then log error "--namespace is a required flag"; print_usage; exit 1; fi

  KEEP_NS=" not"
  if [ "${DELETE_NAMESPACE}" -eq "1" ]; then KEEP_NS=""; fi
  log info "running clean up for namespace ${NAMESPACE} and the namespace will${KEEP_NS} be deleted"
  log info "please run the following command in a terminal that has access to the cluster to clean up after the ansible playbooks"

  echo
  # cleanup the namespace scoped resources
  for kind in "job" "pvc" "cm"; do
    oc_delete_tpl="oc get ${kind} -n ${NAMESPACE} -o name | xargs -I % -n 1 oc delete % -n ${NAMESPACE}"  
    echo "${oc_delete_tpl} && \\"
  done

  # delete cluster scoped resources
  if [ "${DELETE_NAMESPACE}" -eq "1" ]; then
    echo "oc delete ns ${NAMESPACE} --ignore-not-found && \\"
  fi

  echo "oc delete scc zz-fsgroup-scc --ignore-not-found"
  echo

  log info "cleanup script finished with no errors"

  exit 0
}

# Parse CLI args
while [ "${1-}" != "" ]; do
    case $1 in
    --namespace | -n)
        shift
        NAMESPACE="${1}"
        ;;
    --delete-namespace | -d)
        DELETE_NAMESPACE="1"
        ;;
    --help)
        print_usage 0
        ;;
    *)
        echo "Invalid Option ${1}" >&2
        exit 1
        ;;
    esac
    shift
done

run