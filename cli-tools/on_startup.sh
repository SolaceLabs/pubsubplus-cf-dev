#!/bin/bash
echo "On startup script"

if [ ! -d ~/solace-cf-dev ]; then
  su vagrant -c "git clone https://github.com/SolaceDev/solace-cf-dev.git"
fi

