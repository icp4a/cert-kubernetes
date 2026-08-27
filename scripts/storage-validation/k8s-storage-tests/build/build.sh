#!/bin/bash
set -ex

scriptdir=`dirname $0`
docker_file_name=${scriptdir}/../dockerfile
docker_registry=${DOCKER_REGISTRY:-"localhost:5000"}
docker_image=${DOCKER_IMAGE:-"${docker_registry}/k8s-storage-test"}
docker_tag=${TAG_ID:-"latest"}
arch_type=${ARC_TYPE:-`uname -m`}

dockerexe=${DOCKER_EXE:-podman}

curl -sL https://icpfs1.svl.ibm.com/zen/rebuild-binaries/oc/latest/${ARC_TYPE}/go-latest/oc.tgz -o oc.tgz

if [[ "${dockerexe}" == "podman" ]]
then
   nocache=${DEV_NOCACHE:-"--no-cache --pull=always"}
else
   nocache=${DEV_NOCACHE:-"--no-cache --pull"}
fi

${dockerexe} build --format docker ${nocache} -f ${docker_file_name} \
             -t ${docker_image}:${docker_tag}.${arch_type} \
             --build-arg "architecture=${arch_type}" .