#!/bin/bash

checkFileExist() {
    if [ ! -f "$1" ]; then
        echo "ERROR: The $1 file must be present."
        exit 1
    fi
}

checkValidIP() {

# first testing IPV4 format
    test='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'

    if [[ $1 =~ ^$test\.$test\.$test\.$test$ ]]
    then
        echo "IP v4 is $1"
        ret=0
    else
        echo "$1 is not a valid IP v4, checking for IP v6."
        checkValidIPV6 $1
   fi
   return $ret
}

checkValidIPV6() {
    ipv6reg='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'
    var="$1"

    if [[ $var =~ $ipv6reg ]]; then
        echo "IP v6 is $1"
        ret=0
    else
        echo "$1 is not a valid IP v6, exiting."
        ret=1
    fi
   return $ret
}

check-es-config-versions() {
    MINIKUBE_CONFIF_MAP="configuration/bai-configmap.yaml"
    BAI_CONFIG_MAP="charts/ibm-business-automation-insights-dev/templates/bai-configmap.yaml"
    checkFileExist "$BAI_CONFIG_MAP"
    checkFileExist "$MINIKUBE_CONFIF_MAP"
    es_version_BAI=$(cat $BAI_CONFIG_MAP | grep es-config-version | cut -d ":" -f 2 | tr -s " " | xargs)
    es_version_MINIKUBE=$(cat $MINIKUBE_CONFIF_MAP | grep es-config-version | cut -d ":" -f 2 | tr -s " " | xargs)
    if [ ! "$es_version_BAI" == "$es_version_MINIKUBE" ]; then
        echo "Error: The check for the es-config version failed. The value of \"es-config-version\" in $MINIKUBE_CONFIF_MAP should be $es_version_BAI. Exiting..."
        minikube delete
        return 1
    else
        echo "The check for the es-config version passed."
    fi
}

LVAR_BAI_VERSION="3.1.0"
LVAR_SPRINT_VERSION="dev"
LVAR_BAI_IMAGES_SPRINT="ibm-bai-dev-$LVAR_BAI_VERSION-$LVAR_SPRINT_VERSION.tar.gz"
LVAR_BAI_IMAGES="ibm-bai-dev-$LVAR_BAI_VERSION-dev.tar.gz"
LVAR_BAI_CHARTS_SPRINT="charts/ibm-business-automation-insights-dev-$LVAR_BAI_VERSION-$LVAR_SPRINT_VERSION.tgz"
LVAR_BAI_CHARTS="charts/ibm-business-automation-insights-dev-$LVAR_BAI_VERSION.tgz"

expand-BAI-Charts() {
    # moving sprint charts into regular charts
    if [ -f "$LVAR_BAI_CHARTS_SPRINT" ]; then
        mv "$LVAR_BAI_CHARTS_SPRINT" "$LVAR_BAI_CHARTS"
    fi
    tar xvf "$LVAR_BAI_CHARTS" -C charts/
    check-es-config-versions
}


# moving sprint images into regular images
if [ -f "$LVAR_BAI_IMAGES_SPRINT" ]; then
    mv "$LVAR_BAI_IMAGES_SPRINT" "$LVAR_BAI_IMAGES"
fi

