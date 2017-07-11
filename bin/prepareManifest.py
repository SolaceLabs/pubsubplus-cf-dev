import argparse
import os.path
import subprocess
import sys
import yaml
import commonUtils
import ipaddress

# The temporary file that we write the config to
CONFIG_FILE_NAME = "config.yml"
DOCKERFILE_STRING = """FROM solace-app:{}
RUN \\
  echo '#!/bin/bash' > /sbin/dhclient && \\
  echo 'exit 0' >> /sbin/dhclient && \\
  echo '3a:40:d5:42:f4:86' > /usr/sw/.nodeIdentifyingMacAddr && \\
  chmod +x /sbin/dhclient"""

def buildConfigData(deploymentName, jobs, testNetworkIpList):
    return {
        "name": deploymentName,
        "jobs": jobs,
        "networks": buildNetworksData(testNetworkIpList)
    }

def buildNetworksData(staticIps):
    return [{
        "name": "test-network",
        "subnets": [{
            "gateway": "10.244.0.1",
            "static": staticIps
        }]
    }]

def buildTestJobData(name, props, ipList):
    return {
        "name": name,
        "properties": props,
        "networks": [{
            "name": "test-network",
            "static_ips": ipList
        }]
    }

def buildVmrJobProps(poolName, solaceDockerImageName):
    return {
        "pool_name": poolName,
        "containers": [{
            "name": "solace",
            "dockerfile": DOCKERFILE_STRING.format(solaceDockerImageName)
        }]
    }

def outputFiles(data, templateDir, workspaceDir, haEnabled, certEnabled):
    haTemplate = haEnabled and "ha.yml" or "no-ha.yml"
    certTemplate = certEnabled and "cert.yml" or "no-cert.yml"
    
    templateFileName = os.path.join(templateDir, "solace-vmr-deployment.yml")
    networksFileName = os.path.join(templateDir, "networks.yml")
    haTemplateFileName = os.path.join(templateDir, haTemplate)
    certTemplateFileName = os.path.join(templateDir, certTemplate)
    outputFileName = os.path.join(workspaceDir, CONFIG_FILE_NAME)

    with open(outputFileName, "w") as f:
        yaml.dump(data, f, default_flow_style=False)

    subprocess.call(["spiff", "merge",
        templateFileName,
        networksFileName,
        haTemplateFileName,
        certTemplateFileName,
        outputFileName
    ])

def getTestNetworkIps(templateDir, workspaceDir):
    tmpFileName = os.path.join(workspaceDir, "tmp.yml") 
    networksFileName = os.path.join(templateDir, "networks.yml")
    testSubnetHookId = "IP_PLACEHOLDER"

    # Assuming that the one subnet with a (( merge )) in its static IP list
    #   is the one which will hold all data regarding VMR static IPs
    with open(tmpFileName, "w") as f:
        yaml.dump({"networks": buildNetworksData([testSubnetHookId])}, f, default_flow_style=False)

    fakeNetworksObj = yaml.load(subprocess.check_output(["spiff", "merge", networksFileName, tmpFileName]))
    networks = fakeNetworksObj["networks"]
    testNetwork = next(n for n in networks if n["name"] == "test-network")

    testSubnet = next(s for s in testNetwork["subnets"] if testSubnetHookId in s["static"])
    otherSubnets = [s for s in testNetwork["subnets"] if testSubnetHookId not in s["static"]]

    testIpSubnet = ipaddress.ip_network(testSubnet["range"])
    subnetGateway = testSubnet["gateway"]

    for otherIpSubnet in map(lambda s: ipaddress.ip_network(s["range"]), otherSubnets):
        if testIpSubnet.overlaps(otherIpSubnet):
            testIpSubnet = testIpSubnet.address_exclude(otherIpSubnet)

    testHosts = list(map(lambda h: h.exploded, testIpSubnet.hosts()))
    testHosts.remove(subnetGateway)

    subprocess.call(["rm", tmpFileName])
    return testHosts

def main(args):
    deploymentName = args["deploymentName"] or "solace-vmr-warden-deployment"
    templateDir = args["templateDir"]
    workspaceDir = args["workspaceDir"]
    certEnabled = args["cert"]

    jobs = []
    testNetworkIpList = []
    updateServiceBrokerProps = {}
    staticIpList = getTestNetworkIps(templateDir, workspaceDir)

    updateBrokerIp = staticIpList.pop(0)
    testNetworkIpList.append(updateBrokerIp)

    for i in range(len(args["poolName"])):
        poolName = args["poolName"][i]
        jobName = args["jobName"][i] or poolName
        listName = commonUtils.POOL_TYPES[poolName].listName
        numInstances = args["numInstances"][i]
        solaceDockerImageName = commonUtils.POOL_TYPES[poolName].solaceDockerImageName
        haEnabled = commonUtils.POOL_TYPES[poolName].haEnabled

        if len(staticIpList) < numInstances:
            sys.exit(3)

        vmrIpList = staticIpList[:numInstances]
        del staticIpList[:numInstances]

        vmrJobProps = buildVmrJobProps(poolName, solaceDockerImageName)

        jobs.append(buildTestJobData(jobName, vmrJobProps, vmrIpList))
        testNetworkIpList += vmrIpList
        updateServiceBrokerProps["{}_vmr_list".format(listName)] = vmrIpList
        updateServiceBrokerProps["{}_vmr_instances".format(listName)] = len(vmrIpList)

    jobs.append(buildTestJobData("UpdateServiceBroker", updateServiceBrokerProps, [updateBrokerIp]))
    data = buildConfigData(deploymentName, jobs, testNetworkIpList)
    outputFiles(data, templateDir, workspaceDir, haEnabled, certEnabled)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generates a bosh-lite YAML manifest')
    parser.add_argument('-p', '--pool_name', dest='poolName', choices=commonUtils.POOL_TYPES.keys(), nargs='+', required=True)
    parser.add_argument('-i', '--num_instances', dest='numInstances', type=int, nargs='+', required=True)
    parser.add_argument('--cert', action='store_true')
    parser.add_argument('-n', '--deployment_name', dest='deploymentName')
    parser.add_argument('-j', '--job_name', dest='jobName', nargs='+')
    parser.add_argument('-d', '--template_directory', dest='templateDir', required=True)
    parser.add_argument('-w', '--workspace_dir', dest='workspaceDir', required=True)
    main(vars(parser.parse_args()))
