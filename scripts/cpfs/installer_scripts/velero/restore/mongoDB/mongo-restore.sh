#!/bin/bash
CS_NAMESPACE=""
if [[ ! -z $1 ]]; then
  CS_NAMESPACE=$1
fi

#
# Restore Mongo
#
function restore_mongodb () {
  msg "[$STEP] Restore the mongo database"
  STEP=$(( $STEP+1 ))

  oc get job -n $CS_NAMESPACE | grep mongodb-restore 2>&1
  if [ $? -eq 0 ]
  then
    echo "database restore job already run"
    echo "enter oc delete job mongodb-restore and re-run this script to do it again"
    exit -1
  else
    echo Starting restore

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
        image: icr.io/cpopen/cpfs/ibm-mongodb@sha256:16a5587c212963d9b4c323762d89df7d9357decba59369102e10e4bd2ef4ccd2
        command: ["bash", "-c", "cat /cred/mongo-certs/tls.crt /cred/mongo-certs/tls.key > /work-dir/mongo.pem; cat /cred/cluster-ca/tls.crt /cred/cluster-ca/tls.key > /work-dir/ca.pem; mongorestore --db platform-db --host rs0/icp-mongodb-0.icp-mongodb.$CS_NAMESPACE.svc.cluster.local,icp-mongodb-1.icp-mongodb.$CS_NAMESPACE.svc.cluster.local,icp-mongodb-2.icp-mongodb.$CS_NAMESPACE.svc.cluster.local --port $MONGODB_SERVICE_PORT --username $ADMIN_USER --password $ADMIN_PASSWORD --authenticationDatabase admin --ssl --sslCAFile /work-dir/ca.pem --sslPEMKeyFile /work-dir/mongo.pem /dump/dump/platform-db --drop"]
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

if [[ -z $CS_NAMESPACE ]]; then
  export CS_NAMESPACE=ibm-common-services
fi

restore_mongodb