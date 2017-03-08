# SOLACE-CF-DEV

This project provides instructions and tools to support installing and using a Solace Pivotal Tile 
on a local computer having enough resources.

TODO: Confirm sizing....
RAM is biggest requirement, 16GB is the minimum, and 32GB is preferred.

There are many options that may be explored on how to accomplish this goal, the ideal would be a single VM
with all the tools. 

The first version of this project will focus on re-using existing tools standalone without attempting to merge them.


## Requirements

Each of the following requirements for tools and software products needs to be satisfied.
A key goal is to keep what is installed directly on your host computer to a minimum, while containing everying else inside VMs.
With this approach we keep a high level of containment within VMs and isolation from the host system.

At the end you will have these VMs:

* cli-tools for providing a reliable environment to run the scripts of this project.
 - Tiny 1GB of ram or maybe less, just enough to run some scripts..
* PCF Dev for hosting the solace service broker and applications
 - Size to your liking, defaults of PCF are ok, you can make it bigger if you want larger space for your apps.
* BOSH-lite for hosting VMRs
 - Size as recommended below to fit the VMRs

### Common tools

Directly on your compter, you need to:

* Install latest [Git](https://git-scm.com/downloads)
* Install latest [Virtual Box](https://www.virtualbox.org/wiki/Downloads)
* Install latest [Vagrant](https://www.vagrantup.com/downloads.htm)
* Shell access, use your prefered shell. 

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

But first you need to install [BOSH-lite]

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

### Step 2. Install the Solace Service Broker on PCF Dev

A Script in cli-tools can do this:

TODO: Implement this..
~~~~
installServiceBroker.sh 
~~~~

### Step 3. Deploy VMR(s) to BOSH-lite

Example deploy a Shared-VMR with the cert template, which uses a self-signed server certificate.

~~~~
bosh_deploy.sh -p Shared-VMR -t cert
~~~~


Example deploy a Medium-HA-VMR using the ha template, which requests 3 VMR instances and uses a self-signed server certificate.

~~~~
bosh_deploy.sh -p Medium-HA-VMR -t ha
~~~~


## Service Broker

TODO: ...

## How to cleanup

TODO: ...
