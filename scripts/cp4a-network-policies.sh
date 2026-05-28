#!/bin/bash
#set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2025. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
separation_of_duties_flag=false
# This flag is control whether the Network Policy related tasks should be executed or not.
# For all namespaces , depending on the mode being executed we can exit or just skip tasks.
# For generate , install, delete modes, the script is being executed on its owned so we can safely exit.
# However for the other modes, they are called internally from the upgrade scripts and in that scenario we can not exit as that will end the upgrade script too
# instead this flag will get set to true, which means the remaining tasks will just skipped
# https://jsw.ibm.com/browse/DBACLD-201361
skip_network_policy_tasks=false

source ${CUR_DIR}/helper/network-policies/common_functions.sh

function show_help() {
    echo
    echo "Usage:"
    echo
    echo "cp4a-network-policies.sh -m [modeType] -n [cp4ba_namespace]"
    echo
    echo "Options:"
    echo
    echo "  -h  Display help"
    echo
    echo "  -m  Required: The valid mode types are: [generate], [install], [delete]" # [retrieveExisting] [removeRef] - are internal modes
    echo
    echo "  -n  Required: The target namespace of the CP4BA deployment."
    echo "                If CP4BA is deployed using separate namespaces for operators and operands/services, the value is the namespace where CP4BA operands/services are deployed."
    echo
    echo "Additional Information:"
    echo 
    echo "   STEP 1: Run the script in [generate] mode. This copies the sample network policy templates to folder [${CUR_DIR}/network-policies/<namespace>/templates]"
    echo "   STEP 2: Review and modify (if needed) the network policy templates based on your cluster environment."
    echo "   STEP 3: Apply the network policies in you cluster manually or optionally run the script in [install] mode to apply templates in the path [${CUR_DIR}/network-policies/<namespace>/templates]"
    echo
    echo "Note:"
    echo "If the existing deployment has been installed in \"All Namespaces\" on the cluster, generation or installation of network policies is not permitted for the deployment."
    echo  
  #  [delete] mode. Delete the installed network policy" 
  #  [retrieveExisting] mode. This functionality is only used internally for upgrade scenarios"
  #  [removeRef] mode. This functionality is only used internally for upgrade scenarios"
}


function parse_arguments() {
    # process options
    while [[ "$@" != "" ]]; do
        case "$1" in
        -m)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: -m requires an argument"
                exit 1
            fi
            RUNTIME_MODE=$1
            if [[ $RUNTIME_MODE == "generate" || $RUNTIME_MODE == "install" || $RUNTIME_MODE == "delete" || $RUNTIME_MODE == "retrieveExisting" || $RUNTIME_MODE == "removeRef" ]]; then
                echo
            else
                msg "Use a valid value: -m [generate] or [install] or [delete]"
                exit 1
            fi
            ;;
        -n)
            shift
            if [ -z $1 ]; then
                echo "Invalid option: -n requires an argument"
                exit 1
            fi
            TARGET_PROJECT_NAME=$1
            case "$TARGET_PROJECT_NAME" in
            "")
                printf '%b\n' "\x1B[1;31mEnter a valid namespace name, namespace name can not be blank\x1B[0m"
                exit 1
                ;;
            "openshift"*)
                printf '%b\n' "\x1B[1;31mEnter a valid project name, project name should not be 'openshift' or start with 'openshift' \x1B[0m"
                exit 1
                ;;
            "kube"*)
                printf '%b\n' "\x1B[1;31mEnter a valid project name, project name should not be 'kube' or start with 'kube' \x1B[0m"
                exit 1
                ;;
            *)
                # Check cluster login
                check_cluster_login
                # Check project name
                isProjExists=$($CLI_CMD get project $TARGET_PROJECT_NAME --ignore-not-found | wc -l)  >/dev/null 2>&1
                if [ $isProjExists -ne 2 ] ; then
                    printf '%b\n' "\x1B[1;31mInvalid project name \"$TARGET_PROJECT_NAME\", please set a existing project name.\x1B[0m"
                    exit 1
                fi
                : # Null command - validation passed, continue execution
                ;;
            esac
            ;;
        --kind)
        # This param is optional, and used to specify the kind of network policy to be retrieved in the 'retrieveExisting' mode
            shift
            if [ -z $1 ]; then
                echo "Invalid option: --kind requires an argument"
                exit 1
            fi
            KIND=$1
            ;;
        -h | --help | \?)
            show_help
            exit 0
            ;;
        *)
            echo "Invalid option"
            show_help
            exit 1
            ;;
        esac
        shift
    done
}


parse_arguments "$@"
if [[ -z "$RUNTIME_MODE" ]]; then
    printf '%b\n' "\x1B[1;31mPlease rerun command and include value for \"-m <MODE_TYPE>\" option.\n\x1B[0m"
    show_help
    exit 1
