#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

source $SCRIPTPATH/common.sh

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

if [ ! -d $WORKSPACE ]; then
  mkdir -p $WORKSPACE
fi

cd $WORKSPACE

if [ ! -d bucc ]; then
 git clone https://github.com/starkandwayne/bucc.git
else
 (cd bucc; git pull)
fi

if [ -d $WORKSPACE/bucc/state ]; then
   $WORKSPACE/bucc/bin/bucc down 
   $WORKSPACE/bucc/bin/bucc clean
fi

if [ -f $WORKSPACE/bosh_env.sh ]; then
   rm -f $WORKSPACE/bosh_env.sh
fi

if [ -f $WORKSPACE/.bosh_env ]; then
   rm -f $WORKSPACE/.bosh_env
fi

if [ -f $WORKSPACE/deployment-vars.yml ]; then
   rm -f $WORKSPACE/deployment-vars.yml
fi

