#!/bin/bash

# Script to check for new commits on master branch and trigger Jenkins job
# This script is designed to be run by a Jenkins freestyle job every 2 hours

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="dba/cert-kubernetes"
GITHUB_API_URL="https://github.ibm.com/api/v3"
BRANCH="master"
JENKINS_JOB_URL="https://hyc-dba-base-image-jenkins.swg-devops.com/job/cp4ba-install-upgrade/job/master/buildWithParameters"
LAST_COMMIT_FILE="/tmp/last_commit_sha_cp4ba_api.txt"

# Jenkins job parameters
RELEASE_VERSION="26.0.0"
SPRINT_TAG="latest"
BUILD_IMAGE="true"
COPY_IMAGE_TO_STAGING="false"

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if required environment variables are set
check_env_vars() {
    print_message "$YELLOW" "Checking required environment variables..."
    
    if [ -z "$GIT_USER" ] || [ -z "$GIT_PASSWORD" ]; then
        print_message "$RED" "ERROR: GIT_USER and GIT_PASSWORD environment variables must be set"
        exit 1
    fi
    
    if [ -z "$JENKINS_USERNAME" ] || [ -z "$JENKINS_TOKEN" ]; then
        print_message "$RED" "ERROR: JENKINS_USERNAME and JENKINS_TOKEN environment variables must be set"
        exit 1
    fi
    
    print_message "$GREEN" "All required environment variables are set"
}

# Function to get the latest commit SHA from GitHub
get_latest_commit() {
    print_message "$YELLOW" "Fetching latest commit from GitHub..."
    
    local response=$(curl -s -u "${GIT_USER}:${GIT_PASSWORD}" \
        "${GITHUB_API_URL}/repos/${GITHUB_REPO}/commits/${BRANCH}")
    
    if [ $? -ne 0 ]; then
        print_message "$RED" "ERROR: Failed to fetch commit information from GitHub"
        exit 1
    fi
    
    local commit_sha=$(echo "$response" | grep -o '"sha": *"[^"]*"' | head -1 | sed 's/"sha": *"\([^"]*\)"/\1/')
    
    if [ -z "$commit_sha" ]; then
        print_message "$RED" "ERROR: Could not parse commit SHA from GitHub response"
        print_message "$RED" "Response: $response"
        exit 1
    fi
    
    echo "$commit_sha"
}

# Function to get the last processed commit SHA
get_last_commit() {
    if [ -f "$LAST_COMMIT_FILE" ]; then
        cat "$LAST_COMMIT_FILE"
    else
        echo ""
    fi
}

# Function to save the current commit SHA
save_commit() {
    local commit_sha=$1
    echo "$commit_sha" > "$LAST_COMMIT_FILE"
    print_message "$GREEN" "Saved commit SHA: $commit_sha"
}

# Function to trigger Jenkins job
trigger_jenkins_job() {
    local commit_sha=$1
    
    print_message "$YELLOW" "Triggering Jenkins job for commit: $commit_sha"
    
    # Build the Jenkins job URL with parameters
    local jenkins_params="RELEASE_VERSION=${RELEASE_VERSION}&SPRINT_TAG=${SPRINT_TAG}&BUILD_IMAGE=${BUILD_IMAGE}&COPY_IMAGE_TO_STAGING=${COPY_IMAGE_TO_STAGING}"
    
    print_message "$YELLOW" "Jenkins Job URL: ${JENKINS_JOB_URL}"
    print_message "$YELLOW" "Parameters: ${jenkins_params}"
    
    # Trigger the Jenkins job
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        -u "${JENKINS_USERNAME}:${JENKINS_TOKEN}" \
        "${JENKINS_JOB_URL}?${jenkins_params}")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 201 ] || [ "$http_code" -eq 200 ]; then
        print_message "$GREEN" "Successfully triggered Jenkins job (HTTP $http_code)"
        return 0
    else
        print_message "$RED" "ERROR: Failed to trigger Jenkins job (HTTP $http_code)"
        print_message "$RED" "Response: $body"
        return 1
    fi
}

# Function to get commit details
get_commit_details() {
    local commit_sha=$1
    
    print_message "$YELLOW" "Fetching commit details..."
    
    local response=$(curl -s -u "${GIT_USER}:${GIT_PASSWORD}" \
        "${GITHUB_API_URL}/repos/${GITHUB_REPO}/commits/${commit_sha}")
    
    local author=$(echo "$response" | grep -o '"name": *"[^"]*"' | head -1 | sed 's/"name": *"\([^"]*\)"/\1/')
    local message=$(echo "$response" | grep -o '"message": *"[^"]*"' | head -1 | sed 's/"message": *"\([^"]*\)"/\1/')
    local date=$(echo "$response" | grep -o '"date": *"[^"]*"' | head -1 | sed 's/"date": *"\([^"]*\)"/\1/')
    
    print_message "$GREEN" "Commit Details:"
    print_message "$GREEN" "  SHA: $commit_sha"
    print_message "$GREEN" "  Author: $author"
    print_message "$GREEN" "  Date: $date"
    print_message "$GREEN" "  Message: $message"
}

# Main execution
main() {
    print_message "$GREEN" "========================================"
    print_message "$GREEN" "CP4BA API Image Build Automation Script"
    print_message "$GREEN" "========================================"
    echo ""
    
    # Check environment variables
    check_env_vars
    echo ""
    
    # Get latest commit from GitHub
    latest_commit=$(get_latest_commit)
    print_message "$GREEN" "Latest commit on ${BRANCH}: ${latest_commit}"
    echo ""
    
    # Get last processed commit
    last_commit=$(get_last_commit)
    
    if [ -z "$last_commit" ]; then
        print_message "$YELLOW" "No previous commit found. This is the first run."
        print_message "$YELLOW" "Saving current commit and triggering build..."
        echo ""
        
        # Get commit details
        get_commit_details "$latest_commit"
        echo ""
        
        # Trigger Jenkins job
        if trigger_jenkins_job "$latest_commit"; then
            save_commit "$latest_commit"
            print_message "$GREEN" "First run completed successfully"
        else
            print_message "$RED" "Failed to trigger Jenkins job on first run"
            exit 1
        fi
    elif [ "$latest_commit" != "$last_commit" ]; then
        print_message "$YELLOW" "New commit detected!"
        print_message "$YELLOW" "Previous commit: ${last_commit}"
        print_message "$YELLOW" "New commit: ${latest_commit}"
        echo ""
        
        # Get commit details
        get_commit_details "$latest_commit"
        echo ""
        
        # Trigger Jenkins job
        if trigger_jenkins_job "$latest_commit"; then
            save_commit "$latest_commit"
            print_message "$GREEN" "Build triggered successfully for new commit"
        else
            print_message "$RED" "Failed to trigger Jenkins job for new commit"
            exit 1
        fi
    else
        print_message "$GREEN" "No new commits detected"
        print_message "$GREEN" "Last processed commit: ${last_commit}"
        print_message "$GREEN" "Nothing to do"
    fi
    
    echo ""
    print_message "$GREEN" "========================================"
    print_message "$GREEN" "Script execution completed"
    print_message "$GREEN" "========================================"
}

# Run main function
main
exit_code=$?

# Ensure script exits with proper code
exit $exit_code
