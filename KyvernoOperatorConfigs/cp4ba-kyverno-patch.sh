#!/bin/bash
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2026. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# Script to apply CSV patches for CP4BA operators
# Supports HA, ephemeral, and emptyDir modes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$SCRIPT_DIR"

# Source common utilities
source "${SCRIPT_DIR}/../scripts/helper/common.sh"

# Function to prompt for storage class
prompt_for_storage_class() {
    local storage_class=""
    # WHY: Loop until user provides a valid non-empty storage class name
    while [[ -z "$storage_class" ]]; do
        read -p "Please provide block storage class to be used for ephemeral volumes for the operators: " storage_class
        if [[ -z "$storage_class" ]]; then
            error "Storage class name cannot be empty. Please try again." >&2
        fi
    done
    
    # Redirect informational output to stderr so it displays but doesn't get captured
    echo "" >&2
    info "Storage class '$storage_class' will be used for all ephemeral volumes." >&2
    echo "" >&2
    
    #Return the storage class value via stdout (bash function return mechanism)
    echo "$storage_class"
}

# Function to update storage class in a single JSON file
update_storage_class_in_json() {
    local json_file="$1"
    local storage_class="$2"
    
    # Verify file exists before attempting to modify it
    if [[ ! -f "$json_file" ]]; then
        return 1
    fi
    
    # Only process files that contain storageClassName to avoid unnecessary operations
    if grep -q "storageClassName" "$json_file"; then
        # Use sed to replace all storageClassName values in the JSON file
        # The regex pattern matches: "storageClassName": "any-value"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # WHY: macOS sed requires empty string after -i flag
            sed -i '' "s/\"storageClassName\": \"[^\"]*\"/\"storageClassName\": \"$storage_class\"/g" "$json_file"
        else
            # WHY: Linux sed doesn't need empty string after -i flag
            sed -i "s/\"storageClassName\": \"[^\"]*\"/\"storageClassName\": \"$storage_class\"/g" "$json_file"
        fi
        return 0
    fi
    
    return 1
}

# Function to update all ephemeral volume JSON templates
update_all_json_templates() {
    local storage_class="$1"
    local updated_count=0
    local total_count=0
    
    info "Updating storageClassName in all JSON templates..."
    echo ""
    
    # Finds all ephemeral-volume.json files recursively in the directory structure
    while IFS= read -r json_file; do
        ((total_count++))
        if update_storage_class_in_json "$json_file" "$storage_class"; then
            ((updated_count++))
            # Shows which files were updated for transparency
            success "Updated: $(basename "$(dirname "$json_file")")/$(basename "$json_file")"
        fi
    done < <(find "$PATCH_DIR" -type f -name "*-ephemeral-volume.json")
    
    echo ""
    if [[ $updated_count -gt 0 ]]; then
        success "Successfully updated storageClassName in $updated_count JSON template file(s)."
    else
        warning "No JSON template files were updated."
    fi
    echo ""
}

usage() {
    echo "Usage: $0 -n <namespace> -m <mode> [-s <storage-class>] [-o <operator1,operator2,...>] [-h]"
    echo ""
    echo "Options:"
    echo "  -n <namespace>      Namespace where operators are deployed (required)"
    echo "  -m <mode>           Mode: ha, ephemeral, emptydir, or pdb (required)"
    echo "  -s <storage-class>  Block storage class for ephemeral volumes (prompted if not provided for ephemeral mode)"
    echo "  -o <operators>      Comma-separated list of operator names (default: all available)"
    echo "  -h                  Show this help message"
    echo ""
    echo "Available operators (based on directory structure):"
    for dir in "$PATCH_DIR"/*/; do
        if [[ -d "$dir" ]]; then
            basename "$dir"
        fi
    done
    echo ""
    echo "Examples:"
    echo "# Apply HA patches and PDB (if available) to all operators"
    echo "  $0 -n my-namespace -m ha"
    echo "# Apply ephemeral patches with storage class specified (non-interactive)"
    echo "  $0 -n my-namespace -m ephemeral -s managed-nfs-storage"
    echo "# Apply ephemeral patches (will prompt for storage class)"
    echo "  $0 -n my-namespace -m ephemeral"
    echo "# Apply ephemeral patches to specific operators"
    echo "  $0 -n my-namespace -m ephemeral -s rook-ceph-block -o ibm-cp4a-operator,ibm-content-operator"
    echo "# Apply emptydir patches in custom namespace"
    echo "  $0 -n my-namespace -m emptydir"
    echo "# Apply PDB configuration in custom namespace"
    echo "  $0 -n my-namespace -m pdb"
}

get_available_operators() {
    local operators=()
    for dir in "$PATCH_DIR"/*/; do
        if [[ -d "$dir" ]]; then
            operators+=($(basename "$dir"))
        fi
    done
    echo "${operators[@]}"
}

