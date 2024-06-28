#!/bin/bash
OLD_CS_NS=""
if [[ ! -z $1 ]]; then
  OLD_CS_NS=$1
fi
s390x="false"
if [[ ! -z $2 ]]; then
  s390x=$2
fi
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

#
# Restore Mongo
#
function restore_mongodb () {
  msg "[$STEP] Restore the mongo database"
  STEP=$(( $STEP+1 ))

  # Copy the PVC if needed
  oc get pvc cs-mongodump -n $CS_NAMESPACE
  if [ $? -ne 0 ]
  then
    echo PVC cs-mongodump not found!
    exit -1
  fi

  oc delete secret icp-mongo-setaccess -n $CS_NAMESPACE >/dev/null 2>&1
  oc create secret generic icp-mongo-setaccess -n $CS_NAMESPACE --from-file=set_access.js

  oc get job -n $CS_NAMESPACE | grep mongodb-restore 2>&1
  if [ $? -eq 0 ]
  then
    echo "database restore job already run"
    echo "enter oc delete job mongodb-restore and re-run this script to do it again"
    exit -1
  else
    echo Starting restore

    ibm_mongodb_image=$(oc get pod icp-mongodb-0 -n $OLD_CS_NS -o=jsonpath='{range .spec.containers[0]}{.image}{end}')
    if [[ $s390x == "false" ]]; then
      cat <<EOF | oc apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: mongodb-restore
  namespace: $CS_NAMESPACE
spec:
  parallelism: 1
  completions: 1
  backoffLimit: 20
  template:
    spec:
      containers:
      - name: icp-mongodb-restore
        image: $ibm_mongodb_image
        command: ["bash", "-c", "cat /cred/mongo-certs/tls.crt /cred/mongo-certs/tls.key > /work-dir/mongo.pem; cat /cred/cluster-ca/tls.crt /cred/cluster-ca/tls.key > /work-dir/ca.pem; mongorestore --host rs0/icp-mongodb:27017 --username \$ADMIN_USER --password \$ADMIN_PASSWORD --authenticationDatabase admin --ssl --sslCAFile /work-dir/ca.pem --sslPEMKeyFile /work-dir/mongo.pem /dump/dump"]
        resources:
          limits:
            cpu: 500m
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 128Mi
        volumeMounts:
        - mountPath: "/dump"
          name: mongodump
        - mountPath: "/work-dir"
          name: tmp-mongodb
        - mountPath: "/cred/mongo-certs"
          name: icp-mongodb-client-cert
        - mountPath: "/cred/cluster-ca"
          name: cluster-ca-cert
        env:
          - name: ADMIN_USER
            valueFrom:
              secretKeyRef:
                name: icp-mongodb-admin
                key: user
          - name: ADMIN_PASSWORD
            valueFrom:
              secretKeyRef:
                name: icp-mongodb-admin
                key: password
      volumes:
      - name: mongodump
        persistentVolumeClaim:
          claimName: cs-mongodump
      - name: tmp-mongodb
        emptyDir: {}
      - name: icp-mongodb-client-cert
        secret:
          secretName: icp-mongodb-client-cert
      - name: cluster-ca-cert
        secret:
          secretName: mongodb-root-ca-cert
      restartPolicy: Never
EOF
    else
      cat <<EOF | oc apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: mongodb-restore
  namespace: $CS_NAMESPACE
spec:
  parallelism: 1
  completions: 1
  backoffLimit: 20
  template:
    spec:
      containers:
      - name: icp-mongodb-restore
        image: $ibm_mongodb_image
        command: ["bash", "-c", "cat /cred/mongo-certs/tls.crt /cred/mongo-certs/tls.key > /work-dir/mongo.pem; cat /cred/cluster-ca/tls.crt /cred/cluster-ca/tls.key > /work-dir/ca.pem; mongorestore --host rs0/icp-mongodb:27017 --username \$ADMIN_USER --password \$ADMIN_PASSWORD --authenticationDatabase admin /dump/dump"]
        resources:
          limits:
            cpu: 500m
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 128Mi
        volumeMounts:
        - mountPath: "/dump"
          name: mongodump
        - mountPath: "/work-dir"
          name: tmp-mongodb
        - mountPath: "/cred/mongo-certs"
          name: icp-mongodb-client-cert
        - mountPath: "/cred/cluster-ca"
          name: cluster-ca-cert
        env:
          - name: ADMIN_USER
            valueFrom:
              secretKeyRef:
                name: icp-mongodb-admin
                key: user
          - name: ADMIN_PASSWORD
            valueFrom:
              secretKeyRef:
                name: icp-mongodb-admin
                key: password
      volumes:
      - name: mongodump
        persistentVolumeClaim:
          claimName: cs-mongodump
      - name: tmp-mongodb
        emptyDir: {}
      - name: icp-mongodb-client-cert
        secret:
          secretName: icp-mongodb-client-cert
      - name: cluster-ca-cert
        secret:
          secretName: mongodb-root-ca-cert
      restartPolicy: Never
EOF
    fi
    sleep 20s

    LOOK=$(oc get po --no-headers=true -n $CS_NAMESPACE | grep mongodb-restore | awk '{ print $1 }')
    waitforpodscompleted "mongodb-restore" $CS_NAMESPACE

    success "Restore completed: Use the [oc logs $LOOK -n $CS_NAMESPACE] command for details on the restore operation"
  fi
} # restore_mongodb


function waitforpodscompleted() {
  index=0
  retries=60
  echo "Waiting for $1 pod(s) to start ..."
  while true; do
      if [ $index -eq $retries ]; then
        error "Pods are not running or completed, Correct errors and re-run the script"
        exit -1
      fi
      sleep 10
      if [ -z $1 ]; then
        pods=$(oc get pods --no-headers -n $2 2>&1)
      else
        pods=$(oc get pods --no-headers -n $2 | grep $1 2>&1)
      fi
      #echo watching $pods
      echo "$pods" | egrep -q -v 'Completed|Succeeded|No resources found.' || break
      [[ $(( $index % 10 )) -eq 0 ]] && echo "$pods" | egrep -v 'Completed|Succeeded'
      index=$(( index + 1 ))
      # If one matching pod Completed and other matching pods in Error,  remove Error pods
      nothing=$(echo $pods | grep Completed)
      if [ $? -eq 0 ]; then
        nothing=$(echo $pods | grep Error)
        if [ $? -eq 0 ]; then
          echo "$pods" | grep Error | awk '{ print "oc delete po " $1 }' | bash -
        fi
      fi
  done
  if [ -z $1 ]; then
    oc get pods --no-headers=true -n $2
  else
    oc get pods --no-headers=true -n $2 | grep $1
  fi
}

if [[ -z $CS_NAMESPACE ]]; then
  export CS_NAMESPACE=ibm-common-services
fi

restore_mongodb
