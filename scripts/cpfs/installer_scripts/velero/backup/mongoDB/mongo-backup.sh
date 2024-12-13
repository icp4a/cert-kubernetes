#!/bin/bash
# Used by multi-namespace
CS_NAMESPACE=$1
CONVERT=""
if [[ ! -z $2 ]]; then
  CONVERT=$2
fi

function cleanup() {
  if [[ -z $CS_NAMESPACE ]]; then
    export CS_NAMESPACE=ibm-common-services
  fi
  info "[1] Cleaning up from previous backups..."
  oc delete job mongodb-backup --ignore-not-found -n $CS_NAMESPACE
  pv=$(oc get pvc cs-mongodump -n $CS_NAMESPACE --no-headers=true 2>/dev/null | awk '{print $3 }')
  if [[ -n $pv ]]
  then
    oc delete pvc cs-mongodump -n $CS_NAMESPACE --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        info "Failed to delete pvc cs-mongodump, patching its finalizer to null..."
        oc patch pvc cs-mongodump -n $CS_NAMESPACE --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi
    oc delete pv $pv --ignore-not-found
  fi
  success "Cleanup Complete"
}

function backup_mongodb(){
  info "[3] Backing Up MongoDB"
  #
  #  Get the storage class from the existing PVCs for use in creating the backup volume
  #
  SAMPLEPV=$(oc get pvc -n $CS_NAMESPACE | grep mongodb | awk '{ print $3 }')
  SAMPLEPV=$( echo $SAMPLEPV | awk '{ print $1 }' )
  #STGCLASS=$(oc get pvc --no-headers=true mongodbdir-icp-mongodb-0 -n $CS_NAMESPACE | awk '{ print $6 }')
  STGCLASS=ibmc-block-retain-gold
  # Used by multi-namespace
  if [[ $CONVERT != "" ]]; then
    STGCLASS=$CONVERT
  fi
  #
  # Backup MongoDB
  #
  cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cs-mongodump
  namespace: $CS_NAMESPACE
  labels:
    foundationservices.cloudpak.ibm.com: mongo-data
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: $STGCLASS
EOF

  #
  # Start the backup
  #
  info "Starting backup"
  cat <<EOF | oc apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: mongodb-backup
  namespace: $CS_NAMESPACE
spec:
  parallelism: 1
  completions: 1
  backoffLimit: 20
  template:
    spec:
      containers:
      - name: cs-mongodb-backup
        image: icr.io/cpopen/cpfs/ibm-mongodb@sha256:d62f7145428f62466622160005eafcfee39cbf866df88aaeaee4d99173d1882f
        resources:
          limits:
            cpu: 500m
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 128Mi
        command: ["bash", "-c", "cat /cred/mongo-certs/tls.crt /cred/mongo-certs/tls.key > /work-dir/mongo.pem; cat /cred/cluster-ca/tls.crt /cred/cluster-ca/tls.key > /work-dir/ca.pem; mongodump --oplog --out /dump/dump --host mongodb:27017 --username \$ADMIN_USER --password \$ADMIN_PASSWORD --authenticationDatabase admin --ssl --sslCAFile /work-dir/ca.pem --sslPEMKeyFile /work-dir/mongo.pem"]
        volumeMounts:
        - mountPath: "/work-dir"
          name: tmp-mongodb
        - mountPath: "/dump"
          name: mongodump
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
      restartPolicy: OnFailure
EOF
  sleep 15s

  LOOK=$(oc get po --no-headers=true -n $CS_NAMESPACE | grep mongodb-backup | awk '{ print $1 }')
  waitforpods "mongodb-backup" $CS_NAMESPACE
  success "Dump completed: Use the [oc logs $LOOK -n $CS_NAMESPACE] command for details on the backup operation"

} # backup-mongodb()

function waitforpods() {
  index=0
  retries=60
  info "Waiting for $1 pod(s) to start ..."
  while true; do
      [[ $index -eq $retries ]] && exit 1
      if [ -z $1 ]; then
        pods=$(oc get pods --no-headers -n $2 2>&1)
      else
        pods=$(oc get pods --no-headers -n $2 | grep $1 2>&1)
      fi
      echo "$pods" | egrep -q -v 'Completed|Succeeded|No resources found.' || break
      [[ $(( $index % 10 )) -eq 0 ]] && echo "$pods" | egrep -v 'Completed|Succeeded'
      sleep 10
      index=$(( index + 1 ))
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

cleanup
backup_mongodb