find_csv_by_operator() {
    local operator_name="$1"
    local namespace="$2"
    
    # Try different CSV name patterns
    local csv_patterns=(
        "ibm-${operator_name}"
        "${operator_name}"
        "ibm-${operator_name%-operator}"
        "${operator_name%-operator}"
    )
    
    for pattern in "${csv_patterns[@]}"; do
        local csv=$($CLI_CMD get csv -n "$namespace" --no-headers 2>/dev/null | grep -i "$pattern" | awk '{print $1}' | head -1)
        if [[ -n "$csv" ]]; then
            echo "$csv"
            return 0
        fi
    done
    
    return 1
}

apply_patch() {
    local operator="$1"
    local mode="$2"
    local namespace="$3"
    
    local patch_file=""
    local pdb_file=()
    
    case "$mode" in
        "ha"|"pdb")
            patch_file="$PATCH_DIR/$operator/optional-${operator}-ha.json"
            pdb_file=("$PATCH_DIR/$operator/optional-${operator}-pdb.yaml")
            ;;
        "ephemeral")
            patch_file="$PATCH_DIR/$operator/optional-${operator}-ephemeral-volume.json"
            ;;
        "emptydir")
            patch_file="$PATCH_DIR/$operator/optional-${operator}-emptydir-volume.json"
            ;;      
    esac
    
    # Apply PDB for HA or PDB mode
    if [[ ("$mode" == "ha" || "$mode" == "pdb") && -f "$pdb_file" ]]; then
        # For PDB mode, check if ha.json exists to extract replica count, otherwise default to 0
        local replica_count=""
        if [[ "$mode" == "ha" ]]; then
            replica_count=$(grep -o '"value"[[:space:]]*:[[:space:]]*[0-9][0-9]*' "$patch_file" | head -1 | grep -o '[0-9][0-9]*$')
        else
            # Check if CSV exist if exist check the replica count of the running CSV if not exist default to 0
            local csv_name=$(find_csv_by_operator "$operator" "$namespace")
            if [[ -n "$csv_name" ]]; then
                replica_count=$($CLI_CMD get csv "$csv_name" -n "$namespace" -o jsonpath='{.spec.install.spec.deployments[0].spec.replicas}' 2>/dev/null)
            else
                info "CSV not found for operator: $operator, defaulting replica count to 0 for PDB configuration"
                replica_count=0
            fi
            
        fi
        
        if [[ -n "$replica_count" ]]; then
            local min_available=0
            if [[ $replica_count -gt 1 ]]; then
                min_available=1
            fi
            
            info "Replica count: $replica_count, setting minAvailable: $min_available"
            sed -i.bak "s/minAvailable:.*/minAvailable: $min_available/" "$pdb_file"
            rm -f "${pdb_file}.bak"
        else
            info "Using default minAvailable value from PDB file"
        fi
        
        info "Applying resource: $(basename "$pdb_file")"
        if $CLI_CMD apply -f "$pdb_file" -n "$namespace"; then
            success "Successfully applied $(basename "$pdb_file")"
            PDB_SUCCESS=$((PDB_SUCCESS + 1))
        else
            error "Failed to apply $(basename "$pdb_file")"
            PDB_FAILURE=$((PDB_FAILURE + 1))
        fi
    fi

    # Skip CSV patching for PDB-only mode
    if [[ "$mode" == "pdb" ]]; then
        return 0
    fi
    
    # Verify patch file exists
    if [[ ! -f "$patch_file" ]]; then
        error "Patch file not found: $patch_file"
        return 1
    fi
    

    local csv_name=$(find_csv_by_operator "$operator" "$namespace")
    if [[ -z "$csv_name" ]]; then
        error "CSV not found for operator: $operator"
        CSV_FAILURE=$((CSV_FAILURE + 1))
        return 0
    fi
    
    info "Applying $mode patch to CSV: $csv_name"
    if $CLI_CMD patch csv "$csv_name" -n "$namespace" --patch-file "$patch_file" --type json; then
        success "Successfully patched $csv_name"
        CSV_SUCCESS=$((CSV_SUCCESS + 1))
    elif $CLI_CMD patch csv "$csv_name" -n "$namespace" --patch-file "$patch_file" --type json --server-side --force-conflicts; then
        success "Successfully patched $csv_name (server-side)"
        CSV_SUCCESS=$((CSV_SUCCESS + 1))
    else
        error "Failed to patch $csv_name"
        CSV_FAILURE=$((CSV_FAILURE + 1))
    fi

    return 0
}

