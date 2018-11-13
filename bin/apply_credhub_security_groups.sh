#! /bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPTPATH/common.sh

if ! cf security-group credhub_open >/dev/null 2>/dev/null; then
   cf create-security-group credhub_open $SCRIPTPATH/credhub_open.json
fi

echo "Applying credhub_open security to staging and running"

cf bind-staging-security-group credhub_open 
cf bind-running-security-group credhub_open 

