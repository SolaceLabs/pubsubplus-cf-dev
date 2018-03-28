#! /bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPTPATH/common.sh

if [ -z $1 ]; then
  echo "Requires org"
  exit 1
fi

if [ -z $2 ]; then
  echo "Requires space"
  exit 1
fi

if ! cf security-group all_open >/dev/null 2>/dev/null; then
   cf create-security-group all_open $SCRIPTPATH/all_open.json
fi

echo "Applying all_open security group to org: $1 and space: $2"

cf bind-security-group all_open "$1" "$2"