fi
if [[ -z "$TARGET_PROJECT_NAME" ]]; then
    printf '%b\n' "\x1B[1;31mPlease rerun command and include value for \"-n <CP4BA_NAMESPACE>\" option.\n\x1B[0m"
    show_help
    exit 1
fi

#Function to retrieve the operator and operand namespaces
set_operator_operand_namespaces "$TARGET_PROJECT_NAME"

# Call the Function that checks if the deployment has been deployed in "All Namespaces" and if so it will exit as that scenario is not supported
# https://jsw.ibm.com/browse/DBACLD-201361
if all_namespaces_check "$cp4ba_operators_namespace" "$cp4ba_services_namespace"; then
    error "The existing CP4BA deployment in the \"$TARGET_PROJECT_NAME\" namespace has been deployed as \"All namespaces\" in the cluster and the installation of network policies is not permitted for this type of deployment. The script will now terminate."
    # We can exit for generate , install and delete modes
    if [[ "$RUNTIME_MODE" == "generate" || "$RUNTIME_MODE" == "install" || "$RUNTIME_MODE" == "delete" ]]; then
        exit
    # Need a flag to skip the tasks for other modes . Because the other modes are called internally , we can not exit the script and just need to skip the network policy script tasks
    else
        skip_network_policy_tasks="true"
    fi
fi

### BEGIN - SETTING THE VARIABLES USED ###
# Based on the type of deployment we could have two namespaces to check for NPs to be installed in
# In the case of separation of duties there will be 2 namespaces and hence the file paths in operator where NPs are generated will be different
# The folders where we save the NPs will also be different, hence there are lists being created.
# in the scenario where separation of duties is not being used then there is only 1 namespace and related variables used 
namespaces_used=("$cp4ba_services_namespace" "$cp4ba_operators_namespace")
netpol_oper_path_list=("/tmp/${cp4ba_services_namespace}/network-policies" "/tmp/${cp4ba_operators_namespace}/network-policies")
netpol_targ_path_list=("${CUR_DIR}/network-policies/${cp4ba_services_namespace}" "${CUR_DIR}/network-policies/${cp4ba_operators_namespace}")
netpol_targ_log_path=network-policies/${cp4ba_services_namespace}/logs  # save_log function wants relative path

netpol_targ_template_path_list=()
for path in "${netpol_targ_path_list[@]}"; do
    netpol_targ_template_path_list+=("${path}/templates")
done

netpol_targ_existing_path_list=()
for path in "${netpol_targ_path_list[@]}"; do
    netpol_targ_existing_path_list+=("${path}/existing")
done

if [[ "$separation_of_duties_flag" == false ]]; then
    netpol_oper_path_list=("${netpol_oper_path_list[0]}")
    netpol_targ_template_path_list=("${netpol_targ_template_path_list[0]}")
    netpol_targ_existing_path_list=("${netpol_targ_existing_path_list[0]}")
    namespaces_used=("${namespaces_used[0]}")
fi

### END - SETTING THE VARIABLES USED ###

save_log "${netpol_targ_log_path}" "network-policy-log"
trap cleanup_log EXIT

#=======================================================================================================================
# Main
#=======================================================================================================================
# Retrieving network policy templates from the operator pods
if [[ "$RUNTIME_MODE" == "generate" ]]; then
 
    echo "${GREEN_TEXT}---------------------------------${RESET_TEXT}"
    echo "${GREEN_TEXT}Generate network policy templates${RESET_TEXT}"
    echo "${GREEN_TEXT}---------------------------------${RESET_TEXT}"
    echo
    echo "${RED_TEXT}IMPORTANT: ${YELLOW_TEXT}Before generating the network policy templates, please confirm you have set the property 'shared_configuration.sc_generate_sample_network_policies' to 'true' in your CP4BA custom resource and your CP4BA deployment has completed successfully. ${RESET_TEXT}"
    
    prompt_to_continue
    # Function takes in the list of operator paths where the NP templates could be stored and the local folder location where the templates will be stored in
    retrieve_network_policy_templates netpol_oper_path_list[@] netpol_targ_template_path_list[@]
    


fi

# Installing network policy from templates directory
if [[ "$RUNTIME_MODE" == "install" ]]; then
   echo "${RED_TEXT}IMPORTANT: ${YELLOW_TEXT}Before installing the network policy templates, please confirm that the network policies in the folder(s) $netpol_targ_template_path_list have been reviewed and updated to match your environment if necessary.${RESET_TEXT}"
        
    prompt_to_continue
    printf "\n"
    len="${#netpol_targ_template_path_list[@]}"
    # Loop through each potential local template folder to install the network policies
    for (( i=0; i<len; i++ )); do
        if [[ -d "${netpol_targ_template_path_list[$i]}" ]]; then
            echo "${GREEN_TEXT}---------------------------------${RESET_TEXT}"
            echo "${GREEN_TEXT}Installing network policy from templates from ${netpol_targ_template_path_list[$i]}${RESET_TEXT}"
            echo "${GREEN_TEXT}---------------------------------${RESET_TEXT}"
            echo
            install_delete_network_policies "apply" "${netpol_targ_template_path_list[$i]}" "${namespaces_used[$i]}"
        else
            echo
            warning "The script did not find any generated network policy templates in the folder ${netpol_targ_template_path_list[$i]}.This could either mean you must execute \"cp4a-network-policies.sh\" in the \"generate\" mode first or that all required network policy templates have been generated and saved in another folder. "
        fi
    done
    

