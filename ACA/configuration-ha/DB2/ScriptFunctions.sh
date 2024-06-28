##
## Licensed Materials - Property of IBM
## 5737-I23
## Copyright IBM Corp. 2018 - 2022. All Rights Reserved.
## U.S. Government Users Restricted Rights:
## Use, duplication or disclosure restricted by GSA ADP Schedule
## Contract with IBM Corp.
##

function askForConfirmation(){
    while [[  $confirmation != "y" && $confirmation != "n" && $confirmation != "yes" && $confirmation != "no" ]] # While confirmation is not y or n...
    do
        echo
        echo -e "Would you like to continue (Y/N):"
        read confirmation
        confirmation=$(echo "$confirmation" | tr '[:upper:]' '[:lower:]')
    done

    if [[ $confirmation == "n" || $confirmation == "no" ]]
        then
        exit
    fi
}

DB2_QUERY_RESULT=
function run_db2cmd() {
    # Run DB2 query. The query result will be put to the global $DB2_QUERY_RESULT
    #
    # Usage:
    #   run_db2cmd <$query>
    # Note: this function must not be used with command substitution $(run_db2cmd) or `run_db2cmd`
    # command substitution runs in a separate shell and interrupts with DB2 connection in some linux.
    #
    # Arguments:
    #   $query - the query string to append in the db2 command.
    # Returns:
    #   The command exit code.
    # Query result:
    #   Get the query result from the global $DB2_QUERY_RESULT

    set -e

    DB2_QUERY_RESULT=
    local query=$1
    local output
    local rc
    local temp_output

    #echo "Running command: db2 -s -x \"$query\"" >&2

    # db2 command rc code:
    #   0 - success - Ok to continue
    #   1 - no row was selected - Ok to continue
    #   2 - warning - Ok to continue
    #   4 - DB2 or SQL error - should stop
    #   8 - System error - - should stop

    # Create a temp output file
    temp_output=$(mktemp)

    # Loose the error check for the db2 command as db2 returns rc=1 for empty result
    set +e

    # Run the db2 command and capture the output to the temp file
    db2 -s -x "$query" > $temp_output 2>&1
    rc=$?

    # Read the output in the temp file and clean it up
    output=$(cat $temp_output)
    rm -f $temp_output

    # Tighten up the error check
    set -e

    # Only errors out when the rc code from db2 command is greater than 2
    if [ $rc -gt 2 ]; then
        echo "$output" >&2
        return $rc
    fi

    # Set the output to the global variable
    DB2_QUERY_RESULT=$output
    return 0
}

function get_release_schema_version() {
    # Get the script release base version

    # If the user sets DB_SCHEMA_VERSION environment variable, return it directly. This is for dev and QA use only.
    set -e
    local release_schema_version=${DB_SCHEMA_VERSION}
    local sp_version_file
    if [ -z "$release_schema_version" ]; then
        # Try sp-version.json. This is the regular use case.
        sp_version_file="./sp-version.json"
        if [ ! -f "${sp_version_file}" ]; then
            # sp-version.json doesn't exist. Try release.env. This only works in dev environment.
            sp_version_file="../../release.env"
            if [ ! -f "${sp_version_file}" ]; then
                echo "ERROR: sp-version.json is missing" >&2
                return 1
            fi
        fi
        # Extract the value of DB_SCHEMA_VERSION from the file. Note that the input file could be a json file or an env file.
        release_schema_version=$(sed -n -r 's/^ *"?DB_SCHEMA_VERSION"?[=:] *"?([0-9.]+)"?/\1/p' $sp_version_file)
    fi
    if [ -z "${release_schema_version}" ]; then
        echo "ERROR: cannot read DB_SCHEMA_VERSION from ${sp_version_file}" >&2
        return 1
    fi
    echo ${release_schema_version}
}

