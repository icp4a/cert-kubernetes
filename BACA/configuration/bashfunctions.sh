#!/usr/bin/env bash

#
# Licensed Materials - Property of IBM
# 6949-68N
#
# © Copyright IBM Corp. 2018 All Rights Reserved
#

# Function to request user for their domain name

export ICP_clustername=$(echo $DOCKER_REG_FOR_SERVICES | awk -F'[.]' '{print $1}')
export ICP_account_id="id-"$ICP_clustername"-account"

# Login to ICP, to ensure bx pr and kubectl commands work in later functions
function loginToCluster() {
   if [[ $ICP_VERSION == "3.1.0" || $ICP_VERSION == "3.1.2" ]]; then   
      echo
      #echo "\x1B[1;31m Logging into ICP using: bx pr login -a https://$MASTERIP:8443 --skip-ssl-validation -u admin
      # -p admin -c id-mycluster-account.  \x1B[0m"
      export ICP_USER_PASSWORD_DECODE=$(echo $ICP_USER_PASSWORD | base64 --decode)
      #ICP 3.10
     cloudctl login -a https://$MASTERIP:8443 --skip-ssl-validation -u $ICP_USER -p $ICP_USER_PASSWORD_DECODE -c $ICP_account_id -n default
  fi
  if [[ $OCP_VERSION == "3.11" ]]; then
      echo
      export OCP_USER_PASSWORD_DECODE=$(echo $OCP_USER_PASSWORD | base64 --decode)
      #echo "\x1B[1;31m Logging into OCP using: oc login https://$MASTERIP:8443 --insecure-skip-tls-verify=true -u $OCP_USER
      # -p $OCP_USER_PASSWORD_DECODE.  \x1B[0m"
      #OCP 3.11
      oc login https://$MASTERIP:8443 --insecure-skip-tls-verify=true -u $OCP_USER -p $OCP_USER_PASSWORD_DECODE
  fi
}

# -------------------
# HELM Client setup
# -------------------
function downloadHelmClient() {


   if [[ $ICP_VERSION == "3.1.0" || $ICP_VERSION == "3.1.2" ]]; then
      echo
      echo "Downloading Helm 2.9.1 from ICp"
      curl -kLo helm-linux-amd64-v2.9.1.tar.gz https://$MASTERIP:8443/api/cli/helm-linux-amd64.tar.gz
      echo
	  echo "Moving helm to /usr/local/bin and chmod 755 helm"
      tar -xvf helm-linux-amd64-v2.9.1.tar.gz
      chmod 755 ./linux-amd64/helm && mv ./linux-amd64/helm /usr/local/bin
      rm -rf linux-amd64
    # testing Helm
      echo Testing Helm CLI using:  helm version --tls
      helm version --tls
   fi

   if [[ $OCP_VERSION == "3.11" ]]; then
    echo "Downloading Helm 2.11.0 from Github"
      curl -s https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz | tar xz
      echo
          echo "Moving helm to /usr/local/bin and chmod 755 helm"

      chmod 755 ./linux-amd64/helm && mv ./linux-amd64/helm /usr/local/bin
      rm -rf linux-amd64

   fi
}


function helmSetup(){

    if [[ $ICP_VERSION == "3.1.2" ]]; then
    # ICP specific setup
    echo
    echo Initializing Helm CLI using: helm init --client-only
    helm init --client-only
	echo
    echo Creating clusterrolebinding tiller-cluster-admin ....
    kubectl create clusterrolebinding tiller-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
    fi

    if [[ $OCP_VERSION == "3.11" ]]; then
    echo Creating clusterrolebinding tiller-cluster-admin ....
    export TILLER_NAMESPACE=tiller
    oc new-project $TILLER_NAMESPACE
    oc project $TILLER_NAMESPACE
    oc process -f https://github.com/openshift/origin/raw/master/examples/helm/tiller-template.yaml -p TILLER_NAMESPACE="${TILLER_NAMESPACE}" -p HELM_VERSION=v2.11.0 | oc create -f -
    oc rollout status deployment tiller
    oc project $KUBE_NAME_SPACE
    oc policy add-role-to-user $OCP_USER "system:serviceaccount:${TILLER_NAMESPACE}:tiller"
    fi

}

