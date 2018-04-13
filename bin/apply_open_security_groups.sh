#! /bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPTPATH/common.sh

if ! cf security-group all_open >/dev/null 2>/dev/null; then
   cf create-security-group all_open $SCRIPTPATH/all_open.json
fi

echo "Applying all_open security to staging and running"

cf bind-staging-security-group all_open 
cf bind-running-security-group all_open 

