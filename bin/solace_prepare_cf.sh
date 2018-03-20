#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

source $SCRIPTPATH/common.sh

grep solace_router_client_secret $WORKSPACE/deployment-vars.yml > /dev/null

if [ $? -eq 0 ]; then
  export SOLACE_ROUTER_CLIENT_SECRET=$( bosh int $WORKSPACE/deployment-vars.yml --path /solace_router_client_secret || echo "1234" )
else
  export SOLACE_ROUTER_CLIENT_SECRET=${SOLACE_ROUTER_CLIENT_SECRET:-"1234"}
fi

source $SCRIPTPATH/cf_env.sh

export SYSTEM_DOMAIN=${SYSTEM_DOMAIN:-"bosh-lite.com"}

function check_uaac() {
	echo "Looking for CloudFoundry UAA Command Line  ( uaac )"
	which uaac
	if [ $? -eq 1 ]; then
	   echo "Installing CloudFoundry UAA Command Line  ( uaac )"
	   sudo gem install cf-uaac
	fi
}

function enableTcpRoutingForSolaceRouter() {

	check_uaac
	which uaac
	if [ $? -eq 1 ]; then
	   echo "Missing CloudFoundry UAA Command Line  ( uaac ), please install.."
	   exit 1
	fi

        TARGET=${1:-"uaa.$SYSTEM_DOMAIN"}
        uaac target $TARGET --skip-ssl-validation
        uaac token client get admin -s $UAA_ADMIN_CLIENT_SECRET
        FOUND_CLIENT=$( uaac clients | grep name | grep solace_router | wc -l )

        if [ "$FOUND_CLIENT" -eq "0" ]; then

                echo "Adding solace_router client"

                uaac client add solace_router \
                  --name solace_router \
                  --scope uaa.none \
                  --authorized_grant_types "refresh_token,client_credentials" \
                  --authorities "routing.routes.read,routing.routes.write,routing.router_groups.read,cloud_controller.read,cloud_controller.write,cloud_controller.admin" \
                  -s "$SOLACE_ROUTER_CLIENT_SECRET"
        else

                echo "Found solace_router in clients list ( uaac clients ) : "
                uaac clients | grep name | grep solace_router

        fi

        ## Create tcp domain if needed
        TCP_DOMAIN=$( cf target | grep "api endpoint" | sed 's/https\:\/\/api/tcp/g' | sed 's/http\:\/\/api/tcp/g' | awk '{ print $3 }' )

        cf target -o system > /dev/null

        FOUND_COUNT=$(cf domains | grep "$TCP_DOMAIN" | wc -l )

        if [ $FOUND_COUNT -eq "0" ]; then
          echo "Will create tcp domain: $TCP_DOMAIN"
          cf create-shared-domain $TCP_DOMAIN --router-group default-tcp
        else
          echo "tcp domain found : $TCP_DOMAIN"
          cf domains | grep $TCP_DOMAIN
        fi

}

enableTcpRoutingForSolaceRouter
