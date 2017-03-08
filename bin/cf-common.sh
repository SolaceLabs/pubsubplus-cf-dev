#!/usr/bin/env bash

####################################### GLOBALS ###########################################

SHARED_PLAN="af308299-102f-47a3-acb0-7de72be192bf"
SHARED_POOL_NAME="Shared-VMR"
LARGE_PLAN="9bd51219-9cee-4570-99ab-ebe80d82c854"
LARGE_POOL_NAME="Large-VMR"
COMMUNITY_PLAN="c1589346-ca21-4d64-8c31-330d5fb07a58"
COMMUNITY_POOL_NAME="Community-VMR"
MEDIUM_HA_PLAN="9f57fa1c-7bb1-4a48-a651-d0c560fb5730"
MEDIUM_HA_POOL_NAME="Medium-HA-VMR"
LARGE_HA_PLAN="6a833e3f-3a24-419d-94d9-4bb38dc51f04"
LARGE_HA_POOL_NAME="Large-HA-VMR"

export PAIRS_PARAM="includeMonitor=false"
export MONITOR_PARAM="includeBackup=false&includePrimary=false"
export PRIMARY_PARAM="includeMonitor=false&includeBackup=false"
export BACKUP_PARAM="includeMonitor=false&includePrimary=false"

export SB_ORG=${SB_ORG:-"solace"}
export SB_SPACE=${SB_SPACE:-"solace-messaging"}

export TEST_ORG=${TEST_ORG:-"solace-test"}
export TEST_SPACE=${TEST_SPACE:-"test"}

####################################### FUNCTIONS ###########################################

function log() {
 echo ""
 echo `date` $1
}


function confirmServiceBrokerRunning() {
    lookupServiceBrokerDetails
    ## Lookup again to confirm and use for message
    SB_RUNNING=`cf apps | grep -v Getting | grep solace-messaging | sort | tail -1  | grep started | wc -l`
    if [ "$SB_RUNNING" -eq "1" ]; then
      log "confirmServiceBrokerRunning : Service Broker is running"
    else
      log "confirmServiceBrokerRunning : Service Broker is NOT running"
    fi
    ## Will cause an exit in testing ( set -e )
    cf apps | grep -v Getting | grep solace-messaging | sort | tail -1 | grep started
    export SB_APP=`cf apps | grep -v Getting | grep solace-messaging | sort | tail -1 | grep started | awk '{ print $1}'`
}

