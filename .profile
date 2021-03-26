##

export MY_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export PUBSUBPLUS_CF_DEV=${PUBSUBPLUS_CF_DEV:-$MY_HOME}

export PATH=$PUBSUBPLUS_CF_DEV/bin:$PATH

export WORKSPACE=${WORKSPACE:-$HOME/workspace}

export SYSTEM_DOMAIN=${SYSTEM_DOMAIN:-"bosh-lite.com"}
export CF_ADMIN_PASSWORD=${CF_ADMIN_PASSWORD:-"admin"}

export BUCC_HOME=${BUCC_HOME:-$PUBSUBPLUS_CF_DEV/bucc}
export BUCC_STATE_ROOT=${BUCC_STATE_ROOT:-$WORKSPACE/BOSH_LITE_VM/state}
export BUCC_VARS_FILE=${BUCC_VARS_FILE:-$WORKSPACE/BOSH_LITE_VM/vars.yml}
export BUCC_STATE_STORE=${BUCC_STATE_STORE:-$BUCC_STATE_ROOT/state.json}
export BUCC_VARS_STORE=${BUCC_VARS_STORE:-$BUCC_STATE_ROOT/creds.yml}

export BOSH_ENV_FILE=${BOSH_ENV_FILE:-$WORKSPACE/bosh_env.sh}
export DOT_BOSH_ENV_FILE=${DOT_BOSH_ENV_FILE:-$WORKSPACE/.env}

LOCKFILE=$HOME/.env.lck

if [ -f $BUCC_HOME/bin/bucc ]; then
   ## Avoids concurrent writes
   (
     flock -x 200
     $BUCC_HOME/bin/bucc env > $DOT_BOSH_ENV_FILE
     flock -u 200
   ) 200>$LOCKFILE
fi

if [ -f $DOT_BOSH_ENV_FILE ]; then
   ## Avoids reads during writes
   exec 200>$LOCKFILE
   flock -x 200
   source $DOT_BOSH_ENV_FILE
   export BOSH_IP=$BOSH_GW_HOST
   flock -u 200
fi

if [ -f $WORKSPACE/deployment-vars.yml ]; then
   CF_PASSWORD=$(bosh int $WORKSPACE/deployment-vars.yml --path /cf_admin_password 2>/dev/null)
   if [ $? -eq '1' ]; then
      echo 'Detected Windows Deployment, PCFDev is running separately from BOSH-Lite'
      export SYSTEM_DOMAIN='local.pcfdev.io'
      export WINDOWS='true'
   else
      export CF_ADMIN_PASSWORD=$CF_PASSWORD
   fi
fi

source $PUBSUBPLUS_CF_DEV/bin/bosh-common.sh

if [ -z $SEEN_BANNER ]; then
 echo
 echo
 cat $PUBSUBPLUS_CF_DEV/.banner
 echo
 echo
 export SEEN_BANNER=1
fi

printf "PUBSUBPLUS_CF_DEV\t\t%s\n" "$PUBSUBPLUS_CF_DEV"

printf "WORKSPACE\t\t\t%s\n" "$WORKSPACE"

## Test PCF Dev access

CF_API_FOUND=$( cf api | grep "api endpoint" | grep http | wc -l )

if [ "$CF_API_FOUND" -eq "0" ]; then

   printf  "CF   \t\t\t\t%s\n" "Access attempt (may take some time)"

   ping -q -c 5 -w 10 api.$SYSTEM_DOMAIN > /dev/null
   if [ $? -eq "0" ]; then
    export CF_ACCESS=0
    cf api https://api.$SYSTEM_DOMAIN --skip-ssl-validation > /dev/null
    if [ $? -eq 0 ]; then
       cf auth admin $CF_ADMIN_PASSWORD > /dev/null
       if [ $? -eq 0 ]; then
          export CF_ACCESS=1
       else
       export CF_ACCESS=0
       fi
    else
      export CF_ACCESS=0
    fi
   else
     export CF_ACCESS=0
   fi

   if [ $CF_ACCESS -eq "1" ]; then
    printf  "CF   \t\t\t\t%s\n" "OK"
   else
    printf  "CF   \t\t\t\t%s\n" "WARN: CF is not accessible. Is it installed? running? is routing enabled?"
   fi

else
  CF_API=$( cf api | grep "api endpoint" | grep http )
  printf  "CF   \t\t\t\t%s\n" "You seem to have CF set to access ( $CF_API )"
  if [[ $CF_API == *"local.pcfdev.io"* ]]; then
    export WINDOWS='true'
    export SYSTEM_DOMAIN='local.pcfdev.io'
  fi
  export CF_ACCESS=1
fi


## Test BOSH access

export BOSH_ACCESS=0
printf "BOSH   \t\t\t\t%s\n" "Access attempt (may take some time)"

ping -q -c 5 -w 10 $BOSH_IP > /dev/null
if [ $? -eq "0" ]; then
  targetBosh
else
  export BOSH_ACCESS=0
fi

if [ $BOSH_ACCESS -eq "1" ]; then
    printf "BOSH   \t\t\t\t%s\n" "OK"
else
    printf "BOSH   \t\t\t\t%s\n" "WARN: BOSH is not accessible. Is it installed ? running? is routing enabled?"
fi

echo

