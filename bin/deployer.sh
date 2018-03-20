#!/bin/bash

source $SCRIPTPATH/tile-config-common.sh

#Make vars files for ldap, tcp, syslog and tls from tile config file
makeVarsFiles

#find and update service broker jar in release vars 
findServiceBrokerVersion

#run solace_deploy using the vars files sourced from tile config
deploy
