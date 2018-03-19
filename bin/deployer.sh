#!/bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"

export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export WORKSPACE=${WORKSPACE:-"$SCRIPTPATH/../workspace"}

mkdir -p $WORKSPACE
set -e

TLS_PATH=$WORKSPACE/tls_config.yml
VARSPATH=$WORKSPACE/vars.yml
SYSLOG_PATH=$WORKSPACE/syslog_config.yml
TCP_PATH=$WORKSPACE/tcp_routes_config.yml
LDAP_PATH=$WORKSPACE/ldap_config.yml
version='evaluation'

echo '' > $TLS_PATH
echo '' > $VARSPATH
echo '' > $SYSLOG_PATH
echo '' > $TCP_PATH
echo '' > $LDAP_PATH


export TILE_FILE=${TILE_FILE:-$WORKSPACE/*.pivotal}
export TILE_VERSION=$( basename $TILE_FILE | sed 's/solace-messaging-//g' | sed 's/-enterprise//g' | sed 's/\.pivotal//g' | sed 's/\[.*\]//' )
export TEMPLATE_VERSION=$( echo $TILE_VERSION | awk -F\- '{ print $1 }' )
export TEMPLATE_DIR=/home/ubuntu/solace-messaging-cf-dev/templates/$TILE_VERSION

while getopts c:e opt; do
    case $opt in
        c)
            CI_CONFIG_FILE="$OPTARG" 
            ;;
        e) 
            enterprise='-e'i
            version='enterprise'
            ;;
        \?) echo $BASIC_USAGE && >&2 echo "Found bad option: -$OPTARG" && exit 1;;
        :) echo $BASIC_USAGE && >&2 echo "Missing argument for option: -$OPTARG" && exit 1;;
    esac
done

function makeVarsFiles() {
  #creates vars files in workspace from tile config file (for ldap, tcp, tls, and syslog)

  echo 'mysql_plan: 100mb' > $VARSPATH
  
  echo 'solace_broker_cf_organization: solace' >> $VARSPATH
  echo 'solace_broker_cf_space: solace-messaging' >> $VARSPATH
  echo 'solace_router_client_secret: 1234' >> $VARSPATH
  
  grep "starting_port:" $CI_CONFIG_FILE >> $VARSPATH
   
  grep 'secret:' $CI_CONFIG_FILE >> $VARSPATH
  sed -i '0,/secret:/! s/secret:/vmr_admin_password:/' $VARSPATH
  
  awk '/instances:/{i++}i==1' $CI_CONFIG_FILE >> $VARSPATH
  #awk '/Shared-VMR:/ {for(i=1; i<6; i++) {if( i == 6 ) {getline; print}}}' $CI_CONFIG_FILE >> $VARSPATH
  sed -i 's/instances:/shared_plan_instances:/' $VARSPATH
  awk '/instances:/{i++}i==2' $CI_CONFIG_FILE >> $VARSPATH
  sed -i 's/ instances:/large_plan_instances:/' $VARSPATH
  awk '/instances:/{i++}i==3' $CI_CONFIG_FILE >> $VARSPATH
  sed -i 's/ instances:/community_plan_instances:/' $VARSPATH
  sed -i 's/automatic/1/' $VARSPATH
  awk '/instances:/{i++}i==4' $CI_CONFIG_FILE >> $VARSPATH
  sed -i 's/ instances:/medium_ha_plan_instances:/' $VARSPATH
  awk '/instances:/{i++}i==5' $CI_CONFIG_FILE >> $VARSPATH
  sed -i 's/ instances:/large_ha_plan_instances:/' $VARSPATH
  sed -i 's/automatic/3/' $VARSPATH
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
  sed -i 's/"//' $VARSPATH
  sed -i 's/"//' $VARSPATH

  if [[ $(grep 'tls_config: enabled' $CI_CONFIG_FILE) ]]; then
    echo 'solace_vmr_cert:' > $TLS_PATH 
    sed -n '/cert_pem:/,/-----END CERTIFICATE-----/ p' $CI_CONFIG_FILE >> $TLS_PATH
    sed -i 's/ cert_pem:/ certificate:/' $TLS_PATH
    sed -n '/private_key_pem:/,/-----END RSA PRIVATE KEY-----/ p' $CI_CONFIG_FILE >> $TLS_PATH
    sed -i 's/ private_key_pem:/ private_key: /' $TLS_PATH
    if [[ $(grep 'tls_config.enabled.trusted_root_certificates:' $CI_CONFIG_FILE) ]]; then
      sed -n '/tls_config.enabled.trusted_root_certificates/,/-----END CERTIFICATE-----/ p' $CI_CONFIG_FILE >> $TLS_PATH
    fi
    sed -i 's/*//g' $TLS_PATH
    sed -i '/^$/d' $TLS_PATH
    tls="-t $TLS_PATH"
    if [[ $(grep 'broker_validate_cert_disabled: true' $CI_CONFIG_FILE) ]]; then
        tls_dis='-n'
    fi
  else 
    tls='' 
  fi

  if [[ $(grep 'ldap_config: enabled' $CI_CONFIG_FILE) ]]; then
    echo 'ldap:' > $LDAP_PATH
    awk '/ldap_credentials:/ {for(i=0; i<=2; i++) {getline; print}}' $CI_CONFIG_FILE >> $LDAP_PATH
    sed -i 's/ //g' $LDAP_PATH 
    sed -i 's/identity:/  username:/' $LDAP_PATH 
    sed -i 's/password:/  password:/' $LDAP_PATH
    grep 'ldap_server_url:' $CI_CONFIG_FILE >> $LDAP_PATH
    sed -i 's/ldap_config.enabled.ldap_server_url/  server_url/' $LDAP_PATH 

    grep 'ldap_start_tls:'  $CI_CONFIG_FILE >> $LDAP_PATH
    sed -i 's/ldap_config.enabled.ldap_start_tls/  start_tls/' $LDAP_PATH
    grep 'ldap_user_search_base:'  $CI_CONFIG_FILE >> $LDAP_PATH
    sed -i 's/ldap_config.enabled.ldap_user_search_base/  user_search_base/' $LDAP_PATH
    sed -i 's/"/ /g' $LDAP_PATH  

    if [[ $(grep 'management_access_auth_scheme: ldap_server' $CI_CONFIG_FILE) ]]; then
	echo 'management_access_auth_scheme:' >> $LDAP_PATH  
        ldap_mgmt='-b' 

        grep 'ldap_mgmt_read_only_groups:' $CI_CONFIG_FILE >> $LDAP_PATH
        sed -i 's/management_access_auth_scheme.ldap_server.ldap_mgmt_read_only_groups/  mgmt_read_only_groups/'  $LDAP_PATH

        grep 'ldap_mgmt_read_write_groups' $CI_CONFIG_FILE >> $LDAP_PATH
        sed -i 's/management_access_auth_scheme.ldap_server.ldap_mgmt_read_write_groups/  mgmt_read_write_groups/' $LDAP_PATH

        grep 'ldap_mgmt_admin_groups:' $CI_CONFIG_FILE >> $LDAP_PATH
        sed -i 's/management_access_auth_scheme.ldap_server.ldap_mgmt_admin_groups/  mgmt_admin_groups/' $LDAP_PATH
    fi
    sed -i 's/"/ /g' $LDAP_PATH
    if [[ $(grep 'application_access_auth_scheme: ldap_server' $CI_CONFIG_FILE) ]]; then
        ldap_app='-c' 
    fi 
  
    ldap="-l $LDAP_PATH"
  else 
    ldap=''
  fi

  if [[ $(grep 'tcp_routes_config: enabled' $CI_CONFIG_FILE) ]]; then
    echo 'tcp_routes_config:' > $TCP_PATH
    grep 'amqp_tcp_route_enabled' $CI_CONFIG_FILE >> $TCP_PATH
    sed -i 's/tcp_routes_config.enabled.amqp_tcp_route_enabled/  amqp_tcp_route_enabled/' $TCP_PATH
    grep 'amqp_tls_tcp_route_enabled'  $CI_CONFIG_FILE >> $TCP_PATH
    sed -i 's/tcp_routes_config.enabled.amqp_tls_tcp_route_enabled/  amqp_tls_tcp_route_enabled/' $TCP_PATH
    grep 'mqtt_tcp_route_enabled'  $CI_CONFIG_FILE >> $TCP_PATH

    sed -i 's/tcp_routes_config.enabled.mqtt_tcp_route_enabled/  mqtt_tcp_route_enabled/' $TCP_PATH
    grep 'mqtt_tls_tcp_route_enabled'  $CI_CONFIG_FILE >> $TCP_PATH
    echo '  solace_router_client:' >> $TCP_PATH
    awk '/cf_credentials:/ {for(i=0; i<=2; i++) {getline; print}}' $CI_CONFIG_FILE >> $TCP_PATH
    sed -i 's/identity:/\  id:/' $TCP_PATH
    sed -i 's/password:/\  secret:/' $TCP_PATH

    sed -i 's/tcp_routes_config.enabled.mqtt_tls_tcp_route_enabled/  mqtt_tls_tcp_route_enabled/' $TCP_PATH
    grep 'mqtt_ws_tcp_route_enabled'  $CI_CONFIG_FILE >> $TCP_PATH

    sed -i 's/tcp_routes_config.enabled.mqtt_ws_tcp_route_enabled/  mqtt_ws_tcp_route_enabled/' $TCP_PATH
    grep 'mqtt_wss_tcp_route_enabled'  $CI_CONFIG_FILE >> $TCP_PATH
 
    sed -i 's/tcp_routes_config.enabled.mqtt_wss_tcp_route_enabled/  mqtt_wss_tcp_route_enabled/' $TCP_PATH
    grep 'rest_tcp_route_enabled'  $CI_CONFIG_FILE >> $TCP_PATH

    sed -i 's/tcp_routes_config.enabled.rest_tcp_route_enabled/  rest_tcp_route_enabled/' $TCP_PATH
    grep 'rest_tls_tcp_route_enabled'  $CI_CONFIG_FILE >> $TCP_PATH
 
    sed -i 's/tcp_routes_config.enabled.rest_tls_tcp_route_enabled/  rest_tls_tcp_route_enabled/' $TCP_PATH
    grep 'smf_tcp_route_enabled'  $CI_CONFIG_FILE >> $TCP_PATH

    sed -i 's/tcp_routes_config.enabled.smf_tcp_route_enabled/  smf_tcp_route_enabled/' $TCP_PATH
    grep 'smf_tls_tcp_route_enabled'  $CI_CONFIG_FILE >> $TCP_PATH

    sed -i 's/tcp_routes_config.enabled.smf_tls_tcp_route_enabled/  smf_tls_tcp_route_enabled/' $TCP_PATH
    grep 'smf_zip_tcp_route_enabled'  $CI_CONFIG_FILE >> $TCP_PATH

    sed -i 's/tcp_routes_config.enabled.smf_zip_tcp_route_enabled/  smf_zip_tcp_route_enabled/' $TCP_PATH
    grep 'web_messaging_tcp_route_enabled'  $CI_CONFIG_FILE >> $TCP_PATH

    sed -i 's/tcp_routes_config.enabled.web_messaging_tcp_route_enabled/  web_messaging_tcp_route_enabled/' $TCP_PATH
    grep 'web_messaging_tls_tcp_route_enabled'  $CI_CONFIG_FILE >> $TCP_PATH

    sed -i 's/tcp_routes_config.enabled.web_messaging_tls_tcp_route_enabled/  web_messaging_tls_tcp_route_enabled/' $TCP_PATH

    tcp="-r $TCP_PATH"
  else 
    tcp=''
  fi

  if [[ $(grep 'syslog_config: enabled' $CI_CONFIG_FILE) ]]; then
    echo 'syslog:' > $SYSLOG_PATH
    grep "hostname:" $CI_CONFIG_FILE >> $SYSLOG_PATH
    sed -i 's/syslog_config.enabled.syslog_hostname:/  hostname:/' $SYSLOG_PATH

    grep "syslog_port:"  $CI_CONFIG_FILE >> $SYSLOG_PATH
    sed -i 's/syslog_config.enabled.syslog_port:/  port:/' $SYSLOG_PATH
 
    grep "protocol:"  $CI_CONFIG_FILE  >> $SYSLOG_PATH
    sed -i 's/syslog_config.enabled.syslog_protocol:/  protocol:/' $SYSLOG_PATH

    grep "vmr_command_logs:" $CI_CONFIG_FILE  >> $SYSLOG_PATH
    sed -i 's/syslog_config.enabled.syslog_vmr_command_logs:/  vmr_command_logs:/' $SYSLOG_PATH

    grep "vmr_event_logs:"  $CI_CONFIG_FILE >> $SYSLOG_PATH
    sed -i 's/syslog_config.enabled.syslog_vmr_event_logs:/  vmr_event_logs:/' $SYSLOG_PATH

    grep "vmr_system_logs:"  $CI_CONFIG_FILE >> $SYSLOG_PATH
    sed -i 's/syslog_config.enabled.syslog_vmr_system_logs:/  vmr_system_logs:/' $SYSLOG_PATH

    grep "broker_and_agent_logs:" $CI_CONFIG_FILE  >> $SYSLOG_PATH
    sed -i 's/syslog_config.enabled.syslog_broker_and_agent_logs:/  broker_and_agent_logs:/' $SYSLOG_PATH
    syslog="-a $SYSLOG_PATH"
  else 
    syslog=''
  fi
}

