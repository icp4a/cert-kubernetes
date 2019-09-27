
# IBM Cloud Pak for Automation 19.0.2 on Certified Kubernetes

## Introduction

For information about IBM Cloud Pak for Automation 19.0.x, see [IBM Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/welcome/kc_welcome_dba_distrib.html).

The installation of IBM Cloud Pak for Automation software uses Helm charts and Tiller or Kubernetes YAML files. The charts are packages of preconfigured Kubernetes resources that bootstrap a deployment on a Kubernetes cluster. You customize the deployment by changing and adding configuration parameters.

The repository includes one folder for each application or service.

| Folder 	| Product name 	| Version in 19.0.2 |
|------------	|----------------------------------	|------------- |
| AAE 	| IBM Business Automation Application Engine | 19.0.2 |
| BACA 	| IBM Business Automation Content Analyzer | 19.0.2 |
| BAI 	| IBM Business Automation Insights | 19.0.2 |
| BAS 	| IBM Business Automation Studio | 19.0.2 |
| AAE 	| IBM Business Automation Application Engine | 19.0.2 |
| CONTENT 	| IBM FileNet Content Manager | 5.5.3 |
| NAVIGATOR 	| IBM Digital Business Navigator | 3.0.6 |
| ODM 	| IBM Operational Decision Manager | 8.10.2 |
| UMS 	| User Management Service | 19.0.2 |

Each folder contains subfolders, which contain instructions and resources to install the Helm charts. 

Installation is supported only on a Certified Kubernetes platform. There are dozens of Certified Kubernetes offerings and more coming to market each year. Cloud Native Computing Foundation (CNCF) has created a Certified Kubernetes Conformance Program, in which most of the leading vendors and cloud computing providers have Certified Kubernetes offerings. Use the following link to determine whether the vendor and/or platform is certified by CNCF https://landscape.cncf.io/category=platform. For more information about nonqualified platforms, see the [support statement for Certified Kubernetes](http://www.ibm.com/support/docview.wss?uid=ibm10876926).

> **Note**: Use the instructions in the IBM Knowledge Center to help you install the containers on IBM Cloud Private. The support for IBM Cloud Private is deprecated in 19.0.2. For more information, see [Installing products on IBM Cloud Private](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/topics/tsk_install_icp.html).

## Legal Notice

Legal notice for users of this repository [legal-notice.md](legal-notice.md).

## Step 1: Prepare your environment

Before you install any of the containerized software:

1. Go to the prerequisites page in the [IBM Cloud Pak for Automation 19.0.x](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_prepare_env_k8s.html) Knowledge Center.
2. Follow the instructions on preparing your environment in the Knowledge Center.

   How much preparation you need to do depends on your environment and how familiar you are with your environment.

##  Step 2: Get access to the container images

  * **Option 1**: Create a pull secret for the IBM Cloud Entitled Registry

    1. Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

    2. In the **Container software library** tile, click **View library** and then click **Copy key** to copy the entitlement key to the clipboard.

    3. Create a pull secret by running a `kubectl create secret` command.
       ``` console
       $ kubectl create secret docker-registry <my_pull_secret> --docker-server=us.icr.io --docker-username=iamapikey --docker-password="<API_KEY_GENERATED>" --docker-email=user@foo.com
       ```

       > **Note**:The us.icr.io registry domain name is for the region us-south. Use the domain name of the registry that is associated to your cluster location.

    4. Take a note of the secret and the server values so that you can set them to the **pullSecrets** and **repository** parameters when you run the installation command for your containers.

  * **Option 2**: Download the packages from PPA and load the images

    [IBM Passport Advantage (PPA)](https://www-01.ibm.com/software/passportadvantage/pao_customer.html) provides archives (.tgz) for the software. To view the list of Passport Advantage eAssembly installation images, refer to the [19.0.2 download document](http://www.ibm.com/support/docview.wss?uid=ibm10958567).

    1. Download one or more PPA packages to a server that is connected to your Docker registry.

    2. Download the [`loadimages.sh`](scripts/loadimages.sh) script from GitHub.

    3. Log in to the specified Docker registry with the docker login command.
   This command depends on the environment that you have.

       > **Note**: If your platform is OpenShift, do NOT run the .sh script to load the images without preparing your environment beforehand. Go to [Step 3](README.md#step-3-go-to-the-relevant-folders-and-follow-the-instructions) and use the instructions in the respective folders. You can then load the images to the Docker registry with the right privileges.

    4. Run the `loadimages.sh` script to load the images into your Docker registry. Specify the two mandatory parameters in the command line.

       > **Note**: The *docker-registry* value depends on the platform that you are using.

       ```
       -p  PPA archive files location or archive filename
       -r  Target Docker registry and namespace
       -l  Optional: Target a local registry
       ```

       > The following example shows the input values in the command line.

       ```
       # scripts/loadimages.sh -p /Downloads/PPA/ImageArchive.tgz -r <DOCKER-REGISTRY>/demo-project
       ```
## Step 3: Go to the relevant folders and follow the instructions

You can install software on a certified Kubernetes platform with the Helm command line interface (CLI) or the kubectl command line interface (CLI). Use the following links to go to the instructions for the software that you want to install.
> **Note**: UMS must be installed before Business Automation Studio if you want to use the service.

- [Install the User Management Service](UMS/README.md)
- [Install IBM Business Automation Application Engine](AAE/README.md)
- [Install IBM Business Automation Content Analyzer](BACA/README.md)
- [Install IBM Business Automation Insights](BAI/README.md)
- [Install IBM Business Automation Studio](BAS/README.md)
- [Install IBM FileNet Content Manager](CONTENT/README.md)
- [Install IBM Business Automation Navigator](NAVIGATOR/README.md)
- [Install IBM Operational Decision Manager](ODM/README.md)
