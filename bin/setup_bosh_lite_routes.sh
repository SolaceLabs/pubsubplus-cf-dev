#!/bin/bash

platform() {
    if [ "$(uname)" == "Darwin" ]; then
        echo "darwin"
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        echo "linux"
    fi
}

routes() {
    case $(platform) in
        darwin)
            sudo route delete -net 10.244.0.0/16    192.168.50.6
            sudo route add -net 10.244.0.0/16    192.168.50.6
            ;;
        linux)
            sudo route del -net 10.244.0.0/16 gw 192.168.50.6
            sudo route add -net 10.244.0.0/16 gw 192.168.50.6
            ;;
    esac
}


routes
