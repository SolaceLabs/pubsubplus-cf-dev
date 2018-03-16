#!/bin/bash

# Cross-OS compatibility ( gsed )
[[ `uname` == 'Darwin' ]] && {
        which gsed > /dev/null || {
                echo 'ERROR: GNU utils required for Mac. You may use homebrew to install them: brew install coreutils gnu-sed'
                exit 1
        }

   shopt -s expand_aliases
   alias sed=`which gsed`
}

