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

# This script contains shared utility functions and environment variables.

function set_global_env_vars() {
    readonly unameOut="$(uname -s)"
    case "${unameOut}" in
        Linux*)     readonly machine="Linux";;
        Darwin*)    readonly machine="Mac";;
        *)          readonly machine="UNKNOWN:${unameOut}"
    esac

    if [[ "$machine" == "Mac" ]]; then
        SED_COMMAND='sed -i ""'
        SED_COMMAND_FORMAT='sed -i "" s/^M//g'
        YQ_CMD=${CUR_DIR}/helper/yq/yq_darwin_amd64
    else
        SED_COMMAND='sed -i'
        SED_COMMAND_FORMAT='sed -i s/\r//g'
        YQ_CMD=${CUR_DIR}/helper/yq/yq_linux_amd64
    fi
}

############################
# CLI installation utilities
############################

function validate_cli(){
    which oc &>/dev/null
    [[ $? -ne 0 ]] && \
        echo "Unable to locate Openshift CLI, please install it first." && \
        exit 1

    which ${YQ_CMD} &>/dev/null
    [[ $? -ne 0 ]] && \
        while true; do
            echo_bold "\"yq\" Command Not Found\n"
            echo_bold "Please download \"yq\" binary file from cert-kubernetes repo\n"
            exit 0
        done
    which timeout &>/dev/null
    [[ $? -ne 0 ]] && \
        while true; do
            echo_bold "\"timeout\" Command Not Found\n"
            echo_bold "The \"timeout\" will be installed automatically\n"
            echo_bold "Do you accept (Yes/No, default: No):"
            read -rp "" ans
            case "$ans" in
            "y"|"Y"|"yes"|"Yes"|"YES")
                install_timeout_cli
                break
                ;;
            "n"|"N"|"no"|"No"|"NO")
                echo -e "You do not accept, exiting...\n"
                exit 0
                ;;
            *)
                echo_red "You do not accept, exiting...\n"
                exit 0
                ;;
            esac
        done
}

function install_timeout_cli(){
    if [[ ${machine} = "Mac" ]]; then
        echo -n "Installing timeout..."; brew install coreutils >/dev/null 2>&1; sudo ln -s /usr/local/bin/gtimeout /usr/local/bin/timeout >/dev/null 2>&1; echo "done.";
    fi
    printf "\n"
}

function install_yq_cli(){
    if [[ ${machine} = "Linux" ]]; then
        echo -n "Downloading..."; curl -LO https://github.com/mikefarah/yq/releases/download/3.2.1/yq_linux_amd64  >/dev/null 2>&1; echo "done.";
        echo -n "Installing yq..."; sudo chmod +x yq_linux_amd64 >/dev/null; sudo mv yq_linux_amd64 /usr/local/bin/yq >/dev/null; echo "done.";
    else
        echo -n "Installing yq..."; brew install yq >/dev/null; echo "done.";
    fi
    printf "\n"
}


###################
# Echoing utilities
###################

function echo_bold() {
    # Echoes a message in bold characters
    echo_impl "${1}" "m"
}

function echo_red() {
    # Echoes a message in red bold characters
    echo_impl "${1}" ";31m"
}

function echo_impl() {
    # Echoes a message prefixed and suffixed by formatting characters
    local MSG=${1:?Missing message to echo}
    local PREFIX=${2:?Missing message prefix}
    #local SUFFIX=${3:?Missing message suffix}
    echo -e "\x1B[1${PREFIX}${MSG}\x1B[0m"
}

############################
# check OCP version
############################
function check_platform_version(){
    currentver=$(kubectl  get nodes | awk 'NR==2{print $5}')
    requiredver="v1.14.1"
    if [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" = "$requiredver" ]; then
        PLATFORM_VERSION="4.2OrLater"  
    else
        PLATFORM_VERSION="3.11"
    fi
}

set_global_env_vars
