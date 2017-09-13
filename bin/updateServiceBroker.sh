#!/bin/bash

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

source $SCRIPTPATH/cf-common.sh

set -e

if [ -f $WORKSPACE/trusted.crt ]; then

	confirmServiceBrokerRunning
	echo "Will update the Service Broker to add a trusted certificate $WORKSPACE/trusted.crt"
	CERT_FOUND=$( cf ssh $SB_APP  -c "./app/.java-buildpack/open_jdk_jre/bin/keytool -keystore ./app/.java-buildpack/container_certificate_trust_store/truststore.jks -storepass java-buildpack-trust-store-password -list -alias SolaceTrustedCert" | grep trustedCertEntry | grep SolaceTrustedCert | wc -l )
	if [ "$CERT_FOUND" -eq "0" ]; then
		export TRUSTED_CERT=$( cat $WORKSPACE/trusted.crt )
		cf ssh $SB_APP -c "echo '$TRUSTED_CERT' > \$HOME/trusted.crt "
		cf ssh $SB_APP -c "./app/.java-buildpack/open_jdk_jre/bin/keytool -keystore ./app/.java-buildpack/container_certificate_trust_store/truststore.jks -storepass java-buildpack-trust-store-password -importcert -noprompt -alias SolaceTrustedCert -file \$HOME/trusted.crt"
		cf restart $SB_APP
		confirmServiceBrokerRunning
	else
		echo "SolaceTrustedCert was already installed"
	fi

fi

