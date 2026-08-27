#!/bin/bash
#Handle args
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--name)
      shift
      BACKUP_NAME=$1
      shift # past argument
      ;;
    *)
      echo "Unknown option $1"
      echo "example:"
      echo "./restore.sh -n backup_name"
      exit 1
      ;;
  esac
done

# Check that BACKUP_NAME is set
# This is the name of the Velero Backup that will be filled in below
if [ -z $BACKUP_NAME ]
then
  echo "Please give the backup name"
  echo "example:"
  echo "./restore.sh -n backup_name"
  exit 1
fi

# This is to help the customer confirm they are using the correct cluster before starting
echo "Displaying current openshift console URL: "
echo
oc whoami --show-console
echo
echo "If the url looks correct for your restore cluster hit Enter, else stop script"
read ANS

# Need to make sure we have access to the backup, the Knowledge Center doc explains how to set this up
echo "Is Velero/OADP installed on this cluster? If so, hit enter. If not, set it up and then hit enter"
read ANS

echo "Is the velero CLI installed on this machine? If so, hit enter. If not, please install the velero cli"
read ANS

# Confirm we have a good backup
echo "Checking if the backup name provided exists in Velero"
velero backup get | grep $BACKUP_NAME
if [ $? -ne 0 ]
then
  echo "backup name does not exist"
  echo "the following are your options:"
  velero backup get
  exit 1
fi

# Restore the Namespace
echo "Ready to start, we will start with restoring the namespace. Hit enter to begin"
read ANS
sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-namespace.yaml
oc apply -f restore-namespace.yaml
velero restore get | grep restore-namespace | grep Completed
while [ $? -ne 0 ]
do
  echo "Waiting for namespace restore to complete..."
  sleep 5
  velero restore get | grep restore-namespace | grep Completed
done
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-namespace.yaml
sleep 2

#Output all namespaces, the one that was just restored will be seconds old
oc get namespace

#Get the name of the namespace from the end user
echo "Please enter the name of the common service namespace just restored:"
read CS_NAMESPACE

# Restore Entitlement key and pull secret
# We want to save the orginal pull secret because we are going to overwrite it
# The customer can add other secrets back to it later if needed
echo "Now we will restore the entitlement key and pull secret. We will save the original pull secret locally in case we need it later. Hit Enter:"
read ANS
oc get secret pull-secret -n openshift-config -o yaml > original_pull_secret.yaml
oc delete secret pull-secret -n openshift-config
sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-entitlementkey.yaml
oc apply -f restore-entitlementkey.yaml
sleep 5
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-entitlementkey.yaml

sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-pull-secret.yaml
oc apply -f restore-pull-secret.yaml
sleep 5
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-pull-secret.yaml

echo "There should be two secrets recently created:"

# Want to make sure the secrets are restored before finishing here
oc get secret -n $CS_NAMESPACE | grep entitlement
while [ $? -ne 0 ]
do
  echo "Waiting for secrets to be ready..."
  sleep 15
  oc get secret -n $CS_NAMESPACE | grep entitlement
done
oc get secret -n openshift-config | grep pull-secret

# Restore Catalog and operatorgroup
echo "Now we will restore the common services catalog and operator group, hit enter:"
read ANS
sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-catalog.yaml
oc apply -f restore-catalog.yaml
sleep 5
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-catalog.yaml

sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-operatorgroup.yaml
oc apply -f restore-operatorgroup.yaml
sleep 5
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-operatorgroup.yaml

# We can watch for the catalog pod to be in the openshift-marketplace to know when to continue
oc get pod -n openshift-marketplace | grep ibm-operator-catalog | grep Running
while [ $? -ne 0 ]
do
  echo "Waiting for catalog to be ready..."
  oc get pod -n openshift-marketplace | grep ibm-operator-catalog
  sleep 15
  oc get pod -n openshift-marketplace | grep ibm-operator-catalog | grep Running
done

echo "CHECK THE OPERATORHUB on the openshift console and see if the foundational services are available in the catalog. Hit Enter once you see them:"
read ANS

# Restore singleton subscription
# This restores cert-manager and licensing  subscription
echo "Restoring the subscriptions..."
sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-singleton-subscriptions.yaml
oc apply -f restore--singleton-subscriptions.yaml
sleep 5
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-singleton-subscriptions.yaml

echo "You can watch the subscriptions come up in the Openshift Console. Go to Operators -> Installed Operators make sure the project selected is $CERT_MGR_NAMESPACE."
oc get pod -A | grep cert-manager-controller | grep Running
while [ $? -ne 0 ]
do
  echo "Waiting for cert-manager-controller pod to be running..."
  oc get pod -A | grep cert-manager
  sleep 15
  oc get pod -A | grep cert-manager-controller | grep Running
