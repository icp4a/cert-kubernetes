#!/bin/bash
##################################################################
# Licensed Materials - Property of IBM
#  5737-I23
#  Copyright IBM Corp. 2024. All Rights Reserved.
#  U.S. Government Users Restricted Rights:
#  Use, duplication or disclosure restricted by GSA ADP Schedule
#  Contract with IBM Corp.
##################################################################
# Author: Tamilanban Rajendran <tamilanban.rajendran@ibm.com>
# Co-Authors: Infant Sabin <infant.sabin.a@ibm.com> Philippe Kaplan <kaplanph@fr.ibm.com>
# Description: The following script retrieves all indices, mappings and aliases from Elasticsearch, restores them in OpenSearch and validates the document count of the OpenSearch index against Elasticsearch to ensure the successful migration of data
# Elasticsearch and OpenSearch credentials
export ELASTICSEARCH_URL
export OPENSEARCH_URL
export ELASTIC_USERNAME
export ELASTIC_PASSWORD
export OPENSEARCH_USERNAME
export OPENSEARCH_PASSWORD

# Function to check if required environment variables are set
checkEnvVars() {
    local vars=("ELASTICSEARCH_URL" "OPENSEARCH_URL" "ELASTIC_USERNAME" "ELASTIC_PASSWORD" "OPENSEARCH_USERNAME" "OPENSEARCH_PASSWORD")
    for var in "${vars[@]}"; do
    if [[ -n "${!var}" ]]; then
        continue
    else
        echo "Error: $var should not be empty."
        usage
    fi
    done
    # quick test *-search servers and jq
    curl -X GET --fail -u "$OPENSEARCH_USERNAME:$OPENSEARCH_PASSWORD" --insecure "$OPENSEARCH_URL/"
    curl -X GET --fail -u "$ELASTIC_USERNAME:$ELASTIC_PASSWORD" --insecure "$ELASTICSEARCH_URL/"
    jq --version
}

# Function to print usage
usage() {
    echo "Usage: $0 [-dryrun] [-doc_count] [-include=<comma separated indices>] [-exclude=<comma separated indices>] [-include_regex=<comma separated regex patterns>] [-exclude_regex=<comma separated regex patterns>] [-startdate=<start date>] [-enddate=<end date>] [-timestamp_key=<date field key>] [-delete] [logfile] [--help]"
    echo "Options:"
    echo "  -dryrun                                   List of indices of elastic and displaying dry run steps"
    echo "  -doc_count                                List all indices of elastic and opensearch with document count, and exit."
    echo "  -include=<comma separated indices>        List of indices to include"
    echo "  -exclude=<comma separated indices>        List of indices to exclude"
    echo "  -include_regex=<regex pattern>            List of regex pattern to include indices"
    echo "  -exclude_regex=<regex pattern>            List of regex pattern to exclude indices"
    echo "  -startdate=<start date>                   Start date for data migration (format: 'YYYY-MM-DDTHH:MM:SS')"
    echo "  -enddate=<end date>                       End date for data migration (format: 'YYYY-MM-DDTHH:MM:SS')"
    echo "  -timestamp_key=<key>                      Key for date values (default: 'timestamp')"
    echo "  -delete                                   delete Opensearch indices"
    echo "  logfile                                   Optional: Log file to save migration summary"
    echo "  --help                                    Display usage details"
}

function parseArgs() {
    # Parse command line arguments
    logfile=""
    timestamp="timestamp"
    dryrun=false
    include_indices=""
    exclude_indices=""
    include_regex=""
    exclude_regex=""
    dryrun=false
    deleteIndices=false
    report="Summary:"
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -timestamp_key=*)
                timestamp="${1#*=}"
                ;;
            -dryrun)
                dryrun=true
                ;;
            -include=*)
                include_indices="${1#*=}"
                ;;
            -exclude=*)
                exclude_indices="${1#*=}"
                ;;
            -include_regex=*)
                include_regex="${1#*=}"
                ;;
            -exclude_regex=*)
                exclude_regex="${1#*=}"
                ;;
            -startdate=*)
                START_DATE="${1#*=}"
                ;;
            -enddate=*)
                END_DATE="${1#*=}"
                ;;
            -doc_count)
                indexCount
                exit 0
                ;;
            -delete)
                deleteIndices=true
                ;;
            --help)
                usage
                exit 0
                ;;
            -*) 
                # option is not recognized 
                usage
                exit 1
                ;;
            *)
                logfile=$1
                shift
                ;;
        esac
        shift
    done
}

