import ipaddress
from solyaml import literal_unicode
from typing import Dict, Any, Optional, List

class Errand:
    SSH_PORT = 2222 #const
    def __init__(self, name : str) -> None:
        self.name = name

    def generateBoshLiteManifestJob(self, properties : Dict[str, Any], inputFile : Dict[str, Any], outFile: List[Dict[str, Any]]) -> None:
        output = {}
        output["name"] = self.name
        output["instances"] = 1
        output["lifecycle"] = "errand"
        output["templates"] = []
        output["templates"].append({"name": self.name, "release": "solace-messaging"})
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

# Simple/Flat properties
        output["properties"]["starting_port"] = properties["starting_port"]
        output["properties"]["vmr_admin_password"] = properties["admin_password"]

# Handle special structured properties
        output["properties"]["tcp_routes_config"] = {}
        output["properties"]["tcp_routes_config"]["value"] = inputFile["tcp_routes_config"]
        output["properties"]["tcp_routes_config"]["selected_option"] = {}

#        output["properties"]["tcp_routes_config"]["selected_option"]["cf_credentials"] = inputFile["tcp_routes_config.enabled.cf_credentials"]
        output["properties"]["tcp_routes_config"]["selected_option"]["cf_credentials"] = {}
        output["properties"]["tcp_routes_config"]["selected_option"]["cf_credentials"]["identity"] = inputFile["tcp_routes_config.enabled.cf_credentials"]["identity"]
        output["properties"]["tcp_routes_config"]["selected_option"]["cf_credentials"]["password"] = inputFile["tcp_routes_config.enabled.cf_credentials"]["password"]

        ## Get all the tcp_routes_config.enabled.*tcp_route_enabled fields
        output["properties"]["tcp_routes_config"]["selected_option"]["smf_tcp_route_enabled"] = inputFile["tcp_routes_config.enabled.smf_tcp_route_enabled"]


        outFile["jobs"].append(output)

deploy_all = Errand("deploy-all")
delete_all = Errand("delete-all")
