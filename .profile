##

export MY_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export SOLACE_MESSAGING_CF_DEV=${SOLACE_MESSAGING_CF_DEV:-$MY_HOME}

export PATH=$SOLACE_MESSAGING_CF_DEV/bin:$PATH

export WORKSPACE=${WORKSPACE:-$HOME/workspace}

export SYSTEM_DOMAIN=${SYSTEM_DOMAIN:-"bosh-lite.com"}
export CF_ADMIN_PASSWORD=${CF_ADMIN_PASSWORD:-"admin"}

if [ -f $WORKSPACE/bucc/bin/bucc ]; then
   $WORKSPACE/bucc/bin/bucc env > $WORKSPACE/.env
fi

if [ -f $WORKSPACE/.env ]; then
   source $WORKSPACE/.env
   export BOSH_IP=$BOSH_ENVIRONMENT
fi

if [ -f $WORKSPACE/deployment-vars.yml ]; then
   export CF_ADMIN_PASSWORD=$(bosh int $WORKSPACE/deployment-vars.yml --path /cf_admin_password) 
fi

source $SOLACE_MESSAGING_CF_DEV/bin/bosh-common.sh

if [ -z $SEEN_BANNER ]; then
 echo
 echo
 cat $SOLACE_MESSAGING_CF_DEV/.banner
 echo
 echo
 export SEEN_BANNER=1
fi

printf "SOLACE_MESSAGING_CF_DEV\t\t%s\n" "$SOLACE_MESSAGING_CF_DEV"

printf "WORKSPACE\t\t\t%s\n" "$WORKSPACE"

## Test PCF Dev access

CF_API_FOUND=$( cf api | grep "api endpoint" | grep http | wc -l )

if [ "$CF_API_FOUND" -eq "0" ]; then

   printf  "PCFDev \t\t\t\t%s\n" "Access attempt (may take some time)"

   ping -q -c 5 -w 10 api.$SYSTEM_DOMAIN > /dev/null
   if [ $? -eq "0" ]; then
    export PCFDEV=0
    cf api https://api.$SYSTEM_DOMAIN --skip-ssl-validation > /dev/null
    if [ $? -eq 0 ]; then
       cf auth admin $CF_ADMIN_PASSWORD > /dev/null
       if [ $? -eq 0 ]; then
          export PCFDEV=1
       else
       export PCFDEV=0
       fi
    else
      export PCFDEV=0
    fi
   else
     export PCFDEV=0
   fi

   if [ $PCFDEV -eq "1" ]; then
    printf  "PCFDev \t\t\t\t%s\n" "OK"
   else
    printf  "PCFDev \t\t\t\t%s\n" "WARN: PCFDev is not accessible. Is it installed? running? is routing enabled? Is it running on Windows?"
   fi

else
  CF_API=$( cf api | grep "api endpoint" | grep http )
  printf  "PCFDev \t\t\t\t%s\n" "You seem to have CF setup to access ( $CF_API )"
  export PCFDEV=1
fi


## Test BOSH-Lite access

export BOSHLITE=0
printf "BOSH-lite\t\t\t%s\n" "Access attempt (may take some time)"

ping -q -c 5 -w 10 $BOSH_IP > /dev/null
if [ $? -eq "0" ]; then
  targetBosh
else
  export BOSHLITE=0
fi

if [ $BOSHLITE -eq "1" ]; then
    printf "BOSH-lite\t\t\t%s\n" "OK"
else
    printf "BOSH-lite\t\t\t%s\n" "WARN: BOSH-lite is not accessible. Is it installed ? running? is routing enabled?"
fi

echo

