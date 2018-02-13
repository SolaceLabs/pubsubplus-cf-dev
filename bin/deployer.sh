#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"

export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export WORKSPACE=$HOME/repos/pcf/solace-messaging-cf-dev/workspace
mkdir -p $WORKSPACE
set -e

export TLS_PATH=$WORKSPACE/tls_config.yml
export VARSPATH=$WORKSPACE/vars.yml

export TILE_FILE=${TILE_FILE:-$WORKSPACE/*.pivotal}
export TILE_VERSION=$( basename $TILE_FILE | sed 's/solace-messaging-//g' | sed 's/-enterprise//g' | sed 's/\.pivotal//g' | sed 's/\[.*\]//' )
export TEMPLATE_VERSION=$( echo $TILE_VERSION | awk -F\- '{ print $1 }' )
export TEMPLATE_DIR=/home/ubuntu/solace-messaging-cf-dev/templates/$TILE_VERSION

while getopts c: opt; do
    case $opt in
        c)
            CI_CONFIG_FILE="$OPTARG" 
            ;;
        \?) echo $BASIC_USAGE && >&2 echo "Found bad option: -$OPTARG" && exit 1;;
        :) echo $BASIC_USAGE && >&2 echo "Missing argument for option: -$OPTARG" && exit 1;;
    esac
done

function makeVarsAndTLSFile() {
grep "starting_port:" $CI_CONFIG_FILE > $VARSPATH
 
grep 'secret:' $CI_CONFIG_FILE >> $VARSPATH
sed -i 's/secret:/vmr_admin_password:/' $VARSPATH

awk '/instances:/{i++}i==1' $CI_CONFIG_FILE >> $VARSPATH
sed -i 's/instances:/shared_plan_instances:/' $VARSPATH
awk '/instances:/{i++}i==2' $CI_CONFIG_FILE >> $VARSPATH
sed -i 's/instances:/large_plan_instances:/' $VARSPATH
awk '/instances:/{i++}i==3' $CI_CONFIG_FILE >> $VARSPATH
sed -i 's/ instances:/community_plan_instances:/' $VARSPATH
awk '/instances:/{i++}i==4' $CI_CONFIG_FILE >> $VARSPATH
sed -i 's/ instances:/medium_ha_plan_instances:/' $VARSPATH
awk '/instances:/{i++}i==5' $CI_CONFIG_FILE >> $VARSPATH
sed -i 's/ instances:/large_ha_plan_instances:/' $VARSPATH
sed "s/^[ \t]*//" -i $VARSPATH

sed -i '/internet_connected:/d' $VARSPATH
sed -i '/resource_config:/d' $VARSPATH
sed -i '/persistent_disk:/d' $VARSPATH
sed -i '/Large-VMR:/d' $VARSPATH
sed -i '/Community-VMR:/d' $VARSPATH
sed -i '/Medium-HA-VMR:/d' $VARSPATH
sed -i '/Large-HA-VMR:/d' $VARSPATH
sed -i '/Shared-VMR:/d' $VARSPATH
sed -i '/size_mb:/d' $VARSPATH
sed -i '/#/d' $VARSPATH

if [[ $(grep 'tls_config: enabled' $CI_CONFIG_FILE) ]]; then
    echo 'solace_vmr_cert:' > $TLS_PATH 
    echo '    private_key: | ' >> $TLS_PATH
    awk '/private_key_pem:/ {for(i=0; i<=52; i++) {getline; print}}' $CI_CONFIG_FILE >> $TLS_PATH
    sed -i 's/ cert_pem:/certificate:/' $TLS_PATH
    sed -i 's/ private_key_pem:/private_key:/' $TLS_PATH

fi
}

function deploy() { 
cd $SCRIPTPATH/../cf-solace-messaging-deployment/dev
./cf_deploy.sh
./cf_mysql_deploy.sh 
./solace_deploy.sh -v $VARS_PATH -t $TLS_PATH
} 

makeVarsAndTLSFile
deploy




 