main() {
    local mode=""
    local namespace=""
    local operators_input=""
    local storage_class=""
    
    while getopts "m:n:o:s:h" opt; do
        case $opt in
            m)
                mode="$OPTARG"
                ;;
            n)
                namespace="$OPTARG"
                ;;
            o)
                operators_input="$OPTARG"
                ;;
            s)
                storage_class="$OPTARG"
                ;;
            h)
                usage
                exit 0
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$namespace" ]]; then
        echo "Error: Namespace is required (-n)"
        usage
        exit 1
    fi
    
    if [[ -z "$mode" ]]; then
        echo "Error: Mode is required (-m)"
        usage
        exit 1
    fi
    
    if [[ ! "$mode" =~ ^(ha|ephemeral|emptydir|pdb)$ ]]; then
        echo "Error: Mode must be 'ha', 'ephemeral', 'emptydir', or 'pdb'"
        usage
        exit 1
    fi
    
    # This ensures all JSON templates are updated before applying patches
    if [[ "$mode" == "ephemeral" ]]; then
        if [[ -z "$storage_class" ]]; then
            # WHY: If -s flag not provided, prompt user interactively
            storage_class=$(prompt_for_storage_class)
        else
            # WHY: If -s flag provided, confirm the value to user
            info "Using provided storage class: $storage_class"
            echo ""
        fi
        
        # WHY: Update all JSON templates with the storage class before applying patches
        # This eliminates the need for manual editing of JSON files
        update_all_json_templates "$storage_class"
    fi
    
    # Determine operators to process
    local operators=()
    if [[ -n "$operators_input" ]]; then
        IFS=',' read -ra temp_operators <<< "$operators_input"
        # Trim whitespace from each operator name
        for op in "${temp_operators[@]}"; do
            # Remove leading and trailing whitespace
            op=$(echo "$op" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$op" ]]; then
                operators+=("$op")
            fi
        done
    else
        read -ra operators <<< "$(get_available_operators)"
    fi
    
    if [[ ${#operators[@]} -eq 0 ]]; then
        echo "No operators found to process"
        exit 1
    fi
    
    echo "Starting CSV patch operation"
    echo "Mode: $mode"
    echo "Namespace: $namespace"
    echo "Operators: ${operators[*]}"
    echo ""
    
    # Check if namespace exists
    if ! $CLI_CMD get namespace "$namespace" >/dev/null 2>&1; then
        error "Namespace '$namespace' does not exist"
        exit 1
    fi
    
    # Initialize counters
    PDB_SUCCESS=0
    PDB_FAILURE=0
    CSV_SUCCESS=0
    CSV_FAILURE=0
    local total_count=${#operators[@]}
    
    for operator in "${operators[@]}"; do
        echo "Processing operator: $operator"
        apply_patch "$operator" "$mode" "$namespace"
        echo ""
    done
    
    echo ""
    echo "Summary:"
    echo "  Total operators processed: $total_count"
    if [[ "$mode" != "pdb" ]]; then
        echo "    Successful JSON patches: $CSV_SUCCESS"
        echo "    Failed JSON patches: $CSV_FAILURE"
    fi
    if [[ "$mode" == "ha" || "$mode" == "pdb" ]]; then
        echo "    Successful YAML applied: $PDB_SUCCESS"
        echo "    Failed YAML applied: $PDB_FAILURE"
    fi
    
    if [[ "$mode" == "pdb" ]]; then
        # For PDB mode, check PDB results
        if [[ $PDB_FAILURE -eq 0 ]]; then
            success "All PDBs applied successfully!"
            exit 0
        else
            warning "Some PDBs failed. Please check the output above."
            exit 1
        fi
    else
        # For other modes, check CSV results
        if [[ $CSV_FAILURE -eq 0 ]]; then
            success "All JSON patches applied successfully!"
            exit 0
        else
            warning "Some patches failed. Please check the output above."
            exit 1
        fi
    fi
}

main "$@"
