# SOLACE-MESSAGING-CF-DEV

This project provides instructions and tools to support installing and using a Solace Pivotal Tile. In order to install and use a Solace Pivotal Tile the following deployments must be accessible on the local computer: (this guide will assist you with installing and deploying these)

* BOSH-lite deployment to host VMRs (and a CF deployment if you are on linux)
* CF Deployment to host the Solace Service Broker and p-mysql

If you are using Windows, there are a few limitations to the deployment. Windows is not yet supported by BUCC so you will have to deploy BOSH-Lite locally. Additionally, cf logging does not work in BOSH-Lite if it is deployed in windows, so you will need to set up a separate PCFDev virtual machine to host the CF deployment and p-mysql. Therefore the steps for deploying on windows and linux differ, and both are outlined in this document.

## Table of Contents:

* [Hardware Requirements](#hardware-requirements)
* [Installation Requirements](#installation-requirements)
* [Overview of Windows Deployment](#windows-overview)
* [Installation on Windows](#installation-on-windows)
* [Overview of Linux Deployment](#linux-overview)
* [Installation on Linux](#installation-on-linux)
* [Solace Messaging Deployment] (#solace-messaging-deployment)
* [Other useful commands and tools](#other-useful-commands-and-tools)

## Hardware Requirements

Each of the following requirements for tools and software products needs to be satisfied.

A key goal is to keep what is installed directly on your host computer to a minimum, while containing everything else inside VMs.
With this approach we keep a high level of containment within VMs and isolation from the host system.

RAM is biggest requirement, 16GB is the minimum, and 32GB is preferred.

You will also need at least 40GB of free disk space.

### Installation Requirements

While there may be no need for internet access once the setup is completed, it is certainly required during the setup.
All the steps during the setup will access the internet to download and install correctly.

Directly on your computer, you must have or get the following:

* Install latest [Git](https://git-scm.com/downloads) (version 2.7.1+)
* Install latest [Virtual Box](https://www.virtualbox.org/wiki/Downloads) (version 5.1.18+)
* Install latest [Vagrant](https://www.vagrantup.com/downloads.htm) (version 1.9.1+)
* Shell access, use your preferred shell.
 
If you are installing this in a VM you will need to ensure that:

* Intel VT-x/EPT or AMD-RVI Virtualization is enabled.

## Windows Overview

Here is an overview of what this project will help you install if you are using a windows deployment:

![](resources/overview.png)

This guide will help you install the following VMs:

* cli-tools to provide a reliable environment to run the scripts of this project.
  - Tested with 512mb of ram, just enough to run some scripts.
  - You may wish to increase the ram if you want to test applications from this VM. The setting for ram is in [config.yml](cli-tools/config.yml).
* PCF Dev for hosting the solace service broker and your applications.
  - Tested with 4GB, but you may size to suite your needs for hosting for your apps.
* BOSH-lite for hosting VMRs.
  - Size as recommended below to fit the VMRs.

## Installation on Windows

The goal of the installation steps is to start the required VMs. Click [here](#installation-on-linux) for the installation steps for linux.

![](resources/installation.png)

_The setup was last tested on Windows host with 32GB of RAM, using:_
- git version 2.8.2.windows.1
- cf version 6.21.1+6fd3c9f-2016-08-10
- Vagrant 1.9.1
- VirtualBox Version 5.1.10 r112026 (Qt5.6.2)

### Installation Step 1 - Clone this project and start up its cli-tools vm

On your computer, clone this project and start up the cli-tools vm. We will come back to use it in later steps.

~~~~
git clone https://github.com/SolaceLabs/solace-messaging-cf-dev.git
cd solace-messaging-cf-dev
cd cli-tools
vagrant up
~~~~


Just an example on how to run commands in cli-tools vm, which you need to do later.
~~~~
cd solace-messaging-cf-dev
cd cli-tools
vagrant ssh

echo "I am running inside cli-tools vm"
exit
~~~~

_The cli-tools VM will contains all the necessary tools to run the scripts of this project, including 
another clone of this project. The workspace folder visible on your computer is shared with the cli-tools VM._

### Installation Step 2 - PCFDev

PCFDev provides a local installation of cloud foundry in a box to help test applications.

Using PCFDev you can install and test applications, bind to services that are available in PCFDev.

You can also add services to PCF Dev, such as solace-messaging and use solace-messaging with your applications.

Our goal is to to add solace-messaging as a service in PCFDev.

You need to install [PCFDev](https://pivotal.io/pcf-dev). Please follow these instructions:

* Install [cf cli - The Cloud Foundry Command Line Interface](https://pivotal.io/platform/pcf-tutorials/getting-started-with-pivotal-cloud-foundry-dev/install-the-cf-cli)
* Install [PCF Plugin which is used by cf cli](https://pivotal.io/platform/pcf-tutorials/getting-started-with-pivotal-cloud-foundry-dev/install-pcf-dev) 
* Start PCF Dev, using 4GB of ram. You may choose to adjust this.

~~~~
cf dev start -m 4096
~~~~

At this point PCFDev is locally installed and ready to host applications and services.

Optionally, you may follow the full [Getting started with pivotal cloud foundry introduction guide](https://pivotal.io/platform/pcf-tutorials/getting-started-with-pivotal-cloud-foundry-dev/introduction), as you would learn how to install a test application in PCFDev.

### Installation Step 3 - BOSH-lite

We will use [BOSH-lite](https://github.com/cloudfoundry/bosh-lite) to deploy the Solace VMR(s).

But first you need to install [BOSH-lite](https://github.com/cloudfoundry/bosh-lite):

* By now you have already installed  [Virtual Box](https://www.virtualbox.org/wiki/Downloads) and [Vagrant](https://www.vagrantup.com/downloads.htm).
* Clone bosh-lite in the workspace of this project.

~~~
cd solace-messaging-cf-dev
cd workspace
git clone https://github.com/cloudfoundry/bosh-lite
cp ../bin/create_swap.sh bosh-lite
cd bosh-lite
~~~

* Then start bosh-lite:
  - Use VM_MEMORY=5000 if you want to host a single VMR
  - Use VM_MEMORY=15000 if you want to host 3 VMRs that can form an HA Group
  - In general, use VM_MEMORY=5000 * [Number-of-VMRs]
  - Also note the additional swap space, use 2048 Mb per VMR.

~~~
set VM_MEMORY=5000
vagrant up --provider=virtualbox
vagrant ssh -c "sudo /vagrant/create_swap.sh 2048 additionalSwapFile"
~~~

* VERY IMPORTANT: enable routing so communication can work between your hosting computer and the VMs, one of these should work for you.
  - bosh-lite/bin/add-route
  - bosh-lite/bin/add-route.bat

_Without enabled routing, the VMs will not be able to communicate. You will have re-run the add-route* scripts if you reboot your computer_

## Installation on Linux: 

The goal of the installation is to prepare the required deployments.

![](resources/installation-linux.png)

_The setup was last tested on Linux host with 64GB of RAM, using:_
- git version 1.8.3.1
- Vagrant 1.9.7
- VirtualBox Version 5.1.22 r115126 

### Installation Step 1 - Clone this project and start up its cli-tools vm

On your computer, clone this project and start up the cli-tools vm. We will come back to use it in later steps.

~~~~
git clone https://github.com/SolaceLabs/solace-messaging-cf-dev.git
cd solace-messaging-cf-dev
cd cli-tools
vagrant up
~~~~


Just an example on how to run commands in cli-tools vm, which you need to do later.
~~~~
cd solace-messaging-cf-dev
cd cli-tools
vagrant ssh

echo "I am running inside cli-tools vm"
exit
~~~~

_The cli-tools VM will contains all the necessary tools to run the scripts of this project, including 
another clone of this project. The workspace folder visible on your computer is shared with the cli-tools VM._

### Installation Step 2 - BUCC

Since you are using linux you can use BUCC, which is a BOSH-Lite wrapper and can be installed by running the script setup_bosh_bucc. This will download BUCC from the bucc repository: [https://github.com/starkandwayne/bucc](https://github.com/starkandwayne/bucc). 

To set up bucc, the script can be found in [bin/setup_bosh_bucc.sh](bin/setup_bosh_bucc). This will download and set up the bucc cli, and create a swap file and enable routing so that your hosting computer can communicate with the VMs and bosh. 

~~~~
cd bin
./setup_bosh_bucc.sh 
exit
~~~~

### Installation Step 3 - Deploy CF and p-mysql 

You can deploy CF and CF-mysql in bosh-lite to host the solace service broker. In order to do this, run [cf_deploy.sh](bin/cf_deploy.sh) and [cf_mysql_deploy.sh](bin/cf_mysql_deploy.sh). This script will deploy cf from this repository: [https://github.com/cloudfoundry/cf-deployment](https://github.com/cloudfoundry/cf-deployment) and deploy cf-mysql from this repository: [https://github.com/cloudfoundry/cf-mysql-deployment](https://github.com/cloudfoundry/cf-mysql-deployment).

~~~~
cd bin
./cf_deploy.sh 
./cf_mysql_deploy.sh 
~~~~ 

## Solace Messaging Deployment

The goal of the deployment steps is to install Solace Messaging into the running CF environment.

![](resources/deployment.png)

### Deployment - Prerequisites

#### The Solace Pivotal Tile

* The Solace Pivotal Tile is available for download from [PivNet](https://network.pivotal.io/products/solace-messaging/).
* [Solace Pivotal Tile Documentation](http://docs.pivotal.io/partners/solace-messaging/)
  - _You may use Solace Tiles for which we have matching [templates](./templates), 
   Installation will not work without templates to match the tile version_

Please download the Solace Pivotal Tile and keep it around for later use. 

For my example I have downloaded version 1.4.0 and placed it in:

~~~~
solace-messaging-cf-dev/workspace/solace-messaging-1.4.0.pivotal
~~~~


#### Login to cli-tools VM

All deployment steps require you to be logged in to the cli-tools VM 

~~~~
cd solace-messaging-cf-dev
cd cli-tools
vagrant ssh
~~~~

### Deployment Step 1 - Extract the contents of the Solace Pivotal Tile

The pivotal file is a zip file. We need to peel this onion to get the parts we need.

Use extract_tile.sh in the [bin/dev](bin/dev) directory to extract and then upload the relevant contents we need.

~~~~
cd bin/dev
extract_tile.sh -t solace-messaging-1.4.0.pivotal
solace_upload_releases.sh
~~~~

You will find the relevant contents extracted to ~/workspace/releases

### Deployment Step 2 - Deploy 

This will deploy the VMR(s) to BOSH-lite and run an bosh errand to deploy the Solace Service Broker and add solace-messaging as a service in PCFDev

_If not sure what to pick just use the default with no parameters. Otherwise, please ensure that you have allocated enough memory to the BOSH-lite VM for the number and types of VMRs that you want to deploy_

 - On Linux: 

**Example:** Deploy the default which is a single instance of a Shared-VMR using a self-signed server certificate and evaluation vmr edition.
~~~~
./solace_deploy.sh
~~~~

The deployment property file used as default can be found under [templates](templates/1.4.0/),  you can make a copy and edit it.

**Example:** Use a customized deployment property file from which a new bosh-manifest will be generated. 
~~~~
cd solace-messaging-cf-dev/bin
./deployer.sh -c custom_properties.yml
~~~~

 - On Windows: 

To deploy on windows you will need to modify the deploy script (solace_deploy.sh) in bin/dev in the bosh command to use the windows operations file, and change the domains to local.pcfdev.io. More details on this in the [operations](operations) directory. Once this script has been modified, you can use it to deploy on windows with a separate PCFDev VM, or just run the bosh deploy command directly. 

_The current deployment can be updated by simply rerunning the deployment script._

## Using the Deployment

At this stage, solace-messaging is a service in PCFDev or CF, and the BOSH-lite VMR deployment will auto register with the service broker
and become available for use in PCFDev.

_You can use 'cf' from cli-tools, or directly from your host computer, they both access the same PCFDev instance_

For example if you deployed the default Shared-VMR, a "shared" service plan will be available and you can do this:

~~~~
cf m
cf create-service solace-messaging shared solace-messaging-demo-instance
cf services
~~~~

Ideally you will bind the service you created to an application and use it.
You can go ahead download and test the [Solace Sample Apps](https://github.com/SolaceLabs/sl-cf-solace-messaging-demo), or create some of your own.

# Other useful commands and tools

## How to login and access PCFDev

On Windows: 

~~~~
cf api https://api.local.pcfdev.io --skip-ssl-validation
cf auth admin admin
~~~~

On Linux: 

~~~
cf api https://api.bosh-lite.com --skip-ssl-validation
cf auth admin admin
~~~

## How to see what is offered in the marketplace

~~~~
cf marketplace
~~~~

Or better yet, in short form:
~~~~
cf m
~~~~

## Service Broker

You can use your browser to examine the deployed [ service broker dashboard ](http://solace-messaging.local.pcfdev.io/)

You will need a username and password: solacedemo is the default as set for this deployment.

You can also run a script that will fetch a variety of information from the service broker
~~~~
getServiceBrokerInfo.sh
~~~~

## How to suspend and resume VMs

The VMs we created can be suspended and resumed at a later time.
This way you don't need to recreate them. Their state is saved to disk.

### Suspending all VMS
~~~~
cd solace-messaging-cf-dev

cd cli-tools
vagrant suspend

cd ../workspace/bosh-lite
vagrant suspend
~~~~

(and to suspend the PCFDev VM on windows:)
~~~~
cf dev suspend
~~~~

### Resuming all VMS
~~~~
cd solace-messaging-cf-dev

cd cli-tools
vagrant resume

cd ../workspace/bosh-lite
vagrant resume

cf dev resume
~~~~


## Working with VMR in the BOSH-lite deployment

### Listing the VMs

From the cli-tools vm:

~~~~
bosh vms
~~~~

### Access the VMR cli

Get the list of vms, to find the IP address of the VMR instance you want:
~~~~
bosh vms
~~~~

Now ssh to the VMR, the default password is 'admin'.
_You can find the admin password and other goodies in the generated manifest in ~workspace/bosh-solace-manifest.yml_

~~~~
ssh -p 2222 admin@10.244.0.3
~~~~

## How to cleanup

### Delete the Solace VMR Service
~~~~
cf delete-service -f solace-messaging-demo-instance
~~~~

### Deleting the deployment

From the cli-tools vm:
~~~~
cleanup.sh
~~~~

### How to delete BOSH-lite VM

On your host computer (not cli-tools)

~~~~
cd solace-messaging-cf-dev
cd workspace
cd bosh-lite
vagrant destroy
~~~~

### How to delete cli-tools VM

On your host computer (not cli-tools)

~~~~
cd solace-messaging-cf-dev
cd cli-tools
vagrant destroy
~~~~

### How to delete PCF Dev

On your host computer (not cli-tools)

~~~~
cf dev destroy
~~~~

