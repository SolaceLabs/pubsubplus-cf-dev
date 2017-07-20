import argparse
import sys
import yaml
import commonUtils
import ipaddress
import jinja2

# The temporary file that we write the config to
CONFIG_FILE_NAME = "config.yml"
DOCKERFILE_STRING = """FROM solace-app:{}
RUN \\
  echo '#!/bin/bash' > /sbin/dhclient && \\
  echo 'exit 0' >> /sbin/dhclient && \\
  echo '3a:40:d5:42:f4:86' > /usr/sw/.nodeIdentifyingMacAddr && \\
  chmod +x /sbin/dhclient"""

TEMPLATE = None

def outputFiles(deploymentName, testNetworkIps, vmrJobs, brokerJob, certEnabled):
    templateFileName = "solace-vmr-deployment.yml"
    manifest = TEMPLATE.get_template(templateFileName).render(
        name = deploymentName,
        testNetwork = {
            "static_ips": testNetworkIps
        },
        vmrJobs = vmrJobs,
        updateServiceBrokerJob = brokerJob,
        usingCerts = certEnabled
    )

    print(manifest)
    yaml.load(manifest) #validating yaml syntax

def getTestNetworkIps():
    testNetFileName = "test-network.yml"
    testSubnetHookId = "TEST-SUBNET-HOOK"

    testNetwork = yaml.load(
        TEMPLATE.get_template(testNetFileName)
            .render({"static_ips": [testSubnetHookId]}))[0]

    testSubnet = next(s for s in testNetwork["subnets"] if testSubnetHookId in s["static"])
    otherSubnets = [s for s in testNetwork["subnets"] if testSubnetHookId not in s["static"]]

    testIpSubnet = ipaddress.ip_network(testSubnet["range"])
    subnetGateway = testSubnet["gateway"]

    for otherIpSubnet in map(lambda s: ipaddress.ip_network(s["range"]), otherSubnets):
        if testIpSubnet.overlaps(otherIpSubnet):
            testIpSubnet = testIpSubnet.address_exclude(otherIpSubnet)

    testHosts = list(map(lambda h: h.exploded, testIpSubnet.hosts()))
    testHosts.remove(subnetGateway)

    return testHosts

def initTemplateEnvironment(templateDir):
    global TEMPLATE
    if TEMPLATE == None:
        TEMPLATE = jinja2.Environment(
            loader          = jinja2.FileSystemLoader(templateDir),
            trim_blocks     = True,
            lstrip_blocks   = True
        )

def main(args):
    deploymentName = args["deploymentName"] or "solace-vmr-warden-deployment"
    templateDir = args["templateDir"]
    workspaceDir = args["workspaceDir"]
    certEnabled = args["cert"]

    initTemplateEnvironment(templateDir)

    vmrJobs = []
    testNetworkIpList = []
    brokerVmrProps = {}
    staticIpList = getTestNetworkIps()

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

        vmrJob = {}
        vmrJob["name"] = jobName
        vmrJob["poolName"] = poolName
        vmrJob["static_ips"] = vmrIpList
        vmrJob["numInstances"] = len(vmrIpList)
        vmrJob["solaceDockerFile"] =  DOCKERFILE_STRING.format(solaceDockerImageName)
        vmrJobs.append(vmrJob)

        testNetworkIpList += vmrIpList

        vmrUpdate = {}
        vmrUpdate["ipList"] = vmrIpList
        vmrUpdate["numInstances"] = len(vmrIpList)
        brokerVmrProps[listName] = vmrUpdate

    brokerJob = {}
    brokerJob["ip"] = updateBrokerIp
    brokerJob["vmrPropsList"] = brokerVmrProps

    outputFiles(deploymentName, testNetworkIpList, vmrJobs, brokerJob, certEnabled)

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
