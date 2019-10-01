## Deploy IBM Business Automation Content Analyzer

IBM Business Automation Content Analyzer offers the power of intelligent capture with the flexibility of an API that enables you to extend the value of your core enterprise content management (ECM) technology stack. Advanced AI more accurately classifies data and can be configurable in minutes, instead of weeks.

For more information, see [IBM Business Automation Content Analyzer: Details](https://www.ibm.com/support/knowledgecenter/SSYHZ8_19.0.x/com.ibm.dba.offerings/topics/con_baca.html)


## Deploying with Helm charts

- Extract [ibm-dba-baca-prod-1.2.0.tgz](./helm-charts/ibm-dba-baca-prod-1.2.0.tgz) for non-HA deployment and reference the readme in ibm-dba-baca-prod/README.md after extraction.

- Extract [ibm-dba-baca-prod-1.2.0_ha.tgz](./helm-charts/ibm-dba-baca-prod-1.2.0_ha.tgz) for HA deployment and reference the readme in ibm-dba-baca-prod/README.md after extraction.


## Deploying using Kubernetes YAML

- [Using Kubernetes YAML](k8s-yaml/README.md)


## Completing post deployment configuration

After you deploy your container images, you might need to perform some required and some optional steps to get your Business Automation Content Analyzer environment up and running. For detail instructions, see [Completing post deployment tasks for Business Automation Content Analyzer](docs/post-deployment.md)
