#!/bin/bash
set -x

export WIN_DRIVE=${WIN_DRIVE:-"/mnt/c"}
export VIRTUALBOX_HOME=${VIRTUALBOX_HOME:-"$WIN_DRIVE/Program Files/Oracle/VirtualBox"}
export GIT_REPO_BASE=${GIT_REPO_BASE:-"https://github.com/SolaceDev"}
export WORKSPACE=${WORKSPACE:-$HOME/workspace}

# vboxmanage has to be able to see $HOME/.bosh_virtualbox_cpi in the Windows filesystem.
# Therefore we create the files there, and link to them from the Linux home.
function setupLinks() {
    if [ ! -e $HOME/.bosh_virtualbox_cpi ]; then
        mkdir -p $WIN_DRIVE$HOME/.bosh_virtualbox_cpi
        ln -s $WIN_DRIVE$HOME/.bosh_virtualbox_cpi $HOME/.bosh_virtualbox_cpi
    fi

    if [ ! -e /usr/local/bin/VBoxManage ]; then
        sudo ln -s "$VIRTUALBOX_HOME/VBoxManage.exe" /usr/local/bin/VBoxManage
        sudo ln -s "$VIRTUALBOX_HOME/VBoxManage.exe" /usr/local/bin/vboxmanage
    fi
}

function cloneRepo() {
    if [ ! -d repos ]; then
        mkdir repos
    fi
    (
        cd repos
        if [ ! -d solace-messaging-cf-dev ]; then
        (
            git clone $GIT_REPO_BASE/solace-messaging-cf-dev.git
            cd solace-messaging-cf-dev
            if [ ! -z $BRANCH ]; then
                git checkout $BRANCH
            fi
        )
        fi

        if [ ! -f solace-messaging-cf-dev/cf-solace-messaging-deployment/README.md ]; then
        (
            cd solace-messaging-cf-dev
            git clone $GIT_REPO_BASE/cf-solace-messaging-deployment.git
            cd cf-solace-messaging-deployment
            if [ ! -z $BRANCH ]; then
                git checkout $BRANCH
            fi
        )
        fi
    )
}

function installBosh() {
    repos/solace-messaging-cf-dev/bin/bosh_lite_vm.sh -c
    if [ ! -e /usr/local/bin/bosh ]; then
        sudo cp $WORKSPACE/bucc/bin/bosh /usr/local/bin
    fi
    if [ ! -e /usr/local/bin/bucc ]; then
        sudo cp $WORKSPACE/bucc/bin/bucc /usr/local/bin
    fi
}

function deployCf() {
    source $WORKSPACE/bosh_env.sh
    repos/solace-messaging-cf-dev/bin/cf_deploy.sh
}

function installPrograms() {

    # Install the cf cli tool.
    curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&source=github" | tar -zx
    sudo mv cf /usr/local/bin

    sudo apt-get update

    sudo apt-get install -y jq build-essential zlibc zlib1g-dev ruby ruby-dev rubygems openssl libssl-dev libxslt-dev libxml2-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3
    sudo gem install bundler
}

function createSettingsFile() {
	SETTINGS_FILE=$HOME/.settings.sh

	if [ ! -f $SETTINGS_FILE ]; then
		echo "Capturing settings in $SETTINGS_FILE"
		echo "export SOLACE_MESSAGING_CF_DEV=$HOME/repos/solace-messaging-cf-dev" >> $SETTINGS_FILE
		echo "export WORKSPACE=$HOME/workspace" >> $SETTINGS_FILE
		echo "export SOLACE_BUILD_DIR=$HOME/workspace/build" >> $SETTINGS_FILE
		echo "export SOLACE_CACHE=$HOME/.SOLACE_CACHE" >> $SETTINGS_FILE
		echo "source $SETTINGS_FILE" >> ~/.profile
		echo "source repos/solace-messaging-cf-dev/.profile" >> ~/.profile
	fi
}

cd
#setupLinks
#installPrograms
set -e
#cloneRepo
installBosh
deployCf
createSettingsFile
source repos/solace-messaging-cf-dev/.profile