function get_base_db_version() {
    # Get the base DB scheam version
    # Usage:
    #   get_base_db_version <$base_db_name> <$base_db_schema>
    # Arguments:
    #   base_db_name - the base DB name
    #   base_db_schema - the base DB schema. It should be the same as the db user
    # Returns:
    #   The schema version of the base DB.

    set -e

    local base_db_name=$1
    local base_db_schema=$2
    local schema_version

    run_db2cmd "connect to $base_db_name"
    run_db2cmd "set schema $base_db_schema"

    # Make sure the schema is correct
    run_db2cmd "SELECT 1 FROM SYSIBM.SYSTABLES WHERE TYPE='T' AND UPPER(CREATOR)='${base_db_schema^^}' AND UPPER(NAME)='TENANTINFO'"
    if [ -z "$DB2_QUERY_RESULT" ]; then
        echo "ERROR: cannot find base DB tables in database '${base_db_name}' schema '${base_db_schema}'." >&2
        return 1
    fi

    # Try to get the base DB SCHEMA_VERSION from BASE_OPTIONS table. The table is available since in 23.0.2.
    run_db2cmd "SELECT 1 FROM SYSIBM.SYSTABLES WHERE TYPE='T' AND UPPER(CREATOR)='${base_db_schema^^}' AND UPPER(NAME)='BASE_OPTIONS'"
    if [ -n "$DB2_QUERY_RESULT" ]; then
        run_db2cmd "SELECT SCHEMA_VERSION FROM BASE_OPTIONS"
        schema_version=$DB2_QUERY_RESULT
    fi
    if [ -z "$schema_version" ]; then
        # There's no BASE_OPTIONS table. We have to guess...
        schema_version=
        # Check OPT_FLAGS column in TENANTINFO table. OPT_FLAGS column was added on 21.0.3, and removed on 22.0.1.
        run_db2cmd "SELECT 1 FROM SYSCAT.COLUMNS WHERE UPPER(TABNAME)='TENANTINFO' AND UPPER(TABSCHEMA)='${base_db_schema^^}' AND UPPER(COLNAME)='OPT_FLAGS'"
        if [ -n "$DB2_QUERY_RESULT" ]; then
            # If it has this column, it must be 21.0.3.
            schema_version="21.0.3"
        fi

        if [ -z "$schema_version" ]; then
            # Check CONFIG column in TenantInfo. CONFIG was added since the beginning and was removed on 22.0.1, together with OPT_FLAGS.
            run_db2cmd "SELECT 1 FROM SYSCAT.COLUMNS WHERE UPPER(TABNAME)='TENANTINFO' AND UPPER(TABSCHEMA)='${base_db_schema^^}' AND UPPER(COLNAME)='CONFIG'"
            if [ -n "$DB2_QUERY_RESULT" ]; then
                # If CONFIG exists, it must be 21.0.1 or 21.0.2
                schema_version="21.0.2"
            fi
        fi

        if [ -z "$schema_version" ]; then
            # We know it doens't have BASE_OPTIONS table, which was added on 23.0.1, thus it must be 23.0.1
            schema_version="23.0.1"
        fi
    fi

    # Disconnect from the database
    run_db2cmd "connect reset"

    echo $schema_version
}

function get_tenant_db_version() {
    # Get the tenant (project) DB scheam version
    # Usage:
    #   get_tenant_db_version <$base_db_name> <$base_db_schema> <$tenant_db_name> <$tenant_db_schema>
    # Arguments:
    #   base_db_name - the base DB name
    #   base_db_schema - the base DB schema. It should be the same as the db user
    #   tenant_db_name - the tenant DB name matching the DBNAME colum in TenantInfo table. Note that it may be different from the TenantID
    #   tenant_db_schema - the tenant DB schema (i.e., ontology in the TenantInfo table)
    # Returns:
    #   The schema version of the tenant (project) DB.

    local base_db_name=$1
    local base_db_schema=$2
    local tenant_db_name=$3
    local tenant_db_schema=$4
    local schema_version

    run_db2cmd "connect to $base_db_name"
    run_db2cmd "set schema $base_db_schema"

    run_db2cmd "SELECT TENANTDBVERSION FROM TENANTINFO WHERE UPPER(DBNAME)='${tenant_db_name^^}' AND UPPER(ONTOLOGY)='${tenant_db_schema^^}'"
    schema_version=$DB2_QUERY_RESULT

    run_db2cmd connect reset

    if [ -z "${schema_version}" ]; then
        echo "ERROR: cannot find the record of tenant DB '${tenant_db_name}' ontology '${tenant_db_schema}' in base DB." >&2
        return 1
    fi

    echo $schema_version
}

