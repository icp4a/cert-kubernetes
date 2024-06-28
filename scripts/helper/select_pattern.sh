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
# DEPLOYMENT_TYPE="production"
#################debug##########################

function containsElement(){
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}
function select_pattern(){
# This function support mutiple checkbox, if do not select anything, it will return None

    PATTERNS_SELECTED=""
    choices_pattern=()
    pattern_arr=()
    pattern_cr_arr=()
    AUTOMATION_SERVICE_ENABLE=""
    AE_DATA_PERSISTENCE_ENABLE=""
    CPE_FULL_STORAGE=""


    if [[ "${PLATFORM_SELECTED}" == "other" ]]; then
        if [[ "${DEPLOYMENT_TYPE}" == "starter" ]];
        then
            options=("FileNet Content Manager" "Operational Decision Manager" "Automation Decision Services" "Business Automation Application" "Business Automation Workflow Authoring and Automation Workstream Services" "IBM Automation Document Processing")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow-workstreams" "document_processing")
            foundation_0=("BAN" "RR")                 # Foundation for FileNet Content Manager
            foundation_1=("BAN" "RR")                # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR" "UMS")     # Foundation for Automation Decision Services
            foundation_3=("RR" "UMS" "BAS")     # Foundation for Business Automation Applications (full)
            foundation_4=("RR" "UMS" "AE" "BAS")           # Foundation for Business Automation Workflow and workstreams(Demo)
            foundation_5=("BAN" "RR" "AE" "BAS" "UMS")  # Foundation for IBM Automation Document Processing
        else
            options=("FileNet Content Manager" "Operational Decision Manager" "Automation Decision Services" "Business Automation Application" "Business Automation Workflow" "(a) Workflow Authoring" "(b) Workflow Runtime" "Automation Workstream Services" "IBM Automation Document Processing" "(a) Development Environment" "(b) Runtime Environment")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow" "workflow-authoring" "workflow-runtime" "workstreams" "document_processing" "document_processing_designer" "document_processing_runtime")
            foundation_0=("BAN" "RR")                 # Foundation for FileNet Content Manager
            foundation_1=("BAN" "RR")                 # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR" "UMS")     # Foundation for Automation Decision Services
            foundation_3=("BAN" "RR" "UMS" "AE")     # Foundation for Business Automation Applications (full)
            foundation_4=("BAN" "RR")           # Foundation for dummy
            foundation_5=("BAN" "RR" "UMS" "BAS" "AE")           # Foundation for Business Automation Workflow - Workflow Authoring (5a)
            foundation_6=("BAN" "RR" "UMS" "AE")           # Foundation for Business Automation Workflow - Workflow Runtime (5b)
            foundation_7=("BAN" "RR" "UMS" "AE")           # Foundation for Automation Workstream Services (6)
            foundation_8=("BAN" "RR")  # Foundation for IBM Automation Document Processing
            foundation_9=("BAN" "RR" "AE" "BAS" "UMS")  # Foundation for IBM Automation Document Processing - 7a Development Environment
            foundation_10=("BAN" "RR" "AE" "UMS")  # Foundation for IBM Automation Document Processing - 7b Runtime Environment
            foundation_11=("BAN" "RR" "UMS" "AE")           # Foundation for Business Automation Workflow and workstreams(5b+6)
        fi
    else
        if [[ "${DEPLOYMENT_TYPE}" == "starter" ]];
        then
            options=("FileNet Content Manager" "Operational Decision Manager" "Automation Decision Services" "Business Automation Application" "Business Automation Workflow Authoring and Automation Workstream Services" "IBM Automation Document Processing")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow-workstreams" "document_processing")
            foundation_0=("BAN" "RR")                 # Foundation for FileNet Content Manager
            foundation_1=("BAN" "RR")                # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR")     # Foundation for Automation Decision Services
            foundation_3=("RR" "BAS")     # Foundation for Business Automation Applications (full)
            foundation_4=("RR" "AE" "BAS")           # Foundation for Business Automation Workflow and workstreams(Demo)
            foundation_5=("BAN" "RR" "AE" "BAS")  # Foundation for IBM Automation Document Processing
        else
            options=("FileNet Content Manager" "Operational Decision Manager" "Automation Decision Services" "Business Automation Application" "Business Automation Workflow" "(a) Workflow Authoring" "(b) Workflow Runtime" "Automation Workstream Services" "IBM Automation Document Processing" "(a) Development Environment" "(b) Runtime Environment")
            options_cr_val=("content" "decisions" "decisions_ads" "application" "workflow" "workflow-authoring" "workflow-runtime" "workstreams" "document_processing" "document_processing_designer" "document_processing_runtime")
            foundation_0=("BAN" "RR")                 # Foundation for FileNet Content Manager
            foundation_1=("BAN" "RR")                 # Foundation for Operational Decision Manager
            foundation_2=("BAN" "RR")     # Foundation for Automation Decision Services
            foundation_3=("BAN" "RR" "AE")     # Foundation for Business Automation Applications (full)
            foundation_4=("BAN" "RR")           # Foundation for dummy
            foundation_5=("BAN" "RR" "BAS" "AE")           # Foundation for Business Automation Workflow - Workflow Authoring (5a)
            foundation_6=("BAN" "RR" "AE")           # Foundation for Business Automation Workflow - Workflow Runtime (5b)
            foundation_7=("BAN" "RR" "AE")           # Foundation for Automation Workstream Services (6)
            foundation_8=("BAN" "RR")  # Foundation for IBM Automation Document Processing
            foundation_9=("BAN" "RR" "AE" "BAS")  # Foundation for IBM Automation Document Processing - 7a Development Environment
            foundation_10=("BAN" "RR" "AE")  # Foundation for IBM Automation Document Processing - 7b Runtime Environment
            foundation_11=("BAN" "RR" "AE")           # Foundation for Business Automation Workflow and workstreams(5b+6)
        fi   
    fi
    patter_ent_input_array=("1" "2" "3" "4" "5a" "5b" "5A" "5B" "6" "7a" "7b" "7A" "7B" "5b,6" "5B,6" "5b, 6" "5B, 6" "5b 6" "5B 6")
    tips1="\x1B[1;31mTips\x1B[0m:\x1B[1mPress [ENTER] to accept the default (None of the patterns is selected)\x1B[0m"
    tips2="\x1B[1;31mTips\x1B[0m:\x1B[1mPress [ENTER] when you are done\x1B[0m"
    pattern_starter_tips="\x1B[1mInfo: Except pattern (4/5), Business Automation Navigator will be automatically installed in the environment as it is part of the Cloud Pak for Business Automation foundation platform. \n\nTips:  After you make your first selection you will be able to make additional selections since you can combine multiple selections.\n\x1B[0m"
    pattern_custom_tips="\x1B[1mInfo: Business Automation Navigator will be automatically installed in the environment as it is part of the Cloud Pak for Business Automation foundation platform. \n\nTips:  After you make your first selection you will be able to make additional selections since you can combine multiple selections.\n\x1B[0m"
    baw_iaws_tips="\x1B[1mInfo: Note that Business Automation Workflow Authoring (5a) cannot be installed together with Automation Workstream Services (6). However, Business Automation Workflow Runtime (5b) can be installed together with Automation Workstream Services (6).\n\x1B[0m"
    linux_starter_tips="\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31mIBM Automation Document Processing (6) does NOT support a cluster running a Linux on Z (s390x)/Power architecture.\n\x1B[0m"
    linux_custom_tips="\x1B[33;5mATTENTION: \x1B[0m\x1B[1;31mIBM Automation Document Processing (7a/7b) does NOT support a cluster running a Linux on Z (s390x)/Power architecture.\n\x1B[0m"    
    indexof() {
        i=-1
        for ((j=0;j<${#options_cr_val[@]};j++));
        do [ "${options_cr_val[$j]}" = "$1" ] && { i=$j; break; }
        done
        echo $i
    }
    menu() {
        clear
        echo -e "\x1B[1mSelect the Cloud Pak for Business Automation capability to install: \x1B[0m"
        for i in ${!options[@]}; do
            if [[ $DEPLOYMENT_TYPE == "starter" ]];then
                containsElement "${options_cr_val[i]}" "${EXISTING_PATTERN_ARR[@]}"
                retVal=$?
                if [ $retVal -ne 0 ]; then
                    printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                else
                    if [[ "${choices_pattern[i]}" == "(To Be Uninstalled)" ]]; then
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                    else
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(Installed)"
                    fi
                fi
            elif [[ $DEPLOYMENT_TYPE == "production" ]]
            then
                containsElement "${options_cr_val[i]}" "${EXISTING_PATTERN_ARR[@]}"
                retVal=$?
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") ]]; then
                    wwVal=0
                elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" && " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" ]]; then
                    wwVal=1
                fi
                containsElement "baw_authoring" "${EXISTING_OPT_COMPONENT_ARR[@]}"
                baw_authoring_Val=$?
                containsElement "document_processing_designer" "${EXISTING_OPT_COMPONENT_ARR[@]}"
                document_processing_designer_Val=$?
                containsElement "document_processing_runtime" "${EXISTING_OPT_COMPONENT_ARR[@]}"
                document_processing_runtime_Val=$?
                if [[ $retVal -ne 0 ]]; then
                    case "$i" in
                    "7") # for Automation Workstream Services
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" 6 "${options[i]}"  "${choices_pattern[i]}"
                        ;;
                    "8")
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "${choices_pattern[i]}"
                        printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                        printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                        ;;
                    "4") # 5 for Workflow Authoring, 6 for Workflow Runtime
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                        printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                        printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                        ;;
                    "0"|"1"|"2"|"3")
                        printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                        ;;
                    esac
                else
                    if [[ "${choices_pattern[i]}" == "(To Be Uninstalled)" ]]; then
                        case "$i" in
                        "7") # for Automation Workstream Services
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" 6 "${options[i]}"  "${choices_pattern[i]}"
                            ;;
                        "4") # 5 for Workflow Authoring, 6 for Workflow Runtime
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                            printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                            printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            ;;
                        "0"|"1"|"2"|"3"|"4")
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                            ;;
                        "8") # 9 for Development Environment, 10 for Runtime Environment,
                            # if [[ "${choices_pattern[i+1]}" == "(Selected)" || "${choices_pattern[i+2]}" == "(Selected)" ]]; then
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "${choices_pattern[i]}"
                            printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                            printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            ;;
                        esac
                    else
                        case "$i" in
                        "7") # for Automation Workstream Services
                            if [[ (${choices_pattern[6]} == "(To Be Uninstalled)" && ${choices_pattern[7]} == "(To Be Uninstalled)") ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" 6 "${options[i]}"  "${choices_pattern[i]}"
                            else
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" 6 "${options[i]}"  "(Installed)"
                            fi
                            ;;
                        "4") # 5 for Workflow Authoring, 6 for Workflow Runtime
                            if [[ ${choices_pattern[6]} == "(To Be Uninstalled)" && ${choices_pattern[7]} == "(To Be Uninstalled)" && ${choices_pattern[5]} == "" ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(To Be Uninstalled)"
                                if [[ $baw_authoring_Val -eq 0 ]]; then
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                                else
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                                fi
                            elif [[ ${choices_pattern[6]} == "(To Be Uninstalled)" && ${choices_pattern[7]} == "(To Be Uninstalled)" && ${choices_pattern[5]} == "(Selected)" ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "${choices_pattern[i]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            elif [[ $baw_authoring_Val -eq 0 && ${choices_pattern[5]} == "(To Be Uninstalled)" && ${choices_pattern[6]} != "" ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"   "${choices_pattern[i]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"   "${choices_pattern[i+1]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            elif [[ $baw_authoring_Val -eq 0 && ${choices_pattern[5]} == "(To Be Uninstalled)" && ${choices_pattern[6]} == "" ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"   "(To Be Uninstalled)"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"   "${choices_pattern[i+1]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            else
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"   "(Installed)"
                                if [[ $baw_authoring_Val -eq 0 ]]; then
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "(Installed)"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                                else
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "(Installed)"
                                fi
                            fi
                            ;;
                        "0"|"1"|"2"|"3")
                            printf "%1d) %s \x1B[1m%s\x1B[0m\n" $((i+1)) "${options[i]}"  "(Installed)"
                            ;;
                        "8")
                            if [[ ${choices_pattern[9]} == "" && ${choices_pattern[10]} == "" ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "(Installed)"
                                if [[ $document_processing_designer_Val -eq 0 ]]; then
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "(Installed)"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i]}"
                                elif [[ $document_processing_runtime_Val -eq 0 ]]
                                then
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i]}"
                                    printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "(Installed)"
                                fi
                            elif [[ (${choices_pattern[9]} == "(To Be Uninstalled)" && ${choices_pattern[10]} == "(Selected)") || (${choices_pattern[9]} == "(Selected)" && ${choices_pattern[10]} == "(To Be Uninstalled)") ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "(Selected)"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            elif [[ (${choices_pattern[8]} == "(Selected)" && ${choices_pattern[9]} == "(To Be Uninstalled)") || (${choices_pattern[8]} == "(Selected)" && ${choices_pattern[10]} == "(To Be Uninstalled)") ]]; then
                                printf "%1d) %s \x1B[1m%s\x1B[0m\n" 7 "${options[i]}"  "(To Be Uninstalled)"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+1]}"  "${choices_pattern[i+1]}"
                                printf "%s \x1B[1m%s\x1B[0m\n" "   ${options[i+2]}"  "${choices_pattern[i+2]}"
                            fi
                            ;;
                        esac
                   fi
                fi
            fi
        done
        if [[ "$msg" ]]; then echo "$msg"; fi
        printf "\n"
        if [[ $DEPLOYMENT_TYPE == "production" ]]; then
            echo -e "${baw_iaws_tips}"
        fi
        
        if [[ $DEPLOYMENT_TYPE == "production" ]]; then
            echo -e "${pattern_custom_tips}"
            echo -e "${linux_custom_tips}"
        else
            echo -e "${pattern_starter_tips}"
            echo -e "${linux_starter_tips}"
        fi       
        # Show different tips according components select or unselect
        containsElement "(Selected)" "${choices_pattern[@]}"
        retVal=$?
        if [ $retVal -ne 0 ]; then
            echo -e "${tips1}"
        else
            echo -e "${tips2}"
        fi
# ##########################DEBUG############################
#     for i in "${!choices_pattern[@]}"; do
#         printf "%s\t%s\n" "$i" "${choices_pattern[$i]}"
#     done
# ##########################DEBUG############################
    }

    if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
        prompt="Enter a valid option [1 to ${#options[@]}]: "
    elif [[ $DEPLOYMENT_TYPE == "production" ]]
    then
        prompt="Enter a valid option [1 to 4, 5a, 5b, 6, 7a, 7b]: "
    fi

    while menu && read -rp "$prompt" num && [[ "$num" ]]; do
        if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
            [[ "$num" != *[![:digit:]]* ]] &&
            (( num > 0 && num <= ${#options[@]} )) ||
            { msg="Invalid option: $num"; continue; }
            ((num--));
        elif [[ $DEPLOYMENT_TYPE == "production" ]]
        then
            containsElement "${num}" "${patter_ent_input_array[@]}"
            inputretVal=$?
            [[ "${inputretVal}" -eq 0 ]] ||
            { msg="Invalid option: $num"; continue; }
            case "$num" in
            "5a"|"5A")
                num=5
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") ]]; then
                    choices_pattern[6]=""
                    choices_pattern[7]=""
                elif [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" || " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && (${choices_pattern[6]} == "" || ${choices_pattern[7]} == "") ]]; then
                    choices_pattern[5]="(Selected)"
                elif [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime") && (" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && (${choices_pattern[6]} == "(To Be Uninstalled)") && (${choices_pattern[7]} == "(To Be Uninstalled)") ]]; then
                    num=5
                elif [[ (" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring") && ${choices_pattern[5]} == "(To Be Uninstalled)" && (${choices_pattern[6]} == "(Selected)" || ${choices_pattern[7]} == "(Selected)") ]]; then
                    num=5
                fi
                ;;
            "5b"|"5B")
                num=6
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") ]]; then

                    choices_pattern[5]=""
                elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" && " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" && ${choices_pattern[5]} == "(Selected)" ]]; then

                    choices_pattern[6]=""
                elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring" ]]; then
                        if [[ ${choices_pattern[5]} == "(To Be Uninstalled)" ]]; then

                            num=6
                        elif [[ ${choices_pattern[5]} == "(Selected)" || ${choices_pattern[5]} == "" ]]; then
                            choices_pattern[6]="(Selected)"
                            # choices_pattern[7]=""
                        fi
                fi
                ;;
            6)
                num=7
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") ]]; then
                    choices_pattern[5]=""
                elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring" ]]; then
                        if [[ ${choices_pattern[5]} == "(To Be Uninstalled)" ]]; then
                            num=7
                        elif [[ ${choices_pattern[5]} == "(Selected)" || ${choices_pattern[5]} == "" ]]; then
                            choices_pattern[7]="(Selected)"
                            # choices_pattern[7]=""
                        fi
                fi
                ;;
            "5b,6"|"5B,6"|"5b, 6"|"5B, 6"|"5b 6"|"5B 6")
                num=11
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow") ]]; then
                    choices_pattern[5]=""
                else
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring" || ${choices_pattern[5]} == "" ]]; then
                        choices_pattern[6]="(Selected)"
                        choices_pattern[7]="(Selected)"
                    fi
                fi
                ;;
            "1"|"2"|"3"|"4")
                ((num--))
                ;;
            "7a"|"7A")
                num=9
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") ]]; then
                    choices_pattern[10]=""
                else
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing" && " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer" && ${choices_pattern[10]} == "" ]]; then
                        num=9
                    elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing" && " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer" && ${choices_pattern[10]} == "(Selected)" ]]; then
                        choices_pattern[9]=""
                        choices_pattern[8]=""
                    elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing" && " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_runtime" && ${choices_pattern[10]} == "" ]]; then
                        choices_pattern[9]="(Selected)"
                    fi
                fi
                ;;
            "7b"|"7B")
                num=10
                if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing") ]]; then
                    choices_pattern[9]=""
                else
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing" && " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_runtime" && ${choices_pattern[9]} == "" ]]; then
                        num=10
                    elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing" && " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_runtime" && ${choices_pattern[9]} == "(Selected)" ]]; then
                        choices_pattern[10]=""
                        choices_pattern[8]=""
                    elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "document_processing" && " ${EXISTING_OPT_COMPONENT_ARR[@]} " =~ "document_processing_designer" && ${choices_pattern[9]} == "" ]]; then
                        choices_pattern[10]="(Selected)"
                    fi
                fi
                ;;
            esac
        else
            echo "Deployment type is invalid"
            exit 0
        fi
        containsElement "${options_cr_val[num]}" "${EXISTING_PATTERN_ARR[@]}"
        retVal=$?
        containsElement "baw_authoring" "${EXISTING_OPT_COMPONENT_ARR[@]}"
        baw_authoring_Val=$?
        if [[ !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime") && !(" ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams") ]]; then
            wwVal=0
        elif [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" && " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" ]]; then
            wwVal=1
        fi

        if [[ $retVal -ne 0 ]]; then
            if [[ ($num -eq 11) && ($wwVal -eq 0) ]]; then
                [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(Selected)"
                [[ "${choices_pattern[num]}" ]] && choices_pattern[4]="(Selected)" || choices_pattern[4]=""
                [[ "${choices_pattern[num]}" ]] && choices_pattern[6]="(Selected)" || choices_pattern[6]=""
                [[ "${choices_pattern[num]}" ]] && choices_pattern[7]="(Selected)" || choices_pattern[7]=""
            elif [[ ($num -eq 11) && ($wwVal -eq 1) ]]; then
                if [[ ${choices_pattern[4]} == "(Selected)" && ${choices_pattern[5]} == "(Selected)" ]]; then
                    choices_pattern[6]="(To Be Uninstalled)"
                    choices_pattern[7]="(To Be Uninstalled)"
                    choices_pattern[11]="(To Be Uninstalled)"
                else
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[4]="(To Be Uninstalled)" || choices_pattern[4]=""
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[6]="(To Be Uninstalled)" || choices_pattern[6]=""
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[7]="(To Be Uninstalled)" || choices_pattern[7]=""
                fi
            else
                [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(Selected)"
            fi
            if [[ $DEPLOYMENT_TYPE == "production" ]]; then
                if [[ ${choices_pattern[5]} == "(Selected)" || ${choices_pattern[6]} == "(Selected)"  ]]; then
                    choices_pattern[4]="(Selected)"
                fi
                if  [[ "${choices_pattern[5]}" == "" && "${choices_pattern[6]}" == "" ]]; then
                    choices_pattern[4]=""
                fi
                if [[ ${choices_pattern[9]} == "(Selected)" || ${choices_pattern[10]} == "(Selected)"  ]]; then
                    choices_pattern[8]="(Selected)"
                fi
                if  [[ "${choices_pattern[9]}" == "" && "${choices_pattern[10]}" == "" ]]; then
                    choices_pattern[8]=""
                fi
            fi
        else
            if [[ $DEPLOYMENT_TYPE == "starter" ]]; then
                [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
            elif [[ $DEPLOYMENT_TYPE == "production" ]]
            then
                case "$num" in
                "5")
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-authoring" && ("${choices_pattern[6]}" == "(Selected)" || "${choices_pattern[7]}" == "(Selected)") ]]; then
                        choices_pattern[num]="(To Be Uninstalled)"
                    else
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num-1]="" || choices_pattern[num-1]="(To Be Uninstalled)"
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    fi
                    ;;
                "6")
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" && "${choices_pattern[7]}" == "(To Be Uninstalled)" ]]; then
                        if [[ "${choices_pattern[5]}" == "" ]]; then
                            if [[ choices_pattern[num]="(To Be Uninstalled)" ]]; then
                                choices_pattern[num]="(To Be Uninstalled)"
                            else
                                choices_pattern[num]=""
                            fi
                        elif [[ "${choices_pattern[5]}" == "(Selected)" ]]; then
                            choices_pattern[num]="(To Be Uninstalled)"
                        fi

                        # choices_pattern[num-2]="(Installed)"
                    elif  [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workstreams" && "${choices_pattern[7]}" == "" && " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" && "${choices_pattern[6]}" == "" ]]; then
                        choices_pattern[num]=""
                    else
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num-2]="" || choices_pattern[num-2]="(To Be Uninstalled)"
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    fi
                    ;;
                "7")
                    if [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" && "${choices_pattern[6]}" == "(To Be Uninstalled)" ]]; then
                        if [[ "${choices_pattern[5]}" == "" ]]; then
                            if [[ choices_pattern[num]="(To Be Uninstalled)" ]]; then
                                choices_pattern[num]="(To Be Uninstalled)"
                            else
                                choices_pattern[num]=""
                            fi
                        elif [[ "${choices_pattern[5]}" == "(Selected)" ]]; then
                            choices_pattern[num]="(To Be Uninstalled)"
                        fi

                        # choices_pattern[num-2]="(Installed)"
                    elif  [[ " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow-runtime" && "${choices_pattern[7]}" == "" && " ${EXISTING_PATTERN_ARR[@]} " =~ "workflow" && "${choices_pattern[6]}" == "" ]]; then
                        choices_pattern[num]=""
                    else
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    fi
                    ;;
                "9")
                    if [[ ${choices_pattern[10]} == "(Selected)" ]]; then
                        choices_pattern[8]="(Selected)"
                    else
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num-1]="" || choices_pattern[num-1]="(To Be Uninstalled)"
                    fi
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    ;;
                "10")
                    if [[ ${choices_pattern[9]} == "(Selected)" ]]; then
                        choices_pattern[8]="(Selected)"
                    else
                        [[ "${choices_pattern[num]}" ]] && choices_pattern[num-2]="" || choices_pattern[num-2]="(To Be Uninstalled)"
                    fi
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    ;;
                "0"|"1"|"2"|"3")
                    [[ "${choices_pattern[num]}" ]] && choices_pattern[num]="" || choices_pattern[num]="(To Be Uninstalled)"
                    ;;
                esac
            fi
        fi
    done

    # echo "choices_pattern: ${choices_pattern[*]}"
    # read -rsn1 -p"Press any key to continue (DEBUG MODEL)";echo
    # Generate list of the pattern which will be installed or To Be Uninstalled
    for i in ${!options[@]}; do
        array_varname=foundation_$i[@]
        containsElement "${options_cr_val[i]}" "${EXISTING_PATTERN_ARR[@]}"
        retVal=$?
        if [ $retVal -ne 0 ]; then
            [[ "${choices_pattern[i]}" ]] && { pattern_arr=( "${pattern_arr[@]}" "${options[i]}" ); pattern_cr_arr=( "${pattern_cr_arr[@]}" "${options_cr_val[i]}" ); msg=""; }
            [[ "${choices_pattern[i]}" ]] && { foundation_component_arr=( "${foundation_component_arr[@]}" "${!array_varname}" ); }
        else
            if [[ "${choices_pattern[i]}" == "(To Be Uninstalled)" ]]; then
                pos=`indexof "${pattern_cr_arr[i]}"`
                if [[ "$pos" != "-1" ]]; then
                { pattern_cr_arr=(${pattern_cr_arr[@]:0:$pos} ${pattern_cr_arr[@]:$(($pos + 1))}); pattern_arr=(${pattern_arr[@]:0:$pos} ${pattern_arr[@]:$(($pos + 1))}); }

                fi
            else
                { pattern_arr=( "${pattern_arr[@]}" "${options[i]}" ); pattern_cr_arr=( "${pattern_cr_arr[@]}" "${options_cr_val[i]}" ); msg=""; }
                { foundation_component_arr=( "${foundation_component_arr[@]}" "${!array_varname}" ); }
            fi
        fi
    done
    # echo -e "$msg"

    # 4Q: add workflow-workstream into pattern list when select both workflow-runtime and workstream
    if [[ " ${pattern_cr_arr[@]} " =~ "workflow" && " ${pattern_cr_arr[@]} " =~ "workstreams" && "${DEPLOYMENT_TYPE}" == "production" ]]; then
        pattern_cr_arr=( "${pattern_cr_arr[@]}" "workflow-workstreams" )
        foundation_ww=("BAN" "RR" "UMS" "AE")
        foundation_component_arr=( "${foundation_component_arr[@]}" "${foundation_ww[@]}" )
    fi

    if [ "${#pattern_arr[@]}" -eq "0" ]; then
        PATTERNS_SELECTED="None"
        printf "\x1B[1;31mPlease select one pattern at least, exiting... \n\x1B[0m"
        exit 1
    else
        PATTERNS_SELECTED=$( IFS=$','; echo "${pattern_arr[*]}" )
        PATTERNS_CR_SELECTED=$( IFS=$','; echo "${pattern_cr_arr[*]}" )

    fi
    if [[ "$DEPLOYMENT_TYPE" == "production" ]]; then
        # select_ae_data_persistence
        AUTOMATION_SERVICE_ENABLE="No"
    fi
    # select_cpe_full_storage
    FOUNDATION_CR_SELECTED=($(echo "${foundation_component_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    x=0;while [ ${x} -lt ${#FOUNDATION_CR_SELECTED[*]} ] ; do FOUNDATION_CR_SELECTED_LOWCASE[$x]=$(tr [A-Z] [a-z] <<< ${FOUNDATION_CR_SELECTED[$x]}); let x++; done
    FOUNDATION_DELETE_LIST=($(echo "${FOUNDATION_CR_SELECTED[@]}" "${FOUNDATION_FULL_ARR[@]}" | tr ' ' '\n' | sort | uniq -u))

    PATTERNS_CR_SELECTED=($(echo "${pattern_cr_arr[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
}

select_pattern
echo -e "Selected patterns: $PATTERNS_SELECTED \n"