#! /bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}
export VMR_EDITION=${VMR_EDITION:-"evaluation"}

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
    echo "  -v <vars.yml file path>   provide vars.yml file path "
    echo "  -t <tls_config.yml file>  provide tls config file path"
    echo "  -e                        is enterprise mode"
    echo "  -a <syslog_config.yml>    provide syslog config file path"
    echo "  -r <tcp_config.yml>       provide tcp routes config file path" 
    echo "  -l <ldap_config.yml>      provide ldap config file path"   
    echo "  -b                        enable ldap management authorization access" 
    echo "  -c                        enable ldap application authorization access" 
    echo "  -n                        disable service broker tls cert validation"
}


while getopts "t:a:n:b:c:r:l:s:p:v:eh" arg; do
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
            cd ..
            grep -q 'starting_port' vars.yml && sed -i "s/starting_port.*/starting_port: $starting_port/" vars.yml || echo "starting_port: $starting_port" >> vars.yml
	    ;;
        p)
            vmr_admin_password="${OPTARG}"
            grep -q 'vmr_admin_password' vars.yml && sed -i "s/vmr_admin_password.*/vmr_admin_password: $vmr_admin_password/" vars.yml || echo "vmr_admin_password: $vmr_admin_password" >> vars.yml
            ;;
        v)
            VARS_PATH="$OPTARG"
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

if [ -z "$VARS_PATH" ]; then
   VARS_PATH=$SCRIPTPATH/../vars.yml
fi

if [ -n "$SYSLOG_PATH" ]; then
   enable_syslog='-o operations/enable_syslog.yml' 
   syslog_file="-l $SYSLOG_PATH" 
fi

if [ -n "$LDAP_PATH" ]; then 
   enable_ldap='-o operations/enable_ldap.yml' 
   ldap_file="-l $LDAP_PATH"
fi 

if [ $mldap=true ]; then 
   enable_management_access_ldap='-o operations/set_management_access_ldap.yml'
fi 

if [ $disablebrokertls=true ]; then 
   tls_disable_service_broker_cert='-o operations/disable_service_broker_certificate_validation.yml'
fi

if [ -n "$TLS_PATH" ]; then 
   set_tls_cert='-o operations/set_solace_vmr_cert.yml' 
   tls_file="-l $TLS_PATH" 
fi 

if [ $aldap=true ]; then
   enable_management_access_ldap='-o operations/set_application_access_ldap.yml' 
fi 

if [ -n "$TCP_PATH" ]; then
    enable_tcp_routes='-o operations/enable_tcp_routes.yml' 
    tcp_file="-l $TCP_PATH"
fi

cd $SCRIPTPATH/..

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

cd $SCRIPTPATH/../cf-solace-messaging-deployment/

echo "bosh -d solace_messaging \
        deploy solace-deployment.yml \
        -o operations/set_plan_inventory.yml \
        -o operations/bosh_lite.yml \
	-o operations/enable_global_access_to_plans.yml \
        $enable_ldap \
        $enable_syslog \
        $enable_management_access_ldap \
        $enable_application_access_ldap \
        $tls_disable_service_broker_cert \
        $set_tls_cert \
        $enable_tcp_routes \
        -o operations/is_${VMR_EDITION}.yml \
	--vars-store $WORKSPACE/deployment-vars.yml \
	-v system_domain=bosh-lite.com  \
	-v app_domain=bosh-lite.com  \
	-v cf_deployment=cf  \
	-l $VARS_PATH \
	$tls_file \
        $tcp_file \
        $syslog_file \
        $ldap_file \
        -l release-vars.yml"

bosh -d solace_messaging \
        deploy solace-deployment.yml \
        -o operations/set_plan_inventory.yml \
        -o operations/bosh_lite.yml \
	-o operations/enable_global_access_to_plans.yml \
        $enable_ldap \
        $enable_syslog \
        $enable_management_access_ldap \
        $enable_application_access_ldap \
        $tls_disable_service_broker_cert \
        $set_tls_cert \
        $enable_tcp_routes \
        -o operations/is_${VMR_EDITION}.yml \
	--vars-store $WORKSPACE/deployment-vars.yml \
	-v system_domain=bosh-lite.com \
	-v app_domain=bosh-lite.com \
	-v cf_deployment=cf  \
	-l $VARS_PATH \
	$tls_file \
        $tcp_file \
        $syslog_file \
        $ldap_file \
        -l $SCRIPTPATH/templates/1.4.0/release-vars.yml 

[[ $? -eq 0 ]] && { 
  $SCRIPTPATH/solace_add_service_broker.sh 
}

exit $? 
