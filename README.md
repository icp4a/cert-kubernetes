# IBM Cloud Pak for Automation 19.0.3 on Certified Kubernetes

## Introduction

The repository includes folders and resources to help you install the Cloud Pak software. The following software can be managed by the Cloud Pak operator.


| Folder 	| Component name 	| Version in 19.0.3 |
| :---	| :---	| ---: |
| AAE 	| IBM Business Automation Application Engine | 19.0.3 |
| ACA 	| IBM Business Automation Content Analyzer | 19.0.3 |
| ADW 	| IBM Automation Digital Worker | 19.0.3 |
| BAI 	| IBM Business Automation Insights | 19.0.3 |
| BAN   | IBM Business Automation Navigator | 3.0.7 |
| BAS 	| IBM Business Automation Studio | 19.0.3 |
| FNCM 	| IBM FileNet Content Manager | 5.5.4 |
| IAWS 	| IBM Automation Workstream Services | 19.0.3 |
| ODM 	| IBM Operational Decision Manager | 8.10.3 |
| UMS 	| User Management Service | 19.0.3 |

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
| UMS 	| M(1) | M(1) | O(1) | M(1) | O(1) | M(1) |  |

The type of integration is indicated with the following numbers:

| 1. SSO/Authentication | 4. Designer integration in Studio | 7. Runtime view |
| :--- | :--- | :--- |
| **2. Registration to  Resource Registry** | **5. Toolkit for App designer**  | **8. App execution** |
| **3. Event emitter/dashboard** | **6. Skill execution** | **9. Test and deploy** |

## Choose your platform and follow the instructions

Use the following links to go to the platform on which you want to install. On each platform you must configure some manifest files that set up your cluster and the operator. You can then select and add configuration parameters for the software that you want to install in a custom resources (.yaml) file.

- [Managed Red Hat OpenShift on IBM Cloud Public](platform/roks/README.md)
- [Red Hat OpenShift](platform/ocp/README.md)
- [Other Certified Kubernetes platforms](platform/k8s/README.md)

Installation is supported only on Certified Kubernetes platforms. Cloud Native Computing Foundation (CNCF) has created a Certified Kubernetes Conformance Program, in which most of the leading vendors and cloud computing providers have Certified Kubernetes offerings. Use the following link to determine whether the vendor and/or platform is certified by CNCF https://landscape.cncf.io/category=platform. For more information about nonqualified platforms, see the [support statement for Certified Kubernetes](http://www.ibm.com/support/docview.wss?uid=ibm10876926).

> **Note**: Support to install on IBM Cloud Private with the Business Automation Configuration Container is removed in 19.0.3. You can use the Certified Kubernetes instructions to install the automation containers on this platform.

## Legal Notice

Legal notice for users of this repository [legal-notice.md](legal-notice.md).
