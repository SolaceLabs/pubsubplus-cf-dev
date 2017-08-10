#!/bin/bash

export MY_BIN_HOME=$(dirname $(readlink -f $0))
export PYTHONPATH=$MY_BIN_HOME
export MY_HOME=$MY_BIN_HOME/..

export DEPLOYMENT_NAME=${DEPLOYMENT_NAME:-"solace-vmr-warden-deployment"}
export LOG_FILE=${LOG_FILE:-"/tmp/bosh_deploy.log"}

export SOLACE_DOCKER_BOSH_VERSION="29-solace-2"
export SOLACE_DOCKER_BOSH=${SOLACE_DOCKER_BOSH:-"$WORKSPACE/releases/docker-${SOLACE_DOCKER_BOSH_VERSION}.tgz"}

export STEMCELL_VERSION="3312.24"
export STEMCELL_NAME="bosh-stemcell-$STEMCELL_VERSION-warden-boshlite-ubuntu-trusty-go_agent.tgz"
export STEMCELL_URL="https://s3.amazonaws.com/bosh-core-stemcells/warden/$STEMCELL_NAME"

source "commonUtils.sh"

function targetBosh() {

  bosh target 192.168.50.4 lite

}

function prepareBosh() {

  echo "In function prepareBosh"

  targetBosh

  FOUND_DOCKER_RELEASE=`bosh releases | grep "docker" | grep $SOLACE_DOCKER_BOSH_VERSION | wc -l`
  if [ "$FOUND_DOCKER_RELEASE" -eq "0" ]; then
     echo "Uploading docker bosh"
     bosh upload release $SOLACE_DOCKER_BOSH
  else
     echo "$SOLACE_DOCKER_BOSH was found $FOUND_DOCKER_RELEASE"
  fi

  FOUND_STEMCELL=`bosh stemcells | grep bosh-warden-boshlite-ubuntu-trusty-go_agent | grep $STEMCELL_VERSION | wc -l`
  if [ "$FOUND_STEMCELL" -eq "0" ]; then
    if [ ! -f /tmp/$STEMCELL_NAME ]; then
      echo "Downloading stemcell"
      wget -O /tmp/$STEMCELL_NAME $STEMCELL_URL
    fi
    echo "Uploading stemcell"
    bosh upload stemcell /tmp/$STEMCELL_NAME
  else
     echo "$STEMCELL_NAME was found $FOUND_STEMCELL"
  fi
}

function deleteOrphanedDisks() {

bosh disks --orphaned

ORPHANED_DISKS=`bosh disks --orphaned | grep -v "| Disk"  | grep "^|"  | awk -F\| '{ print $2 }'`

for DISK_ID in $ORPHANED_DISKS; do
	echo "Will delete $DISK_ID"
	bosh delete disk $DISK_ID
done

}

function shutdownVMRJobs() {

 echo "In shutdownVMRJobs"

 VM_JOB=$1

 echo "Looking for VM job $VM_JOB" 
 VM_FOUND_COUNT=`bosh vms | grep $VM_JOB | wc -l`
 VM_RUNNING_FOUND_COUNT=`bosh vms | grep $VM_JOB | grep running |  wc -l`
 DEPLOYMENT_FOUND_COUNT=`bosh deployments | grep $DEPLOYMENT_NAME | wc -l`
 RELEASE_FOUND_COUNT=`bosh releases | grep solace-vmr | wc -l`

 if [ "$VM_RUNNING_FOUND_COUNT" -eq "1" ]; then

   echo "Will stop monit jobs if any are running"
   bosh ssh $VM_JOB "sudo /var/vcap/bosh/bin/monit stop all" 

   RUNNING_COUNT=`bosh ssh $VM_JOB "sudo /var/vcap/bosh/bin/monit summary" | grep running | wc -l`
   MAX_WAIT=60
   while [ "$RUNNING_COUNT" -gt "0" ] && [ "$MAX_WAIT" -gt "0" ]; do
   	echo "Waiting for monit to finish shutdown - found $RUNNING_COUNT still running"
	sleep 5
        let MAX_WAIT=MAX_WAIT-5
        RUNNING_COUNT=`bosh ssh $VM_JOB "sudo /var/vcap/bosh/bin/monit summary " | grep running | wc -l`
   done

 fi

}

