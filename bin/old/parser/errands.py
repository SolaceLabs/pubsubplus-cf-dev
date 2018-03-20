import ipaddress
from solyaml import literal_unicode
from typing import Dict, Any, Optional, List
from schema import root
import yaml


class Errand:
    SSH_PORT = 2222 #const
    def __init__(self, name : str, release : str, property_source : str = '' ) -> None:
        self.name = name
        self.release = release
        self.property_source = property_source

    def generateBoshLiteManifestJob(self, properties : Dict[str, Any], inputFile : Dict[str, Any], inputMetaFile : Dict[str, Any], outFile: List[Dict[str, Any]]) -> None:

        ## Look for solace_messaging app_manifest to be used as starter
        for job_type in inputMetaFile["job_types"]:
           if job_type["name"] == self.name or job_type["name"] == self.property_source: 
              errand_manifest_str = job_type["manifest"];
              errandManifest = yaml.load(errand_manifest_str)
              # print("Found my errand manifest " , errand_manifest_str  )

        output = {}
        output["name"] = self.name
        output["instances"] = 1
        output["lifecycle"] = "errand"
        output["templates"] = []
        output["templates"].append({"name": self.name, "release": self.release})
        output["resource_pool"] = "common-resource-pool"
        output["networks"] = []
        output["networks"].append({})
        output["networks"][0]["name"] = "test-network"

        output["properties"] = {}
        output["properties"]["cf"] = {}
        output["properties"]["cf"]["admin_user"] = "admin"
        output["properties"]["cf"]["admin_password" ] = "admin"

        output["properties"]["domain"] = "local.pcfdev.io"
        output["properties"]["app_domains"] = []
        output["properties"]["app_domains"].append( "local.pcfdev.io" )

        output["properties"]["org"] = "solace"
        output["properties"]["space"] = "solace-messaging"

        output["properties"]["ssl"] = {}
        output["properties"]["ssl"]["skip_cert_verify"] = True

        output["properties"]["security"] = {}
        output["properties"]["security"]["user"] = "solacedemo"
        output["properties"]["security"]["password"] = "solacedemo"


        output["properties"]["solace_messaging"] = {}

        output["properties"]["solace_messaging"]["user"] = "solacedemo"
        output["properties"]["solace_messaging"]["password"] = "solacedemo"
        output["properties"]["solace_messaging"]["enable_global_access_to_plans"] = True


        # Test specific settings
        output["properties"]["solace_messaging"]["auto_services"] = []
        output["properties"]["solace_messaging"]["auto_services"].append({ "name": "p-mysql", "plan" : "1gb" } )

        ## Start with app_manifest of tile
        output["properties"]["solace_messaging"]["app_manifest"] = errandManifest["solace_messaging"]["app_manifest"]

        # Using 1GB
        output["properties"]["solace_messaging"]["app_manifest"]["memory"] = "1024M"


        ## TODO: See about adding generic manifest processing

        ## TODO: FIX ME, get these from the inputFile tcp routes cf credentials 
        output["properties"]["solace_messaging"]["app_manifest"]["env"]["SOLACE_ROUTER_CLIENT_ID"] = "solace_router"
        output["properties"]["solace_messaging"]["app_manifest"]["env"]["SOLACE_ROUTER_CLIENT_SECRET"] = "1234"


        output["properties"]["provides"] = {} 
        output["properties"]["consumes"] = {}
        output["properties"]["consumes"]["solace_vmr_shared_vmr"] = { "from": "shared_vmr_list" } 

#
# Simple/Flat properties
        output["properties"]["starting_port"] = properties["starting_port"]
        output["properties"]["vmr_admin_password"] = properties["admin_password"]

# Handle special structured properties ( tls_config, tcp_routes_config, ... )

## Custom generate
        customProperties = root.generateSelectorPropertiesFromCiFile(inputFile)
        output["properties"].update(customProperties)




## Add the job
        outFile["jobs"].append(output)

# Define the errands
deploy_all = Errand("deploy-all", "solace-messaging")
delete_all = Errand("delete-all", "solace-messaging")
tests = Errand("tests", "solace-vmr", "deploy-all")
