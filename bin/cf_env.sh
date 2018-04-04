#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

CF_ADMIN_PASSWORD=$(bosh int $WORKSPACE/deployment-vars.yml --path /cf_admin_password)  
export CF_ADMIN_PASSWORD=${CF_ADMIN_PASSWORD:-'admin'}
export UAA_ADMIN_CLIENT_SECRET=$(bosh int $WORKSPACE/deployment-vars.yml --path /uaa_admin_client_secret)  

cf api https://api.bosh-lite.com --skip-ssl-validation
cf auth admin $CF_ADMIN_PASSWORD  
