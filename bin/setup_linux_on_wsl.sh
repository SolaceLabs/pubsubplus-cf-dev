#!/bin/bash
set -x

export WIN_DRIVE=${WIN_DRIVE:-"/mnt/c"}
export VIRTUALBOX_HOME=${VIRTUALBOX_HOME:-"$WIN_DRIVE/Program Files/Oracle/VirtualBox"}
export GIT_REPO_BASE=${GIT_REPO_BASE:-"https://github.com/SolaceDev"}

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
    if [ ! -e solace-messaging-cf-dev ]; then
        (
            git clone $GIT_REPO_BASE/solace-messaging-cf-dev.git
            cd solace-messaging-cf-dev
            if [ ! -z $GIT_BRANCH ]; then
                git checkout $GIT_BRANCH
            fi

            git clone $GIT_REPO_BASE/cf-solace-messaging-deployment.git
            cd cf-solace-messaging-deployment
            if [ ! -z $GIT_BRANCH ]; then
                git checkout $GIT_BRANCH
            fi
        )
    fi
}

function installBosh() {
    solace-messaging-cf-dev/bin/bosh_lite_vm.sh -c
    if [ ! -e /usr/local/bin/bosh ]; then
        sudo cp solace-messaging-cf-dev/workspace/bucc/bin/bosh /usr/local/bin
    fi
    if [ ! -e /usr/local/bin/bucc ]; then
        sudo cp solace-messaging-cf-dev/workspace/bucc/bin/bucc /usr/local/bin
    fi
}

function deployCf() {
    source solace-messaging-cf-dev/workspace/bosh_env.sh
    solace-messaging-cf-dev/bin/cf_deploy.sh
    #solace-messaging-cf-dev/bin/cf_mysql_deploy.sh
}

function installPrograms() {


    # CF CLI from https://docs.cloudfoundry.org/cf-cli/install-go-cli.html
    wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -
    echo "deb https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list
    sudo apt-get update
    sudo apt-get install -y jq build-essential zlibc zlib1g-dev ruby ruby-dev rubygems openssl libssl-dev libxslt-dev libxml2-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 cf-cli
    sudo gem install bundler
}

cd
setupLinks
installPrograms
set -e
cloneRepo
installBosh
deployCf
echo Now run: source solace-messaging-cf-dev/workspace/bosh_env.sh
echo    then: solace-messaging-cf-dev/bin/cf_env.sh

