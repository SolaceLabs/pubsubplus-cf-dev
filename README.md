# SOLACE-CF-DEV

This project provides instructions and tools to support installing and using a Solace Pivotal Tile 
on a local computer having enough resources.

RAM is biggest requirement, 16GB is the minimum, and 32GB is preferred.

## Current and future state

The initial version of this project will focus on re-using existing tools standalone without attempting to merge them.
The project also includes a subset of scripts that can use benefit from refactoring in a single solid codebase.

A future version of the project may attempt to use a single VM with all the tools. 

## Requirements

Each of the following requirements for tools and software products needs to be satisfied.

A key goal is to keep what is installed directly on your host computer to a minimum, while containing everying else inside VMs.
With this approach we keep a high level of containment within VMs and isolation from the host system.

At the end you will have these VMs:

* cli-tools for providing a reliable environment to run the scripts of this project.
 - 1GB of ram or less, just enough to run some scripts. You can adjust ram in [config.yml](cli-tools/config.yml)
* PCF Dev for hosting the solace service broker and applications
 - Size to your liking, defaults of PCF are ok, you can make it bigger if you want larger space for your apps.
* BOSH-lite for hosting VMRs
 - Size as recommended below to fit the VMRs

### Common tools

Directly on your computer, you need to:

* Install latest [Git](https://git-scm.com/downloads)
* Install latest [Virtual Box](https://www.virtualbox.org/wiki/Downloads)
* Install latest [Vagrant](https://www.vagrantup.com/downloads.htm)
* Shell access, use your preferred shell. 

### Clone this project and start up its cli-tools vm

On your computer, clone this project and start up the cli-tools vm. We will come back to use it in later steps.

~~~~
git clone https://github.com/SolaceDev/solace-cf-dev.git
cd solace-cf-dev
cd cli-tools
vagrant up
~~~~

Just an example on how to run commands in cli-tools vm, which you need to do later.
~~~~
cd solace-cf-dev
cd cli-tools
vagrant ssh

echo "I am running inside cli-tools vm"
exit
~~~~


### PCFDev

PCFDev provides a local installation of cloud foundry in a box to help test applications.

Using PCFDev you can install and test applications, bind to services that are available in PCFDev.

You can also add services to PCF Dev, such as solace-messaging and use solace-messaging with your applications.

Our goal is to to add solace-messaging as a service in PCFDev.

But first you need to install [PCFDev](https://pivotal.io/pcf-dev). Please follow these instructions:

* Install [cf cli - The Cloud Foundry Command Line Interface] (https://pivotal.io/platform/pcf-tutorials/getting-started-with-pivotal-cloud-foundry-dev/install-the-cf-cli)
* Install [PCF Plugin which is used by cf cli] (https://pivotal.io/platform/pcf-tutorials/getting-started-with-pivotal-cloud-foundry-dev/install-pcf-dev) 
* Start PCF Dev. 

~~~~
cf dev start
~~~~

At this point PCFDev is locally installed and ready host applications and services.

Optionally, you may follow the full [Getting started with pivotal cloud foundry introduction guide](https://pivotal.io/platform/pcf-tutorials/getting-started-with-pivotal-cloud-foundry-dev/introduction), as you would learn how to install a test application in PCFDev.

### BOSH-lite

We will use [BOSH-lite] (https://github.com/cloudfoundry/bosh-lite) to deploy the Solace VMR(s).

But first you need to install [BOSH-lite] (https://github.com/cloudfoundry/bosh-lite) :

* By now you have already installed  [Virtual Box](https://www.virtualbox.org/wiki/Downloads) and [Vagrant](https://www.vagrantup.com/downloads.htm).
* Clone bosh-lite in the workspace of this project.

~~~~
cd solace-cf-dev
cd workspace
git clone https://github.com/cloudfoundry/bosh-lite
cd bosh-lite
~~~~

* Then start bosh-lite  
 - Use VM_MEMORY=5000 if you want to host a single VMR
 - Use VM_MEMORY=15000 if you want to host 3 VMRs that can form an HA Group

~~~~
VM_MEMORY=5000 vagrant up --provider=virtualbox
~~~~

* VERY IMPORTANT: enable routing so communication can work between your hosting computer and the VMs, one of these should work for you.
 - bosh-lite/bin/add-route 
 - bosh-lite/bin/add-route.bat 

_Without enabled routing, the VMs will not be able to communicate. You will have re-run the add-route* scripts if you reboot your computer_

### The Solace Pivotal Tile

* The Solace Pivotal Tile is available for download from PivNet (https://network.pivotal.io/products/solace-messaging/).
* [ Solace Pivotal Tile Documentation ] (http://docs.pivotal.io/partners/solace-messaging/)
- _You may use Solace Tiles for which we have matching [templates](./templates), 
   Installation will not work without templates to match the tile version_

Please download the Solace Pivotal Tile and keep it around for later use. 

For my example I have downloaded version 0.4.0 and placed it in:

~~~~
solace-cf-dev/workspace/solace-messaging-0.4.0.pivotal
~~~~


## Connecting the dots

Now we have all the tools, the VMs created, and we can start using them.

## Do the steps below using the cli-tools VM 

~~~~
cd solace-cf-dev
cd cli-tools
vagrant ssh
~~~~

### Step 1. Extract the contents of the Solace Pivotal Tile

The pivotal file is a zip file. We need to peel this onion to get the parts we need.

Use extract_tile.sh to extract the relevant contents we need.

~~~~
cd workspace
extract_tile.sh -t solace-messaging-0.4.0.pivotal
~~~~

You will find the relevant contents extracted to ~workspace/releases

### Step 2. Install the Solace Service Broker on PCF Dev

installServiceBroker.sh script in cli-tools can do this for you:
- login to PCFDev
- install Service broker
- bind service broker to a mysql database
- add solace-messaging as a service in PCFDev
- show the contents of the marketplace at the end of the installation.

~~~~
installServiceBroker.sh 
~~~~


### Step 3. Deploy VMR(s) to BOSH-lite

_Deploy only one and only once, if not sure just use the default with no parameters_

Example deploy the default which is "Shared-VMR" with a self-signed server certificate.

~~~~
bosh_deploy.sh
~~~~

Example deploy a Community-VMR with the cert template, which uses a self-signed server certificate.

~~~~
bosh_deploy.sh -p Community-VMR -t cert
~~~~

Example deploy a Medium-HA-VMR using the ha template, which requests 3 VMR instances and uses a self-signed server certificate.

~~~~
bosh_deploy.sh -p Medium-HA-VMR -t ha
~~~~

_Keep in mind that not all Tile Releases contain all solace-messaging service plans.
And that you may only deploy a single type pool (-p) to BOSH-lite.
The flag for the pool name (-p) will correspond to a service plan in the marketplace_

Pool name to service plan mapping:

- Shared-VMR
 * shared
- Large-VMR
 * large
- Community-VMR
 * community
- Medium-HA-VMR
 * medium-ha
- Large-HA-VMR
 * large-ha

### Step 4. Go ahead and use the solace-messaging service

At this stage, solace-messaging is a service in PCFDev, and the BOSH-lite VMR deployment will auto register with the service broker
and become available for use in PCFDev.

_You can use 'cf' from cli-tools, or directly from your host computer, they both access the same PCFDev instance_

For example if you deployed the default Shared-VMR you will do this:

~~~~
cf m
cf create-service solace-messaging shared test_shared_instance
...
~~~~

Go ahead download and test the Solace Sample Apps 


# Other usefull info

## How to login and access PCFDev

~~~~
cf api https://api.local.pcfdev.io --skip-ssl-validation
cf auth admin admin
~~~~

## How to see what is offered in the marketplace

~~~~
cf marketplace
~~~~

Or better yet, in short form:
~~~~
cf m
~~~~


## Service Broker

You can use your browser to examine a [ basic service broker dashboard ](http://solace-messaging.local.pcfdev.io/)

You will need username and password: solacedemo is the default as set in [service-broker-manifest.yml](templates/service-broker-manifest.yml)

You can also run a script that will fetch a variety of information from the service broker
~~~~
getServiceBrokerInfo.sh
~~~~

## How to suspend and resume VMs

Any of the VMS we have can be suspended and later on resumed.

### Suspending all VMS
~~~~
cd solace-cf-dev
cd workspace

cd cli-tools
vagrant suspend

cd ../bosh-lite
vagrant suspend

cf dev suspend
~~~~

### Resuming all VMS
~~~~
cd solace-cf-dev
cd workspace

cd cli-tools
vagrant resume

cd ../bosh-lite
vagrant resume

cf dev resume
~~~~

## How to cleanup

### To remove a deployment from BOSH-lite

Use the same parametes with bosh_cleanup.sh as the one you used with bosh_deploy.sh .
If you remove a deployment from BOSH-lite the service-broker inventory will be out-of-sync with the deployment.
Just re-install the service broker to reset everything.

~~~~
bosh_cleanup.sh -p Shared-VMR -t cert
installServiceBroker.sh 
~~~~

### How to delete BOSH-lite VM

On your host computer (not cli-tools)

~~~~
cd solace-cf-dev
cd workspace
cd bosh-lite
vagrant destroy
~~~~

### How to delete cli-tools VM

On your host computer (not cli-tools)

~~~~
cd solace-cf-dev
cd workspace
cd cli-tools
vagrant destroy
~~~~

### How to delete PCF Dev

On your host computer (not cli-tools)

~~~~
cf dev destroy
~~~~