# "macros" to simplify code reading
function curlPUT() {
     curl -s -X PUT -u "${OPENSEARCH_USERNAME}:${OPENSEARCH_PASSWORD}" --insecure --url "${OPENSEARCH_URL}/$1" -H 'Content-Type: application/json' -d "$2"
}
function curlPOST() {
     curl -s -X POST -u "${OPENSEARCH_USERNAME}:${OPENSEARCH_PASSWORD}" --insecure --url "${OPENSEARCH_URL}/$1" -H 'Content-Type: application/json' -d "$2"
}
function curlGET() {
     curl -s -X GET -u "${OPENSEARCH_USERNAME}:${OPENSEARCH_PASSWORD}" --insecure --url "${OPENSEARCH_URL}/$1" -H 'Content-Type: application/json'
}
function curlDELETE() {
     curl -s -X DELETE -u "${OPENSEARCH_USERNAME}:${OPENSEARCH_PASSWORD}" --insecure --url "${OPENSEARCH_URL}/$1" 
}

# check progress, using task API
function checkProgress() {
    # $1 is index
    # $2 is task id
    local completion response total created message
    echo "Migration status for index: $1"
    response=$(curlGET "_tasks/$2")
    completion=$(jq -r ".completed" <<< "$response")
    created=$(jq -r ".task.status.created" <<< "$response")
    while [ "${completion}" == 'false' ]; do 
      sleep 5
      response=$(curlGET "_tasks/$2")
      completion=$(jq -r ".completed" <<< "$response")
      created=$(jq -r ".task.status.created" <<< "$response")
      total=$(jq -r ".task.status.total" <<< "$response")
      if [[ "$created" != "0" ]]; then
          echo -ne "Copied documents/total: ${created}/${total}             \r"
      fi
    done
    # migration done 
    if [[ "$created" == "0" ]]; then
         echo "No Document to copy."
         printf -v report '%s\n%s\n' "${report}" "Migration of $1 skipped (no document). Task ID: $2"
    else
      total=$(jq -r ".task.status.total" <<< "$response")
      local tookMS=$(jq -r ".response.took" <<< "$response")
      message="Migration of $1: ${created} documents in ${tookMS}ms ($(( 1000*created/(tookMS+1) )) documents/s). Task ID: $2"
      printf -v report '%s\n%s\n' "${report}" "${message}"
      echo -e "\nDone.\n${message}"
    fi
}

# Function to migrate aliases for an index from Elasticsearch to OpenSearch
function migrate_aliases() {
  source_index="$1"
  dest_index="$2"

  if $dryrun; then
        echo "Processing alias:"
        local action="{
                \"actions\": [
                {
                    \"add\": {
                    \"index\": \"${dest_index}\",
                    \"alias\": \"${alias_name}\"
                    }
                }
                ]
            }"
       echo "curl -X POST -u OPENSEARCH_USERNAME:OPENSEARCH_PASSWORD --insecure OPENSEARCH_URL/_aliases -H 'Content-Type: application/json' -d '${action}'"
       return 0
   fi
  # Migrate aliases from Elasticsearch to OpenSearch
  aliases=$(curl -s -X GET -u "$ELASTIC_USERNAME:$ELASTIC_PASSWORD" --insecure "$ELASTICSEARCH_URL/${source_index}")

  # Extract and migrate aliases using jq
  alias_names=$(echo "$aliases" | jq -r '.[].aliases | keys[]')


  for alias_name in $alias_names; do
    echo "Processing alias: $alias_name"
    curlPOST "_aliases" "
        {
            \"actions\": [
            {
                \"add\": {
                \"index\": \"${dest_index}\",
                \"alias\": \"${alias_name}\"
                }
            }
            ]
        }"
  done
}

