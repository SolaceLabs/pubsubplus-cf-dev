#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

for RELEASE_FILE in `ls $WORKSPACE/releases/*.tgz`; do
  RELEASE=$(basename $RELEASE_FILE)
  echo "Uploading release $RELEASE"
  bosh upload-release $RELEASE_FILE
done

bosh releases
