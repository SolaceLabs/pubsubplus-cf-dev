# Using cf-pubsubplus-deployment on Windows: 

To use the new manifest on windows, use the ops file found in this folder [make_windows_deployment.yml](operations/make_windows_deployment.yml), in the bosh deploy command. More info about the bosh deploy command can be found in pubsubplus-cf-dev repository. 

It is also important that -o pubsubplus-cf-dev/operations/make_windows_deployment.yml is at the end of the bosh command so that it overwrites any earlier changes made to the manifest in terms of the p-mysql plans. 

The other important thing in the bosh deploy command is to change 
~~~
-v app-domain=bosh-lite.com \
-v system-domain=bosh-lite.com
~~~ 
to be: 
~~~
 -v app-domain=local.pcfdev.io \
 -v system-domain=local.pcfdev.io
~~~

