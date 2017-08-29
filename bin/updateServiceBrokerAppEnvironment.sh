#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

set -e
source $SCRIPTPATH/bosh-common.sh

DEPLOYED_MANIFEST_FILE=$WORKSPACE/deployed-manifest.yml
DEPLOYMENT_NAME=${DEPLOYMENT_NAME:-"solace-vmr-warden-deployment"}

CMD_NAME=`basename $0`
BASIC_USAGE="usage: $CMD_NAME [-r][-h]"

function showUsage() {
    read -r -d '\0' USAGE_DESCRIPTION << EOM
$BASIC_USAGE

Update the environment variables of the service broker app against the bosh deployment.

optional arguments:
  -r    Resets all service broker environment variables to their defaults
  -h    Show this help message and exit
\0
EOM
    echo "$USAGE_DESCRIPTION"
}

# This sets up the environment variables that are normally set by the tile.
# e.g. SOLACE_VMR_MEDIUM_HA_VMR_HOSTS: ["192.168.101.16", "192.168.101.17", "192.168.101.18"]
# It sets the environment on the service broker and restages it.

function setupServiceBrokerEnvironment() {
  echo "In setupServiceBrokerEnvironment - doing cf target..."
  if cf target -o solace -s solace-messaging; then
    setServiceBrokerSimpleProperty starting_port STARTING_PORT
    setServiceBrokerSimpleProperty admin_password VMR_ADMIN_PASSWORD
    setServiceBrokerVMRHostsEnvironment
    setServiceBrokerSyslogEnvironment
    setServiceBrokerLDAPEnvironment
    setServiceBrokerTLSEnvironment

    echo restaging message broker...
    cf restage solace-messaging
  else
    >&2 echo "solace organization does not exist, please install the service broker and re-run $CMD_NAME"
  fi
}

function resetServiceBrokerEnvironment() {
  echo "In resetServiceBrokerEnvironment"
  if cf target -o solace -s solace-messaging; then
    resetServiceBrokerVMRHostsEnvironment
    resetServiceBrokerSyslogEnvironment
    resetServiceBrokerLDAPEnvironment
    resetServiceBrokerTLSEnvironment

    echo restaging message broker...
    cf restage solace-messaging
  else
    echo "solace organization does not exist so no need to reset service broker environment"
  fi
}

function setServiceBrokerSimpleProperty() {
  MANIFEST_PROPERTY_NAME=$1
  SB_ENV_NAME=$2

  echo "Setting $SB_ENV_NAME env variables on Service Broker..." 
  # Using no default with shyaml since we want it to fail if value is not found
  VALUE_FROM_MANIFEST=`cat $DEPLOYED_MANIFEST_FILE | shyaml get-value jobs.0.properties.$MANIFEST_PROPERTY_NAME`
  cf set-env solace-messaging $SB_ENV_NAME $VALUE_FROM_MANIFEST
}

function resetServiceBrokerTLSEnvironment() {

  cf unset-env solace-messaging TLS_CONFIG

}


function setServiceBrokerTLSEnvironment() {

  tls_config=`cat $DEPLOYED_MANIFEST_FILE | shyaml get-value jobs.0.properties.tls_config "disabled" `
  echo cf set-env solace-messaging TLS_CONFIG "{'value' : '$tls_config'}"
  cf set-env solace-messaging TLS_CONFIG "{'value' : '$tls_config'}"

}
 
function resetServiceBrokerLDAPEnvironment() {
 
  cf unset-env solace-messaging LDAP_CONFIG 
  cf unset-env solace-messaging MANAGEMENT_ACCESS_AUTH_SCHEME 
  cf unset-env solace-messaging APPLICATION_ACCESS_AUTH_SCHEME 

}

function setServiceBrokerLDAPEnvironment() {

  ldap_config=`cat $DEPLOYED_MANIFEST_FILE | shyaml get-value jobs.0.properties.ldap_config "disabled" `
  management_access_auth_scheme=`cat $DEPLOYED_MANIFEST_FILE | shyaml get-value jobs.0.properties.management_access_auth_scheme "vmr_internal" `
  application_access_auth_scheme=`cat $DEPLOYED_MANIFEST_FILE | shyaml get-value jobs.0.properties.application_access_auth_scheme "vmr_internal" `

  echo cf set-env solace-messaging LDAP_CONFIG "{'value' : '$ldap_config'}"
  cf set-env solace-messaging LDAP_CONFIG "{'value' : '$ldap_config'}"

  echo cf set-env solace-messaging MANAGEMENT_ACCESS_AUTH_SCHEME "{'value' : '$management_access_auth_scheme'}"
  cf set-env solace-messaging MANAGEMENT_ACCESS_AUTH_SCHEME "{'value' : '$management_access_auth_scheme'}"

  echo cf set-env solace-messaging APPLICATION_ACCESS_AUTH_SCHEME "{'value' : '$application_access_auth_scheme'}"
  cf set-env solace-messaging APPLICATION_ACCESS_AUTH_SCHEME "{'value' : '$application_access_auth_scheme'}"

}
 