# Function to perform bulk reindexing with retry and capture index summary
function bulk_reindex_with_retry() {
  reindex_request="$1"
  index="$2"
  retries=3
  retry_delay=5
  response=""

  for ((attempt = 1; attempt <= retries; attempt++)); do
    if $dryrun; then
        echo "curl -s -X POST -u OPENSEARCH_USERNAME:OPENSEARCH_PASSWORD --insecure OPENSEARCH_URL/_reindex?wait_for_completion=false -H 'Content-Type: application/json' -d ${reindex_request}"
        return 0
    else
        curlPUT "${index}/_settings" '{"index":{"refresh_interval":"-1","number_of_replicas":0}}' >>/dev/null
        response=$(curlPOST "_reindex?wait_for_completion=false" "$reindex_request")
        # Check if reindexing request was successful
        if [ $? -eq 0 ]; then
            # Check if the response contains any error message
            error=$(echo "$response" | jq -r '.error')
            if [ "$error" != "null" ]; then
                echo "Reindexing attempt $attempt failed for index $index: $error. Retrying in $retry_delay seconds..."
                sleep $retry_delay
            else
                echo "${response}"
                taskID=$(echo "$response" | jq -r '.task')
                return 0
            fi
        else
            echo "Reindexing attempt $attempt failed for index $index. Retrying in $retry_delay seconds..."
            sleep $retry_delay
        fi
    fi
  done

  # All retry attempts failed
  echo "Maximum number of retries exceeded for index $index. Reindexing failed."
  migration_reason+=("Maximum number of retries exceeded")
  return 1
}
# Function to include indices based on regex pattern
function include_indices_regex() {
    # transform regex to accept  multi pattern
    local regex="(${1//,/|})"
    shift
    local indices_array=("$@")
    local included_indices=()
    # Iterate through each index in the indices array
    for index in "${indices_array[@]}"; do
        # Check if the index matches the regex pattern
        if [[ "$index" =~ $regex ]]; then
            included_indices+=("$index")
        fi
    done
    # Return the array of included indices
    echo "${included_indices[@]}"
}

function indexCount() {
    echo "Elasticsearch document count:"
    curl -s -X GET -u "$ELASTIC_USERNAME:$ELASTIC_PASSWORD" --insecure "$ELASTICSEARCH_URL/_cat/indices?format=json" | \
      jq -r '.[] | "The index \(.index) has \(.["docs.count"]) document(s)."'
    echo
    echo "Opensearch document count:"
    curlGET "_cat/indices?format=json" | \
      jq -r '.[] | "The index \(.index) has \(.["docs.count"]) document(s)."'
}

