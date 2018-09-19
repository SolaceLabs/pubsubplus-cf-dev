#!/usr/bin/env bash

####################################### GLOBALS ###########################################

SHARED_PLAN="af308299-102f-47a3-acb0-7de72be192bf"
SHARED_POOL_NAME="enterprise-shared"
LARGE_PLAN="9bd51219-9cee-4570-99ab-ebe80d82c854"
LARGE_POOL_NAME="enterprise-large"
MEDIUM_HA_PLAN="9f57fa1c-7bb1-4a48-a651-d0c560fb5730"
MEDIUM_HA_POOL_NAME="enterprise-medium-ha"
LARGE_HA_PLAN="6a833e3f-3a24-419d-94d9-4bb38dc51f04"
LARGE_HA_POOL_NAME="enterprise-large-ha"

export SOLACE_SERVICE_NAME="solace-pubsub"

export PAIRS_PARAM="includeMonitor=false"
export MONITOR_PARAM="includeBackup=false&includePrimary=false"
export PRIMARY_PARAM="includeMonitor=false&includeBackup=false"
export BACKUP_PARAM="includeMonitor=false&includePrimary=false"

export SB_ORG=${SB_ORG:-"solace"}
export SB_SPACE=${SB_SPACE:-"solace-broker"}

export TEST_ORG=${TEST_ORG:-"solace-test"}
export TEST_SPACE=${TEST_SPACE:-"test"}

export SYSTEM_DOMAIN=${SYSTEM_DOMAIN:-"bosh-lite.com"}
export CF_ADMIN_PASSWORD=${CF_ADMIN_PASSWORD:-"admin"}
export UAA_ADMIN_CLIENT_SECRET=${UAA_ADMIN_CLIENT_SECRET:-"admin-client-secret"}

export JAVA_BUILD_PACK_VERSION=${JAVA_BUILD_PACK_VERSION:-"3.13"}

####################################### FUNCTIONS ###########################################

function log() {
 echo ""
 echo `date` $1
}


function confirmServiceBrokerRunning() {

    getServiceBrokerDetails

    ## Lookup again to confirm and use for message
    SB_RUNNING=`cf apps | grep -v Getting | grep solace-pubsub-broker | sort | tail -1  | grep started | wc -l`
    if [ "$SB_RUNNING" -eq "1" ]; then
      log "confirmServiceBrokerRunning : Service Broker is running"
    else
      log "confirmServiceBrokerRunning : Service Broker is NOT running"
    fi
    ## Will cause an exit in testing ( set -e )
    cf apps | grep -v Getting | grep solace-pubsub-broker | sort | tail -1 | grep started
    export SB_APP=`cf apps | grep -v Getting | grep solace-pubsub-broker | sort | tail -1 | grep started | awk '{ print $1}'`
}

function getServiceBrokerDetails() {
 
 switchToServiceBrokerTarget

 SB_FOUND=`cf apps | grep -v Getting | grep solace-pubsub-broker | sort | tail -1 | wc -l`
 SB_RUNNING=`cf apps | grep -v Getting | grep solace-pubsub-broker | sort | tail -1  | grep started | wc -l`

 if [ "$SB_FOUND" -eq "1" ]; then
  ## Capture a few details from the service broker
   export SB_APP=`cf apps | grep -v Getting | grep solace-pubsub-broker | sort | tail -1  | awk '{ print $1}'`
   export SB_URL=`cf apps | grep -v Getting | grep solace-pubsub-broker | sort | tail -1  | grep $SB_APP | awk '{ print $6}'`
   export SECURITY_USER_NAME=`cf env $SB_APP | grep SECURITY_USER_NAME | awk '{ print $2}'`
   export SECURITY_USER_PASSWORD=`cf env $SB_APP | grep SECURITY_USER_PASSWORD | awk '{ print $2}'`
   export VMR_SUPPORT_PASSWORD=`cf env $SB_APP | grep VMR_SUPPORT_PASSWORD | awk '{ print $2}'`
   export VMR_SUPPORT_USER=`cf env $SB_APP | grep VMR_SUPPORT_USER | awk '{ print $2}'`
   export VMR_ADMIN_PASSWORD=`cf env $SB_APP  | grep VMR_ADMIN_PASSWORD | awk '{print $2}'`
   export VMR_ADMIN_USER=`cf env $SB_APP  | grep VMR_ADMIN_USER | awk '{print $2}'`
   export STARTING_PORT=`cf env $SB_APP | grep STARTING_PORT | awk '{print $2}'`
   export SB_BASE=$SECURITY_USER_NAME:$SECURITY_USER_PASSWORD@$SB_URL
 fi

 if [ "$SB_RUNNING" -eq "1" ]; then
    lookupServiceBrokerVMRs
 fi


}