function setServiceBrokerVMRHostsEnvironment() {
  POOL_NAMES=$(py "getPoolNames")

  for POOL in ${POOL_NAMES[@]}; do
    ENV_NM=`echo $POOL | tr '[:lower:]-' '[:upper:]_'`
    ENV_NAME=SOLACE_VMR_${ENV_NM}_HOSTS

    JOB=`py "getManifestJobByName" $DEPLOYED_MANIFEST_FILE $POOL`
    if [ "$(echo -n $JOB | wc -c)" -gt "0" ]; then
      JOB_NAME=$(echo -n $JOB | shyaml get-value name)
      IPS=`bosh vms | grep "$JOB_NAME" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | sed 's/^/"/g' | sed 's/$/"/g' | tr "\n" ","`
      # Remove trailing ',' and wrap into square braces
      IPS="[${IPS%,}]"
    else
      IPS="[]"
    fi

    echo setting environment variable $ENV_NAME to "$IPS"
    cf set-env solace-messaging $ENV_NAME "$IPS"
  done
}

function resetServiceBrokerVMRHostsEnvironment() {
  POOL_NAMES=$(py "getPoolNames")
  for POOL in ${POOL_NAMES[@]}; do
    ENV_NM=`echo $POOL | tr '[:lower:]-' '[:upper:]_'`
    ENV_NAME=SOLACE_VMR_${ENV_NM}_HOSTS
    IPS='[]'

    echo setting environment variable $ENV_NAME to "$IPS"
    cf set-env solace-messaging $ENV_NAME "$IPS"
  done
}

function setServiceBrokerSyslogEnvironment() {
  echo "Setting SYSLOG env variables on Service Broker..." 
  SYSLOG_CONFIG=`cat $DEPLOYED_MANIFEST_FILE | shyaml get-value jobs.0.properties.syslog_config "disabled"`
  if [ "$SYSLOG_CONFIG" == "enabled" ]; then
    SYSLOG_HOSTNAME=`cat $DEPLOYED_MANIFEST_FILE | shyaml get-value jobs.0.properties.syslog_hostname ""`
    SYSLOG_PORT=`cat $DEPLOYED_MANIFEST_FILE | shyaml get-value jobs.0.properties.syslog_port "514"`
    SYSLOG_PROTOCOL=`cat $DEPLOYED_MANIFEST_FILE | shyaml get-value jobs.0.properties.syslog_protocol "udp"`
    SYSLOG_BROKER_AND_AGENT_LOGS=`cat $DEPLOYED_MANIFEST_FILE | shyaml get-value jobs.0.properties.syslog_broker_and_agent_logs "false"`
    cf set-env solace-messaging SYSLOG_CONFIG "{'value':'$SYSLOG_CONFIG', 'selected_option':{'syslog_hostname':'$SYSLOG_HOSTNAME','syslog_port':$SYSLOG_PORT,'syslog_protocol':'$SYSLOG_PROTOCOL','syslog_vmr_command_logs':true,'syslog_vmr_event_logs':true,'syslog_vmr_system_logs':true,'syslog_broker_and_agent_logs':$SYSLOG_BROKER_AND_AGENT_LOGS}}"
  else
    cf set-env solace-messaging SYSLOG_CONFIG "{'value':'$SYSLOG_CONFIG', 'selected_option':{}}"
  fi
}

function resetServiceBrokerSyslogEnvironment() {
  cf set-env solace-messaging SYSLOG_CONFIG "{'value':'disabled','selected_option':{}}"
}


RESET=1
while getopts :rh opt; do
  case $opt in
    r) RESET=0;;
    h) 
        showUsage
        exit 0;;
    \?) echo $BASIC_USAGE && >&2 echo "Found bad option: -$OPTARG" && exit 1;;
    :) echo $BASIC_USAGE && >&2 echo "Missing argument for option: -$OPTARG" && exit 1;;
  esac
done

DEPLOYMENT_FOUND_COUNT=`2>&1 bosh deployments | grep $DEPLOYMENT_NAME | wc -l`
if [ "$RESET" -eq "0" ]; then
    resetServiceBrokerEnvironment
elif [ "$DEPLOYMENT_FOUND_COUNT" -eq "0" ]; then
    echo "Bosh deployment, $DEPLOYMENT_NAME, does not exist. Will reset the service broker environments..."
    resetServiceBrokerEnvironment
else
    echo "Temporarily downloading most up-to-date bosh manifest for deployment $DEPLOYMENT_NAME"
    (echo "yes") | bosh download manifest $DEPLOYMENT_NAME $DEPLOYED_MANIFEST_FILE

    if ! [ -s "$DEPLOYED_MANIFEST_FILE" ]; then
        echo "The downloaded manifest file was empty, resetting service broker environments..."
        resetServiceBrokerEnvironment
    else
        setupServiceBrokerEnvironment
    fi

    if [ -e "$DEPLOYED_MANIFEST_FILE" ]; then
        echo "Deleting $DEPLOYED_MANIFEST_FILE"
        rm $DEPLOYED_MANIFEST_FILE
    fi
fi

