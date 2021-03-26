#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

cd $SCRIPTPATH/..

echo
echo "Running Errand [ delete-all ]"
bosh -d solace_pubsub run-errand delete-all --instance=management/first $@