function lookupServiceBrokerDetails() {

 getServiceBrokerDetails

 if [ "$SB_FOUND" -eq "1" ]; then
 log "ServiceBroker $SB_APP: http://${SB_URL}"
 log "Servicebroker URL BASE: ${SB_BASE} "

 if [ "$SB_RUNNING" -eq "1" ]; then
    lookupServiceBrokerVMRs
    log "Servicebroker LARGE_LIST: ${LARGE_LIST} "
    log "Servicebroker SHARED_LIST: ${SHARED_LIST} "
    log "Servicebroker LARGE_HA_LIST: ${LARGE_HA_LIST} "
    log "Servicebroker LARGE_HA_PAIRS_LIST: ${LARGE_HA_PAIRS_LIST} "
    log "Servicebroker LARGE_HA_PRIMARY_LIST: ${LARGE_HA_PRIMARY_LIST} "
    log "Servicebroker LARGE_HA_BACKUP_LIST: ${LARGE_HA_BACKUP_LIST} "
    log "Servicebroker LARGE_HA_MONITOR_LIST: ${LARGE_HA_MONITOR_LIST} "
    log "Servicebroker MEDIUM_HA_LIST: ${MEDIUM_HA_LIST} "
    log "Servicebroker MEDIUM_HA_PAIRS_LIST: ${MEDIUM_HA_PAIRS_LIST} "
    log "Servicebroker MEDIUM_HA_PRIMARY_LIST: ${MEDIUM_HA_PRIMARY_LIST} "
    log "Servicebroker MEDIUM_HA_BACKUP_LIST: ${MEDIUM_HA_BACKUP_LIST} "
    log "Servicebroker MEDIUM_HA_MONITOR_LIST: ${MEDIUM_HA_MONITOR_LIST} "
    log "Servicebroker ALL_LIST: ${ALL_LIST} "
    getServiceBrokerRouterInventory
    log "Servicebroker AvailabilityZones ${AVAILABILITY_ZONE_COUNT} : ${AVAILABILITY_ZONES} "
 else
    log "Servicebroker $SB_APP is not running"
 fi

 else
   log "Could not find solace-pubsub-broker in the current cloud-foundry environment"
 fi

}

