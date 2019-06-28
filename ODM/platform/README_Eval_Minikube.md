# Install IBM Operational Decision Manager for developers on Minikube

IBM Operational Decision Manager for developers can be used on a personal computer to run and evaluate Operational Decision Manager in a single container.

## Step 1: Install Minikube

1. Refer to the Kubernetes [documentation](https://kubernetes.io/docs/setup/minikube/#installation) to install Minikube.

2. Start Minikube with the minimum required CPU and memory.

   ```console
   $ minikube start --cpus 4 --memory 4096
   ```

   > **Note**: If you started a Minikube cluster without these parameters, stop and delete it before restarting it again.
   ```console
   $ minikube stop
   $ minikube delete
   $ minikube start --cpus 4 --memory 4096
   ```

3. Verify your installation.

   ```console
   $ kubectl get nodes
   ```

## Step 2: Install an Operational Decision Manager for developers release

Install a release with the default configuration. The name defined in the configuration is `odm-eval-ibm-odm-dev`.

1. Download the [odm-eval.yaml](../configuration/odm-eval.yaml) descriptor to your computer.

2. Accept the license and deploy the release by using the following command:

   ```console
   $ sed 's/view/accept/' odm-eval.yaml | kubectl create --validate=false -f -
   ```

   The package is deployed in a matter of minutes.

## Step 3: Verify that the deployment is running

1. Monitor the pod until it shows a STATUS of *Running* or *Completed*:

   ```console
   $ while kubectl get pods  | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done
   ```

2. When the pod is *Running*, you can access the application with the URL returned by the `minikube service` command.

   ```console
   $ minikube service list

   |-------------|----------------------|-----------------------------|
   |  NAMESPACE  |         NAME         |             URL             |
   |-------------|----------------------|-----------------------------|
   | default     | kubernetes           | No node port                |
   | default     | odm-eval-ibm-odm-dev | http://xxx.xxx.xx.xxx:31074 |
   | kube-system | kube-dns             | No node port                |
   |-------------|----------------------|-----------------------------|
   ```

3. Open the URL named `odm-eval-ibm-odm-dev`. Use odmAdmin/odmAdmin for the user/password.

## To uninstall the release

To uninstall and delete the release from the Kubernetes CLI, use the following command:

```console
$ kubectl delete -f odm-eval.yaml
```
