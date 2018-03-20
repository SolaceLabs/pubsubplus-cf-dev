#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPTPATH/deploy-common.sh

BOSH_CMD="bosh interpolate solace-deployment.yml $BOSH_PARAMS"

# To stderr avoiding stdout to allow saving bosh interpolate output
echo $BOSH_CMD 1>&2

$BOSH_CMD

