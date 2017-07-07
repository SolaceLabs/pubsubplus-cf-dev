import argparse
import os.path
import subprocess
import yaml
import commonUtils
import ipaddress

# The temporary file that we write the config to
CONFIG_FILE_NAME = "config.yml"
TMP_FILE_NAME = "tmp.yml"
DOCKERFILE_STRING = """FROM solace-app:{}
RUN \\
  echo '#!/bin/bash' > /sbin/dhclient && \\
  echo 'exit 0' >> /sbin/dhclient && \\
  echo '3a:40:d5:42:f4:86' > /usr/sw/.nodeIdentifyingMacAddr && \\
  chmod +x /sbin/dhclient"""

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

def buildNetworksData(staticIps):
    return [{
        "name": "test-network",
        "subnets": [{
            "gateway": "10.244.0.1",
            "static": staticIps
        }]
    }]

def buildVmrJobData(jobName, poolName, solaceDockerImageName, vmrIpList):
    return {
        "name": jobName,
        "properties": {
            "pool_name": poolName,
            "containers": [{
                "name": "solace",
                "dockerfile": DOCKERFILE_STRING.format(solaceDockerImageName)
            }]
        },
        "networks": [{
            "name": "test-network",
            "static_ips": vmrIpList
        }]

    }

def getVmrIps(templateDir, workspaceDir):
    blankFileName = os.path.join(workspaceDir, TMP_FILE_NAME) 
    networksFileName = os.path.join(templateDir, "networks.yml")
    vmrSubnetHookId = "IP_PLACEHOLDER"

    with open(blankFileName, "w") as f:
        yaml.dump({"networks": buildNetworksData([vmrSubnetHookId])}, f, default_flow_style=False)

    # Assuming that the one subnet with a (( merge )) in its static IP list
    #   is the one which will hold all data regarding VMR static IPs
    networks = yaml.load(subprocess.check_output(["spiff", "merge", networksFileName, blankFileName]))["networks"]
    testNetwork = next(n for n in networks if n["name"] == "test-network")

    vmrSubnet = next(s for s in testNetwork["subnets"] if vmrSubnetHookId in s["static"])
    otherSubnets = [s for s in testNetwork["subnets"] if vmrSubnetHookId not in s["static"]]

    vmrIpSubnet = ipaddress.ip_network(vmrSubnet["range"])

    for otherIpSubnet in map(lambda s: ipaddress.ip_network(s["range"]), otherSubnets):
        if vmrIpSubnet.overlaps(otherIpSubnet):
            vmrIpSubnet = vmrIpSubnet.address_exclude(otherIpSubnet)

    vmrHosts = list(map(lambda h: h.exploded, vmrIpSubnet.hosts()))

    with open(blankFileName, "w") as f:
        yaml.dump(vmrHosts, f, default_flow_style=False)

#    subprocess.call(["rm", blankFileName])
    vmrHosts.reverse()
    return vmrHosts

def main(args):
    deploymentName = args["deploymentName"] or "solace-vmr-warden-deployment"
    templateDir = args["templateDir"]
    workspaceDir = args["workspaceDir"]
    certEnabled = args["cert"]

    jobs = [];
    updateServiceBrokerProps = {};
    staticIps = getVmrIps(templateDir, workspaceDir);

    for i in range(len(args["poolName"])):
        if len(vmrHosts) == 0:
            return 3

        poolName = args["poolName"][i]
        jobName = args["jobName"][i] or poolName
        listName = commonUtils.POOL_TYPES[poolName].listName
        solaceDockerImageName = commonUtils.POOL_TYPES[poolName].solaceDockerImageName
        haEnabled = commonUtils.POOL_TYPES[poolName].haEnabled

        vmrIpList = [vmrHosts.pop(0)]
        if haEnabled:
            vmrIpList.append(vmrHosts.pop(0))
            vmrIpList.append(vmrHosts.pop(0))

        jobs.append(buildVmrJobData(jobName, poolName, solaceDockerImageName, vmrIpList))
        updateServiceBrokerProps["{}_vmr_list".format(listName)] = vmrIpList
        updateServiceBrokerProps["{}_vmr_instances".format(listName)] = len(vmrIpList)

    jobs.append({
        "name": "UpdateServiceBroker",
        "properties": updateServiceBrokerProps
    })
    
    data = {
        "name": deploymentName,
        "jobs": jobs,
        "networks": buildNetworksData(vmrIpList)
    }
    return #TODO REMOVE THIS
    outputFiles(data, templateDir, workspaceDir, haEnabled, certEnabled)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generates a bosh-lite YAML manifest')
    parser.add_argument('-p', '--pool_name', dest='poolName', choices=commonUtils.POOL_TYPES.keys(), nargs='+', required=True)
    parser.add_argument('--cert', action='store_true')
    parser.add_argument('-n', '--deployment_name', dest='deploymentName')
    parser.add_argument('-j', '--job_name', dest='jobName', nargs='+')
    parser.add_argument('-d', '--template_directory', dest='templateDir', required=True)
    parser.add_argument('-w', '--workspace_dir', dest='workspaceDir', required=True)
    main(vars(parser.parse_args()))
