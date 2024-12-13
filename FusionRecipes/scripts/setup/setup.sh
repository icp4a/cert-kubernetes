#!/bin/bash
### Following resource will get created in ibm-spectrum-fusion-ns namespace
# 1. secret to store the access for s3 location created
# 2. backupstoragelocation.data-protection.isf.ibm.com : Location for s3
# 3. backuppolicy.data-protection.isf.ibm.com: Policy 
# 4. policyassignment.data-protection.isf.ibm.com: Policy will get assinged to specified application along with the custom recipe
# 5. application.application.isf.ibm.com : if you application is deployed more than one namespace , then this will help to create fusion 
# application after provide all ns which you want to be the part of recipe 

# Function to prompt for input with a message
prompt_input() {
    local input
    read -p "$1: " input
    echo "$input"
}

echo "\n-------Create Fusion Backup Storage Location------\n"
# Prompt for necessary inputs with error checking
ACCESS_KEY=""
while [[ -z "$ACCESS_KEY" ]]; do
    ACCESS_KEY=$(prompt_input "Enter Access Key(in case of IBM , AWS or any s3 compalible) or Account Name(in case of Azure)")
    if [[ -z "$ACCESS_KEY" ]]; then
        echo "Error: Access Key or Account Name cannot be empty" >&2
    fi
done

SECRET_KEY=""
while [[ -z "$SECRET_KEY" ]]; do
    SECRET_KEY=$(prompt_input "Enter Secret Key(in case of IBM , AWS or any s3 compalible)  or Account access key (in case of Azure)")
    if [[ -z "$SECRET_KEY" ]]; then
        echo "Error: Secret Key or Account access key cannot be empty" >&2
    fi
done

BUCKET_NAME=""
while [[ -z "$BUCKET_NAME" ]]; do
    BUCKET_NAME=$(prompt_input "Enter Bucket Name")
    if [[ -z "$BUCKET_NAME" ]]; then
        echo "Error: Bucket Name cannot be empty" >&2
    fi
done

ENDPOINT=""
while [[ -z "$ENDPOINT" ]]; do
    ENDPOINT=$(prompt_input "Enter Endpoint")
    if [[ -z "$ENDPOINT" ]]; then
        echo "Error: Endpoint cannot be empty" >&2
    fi
done

FBSL_TYPE=""
while [[ -z "$FBSL_TYPE" ]]; do
    FBSL_TYPE=$(prompt_input "Enter fusion backup storage location type(i.e ibm )")
    if [[ -z "$FBSL_TYPE" ]]; then
        echo "Error: fusion backup storage location type cannot be empty" >&2
    fi
done

FBSL_NAME=""
while [[ -z "$FBSL_NAME" ]]; do
    FBSL_NAME=$(prompt_input "Enter fusion backup storage location Name")
    if [[ -z "$FBSL_NAME" ]]; then
        echo "Error: fusion backup storage location name cannot be empty" >&2
    fi
done

ACCESS_KEY=$(echo -n "$ACCESS_KEY" | base64)
SECRET_KEY=$(echo -n "$SECRET_KEY" | base64)
# Check if $FBSL_TYPE is azure
if [ "$FBSL_TYPE" == "azure" ]; then
    # Azure specific parameters
    # DATA="  storage-account-name: $(echo -n "$ACCESS_KEY" | base64)\n storage-account-access-key: $(echo -n "$SECRET_KEY" | base64)"
    SECRET_DATA=$(cat <<EOF
  storage-account-name: $ACCESS_KEY
  storage-account-access-key: $SECRET_KEY
EOF
    )
else
    # For anything else
    # DATA="  access-key-id: $(echo -n "$ACCESS_KEY" | base64)\n  secret-access-key: $(echo -n "$SECRET_KEY" | base64)"
SECRET_DATA=$(cat <<EOF
  access-key-id: $ACCESS_KEY
  secret-access-key: $SECRET_KEY
EOF
)
fi

echo "SECRET_DATA :::::: $SECRET_DATA"

# Check if $FBSL_TYPE is AWS or IBM or AZURE 

# accountKey , accountKeySecret : azure 
# region : aws 
# Set default parameters
# PARAMS="bucket: $BUCKET_NAME\n    endpoint: $ENDPOINT"

PARAMS=$(cat <<EOF
bucket: $BUCKET_NAME
    endpoint: $ENDPOINT
EOF
)

# Check if $FBSL_TYPE is aws
if [ "$FBSL_TYPE" == "aws" ]; then
    # AWS specific parameter
    REGION=""
    while [[ -z "$REGION" ]]; do
        REGION=$(prompt_input "Enter region")
        if [[ -z "$REGION" ]]; then
            echo "Error: region cannot be empty in case of aws" >&2
        fi
    done
    # PARAMS="${PARAMS}\n    region: $REGION"
    PARAMS=$(cat <<EOF
bucket: $BUCKET_NAME
    endpoint: $ENDPOINT
    region: $REGION
EOF
)
fi

echo "PARAMS :::::: $PARAMS"

# Create Fusion backup storage location
./fbsl.sh $FBSL_NAME $FBSL_TYPE "$SECRET_DATA" "$PARAMS" 

# Wait until the resource reaches the "Connected" phase
while [[ $(oc get fbsl $FBSL_NAME -n ibm-spectrum-fusion-ns -o 'jsonpath={..status.phase}') != "Connected" ]]; do 
    echo "Waiting for the resource to reach 'Connected' phase..."
    sleep 5
