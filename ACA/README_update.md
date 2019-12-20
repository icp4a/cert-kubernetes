# IBM® Business Automation Content Analyzer
=========

## Introduction

With these instructions, you can update IBM Business Automation Content Analyzer with IBM® Cloud Pak for Automation platform. IBM Business Automation Content Analyzer offers the power of intelligent capture with the flexibility of an API that enables you to extend the value of your core enterprise content management (ECM) technology stack and helps you rapidly accelerate extraction and classification of data in your documents. 



## Redeploying Content Analyzer if changes are made to the Role Variables
If you need to make changes to Content Analyzer deployment, you must redeploy Content Analyzer by doing the following:

Note that this process removes any documents that you processed in Content Analyzer.  Download any needed document output from Content Analyzer before doing these steps.

1) In the CR yaml file:  comment out the `ca_configuration` section.

2) Apply the CR.  For example:  `oc apply -f [PATH TO CR YAML]`.
 
3) Delete the contents under the Content Analyzer Data PVC and Content Analyzer Config PVC.

4) In the CR yaml file:  uncomment the `ca_configuration` section and make the changes.

5) Apply the CR.  For example:  `oc apply -f [PATH TO CR YAML]`.
