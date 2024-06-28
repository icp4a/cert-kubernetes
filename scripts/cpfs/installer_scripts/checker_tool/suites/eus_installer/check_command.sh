source "${check_cpfs_workdir}"/output.sh

function check_command() {
    local command=$1

    if [[ -z "$(command -v ${command} 2> /dev/null)" ]]; then
        append_check "eus_installer" "check ${command}" "failed" "${command} command not available" ""
        error "${command} command not available"
    else
        append_check "eus_installer" "check ${command}" "ok" "${command} command available" ""
        success "${command} command available"
    fi
}

create_group "eus_installer"
check_command "oc"
check_command "yq"
update_overall "eus_installer"

