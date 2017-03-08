
To support testing a bosh release directly by developers.

Requires a [bosh-lite] (https://github.com/cloudfoundry/bosh-lite) 
- Assumes installation with default networking options. 
- Scripts need to be able to target bosh: bosh target 192.168.50.4 lite

- The files in [templates](./templates/) are used to generate a bosh deployment manifest.yml
--  These files are processed with the help of the [deploy.sh](./deploy.sh) script.

- The [templates](./templates) contain parameters that assume you have installed the [Solace Service Broker](../../solace-service-broker) in a locally accessible [PCF Dev](https://pivotal.io/pcf-dev)

## Scripts:

- bosh_prepare.sh
-- prepares bosh-lite to use the solace bosh release, adds docker-bosh and stemcell

_If you use any parameters with bosh_deploy.sh you should re-use them with bosh_cleanup.sh_

- bosh_deploy.sh   
-- prepare bosh if not done already, adds docker-bosh, stemcell
-- Prepares a bosh deployment manifest.yml
-- Will exit if the VMR was already deployed to bosh
-- uploads the release to bosh
-- deploys the release according to the generated manifest.yml

- bosh_cleanup.sh 
-- Cleanup from bosh lite deployment
--- Deletes a recent deployment to bosh lite 
--- Deletes the release
--- Deletes orphaned disks

