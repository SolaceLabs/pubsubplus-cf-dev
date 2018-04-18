#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

if [ -f $SCRIPTPATH/cf_env.sh ]; then
 source $SCRIPTPATH/cf_env.sh
fi

cd $WORKSPACE

if [ -f bosh_env.sh ]; then
 source bosh_env.sh
fi

if [ ! -d cf-mysql-deployment ]; then
  git clone https://github.com/cloudfoundry/cf-mysql-deployment.git
else
  ( cd cf-mysql-deployment; git pull )
fi

cd cf-mysql-deployment

bosh \
  -d cf-mysql \
  deploy cf-mysql-deployment.yml \
  -o operations/bosh-lite.yml \
  -o $SCRIPTPATH/cf_mysql_add-broker.yml \
  -o operations/register-proxy-route.yml \
  -o operations/latest-versions.yml \
  --vars-store $WORKSPACE/deployment-vars.yml \
  -v cf_mysql_external_host=p-mysql.$SYSTEM_DOMAIN \
  -v cf_mysql_host=$SYSTEM_DOMAIN \
  -v cf_api_url=https://$CF_API_DOMAIN \
  -v cf_skip_ssl_validation=true \
  -v proxy_vm_extension=mysql-proxy-lb 

[[ $? -eq 0 ]] && {
  bosh -d cf-mysql run-errand broker-registrar-vm
}

[[ $? -eq 0  ]] && {
 echo "Create a test org and space to check marketplace"
 cf create-org test
 cf target -o test
 cf create-space test
 cf target -o test
 cf m -s p-mysql
}
