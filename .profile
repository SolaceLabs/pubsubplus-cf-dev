##

export PATH=$HOME/solace-cf-dev/bin:$PATH

( cd $HOME/solace-cf-dev; git checkout -- . ; git pull )

## Just in case
chmod +x $HOME/solace-cf-dev/bin/*.sh

if [ ! -f $HOME/.bosh_config ]; then
  cp $HOME/solace-cf-dev/templates/bosh_config $HOME/.bosh_config
fi

