#!/bin/bash
set -x

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export WIN_DRIVE=${WIN_DRIVE:-"/mnt/c"}
export VIRTUALBOX_HOME=${VIRTUALBOX_HOME:-"$WIN_DRIVE/Program Files/Oracle/VirtualBox"}
export GIT_REPO_BASE=${GIT_REPO_BASE:-"https://github.com/SolaceDev"}
export WORKSPACE=${WORKSPACE:-$HOME/workspace}
export SETTINGS_FILE=${SETTINGS_FILE:-$HOME/.settings.sh}
export REPOS_DIR=${REPOS_DIR:-$HOME/repos}

SETUP_LOG_FILE=${SETUP_LOG_FILE:-"$WORKSPACE/$SCRIPT.log"}

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
    if [ ! -d $REPOS_DIR ]; then
        mkdir $REPOS_DIR
    fi
    (
        cd $REPOS_DIR
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
    $REPOS_DIR/solace-messaging-cf-dev/bin/bosh_lite_vm.sh -c
}

function deployCf() {
    source $WORKSPACE/bosh_env.sh
    $REPOS_DIR/solace-messaging-cf-dev/bin/cf_deploy.sh
}

function installPrograms() {

    # Install the cf cli tool.
    curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&source=github" | tar -zx
    sudo mv cf /usr/local/bin

    sudo apt-get update

    sudo apt-get install -y jq build-essential zlibc zlib1g-dev ruby ruby-dev rubygems openssl libssl-dev libxslt-dev libxml2-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3
    sudo gem install bundler
}

function getSettingsEnv() {
		echo "export SOLACE_MESSAGING_CF_DEV=$REPOS_DIR/solace-messaging-cf-dev"
		echo "export WORKSPACE=$HOME/workspace"
		echo "export PATH=\$PATH:$WORKSPACE/bucc/bin"
}

function createSettingsFile() {

	if [ ! -f $SETTINGS_FILE ]; then
		echo "Capturing settings in $SETTINGS_FILE"
	        getSettingsEnv >> $SETTINGS_FILE
	fi
}

function alterProfile() {
    NUM_LINES=$( grep -c "source $SETTINGS_FILE" ~/.profile )

    if [ "$NUM_LINES" -eq 0 ]; then
        echo out there
        read -p "Would you like  your .profile modified to automatically set up the CF environment when you next log in? (yN): "

        if [[ $REPLY =~ ^[Yy] ]]; then
            echo "source $SETTINGS_FILE" >> ~/.profile
            echo "source $REPOS_DIR/solace-messaging-cf-dev/.profile" >> ~/.profile
        fi
    fi
}

function setupLinuxOnWsl() {

cd
setupLinks
installPrograms
set -e
cloneRepo
installBosh
deployCf
createSettingsFile
set +e
alterProfile

}


#### 

setupLinuxOnWsl | tee $SETUP_LOG_FILE

echo "Setup log file: $SETUP_LOG_FILE"
