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

# Please keep all the options in order here and in the getops section.

function showUsage() {
    echo
    echo "Usage: $SCRIPT [OPTIONS]"
    echo
    echo "OPTIONS"
    echo "  -b                   Produces an environment variables file to supporting using BOSH cli with the BOSH-lite VM"
    echo "  -c                   Creates the BOSH-lite VM"
    echo "  -d                   Destroys the BOSH-lite VM"
    echo "  -g <NAME>            Restores a snapshot of the BOSH-lite VM with the given NAME, the VM should be already Saved (-s)"
    echo "  -h                   Show Command options "
    echo "  -n                   Recreates routes to support communications between host and BOSH-lite VM"
    echo "  -l                   Lists available snapshot names of the BOSH-lite VM"
    echo "  -o                   Powers down the BOSH-lite VM WITHOUT SAVING STATE. You should have an existing snapshot you can restore."
    echo "  -p                   Poweron the BOSH-lite VM assuming a previously saved state."
    echo "  -r                   Rolls back to the current snapshot of the BOSH-lite VM, the VM should be already Saved (-s)"
    echo "  -s                   Saves the state and suspends the BOSH-lite VM"
    echo "  -t <NAME>            Takes a snapshot of the BOSH-lite VM with the given NAME"
    echo "  -x <NAME>            Deletes a snapshot of the BOSH-lite VM with the given NAME"
}

while getopts "bcdg:hrlnopst:x:" arg; do
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
        g)
            export SNAPSHOT_NAME=${OPTARG:-"INITIAL"}
	    restore_bosh_lite_vm_snapshot $SNAPSHOT_NAME
            ;;
        h)
            showUsage
            exit 0
            ;;
        l)
	    list_bosh_lite_vm_snapshot
            ;;
        n)
            setup_bosh_lite_routes           
            ;;
        o) 
	    poweroff
            ;;
        p)
            resume_bosh_lite_vm
	    ;;
        r)
	    restore_current_bosh_lite_vm_snapshot
            ;;
        s) 
	    savestate_bosh_lite_vm
            ;; 
        t)
            export SNAPSHOT_NAME=${OPTARG:-"INITIAL"}
	    take_bosh_lite_vm_snapshot $SNAPSHOT_NAME
            ;;
        x)
            export SNAPSHOT_NAME=${OPTARG:-"INITIAL"}
	    delete_bosh_lite_vm_snapshot $SNAPSHOT_NAME
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