function set_base_db_version() {
    # Sets the base DB scheam version
    # Usage:
    #   set_base_db_version <$base_db_name> <$base_db_schema> [$schema_version]
    # Arguments:
    #   base_db_name - the base DB name
    #   base_db_schema - the base DB schema. It should be the same as the db user
    #   schema_version (optional) - the schema version to set. If not provided, the version from get_release_schema_version will be used.

    set -e
    local base_db_name=$1
    local base_db_schema=$2
    local schema_version=$3

    if [ -z "$schema_version" ]; then
        schema_version=$(get_release_schema_version)
    fi

    run_db2cmd "connect to $base_db_name"
    run_db2cmd "set schema $base_db_schema"

    run_db2cmd "UPDATE base_options SET schema_version='${schema_version}'"

    run_db2cmd "connect reset"
}

function set_tenant_db_version() {
    # Sets the tenant (project) DB scheam version
    # Usage:
    #   set_tenant_db_version <$base_db_name> <$base_db_schema> <$tenant_db_name> <$tenant_db_schema> [$schema_version]
    # Arguments:
    #   base_db_name - the base DB name
    #   base_db_schema - the base DB schema. It should be the same as the db user
    #   tenant_db_name - the tenant DB name matching the DBNAME colum in TenantInfo table. Note that it may be different from the TenantID
    #   tenant_db_schema - the tenant DB schema (i.e., ontology in the TenantInfo table)
    #   schema_version (optional) - the schema version to set for this tenant (project). If not provided, the version from get_release_schema_version will be used.

    set -e
    local base_db_name=$1
    local base_db_schema=$2
    local tenant_db_name=$3
    local tenant_db_schema=$4
    local schema_version=$5

    if [ -z "$schema_version" ]; then
        schema_version=$(get_release_schema_version)
    fi

    run_db2cmd "connect to $base_db_name"
    run_db2cmd "set schema $base_db_schema"

    run_db2cmd "UPDATE TENANTINFO SET TENANTDBVERSION='${schema_version}', BACAVERSION='${schema_version}' WHERE UPPER(DBNAME)='${tenant_db_name^^}' AND UPPER(ONTOLOGY)='${tenant_db_schema^^}'"

    run_db2cmd "connect reset"
  
}

function get_upgrade_templates() {
    # List the SQL template to run
    # Usage:
    #   get_upgrade_templates <$prefix> <$from_version> <$to_version>
    # Arguments:
    #   prefix - the template prefix. It must be UpgradeBaseDB or UpgradeTenantDB
    #   from_version - the from portion of the template filename
    #   to_version - the to portion of the template filename
    # Returns:
    #   a sorted list of SQL templates to run

    set -e
    local prefix=$1
    local from_version=$2
    local to_version=$3
    local template_files=$(find ./sql/ -name "${prefix}_*.sql.template" | sort -n)
    local this_from
    local this_to
    local matched=false
    for template_file in $template_files; do
        if ! $matched; then
            this_from=$(echo $template_file | sed -r "s/.*${prefix}_([0-9.]+)_to_([0-9.]+)\.sql\.template/\1/")
            if [ "$this_from" == "$from_version" ]; then
                matched=true
            fi
        fi
        if $matched; then
            echo $template_file
            this_to=$(echo $template_file | sed -r "s/.*${prefix}_([0-9.]+)_to_([0-9.]+)\.sql\.template/\2/")
            if [ "$this_to" == "$to_version" ]; then
                break
            fi
        fi
    done
}

