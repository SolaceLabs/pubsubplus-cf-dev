#!/usr/bin/python3

import argparse
import os
import sys
import yaml
import commonUtils
import ipaddress
import jinja2
import subprocess

DOCKERFILE_STRING = """FROM solace-app:{}
RUN \\
  echo '#!/bin/bash' > /sbin/dhclient && \\
  echo 'exit 0' >> /sbin/dhclient && \\
  echo '3a:40:d5:42:f4:86' > /usr/sw/.nodeIdentifyingMacAddr && \\
  chmod +x /sbin/dhclient"""

TEMPLATE = None
BIN_DIR = os.path.dirname(os.path.realpath(__file__))
TEMPLATES_DIR = os.path.join(BIN_DIR, os.pardir, "templates")
WORKSPACE_DIR = os.environ['WORKSPACE']
BOSH_COMMON_FILE = os.path.join(BIN_DIR, "bosh-common.sh")
DEFAULT_MANIFEST_FILE = os.path.join(WORKSPACE_DIR, "bosh-solace-manifest.yml")
DEFAULT_POOL_OPTION = "Shared-VMR:1"

def initTemplateEnvironment(templateDir):
    global TEMPLATE
    if TEMPLATE == None:
        TEMPLATE = jinja2.Environment(
            loader          = jinja2.FileSystemLoader(templateDir),
            trim_blocks     = True,
            lstrip_blocks   = True
        )

def runBash(scriptPath, functionName = None):
    bashCmd = ["bash", "-c", "source {}".format(scriptPath)]
    bashCmd[2] += " && {} && env".format(functionName) if functionName != None else " && env"
    proc = subprocess.Popen(bashCmd, stdout = subprocess.PIPE)
    exportedVars = {}

    for line in proc.stdout:
        (key, _, value) = line.decode().strip().partition("=")
        exportedVars[key] = value

    try:
        out, errs = proc.communicate(timeout=15)
    except TimeoutExpired:
        proc.kill()
        out,errs = proc.communicate()
        print("Function {} in bash script {} didn't respond and timed out...", file=sys.stderr)
        sys.exit(1)
 
    return exportedVars

def getTemplatesDir():
    script = BOSH_COMMON_FILE
    fnc = "getReleaseNameAndVersion"
    exportedEnvs = runBash(script, fnc)
    versionEnvName = "SOLACE_VMR_BOSH_RELEASE_VERSION"

    if versionEnvName not in exportedEnvs:
        print("{} was not exported after executing {} on script {}".format(versionEnvName, fnc, script),
            file=sys.stderr)
        sys.exit(1)

    return os.path.join(TEMPLATES_DIR, exportedEnvs[versionEnvName])
    

def writeManifest(outFile, deploymentName, testNetworkIps, vmrJobs, brokerJob, certEnabled):
    manifest = TEMPLATE.get_template("solace-vmr-deployment.yml").render(
        name                    = deploymentName,
        testNetwork             = {"static_ips": testNetworkIps},
        vmrJobs                 = vmrJobs,
        updateServiceBrokerJob  = brokerJob,
        usingCerts              = certEnabled
    )

    with open(outFile, 'w') as f:
        print(manifest, file=f)

    print("Manifest file generated to {}".format(outFile))

def getTestNetworkIps():
    testNetwork = yaml.load(TEMPLATE.get_template("test-network.yml").render())[0]

    testSubnets = [s for s in testNetwork["subnets"]]
    testSubnet = testSubnets[0]
    otherSubnets = testSubnets[1:]

    testIpSubnet = ipaddress.ip_network(testSubnet["range"])
    otherIpSubnets = [ipaddress.ip_network(s["range"]) for s in otherSubnets]
    subnetGateway = testSubnet["gateway"]

    overlapOtherIpSubnets = [s for s in otherIpSubnets if testIpSubnet.overlaps(s)]
    for otherIpSubnet in overlapOtherIpSubnets:
        testIpSubnet = testIpSubnet.address_exclude(otherIpSubnet)

    testHosts = [h.exploded for h in testIpSubnet.hosts()]
    testHosts.remove(subnetGateway)
    return testHosts

