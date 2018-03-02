#Using cf-solace-messaging deployment on Windows: 

To use the new manifest on windows, use the ops file found in this folder [make_windows_deployment.yml](operations/make_windows_deployment.yml), in the bosh deploy command. More info about the bosh deploy command can be found in cf-solace-messaging dev repository. 

The other important thing in the bosh deploy command is to change 
~~~
-v app-domain=bosh-lite.com 
~~~ 
to be: 
~~~
 -v app-domain=local.pcfdev.io
~~~
and make the same change for -v system-domain. 