function lookupServiceBrokerDetails() {
 
 switchToServiceBrokerTarget

 SB_FOUND=`cf apps | grep -v Getting | grep solace-messaging | sort | tail -1 | wc -l`
 SB_RUNNING=`cf apps | grep -v Getting | grep solace-messaging | sort | tail -1  | grep started | wc -l`
 if [ "$SB_FOUND" -eq "1" ]; then


## Capture a few details from the service broker
 export SB_APP=`cf apps | grep -v Getting | grep solace-messaging | sort | tail -1  | awk '{ print $1}'`
 export SB_URL=`cf apps | grep -v Getting | grep solace-messaging | sort | tail -1  | grep $SB_APP | awk '{ print $6}'`
 export SECURITY_USER_NAME=`cf env $SB_APP | grep SECURITY_USER_NAME | awk '{ print $2}'`
 export SECURITY_USER_PASSWORD=`cf env $SB_APP | grep SECURITY_USER_PASSWORD | awk '{ print $2}'`
 export VMR_SUPPORT_PASSWORD=`cf env $SB_APP | grep VMR_SUPPORT_PASSWORD | awk '{ print $2}'`
 export VMR_SUPPORT_USER=`cf env $SB_APP | grep VMR_SUPPORT_USER | awk '{ print $2}'`
 export VMR_ADMIN_PASSWORD=`cf env $SB_APP  | grep VMR_ADMIN_PASSWORD | awk '{print $2}'`
 export VMR_ADMIN_USER=`cf env $SB_APP  | grep VMR_ADMIN_USER | awk '{print $2}'`
 export STARTING_PORT=`cf env $SB_APP | grep STARTING_PORT | awk '{print $2}'`
 export SB_BASE=$SECURITY_USER_NAME:$SECURITY_USER_PASSWORD@$SB_URL

 log "ServiceBroker $SB_APP: http://${SB_URL}"
 log "Servicebroker URL BASE: ${SB_BASE} "
 if [ "$SB_RUNNING" -eq "1" ]; then
    lookupServiceBrokerVMRs
    log "Servicebroker LARGE_VMR_LIST: ${LARGE_VMR_LIST} "
    log "Servicebroker SHARED_VMR_LIST: ${SHARED_VMR_LIST} "
    log "Servicebroker COMMUNITY_VMR_LIST: ${COMMUNITY_VMR_LIST} "
    log "Servicebroker LARGE_HA_VMR_LIST: ${LARGE_HA_VMR_LIST} "
    log "Servicebroker LARGE_HA_VMR_PAIRS_LIST: ${LARGE_HA_VMR_PAIRS_LIST} "
    log "Servicebroker LARGE_HA_VMR_PRIMARY_LIST: ${LARGE_HA_VMR_PRIMARY_LIST} "
    log "Servicebroker LARGE_HA_VMR_BACKUP_LIST: ${LARGE_HA_VMR_BACKUP_LIST} "
    log "Servicebroker LARGE_HA_VMR_MONITOR_LIST: ${LARGE_HA_VMR_MONITOR_LIST} "
    log "Servicebroker MEDIUM_HA_VMR_LIST: ${MEDIUM_HA_VMR_LIST} "
    log "Servicebroker MEDIUM_HA_VMR_PAIRS_LIST: ${MEDIUM_HA_VMR_PAIRS_LIST} "
    log "Servicebroker MEDIUM_HA_VMR_PRIMARY_LIST: ${MEDIUM_HA_VMR_PRIMARY_LIST} "
    log "Servicebroker MEDIUM_HA_VMR_BACKUP_LIST: ${MEDIUM_HA_VMR_BACKUP_LIST} "
    log "Servicebroker MEDIUM_HA_VMR_MONITOR_LIST: ${MEDIUM_HA_VMR_MONITOR_LIST} "
    log "Servicebroker ALL_VMR_LIST: ${ALL_VMR_LIST} "
    getServiceBrokerRouterInventory
    log "Servicebroker AvailabilityZones ${AVAILABILITY_ZONE_COUNT} : ${AVAILABILITY_ZONES} "
 else
    log "Servicebroker $SB_APP is not running"
 fi

  ## Remove at some point..
 log "ServiceBroker $SB_APP env: "
 cf env $SB_APP

 else
   log "Could not find solace-messaging in the current cloud-foundry environment"
   return 1
 fi

}