function deleteDeploymentAndRelease() {

 DEPLOYMENT_FOUND_COUNT=`bosh deployments | grep $DEPLOYMENT_NAME | wc -l`
 RELEASE_FOUND_COUNT=`bosh releases | grep solace-vmr | wc -l`

 if [ "$DEPLOYMENT_FOUND_COUNT" -eq "1" ]; then
    # Delete the deployment 
    echo "Deleting deployment $DEPLOYMENT_NAME"
    echo "yes" | bosh delete deployment $DEPLOYMENT_NAME
 else
   echo "No deployment found."
 fi

 if [ "$RELEASE_FOUND_COUNT" -eq "1" ]; then
    # solace-vmr
    echo "Deleting release solace-vmr"
    echo "yes" | bosh delete release solace-vmr
 else
    echo "No release found"
 fi

}

# Generates a bosh-lite manifest and prints it to stdout
function generateManifest() {

local VMR_JOB_NAME_ARG=""
local CERT_ARG=''
if [ -n "$SERIALIZED_VMR_JOB_NAME" ]; then
    VMR_JOB_NAME_ARG="-j $SERIALIZED_VMR_JOB_NAME"
fi
if [ "$CERT_ENABLED" == true ]; then
    CERT_ARG="--cert"
fi
export PREPARE_MANIFEST_COMMAND="python3 ${MY_BIN_HOME}/prepareManifest.py $CERT_ARG $VMR_JOB_NAME_ARG -w $WORKSPACE -p $SERIALIZED_POOL_NAME -i $SERIALIZED_NUM_INSTANCES -d $TEMPLATE_DIR -n $DEPLOYMENT_NAME"
>&2 echo "Running: $PREPARE_MANIFEST_COMMAND"
$PREPARE_MANIFEST_COMMAND
}

function prepareManifest() {

generateManifest > $MANIFEST_FILE

if [ $? -ne 0 ]; then
 >&2 echo
 >&2 echo "Preparing the Manifest failed."
 exit 1
fi 
}

function resolveConflictsAndRegenerateManifest() {
 python3 ${MY_BIN_HOME}/adjustManifest.py -m $MANIFEST_FILE -w $WORKSPACE -d $TEMPLATE_DIR -n $DEPLOYMENT_NAME
}

function build() {

echo "Will build the BOSH Release (May take some time)"

./build.sh | tee -a $LOG_FILE

if [ $? -ne 0 ]; then
 >&2 echo
 >&2 echo "Build failed."
 exit 1
fi 

}

function uploadAndDeployRelease() {

SOLACE_VMR_BOSH_RELEASE_FILE=`ls $WORKSPACE/releases/solace-vmr-*.tgz | tail -1`
RELEASE_FOUND_COUNT=`bosh releases | grep solace-vmr | wc -l`

echo "in function uploadAndDeployRelease. SOLACE_VMR_BOSH_RELEASE_FILE: $SOLACE_VMR_BOSH_RELEASE_FILE"

if [ -f $SOLACE_VMR_BOSH_RELEASE_FILE ]; then

 targetBosh

 if [ "$RELEASE_FOUND_COUNT" -eq "0" ]; then
  echo "Will upload release $SOLACE_VMR_BOSH_RELEASE_FILE"

  bosh upload release $SOLACE_VMR_BOSH_RELEASE_FILE | tee -a $LOG_FILE
 else
  echo "releases solace-vmr already exists. Skipping release upload..."
 fi

 echo "Calling bosh deployment"
 echo "MANIFEST_FILE=$MANIFEST_FILE"

 bosh deployment $MANIFEST_FILE | tee -a $LOG_FILE 

 for I in ${!POOL_NAME[@]}; do
  echo "Will deploy VMR with name ${VMR_JOB_NAME[I]} , having POOL_NAME: ${POOL_NAME[I]}, and using ${SOLACE_DOCKER_IMAGE_NAME[I]}" | tee -a $LOG_FILE
 done

 echo "yes" | bosh deploy | tee -a $LOG_FILE
 bosh vms
 DEPLOYMENT_FOUND_COUNT=`bosh deployments | grep $DEPLOYMENT_NAME | wc -l`
 if [ "$DEPLOYMENT_FOUND_COUNT" -eq "0" ]; then
   echo "bosh did not find any deployments - deployment likely failed"
   exit 1
 fi

else
 >&2 echo "Could not locate a release file in $WORKSPACE/releases/solace-vmr-*.tgz"
 exit 1
fi

}

