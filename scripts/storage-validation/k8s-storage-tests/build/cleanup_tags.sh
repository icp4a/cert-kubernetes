#!/bin/bash

if [ $# -ne 3 ]; then
  echo "Error: This script requires exactly three arguments."
  echo "Usage: cleanup.sh upstream/origin <IMAGE-NAME> <CP4D-VERSION>"
  echo "Example: ./cleanup_tags.sh upstream k8s-storage-test 5.1.2"
  exit 1
fi

CPDVER="$3"
IMAGE="$2"
REMOTE="$1"

# CLEANUP PRE-EXISTING LOCAL TAGS ON REMOTE
TAGS=`git tag |grep ${IMAGE}-${CPDVER}`
echo "TAGS: ${TAGS}"

for tag in ${TAGS}
do
   git push --delete ${REMOTE} ${tag}
done