done

# Restore licensing and cert-manager data
# There are a number of configmaps, CRDs, Issuers, and Certificates that get restored here
# Certificates usually take the longest, so we watch for those.
echo "Now restoring licensing and cert-manager data. Hit Enter:"
read ANS
sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-licensing.yaml
oc apply -f restore-licensing.yaml
sleep 5
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-licensing.yaml

sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-cert-manager.yaml
oc apply -f restore-cert-manager.yaml
sleep 5
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-cert-manager.yaml
## Wait on certificates to populate
oc get certificates -n $CS_NAMESPACE | grep cs-ca-certificate
while [ $? -ne 0 ]
do
  echo "Waiting on certificates to be populated..."
  sleep 10
  oc get certificates -n $CS_NAMESPACE | grep cs-ca-certificate
done


# Restore subscription
# This just restores the common-services subscription
# It's done restoring once ODLM is running
echo "Restoring the subscriptions..."
sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-subscriptions.yaml
oc apply -f restore-subscriptions.yaml
sleep 5
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-subscriptions.yaml
## TODO Check running pods in common-services namespace and wait for operand-deployment-lifecycle-manager pod to be running
echo "You can watch the subscriptions come up in the Openshift Console. Go to Operators -> Installed Operators make sure the project selected is $CS_NAMESPACE."
oc get pod -n $CS_NAMESPACE | grep operand-deployment-lifecycle-manager | grep Running
while [ $? -ne 0 ]
do
  echo "Waiting for operand-deployment-lifecycle-manager pod to be running..."
  oc get pod -n $CS_NAMESPACE
  sleep 15
  oc get pod -n $CS_NAMESPACE | grep operand-deployment-lifecycle-manager | grep Running
done


echo "Now that the subscriptions are in, we'll remove the default commonService object and restore our commonService object. Hit Enter:"
read ANS

# Restore the CommonService CR
# A default is created during the subscription restore
# We need to delete it, give it a chance to clear
# then restore the one we have backed up
oc delete commonservice common-service -n $CS_NAMESPACE
echo "Waiting one minute for the deletion to complete..."
sleep 30
sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-commonservice.yaml
oc apply -f restore-commonservice.yaml
sleep 30
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-commonservice.yaml
##Check status of common-service, should be Phase: Succeeded
oc get commonservice common-service -n $CS_NAMESPACE

echo "Now restoring the operand request. Hit Enter:"
read ANS

# Restore the operands
# This is all the services within foundational service getting restored
# We need MongoDB up so we can restore the mongodb data
sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-operands.yaml
oc apply -f restore-operands.yaml
sleep 5
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-operands.yaml

oc get pods -n $CS_NAMESPACE | grep icp-mongodb-0 | grep Running
while [ $? -ne 0 ]
do
  echo "Waiting foundational services to be ready...Checking every minute"
  oc get pods -n $CS_NAMESPACE
  sleep 60
  oc get pods -n $CS_NAMESPACE | grep icp-mongodb-0 | grep Running
done
echo "5 more minutes..."
sleep 300

# Now we can restore the mongodb data, we have a post-restore hook
# in the backup pod that restores the database
echo "Restore MongoDB Database:"
read ANS
sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-mongo-data.yaml
oc apply -f restore-mongo-data.yaml
sleep 60
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-mongo-data.yaml

# Restore Zen
# This takes awhile, but once the metastoredb is back we can move on and restore that db
echo "Restore Zen Service. Hit Enter:"
read ANS
sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-zen.yaml
oc apply -f restore-zen.yaml
sleep 5
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-zen.yaml
echo "Now we wait until MongoDB and the Zen Service is up and running. This can take up to 45 minutes, you'll be prompted to continue when
the cluster is ready..."
oc get pod zen-metastoredb-2 -n $CS_NAMESPACE
while [ $? -ne 0 ]
do
  echo "Waiting on zen-metastore database..."
  sleep 60
  oc get pod zen-metastoredb-2 -n $CS_NAMESPACE | grep Running
done

# Restore metastoredb
# There is a post restore hook in the backup pod that will trigger
# the restore 
echo "We are ready to restore metastoredb, hit enter:"
read ANS
sed -i s/__BACKUP_NAME__/$BACKUP_NAME/g restore-zen-data.yaml
oc apply -f restore-zen-data.yaml
sleep 5
sed -i s/$BACKUP_NAME/__BACKUP_NAME__/g restore-zen-data.yaml
