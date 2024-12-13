#!/usr/bin/env bash

# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2023. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# This is an internal component, bundled with an official IBM product. 
# Please refer to that particular license for additional information. 

export check_cpfs_workdir=$(dirname "$(readlink -f "$BASH_SOURCE")")
export WORKTMP="/tmp"

source "${check_cpfs_workdir}"/output.sh

# Where groups of test cases can be found
CHECKS_ROOT=${CHECKS_ROOT:-${check_cpfs_workdir}/suites}

OUTPUT_FILENAME="results.json"

function main() {
    echo "This is the main function"
    pre_req
    create_json "${check_cpfs_workdir}/${OUTPUT_FILENAME}"
    parse_arguments "$@"

    # TODO: remove this block of comments for release. This is just for testing
    # and to show how to use the functions
    # create_json "${check_cpfs_workdir}/${OUTPUT_FILENAME}"
    # create_group "group1 test"
    # create_group "group2 test"
    # append_check "group1 test" "check3" "ok" "reason 1" ""
    # append_check "group1 test" "check1" "ok" "" ""
    # append_check "group1 test" "check3" "failed" "reason 2" ""
    # update_overall "group1 test" "ok"
    # update_overall "group2 test" "failed"
}

function pre_req() {
    if [ "$OPERATOR_NS" == "" ]; then
        echo "OPERATOR_NS is not set, use default namespace: ibm-common-services"
        echo "You can set OPERATOR_NS by using the following command 'export OPERATOR_NS=<namespace>' "
        export OPERATOR_NS="ibm-common-services"
    fi
}

function parse_arguments() {
    # process options
    if [[ "$@" != "" ]]; then
        case "$1" in
        --all | -a)
            run_checks 'all'
            ;;
        --groups | -g)
            run_checks 'groups' $2
            ;;
        --cases | -c)
            run_checks 'cases' $2
            ;;
        --ignore-groups | -ng)
            run_checks 'ignore_groups' $2
            ;;
        --ignore-cases | -nc)
            run_checks 'ignore_cases' $2
            ;;
        --output-file | -f)
            OUTPUT_FILENAME=$2
            ;;
        --help | -h)
            print_usage
            exit 0
            ;;
        *)
            print_usage
            exit 1
            ;;
        esac
    fi
}

function print_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} [OPTIONS]..."
    echo ""
    echo "Accepted cli arguments are:"
    echo -e "\t[--help|-h], prints this help."
    echo -e "\t[--all|-a], all cases will be ran."
    echo -e "\t[--groups|-g <groups>], the case groups should be like --groups='group1,group2'."
    echo -e "\t[--groups|-g -l], list the current supported groups."
    echo -e "\t[--ignore-groups|-ng <groups>], skip the cases groups, like -ng group1,group2."
    echo -e "\t[--cases|-c <cases>], the cases should be like --cases='case1,case2'."
    echo -e "\t[--cases|-c -l], list the current supported cases."
    echo -e "\t[--ignore-cases|-nc <cases>], skip the cases groups, like -nc case1,case2."
    echo -e "\t[--output-file|-f <string>], name to use for the output file. Default name is 'results.json'"
    echo ""
}

function run_checks() {

    declare -a bats_files
    declare -a test_groups
    declare -a ignore_cases
    declare -a not_run_groups
    declare -a not_run_cases

    if [[ $1 == 'all' ]]; then
        test_suites=$(ls ${CHECKS_ROOT})
        for group in $test_suites
        do 
            test_groups="$group $test_groups"
        done
    fi

    if [[ $1 == 'groups' ]]; then
        if [[ $2 == '-l' ]]; then
            echo "The supported groups are: "
            ls -1 ./suites
            exit 0
        else
            data=$2
            temp_data=`echo ${data//,/|}`
            for group in $temp_data
            do 
                test_groups="$group $test_groups"
            done
        fi
    fi

    if [[ $1 == 'cases' ]]; then
        if [[ $2 == '-l' ]]; then
            echo "The supported cases are: "
            find ./suites -name *.sh | awk -F '/' '{print $4}' | awk -F . '{print $1}'
            exit 0
        else
            data=$2
            temp_data=`echo ${data//,/|}`
            for case in $temp_data
            do 
                file_full_path=( $(ls ${CHECKS_ROOT}/*/${case}.sh) )
                group_name=$(basename $( dirname ${file_full_path} ))
                bash_files+=( $(ls ${CHECKS_ROOT}/*/${case}.sh) )
                bash "${CHECKS_ROOT}/${group_name}/${case}.sh"
            done
        fi
    fi

    if [[ $1 == 'ignore_groups' ]]; then
        data=$2
        temp_data=`echo ${data//,/|}`
        test_suites=$(ls ${CHECKS_ROOT} | egrep -v "$temp_data")
        not_run_groups=$temp_data
    fi

    if [[ $1 == 'ignore_cases' ]]; then
        data=$2
        test_suites=$(ls ${CHECKS_ROOT})
        temp_data=`echo ${data//,/|}`
        for nc in $temp_data
        do
            not_run_cases+=( $(ls ${CHECKS_ROOT}/*/${nc}.sh) )
        done

        for group in $test_suites; do
            test_groups="$group $test_groups"
        done
    fi

    # generate test list
    if [[ $1 != 'cases' ]]; then
        for group in ${test_groups[*]}; do
            for test in $(ls ${CHECKS_ROOT}/${group}/*.sh); do
                if [[ ${not_run_cases} ]]; then
                    for case in ${not_run_cases}; do
                        if [[ "${test}" != "${case}" ]]; then
                            bash_files+=( ${test} )
                            bash "${test}"
                        fi
                    done
                else
                    bash_files+=( ${test} )
                    bash "${test}"
                fi
            done
        done
    fi
}


main "$@"