function getIndices() { 
    local server
    # Fetch all indices from Elasticsearch (or OS, if deleting)
    if $deleteIndices ;then
      all_indices=$(curlGET "_cat/indices" | awk '{print $3}' | tr '\n' ',' | sed 's/,$//')
      server=Opensearch
    else
      all_indices=$(curl -s -X GET -u "$ELASTIC_USERNAME:$ELASTIC_PASSWORD" --insecure "$ELASTICSEARCH_URL/_cat/indices" | awk '{print $3}' | tr '\n' ',' | sed 's/,$//')
      server=Elasticsearch
    fi
    # Convert comma-separated indices to an array
    IFS=',' read -ra SOURCE_INDICES <<< "$all_indices"

    echo "All indices fetched from $server:"
    echo "$all_indices"

    # Check if -include_indices is provided
    if [[ -n $include_indices ]]; then
        # Convert comma-separated include_indices to an array
        IFS=',' read -r -a include_indices_array <<< "$include_indices"
        
        # Initialize an empty array to store valid included indices
        valid_included_indices=()

        # Iterate through each index specified with -include_indices
        for include_index in "${include_indices_array[@]}"; do
            # Flag to track if the include_index was found
            found=false
            
            # Iterate through each index in the list of all indices
            for index in "${SOURCE_INDICES[@]}"; do
                # Check if the include_index matches the current index
                if [[ $index == "$include_index" ]]; then
                    # If the include_index exists, add it to the list of valid included indices
                    valid_included_indices+=("$include_index")
                    found=true
                    break
                fi
            done

            # Check if the include_index was not found in the list of all indices
            if [[ $found == false ]]; then
                # Print a warning message
                echo "Warning: Index '$include_index' specified with -include_indices does not exist in Elasticsearch."
            fi
        done

        # Set SOURCE_INDICES to valid_included_indices
        SOURCE_INDICES=("${valid_included_indices[@]}")
    fi

    # Check if -include_regex is provided
    if [[ -n $include_regex ]]; then
        filtered_indices_array=($(include_indices_regex "$include_regex" "${SOURCE_INDICES[@]}"))
        # Set SOURCE_INDICES to valid_included_indices
        SOURCE_INDICES=("${filtered_indices_array[@]}")
    fi

    # Check if -exclude_indices is provided
    if [[ -n $exclude_indices ]]; then
        # Convert comma-separated exclude_indices to an array
        IFS=',' read -r -a exclude_indices_array <<< "$exclude_indices"

        # Iterate through each index specified with -exclude_indices
        for exclude_index in "${exclude_indices_array[@]}"; do
            # Flag to track if the exclude_index was found
            found=false

            # Iterate through each index in the list of all indices
            for ((i = 0; i < ${#SOURCE_INDICES[@]}; i++)); do
                index=${SOURCE_INDICES[i]}
                # Check if the exclude_index matches the current index
                if [[ $index == "$exclude_index" ]]; then
                    # If the exclude_index exists, remove it from the list of SOURCE_INDICES
                    unset 'SOURCE_INDICES[i]'
                    found=true
                    echo "Excluded $index"
                    break
                fi
            done

            # Check if the exclude_index was not found in the list of all indices
            if [[ $found == false ]]; then
                # Print a warning message
                echo "Warning: Index '$exclude_index' specified with -exclude_indices does not exist in Elasticsearch."
            fi
        done
    fi

    # Check if -exclude_regex is provided
    if [[ -n $exclude_regex ]]; then
        # Iterate through each index in the list of all indices
        # exclude all indices starting with '.'
        excl="(^\.|${exclude_regex//,/|})"
    else 
        excl="^\."
    fi
    for index in "${SOURCE_INDICES[@]}"; do
        # Check if the index matches the regex pattern
        if [[ $index =~ $excl ]]; then
            # If the index matches, remove it from the list of SOURCE_INDICES
            SOURCE_INDICES=("${SOURCE_INDICES[@]/$index}")
            echo "Excluded $index"
        fi
    done

    # Remove empty values from the SOURCE_INDICES array
    filtered_indices=()
    for index in "${SOURCE_INDICES[@]}"; do
        if [[ -n "$index" ]]; then
            filtered_indices+=("$index")
        fi
    done

    # Assign the filtered indices back to SOURCE_INDICES
    SOURCE_INDICES=("${filtered_indices[@]}")
}

function createDestIndices() {
    # Create destination indices with prefix "<cloudpak>-eos-"
    DEST_INDICES=()
    for source_index in "${SOURCE_INDICES[@]}"; do
    # verify index is open
    status=$(curl -s -X GET -u "$ELASTIC_USERNAME:$ELASTIC_PASSWORD" --insecure "$ELASTICSEARCH_URL/_cat/indices/${source_index}" | awk '{print $2}')
    if [[ "$status" == "close" ]]; then
        echo "Index ${source_index} is closed on Elasticssearck. Skipping."
        continue
    fi
    # Get settings from Elasticsearch
    settings=$(curl -s -X GET -u "$ELASTIC_USERNAME:$ELASTIC_PASSWORD" --insecure "$ELASTICSEARCH_URL/$source_index/_settings")

    # Filter and extract the settings object
    filtered_settings=$(echo "$settings" | jq '.[] | { settings: .settings | del(.index.creation_date, .index.uuid, .index.version, .index.provided_name) }')
    parsed_settings=$(echo "$filtered_settings" | jq -r '.settings')

    # Get mappings from Elasticsearch
    mappings=$(curl -s -X GET -u "$ELASTIC_USERNAME:$ELASTIC_PASSWORD" --insecure "$ELASTICSEARCH_URL/$source_index/_mappings")

    # Filter and extract the mappings object
    filtered_mappings=$(echo "$mappings" | jq '.[].mappings|del(..|.omit_norms?)')

    dest_index="${source_index}"

    printf "\nCreating index %s with same mappings and settings than Elasticsearch\n" "$dest_index"

    # Create index in OpenSearch with mappings
    if $dryrun; then
        echo "curl -X PUT -u OPENSEARCH_USERNAME:OPENSEARCH_PASSWORD --insecure OPENSEARCH_URL/dest_index -H Content-Type: application/json -d {
        settings:  parsed_settings,
        mappings:  filtered_mappings
        }"
    else
        # Execute the curl to create settings based on Elasticsearch
        curl -s -X GET --fail -u "${OPENSEARCH_USERNAME}:${OPENSEARCH_PASSWORD}" --insecure --url "${OPENSEARCH_URL}/$dest_index" -o /dev/null || \
        curlPUT "$dest_index" '{
        "settings": '"$parsed_settings"',
        "mappings": '"$filtered_mappings"'
        }'
    fi

    DEST_INDICES+=("$dest_index")
    done
}

function reindex() {
    # Perform bulk reindex for each index present in Elasticsearch
    for ((i=0; i<${#SOURCE_INDICES[@]}; i++)); do
    # Print index information for debugging
    printf "\nProcessing index: %s\n" "${SOURCE_INDICES[i]}"
    # Construct reindexing request
    if [[ -n ${START_DATE} || -n ${END_DATE} ]]; then
            # Reindexing request with time range
            endDateLine=""
            if [[ -n "${END_DATE}" ]]; then
            endDateLine=",\"lt\": \"${END_DATE}\""
            fi
            query=",\"query\": {
                \"range\": {
                    \"${timestamp}\": {
                    \"gte\": \"${START_DATE:=0}\"
                    ${endDateLine}
                    }
                } }"
    fi
    reindex_request="{
            \"source\": {
            \"remote\": {
                \"host\": \"$ELASTICSEARCH_URL\",
                \"username\": \"$ELASTIC_USERNAME\",
                \"password\": \"$ELASTIC_PASSWORD\"
            },
            \"index\": \"${SOURCE_INDICES[i]}\"
            ${query}
            },
            \"dest\": {
                \"index\": \"${DEST_INDICES[i]}\"
            }
        }"
    # Execute bulk reindexing with retry
    bulk_reindex_with_retry "$reindex_request" "${DEST_INDICES[i]}"
    if $dryrun; then
        echo "Dryrun -- skipping reindex step."
    else
        checkProgress "${DEST_INDICES[i]}" "${taskID}"
        # reset index refresh and replicas, and refresh
        curlPUT "${index}/_settings" '{"index":{"refresh_interval":null,"number_of_replicas":null}}' > /dev/null
        curlGET "${index}/_refresh" > /dev/null
    fi
    done
}