# This sets up the environment variables that are normally set by the tile.
# e.g. SOLACE_VMR_MEDIUM_HA_VMR_HOSTS: ["192.168.101.16", "192.168.101.17", "192.168.101.18"]
# It sets the environment on the service broker and restages it.

function setupServiceBrokerEnvironment() {
  echo "In setupServiceBrokerEnvironment - doing cf target..."
  cf target -o solace -s solace-messaging
  setServiceBrokerSimpleProperty starting_port STARTING_PORT
  setServiceBrokerSimpleProperty admin_password VMR_ADMIN_PASSWORD
  setServiceBrokerVMRHostsEnvironment
  setServiceBrokerSyslogEnvironment
  setServiceBrokerLDAPEnvironment
  setServiceBrokerTLSEnvironment

  echo restaging message broker...
  cf restage solace-messaging
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
  VALUE_FROM_MANIFEST=`cat $MANIFEST_FILE | shyaml get-value jobs.0.properties.$MANIFEST_PROPERTY_NAME`
  cf set-env solace-messaging $SB_ENV_NAME $VALUE_FROM_MANIFEST
}

function resetServiceBrokerTLSEnvironment() {

  cf unset-env solace-messaging TLS_CONFIG

}


function setServiceBrokerTLSEnvironment() {

  tls_config=`cat $MANIFEST_FILE | shyaml get-value jobs.0.properties.tls_config "disabled" `
  echo cf set-env solace-messaging TLS_CONFIG "{'value' : '$tls_config'}"
  cf set-env solace-messaging TLS_CONFIG "{'value' : '$tls_config'}"

}
 
function resetServiceBrokerLDAPEnvironment() {
 
  cf unset-env solace-messaging LDAP_CONFIG 
  cf unset-env solace-messaging MANAGEMENT_ACCESS_AUTH_SCHEME 
  cf unset-env solace-messaging APPLICATION_ACCESS_AUTH_SCHEME 

}

function setServiceBrokerLDAPEnvironment() {

  ldap_config=`cat $MANIFEST_FILE | shyaml get-value jobs.0.properties.ldap_config "disabled" `
  management_access_auth_scheme=`cat $MANIFEST_FILE | shyaml get-value jobs.0.properties.management_access_auth_scheme "vmr_internal" `
  application_access_auth_scheme=`cat $MANIFEST_FILE | shyaml get-value jobs.0.properties.application_access_auth_scheme "vmr_internal" `

  echo cf set-env solace-messaging LDAP_CONFIG "{'value' : '$ldap_config'}"
  cf set-env solace-messaging LDAP_CONFIG "{'value' : '$ldap_config'}"

  echo cf set-env solace-messaging MANAGEMENT_ACCESS_AUTH_SCHEME "{'value' : '$management_access_auth_scheme'}"
  cf set-env solace-messaging MANAGEMENT_ACCESS_AUTH_SCHEME "{'value' : '$management_access_auth_scheme'}"

  echo cf set-env solace-messaging APPLICATION_ACCESS_AUTH_SCHEME "{'value' : '$application_access_auth_scheme'}"
  cf set-env solace-messaging APPLICATION_ACCESS_AUTH_SCHEME "{'value' : '$application_access_auth_scheme'}"

}
 
