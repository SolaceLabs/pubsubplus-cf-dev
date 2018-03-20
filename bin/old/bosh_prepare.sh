#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export WORKSPACE=${WORKSPACE:-"$HOME/workspace"}
mkdir -p $WORKSPACE
export LOG_FILE=${LOG_FILE:-"$WORKSPACE/prepare_bosh.log"}

COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON

cd $SCRIPTPATH/..

prepareBosh | tee $LOG_FILE
