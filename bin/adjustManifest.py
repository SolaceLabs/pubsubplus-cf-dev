import argparse
import yaml

import commonUtils
import prepareManifest

def main(args):
    print("Optimizing manifest static IPs to maximize VMR reuse...")
    deploymentName = args["deploymentName"]
    templateDir = args["templateDir"]
    manifestFile = args["manifestFile"]
    workspaceDir = args["workspaceDir"]

    prepareManifest.initTemplateEnvironment(templateDir)

    with open(manifestFile, 'r') as f:
        manifest = yaml.load(f)

    foundNetworks = [s for s in manifest["networks"] if s["name"] == "test-network"]
    foundNetwork = foundNetworks[0]
    foundSubnets = foundNetwork["subnets"]
    testSubnet = foundSubnets[0]
    testSubnet["static"] = []

    deployedIpConfig = prepareManifest.getDeployedIps(deploymentName, workspaceDir, [j["name"] for j in manifest['jobs']])
    freeIps = prepareManifest.getTestNetworkIps()

    if len([j for j in manifest["jobs"] if j["name"] == "UpdateServiceBroker"]) > 0:
        testSubnet["static"] += [freeIps.pop(0)]

    for job in manifest["jobs"]:
        poolName = job["name"]
        if poolName not in deployedIpConfig:
            continue

        numToDelete = len(deployedIpConfig[poolName]) - job["instances"]
        if numToDelete > 0:
            instances = deployedIpConfig[poolName][:numToDelete]
            deployedIpConfig["global"] = list(set(deployedIpConfig["global"]) - set(instances))
            del deployedIpConfig[poolName][:numToDelete]

    freeIps = list(set(freeIps) - set(deployedIpConfig["global"]))
    freeIps.sort()

    for job in manifest["jobs"]:
        poolName = job["name"]
        if poolName not in commonUtils.POOL_TYPES:
            continue

        numInstancesToAllocate = job["instances"]
        vmrIpList = []
        if poolName in deployedIpConfig:
            vmrIpList = deployedIpConfig[poolName]
            numInstancesToAllocate -= len(deployedIpConfig[poolName])

        vmrIpList += freeIps[:numInstancesToAllocate]
        del freeIps[:numInstancesToAllocate]

        job["networks"][0]["static_ips"] = vmrIpList
        testSubnet["static"] += vmrIpList

    with open(manifestFile, 'w') as f:
        print(yaml.dump(manifest, default_flow_style=False), file=f)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Aligns a bosh-lite YAML manifest with the deployed manifest')
    parser.add_argument('-m', '--manifest_file', dest='manifestFile', required=True)
    parser.add_argument('-n', '--deployment_name', dest='deploymentName', required=True)
    parser.add_argument('-d', '--template_directory', dest='templateDir', required=True)
    parser.add_argument('-w', '--workspace_dir', dest='workspaceDir', required=True)
    main(vars(parser.parse_args()))