function doDeleteIndices () {
  if [[ "${#SOURCE_INDICES[@]}" == 0 ]]; then
    # empty list
    echo "No index to delete."
  else
    read -r -p "Delete these indices? [y/N]" -n 1
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        printf -v indexList '%s,' "${SOURCE_INDICES[@]}"
        curlDELETE "${indexList%,}"
    else
        echo "Delete canceled."
    fi
  fi
}

function main() {
    # Start time for total migration
    total_start=$(date +%s)
    parseArgs "$@"
    checkEnvVars

    getIndices
    # Print the list of indices
    printf "\nIndices to process:\n"
    printf '%s\n' "${SOURCE_INDICES[@]}"
    if $deleteIndices ;then
        doDeleteIndices
        # refresh all, just in case
        curlGET "_refresh" > /dev/null
    else
        # normal reindex process 
        createDestIndices
        # reindexing
        reindex_start=$(date +%s)
        reindex
        reindex_end=$(date +%s)
        reindex_time=$((reindex_end - reindex_start))

        # Migrate aliases for each index
        for ((i=0; i<${#SOURCE_INDICES[@]}; i++)); do
        # Print index information for debugging
        printf "\nMigrating aliases for %s \n" "${SOURCE_INDICES[i]}"
        migrate_aliases "${SOURCE_INDICES[i]}" "${DEST_INDICES[i]}"
        done
        # refresh all, just in case
        curlGET "_refresh" > /dev/null
        # End time for total migration
        total_end=$(date +%s)
        total_time=$((total_end - total_start))
        printf "\n%sDocument transfer time: %s seconds\nTotal Script Execution Time: %s seconds\n" "${report}" "$reindex_time" "$total_time"
        if [[ -n "$logfile" ]]; then
        printf "\n%sDocument transfer time: %s seconds\nTotal Script Execution Time: %s seconds\n" "${report}" "$reindex_time" "$total_time" > "${logfile}"
        fi
    fi
}

main "$@"