function checkHelm(){

    if [[ $ICP_VERSION == "3.1.2" ]]; then
    MAX_ITERATIONS=120
    count=0
    while [[ $( kubectl get deployment tiller-deploy --namespace kube-system | sed -n '1!p' | awk '{print $5}' ) == 0 ]]
    do
        if [ "$count" -eq $MAX_ITERATIONS ]; then
          echo "ERROR: Failed to find tiller-deploy after $MAX_ITERATIONS tries.  Please check your cluster using kubectl get deployment tiller-deploy --namespace kube-system"
	  return 1
	fi
        echo "Checking that helm tiller is deployed ......................"
        sleep 10
        ((count++))
    done
    echo "Helm deployed successfully ......................"
    fi
}



function getWorkerIPs() {
    echo "inside getWorkerIPs"  
    if [[ $ICP_VERSION == "3.1.0" || $ICP_VERSION == "3.1.2" ]]; then
        export ICP_USER_PASSWORD_DECODE=$(echo $ICP_USER_PASSWORD | base64 --decode)
        echo "About to get all the worker IPs from $ICP_VERSION"
        echo  "login -a https://$MASTERIP:8443 --skip-ssl-validation -u $ICP_USER -p $ICP_USER_PASSWORD_DECODE -c $ICP_account_id"
        cloudctl login -a https://$MASTERIP:8443 --skip-ssl-validation -u $ICP_USER -p $ICP_USER_PASSWORD_DECODE -c $ICP_account_id -n default
        export WORKER_IPs=$(cloudctl cm workers --json | grep "publicIP" | awk '{print $2}' | cut -d ',' -f1 | tr -d '"')
            if [ -z "$WORKER_IPs" ]; then
                echo "Cannot find public IP for worker nodes.  Will try to check for Private IP now"
                export WORKER_IPs=$(cloudctl cm workers --json | grep "privateIP" | awk '{print $2}' | cut -d ',' -f1 | tr -d '"')
                echo WORKER_IPs=$WORKER_IPs
                if [[ -z "$WORKER_IPs" ]]; then exit 1; fi
            fi
    fi
    if [[ $OCP_VERSION == "3.11" ]]; then
        echo "About to get all the worker IPs from $OCP_VERSION"
        loginToCluster
        export WORKER_IPs=$(oc get nodes | grep compute | grep  [^Not]Ready | awk '{print $1}' | cut -d ',' -f1 | tr -d '"')
	echo WORKER_IPs=$WORKER_IPs
        if [[ -z "$WORKER_IPs" ]]; then exit 1; fi
    fi

}
function getWorkerIPBasedOnLabel() {
    echo "inside getWorkerIP1s.  It will get the worker IPs based on label"

    loginToCluster
    if [[ $ICP_VERSION == "3.1.0" || $ICP_VERSION == "3.1.2" ]]; then
        export WORKER_IP1s=$(kubectl get nodes --show-labels |grep worker.*$KUBE_NAME_SPACE=baca | grep  [^Not]Ready | awk {'print $1'})
    fi
    if [[ $OCP_VERSION == "3.11" ]]; then
        export WORKER_IP1s=$(kubectl get nodes --show-labels |grep compute=true |grep celery$KUBE_NAME_SPACE'='baca | grep  [^Not]Ready | awk {'print $1'})
    fi
    echo $WORKER_IP1s
    if [[ -z "$WORKER_IP1s" ]]; then exit 1; fi

}
function clearAllLabels(){
    echo "About to clear ALL label nodes with in $KUBE_NAME_SPACE"
    getWorkerIPs
    for i in $WORKER_IPs
        do
           echo "Clear out previous labeling"
           kubectl label nodes $i {celery$KUBE_NAME_SPACE-,mongo$KUBE_NAME_SPACE-,mongo-admin$KUBE_NAME_SPACE-}
           echo
        done
}
#function labelNodes() {
#    clearAllLabels
#    echo "About to label ALL nodes with celery$KUBE_NAME_SPACE=baca."
#    getWorkerIPs
#    for i in $WORKER_IPs
#        do
#           echo "Label --overwrite $i with celery$KUBE_NAME_SPACE=baca"
#           kubectl label nodes --overwrite $i {celery$KUBE_NAME_SPACE=baca,mongo$KUBE_NAME_SPACE=baca,mongo-admin$KUBE_NAME_SPACE=baca}
#        done
#}

