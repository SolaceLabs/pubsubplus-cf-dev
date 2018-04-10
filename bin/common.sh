#!/bin/bash

# Cross-OS compatibility ( gsed )
[[ $(uname) == 'Darwin' ]] && {
        which gsed > /dev/null || {
                echo 'ERROR: GNU utils required for Mac. You may use homebrew to install them: brew install coreutils gnu-sed'
                exit 1
        }

   shopt -s expand_aliases
   alias sed="$(which gsed)"
}

REQUIRED_TOOLS="jq curl cf git gem sort head tail wc basename dirname grep which mktemp unzip tar ruby bundle"

for REQUIRED_TOOL in $REQUIRED_TOOLS; do
 which $REQUIRED_TOOL > /dev/null || {
	echo "ERROR: '$REQUIRED_TOOL' was not found. Please install it."
	exit 1
 }
done