function lookupServiceBrokerVMRs() {
 
 INFO_DATA=`curl -sX GET $SB_BASE/info` 

 # Pre 1.1.0 backwards compatibility
 if [ "$(echo $INFO_DATA | jq length)" == "0" ]; then
  deprecated_lookupServiceBrokerVMRs
  return
 fi

 ROUTERS_DATA=`echo $INFO_DATA | jq -c ".messageRouters"`
  
 export ALL_LIST=$(formatVMRList $(echo $ROUTERS_DATA       | jq -c '.[] | .sshLink'))
 export SHARED_LIST=$(formatVMRList $(echo $ROUTERS_DATA    | jq -c 'map(select(.poolName == "enterprise-shared"))'    | jq -c '.[] | .sshLink'))
 export LARGE_LIST=$(formatVMRList $(echo $ROUTERS_DATA     | jq -c 'map(select(.poolName == "enterprise-large"))'     | jq -c '.[] | .sshLink'))
 
 export MEDIUM_HA_LIST=$(formatVMRList $(echo $ROUTERS_DATA | jq -c 'map(select(.poolName == "enterprise-medium-ha"))' | jq -c '.[] | .sshLink'))
 export MEDIUM_HA_PAIRS_LIST=$(formatVMRList $(echo $ROUTERS_DATA   | jq -c 'map(select(.poolName == "enterprise-medium-ha" and .role != "monitor"))' | jq -c '.[] | .sshLink'))
 export MEDIUM_HA_PRIMARY_LIST=$(formatVMRList $(echo $ROUTERS_DATA | jq -c 'map(select(.poolName == "enterprise-medium-ha" and .role == "primary"))' | jq -c '.[] | .sshLink'))
 export MEDIUM_HA_BACKUP_LIST=$(formatVMRList $(echo $ROUTERS_DATA  | jq -c 'map(select(.poolName == "enterprise-medium-ha" and .role == "backup"))'  | jq -c '.[] | .sshLink'))
 export MEDIUM_HA_MONITOR_LIST=$(formatVMRList $(echo $ROUTERS_DATA | jq -c 'map(select(.poolName == "enterprise-medium-ha" and .role == "monitor"))' | jq -c '.[] | .sshLink'))
 
 export LARGE_HA_LIST=$(formatVMRList $(echo $ROUTERS_DATA         | jq -c 'map(select(.poolName == "enterprise-large-ha"))'                        | jq -c '.[] | .sshLink'))
 export LARGE_HA_PAIRS_LIST=$(formatVMRList $(echo $ROUTERS_DATA   | jq -c 'map(select(.poolName == "enterprise-large-ha" and .role != "monitor"))' | jq -c '.[] | .sshLink'))
 export LARGE_HA_PRIMARY_LIST=$(formatVMRList $(echo $ROUTERS_DATA | jq -c 'map(select(.poolName == "enterprise-large-ha" and .role == "primary"))' | jq -c '.[] | .sshLink'))
 export LARGE_HA_BACKUP_LIST=$(formatVMRList $(echo $ROUTERS_DATA  | jq -c 'map(select(.poolName == "enterprise-large-ha" and .role == "backup"))'  | jq -c '.[] | .sshLink'))
 export LARGE_HA_MONITOR_LIST=$(formatVMRList $(echo $ROUTERS_DATA | jq -c 'map(select(.poolName == "enterprise-large-ha" and .role == "monitor"))' | jq -c '.[] | .sshLink'))

}

