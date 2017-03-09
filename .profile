##

export PATH=$HOME/solace-messaging-cf-dev/bin:$PATH

## Just in case
chmod +x $HOME/solace-messaging-cf-dev/bin/*.sh

## Just to get bosh-lite going with any fuss
if [ ! -f $HOME/.bosh_config ]; then
  cp $HOME/solace-messaging-cf-dev/.bosh_config $HOME/.bosh_config
fi

# Used by most scripts
export WORKSPACE=$HOME/workspace


