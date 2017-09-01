## About the templates

- Templates are tile version specific. 
- There is a folder for each supported tile version.

There many kinds of templates:
- BOSH manifest components used for generating basic BOSH manifests.
- service broker manifest.

### Service broker manifest

Currently used as is for the deployment of the service broker in PCFDev.

### Bosh manifest templates

Each of the BOSH manifest templates are components which are put together by `generateBoshManifest.py` to build fully-valid basic BOSH manifests that could be used for deployment.

These templates are Jinja2 templates which allow for value substitutions at execution-time. The abstraction provided by Jinja2 promotes code reusage between the varying types of templates, and cleanly separates most of the BOSH manifest structuring logic from the actual executing code.

For simplicity, some static settings are used in these manifests which include:
- Certificates
- Base networking (i.e. subnet specification)
- passwords

Once a deployment is done, the generated bosh manifest from the template is stored in `$MANIFEST`, which is set to `~/workspace/bosh-solace-manifest.yml` by default.

You may edit that manifest and have bosh re-deploy with the changed settings such as changing passwords.

~~~~
bosh deployment ~/workspace/bosh-solace-manifest.yml
bosh deploy
~~~~