releasepath="$SCRIPTPATH/../cf-solace-messaging-deployment/release-vars.yml"

function findVmrLoad() { 
    #updates vmr load in release-vars.yml
    loadpath=$SCRIPTPATH/../../tile/build-$version/product/metadata/solace-messaging.yml
    awk '/SOLACE_LOAD_VERSION:/{i++}i==1' $loadpath >> $releasepath
    sed -i '/solace_load_version/d' $releasepath
    sed -i 's/SOLACE_LOAD_VERSION/solace_load_version/' $releasepath
}

function findServiceBrokerVersion() { 
    #update service broker jar version in release-vars.yml 
    servicebrokerversion=$SCRIPTPATH/../../solace-service-broker/gradle.properties
    releasepath="$SCRIPTPATH/../cf-solace-messaging-deployment/release-vars.yml"
    awk '/versionPatch=/{i++}i==1' $servicebrokerversion >> $releasepath
    sed -i '/solace_service_broker_jar/d' $releasepath
    sed -i 's/versionPatch=/solace_service_broker_jar: solace-service-broker-0.0./' $releasepath  
    sed -i '/^solace_service_broker_jar/ s/$/.jar/' $releasepath
}

function deploy() {
    #deploys solace vmr and service broker using configuration from tile config
 
    deployScript="$SCRIPTPATH/dev"
    cd $deployScript
    $deployScript/solace_deploy.sh -v $VARSPATH $tls $tls_dis $syslog $ldap $tcp $enterprise $ldap_mgmt $ldap_app
} 

makeVarsFiles
findServiceBrokerVersion
deploy

