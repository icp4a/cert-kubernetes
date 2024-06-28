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

############################################################
#Setup Variables
############################################################

DIR="$( cd "$( dirname "$0" )" && pwd )"

source $DIR/helper/post-install/env.sh
source $DIR/helper/post-install/services/functions.sh

#Source all capabilities specific functions
############################################################
source $DIR/helper/post-install/services/filenet.sh
source $DIR/helper/post-install/services/ads.sh
source $DIR/helper/post-install/services/baa.sh
source $DIR/helper/post-install/services/odm.sh
source $DIR/helper/post-install/services/bai.sh
source $DIR/helper/post-install/services/baw.sh
source $DIR/helper/post-install/services/rpa.sh
source $DIR/helper/post-install/services/rregistry.sh
source $DIR/helper/post-install/services/tm.sh
source $DIR/helper/post-install/services/bastudio.sh
source $DIR/helper/post-install/services/navigator.sh
source $DIR/helper/post-install/services/baml.sh
source $DIR/helper/post-install/services/pfs.sh
#source $DIR/helper/post-install/probe/checkURL4BA.sh

CP_FUNCTION_NAME="CP4BA Service"
#############################################################
case ${1} in
    --help|--?|?|-?|help|-help|--Help|-Help)
        printHeaderMessage "Help Menu for service flags"
        echo "--Precheck                           This will precheck OCP access"
        echo "--StarterStatus                      This will give status for services for Starter"
        echo "--StarterConsole                     This will give console for services URLs for Starter"
        echo "--StarterProbe                       This will probe readiness/liveness of the Starter endpoints"
        echo "--Status                             This will give status for services for Production"
        echo "--Console                            This will give console for services URLs for Production"
        echo "--Probe                              This will probe readiness/liveness of the Production endpoints"
        echo "--RPAStatus                          This will give status for RPA Server"
        echo "--RPAConsole                         This will give console for RPA Server"
        echo ""
        consoleFooter "${CP_FUNCTION_NAME}"
        exit 0
        ;;
esac

#Check for OS and set some vars accordingly:
OS
#Check connection to cluster:
validateOCPAccess
#Load APIs and Operator info
#operatorAndAPIVersions

case ${1} in
    --precheck|--Precheck)
         echo "--- Good to go!"
         consoleFooter "${CP_FUNCTION_NAME}"
         exit 0
         ;;
    --Status|--status)
          cp4baProductionServiceStatus
          consoleFooter "${CP_FUNCTION_NAME}"
          cleanUp
          exit 0
          ;;
    --Console|--console)
          cp4baServiceConsole "production"
          consoleFooter "${CP_FUNCTION_NAME}"
          cleanUp
          exit 0
          ;;
    --StarterStatus|--starterStatus)
          cp4baServiceStatus "starter"
          consoleFooter "${CP_FUNCTION_NAME}"
          exit 0
          ;;
    --StarterConsole|--starterConsole)
          cp4baServiceConsole "starter"
          consoleFooter "${CP_FUNCTION_NAME}"
          exit 0
          ;;
    --RPAConsole)
          cp4baRPAConsole
          consoleFooter "${CP_FUNCTION_NAME}"
          exit 0
          ;;
    --RPAStatus)
          cp4baRPAServerStatus
          consoleFooter "${CP_FUNCTION_NAME}"
          exit 0
          ;;
    --StarterProbe|--starterProbe|--Probe|--probe)
         cp4baServiceProbe
         exit 0
         ;;
    --*|-*)
        echo "${RED_TEXT}Unsupported flag in command line - ${1}. ${RESET_TEXT}"
        echo ""
        consoleFooter "${CP_FUNCTION_NAME}"
        exit 9
        ;;
esac

#Call cleanup to delete logs folder
###cleanUp