fi

# Deleting network policy from templates directory
if [[ "$RUNTIME_MODE" == "delete" ]]; then
    echo "${RED_TEXT}IMPORTANT: ${YELLOW_TEXT}Please confirm that you want to delete the network policies from your cluster based on the network policy templates in the directory/directories $netpol_targ_template_path_list ${RESET_TEXT}"
    prompt_to_continue
    printf "\n"
    len="${#netpol_targ_template_path_list[@]}"
    # Loop through each potential local template folder to delete the network policies
    for (( i=0; i<len; i++ )); do
        if [[ -d "${netpol_targ_template_path_list[$i]}" ]]; then
            echo "${GREEN_TEXT}---------------------------------${RESET_TEXT}"
            echo "${GREEN_TEXT}Deleting network policy from templates from ${netpol_targ_template_path_list[$i]}${RESET_TEXT}"
            echo "${GREEN_TEXT}---------------------------------${RESET_TEXT}"
            echo
            install_delete_network_policies "delete" "${netpol_targ_template_path_list[$i]}" "${namespaces_used[$i]}"
        else
            echo
            warning "The script did not find any generated network policy templates in the folder ${netpol_targ_template_path_list[$i]}.This could either mean you must execute \"cp4a-network-policies.sh\" in the \"generate\" mode first or that all required network policy templates have been generated and saved in another folder. "
        fi
    done
    
fi


# This is internal mode where we retrieve the existing network policies as part of the upgrade process
# When this function is called, it needs the kind's name, namespace.
if [[ "$RUNTIME_MODE" == "retrieveExisting"  && ! -z "$KIND" && "$skip_network_policy_tasks" == "false" ]]; then
    len="${#netpol_targ_existing_path_list[@]}"
    for (( i=0; i<len; i++ )); do
        echo "${GREEN_TEXT}----------------------------------------------------------------------------------------------------------------------------------------${RESET_TEXT}"
        echo "${GREEN_TEXT}Retrieving existing network policies in namespace ${namespaces_used[$i]} from owned by "$KIND" and saving them to ${netpol_targ_existing_path_list[$i]} ${RESET_TEXT}"
        echo "${GREEN_TEXT}----------------------------------------------------------------------------------------------------------------------------------------${RESET_TEXT}"
        echo

        retrieve_existing_network_policies "$KIND" "${namespaces_used[$i]}" "${netpol_targ_existing_path_list[$i]}"
        # For CR Kind Content we need to retrieive NPs owned by Foundation CR
        #if [[ "$KIND" == "Content" ]]; then
        #    retrieve_existing_network_policies "Foundation" "${namespaces_used[$i]}" "${netpol_targ_existing_path_list[$i]}"
        #fi
        # For CR Kind ICP4ACluster we need to retrieive NPs owned by Content CR
        #if [[ "$KIND" == "ICP4ACluster" ]]; then
        #    retrieve_existing_network_policies "Content" "${namespaces_used[$i]}" "${netpol_targ_existing_path_list[$i]}"
        #fi
    done
fi


# This is internal mode where we remove the ownerReference the existing network policies as part of the upgrade process so that the operator will no longer own the network policies
# The retrievingExisting mode should be run first to get the existing network policies, then this function can be run to remove the ownerReference, then apply them to the cluster.
# When this function is called, it needs the location of the existing network policies
if [[ "$RUNTIME_MODE" == "removeRef" && "$skip_network_policy_tasks" == "false" ]]; then
    len="${#netpol_targ_existing_path_list[@]}"
    for (( i=0; i<len; i++ )); do
        echo "${GREEN_TEXT}---------------------------------${RESET_TEXT}"
        echo "${GREEN_TEXT}Removing ownerReference from ${netpol_targ_existing_path_list[$i]} and then re-applying them${RESET_TEXT}"
        echo "${GREEN_TEXT}---------------------------------${RESET_TEXT}"
        echo

        remove_owner_reference "${netpol_targ_existing_path_list[$i]}" "${namespaces_used[$i]}"
        if [[ $? -ne 0 ]]; then
            error " - Error: removing ownerReference from network policy files in ${netpol_targ_existing_path_list[$i]}."
            exit 1
        else
            install_delete_network_policies "replace" "${netpol_targ_existing_path_list[$i]}" "${namespaces_used[$i]}"
        fi
    done
    
fi