done
echo "\n-------Storage Location Created  Successfully : $FBSL_NAME------\n"


echo "\n-------Create Fusion Backup Policy------\n"
BACKUP_POLICY_NAME=""
while [[ -z "$BACKUP_POLICY_NAME" ]]; do
    BACKUP_POLICY_NAME=$(prompt_input "Enter fusion backup policy name")
    if [[ -z "$BACKUP_POLICY_NAME" ]]; then
        echo "Error: fusion backup policy name cannot be empty" >&2
    fi
done

RETENTION_PERIOD=""
while [[ -z "$RETENTION_PERIOD" ]]; do
    RETENTION_PERIOD=$(prompt_input "Enter retention period(i.e 1, 2, ...) depends on retention unit (Default RETENTION_PERIOD is 30)")
    if [[ -z "$RETENTION_PERIOD" ]]; then
        RETENTION_PERIOD=30
        echo "Default RETENTION_PERIOD is 30" >&2
    fi
done

RETENTION_UNIT=""
while [[ -z "$RETENTION_UNIT" ]]; do
    RETENTION_UNIT=$(prompt_input "Enter retention unit i.e. (days,weeks,months,years)(Default RETENTION_UNIT is days)")
    if [[ -z "$RETENTION_UNIT" ]]; then
        RETENTION_UNIT=days
        echo "Default RETENTION_UNIT is days" >&2
    fi
done

SCHEDULE_CRON_EXPRESSION=""
while [[ -z "$SCHEDULE_CRON_EXPRESSION" ]]; do
    SCHEDULE_CRON_EXPRESSION=$(prompt_input "Enter a valid cron expression to schdule the backup(Default SCHEDULE_CRON_EXPRESSION is 00 0 1 * *)")
    if [[ -z "$SCHEDULE_CRON_EXPRESSION" ]]; then
        SCHEDULE_CRON_EXPRESSION="00 0 1 * *"
        echo "Default SCHEDULE_CRON_EXPRESSION is 00 0 1 * *(At 12:00 AM, on day 1 of the month)" >&2
    fi
done

SCHEDULE_TIME_ZONE=""
while [[ -z "$SCHEDULE_TIME_ZONE" ]]; do
    SCHEDULE_TIME_ZONE=$(prompt_input "Enter a valid timezome to schdule the backup(Default timezome is UTC)")
    if [[ -z "$SCHEDULE_TIME_ZONE" ]]; then
        SCHEDULE_TIME_ZONE=UTC
        echo "Default timezome is UTC" >&2
    fi
done

# Create Fusion backup policy
./fbackup_policy.sh $BACKUP_POLICY_NAME $FBSL_NAME $RETENTION_PERIOD $RETENTION_UNIT "$SCHEDULE_CRON_EXPRESSION" $SCHEDULE_TIME_ZONE

# Wait until the resource reaches the "Created" phase
while [[ $(oc get fbp $BACKUP_POLICY_NAME -n ibm-spectrum-fusion-ns -o 'jsonpath={..status.phase}') != "Created" ]]; do 
    echo "Waiting for the resource to reach 'Created' phase..."
    sleep 5
done
echo "\n-------Backup Policy Created  Successfully : $BACKUP_POLICY_NAME------\n"


echo "\n-------Create Fusion Backup Policy Assignment------\n"

APPLICATION=""
while [[ -z "$APPLICATION" ]]; do
    APPLICATION=$(prompt_input "Enter a valid application name to protect")
    if [[ -z "$APPLICATION" ]]; then
        echo "Error: application name cannot be empty" >&2
    fi
done
RECIPE_NAME=""
while [[ -z "$RECIPE_NAME" ]]; do
    RECIPE_NAME=$(prompt_input "Enter a valid recipe name")
    if [[ -z "$RECIPE_NAME" ]]; then
        echo "Error: recipe name cannot be empty" >&2
    fi
done


POLICY_ASSIGNMENT_NAME=$APPLICATION-$BACKUP_POLICY_NAME
echo Policy assignment name will be in format application-backuppolicy : $POLICY_ASSIGNMENT_NAME

# Create the policy assignment with custom recipe
./fbackuppolicy_assignment.sh $POLICY_ASSIGNMENT_NAME $APPLICATION $BACKUP_POLICY_NAME $FBSL_NAME $RECIPE_NAME

# Wait until the resource reaches the "Assigned" phase
while [[ $(oc get fpa $POLICY_ASSIGNMENT_NAME -n ibm-spectrum-fusion-ns -o 'jsonpath={..status.phase}') != "Assigned" ]]; do 
    echo "Waiting for the resource to reach 'Assigned' phase..."
    sleep 5
done
echo "\n-------Backup Policy $BACKUP_POLICY_NAME Assigned  Successfully to Application : $APPLICATION ------\n"

MULTIPLE_NS=""
while [[ -z "$MULTIPLE_NS" ]]; do
    MULTIPLE_NS=$(prompt_input "Enter a minimum valid two namsspaces separated with space")
    if [[ -z "$MULTIPLE_NS" ]]; then
        echo "Error: namsspaces cannot be empty" >&2
    fi
done

# Create fapp if your application is deployed in more than 1 namespace
./fapp.sh $APPLICATION $MULTIPLE_NS


#put a check after each resource create to proceed to next step
