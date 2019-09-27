# Install IBM Operational Decision Manager on Minikube

Before you install make sure that you have prepared your environment. For more information, see [Preparing to install ODM for production](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_preparing_odmk8s.html) as well as [Customizing ODM for production](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.install/k8s_topics/tsk_install_odm.html).

## Step 1: Install Minikube and Tiller

1. Refer to the Kubernetes [documentation](https://kubernetes.io/docs/setup/minikube/#installation) to install Minikube.

2. Start Minikube with the minimum required CPU and memory.

   ```console
   $ minikube start --cpus 6 --memory 4096
   ```

   > **Note**: If you started a Minikube cluster without these parameters, stop and delete it before restarting it again.
   ```console
   $ minikube stop
   $ minikube delete
   $ minikube start --cpus 6 --memory 4096
   ```

3. Verify your installation.

   ```console
   $ kubectl get nodes
   ```

4. Install [Helm 2.9.1](https://github.com/helm/helm/releases/tag/v2.9.1).

   > **Note**: Version 2.9.1 is required to use Minikube.

5. Install Tiller in the Minikube cluster.

   ```console
   $ helm init
   ```

## Step 2: Push and tag the downloaded images in Minikube

1. Follow the instructions to download the IBM Operational Decision Manager images and the loadimages.sh file in [Download PPA and load images](../../README.md#step-2-download-a-product-package-from-ppa-and-load-the-images).

   > **Note**: **DO NOT** run the loadimages.sh script at this point.

2. Configure your shell to use the Minikube built-in [Docker daemon](https://kubernetes.io/docs/setup/minikube/#use-local-images-by-re-using-the-docker-daemon).

   ```console
   $ eval $(minikube docker-env)
   ```

3. Use the following command to load and tag the images in the Minikube local repository.

   ```console
   $ scripts/loadimages.sh -l -p <PPA-ARCHIVE>.tgz -r ibmcom
   ```

## Step 3: Install a Kubernetes release of Operational Decision Manager

1. Download the `ibm-odm-prod-<version>.tgz` file. The archive contains the `ODM for production (ibm-odm-prod)` Helm chart.
   - [ibm-odm-prod-2.2.1.tgz](../helm-charts/ibm-odm-prod-2.2.1.tgz) for Operational Decision Manager 8.10.2

2. Install a release with the default configuration and a name of `my-odm-prod-release` by using the following command:

   ```console
   $ helm install --name my-odm-prod-release \
     --set internalDatabase.persistence.useDynamicProvisioning=true \
     /path/to/ibm-odm-prod-<version>.tgz
   ```

   > **Note**: You can also install on Minikube by using Kubernetes YAML. Refer to the [k8s-yaml/README.md](../k8s-yaml/README.md).

3. The package is deployed asynchronously in a matter of minutes, and is composed of several services.

   > **Note**: You can check the status of the pods that you created:
   ```console
   $ kubectl get pods
   NAME                                                READY   STATUS    RESTARTS   AGE
   my-odm-prod-release-dbserver-***                    1/1     Running   0          44m
   my-odm-prod-release-odm-decisioncenter-***          1/1     Running   0          44m
   my-odm-prod-release-odm-decisionrunner-***          1/1     Running   0          44m
   my-odm-prod-release-odm-decisionserverconsole-***   1/1     Running   0          44m
   my-odm-prod-release-odm-decisionserverruntime-***   1/1     Running   0          44m
   ```

The release is an instance of the `ibm-odm-prod` chart. All of the components are now running in a Kubernetes cluster.

> **Tip**: List all existing releases with the `helm list` command.


## Step 4: Verify that the deployment is running

When all of the pods are *Running*, you can access the application with the URLs returned by the `minikube service` command.

```console
$ minikube service list
```

## To customize a release

Refer to the customizing instructions in [helm-charts/README.md](../helm-charts/README.md#customize-a-kubernetes-release-of-operational-decision-manager).

## To uninstall a release

Refer to the uninstalling instructions in [helm-charts/README.md](../helm-charts/README.md#uninstall-a-kubernetes-release-of-operational-decision-manager).
