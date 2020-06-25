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
ARG=$1
ASYNC=$2
NAMESPACE=cs-operands-installer
registry_namespace=default
registry_svc=docker-registry
LOCAL_PORT=5000
CUR_DIR=$(pwd)
if [ -n "$(echo $CUR_DIR | grep scripts)" ]; then
    PARENT_DIR=$(dirname "$PWD")
else
    PARENT_DIR=$CUR_DIR
fi

COMMON_SERVICES_INSTALL_DIRECTORY_OCP311=${PARENT_DIR}/descriptors/common-services/scripts/


function create_image_bot() {
  oc get namespace ibm-common-services &>/dev/null || oc create namespace ibm-common-services
  oc -n ibm-common-services get serviceaccount image-bot &>/dev/null || oc -n ibm-common-services create serviceaccount image-bot
  oc -n ibm-common-services policy add-role-to-user registry-editor system:serviceaccount:ibm-common-services:image-bot
}

function set_registry_portforward() {
  echo "Start registry port forward process"
  local registry_port=$(oc get svc $registry_svc -n $registry_namespace -o jsonpath='{.spec.ports[0].port}')
  local port_fwd_obj=$(oc get pods -n $registry_namespace | awk '/^docker-registry-/ {print $1}' | head -n1)
  oc port-forward "$port_fwd_obj" -n "$registry_namespace" "$LO:qCAL_PORT:$registry_port" > .registry-pf.log 2>&1 &
  wait_for_url_timed "http://localhost:5000"
  sleep 5
}

function unset_registry_portforward() {
  local pids=$(ps -ef | awk '/oc port-forward docker-registry/ {print $2}')
  kill -9 $pids &>/dev/null
}

function docker_login() {
  docker login -u image-bot -p "$(oc -n ibm-common-services serviceaccounts get-token image-bot)" localhost:$LOCAL_PORT
  if [[ $? -ne 0 ]]; then
    echo "Docker login failed, please check the image registry in your cluster and try again"
    exit 1
  fi
}

function docker_logout() {
  docker login -u image-bot -p "$(oc -n ibm-common-services serviceaccounts get-token image-bot)" localhost:$LOCAL_PORT
}

function upload() {
    for file in $(ls ../offline)
    do
      if test -f "../offline/$file/image.tar"; then
        echo "Load images for $file ..."
        docker load --input ../offline/$file/image.tar
        echo "Tag and push images for $file ..."
        for image in $(cat ../offline/$file/image.manifest); do
          imageName=$(echo $image | awk -F "/" '{print $NF}')
          docker tag $image "localhost:$LOCAL_PORT/ibm-common-services/$imageName" && docker push "localhost:$LOCAL_PORT/ibm-common-services/$imageName"
          docker rmi "localhost:5000/ibm-common-services/$imageName" $image
        done
      else
        echo "There is no image.tar file in the $file folder"
      fi
    done
}

function wait_for_url_timed {
  STARTTIME=$(date +%s)
  url=$1
  max_wait=${2:-60*1000}
  wait=0.2
  expire=$(($(time_now) + $max_wait))
  set +e
  while [[ $(time_now) -lt $expire ]]; do
  out=$(curl --max-time 2 -fs $url 2>/dev/null)
  if [ $? -eq 0 ]; then
    set -e
    echo ${out}
    ENDTIME=$(date +%s)
    echo "Success accessing '$url' after $(($ENDTIME - $STARTTIME)) seconds"
    return 0
  fi
  sleep $wait
  done
  echo "ERROR: gave up waiting for $url"
  set -e
  return 1
}

function time_now() {
  echo $(date +%s000)
}

function offline_config() {
  sed -i_orig "s|quay.io/opencloudio|docker-registry.default.svc:5000/ibm-common-services|g" configmap.yaml install.yaml uninstall.yaml
}

