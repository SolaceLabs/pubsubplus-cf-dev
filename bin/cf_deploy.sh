#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

export SYSTEM_DOMAIN=${SYSTEM_DOMAIN:-"bosh-lite.com"}

export CF_DEPLOYMENT_VERSION=${CF_DEPLOYMENT_VERSION:-"v1.19.0"}

export STEMCELL_VERSION=${STEMCELL_VERSION:-"3541.9"}
export STEMCELL_NAME="bosh-stemcell-$STEMCELL_VERSION-warden-boshlite-ubuntu-trusty-go_agent.tgz"
export STEMCELL_URL="https://s3.amazonaws.com/bosh-core-stemcells/warden/$STEMCELL_NAME"

if [ ! -d $WORKSPACE ]; then
  mkdir -p $WORKSPACE
fi

cd $WORKSPACE

if [ -f bosh_env.sh ]; then
 source bosh_env.sh
fi

if [ ! -d $WORKSPACE/cf-deployment ]; then
 ( cd $WORKSPACE; git clone https://github.com/cloudfoundry/cf-deployment.git )
fi

(cd $WORKSPACE/cf-deployment; git fetch --all; git checkout tags/$CF_DEPLOYMENT_VERSION)

cd $WORKSPACE/cf-deployment

echo "Checking stemcell $STEMCELL_NAME"

  FOUND_STEMCELL=`bosh stemcells | grep bosh-warden-boshlite-ubuntu-trusty-go_agent | grep $STEMCELL_VERSION | wc -l`
  if [ "$FOUND_STEMCELL" -eq "0" ]; then
     if [ ! -f $WORKSPACE/$STEMCELL_NAME ]; then
        wget -O $WORKSPACE/$STEMCELL_NAME $STEMCELL_URL
     fi
     bosh upload-stemcell $WORKSPACE/$STEMCELL_NAME
  else
     echo "$STEMCELL_NAME was found $FOUND_STEMCELL"
  fi

echo "Loading cloud-config iaas-support/bosh-lite/cloud-config.yml"
bosh update-cloud-config $SCRIPTPATH/../cf-solace-messaging-deployment/iaas-support/bosh-lite/cloud-config.yml

bosh -d cf deploy cf-deployment.yml \
	-o operations/bosh-lite.yml \
	-o operations/use-compiled-releases.yml \
	-o operations/use-trusted-ca-cert-for-apps.yml \
	--vars-store $WORKSPACE/deployment-vars.yml \
        -l $SCRIPTPATH/cf_trusted-ca-cert-for-apps.yml \
	-v system_domain=$SYSTEM_DOMAIN
        

if [ -f $SCRIPTPATH/cf_env.sh ]; then
  $SCRIPTPATH/cf_env.sh 
[[ $? -eq 0 ]] && {
	echo "Create a system/system org and space"
	cf target -o system
	cf create-space system
	cf target -o system
	cf m
}
fi

echo
echo "TIP: To deploy CF-MYSQL on bosh you should run \"$SCRIPTPATH/cf_mysql_deploy.sh\""
echo
