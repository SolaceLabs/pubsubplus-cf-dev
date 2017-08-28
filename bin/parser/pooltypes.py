from solyaml import literal_unicode
from typing import Dict, Any, Optional, List

class PoolType:
    SSH_PORT = 2222 #const
    def __init__(self, name : str, isHA : bool, solaceDockerImageName: str) -> None:
        self.name = name
        # HA is 3, non-HA is 1
        self.isHA = isHA
        self.solaceDockerImageName = solaceDockerImageName

    def getNumInstances(self, commandLineArgs: Optional[int], inputFile : Dict[str, Any]) -> int:
        if commandLineArgs is not None:
            return int(commandLineArgs)
        fileValue = inputFile["jobs"][self.name]["resource_config"]["instances"]
        if fileValue == "automatic":
            fileValue = 1 if not self.isHA else 3
        return int(fileValue)

    def generateBoshLiteManifestJob(self, properties : Dict[str, Any], numInstances: int, outFile: List[Dict[str, Any]]) -> None:
        if numInstances == 0:
            return
        output = {}
        output["name"] = self.name
        output["instances"] = numInstances 
        output["persistent_disk"] = 20480
        output["templates"] = []
        output["templates"].append({"name": "docker", "release": "docker"})
        output["templates"].append({"name": "prepare_vmr", "release": "solace-vmr"})
        output["templates"].append({"name": "containers", "release": "solace-vmr"})
        output["templates"].append({"name": "vmr_agent", "release": "solace-vmr"})
        output["properties"] = {}
        output["resource_pool"] = "common-resource-pool"
        output["networks"] = []
        output["networks"].append({})
        output["networks"][0]["name"] = "test-network"
        output["properties"]["containers"] = []
        output["properties"]["containers"].append({})
        output["properties"]["containers"][0]["name"] = "solace"
        output["properties"]["containers"][0]["image"] = "solace-bosh"
        output["properties"]["containers"][0]["memory"] = "4G"
        output["properties"]["containers"][0]["uts"] = "host"
        output["properties"]["containers"][0]["privileged"] = True
        output["properties"]["containers"][0]["shm_size"] = "2G"
        output["properties"]["containers"][0]["net"] = "host"
        output["properties"]["containers"][0]["dockerfile"] = literal_unicode( \
"""          FROM solace-app:{}

          RUN \\
            echo '#!/bin/bash' > /sbin/dhclient && \\
            echo 'exit 0' >> /sbin/dhclient && \\
            echo '3a:40:d5:42:f4:86' > /usr/sw/.nodeIdentifyingMacAddr && \\
            chmod +x /sbin/dhclient""".format(self.solaceDockerImageName))
        output["properties"]["containers"][0]["env_vars"] = [
            "NODE_TYPE=MESSAGE_ROUTING_NODE",
            "SERVICE_SSH_PORT=" + str(self.SSH_PORT),
            "ALWAYS_DIE_ON_FAILURE=1",
            "USERNAME_ADMIN_PASSWORD=" + properties["admin_password"],
            "USERNAME_ADMIN_GLOBALACCESSLEVEL=admin"
        ]
        output["properties"]["containers"][0]["encrypted_vars"] = [
            "DEBUG_USERNAME_ROOT_ENCRYPTEDPASSWORD=solace1"
        ]
        output["properties"]["containers"][0]["volumes"] = [
            "/var/vcap/store/prepare_vmr/volumes/jail:/usr/sw/jail",
            "/var/vcap/store/prepare_vmr/volumes/var:/usr/sw/var",
            "/var/vcap/store/prepare_vmr/volumes/internalSpool:/usr/sw/internalSpool",
            "/var/vcap/store/prepare_vmr/volumes/adbBackup:/usr/sw/adb",
            "/var/vcap/store/prepare_vmr/volumes/adb:/usr/sw/internalSpool/softAdb"
        ]
        output["properties"].update(properties)
        output["properties"]["pool_name"] = self.name
        output["properties"]["admin_user"] = "admin"
        output["properties"]["vmr_agent_port"] = 18080
        output["properties"]["semp_port"] = 8080
        output["properties"]["semp_ssl_port"] = 943
        output["properties"]["ssh_port"] = self.SSH_PORT
        output["properties"]["heartbeat_rate"] = 15000
        output["properties"]["broker_user"] = "solacedemo"
        output["properties"]["broker_password"] = "solacedemo"
        output["properties"]["broker_hostname"] = "solace-messaging.local.pcfdev.io"
        output["properties"]["system_domain"] = "local.pcfdev.io"
        output["properties"]["cf_api_host"] = "api.local.pcfdev.io"
        output["properties"]["cf_client_id"] = "solace_router"
        output["properties"]["cf_client_secret"] = "1234"
        output["properties"]["cf_organization"] = "solace"
        output["properties"]["cf_space"] = "solace-messaging"
        outFile["jobs"].append(output)

Shared = PoolType("Shared-VMR", False, "latest-evaluation")
Community = PoolType("Community-VMR", False, "latest-community")
Large = PoolType("Large-VMR", False, "latest-evaluation")
MediumHA = PoolType("Medium-HA-VMR", True, "latest-evaluation")
LargeHA = PoolType("Large-HA-VMR", True, "latest-evaluation")
