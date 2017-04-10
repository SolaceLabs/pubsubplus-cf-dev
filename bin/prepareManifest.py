import argparse
import os
import yaml

# The temporary file that we write the config to
CONFIG_FILE_NAME = "config.yml"
POOL_TYPES = {
    # poolName : ListName
    "Shared-VMR": "shared",
    "Medium-HA-VMR": "medium_ha",
    "Large-VMR": "large",
    "Large-HA-VMR": "large_ha",
    "Community-VMR": "community",
}
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
    haTemplateFileName = os.path.join(templateDir, haTemplate)
    certTemplateFileName = os.path.join(templateDir, certTemplate)
    outputFileName = os.path.join(workspaceDir, CONFIG_FILE_NAME)

    with open(outputFileName, "w") as f:
        yaml.dump(data, f, default_flow_style=False)
        os.system("spiff merge {} {} {} {}".format(
            templateFileName,
            haTemplateFileName,
            certTemplateFileName,
            outputFileName)
        )

def main(args):
    poolName = args["poolName"]
    deploymentName = args["deploymentName"] or "solace-vmr-warden-deployment"
    jobName = args["jobName"] or poolName
    listName = POOL_TYPES[poolName]
    solaceDockerImageName = args["solaceDockerImageName"]
    vmrIpList = ["10.244.0.3"]
    certEnabled = args["cert"]
    haEnabled = args["ha"]
    if haEnabled:
        vmrIpList.append("10.244.0.4")
        vmrIpList.append("10.244.0.5")
    templateDir = args["templateDir"]
    workspaceDir = args["workspaceDir"]
    
    data = {
        "name": deploymentName,
        "jobs": [{
            "name": jobName,
            "properties": {
                "pool_name": poolName,
            	"containers": [{
                    "name": "solace",
                    "dockerfile": DOCKERFILE_STRING.format(solaceDockerImageName)
                }]
            }
        }, {
            "name": "UpdateServiceBroker",
            "properties": {
                "{}_vmr_list".format(listName): vmrIpList,
                "{}_vmr_instances".format(listName): len(vmrIpList)
            }
        }]
    }
    outputFiles(data, templateDir, workspaceDir, haEnabled, certEnabled)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generates a bosh-lite YAML manifest')
    parser.add_argument('-p', '--pool_name', dest='poolName', choices=POOL_TYPES.keys(), required=True)
    parser.add_argument('--cert', action='store_true')
    parser.add_argument('--ha', action='store_true')
    parser.add_argument('-n', '--deployment_name', dest='deploymentName')
    parser.add_argument('-j', '--job_name', dest='jobName')
    parser.add_argument('-d', '--template_directory', dest='templateDir', required=True)
    parser.add_argument('-s', '--solace_docker_image_name', dest='solaceDockerImageName', required=True)
    parser.add_argument('-w', '--workspace_dir', dest='workspaceDir', required=True)
    main(vars(parser.parse_args()))