function customLabelNodes() {
    loginToCluster
    clearAllLabels
#    echo "Clear out previous labeling"
#    kubectl label nodes $i {celery$KUBE_NAME_SPACE-,mongo$KUBE_NAME_SPACE-,mongo-admin$KUBE_NAME_SPACE-,postgres$KUBE_NAME_SPACE-}

    echo "About to label  --overwrite $CA_WORKERS with celery$KUBE_NAME_SPACE=baca."
    echo label nodes {$CA_WORKERS} celery$KUBE_NAME_SPACE=baca
    for i in $(echo $CA_WORKERS | sed "s/,/ /g")
        do
           echo "Label $i with celery$KUBE_NAME_SPACE=baca"
            kubectl label nodes --overwrite $i celery$KUBE_NAME_SPACE=baca
            echo
        done
    echo
    echo "About to label  $MONGO_WORKERS with mongo$KUBE_NAME_SPACE=baca."
    for i in $(echo $MONGO_WORKERS | sed "s/,/ /g")
        do
           echo "Label $i with mongo$KUBE_NAME_SPACE=baca"
           kubectl label nodes --overwrite $i mongo$KUBE_NAME_SPACE=baca
        done
    echo
    echo "About to label  $MONGO_ADMIN_WORKERS with mongo-admin$KUBE_NAME_SPACE=baca."
    for i in $(echo $MONGO_ADMIN_WORKERS | sed "s/,/ /g")
        do
           echo "Label $i with mongo-admin$KUBE_NAME_SPACE=baca"
           kubectl label nodes --overwrite $i mongo-admin$KUBE_NAME_SPACE=baca
        done
    echo
}



