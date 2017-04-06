##

export SOLACE_MESSAGING_CF_DEV=$HOME/solace-messaging-cf-dev

export PATH=$SOLACE_MESSAGING_CF_DEV/bin:$PATH

## Just in case
chmod +x $SOLACE_MESSAGING_CF_DEV/bin/*.sh

## Just to get bosh-lite going with any fuss
if [ ! -f $HOME/.bosh_config ]; then
  cp $SOLACE_MESSAGING_CF_DEV/.bosh_config $HOME/.bosh_config
fi

echo
echo
cat $SOLACE_MESSAGING_CF_DEV/.banner
echo
echo

printf "SOLACE_MESSAGING_CF_DEV\t\t%s\n" "$SOLACE_MESSAGING_CF_DEV"

# Used by most scripts
export WORKSPACE=$HOME/workspace

printf "WORKSPACE\t\t\t%s\n" "$WORKSPACE"

## Test PCF Dev access

printf  "PCFDev \t\t\t\t%s\n" "Access attempt (may take some time)"

ping -q -c 5 -w 10 api.local.pcfdev.io > /dev/null
if [ $? -eq "0" ]; then
 export PCFDEV=0
 cf api https://api.local.pcfdev.io --skip-ssl-validation > /dev/null
 if [ $? -eq 0 ]; then
    cf auth admin admin > /dev/null
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
 printf  "PCFDev \t\t\t\t%s\n" "WARN: PCFDev is not accessible. Is it installed? running? is routing enabled?"
fi

## Test BOSH-Lite access

export BOSHLITE=0
printf "BOSH-lite\t\t\t%s\n" "Access attempt (may take some time)"

ping -q -c 5 -w 10 192.168.50.4 > /dev/null
if [ $? -eq "0" ]; then
  bosh -n target 192.168.50.4 lite > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    bosh -n login admin admin > /dev/null 2>&1
    if [ $? -eq 0 ]; then
       export BOSHLITE=1
    else
       export BOSHLITE=0
    fi
  else
    export BOSHLITE=0
  fi
else
  export BOSHLITE=0
fi

if [ $BOSHLITE -eq "1" ]; then
    printf "BOSH-lite\t\t\t%s\n" "OK"
else
    printf "BOSH-lite\t\t\t%s\n" "WARN: BOSH-lite is not accessible. Is it installed ? running? is routing enabled?"
fi

echo