def main(args):
    deploymentName = args["deploymentName"]
    poolDefs = [p for p in args["poolConfigs"] if p["numInstances"] > 0]
    certEnabled = not args["noCert"]
    templateDir = getTemplatesDir()

    if 'MANIFEST_FILE' in os.environ:
        manifestEnv = os.environ['MANIFEST_FILE']
        print("Found exported environment variable MANIFEST_FILE: {}".format(manifestEnv))
        outFile = os.path.expanduser(manifestEnv)
    else:
        outFile = args["outFile"]

    if not os.path.isabs(outFile):
        outFile = os.path.join(BIN_DIR, outFile)

    print("Generating manifest {}".format(outFile))
    print("Using manifest templates dir {}".format(templateDir))

    initTemplateEnvironment(templateDir)
    vmrJobs = []
    testNetworkIpList = []
    brokerVmrProps = {}
    freeIps = getTestNetworkIps()

    # Pre 1.1.0 Compatibility: Everything that uses this is for backwards comp support
    genBrokerJob =  os.path.exists(os.path.join(templateDir, "update-service-broker-job.yml"))

    if genBrokerJob:
        updateBrokerIp = freeIps.pop(0)
        testNetworkIpList.append(updateBrokerIp)

    maxAvailableVMs = len(freeIps)
    numSpecifiedVMs = sum([p["numInstances"] for p in poolDefs])
    if maxAvailableVMs < numSpecifiedVMs:
        raise ValueError(
            "Generating the Manifest failed. "
            "Total number of instances exceeded the maximum capacity of the subnet.\n\n" +
            "Please reduce the number of VMR instances:\n" +
            "   Max available VMs: {}\n".format(maxAvailableVMs) +
            "   Total given VMs:   {}"  .format(numSpecifiedVMs))
        sys.exit(1)

    for poolDef in poolDefs:
        poolName = poolDef["poolName"]
        listName = commonUtils.POOL_TYPES[poolName].listName
        numInstances = poolDef["numInstances"]
        solaceDockerImageName = commonUtils.POOL_TYPES[poolName].solaceDockerImageName

        numInstancesToAllocate = numInstances
        vmrIpList = freeIps[:numInstancesToAllocate]
        del freeIps[:numInstancesToAllocate]

        vmrJob = {}
        vmrJob["name"] = poolName
        vmrJob["poolName"] = poolName
        vmrJob["static_ips"] = vmrIpList
        vmrJob["numInstances"] = len(vmrIpList)
        vmrJob["solaceDockerFile"] =  DOCKERFILE_STRING.format(solaceDockerImageName)
        vmrJobs.append(vmrJob)

        testNetworkIpList += vmrIpList

        if genBrokerJob:
            vmrUpdate = {}
            vmrUpdate["ipList"] = vmrIpList
            vmrUpdate["numInstances"] = len(vmrIpList)
            brokerVmrProps[listName] = vmrUpdate

    brokerJob = None
    if genBrokerJob:
        brokerJob = {}
        brokerJob["ip"] = updateBrokerIp
        brokerJob["vmrPropsList"] = brokerVmrProps

    writeManifest(outFile, deploymentName, testNetworkIpList, vmrJobs, brokerJob, certEnabled)

def instancedPool(arg):
    p = {}
    if ':' in arg:
        args = arg.split(':')
        p["poolName"] = args[0]
        p["numInstances"] = int(args[1])
    else:
        p["poolName"] = arg
        p["numInstances"] = 1

    if p["poolName"] not in commonUtils.POOL_TYPES:
        raise argparse.ArgumentError()
    elif p["numInstances"] < 0:
        raise argparse.ArgumentError()
    elif commonUtils.POOL_TYPES[p["poolName"]].haEnabled:
        p["numInstances"] *= 3

    return p

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generates a basic bosh-lite manifest')

    parser.add_argument('-n', '--deployment_name', metavar='DEPLOYMENT_NAME', dest='deploymentName',
        help='The name of this deployment (default: solace-vmr-warden-deployment)',
        default='solace-vmr-warden-deployment')

    parser.add_argument('-p', '--pools', metavar='POOL_CONFIG', dest='poolConfigs',
        help='The pools and number of instances to deploy, ' + 
            'format: POOL_NAME[:NUM_INSTANCES], omit the NUM_INSTANCES to use the automatic setting (default: {})'.format(DEFAULT_POOL_OPTION),
        nargs='+',
        type=instancedPool,
        default=[instancedPool(DEFAULT_POOL_OPTION)])

    parser.add_argument('-o', '--output-file', metavar='OUT_FILE',dest='outFile',
        help='The file path to store generated bosh-lite manifest, Note: This is superseded by environment MANIFEST_FILE (default: {})'.format(DEFAULT_MANIFEST_FILE),
        default=DEFAULT_MANIFEST_FILE)

    parser.add_argument('--no-cert', dest='noCert',
        help='To not use a self-signed certificate',
        action='store_true')

    main(vars(parser.parse_args()))
