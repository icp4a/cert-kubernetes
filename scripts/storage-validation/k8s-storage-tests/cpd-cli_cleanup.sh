#!/usr/bin/env sh

HELP="
This script lists storage test resources in the supplied namespace. If the '--delete' flag is provided, it removes those resources.

USAGE:
  cleanup.sh --namespace <namespace> <--delete>

FLAGS:
  -c | --command:           (Required) The cpd-cli storage command resources to list and/or clean up, storage-performance|storage-validation.
  --delete:                 Delete storage test resources created in --namespace.
  -n | --namespace:         (Required) The namespace specified in param.yml, storage_validation_namespace|storage_perf_namespace.
  -h | --help:              Show help for cleanup.sh
"
NAMESPACE=
COMMAND=
DELETE_RESOURCES="0"

CM_SEARCH=
JOB_SEARCH=
PVC_SEARCH=
LOCAL_CONTAINER=

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

set_vars() {
  if [ "${COMMAND}" == "storage-performance" ]; then
    PVC_SEARCH="pvc-sysbench-rwo\|pvc-sysbench-rwx"
    JOB_SEARCH="sysbench-random-\|sysbench-sequential-"
    LOCAL_CONTAINER="k8s-storage-perf"
  fi

  if [ "${COMMAND}" == "storage-validation" ]; then
    CM_SEARCH="consumer\|producer"
    PVC_SEARCH="readiness-readwritemany\|readiness-readwriteonce"
    JOB_SEARCH="readiness-consumer\|readiness-create\|readiness-edit\|readiness-file\|readiness-mount\|readiness-producer\|readiness-read"
    LOCAL_CONTAINER="k8s-storage-val"
  fi
}

list() {
  echo "\nListing ${COMMAND} cluster resources in namespace: ${NAMESPACE}"
  
  if [ -n "${CM_SEARCH}" ]; then
    echo "\nCONFIGMAPS:"
    oc get cm -n ${NAMESPACE} | sed -n "1p;/${CM_SEARCH}/p"
  fi
  
  echo "\nPVCS:"
  oc get pvc -n ${NAMESPACE} | sed -n "1p;/${PVC_SEARCH}/p"
  echo "\nJOBS:"
  oc get job -n ${NAMESPACE} | sed -n "1p;/${JOB_SEARCH}/p"

  echo "\nLocal ${COMMAND} playbook container:"
  podman ps -a --filter="name=${LOCAL_CONTAINER}"
  echo ""
}

delete_resources() {
    echo "\nDeleting ${COMMAND} cluster resources from namespace: ${NAMESPACE}"
    oc get job -n ${NAMESPACE} -o name | grep "${JOB_SEARCH}" | xargs -I % -n 1 oc delete % -n ${NAMESPACE}

    if [ -n "${CM_SEARCH}" ]; then
      oc get cm -n ${NAMESPACE} -o name | grep "${CM_SEARCH}" | xargs -I % -n 1 oc delete % -n ${NAMESPACE}
    fi
    
    sleep 10
    oc get pvc -n ${NAMESPACE} -o name | grep "${PVC_SEARCH}" | xargs -I % -n 1 oc delete % -n ${NAMESPACE}

    echo "\nRemoving local ${COMMAND} container:"
    podman rm -f ${LOCAL_CONTAINER}
    echo ""
}

run() {
  # confirm required flags have been provided  
  if [ -z "${NAMESPACE}" ]; then
    log error "You must specify the --namespace option. For example: --namespace <project-name>"
    print_usage
    exit 1
  fi
  if [ "${COMMAND}" != "storage-performance" ] && [ "${COMMAND}" != "storage-validation" ]; then
    log error "You must specify the --command option. For example: --command <storage-performance|storage-validation>"
    print_usage
    exit 1
  fi

  # set command-specific variables
  set_vars

  # show resources
  list

  # delete storage test resources and re-run list to confirm deletion
  if [ "${DELETE_RESOURCES}" -eq "1" ]; then
    delete_resources
  fi

  exit 0
}

# Parse CLI args
while [ "${1-}" != "" ]; do
    case $1 in
    --namespace | -n)
        shift
        NAMESPACE="${1}"
        ;;
    --command | -c)
        shift
        COMMAND="${1}"
        ;;    
    --delete)
        shift
        DELETE_RESOURCES="1"
        ;;
    --help | -h)
        print_usage 0
        exit 0
        ;;
    *)
        echo "Invalid Option ${1}" >&2
        exit 1
        ;;
    esac
    shift
done

run
