RED_TEXT=`tput setaf 1`
GREEN_TEXT=`tput setaf 2`
ORANGE_TEXT=`tput setaf 5`
BLUE_TEXT=`tput setaf 6`
YELLOW_TEXT=`tput setaf 3`
RESET_TEXT=`tput sgr0`
#Probe
RED='\033[1;31m' # Red
GRE='\033[1;32m' # Green
BLU='\033[1;34m' # Blue
BLD='\033[1m'    # Bold
NC='\033[0m'     # No Color

#Unicode Icons
## https://apps.timwhitlock.info/emoji/tables/unicode
ICON_SUCCESS=`echo -e "\xE2\x9C\x94" `
ICON_FAIL=`echo -e "\xE2\x9D\x8C  FAILED " `
ICON_WARNING=`echo -e "\xE2\x9D\x97  WARNING " `
ICON_WAITING=`echo -e "\xE2\x9C\x8B" `
ICON_VERY_BAD_FAIL=`echo -e "\xF0\x9F\x92\x80" `
ICON_WAITING_USER_INPUT=`echo -e "\xF0\x9F\x91\x89  Waiting for User Input:  " `
ICON_TIMER=`echo -e "\xE2\x8F\xB0" `
ICON_COFFEE=`echo -e "\xF0\x9F\x8D\xB5" `

OS_NAME=`uname`
CURRENT_DATE_TIME=`date +"%Y-%m-%d"`

# This section is to customize the Cloud Pak foundational services install type.
# By default, a shared Cloud Pak foundational services is used with a default ns of "ibm-common-services".
# If needed, you can change the ns to a dedicated Cloud Pak foundational services ns.
CP4BA_COMMON_SERVICES_NAMESPACE="ibm-common-services"


# PROBE: TESTING SERVICES URLs
# Populate these params before running probe
############################################
PROBE_USER_API_KEY=   # user Api Key generated from CP4BA console
PROBE_USER_NAME=      # user name, user who has right to open all CP4BA links
PROBE_USER_PASSWORD=  # user password for basic authentication
PROBE_VERBOSE='-v'    # verbose option, empty or "-v" to see additional debug information

#IBM Production Defaults
############################
### Optional - Place holders... ###
CP4BA_DEPLOYMENT_PRODUCTION_ADMIN_USER="Located in your LDAP Sever"     # "BUAdmin"
CP4BA_DEPLOYMENT_PRODUCTION_LDAP_PASSWORD="Located in your LDAP Sever"  # "admin"

CP4BA_DEPLOYMENT_PRODUCTION_DECISIONS_ADMIN_USER="Located in your LDAP Sever"     # "odmAdmin"
CP4BA_DEPLOYMENT_PRODUCTION_DECISIONS_LDAP_PASSWORD="Located in your LDAP Sever"  # "admin"

### FNCM - FileNet Content Manager - PRODUCTION
CP4BA_DEPLOYMENT_PRODUCTION_FNCM_ADMIN_USER="Located in your LDAP Sever"
CP4BA_DEPLOYMENT_PRODUCTION_FNCM_LDAP_PASSWORD="Located in your LDAP Sever"

### BAW - Business Automation Workflow - PRODUCTION
CP4BA_DEPLOYMENT_PRODUCTION_BAW_ADMIN_USER="Located in your LDAP Sever"
CP4BA_DEPLOYMENT_PRODUCTION_BAW_LDAP_PASSWORD="Located in your LDAP Sever"

### ADS - Automation Decision Services - PRODUCTION
CP4BA_DEPLOYMENT_PRODUCTION_ADS_ADMIN_USER="Located in your LDAP Sever"
CP4BA_DEPLOYMENT_PRODUCTION_ADS_LDAP_PASSWORD="Located in your LDAP Sever"

### BAA - Business Automation Application - PRODUCTION
CP4BA_DEPLOYMENT_PRODUCTION_BAA_ADMIN_USER="Located in your LDAP Sever"
CP4BA_DEPLOYMENT_PRODUCTION_BAA_LDAP_PASSWORD="Located in your LDAP Sever"

### AWS - Automation Workstream Services - PRODUCTION
CP4BA_DEPLOYMENT_PRODUCTION_AWS_ADMIN_USER="Located in your LDAP Sever"
CP4BA_DEPLOYMENT_PRODUCTION_AWS_LDAP_PASSWORD="Located in your LDAP Sever"

### WPSA - Workflow Process Service Authoring - PRODUCTION
CP4BA_DEPLOYMENT_PRODUCTION_WPSA_ADMIN_USER="Located in your LDAP Sever"
CP4BA_DEPLOYMENT_PRODUCTION_WPSA_LDAP_PASSWORD="Located in your LDAP Sever"

#IBM RPA
############################
CP4BA_RPA_SERVER_NAMESPACE=cp4ba-rpa-server
CP4BA_RPA_SERVER_NAME=cp4ba-rpa-server


