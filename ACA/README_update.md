# IBM® Business Automation Content Analyzer
=========

## Introduction

This readme provide instruction to update IBM Business Automation Content Analyzer with IBM® Cloud Pak for Automation platform. IBM Business Automation Content Analyzer offers the power of intelligent capture with the flexibility of an API that enables you to extend the value of your core enterprise content management (ECM) technology stack and helps you rapidly accelerate extraction and classification of data in your documents. 



## Redeploying Content Analyzer if changes are made to the Role Variables
If you need to make changes to CA deployment, you must redeploy CA by doing the following:

Please note that this process will remove any documents you have processed in Content Analyzer.  Please download any needed document output from Content Analyzer before performing these steps.

1) In the CR yaml file:  comment out `ca_configuration` section

2) Apply the CR.  For example:  `oc apply -f [PATH TO CR YAML]`
 
3) Delete the contents under the CA Data PVC and CA Config PVC.

4) In the CR yaml file:  uncomment `ca_configuration` section and make the desired changes.

5) Apply the CR.  For example:  `oc apply -f [PATH TO CR YAML]`