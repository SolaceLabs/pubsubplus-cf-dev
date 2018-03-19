# DEV

Development and testing support tools.

## Table of contents

[About](#About)

[Requirements](#Requirements)

[Deployment](#Deployment)


<a name="About"></a>
## About

This folder contains basic scripts to support a deployment of solace messaging on bosh-lite.
This can be used for development and testing.

<a name="Requirements"></a>
## Requirements

In order to use solace-messaging on a development environment these requirements need to be met:

* Install [Virtualbox](https://www.virtualbox.org/), tested on 5.2.6
* Install [BOSH Cli v2](https://bosh.io/docs/cli-v2.html#install)
* Install [CF Cli](https://github.com/cloudfoundry/cli#downloads)
* Install [jq](https://stedolan.github.io/jq/)

### Installation overview

The remainder of this document will guide you through the installation of:

* A Virtualbox BOSH-Lite [bosh-deployment](https://github.com/cloudfoundry/bosh-deployment), using [BUCC](https://github.com/starkandwayne/bucc)
* [Cloud Foundry](https://github.com/cloudfoundry/cf-deployment) deployment on BOSH-Lite
* [MySQL for Cloud Foundry](https://github.com/cloudfoundry/cf-mysql-deployment)
* [Solace Messaging](#Deployment)

<a name="install_bosh"></a>
### Install BOSH

A BOSH-Lite [bosh-deployment](https://github.com/cloudfoundry/bosh-deployment) is required with sufficient RAM and Disk to support the desired installation.

A quick way to get started with BOSH is to use [BUCC](https://github.com/starkandwayne/bucc).

Add cf-solace-messaging-deployment/dev to the $PATH, assuming you have cloned this project in your $HOME folder.

~~~~
export PATH=$HOME/cf-solace-messaging-deployment/dev:$PATH
cd cf-solace-messaging-deployment
~~~~

Optional - Adjust settings for VM_MEMORY, VM_SWAP, VM_CPUS, VM_DISK_SIZE.
The values shown below are the current defaults. Which are enough for the full installation of CF, P-MYSQL, and a single Solace VMR.
You should increase the RAM by 4GB and SWAP by 2GB per additional VMR. 
The VM_DISK_SIZE must be increased when using 3 or more VMRs.
~~~~
export VM_MEMORY=8192
export VM_SWAP=8192
export VM_CPUS=4
export VM_DISK_SIZE=65_536
~~~

This script will use [BUCC](https://github.com/starkandwayne/bucc) on a Linux or Mac, there is NO support for Windows yet. 
This script will prompt you for administrator password in order to add routes. It will setup additional swap space in the BOSH-Lite VM.

~~~
setup_bosh_bucc.sh
~~~~

Once done the script will create workspace/bosh_env.sh

Verify bosh is deployed, we expect to see no listed VMs, and no errors accessing BOSH.
~~~~
source workspace/bosh_env.sh
bosh vms
~~~~

<a name="install_cf"></a>
### Install Cloud Foundry

How to deploy cloud foundry to BOSH. 
This requires access to BOSH, this should be already done from the previous step.

~~~~
cf_deploy.sh
~~~~

Cloud Foundry (CF) Is now installed, verify access to CF. Expect no errors.

~~~~
cf_env.sh
cf orgs
cf m
~~~~

<a name="install_cf_mysql"></a>
### Install MySQL for Cloud Foundry

How to deploy MySQL for cloud foundry to BOSH. 

~~~~
cf_env.sh
cf_mysql_deploy.sh
~~~~

Verify that MySQL is installed and that its plans are visible in Cloud Foundry

~~~~
cf target -o test
cf m
~~~~

<a name="Deployment"></a>
## Deployment

With the installation of BOSH, Cloud Foundry and MySQL for Cloud Foundry we are now ready to add Solace Messaging.

<a name="deploy_extract"></a>
### Obtain and extract the BOSH releases of a Solace Pivotal Tile.

For example, having obtained solace-messaging-1.4.0.pivotal from Solace:

~~~
extract_tile.sh -t solace-messaging-1.4.0.pivotal
~~~

This will unzip the file and keep the required BOSH releases under workspace/releases/*.tgz

<a name="deploy_upload"></a>
### Upload the BOSH releases 

This will uploaded the releases found in workspace/releases/*.tgz to BOSH
~~~~
solace_upload_releases.sh
~~~~

<a name="deploy_solace_messaging"></a>
### Deploy Solace Messaging 

Adjust the [vars.yml](../vars.yml) to set the number of VMRs, set shared_plan_instances to 1.
By default an evaluation VMR is assumed to be in use. 

If you are using the enterprise edition:
~~~~
export VMR_EDITION="enterprise"
~~~~

This will deploy Solace Messaging to BOSH and adds Solace Messaging as a Service to Cloud Foundry

~~~~
solace_deploy.sh
~~~~

Verify solace-messaging is available

~~~~
cf target -o test
cf m
~~~~

You expect no errors, and you should see solace-messaging with its plans visible in the marketplace.


### Creating and using solace-messaging services

So you have a deployment, you can go ahead and try out [Solace Messaging tutorials and sample application for Cloud Foundry](http://dev.solace.com/get-started/pcf-tutorials/)

## Other notes.

There are current limitations with the bosh-virtualbox and the deployment cannot be simply resumed if virtual box was shutdown.
If you want to keep your deployment on virtual box, remember to pause and save it before any reboot/shutdown.


<a name="delete_solace_messaging"></a>
### Deleting the Solace Messaging Deployment

This script will delete the solace-messaging deployment, remove the solace bosh releases and delete any orphaned disks.

~~~~
solace_delete_deployment.sh
~~~~

<a name="uninstall_everything"></a>
### Uninstall everything

This is usefull to delete everything, or reset in order to start over.

To delete the full setup of the BOSH,  removing all its contents, allocated disks, and delete the VM.

~~~~
destroy_bosh_bucc.sh
~~~~