function install() {
  oc apply -f ${COMMON_SERVICES_INSTALL_DIRECTORY_OCP311}\namespace.yaml
  oc apply -f ${COMMON_SERVICES_INSTALL_DIRECTORY_OCP311}\rbac.yaml
  oc apply -f ${COMMON_SERVICES_INSTALL_DIRECTORY_OCP311}\configmap.yaml
  oc apply -f ${COMMON_SERVICES_INSTALL_DIRECTORY_OCP311}\install.yaml
  if [[ $ASYNC != "--async" ]]; then
    waiting_complete "deploy"
  fi
  exit 0
}

function uninstall() {
  if [[ $ASYNC != "--async" ]]; then
    waiting_complete "uninstall"
  fi
  oc delete job cs-operands-install cs-operands-uninstall -n $NAMESPACE
  oc delete -f ${COMMON_SERVICES_INSTALL_DIRECTORY_OCP311}\rbac.yaml
  oc delete -f ${COMMON_SERVICES_INSTALL_DIRECTORY_OCP311}\configmap.yaml
  oc delete -f ${COMMON_SERVICES_INSTALL_DIRECTORY_OCP311}\namespace.yaml
  oc delete namespace ibm-common-services
  exit 0
}

# Waiting for common service deploy complete
function waiting_complete() {
  index=0
  retries=30
  while true; do
    if [[ $index -eq $retries ]]; then
      echo "Timeout for deploy common services"
      exit 1
    fi

    if [[ $1 == "uninstall" ]]; then
      latest_deploy=$(oc -n $NAMESPACE get pods -l 'operation=uninstall,control-plane=cs-operands' --sort-by=.metadata.creationTimestamp -o=name | sed "s/^.\{4\}//" | head -n1 2>/dev/null)
    elif [[ $1 == "deploy" ]]; then
      latest_deploy=$(oc -n $NAMESPACE get pods -l 'operation=deploy,control-plane=cs-operands' --sort-by=.metadata.creationTimestamp -o=name | sed "s/^.\{4\}//" | head -n1 2>/dev/null)
    else
      latest_deploy=$(oc -n $NAMESPACE get pods -l 'operation in (deploy,uninstall),control-plane=cs-operands' --sort-by=.metadata.creationTimestamp -o=name | sed "s/^.\{4\}//" | head -n1 2>/dev/null)
    fi

    if [[ ! -z "$latest_deploy" ]]; then
      DEPLOYING_STATUS=$(oc -n $NAMESPACE get pods $latest_deploy --no-headers | awk '{print $3}')
      if [[ "$DEPLOYING_STATUS" == "Running" ]]; then
        oc -n $NAMESPACE logs $latest_deploy -f
        continue
      elif [[ "$DEPLOYING_STATUS" == "Completed" ]]; then
        echo "Common services job completed"
        break
      elif [[ "$DEPLOYING_STATUS" == "Error" ]]; then
        echo "Common services job failed. Check deploy log with command: oc -n $NAMESPACE logs $latest_deploy"
        exit 1
      else
        index=$(( index + 1 ))
        [[ $(( $index % 5 )) -eq 0 ]] && echo "Waiting for common services job running ..."
        sleep 10
        continue
      fi
    else
      index=$(( index + 1 ))
      [[ $(( $index % 5 )) -eq 0 ]] && echo "Waiting for common services job create ..."
      sleep 30
      continue
    fi
  done
}

case $ARG in
  upload)
    create_image_bot
    set_registry_portforward
    docker_login
    upload
    docker_logout
    unset_registry_portforward
    ;;
  offline-install)
    create_image_bot
    set_registry_portforward
    docker_login
    upload
    docker_logout
    unset_registry_portforward
    offline_config
    install
    ;;
  offline-uninstall)
    offline_config
    uninstall
    ;;
  install)
    install
    ;;
  uninstall)
    uninstall
    ;;
  *)
    echo "Please input correct command: upload, install, uninstall, offline-install, offline-uninstall"
    ;;
esac
