# IBM Cloud Pak for Automation 20.0.1 on Certified Kubernetes

This repository includes folders and resources to help you install the Cloud Pak for Automation software. Installation of the software components is done with the Cloud Pak operator. For demonstration purposes or to get started with the Cloud Pak, you can install a single capability of Digital Business Automation (DBA). For enterprise purposes, you must enable one or more components in a custom resource file and install them in a specified namespace. 

This README is divided into the following sections.

- [Install the Cloud Pak for demonstration purposes](README.md#install-the-cloud-pak-for-demonstration-purposes)
- [Install the Cloud Pak for enterprise purposes](README.md#install-the-cloud-pak-for-enterprise-purposes)
- [Legal Notice](README.md#legal-notice)

## Install the Cloud Pak for demonstration purposes

> **Important:** The Cloud Pak capabilities are presented as patterns. A single pattern is installed in a specified namespace. You cannot install more than one pattern in a single namespace. In 20.0.1, patterns cannot be used to install the Cloud Pak for enterprise purposes. 

The "demo" deployment type reduces the number of steps that you need to do as it uses an Ansible role to create persistent storage that is allocated to a node. If you want to install the Cloud Pak components into a cluster with external storage, see [Install the Cloud Pak for enterprise purposes](README.md#install-the-cloud-pak-for-enterprise-purposes).

Click [Next](demo/README.md) to follow the instructions.

## Install the Cloud Pak for enterprise purposes

The following software can be installed by the Cloud Pak operator. It is important that you **take note of the dependencies** before you proceed to the platform instructions.

| Folder 	| Component name 	| Version in 20.0.1 |
| :---	| :---	| ---: |
| AAE 	| IBM Business Automation Application Engine | 20.0.1 |
| ACA 	| IBM Business Automation Content Analyzer | 20.0.1 |
| ADW 	| IBM Automation Digital Worker | 20.0.1 |
| BAI 	| IBM Business Automation Insights | 20.0.1 |
| BAN   | IBM Business Automation Navigator | 20.0.1 |
| BAS 	| IBM Business Automation Studio | 20.0.1 |
| FNCM 	| IBM FileNet Content Manager | 5.5.4 |
| IAWS 	| IBM Automation Workstream Services | 20.0.1 |
| ODM 	| IBM Operational Decision Manager | 8.10.3 |
| UMS 	| User Management Service | 20.0.1 |

The following table shows dependencies between the components. A mandatory component is indicated in each column with an "M". Optional installation is indicated with an "O".

|  | ACA needs | ADW needs | BAN needs | BAS needs | FNCM needs | IAWS needs | ODM needs |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| AAE 	|  |  |  | M(8,9) |  | M(8) |  |
| ACA 	| - | O(6) |  |  |  |  |  |
| BAI 	|  | O(3) |  |  | O(3) |  | O(3) |
| BAN 	|  |  | - |  | M(7) | M(7) |  |
| BAS 	|  M(4) | M(2,4) |  | - |  | M(4) | O(2,5) |
| FNCM 	|  |  |  |  | - | M(CMIS/CPE only) |  |
| ODM 	|  | O(6) |  |  |  |  | - |
| UMS 	| M(1) | M(1) | O(1) | M(1) | O(1) | M(1) | O(1) |

The type of integration is indicated with the following numbers:

| 1. SSO/Authentication | 4. Designer integration in Studio | 7. Runtime view |
| :--- | :--- | :--- |
| **2. Registration to Resource Registry** | **5. Toolkit for App Designer**  | **8. App execution** |
| **3. Event emitter/dashboard** | **6. Skill execution** | **9. Test and deploy** |

Use the following links to go to the platform on which you want to use the Cloud Pak. On each platform you must configure the operator manifest files to set up an operator instance on your cluster. You can then select and add configuration parameters for the software that you want to install in a custom resources file.

- [IBM Cloud Public](platform/roks/README.md)
- [Red Hat OpenShift](platform/ocp/README.md)
- [Other Certified Kubernetes platforms](platform/k8s/README.md)

## Legal Notice

Legal notice for users of this repository [legal-notice.md](legal-notice.md).
