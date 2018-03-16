#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}
export VMR_EDITION=${VMR_EDITION:-"evaluation"}

if [ -f $WORKSPACE/bosh_env.sh ]; then
 source $WORKSPACE/bosh_env.sh
fi

cd $SCRIPTPATH/..

bosh interpolate solace-deployment.yml \
        -o operations/set_plan_inventory.yml \
        -o operations/bosh_lite.yml \
        -o operations/set_solace_vmr_cert.yml \
        -o operations/add_vmr_trusted_certs.yml \
        -o operations/is_${VMR_EDITION}.yml \
        -o operations/enable_global_access_to_plans.yml \
        --vars-store $WORKSPACE/deployment-vars.yml \
        -v system_domain=bosh-lite.com  \
        -v app_domain=bosh-lite.com  \
        -v cf_deployment=cf  \
        -l vars.yml \
        -l release-vars.yml \
        -l operations/example-vars-files/certs.yml

