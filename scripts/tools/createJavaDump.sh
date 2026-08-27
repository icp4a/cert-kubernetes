#!/bin/bash
###############################################################################
##
##Licensed Materials - Property of IBM
##
##(C) Copyright IBM Corp. 2021. All Rights Reserved.
##
##US Government Users Restricted Rights - Use, duplication or
##disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
##
###############################################################################
set -e 
set -u

# This script will create a javacore dump for the specified Liberty server instance name such as server dump server_name --archive=package_file_name.dump.zip --include=heap
# If you want to collect the java core dump for a container running Liberty server, then you can copy this script into the container and run it.
# This script will require the following input:
# --server_name: The name of the server instance for which the javacore dump is to be created.  Default is defaultServer
# --archive_location: The location of the save dump file (in Zip format).  Recommend to be a PVC mount point.
# --diagnostic_options: Such as heap, system, thread, etc.  Default is heap
# --interval: How often to create the javacore dump.  Default is 3 minutes (3m). It should be in the format of 300s, 5m, etc.



function usage {
    echo "This script will create a javacore dump for the specific Websphere Liberty server instance name at a configurable interval."
    echo "This script needs to be executed on the Liberty server."
    echo "Options:"
    echo "  --server_name string                              [Optional] The name of the Liberty server instance for which the javacore dump is to be created.  Default is defaultServer"
    echo "  --server_bin_path string                          [Optional] The path to the Liberty server bin directory. Default is /opt/ibm/wlp/bin"
    echo "  --archive_location  string                        [Optional] The location of the save dump file (in Zip format).  Recommend to be a PVC mount point. Default is "/tmp/" "
    echo "  --diagnostic_options string                       [Optional] Such as heap, system, thread, etc.  Default is heap"
    echo "  --interval string                                 [Optional] How often to create the javacore dump. For example: 300s, 5m.  Default is 3m."
    echo "Usage: ${0} --server_name defaultServer  --server_bin_path /opt/ibm/wlp/bin --archive_location /tmp/dump --diagnostic_options heap  --interval 60s"
    exit 1
}

function parse_arguments (){ 
    if [[ $# -eq 0 ]]; then
        echo "No arguments supplied. The script will run with default values which may not suitable in all situations. For more information, use "${0}" --help"
        echo "Do you want to proceed? [y/n]"
        read -r input
        if [[ "$input" == "n" || "$input" == "N" ]]; then
            usage
            exit 1
        fi
    fi  
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
        --server_name)
            shift
            SERVER_NAME=${1:-}
            ;;
        --server_bin_path)
            shift
            SERVER_BIN_PATH=${1:-}
            ;;
        --archive_location)
            shift
            ARCHIVE_LOCATION=${1:-}
            ;;
        --diagnostic_options)
            shift
            DIAGNOSTIC_OPTIONS=${1:-}
            ;;
        --interval)
            shift
            INTERVAL=${1:-}
            ;;
        --help)
            usage
            exit 1
            ;;
        *)
            echo "Unknown arguments"
            usage
            exit 1
            ;;
        esac
        shift
    done
}
# Define the default values
SERVER_NAME=${SERVER_NAME:-"defaultServer"}
SERVER_BIN_PATH=${SERVER_BIN_PATH:-"/opt/ibm/wlp/bin"}
ARCHIVE_LOCATION=${ARCHIVE_LOCATION:-"/tmp"}
DIAGNOSTIC_OPTIONS=${DIAGNOSTIC_OPTIONS:-"heap"}
INTERVAL=${INTERVAL:-"3m"}

function createJDump(){
    DUMP_FILE_NAME="javacore_$(date +%Y%m%d%H%M%S).zip"
    echo "Creating javacore dump for server instance $SERVER_NAME"
    echo "Archive location: $ARCHIVE_LOCATION"
    echo "Diagnostic options: $DIAGNOSTIC_OPTIONS"
    echo "Interval: $INTERVAL"
    while true; do
      DUMP_FILE_NAME="javacore_$(date +%Y%m%d%H%M%S).zip"
      echo "$SERVER_BIN_PATH/server dump "$SERVER_NAME" --archive="$ARCHIVE_LOCATION"/"$DUMP_FILE_NAME" --include="$DIAGNOSTIC_OPTIONS""
      $SERVER_BIN_PATH/server dump "$SERVER_NAME" --archive="$ARCHIVE_LOCATION"/"$DUMP_FILE_NAME" --include="$DIAGNOSTIC_OPTIONS"
      echo "Javacore dump created successfully"
      echo "Sleeping for "$INTERVAL". Press control-c to stop"
      sleep $INTERVAL
    done
}

function main(){
  parse_arguments "$@"
  createJDump
}

main "$@"