function setServiceBrokerVMRHostsEnvironment() {
  JOBS=`cat $MANIFEST_FILE | shyaml -y get-values-0 jobs`
  POOL_NAMES=$(py "getPoolNames")

  for POOL in ${POOL_NAMES[@]}; do
    ENV_NM=`echo $POOL | tr '[:lower:]-' '[:upper:]_'`
    ENV_NAME=SOLACE_VMR_${ENV_NM}_HOSTS

    JOB=`py "getManifestJobByName" $MANIFEST_FILE $POOL`
    if [ "$(echo -n $JOB | wc -c)" -gt "0" ]; then
      IPS=$(echo -n $JOB | shyaml get-values networks.0.static_ips)
      IFS=' ' read -r -a IPS <<< $IPS
      IPSTR="[\"$(echo $(IFS=','; echo "${IPS[*]}") | sed s/,/\",\"/g)\"]"
    else
      IPSTR="[]"
    fi

    echo setting environment variable $ENV_NAME to "$IPSTR"

    cf set-env solace-messaging $ENV_NAME "$IPSTR"
  done
}

function resetServiceBrokerVMRHostsEnvironment() {
  for POOL in ${POOL_NAME[@]}; do
    ENV_NM=`echo $POOL | tr '[:lower:]-' '[:upper:]_'`
    ENV_NAME=SOLACE_VMR_${ENV_NM}_HOSTS
    IPSTR='[]'

    echo setting environment variable $ENV_NAME to "$IPSTR"

    cf set-env solace-messaging $ENV_NAME "$IPSTR"
  done
}

function setServiceBrokerSyslogEnvironment() {
  echo "Setting SYSLOG env variables on Service Broker..." 
  SYSLOG_CONFIG=`cat $MANIFEST_FILE | shyaml get-value jobs.0.properties.syslog_config "disabled"`
  if [ "$SYSLOG_CONFIG" == "enabled" ]; then
    SYSLOG_HOSTNAME=`cat $MANIFEST_FILE | shyaml get-value jobs.0.properties.syslog_hostname ""`
    SYSLOG_PORT=`cat $MANIFEST_FILE | shyaml get-value jobs.0.properties.syslog_port "514"`
    SYSLOG_PROTOCOL=`cat $MANIFEST_FILE | shyaml get-value jobs.0.properties.syslog_protocol "udp"`
    SYSLOG_BROKER_AND_AGENT_LOGS=`cat $MANIFEST_FILE | shyaml get-value jobs.0.properties.syslog_broker_and_agent_logs "false"`
    cf set-env solace-messaging SYSLOG_CONFIG "{'value':'$SYSLOG_CONFIG', 'selected_option':{'syslog_hostname':'$SYSLOG_HOSTNAME','syslog_port':$SYSLOG_PORT,'syslog_protocol':'$SYSLOG_PROTOCOL','syslog_vmr_command_logs':true,'syslog_vmr_event_logs':true,'syslog_vmr_system_logs':true,'syslog_broker_and_agent_logs':$SYSLOG_BROKER_AND_AGENT_LOGS}}"
  else
    cf set-env solace-messaging SYSLOG_CONFIG "{'value':'$SYSLOG_CONFIG', 'selected_option':{}}"
  fi
}

function resetServiceBrokerSyslogEnvironment() {
  cf set-env solace-messaging SYSLOG_CONFIG "{'value':'disabled','selected_option':{}}"
}


###################### Common parameter processing ########################


export BASIC_USAGE_PARAMS="-p [Shared-VMR|Large-VMR|Community-VMR|Medium-HA-VMR|Large-HA-VMR] -n (To not use a self-signed certificate)"

CMD_NAME=`basename $0`

function showUsage() {
  echo
  echo "Usage: $CMD_NAME $BASIC_USAGE_PARAMS " $1
  echo
}

function missingRequired() {
  >&2 echo
  >&2 echo "Some required argument(s) were missing."
  >&2 echo 

  showUsage
  exit 1
}

# if (($# == 0)); then
#   missingRequired
# fi

