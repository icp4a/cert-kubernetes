## Post Deployment steps for non-ingress setup  (Option 1)

Since OpenShift's router does not support URL rewriting, there are some steps necessary post-deployment to enable accessing 
IBM Business Automation Content Analyzer via the node ports exposed by the services. Or if you do not want to use path based ingress on ICP, follow the same steps.

###### Once deployment is started:

To find the node port for the backend service, execute:  
```console
# kubectl get svc spbackend
NAME        TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
spbackend   NodePort   172.1.1.1       <none>        8080:30437/TCP   19h
```
In the above example, the node port is 30437
1) Execute:  `kubectl edit deploy spfrontend`
2) Look for the BACKEND_PORT environment variable and add the value from the previous step in quotes:  
    for eaxmple,      
        `- name: BACKEND_HOST`   
&nbsp;&nbsp;          `value: myopenshift1.com`    
        `- name: BACKEND_PROTOCOL`    
&nbsp;&nbsp;          `value: https`    
        **`- name: BACKEND_PORT`    
&nbsp;&nbsp;          `value: "30437"`**   
3) Ensure that the BACKEND_PATH and FRONTEND_PATH variables are blank (for example, no values)  
    for eaxmple,  
    `    - name: BACKEND_PATH`  
        `- name: FRONTEND_PATH`  
        `- name: FRONTEND_HOST`  
&nbsp;&nbsp;        `value: myopenshift1.com`   

4) Save the changes. This should cause the spfrontend pods to restart.
5) Look at the service list again and note the node port of spfrontend service (for eaxmple, `kubectl get svc spfrontend`).
6) Access Content Analyzer using the URL:  `https://<bxdomainname>:<frontend node port>/?tid=<tenantid>&ont=<tenant ontology> `  
   (tenant id and ontology defined when adding tenant to base Db2 database)


## Post Deployment steps for OpenShift route setup  (Option 2)

You can also deploy IBM Business Automation Content Analyzer using an OpenShift route as the ingress point to expose the frontend and backend services via an externally-reachable, unique hostname such www.backend.example.com and www.frontend.example.com.  
A defined route and the endpoints identified by its service can be consumed by a router to provide named connectivity that allows external clients to reach your applications.   

Run the command below to create appropriate routes for the services.

###### Once deployment is started:

1) To create a route for the frontend service, execute:  
    ```console
    # oc create route passthrough <frontend-route-name> --insecure-policy=Redirect --service=spfrontend --hostname=<frontend_router_hostname>
    ```
    > **Sample**: oc create route passthrough spfrontend-route --insecure-policy=Redirect --service=spfrontend --hostname=www.ca.frontendsp

2) To create a route for the backend service, execute:  
    ```console
    # oc create route passthrough <backend-route-name> --insecure-policy=Redirect --service=spbackend --hostname=<backend_router_hostname>
    ```
    > **Sample**: oc create route passthrough spbackend-route --insecure-policy=Redirect --service=spbackend --hostname=www.ca.backendsp  
    > **Note**: A route name is limited to 63 characters, and router hostname given a wildcard DNS entry and must be unique.  
   
3) Add the frontend router hostname and backend router hostname, that were specified at steps 1 & 2 above, to your client hosts file or DNS server, so that external client can reach endpoint by name. Two DNS entries should point to OpenShift's Infra node IP address.  

4) Edit the spfrontend deployment
   - Execute:  `kubectl edit deploy spfrontend`
   - Look for the BACKEND_HOST environment variable and change the value to hostname of backend router that specified in the setp 2 in quotes:     
    for eaxmple,      
        **`- name: BACKEND_HOST`   
&nbsp;&nbsp;          `value: www.ca.backendsp`**   
   - Ensure that the BACKEND_PATH and FRONTEND_PATH variables are blank (for eaxmple, no values)  
    for eaxmple,  
    `    - name: BACKEND_PATH`  
        `- name: FRONTEND_PATH`    

   - Save the changes. This should cause the spfrontend pods to restart.
   
5) Access backend endpoint to accept certificate using the URL: `https://<backend_router_hostname>` (backend_router_hostname defined when creating route for the backend service)

    **Note**: If the content **WORKS** appears in the page, it means the backend route is working.

6) Access frontend endpoint to accept certificate using the URL: `https://<frontend_router_hostname>/?tid=<tenantid>&ont=<tenant ontology> `   
(frontend_router_hostname defined when creating route for the frontend service. tenant id and ontology defined when adding tenant to base Db2 database)
