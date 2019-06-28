#!/bin/bash

LVAR_SCRIPT_NAME="$(basename $0)"
LVAR_BAI_VERSION="3.1.0"
LVAR_MINIKUBE_VERSION="1.0.1"
LVAR_LOCALHOST_IP=""
LVAR_FORCE_MINIKUBE_VERSION="false"
LVAR_VM_DRIVER=""
LVAR_VBOX_NETWORKS=""

set -e

# Common script utilities
source ./utilities.sh

showHelp() {
    echo
    echo "--------------------------------------------------------------------------"
    echo "Installs a Business Automation Insights release on minikube."
    echo "--------------------------------------------------------------------------"
    echo "Prerequisites"
    echo "These files must be present in the same directory:"
    echo " - configuration/pv.yaml"
    echo " - configuration/bai-configmap.yaml"
    echo " - configuration/bai-psp.yaml"
    echo " - configuration/easy-install-kafka.yaml"
    echo " - configuration/easy-install.yaml"
    echo " - install-bai-minikube.sh"
    echo " - $LVAR_BAI_IMAGES"
    echo
    echo "--------------------------------------------------------------------------"
    echo "Arguments:"
    echo "  -e <event type>"
    echo "      Mandatory. The <event type> argument must have one of the following values:"
    echo "      - bpmn "
    echo "      - bawadv "
    echo "      - icm  "
    echo "      - odm "
    echo "      - content "
    echo "  -i <local machine IP address>"
    echo "      Optional. Needed only if the event emitter is not present on the local machine."
    echo "      Defaults to the value of \"minikube ip\"."
    echo "  -f"
    echo "      Optional. Bypasses the minikube version validation."
    echo
    echo "  -h: Displays this help."
    echo
    echo "Examples:"
    echo
    echo "  ./${LVAR_SCRIPT_NAME} -e odm"
    echo
    echo "---------------------------------------------------------------"
    exit 1
}
echo

purgeOldImages() {
    images=$(docker images | grep "bai-" | tr -s " " | cut -d " " -f 3)
    if [ ! -z "$images" ]; then
        echo "removing docker images $images"
        docker rmi -f $images
    else
        echo "No Docker images to remove."
    fi
}

installNewImages() {
    echo "Loading Business Automation Insights images"
    purgeOldImages
    tar xvf "$LVAR_BAI_IMAGES"
    cd images
    for f in *.tar.gz; do cat $f |  docker load ; done
    cd ..
}

disableVirtualBoxDHCP() {
    # this is supposed to work on both Win10/GitBash and OSx Mojave platforms.
    VBoxManage list dhcpservers > dhcpList.txt
    IP_MASK=$(minikube ip | cut -d "." -f -3)

    cat dhcpList.txt | grep NetworkName > names.txt
    cat dhcpList.txt | grep lowerIPAddress > ips.txt

    LVAR_MINIKUBE_NETWORK_NAME=$(awk 'BEGIN {OFS=" "}{
      getline line < "names.txt"
      print $0,line
    } ' ips.txt  | grep "$IP_MASK" | cut -d ":" -f 3 | tr -s " " | xargs)

    rm dhcpList.txt names.txt ips.txt
    VBoxManage dhcpserver modify --netname "$LVAR_MINIKUBE_NETWORK_NAME" --disable
    echo "Disabled DHCP server on VirtualBox network name: "$LVAR_MINIKUBE_NETWORK_NAME""
}

while getopts :e:d:h:i:f option;
do
    case ${option} in
        e)
            EVENT_PROCESSING_TYPE=$OPTARG
            echo "Event processing is for ${EVENT_PROCESSING_TYPE}"
            ;;
        h)
            showHelp
            ;;
        i)
            LVAR_LOCALHOST_IP=$OPTARG
            checkValidIP $LVAR_LOCALHOST_IP
            echo "Local machine IP address: $LVAR_LOCALHOST_IP"
            ;;
        f)
            LVAR_FORCE_MINIKUBE_VERSION="true"
            ;;
        d)
            LVAR_VM_DRIVER=$OPTARG
            echo "Use vm driver: ${LVAR_VM_DRIVER}"
            ;;
        \?)
            echo "Invalid option: -${OPTARG}"
            exit 1
            ;;
    esac
done
echo

if [ -z "${EVENT_PROCESSING_TYPE}" ]; then
    echo "ERROR: You must provide an event type to process...."
    showHelp
fi

if [ "${EVENT_PROCESSING_TYPE}" != "odm" -a  "${EVENT_PROCESSING_TYPE}" != "icm" -a "${EVENT_PROCESSING_TYPE}" != "bpmn" -a "${EVENT_PROCESSING_TYPE}" != "bawadv" -a "${EVENT_PROCESSING_TYPE}" != "content" ]; then
    echo "ERROR: This event type is invalid and cannot be processed: ${EVENT_PROCESSING_TYPE}"
    showHelp
fi

checkFileExist "./configuration/pv.yaml"
checkFileExist "./configuration/bai-configmap.yaml"
checkFileExist "./configuration/bai-psp.yaml"
checkFileExist "./configuration/easy-install-kafka.yaml"
checkFileExist "./configuration/easy-install.yaml"
checkFileExist "./install-bai-minikube.sh"
checkFileExist "./install-bai.sh"
checkFileExist "./$LVAR_BAI_IMAGES"

if [ "$LVAR_FORCE_MINIKUBE_VERSION" == "false" ]; then
    echo "Checking the minikube version."
    if echo "$(minikube version)" | grep "$LVAR_MINIKUBE_VERSION" > /dev/null; then
      echo "The minikube version is correct."
    else
      echo "The minikube version is NOT correct. Only version $LVAR_MINIKUBE_VERSION is supported. Exiting."
      echo "If you wish to skip this check, use the -f option."
      exit 1
    fi
else
    echo "You have chosen to use an unchecked version of minikube."
fi

echo "Creating the minikube machine"

if [ ! -z "$LVAR_VM_DRIVER" ]; then
    MINIKUBE_OPTS=" --vm-driver $LVAR_VM_DRIVER"
fi
minikube $MINIKUBE_OPTS start --cpus 2 --memory 6144

minikube docker-env --shell bash
eval $(minikube docker-env --shell bash)

# setting kafka communication address
if [ -z "$LVAR_LOCALHOST_IP" ]; then
    LVAR_LOCALHOST_IP="$(minikube ip)"
fi


minikube ssh "sudo mkdir -p /data/bai"
minikube ssh "sudo mkdir -p /data/bai-elasticsearch-data-1"
minikube ssh "sudo mkdir -p /data/bai-elasticsearch-master-1"
minikube ssh "sudo chmod -R 777 /data"

if command -v VBoxManage; then
    echo "Opening the Kafka communication port"
    VBoxManage controlvm "minikube" natpf1 "kafka service,tcp,,31090,,31090"
    disableVirtualBoxDHCP
else
    echo "Warning: VirtualBox does not exist. The Kafka communication port cannot be opened."
    echo "The event emitter must be hosted locally."
fi

installNewImages

./install-bai.sh -e "$EVENT_PROCESSING_TYPE" -i "$(minikube ip)" -j "$LVAR_LOCALHOST_IP" -p ./configuration/pv.yaml -c ./configuration/bai-configmap.yaml -s ./configuration/bai-psp.yaml -k ./configuration/easy-install-kafka.yaml -b ./configuration/easy-install.yaml