while getopts :m:p:hna opt; do
    case $opt in
      m)
        #Reserved for bosh_deploy
        ;;
      p)
        OPT_VALS=(${OPTARG//:/ })

        if printf '%s\n' "${POOL_NAME[@]}" | grep -x -q ${OPT_VALS[0]}; then
            >&2 echo
            >&2 echo "Operation conflict: Pool name ${OPTARG[0]} cannot be specified more than once" >&2
            >&2 echo
            showUsage
            exit 1
        elif [ -n "${OPT_VALS[1]}" ] && ((echo "${OPT_VALS[1]}" | grep -qE "[^0-9]") || [ ${OPT_VALS[1]} -le 0 ]); then
            >&2 echo
            >&2 echo "Invalid option: \"${OPT_VALS[1]}\". Number of instances for a VMR can only be a non-zero positive integer" >&2
            >&2 echo
            showUsage
            exit 1
        fi

        POOL_NAME+=(${OPT_VALS[0]})
        if [ -z ${OPT_VALS[1]} ]; then
            NUM_INSTANCES+=(-1)
        else
            NUM_INSTANCES+=(${OPT_VALS[1]})
        fi
      ;;
      n)
        export CERT_ENABLED=false
      ;;
      a)
        #Reserved for bosh_cleanup
        ;;
      h)
        showUsage
        exit 0
      ;;
      \?)
      >&2 echo
      >&2 echo "Invalid option: -$OPTARG" >&2
      >&2 echo
      showUsage
      exit 1
      ;;
  esac
done

missing_required=0

if ((missing_required)); then
   missingRequired
fi

## Derived and default values

if [ -z $POOL_NAME ]; then
    POOL_NAME="Shared-VMR"
fi

if [ -z $CERT_ENABLED ]; then
    export CERT_ENABLED=true
fi

for i in "${!POOL_NAME[@]}"; do
    VMR_JOB_NAME+=(${POOL_NAME[i]})

    if [ "$(py "isValidPoolName" "${POOL_NAME[i]}")" -eq 0 ]; then
        >&2 echo
        >&2 echo "Sorry, I don't seem to know about pool name: ${POOL_NAME[i]}"
        >&2 echo
        showUsage
        exit 1
    fi

    SOLACE_DOCKER_IMAGE_NAME+=($(py "getSolaceDockerImageName" ${POOL_NAME[i]}))

    if [ -z ${NUM_INSTANCES[i]} ] || [ ${NUM_INSTANCES[i]} -eq -1 ]; then
        NUM_INSTANCES[$i]=1
    fi

    if [ "$(py "getHaEnabled" ${POOL_NAME[i]})" -eq "1" ]; then
        HA_ENABLED+=(true)
        NUM_INSTANCES[$i]=$((${NUM_INSTANCES[i]} * 3))
    else
        HA_ENABLED+=(false)
    fi

    INSTANCE_COUNT=0
    while [ "$INSTANCE_COUNT" -lt "${NUM_INSTANCES[i]}" ]; do
        VM_JOB+=("${VMR_JOB_NAME[i]}/$INSTANCE_COUNT")
        let INSTANCE_COUNT=INSTANCE_COUNT+1
    done
done

echo "    Deployment     $DEPLOYMENT_NAME"
echo

for i in "${!POOL_NAME[@]}"; do
    echo "    VMR JOB NAME   ${VMR_JOB_NAME[i]}"
    echo "    CERT_ENABLED   $CERT_ENABLED"
    echo "    HA_ENABLED     ${HA_ENABLED[i]}"
    echo "    NUM_INSTANCES  ${NUM_INSTANCES[i]}"

    INSTANCE_COUNT=0
    while [ "$INSTANCE_COUNT" -lt "${NUM_INSTANCES[i]}" ];  do
         echo "    VM/$INSTANCE_COUNT           ${VMR_JOB_NAME[i]}/$INSTANCE_COUNT"
         let INSTANCE_COUNT=INSTANCE_COUNT+1
    done
    echo
done

## Serialize settings
export SERIALIZED_VMR_JOB_NAME=$(IFS=' '; echo "${VMR_JOB_NAME[*]}")
export SERIALIZED_POOL_NAME=$(IFS=' '; echo "${POOL_NAME[*]}")
export SERIALIZED_NUM_INSTANCES=$(IFS=' '; echo "${NUM_INSTANCES[*]}")

