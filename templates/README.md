## About the templates

- Templates are tile version specific. 
- There is a folder for each supported tile version.

There many kinds of templates:
- bosh manifests
- service broker manifest

### Service broker manifest

Currently used as is for the deployment of the service broker in PCFDev.

### Bosh manifest templates

- bosh templates are selected with the -t parameter with the bosh_* commands.
- Most templates are bosh manifests for which we do some substitution.

The provided bosh manifest templates currently define a single VMR job for a bosh deployment.

Template substitutions allows
- Control the job name
- Control the pool name parameter which ends up mapping it to a service plan.
- The docker vmr image to use, which is also mapped to the pool name.

Template have static settings:
- The number of instances, the default is 1 for most templates
- Cerificates which are present in some templates
- networking
- passwords

Once a deployment is done, the generated bosh manifest from the template is ~workspace/bosh-solace-manifest.yml

You may edit that manifest and have bosh re-deploy with the changed settings such as changing passwords.

~~~~
cd
bosh deployment workspace/bosh-solace-manifest.yml
bosh deploy
~~~~

