# SOLACE-MESSAGING-CF-DEV

This project provides instructions and tools that support local development and testing of Solace Messaging for Cloud Foundry.

## Table of Contents:

* [About](#about)
* [Operating System](#operating-system)
* [Hardware Requirements](#hardware-requirements)
* [Installation Requirements](#installation-requirements)
* [Installation on Windows](#installation-on-windows)
  * [Overview of Windows Deployment](#windows-overview)
  * [Installation Steps on Windows](#installation-steps-on-windows)
* [Installation on Linux](#installation-on-linux)
  * [Overview of Linux Deployment](#linux-overview)
  * [Installation Steps on Linux](#installation-steps-on-linux)
* [Solace Messaging Deployment](#solace-messaging-deployment)
* [Other useful commands and tools](#other-useful-commands-and-tools)

<a name="about"></a>
# About

A Deployment Solace Messaging for Cloud Foundry has prerequisites for which this guide will provide steps to satisfy:

- A deployment of [BOSH](https://github.com/cloudfoundry/bosh) or [BOSH-lite](https://github.com/cloudfoundry/bosh-lite): Hosting the Solace PubSub+ instances.
- A deployment of [Cloud Foundry](https://github.com/cloudfoundry/cf-deployment): Hosting the Solace Service Broker and Test Applications.
- A [Solace BOSH Deployment](https://github.com/SolaceDev/cf-solace-messaging-deployment/): Defines and produces the bosh manifests to deploy Solace Messaging for Cloud Foundry

<a name="operating-system"></a>
# Operating system

This project and its tools will support a deployment on Linux, Mac and the Windows Subsystem for Linux (WSL) which is available on Windows 10 and later.

Any instructions given for Linux will work on Mac and the WSL.

This guide will provide different steps for deploying on Windows than Linux ( Mac ).

<a name="hardware-requirements"></a>
# Hardware Requirements

Each of the following requirements for tools and software products needs to be satisfied.

A key goal is to keep what is installed directly on your host computer to a minimum, while containing everything else inside VMs and the WSL.
With this approach we keep a high level of containment within VMs and isolation from the host system.

RAM is biggest requirement, 16GB is the minimum, and 32GB is preferred.

You will also need at least 40GB of free disk space.

<a name='installation-requirements'></a>
# Installation Requirements

While there may be no need for internet access once the setup is completed, it is certainly required during the setup.
All the steps during the setup will access the internet to download and install correctly.

Directly on your computer, you must have or get the following:

* Install latest [Git](https://git-scm.com/downloads) (version 2.7.1+)
* Install latest [Virtual Box](https://www.virtualbox.org/wiki/Downloads) (version 5.2.6+)
* Unless you are installing on WSL, you will also need the latest [Vagrant](https://www.vagrantup.com/downloads.htm) (version 2.0.1+)
* Shell access, use your preferred shell.
 
If you are installing this in a VM you will need to ensure that:

* Intel VT-x/EPT or AMD-RVI Virtualization is enabled.


<a name="installation-on-windows"></a>
# Installation on Windows

<a name="windows-overview"></a>
## Overview of Windows Deployment

Here is an overview of what this project will help you install if you are using a Windows deployment:

![](resources/overview-wsl.png)

This guide will help you install Bosh VM for hosting Solace PubSub+ instances.

<a name="installation-steps-on-windows"></a>
## Installation Steps on Windows

The goal of the installation steps is to start the required VMs on Windows.

_The setup was last tested on Windows host with 32GB of RAM, using:_
- WSL with Ubuntu 18.04
- cf version 6.38.0+7ddf0aadd.2018-08-07
- VirtualBox Version 5.2.18r124329

### Installation on WSL - Step 1 - Install the Windows Subsystem for Linux

Ensure VirtualBox is installed.

Follow the [WSL installation instructions](https://docs.microsoft.com/en-us/windows/wsl/install-win10) and select the Ubuntu distribution.

### Installation on Windows - Step 2 - Run the installer that sets up Bosh and CF

First of all, enable routing so communication can work between your hosting computer and the VMs, one of these should work for you.

In a Windows Administrator CMD console, run:

~~~
route add 10.244.0.0/19 192.168.50.6
~~~

_Without enabled routing, the VMs will not be able to communicate. You will have re-run this if you reboot your computer_

Open an Ubuntu shell by typing Ubuntu into the Windows search tool and clicking on the application's icon.

This project provides a script that installs bosh assumes certain file locations. These can be overridden by environment variables. These variables with their defaults are:

~~~
WIN_DRIVE: /mnt/c
VIRTUALBOX_HOME: $WIN_DRIVE/Program Files/Oracle/VirtualBox
GIT_REPO_BASE: https://github.com/SolaceDev
~~~

In WSL, the drives containing the Windows file systems are accessible through /mnt/c, mnt/d etc.

If these values are correct for your system then you can invoke the Bosh/CF installation script by running

~~~
curl -L https://github.com/SolaceDev/solace-messaging-cf-dev/raw/master/bin/setup_bosh_on_wsl.sh | bash
~~~

Otherwise clone the repository, set the environment variables correctly and run the script. The script expects the repository to be under $HOME/repos. For example if VirtualBox was installed to a different directory, do this:

~~~
cd
mkdir repos
cd repos
git clone https://github.com/SolaceDev/solace-messaging-cf-dev/
export VIRTUALBOX_HOME=/mnt/d/Apps/VirtualBox
solace-messaging-cf-dev/bin/setup_bosh_on_wsl.sh
~~~

That script will install ruby and other required programs and libraries, clone the repository if it's not already cloned, create the bosh virtual machine and deploy Cloud Foundry.

The script also calls another script, bosh_lite_vm.sh, which downloads and uses [BUCC](https://github.com/starkandwayne/bucc). That provides a convenient wrapper around a [bosh-deployment](https://github.com/cloudfoundry/bosh-deployment).

It creates the BOSH-lite VM. The following environment variable parameters are available to adjust the size of the BOSH-lite VM when creating it.
  - VM_MEMORY=8192 is the default: it is enough to support the deployment of CF, CF-MYSQL and a single PubSub+ instance
  - VM_SWAP=8192 is the default: it is enough to support up to 4 PubSub+ instances before needing to add more.
  - VM_DISK_SIZE=65_536 is the default: it is enough to support up to 4 PubSub+ instances before needing more storage.
  - VM_EPHEMERAL_DISK_SIZE=32_768 is the default: it provides enough room to spare for multiple deployments and re-deployment. You should not need to adjust this.
  - In general under a BOSH-lite deployment you should add 4000 Mb to VM_MEMORY and 2000 Mb to VM_SWAP per additional PubSub+ instance.

The script also copies the command line programs bosh, bucc and cf to /usr/local/bin. Further, it adds a command to your .profile which sets up the proper bosh and cf environment variables to be able to connect to the cf environment as soon as you log into WSL.

Once that is complete then you can deploy Solace as per [these instructions.](#solace-messaging-deployment). Note that it is not necessary to use the cli-tools vagrant virtual machine - the commands should work fine running under WSL.

<a name="installation-on-linux"></a>
# Installation on Linux

<a name="linux-overview"></a>
## Overview of Linux Deployment

The goal of the installation is to prepare the required deployments.

![](resources/installation-linux.png)

This guide will help you install and deploy the following:

* cli-tools to provide a reliable environment to run the scripts of this project.
  - Tested with 512mb of ram, just enough to run some scripts.
  - You may wish to increase the ram if you want to test applications from this VM. The setting for ram is in [config.yml](cli-tools/config.yml).
* BOSH-lite for hosting CF, Solace PubSub+ instances.
  - Size as recommended below to fit the PubSub+ instances.
* A Deployment of CF and CF-MYSQL to BOSH-lite.

The setup was last tested on:

_Linux host with 64GB of RAM, using:_
- git version 1.8.3.1
- Vagrant 1.9.7
- VirtualBox Version 5.1.22 r115126 

_Mac host with 16GB of RAM, using:_
- git version 2.15.1
- Vagrant 2.0.1
- VirtualBox Version 5.2.6

<a name="installation-steps-on-linux"></a>
# Installation Steps on Linux

These steps are also applicable on a Mac.

### Installation on Linux - Step 1 - Clone this project and start up its cli-tools vm

On your computer, clone this project and start up the cli-tools vm. We will come back to use it in later steps.

~~~~
git clone https://github.com/SolaceLabs/solace-messaging-cf-dev.git
cd solace-messaging-cf-dev
git submodule init
git submodule update
~~~~

Startup the cli-tools vm. 

~~~~
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

### Installation on Linux - Step 2 - BOSH-lite VM

A quick way to get started with BOSH is to use [BUCC](https://github.com/starkandwayne/bucc), it provides a convenient wrapper around a [bosh-deployment](https://github.com/cloudfoundry/bosh-deployment).

To set BOSH-lite please use [bin/bosh_lite_vm.sh -c](bin/bosh_lite_vm.sh), the '-c' create option will do the following:

* Download and set up the bucc cli
* Create the BOSH-lite VM
* Create additional swap space on the BOSH-lite VM
* Enable routing so that your hosting computer can communicate with the VMs hosting BOSH-lite

* The following environment variable parameters are available to adjust the size of the BOSH-lite VM when creating it.
  - VM_MEMORY=8192 is the default: it is enough to support the deployment of CF, CF-MYSQL and a single PubSub+ instance
  - VM_SWAP=8192 is the default: it is enough to support up to 4 PubSub+ instances before needing to add more.
  - VM_DISK_SIZE=65_536 is the default: it is enough to support up to 4 PubSub+ instances before needing more storage.
  - VM_EPHEMERAL_DISK_SIZE=32_768 is the default: it provides enough room to spare for multiple deployments and re-deployment. You should not need to adjust this.
  - In general under a BOSH-lite deployment you should add 4000 Mb to VM_MEMORY and 2000 Mb to VM_SWAP per additional PubSub+ instance.

~~~~
cd bin
./bosh_lite_vm.sh -c
~~~~

### Installation on Linux - Step 3 - Deploy CF

To deploy CF in BOSH-lite to host the Solace service broker and other applications:

* Run [cf_deploy.sh](bin/cf_deploy.sh). This script will deploy cf from this repository: [cf-deployment](https://github.com/cloudfoundry/cf-deployment). 

~~~~
cd bin
./cf_deploy.sh 
~~~~ 

You are now ready for a [Solace Messaging Deployment](#solace-messaging-deployment)

<a name="solace-messaging-deployment"></a>
# Solace Messaging Deployment

The goal of the deployment steps is to install Solace Messaging into the running CF environment.

![](resources/deployment.png)

### Deployment - Prerequisites

#### The Solace Pivotal Tile

* The Solace Pivotal Tile is available for download from [PivNet](https://network.pivotal.io/products/solace-messaging/).
* [Solace Pivotal Tile Documentation](http://docs.pivotal.io/partners/solace-pubsub/)
  - _You may use Solace Tiles for which we have matching [templates](./templates), 
   Installation will not work without templates to match the tile version_

Please download the Solace Pivotal Tile and keep it around for later use. 

For my example I have downloaded version 1.4.0 and placed it in:

~~~~
solace-messaging-cf-dev/workspace/solace-messaging-1.4.0.pivotal
~~~~


#### Login to cli-tools VM

All deployment steps require you to be logged in to the cli-tools VM **unless you are using WSL.**

~~~~
cd solace-messaging-cf-dev
cd cli-tools
vagrant ssh
~~~~

### Deployment Step 1 - Extract the bosh releases from the Solace Pivotal Tile

The pivotal file is a zip file. We need to extract the relevant bosh releases needed for this deployment.

Do the following to extract the tile contents, adjusting the file name as appropritate:

~~~~
extract_tile.sh -t ~/workspace/solace-pubsub-1.4.0.pivotal
~~~~

You will find the relevant contents extracted to ~/workspace/releases

### Deployment Step 2 - Upload the bosh releases to BOSH-lite

To upload the extracted bosh releases to BOSH-lite.

~~~~
solace_upload_releases.sh
~~~~

### Deployment Step 3 - Optional: Deploy cf-mysql

The solace deployment uses mysql to keep track of its state. By default it uses an internal instance of mysql, but if you need to you can deploy a cf mysql deployment by running
~~~
cf_mysql_deploy.sh
~~~
and providing the -z option to the solace_deploy.sh script (see next step.)

### Deployment Step 4 - Deploy 

This will deploy the PubSub+ instance(s) to BOSH-lite and run an bosh errand to deploy the Solace Service Broker and add solace-pubsub as a service in Cloud Foundry.

_If not sure what to pick just use the default with no parameters. Otherwise, please ensure that you have allocated enough memory to the BOSH-lite VM for the number and types of PubSub+ instances that you want to deploy._

**Example:** Deploy the default which is a single instance of a Shared PubSub+ instance using a self-signed server certificate and evaluation PubSub+ instance edition.
~~~~
solace_deploy.sh
~~~~

The deployment variables file used as default can be found under [templates](templates/1.4.0/),  you can make a copy and edit it.

**Example:** Setting admin password to 'solace1' and setting a test server certificate and disabling the service broker's certificate validation.
~~~~
solace_deploy.sh -s 6000 -p solace1 -t ~/solace-messaging-cf-dev/cf-solace-messaging-deployment/operations/example-vars-files/certs.yml -n
~~~~

_The current deployment can be updated by simply rerunning the deployment script._

## Using the Deployment

At this stage, solace-pubsub is a service in the CF Deployment, and the BOSH-lite PubSub+ deployment will auto register with the service broker
and become available for use in CF.

_You can use 'cf' from cli-tools, or directly from your host computer, they both access the same CF instance_

For example if you deployed the default Shared PubSub+ instance, a "shared" service plan will be available and you can do this:

~~~~
cf m
cf create-service solace-pubsub shared solace-pubsub-demo-instance
cf services
~~~~

Ideally you will bind the service you created to an application and use it.
You can go ahead download and test the [Solace Sample Apps](https://github.com/SolaceLabs/sl-cf-solace-messaging-demo), or create some of your own.

<a name="other-useful-commands-and-tools"></a>
# Other useful commands and tools

## How to login and access CF

On Windows: 

~~~~
cf api https://api.local.pcfdev.io --skip-ssl-validation
cf auth admin admin
~~~~

On Linux: 

This can be executed in the cli-tools vm or locally. 
If it is ran locally it needs to run inside the solace-messaging-cf-dev/bin directory.
~~~
./cf_env.sh 
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

You can use your browser to examine the deployed service broker dashboard: 

* On Windows (non-WSL), having PCF-Dev deployed service broker
  * [ service broker dashboard ](http://solace-pubsub-broker.local.pcfdev.io/)

* On Linux, Mac or WSL, having service broker deployed on CF-Deployment
  * [ service broker dashboard ](http://solace-pubsub-broker.bosh-lite.com/)

* For Linux and Windows, you will need a username and password, do the following to discover the generated solace_broker_user and solace_broker_password

~~~~
solace_broker_user=$(bosh int $WORKSPACE/deployment-vars.yml --path /solace_broker_user)
solace_broker_password=$(bosh int $WORKSPACE/deployment-vars.yml --path /solace_broker_password)
echo "solace_broker_user: $solace_broker_user       solace_broker_password: $solace_broker_password"
~~~~

You can also run a script that will fetch a variety of information from the service broker
~~~~
getServiceBrokerInfo.sh
~~~~

## To use TCP Routing feature

In the cli-tools vm you can run this script to set up the solace router uaa client and the tcp domain. 

~~~
setup_tcp_routing.sh
~~~

## How to suspend and resume VMs

The VMs we created can be suspended and resumed at a later time.
This way you don't need to recreate them. Their state is saved to disk.

### Suspending all VMS


* On Linux: 

~~~~
cd solace-messaging-cf-dev

cd cli-tools
vagrant suspend
~~~~ 

* On all platforms:

The bosh created VM in virtualbox cannot be successfully restarted.  But they can be preserved by pausing and saving their state in virtualbox. 

~~~~ 
bosh_lite_vm.sh -s
~~~~ 

Alternatively you can use the virtualbox GUI to 'pause' and 'close' > 'save state'. 

### Resuming all VMS

* On Linux: 

~~~~
cd solace-messaging-cf-dev

cd cli-tools
vagrant resume
~~~~

* On all platforms:

The bosh created VM in virtualbox may be resumed if previously paused and saved by using [bosh_lite_vm.sh -s](bin/bosh_lite_vm.sh)

~~~~
bosh_lite_vm.sh -r
~~~~

Alternatively you can use the virtualbox GUI to the 'start' > 'headless start'. 

## Working with PubSub+ instance in the BOSH deployment

### Listing the VMs

From the cli-tools vm:

~~~~
bosh vms
~~~~

### Access the PubSub+ instance cli

Get the list of vms, to find the IP address of the PubSub+ instance you want:
~~~~
bosh vms
~~~~

Now ssh to the PubSub+ instance. The admin password is whatever you had set in the vars.yml and the SSH port on this BOSH-lite deployment is set to 3022.

~~~~
ssh -p 3022 admin@10.244.0.150
~~~~

## How to cleanup

### Deleting the Solace Messaging deployment

From the cli-tools vm:
~~~~
solace_delete_deployment.sh
~~~~

* On Linux, this will destroy the VM for BOSH-lite which also contains CF, and CF-MYSQL if it was installed:

~~~~
bosh_lite_vm.sh -d
~~~~

### How to delete cli-tools VM

This is not necessary if you're using WSL.

On your host computer (not cli-tools)

~~~~
cd solace-messaging-cf-dev
cd cli-tools
vagrant destroy
~~~~