function lookupServiceBrokerVMRs() {

 export ALL_VMR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links`
 export SHARED_VMR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$SHARED_PLAN`
 export LARGE_VMR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_PLAN`
 export COMMUNITY_VMR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$COMMUNITY_PLAN`
 export MEDIUM_HA_VMR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN`
 export MEDIUM_HA_VMR_PAIRS_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN?$PAIRS_PARAM`
 export MEDIUM_HA_VMR_PRIMARY_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN?$PRIMARY_PARAM`
 export MEDIUM_HA_VMR_BACKUP_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN?$BACKUP_PARAM`
 export MEDIUM_HA_VMR_MONITOR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$MEDIUM_HA_PLAN?$MONITOR_PARAM`
 export LARGE_HA_VMR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN`
 export LARGE_HA_VMR_PAIRS_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN?$PAIRS_PARAM`
 export LARGE_HA_VMR_PRIMARY_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN?$PRIMARY_PARAM`
 export LARGE_HA_VMR_BACKUP_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN?$BACKUP_PARAM`
 export LARGE_HA_VMR_MONITOR_LIST=`curl -sX GET $SB_BASE/solace/manage/solace_message_routers/links/$LARGE_HA_PLAN?$MONITOR_PARAM`

}

function showServiceBrokerVMRs() {

 log "ServiceBroker: VMR Lists "
 echo "ALL_VMR_LIST=${ALL_VMR_LIST}"
 echo "SHARED_VMR_LIST=${SHARED_VMR_LIST}"
 echo "LARGE_VMR_LIST=${LARGE_VMR_LIST}"
 echo "COMMUNITY_VMR_LIST=${COMMUNITY_VMR_LIST}"
 echo "MEDIUM_HA_VMR_LIST=${MEDIUM_HA_VMR_LIST}"
 echo "MEDIUM_HA_VMR_PAIRS_LIST=${MEDIUM_HA_VMR_PAIRS_LIST}"
 echo "MEDIUM_HA_VMR_PRIMARY_LIST=${MEDIUM_HA_VMR_PRIMARY_LIST}"
 echo "MEDIUM_HA_VMR_BACKUP_LIST=${MEDIUM_HA_VMR_BACKUP_LIST}"
 echo "MEDIUM_HA_VMR_MONITOR_LIST=${MEDIUM_HA_VMR_MONITOR_LIST}"
 echo "LARGE_HA_VMR_LIST=${LARGE_HA_VMR_LIST}"
 echo "LARGE_HA_VMR_PAIRS_LIST=${LARGE_HA_VMR_PAIRS_LIST}"
 echo "LARGE_HA_VMR_PRIMARY_LIST=${LARGE_HA_VMR_PRIMARY_LIST}"
 echo "LARGE_HA_VMR_BACKUP_LIST=${LARGE_HA_VMR_BACKUP_LIST}"
 echo "LARGE_HA_VMR_MONITOR_LIST=${LARGE_HA_VMR_MONITOR_LIST}"

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
 curl -sX GET $SB_BASE/solace/status/services/solace-messaging/plans/$SHARED_PLAN -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: large plan stats"
 curl -sX GET $SB_BASE/solace/status/services/solace-messaging/plans/$LARGE_PLAN -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: community plan stats"
 curl -sX GET $SB_BASE/solace/status/services/solace-messaging/plans/$COMMUNITY_PLAN -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: medium-ha plan stats"
 curl -sX GET $SB_BASE/solace/status/services/solace-messaging/plans/$MEDIUM_HA_PLAN -H "Content-Type: application/json;charset=UTF-8"
 log "ServiceBroker: large-ha plan stats"
 curl -sX GET $SB_BASE/solace/status/services/solace-messaging/plans/$LARGE_HA_PLAN -H "Content-Type: application/json;charset=UTF-8"

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

function unbindService() {
	log "Listing of Services, before Unbinding service $1 $2"
	cf services
        FOUND=`cf services | grep $1 | grep $2 | wc -l`
	log "Found $FOUND, before Unbinding service $1  $2"
	if [ "$FOUND" -gt "0" ]; then
  		cf unbind-service $1 $2
		log "Deleted binding $1 $2"
	else
		log "Binding not found $1 $2"
	fi
}

function waitForServiceDelete() {

## Waits for a service to be deleted
REMAINING=`cf services | grep $1 | wc -l`
export DELETE_FAILED=`cf services | grep $1 | grep "delete failed" | wc -l`
export DELETE_INPROGRESS=`cf services | grep $1 | grep "delete in progress" | wc -l`
MAXWAIT=30
while [ "$REMAINING" -gt "0" ] && [ "$MAXWAIT" -gt "0" ]; do
  log "Waiting for delete of $1 to finish ($REMAINING), timeout counter: $MAXWAIT , InProgress: $DELETE_INPROGRESS, DeleteFailed: $DELETE_FAILED"

  if [ "$DELETE_FAILED" -eq "1" ]; then
     log "delete of $1 failed"
     cf services
     break
  fi

  sleep 10 
  cf services
  REMAINING=`cf services | grep $1 | wc -l`
  export DELETE_FAILED=`cf services | grep $1 | grep "delete failed" | wc -l`
  export DELETE_INPROGRESS=`cf services | grep $1 | grep "delete in progress" | wc -l`
  let MAXWAIT=MAXWAIT-1
  checkServiceBrokerServicePlanStats " Watching async delete of $1 ($REMAINING), timeout counter: $MAXWAIT"
done

if [ "$DELETE_FAILED" -eq "1" ] && [ "$EXIT_ON_TEST_FAIL" -eq "1" ]; then
    return 1
fi

}

function forceDeleteApp() {
	log "Listing of apps before deleting application $1"
	cf apps
        FOUND=`cf apps | grep $1 | wc -l`
	log "Found $FOUND, before deleting application "$1
	if [ "$FOUND" -gt "0" ]; then
	 	cf delete $1 -f
		log "Deleted application $1"
	else
		log "Application not found $1"
	fi
}


function forceUnbindService() {

        FOUND_BINDING_APP_COUNT=`cf services | grep solace-messaging | grep $1 | wc -l `
        FOUND_BINDING_APP=`cf services | grep solace-messaging | grep $1 | awk '{ print $4 }'`
	if [ "$FOUND_BINDING_APP_COUNT" -gt "0" ] && [ "$FOUND_BINDING_APP" != "create" ]; then
		log "Service $1 has binding to $FOUND_BINDING_APP"
		unbindService $FOUND_BINDING_APP $1
	else
		log "Service $1 has no app binding to $FOUND_BINDING_APP"
	fi

}

function forceDeleteService() {

	forceUnbindService $1

	log "Listing of services before Deleting service $1"
	cf services
        FOUND=`cf services | grep solace-messaging | grep $1 | wc -l`
	log "Found $FOUND, before Deleting service $1"

	if [ "$FOUND" -gt "0" ]; then
	 	cf delete-service $1 -f
		log "Deleted service $1"
		waitForServiceDelete $1
	else
		log "Service not found $1"
	fi
}

function forceDeleteServiceNoWait() {

	forceUnbindService $1

	log "Listing of services before Deleting service $1"
	cf services
        FOUND=`cf services | grep $1 | wc -l`
	log "Found $FOUND, before Deleting service $1"

	if [ "$FOUND" -gt "0" ]; then
	 	cf delete-service $1 -f
		log "Deleted service $1"
	else
		log "Service not found $1"
	fi
}

function switchToOrgAndSpace() {

 # Create (will proceed even if it exists)
 log "Will create and target org: $1"
 cf create-org $1
 cf target -o $1

 log "Will create and target space: $2"
 cf create-space $2
 cf target -o $1 -s $2

}

function switchToTestOrgAndSpace() {

 switchToOrgAndSpace $TEST_ORG $TEST_SPACE

}

function switchToLongTestOrgAndSpace() {

 switchToOrgAndSpace $LONG_TEST_ORG $LONG_TEST_SPACE

}


function testMarketPlace() {

 ## Checking Marketplace
 log "Enabling access to the Solace Service Broker provided service: solace-messaging"
 cf enable-service-access solace-messaging

 log "Marketplace:"
 cf m

 #todo: Need to install tile for this check to work (enable_global_access_to_plans)
 # Rely on grep's non-0 exit code to fail script

 log "Checking marketplace for solace service: solace-messaging"
 cf m | grep solace-messaging
 log "Checking marketplace for solace service plan: shared"
 cf m | grep shared 
 log "Checking marketplace for solace service plan: large"
 cf m | grep large
 log "Checking marketplace for solace service plan: community"
 cf m | grep community
 log "Checking marketplace for solace service plan: medium-ha"
 cf m | grep medium-ha
 log "Checking marketplace for solace service plan: large-ha"
 cf m | grep large-ha

 log "Checking marketplace for solace service plan: shared, free"
 cf m -s solace-messaging | grep shared | grep free
 log "Checking marketplace for solace service plan: large, free"
 cf m -s solace-messaging | grep -v large-ha | grep large | grep free
 log "Checking marketplace for solace service plan: community, free"
 cf m -s solace-messaging | grep community | grep free
 log "Checking marketplace for solace service plan: medium-ha, free"
 cf m -s solace-messaging | grep medium-ha | grep free
 log "Checking marketplace for solace service plan: large-ha, free"
 cf m -s solace-messaging | grep large-ha | grep free

}

function switchToServiceBrokerTarget() {
	FOUND_ORG=`cf orgs | grep $SB_ORG | wc -l`
 	if [ "$FOUND_ORG" -gt "0" ]; then
 	   cf target -o $SB_ORG -s $SB_SPACE
	else
	   log "Unable to locate required ORG: $SB_ORG and SPACE: $SB_SPACE"
	   cf orgs 
	   ## Will cause a non 0 exit code, and will fail in test pipeline
	   cf orgs | grep $SB_ORG 
	fi
}

function restartServiceBroker() {
 	switchToServiceBrokerTarget
	cf restart $SB_APP
}

