#!/bin/bash

export SCRIPT=$(readlink -f "$0")
export SCRIPTPATH=$(dirname "$SCRIPT")

export WORKSPACE=${WORKSPACE:-"$HOME/workspace"}
export LOG_FILE=${LOG_FILE:-"$WORKSPACE/prepare_bosh.log"}

COMMON=${COMMON:-bosh-common.sh}
source $SCRIPTPATH/$COMMON

cd $SCRIPTPATH/..

prepareBosh | tee $LOG_FILE
