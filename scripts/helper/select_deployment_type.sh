
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

function select_deployment_type(){
    printf "\n"

    if [[ "$SCRIPT_MODE" == "OLM" ]]
    then
        DEPLOYMENT_TYPE="production"
        echo -e "An enterprise deployment will be prepared for the OCP Catalog."
        # read -rsn1 -p"Press any key to continue ...";echo
        # options=("Starter")
        # PS3='Enter a valid option [1 to 1]: '
        # select opt in "${options[@]}"
        # do
        #     case $opt in
        #         "Starter")
        #             DEPLOYMENT_TYPE="starter"
        #             break
        #             ;;
        #         *) echo "invalid option $REPLY";;
        #     esac
        # done
    else
        echo -e "\x1B[1mWhat type of deployment is being performed?\x1B[0m"

        COLUMNS=12
        options=("Starter" "Production")
        if [ -z "$existing_deployment_type" ]; then
            PS3='Enter a valid option [1 to 2]: '
            select opt in "${options[@]}"
            do
                case $opt in
                    "Starter")
                        DEPLOYMENT_TYPE="starter"
                        break
                        ;;
                    "Production")
                        DEPLOYMENT_TYPE="production"
                        break
                        ;;
                    *) echo "invalid option $REPLY";;
                esac
            done
        else
            options_var=("starter" "production")
            for i in ${!options_var[@]}; do
                if [[ "${options_var[i]}" == "$existing_deployment_type" ]]; then
                    printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(Selected)"
                else
                    printf "%1d) %s\n" $((i+1)) "${options[i]}"
                fi
            done
            echo -e "\x1B[1;31mExisting deployment type found in CR: \"$existing_deployment_type\"\x1B[0m"
            # echo -e "\x1B[1;31mDo not need to select again.\n\x1B[0m"
            read -rsn1 -p"Press any key to continue ...";echo
        fi
    fi
}

select_deployment_type
echo "Selected deployment type: $DEPLOYMENT_TYPE"