#! /bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}
export CF_SOLACE_MESSAGING_DEPLOYMENT_HOME=${CF_SOLACE_MESSAGING_DEPLOYMENT_HOME:-"$( cd $SCRIPTPATH/../cf-solace-messaging-deployment && pwd )"}

source $SCRIPTPATH/common.sh

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}
export VMR_EDITION=${VMR_EDITION:-"evaluation"}

export SYSTEM_DOMAIN=${SYSTEM_DOMAIN:-"bosh-lite.com"}

if [ -f $WORKSPACE/bosh_env.sh ]; then
 source $WORKSPACE/bosh_env.sh
fi

function showUsage() {
    echo
    echo "Usage: $CMD_NAME [OPTIONS]"
    echo
    echo "OPTIONS"
    echo "  -s <starting_port>        provide starting port "
    echo "  -p <vmr_admin_password>   provide vmr admin password "
    echo "  -h                        show command options "
    echo "  -v <vars.yml>             provide vars.yml file path "
    echo "  -t <tls_config.yml>       provide tls config file path"
    echo "  -e                        is enterprise mode"
    echo "  -a <syslog_config.yml>    provide syslog config file path"
    echo "  -r <tcp_config.yml>       provide tcp routes config file path" 
    echo "  -l <ldap_config.yml>      provide ldap config file path"   
    echo "  -b                        enable ldap management authorization access" 
    echo "  -c                        enable ldap application authorization access" 
    echo "  -n                        disable service broker tls cert validation"
}


while getopts "t:a:nbcr:l:s:p:v:eh" arg; do
    case "${arg}" in
        t) 
            TLS_PATH="$OPTARG"
            ;;
        a)
            SYSLOG_PATH="$OPTARG"
            ;;
        n) 
            disablebrokertls=true
            ;; 
        b) 
            mldap=true
            ;;
        c) 
            aldap=true
            ;;
        r) 
	    TCP_PATH="$OPTARG" 
            ;;
        l) 
	    LDAP_PATH="$OPTARG"
            ;; 
        s)
            starting_port="$OPTARG"
	    ;;
        p)
            vmr_admin_password="${OPTARG}"
            ;;
        v)
            VARS_FILE="$OPTARG"
            ;; 
        e) 
	    VMR_EDITION="enterprise"
            ;;
        h)
            showUsage
            exit 0
            ;;
       \?)
       >&2 echo
       >&2 echo "Invalid option: -$OPTARG" >&2
       >&2 echo
       showUsage
       exit 1
       ;;
    esac
done

if [ -z "$VARS_FILE" ]; then
   if [ ! -f $WORKSPACE/vars.yml ]; then
     cp $CF_SOLACE_MESSAGING_DEPLOYMENT_HOME/vars.yml $WORKSPACE
   fi
   VARS_FILE=$WORKSPACE/vars.yml
fi

if [ -n "$vmr_admin_password" ]; then
   grep -q 'vmr_admin_password' $VARS_FILE && sed -i "s/vmr_admin_password.*/vmr_admin_password: $vmr_admin_password/" $VARS_FILE || echo "vmr_admin_password: $vmr_admin_password" >> $VARS_FILE
fi

if [ -n "$starting_port" ]; then
   grep -q 'starting_port' $VARS_FILE && sed -i "s/starting_port.*/starting_port: $starting_port/" $VARS_FILE || echo "starting_port: $starting_port" >> $VARS_FILE
fi

if [ -n "$SYSLOG_PATH" ]; then
   ENABLE_SYSLOG_OPS='-o operations/enable_syslog.yml' 
   SYSLOG_VARS="-l $SYSLOG_PATH" 
fi

if [ -n "$LDAP_PATH" ]; then 
   ENABLE_LDAP_OPS='-o operations/enable_ldap.yml' 
   LDAP_VARS="-l $LDAP_PATH"
fi 

if [[ $mldap == true ]]; then 
   ENABLE_MANAGEMENT_ACCESS_LDAP_OPS='-o operations/set_management_access_ldap.yml'
fi 

if [[ $disablebrokertls == true ]]; then 
   DISABLE_SERVICE_BROKER_CERTIFICATE_VALIDATION_OPS='-o operations/disable_service_broker_certificate_validation.yml'
fi

if [ -n "$TLS_PATH" ]; then 
   SET_SOLACE_VMR_CERT_OPS='-o operations/set_solace_vmr_cert.yml' 
   TLS_VARS="-l $TLS_PATH" 
fi 

if [[ $aldap == true ]]; then
   ENABLE_APPLICATION_ACCESS_LDAP_OPS='-o operations/set_application_access_ldap.yml' 
fi 

if [ -n "$TCP_PATH" ]; then
    ENABLE_TCP_ROUTES_OPS='-o operations/enable_tcp_routes.yml' 
    TCP_ROUTES_VARS="-l $TCP_PATH"
fi

SOLACE_VMR_RELEASE_FOUND_COUNT=`bosh releases | grep solace-vmr | wc -l`

if [ "$SOLACE_VMR_RELEASE_FOUND_COUNT" -eq "0" ]; then
   echo "solace-vmr release seem to be missing from bosh, please upload-release to bosh"
   exit 1
fi

SOLACE_MESSAGING_RELEASE_FOUND_COUNT=`bosh releases | grep solace-messaging | wc -l`

if [ "$SOLACE_MESSAGING_RELEASE_FOUND_COUNT" -eq "0" ]; then
   echo "solace-messaging release seem to be missing from bosh, please upload-release to bosh"
   exit 1
fi

OPS_BASE=${OPS_BASE:-" -o operations/set_plan_inventory.yml -o operations/bosh_lite.yml -o operations/enable_global_access_to_plans.yml "}

FEATURES_OPS=${FEATURES_OPS:-"$ENABLE_LDAP_OPS $ENABLE_SYSLOG_OPS $ENABLE_MANAGEMENT_ACCESS_LDAP_OPS $ENABLE_APPLICATION_ACCESS_LDAP_OPS $DISABLE_SERVICE_BROKER_CERTIFICATE_VALIDATION_OPS $SET_SOLACE_VMR_CERT_OPS $ENABLE_TCP_ROUTES_OPS"}
FEATURES_VARS=${FEATURES_VARS:-"$TLS_VARS $TCP_ROUTES_VARS $SYSLOG_VARS $LDAP_VARS "}

VARS_STORE=${VARS_STORE:-"--vars-store $WORKSPACE/deployment-vars.yml "}

CMD_VARS=${CMD_VARS:="-v system_domain=$SYSTEM_DOMAIN -v app_domain=$SYSTEM_DOMAIN -v cf_deployment=cf "}

RELEASE_VARS=${RELEASE_VARS:-" -l release-vars.yml"}

BOSH_PARAMS=" $OPS_BASE $FEATURES_OPS -o operations/is_${VMR_EDITION}.yml $VARS_STORE $CMD_VARS -l $VARS_FILE $FEATURES_VARS $RELEASE_VARS "

