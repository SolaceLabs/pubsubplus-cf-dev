#!/bin/bash

# bosh -d solace_messaging run-errand delete-all

bosh -d solace_messaging deploy solace-deployment.yml --vars-store ~/deployment-vars.yml -v system_domain=bosh-lite.com  -l vars.yml

# bosh -d solace_messaging run-errand --keep-alive deploy-all

bosh -d solace_messaging run-errand deploy-all


