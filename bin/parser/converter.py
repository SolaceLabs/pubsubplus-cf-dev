#!/usr/bin/python3

import argparse
from schema import root
import yaml
from pooltypes import Shared, Community, Large, MediumHA, LargeHA

MANIFEST_TEMPLATE = """name: solace-vmr-warden-deployment
director_uuid: <%= `bosh status --uuid` %>

releases:
- name: docker
  version: latest
- name: solace-vmr
  version: latest
- name: solace-messaging
  version: latest

compilation:
  workers: 1
  network: test-network
  reuse_compilation_vms: true
  cloud_properties:
    name: random

update:
  canaries: 1
  canary_watch_time: 30000-240000
  update_watch_time: 30000-600000
  max_in_flight: 1

resource_pools:
- name: common-resource-pool
  network: test-network
  size: 1
  stemcell:
    name: bosh-warden-boshlite-ubuntu-trusty-go_agent
    version: latest
  cloud_properties:
    name: random

networks:
- name: test-network
  type: manual
  subnets:
  - range: 10.244.0.0/28
    gateway: 10.244.0.1
    static:
      - 10.244.0.2
    cloud_properties:
      name: random
  - range: 10.244.0.16/28
    gateway: 10.244.0.17
    static: []
    cloud_properties:
      name: random"""

def main(args) -> None:
    with open(args["in-arg"], "r") as inFile:
        inputFile = yaml.load(inFile)

    output = yaml.load(MANIFEST_TEMPLATE)
    output["jobs"] = []
    generatedProperties = root.generatePropertiesFromCiFile(inputFile)
    # FIXME
    assert "vmr_admin_password" in generatedProperties
    generatedProperties["admin_password"] = generatedProperties["vmr_admin_password"]
    del generatedProperties["vmr_admin_password"]

    Shared.generateBoshLiteManifestJob(generatedProperties, Shared.getNumInstances(args["shared"], inputFile), output)
    Community.generateBoshLiteManifestJob(generatedProperties, Community.getNumInstances(args["community"], inputFile), output)
    Large.generateBoshLiteManifestJob(generatedProperties, Large.getNumInstances(args["large"], inputFile), output)
    MediumHA.generateBoshLiteManifestJob(generatedProperties, MediumHA.getNumInstances(args["medium-HA"], inputFile), output)
    LargeHA.generateBoshLiteManifestJob(generatedProperties, LargeHA.getNumInstances(args["large-HA"], inputFile), output)
    for job in output["jobs"]:
        for network in job["networks"]:
            for static_ip in network["static_ips"]:
                output["networks"][0]["subnets"][0]["static"].append(static_ip)

    with open(args["out-arg"], "w") as outFile:
        yaml.dump(output, outFile, default_flow_style=False, width=100000000)

if __name__ == "__main__":
    parser = argparse.ArgumentParser("Convert a CI config file to a bosh-lite manifest file")
    parser.add_argument("--in-file", dest="in-arg", required=True, help="CI property input file")
    parser.add_argument("--out-file", dest="out-arg", default="output/manifest.out.yml", help="Bosh-lite manifest generated file, default \"manifest.out.yml\"")
    parser.add_argument("--shared-VMRs", dest="shared", default=None, help="Number of Shared VMR instances, default 1", type=int)
    parser.add_argument("--community-VMRs", dest="community", default=None, help="Number of Community VMR instances, default 1", type=int)
    parser.add_argument("--large-VMRs", dest="large", default=None, help="Number of Large VMR instances, default 1", type=int)
    parser.add_argument("--medium-HA-VMRs", dest="medium-HA", default=None, help="Number of Medium HA VMR instances, default 1", type=int)
    parser.add_argument("--large-HA-VMRs", dest="large-HA", default=None, help="Number of Large HA VMR instances, default 1", type=int)
    main(vars(parser.parse_args()))
