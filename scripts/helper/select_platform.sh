
#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
# Copied from cp4a-deployment.sh but removed part useless functions.
# Used by loadimage.sh only for now

#################debug##########################
# DEPLOYMENT_TYPE="starter"
#################debug##########################

function select_platform(){
    printf "\n"
    echo -e "\x1B[1mSelect the cloud platform to deploy: \x1B[0m"
    COLUMNS=12
    if [ -z "$existing_platform_type" ]; then
        if [[ $DEPLOYMENT_TYPE == "starter" ]];then
            # echo -e "\x1B[1mOnly Openshift Container Platform (OCP) - Private Cloud is supported.\x1B[0m"
            # PLATFORM_SELECTED="OCP"
            # read -rsn1 -p"Press any key to continue";echo
            options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
            PS3='Enter a valid option [1 to 2]: '
        elif [[ $DEPLOYMENT_TYPE == "production" ]]
        then
            if [[ "${SCRIPT_MODE}" == "OLM" ]]; then
                options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
                PS3='Enter a valid option [1 to 2]: '
            else
                options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud" "Other ( Certified Kubernetes Cloud Platform / CNCF)")
                PS3='Enter a valid option [1 to 3]: '
            fi
        fi

        select opt in "${options[@]}"
        do
            case $opt in
                "RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud")
                    PLATFORM_SELECTED="ROKS"
                    use_entitlement="yes"
                    break
                    ;;
                "Openshift Container Platform (OCP) - Private Cloud")
                    PLATFORM_SELECTED="OCP"
                    use_entitlement="yes"
                    break
                    ;;
                "Other ( Certified Kubernetes Cloud Platform / CNCF)")
                    PLATFORM_SELECTED="other"
                    break
                    ;;
                *) echo "invalid option $REPLY";;
            esac
        done
    else
        if [[ $DEPLOYMENT_TYPE == "starter" ]];then
            # echo -e "\x1B[1mOnly Openshift Container Platform (OCP) - Private Cloud is supported.\x1B[0m"
            # PLATFORM_SELECTED="OCP"
            # read -rsn1 -p"Press any key to continue";echo
            options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
            options_var=("ROKS" "OCP")
        elif [[ $DEPLOYMENT_TYPE == "production" ]]
        then
            if [[ "${SCRIPT_MODE}" == "OLM" ]]; then
                options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud")
                options_var=("ROKS" "OCP")
            else
                options=("RedHat OpenShift Kubernetes Service (ROKS) - Public Cloud" "Openshift Container Platform (OCP) - Private Cloud" "Other ( Certified Kubernetes Cloud Platform / CNCF)")
                options_var=("ROKS" "OCP" "other")
            fi
        fi
        for i in ${!options_var[@]}; do
            if [[ "${options_var[i]}" == "$existing_platform_type" ]]; then
                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(Selected)"
            else
                printf "%1d) %s\n" $((i+1)) "${options[i]}"
            fi
        done
        echo -e "\x1B[1;31mExisting platform type found in CR: \"$existing_platform_type\"\x1B[0m"
        # echo -e "\x1B[1;31mDo not need to select again.\n\x1B[0m"
        read -rsn1 -p"Press any key to continue ...";echo
    fi

    if [[ "$PLATFORM_SELECTED" == "OCP" || "$PLATFORM_SELECTED" == "ROKS" ]]; then
        CLI_CMD=oc
    elif [[ "$PLATFORM_SELECTED" == "other" ]]
    then
        CLI_CMD=kubectl
    fi
}

select_platform
echo "Selected platform: $PLATFORM_SELECTED"