function getNFSServer() {
    #Get a list of worker IPs
    if [[ $PVCCHOICE == "1" ]]; then # This is the option 1 where the script will create everything for Internal usage.
        getWorkerIPBasedOnLabel
        #Create directories:
        echo "Creating required directory for SP by ssh into $NFS_IP"
        if [ -z "$SSH_USER" ]; then
           export SSH_USER="root"
        fi

        if [ "$SSH_USER" == "root" ]; then
            export SUDO_CMD=""
        else
            export SUDO_CMD="sudo "
        fi
        echo "Creating necessary folder in $NFS_IP..."
        ssh $SSH_USER@$NFS_IP -oStrictHostKeyChecking=no "$SUDO_CMD mkdir -p /exports/smartpages/$KUBE_NAME_SPACE/{logs,data,config}"
        ssh $SSH_USER@$NFS_IP -oStrictHostKeyChecking=no "$SUDO_CMD mkdir -p /exports/smartpages/$KUBE_NAME_SPACE/logs/{backend,frontend,callerapi,processing-extraction,pdfprocess,setup,interprocessing,classifyprocess-classify,ocr-extraction,postprocessing,reanalyze,updatefiledetail,spfrontend,redis,rabbitmq,mongo,mongoadmin,utf8process}"
        ssh $SSH_USER@$NFS_IP -oStrictHostKeyChecking=no "$SUDO_CMD mkdir -p /exports/smartpages/$KUBE_NAME_SPACE/config/backend"



        echo "Creating data directory on NFS ..."
        ssh $SSH_USER@$NFS_IP -oStrictHostKeyChecking=no "$SUDO_CMD mkdir -p /exports/smartpages/$KUBE_NAME_SPACE/data/{mongo,mongoadmin}"


         echo "Setting owner (51000:51001)  for BACA's PVC"
         ssh $SSH_USER@$NFS_IP -oStrictHostKeyChecking=no "$SUDO_CMD chown -R 51000:51001 /exports/smartpages/"




        echo "Checking to see if NFS server is installed..."
        if [[ $ICP_VERSION == "3.1.2" ]]; then
          ssh $SSH_USER@$NFS_IP "$SUDO_CMD systemctl status nfs-kernel-server"
            if [[ $? != "0" ]]; then
                echo "We could not find nfs service.  We will try to install nfs server"
                ssh $SSH_USER@$NFS_IP "$SUDO_CMD apt install nfs-kernel-server && $SUDO_CMD systemctl enable nfs-kernel-server && $SUDO_CMD systemctl restart nfs-kernel-server"

            fi
        fi
        if [[ $OCP_VERSION == "3.11" ]]; then
           ssh $SSH_USER@$NFS_IP "$SUDO_CMD systemctl status nfs-server"
            if [[ $? != "0" ]]; then
              echo "We could not find nfs service.  We will try to install nfs server"
              ssh $SSH_USER@$NFS_IP "$SUDO_CMD yum install nfs-utils && $SUDO_CMD systemctl enable nfs-server && $SUDO_CMD systemctl restart nfs-server"
            fi
        fi



        
        #We will backup the existing /etc/exports
        #Compare the icp worker ip w/ the existing IP in the /etc/exports file then insert any missing entry (IP) into /etc/exports.
        echo "ssh $SSH_USER@$NFS_IP "$SUDO_CMD cp /etc/exports /etc/exports_bak""
        ssh $SSH_USER@$NFS_IP "$SUDO_CMD cp /etc/exports /etc/exports_bak"
        export EXPORTS_FILE=`ssh $SSH_USER@$NFS_IP "$SUDO_CMD cat /etc/exports |grep '/exports/smartpages'" | awk '{print $2}' | cut -d'(' -f1`
        echo "from exports files: $EXPORTS_FILE"
        echo "from k8's : $WORKER_IP1s"

        #if [[ $? == "1" ]]; then

            echo "Inside writting to /etc/exports routine"
            echo $WORKER_IP1s

            for i in $WORKER_IP1s
            do

               echo $EXPORTS_FILE |grep $i
               if [[ $? == "1" ]]; then
                    echo $i
                   echo "Cannot find $i in the /etc/exports file....."
                   echo "Writing '/exports/smartpages "$i"(rw,sync,no_root_squash)' to $NFS_IP/etc/exports file"

                   ssh $SSH_USER@$NFS_IP "echo '/exports/smartpages "$i"(rw,sync,no_root_squash)' | $SUDO_CMD tee --append /etc/exports"
               else
                   echo " $i matched"
               fi

            done


        #restart nfs service if available$KUBE_NAME_SPACE/config
        if [[ $ICP_VERSION == "3.1.2" ]]; then
        ssh $SSH_USER@$NFS_IP "$SUDO_CMD systemctl restart nfs-kernel-server"
        fi
        if [[ $OCP_VERSION == "3.11" ]]; then
        ssh $SSH_USER@$NFS_IP "$SUDO_CMD systemctl restart nfs-server"
        fi


    else
        echo -e "\x1B[1;32mPVCCHOICE is not defined.  Therefore, you must create the following pvc name: \x1B[0m"
    fi # end if of pvc=1

}
function calMemoryLimitedDist(){

        echo -e "\x1B[1;32mChecking to see if bc package is installed\x1B[0m"
        dpkg -l | awk {'print $2'} |grep ^bc$ > /dev/null
        if [[ $? != "0" ]]; then
            echo "Installing bc package for resource calculation"
            apt install bc -y
        fi
        echo CALLERAPI_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.03 * 1024" | bc)Mi"
        echo BACKEND_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.04 * 1024" | bc)Mi"
        echo FRONTEND_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.03 * 1024" | bc)Mi"
        echo POST_PROCESS_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.03 * 1024" | bc)Mi"
        echo PDF_PROCESS_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.06 * 1024" | bc)Mi"
        echo UTF8_PROCESS_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.06 * 1024" | bc)Mi"
        echo SETUP_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.03 * 1024" | bc)Mi"
        echo OCR_EXTRACTION_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.09 * 1024" | bc)Mi"
        echo CLASSIFY_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.06 * 1024" | bc)Mi"
        echo PROCESSING_EXTRACTION_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.09 * 1024" | bc)Mi"
 #       echo INTER_PROCESSING_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.03 * 1024" | bc)Mi"
        echo REANALYZE_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.045 * 1024" | bc)Mi"
        echo UPDATEFILE_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.03 * 1024" | bc)Mi"
        echo RABBITMQ_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.06 * 1024" | bc)Mi"
#        echo MINIO_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.04 * 1024" | bc)Mi"
        echo REDIS_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.04 * 1024" | bc)Mi"
        echo MONGO_LIMITED_MEMORY="$(echo "$MONGO_SERVER_MEMORY  * 0.6 * 1024" | bc)Mi"
        echo MONGO_ADMIN_LIMITED_MEMORY="$(echo "$MONGO_ADMIN_SERVER_MEMORY * 0.6 * 1024" | bc)Mi"
        export mongo_memory_value="$(echo "$MONGO_SERVER_MEMORY  * 0.6 " | bc)"
        export mongo_admin_memory_value="$(echo "$MONGO_ADMIN_SERVER_MEMORY  * 0.6 " | bc)"


    export MONGO_WIREDTIGER_LIMIT="$(echo "($mongo_memory_value -1)*0.5" | bc)"

    if [[ 1 -eq $(echo "$MONGO_WIREDTIGER_LIMIT < 0.25" |bc -l) ]];then
         echo MONGO_WIREDTIGER_LIMIT='0.25'


    else
        echo "MONGO_WIREDTIGER_LIMIT=$MONGO_WIREDTIGER_LIMIT"

    fi

#    echo "mongo_admin_memory_value=$mongo_admin_memory_value"
    export MONGO_ADMIN_WIREDTIGER_LIMIT="$(echo "($mongo_admin_memory_value -1)*0.5" | bc)"

    if [[ 1 -eq $(echo "$MONGO_ADMIN_WIREDTIGER_LIMIT < 0.25" |bc -l) ]];then
         echo MONGO_ADMIN_WIREDTIGER_LIMIT='0.25'

    else
        echo "MONGO_ADMIN_WIREDTIGER_LIMIT=$MONGO_ADMIN_WIREDTIGER_LIMIT"
    fi

}