function run_base_db_upgrade_templates() {
    # Run the base DB sql templates. This function will connect to the database
    # Usage:
    #   run_base_db_upgrade_templates <$base_db_name> <$base_db_schema> <$template_files>
    # Arguments:
    #   base_db_name - the base database name
    #   base_db_schema - the base schema
    #   template_files - a list of template files to run

    set -e
    local base_db_name=$1
    local base_db_schema=$2
    local template_files=$3
    local rc

    run_db2cmd "connect to $base_db_name"
    run_db2cmd "set schema $base_db_schema"

    local template_file
    local this_version
    local last_version

    for template_file in $template_files; do
        # Track the versions
        if [ -z "$last_version" ]; then
            last_version=$(echo $template_file | sed -r "s/.+_([0-9.]+)_to_([0-9.]+)\.sql\.template/\1/")
        fi
        this_version=$(echo $template_file | sed -r "s/.+_([0-9.]+)_to_([0-9.]+)\.sql\.template/\2/")

        # Run the upgrade sql file
        echo ""
        echo "Running upgrade script: ${template_file}"
        set +e
        db2 -stvf "${template_file}"
        rc=$?
        set -e

        # Error handling
        if [ $rc -gt 2 ]; then
            echo ""
            echo "ERROR  : script ${template_file} failed with rc=${rc}."
            echo "CAUSE  : likely due to unexpected issues in base DB '$base_db_name' schame '$base_db_schema'."
            echo "STATUS : the base DB remains at version ${last_version}."
            echo "Recommendation: review the output above and fix any issues in the database, then re-run the upgrade."
            run_db2cmd "connect reset"
            return $rc
        fi

        # Commit the version upgrade in base DB if base_options table exists
        run_db2cmd "SELECT 1 FROM SYSIBM.SYSTABLES WHERE TYPE='T' AND UPPER(CREATOR)='${base_db_schema^^}' AND UPPER(NAME)='BASE_OPTIONS'"
        if [ -n "$DB2_QUERY_RESULT" ]; then
            run_db2cmd "UPDATE base_options SET schema_version='${this_version}'"
        fi
        last_version=$this_version
    done

    run_db2cmd "connect reset"
}

function run_tenant_db_upgrade_templates() {
    # Run the tenant DB sql templates. This function will connect to the database
    # Usage:
    #   run_tenant_db_upgrade_templates <$base_db_name> <$base_db_schema> <$tenant_db_name> <$tenant_db_schema> <$template_files>
    # Arguments:
    #   base_db_name - the base database name
    #   base_db_schema - the base schema
    #   tenant_db_name - the tenant db name
    #   tenant_db_schema - the tenant schema (ontology)
    #   template_files - a list of template files to run

    set -e
    local base_db_name=$1
    local base_db_schema=$2
    local tenant_db_name=$3
    local tenant_db_schema=$4
    local template_files=$5
    local rc

    local template_file
    local this_version
    local last_version

    for template_file in $template_files; do
        # Track the versions
        if [ -z "$last_version" ]; then
            last_version=$(echo $template_file | sed -r "s/.*_([0-9.]+)_to_([0-9.]+)\.sql\.template/\1/")
        fi
        this_version=$(echo $template_file | sed -r "s/.*_([0-9.]+)_to_([0-9.]+)\.sql\.template/\2/")

        # Connnect to the tenant DB
        run_db2cmd "connect to $tenant_db_name"
        run_db2cmd "set schema $tenant_db_schema"

        # Run the upgrade sql file
        echo ""
        echo "Running upgrade script: ${template_file}"
        set +e
        db2 -stvf "${template_file}"
        rc=$?
        run_db2cmd "connect reset"
        set -e

        # Error handling
        if [ $rc -gt 2 ]; then
            echo ""
            echo "ERROR  : script ${template_file} failed with rc=${rc}."
            echo "CAUSE  : likely due to unexpected issues in tenant DB '$tenant_db_name' schame '$tenant_db_schema'."
            echo "STATUS : the tenant DB remains at version ${last_version}."
            echo "Recommendation: review the output above and fix any issues in the database, then re-run the upgrade."
            return $rc
        fi

        # Commit the version upgrade in base DB
        set_tenant_db_version $base_db_name $base_db_schema $tenant_db_name $tenant_db_schema $this_version
        last_version=$this_version
    done

}
