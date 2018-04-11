#! /bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

source $SCRIPTPATH/common.sh

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

if [ -f $WORKSPACE/bosh_env.sh ]; then
 source $WORKSPACE/bosh_env.sh
fi

source $SCRIPTPATH/bosh-common.sh

function showUsage() {
    echo
    echo "Usage: $SCRIPT [OPTIONS]"
    echo
    echo "OPTIONS"
    echo "  -h                   Show Command options "
    echo "  -c                   Creates the BOSH-lite VM"
    echo "  -d                   Destroys the BOSH-lite VM"
    echo "  -s                   Saves the state of the BOSH-lite VM"
    echo "  -r                   Restarts the BOSH-lite VM assuming a previously saved state."
}

while getopts "hcdsr" arg; do
    case "${arg}" in
        c)
	    ## Create the VM and do additional tasks
	    create_bosh_lite_vm
	    bosh_lite_vm_additions

	    echo
	    echo "TIP: To access bosh you should \"source $WORKSPACE/bosh_env.sh\""
	    echo
	    echo "TIP: To deploy Cloud Foundry on bosh you should run \"$SCRIPTPATH/cf_deploy.sh\""
	    echo
            ;;
        d) 
	    destroy_bosh_lite_vm
            ;;
        s) 
	    savestate_bosh_lite_vm
            ;; 
        r)
            resume_bosh_lite_vm
	    ;;
        h)
            showUsage
            exit 0
            ;;
       \?)
       >&2 echo
       >&2 echo "Invalid option: -$OPTARG" >&2
       >&2 echo
       showUsage
       exit 1
       ;;
    esac
done