#Deprecated 1.1.0
function deprecated_lookupServiceBrokerVMRs() {

 export ALL_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links`
 export SHARED_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$SHARED_PLAN`
 export LARGE_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_PLAN`
 export MEDIUM_HA_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN`
 export MEDIUM_HA_PAIRS_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN?$PAIRS_PARAM`
 export MEDIUM_HA_PRIMARY_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN?$PRIMARY_PARAM`
 export MEDIUM_HA_BACKUP_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN?$BACKUP_PARAM`
 export MEDIUM_HA_MONITOR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN?$MONITOR_PARAM`
 export LARGE_HA_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN`
 export LARGE_HA_PAIRS_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN?$PAIRS_PARAM`
 export LARGE_HA_PRIMARY_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN?$PRIMARY_PARAM`
 export LARGE_HA_BACKUP_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN?$BACKUP_PARAM`
 export LARGE_HA_MONITOR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN?$MONITOR_PARAM`

}

function formatVMRList() {
  # Echos formatted results from jq
  echo `echo "$@" | tr -d "\"\n\r" | tr " " ","`
}

function showServiceBrokerVMRs() {

 log "ServiceBroker: VMR Lists "
 echo "ALL_LIST=${ALL_LIST}"
 echo "SHARED_LIST=${SHARED_LIST}"
 echo "LARGE_LIST=${LARGE_LIST}"
 echo "MEDIUM_HA_LIST=${MEDIUM_HA_LIST}"
 echo "MEDIUM_HA_PAIRS_LIST=${MEDIUM_HA_PAIRS_LIST}"
 echo "MEDIUM_HA_PRIMARY_LIST=${MEDIUM_HA_PRIMARY_LIST}"
 echo "MEDIUM_HA_BACKUP_LIST=${MEDIUM_HA_BACKUP_LIST}"
 echo "MEDIUM_HA_MONITOR_LIST=${MEDIUM_HA_MONITOR_LIST}"
 echo "LARGE_HA_LIST=${LARGE_HA_LIST}"
 echo "LARGE_HA_PAIRS_LIST=${LARGE_HA_PAIRS_LIST}"
 echo "LARGE_HA_PRIMARY_LIST=${LARGE_HA_PRIMARY_LIST}"
 echo "LARGE_HA_BACKUP_LIST=${LARGE_HA_BACKUP_LIST}"
 echo "LARGE_HA_MONITOR_LIST=${LARGE_HA_MONITOR_LIST}"

}

function checkServiceBrokerRepoStats() {

 log "ServiceBroker: Repo stats $1"
 curl -sX GET $SB_BASE/solace/status/repositories -H "Content-Type: application/json;charset=UTF-8"

 # TODO: Add some parameter driven assertions later

}

function checkServiceBrokerServicePlanStats() {

 # Just output for logging for now
 log "ServiceBroker: service plan stats $1"
 curl -sX GET $SB_BASE/solace/status -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: shared plan stats"
 curl -sX GET $SB_BASE/solace/status/services/$SOLACE_SERVICE_NAME/plans/$SHARED_PLAN -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: large plan stats"
 curl -sX GET $SB_BASE/solace/status/services/$SOLACE_SERVICE_NAME/plans/$LARGE_PLAN -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: medium-ha plan stats"
 curl -sX GET $SB_BASE/solace/status/services/$SOLACE_SERVICE_NAME/plans/$MEDIUM_HA_PLAN -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: large-ha plan stats"
 curl -sX GET $SB_BASE/solace/status/services/$SOLACE_SERVICE_NAME/plans/$LARGE_HA_PLAN -H "Content-Type: application/json;charset=UTF-8"

 getServiceBrokerMessageRoutersSummary $1

 # TODO: Add some parameter driven assertions later

}

function getServiceBrokerRouterInventory() {

  export INVENTORY_RESPONSE=$(curl -sX GET $SB_BASE/solace/resources/solace_message_routers/inventory -H "Content-Type: application/json;charset=UTF-8")
  export AVAILABILITY_ZONES=$( echo $INVENTORY_RESPONSE | jq ".routerInventory[].haGroups[].availabilityZones"  | grep -v "\[" | grep -v "\]" | sort | uniq )
  export AVAILABILITY_ZONE_COUNT=$( echo $AVAILABILITY_ZONES | tr ',' '\n' | wc -l )

}

function showServiceBrokerRouterInventory() {

  getServiceBrokerRouterInventory

  log "ServiceBroker inventory view"
  echo
  echo $INVENTORY_RESPONSE
  echo 
  echo "Availability Zones: $AVAILABILITY_ZONE_COUNT"
  echo $AVAILABILITY_ZONES
  echo
}

function getServiceBrokerMessageRoutersSummary() {

 log "ServiceBroker: Message Routers Summary $1"
 echo
 curl -sX GET $SB_BASE/solace/resources/solace_message_routers/summary -H "Content-Type: application/json;charset=UTF-8"
 echo

}

function getServiceBrokerRouters() {

 log "ServiceBroker: Message Routers Details"
 echo
 export SERVICE_BROKER_DETAILS=`curl -sX GET $SB_BASE/solace/resources/solace_message_routers/details -H "Content-Type: application/json;charset=UTF-8"`
 echo
 
 # Show summary after the details
 getServiceBrokerMessageRoutersSummary

}

####################################### TEST FUNCTIONS ###########################################

function switchToOrgAndSpace() {

 FOUND_ORG=0
 for ORG in $(cf orgs | grep -v "Getting" | grep -v "^name"); do
    if [ "$ORG" == "$1" ]; then
       FOUND_ORG=1
    fi
 done

 if [ "$FOUND_ORG" -eq "0" ]; then
   log "Will create and target org: $1"
   cf create-org $1 > /dev/null
 fi

 cf target -o $1 > /dev/null

 FOUND_SPACE=0
 for SPACE in $(cf spaces | grep -v "Getting" | grep -v "^name"); do
    if [ "$SPACE" == "$2" ]; then
       FOUND_SPACE=1
    fi
 done

 if [ "$FOUND_SPACE" -eq "0" ]; then
   log "Will create and target space: $2"
   cf create-space $2 > /dev/null
 fi

 cf target -o $1 -s $2 > /dev/null
 if [ $? -ne 0 ]; then
    log "FAILED: cf target -o $1 -s $2"
 fi

}

function switchToTestOrgAndSpace() {

 switchToOrgAndSpace $TEST_ORG $TEST_SPACE

}

function enableAndShowInMarketPlace() {

 ## Checking Marketplace
 log "Enabling access to the Solace Service Broker provided service: $SOLACE_SERVICE_NAME"
 cf enable-service-access $SOLACE_SERVICE_NAME

 log "Marketplace:"
 cf m

 #todo: Need to install tile for this check to work (enable_global_access_to_plans)
 # Rely on grep's non-0 exit code to fail script

 log "Checking marketplace for solace service: $SOLACE_SERVICE_NAME"
 cf m | grep $SOLACE_SERVICE_NAME
 log "Checking marketplace for solace service plan: shared"
 cf m | grep shared 
 log "Checking marketplace for solace service plan: large"
 cf m | grep large
 log "Checking marketplace for solace service plan: medium-ha"
 cf m | grep medium-ha
 log "Checking marketplace for solace service plan: large-ha"
 cf m | grep large-ha

 log "Checking marketplace for solace service plan: shared, free"
 cf m -s $SOLACE_SERVICE_NAME | grep shared | grep free
 log "Checking marketplace for solace service plan: large, free"
 cf m -s $SOLACE_SERVICE_NAME | grep -v large-ha | grep large | grep free
 log "Checking marketplace for solace service plan: medium-ha, free"
 cf m -s $SOLACE_SERVICE_NAME | grep medium-ha | grep free
 log "Checking marketplace for solace service plan: large-ha, free"
 cf m -s $SOLACE_SERVICE_NAME | grep large-ha | grep free

}

function switchToServiceBrokerTarget() {
        switchToOrgAndSpace $SB_ORG $SB_SPACE
}

function restartServiceBroker() {
 	switchToServiceBrokerTarget
	cf restart $SB_APP
}


function cf_login() {
 export CF_ACCESS=0 
 cf api https://api.$SYSTEM_DOMAIN --skip-ssl-validation > /dev/null
 if [ $? -eq 0 ]; then
    cf auth admin $CF_ADMIN_PASSWORD > /dev/null
    if [ $? -eq 0 ]; then
       export CF_ACCESS=1 
    else
       export CF_ACCESS=0 
    fi
 else
   export CF_ACCESS=0 
 fi

}




function addBuildPack() {

   cf target -o system
   FOUND_BUILDPACK=$( cf buildpacks | grep java_buildpack_offline | grep java-buildpack-offline-v${BUILD_PACK_VERSION}.zip | wc -l )
   if [ "$FOUND_BUILDPACK" -eq "0" ]; then
      echo "Will make a new buildpack and add to pcfdev"
      ( 
        cd $WORKSPACE
	if [ ! -f java-buildpack-${JAVA_BUILD_PACK_VERSION}.tgz  ]; then
           echo "Downloading java-buildpack-${JAVA_BUILD_PACK_VERSION}.tgz"
           curl -L -X GET https://github.com/cloudfoundry/java-buildpack/archive/v${JAVA_BUILD_PACK_VERSION}.tar.gz -o java-buildpack-${JAVA_BUILD_PACK_VERSION}.tgz -s
        fi
	if [ -d java-buildpack-${JAVA_BUILD_PACK_VERSION} ]; then
		rm -rf java-buildpack-${JAVA_BUILD_PACK_VERSION}
        fi
	tar -xzf java-buildpack-${JAVA_BUILD_PACK_VERSION}.tgz
	cd java-buildpack-${JAVA_BUILD_PACK_VERSION}
	if [ -f $WORKSPACE/trusted.crt ]; then
		echo "Will add a CA trusted certificate to the JVM"
		mkdir -p resources/open_jdk_jre/lib/security
		keytool -keystore resources/open_jdk_jre/lib/security/cacerts -storepass changeit --importcert -noprompt -alias SolaceDevTrustedCert -file $WORKSPACE/trusted.crt
	fi
	bundle install
	bundle exec rake clean package OFFLINE=true PINNED=true
	if [ -f build/java-buildpack-offline-v${JAVA_BUILD_PACK_VERSION}.zip ]; then
	   cf create-buildpack  java_buildpack_offline build/java-buildpack-offline-v${JAVA_BUILD_PACK_VERSION}.zip 0 --enable
	else
	   echo "Did not find expected build pack file build/java-buildpack-offline-v${JAVA_BUILD_PACK_VERSION}.zip"
	   exit 1
	fi
      )
   else
	echo "Found java build pack there already :"
   	cf buildpacks | grep java_buildpack_offline | grep java-buildpack-offline-v${JAVA_BUILD_PACK_VERSION}.zip 
   fi

}