function calMemoryLimitedShared(){
        echo CALLERAPI_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.03 * 1024" | bc)Mi"
        echo BACKEND_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.04 * 1024" | bc)Mi"
        echo FRONTEND_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.03 * 1024" | bc)Mi"
        echo POST_PROCESS_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.03 * 1024" | bc)Mi"
        echo PDF_PROCESS_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.06 * 1024" | bc)Mi"
        echo UTF8_PROCESS_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.06 * 1024" | bc)Mi"
        echo SETUP_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.03 * 1024" | bc)Mi"
        echo OCR_EXTRACTION_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.09 * 1024" | bc)Mi"
        echo CLASSIFY_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.06 * 1024" | bc)Mi"
        echo PROCESSING_EXTRACTION_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.09 * 1024" | bc)Mi"
#        echo INTER_PROCESSING_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.03 * 1024" | bc)Mi"
        echo REANALYZE_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.045 * 1024" | bc)Mi"
        echo UPDATEFILE_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.03 * 1024" | bc)Mi"
        echo RABBITMQ_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.06 * 1024" | bc)Mi"
#        echo MINIO_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.04 * 1024" | bc)Mi"
        echo REDIS_LIMITED_MEMORY="$(echo "$SERVER_MEMORY * 0.04 * 1024" | bc)Mi"
        echo MONGO_LIMITED_MEMORY="$(echo "$MONGO_SERVER_MEMORY * 0.1 * 1024" | bc)Mi"
        export mongo_memory_value="$(echo "$MONGO_SERVER_MEMORY  * 0.1" | bc)"
        echo MONGO_ADMIN_LIMITED_MEMORY="$(echo "$MONGO_ADMIN_SERVER_MEMORY * 0.1 * 1024" | bc)Mi"
        export mongo_admin_memory_value="$(echo "$MONGO_ADMIN_SERVER_MEMORY  * 0.1" | bc)"

#    echo "mongo_memory_value=$mongo_memory_value"
    export MONGO_WIREDTIGER_LIMIT="$(echo "($mongo_memory_value -1)*0.5" | bc)"
    #echo "MONGO_WIREDTIGER_LIMIT=$MONGO_WIREDTIGER_LIMIT"
    if [[ 1 -eq $(echo "$MONGO_WIREDTIGER_LIMIT < 0.25" |bc -l) ]];then
         echo MONGO_WIREDTIGER_LIMIT='0.25'

    else
        echo "MONGO_WIREDTIGER_LIMIT=$MONGO_WIREDTIGER_LIMIT"
    fi

#    echo "mongo_admin_memory_value=$mongo_admin_memory_value"
    export MONGO_ADMIN_WIREDTIGER_LIMIT="$(echo "($mongo_admin_memory_value -1)*0.5" | bc)"
    #echo "MONGO_WIREDTIGER_LIMIT=$MONGO_WIREDTIGER_LIMIT"
    if [[ 1 -eq $(echo "$MONGO_WIREDTIGER_LIMIT < 0.25" |bc -l) ]];then
         echo MONGO_ADMIN_WIREDTIGER_LIMIT='.25'
    else
        echo "MONGO_ADMIN_WIREDTIGER_LIMIT=$MONGO_ADMIN_WIREDTIGER_LIMIT"
    fi

}
function calNumOfContainers(){
    if [[ $ICP_VERSION == "3.1.0" || $ICP_VERSION == "3.1.2" ]]; then  
        export numOfCelery=$(kubectl get nodes --show-labels |grep worker.*celery$KUBE_NAME_SPACE=baca | wc -l)
    fi
    if [[ $OCP_VERSION == "3.11" ]]; then 
        export numOfCelery=$(oc get nodes --show-labels |grep compute=true | grep celery$KUBE_NAME_SPACE=baca | wc -l)
    fi
    echo CELERY_REPLICAS=$numOfCelery
    echo NON_CELERY_REPLICAS=$numOfCelery

}
