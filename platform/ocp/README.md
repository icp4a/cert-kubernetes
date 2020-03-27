# IBM Cloud Pak for Automation 20.0.1 on Red Hat OpenShift

Red Hat OpenShift Cloud Platform 3.11, 4.2, or 4.3 is the target platform for Cloud Pak for Automation 20.0.1.

The podman (Pod Manager) command in OCP 4.x can be used to run containers outside of Kubernetes and the OpenShift command line interface. The podman tool acts as a replacement for docker with even more container management features. The two command-line interfaces are so similar that you might want to define `alias docker='podman'`.

Choose which use case you need, and then follow the links below to find the right instructions:

- [Install Cloud Pak for Automation 20.0.1 on Red Hat OpenShift](install.md)
- [Uninstall Cloud Pak for Automation 20.0.1 on Red Hat OpenShift](uninstall.md)
- [Upgrade Cloud Pak for Automation 19.0.3 to 20.0.1 on Red Hat OpenShift](upgrade.md)
- [Migrate 19.0.1 or 19.0.2 persisted data to 20.0.1 on Red Hat OpenShift](migrate.md)
- [Update Cloud Pak for Automation 20.0.1 on Red Hat OpenShift](update.md)

> **Note:** If you installed a previous version of Cloud Pak for Automation on OpenShift Cloud Platform (OCP) 3.11 and you want to upgrade OCP to 4.x, you must install a new instance of the ICP4ACluster. You can then follow the instructions in [How to migrate to 20.0.1](migrate.md) to point your new instance to your persisted data.
