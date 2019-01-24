#! /bin/bash

export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WORKSPACE=${WORKSPACE:-$SCRIPTPATH/../workspace}

source $SCRIPTPATH/common.sh

export BOSH_NON_INTERACTIVE=${BOSH_NON_INTERACTIVE:-true}

export BOSH_ENV_FILE=${BOSH_ENV_FILE:-$WORKSPACE/bosh_env.sh}

if [ -f $BOSH_ENV_FILE ]; then
 source $BOSH_ENV_FILE
fi

source $SCRIPTPATH/bosh-common.sh

function showUsage() {
    echo
    echo "Usage: $SCRIPT [OPTIONS]"
    echo
    echo "OPTIONS"
    echo "  -h                   Show Command options "
    echo "  -c                   Creates the BOSH-lite VM"
    echo "  -b                   Produces an environment variables file to supporting using BOSH cli with the BOSH-lite VM"
    echo "  -d                   Destroys the BOSH-lite VM"
    echo "  -s                   Saves the state and suspends the BOSH-lite VM"
    echo "  -p                   Poweron the BOSH-lite VM assuming a previously saved state."
    echo "  -n                   Recreates routes to support communications between host and BOSH-lite VM"
    echo "  -t <NAME>            Takes a snapshot of the BOSH-lite VM with the given NAME"
    echo "  -g <NAME>            Restores a snapshot of the BOSH-lite VM with the given NAME, the VM should be already Saved (-s)"
    echo "  -x <NAME>            Deletes a snapshot of the BOSH-lite VM with the given NAME"
    echo "  -r                   Rolls back to the current snapshot of the BOSH-lite VM, the VM should be already Saved (-s)"
    echo "  -l                   Lists available snapshot names of the BOSH-lite VM"
}

while getopts "hbcdsrnt:g:x:pl" arg; do
    case "${arg}" in
        b) 
	    create_bosh_env_file
            ;;
        c)
	    ## Create the VM and do additional tasks
	    create_bosh_lite_vm
	    bosh_lite_vm_additions

	    echo
	    echo "TIP: To access bosh you should \"source $BOSH_ENV_FILE\""
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
        p)
            resume_bosh_lite_vm
	    ;;
        n)
            setup_bosh_lite_routes           
            ;;
        t)
            export SNAPSHOT_NAME=${OPTARG:-"INITIAL"}
	    take_bosh_lite_vm_snapshot $SNAPSHOT_NAME
            ;;
        g)
            export SNAPSHOT_NAME=${OPTARG:-"INITIAL"}
	    restore_bosh_lite_vm_snapshot $SNAPSHOT_NAME
            ;;
        x)
            export SNAPSHOT_NAME=${OPTARG:-"INITIAL"}
	    delete_bosh_lite_vm_snapshot $SNAPSHOT_NAME
            ;;
        r)
	    restore_current_bosh_lite_vm_snapshot
            ;;
        l)
	    list_bosh_lite_vm_snapshot
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
