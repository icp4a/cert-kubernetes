#!/usr/bin/env bash
set -x

echo "Downloading sonar-scanner version ${SONAR_SCANNER_VERSION}"
wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip
unzip sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip -d .

# Scanning repo based on change being a pull request or branch scan
# https://w3.ibm.com/w3publisher/sonarqube-ibm/using-sonarqube/scanner-configuration-setup
./sonar-scanner-${SONAR_SCANNER_VERSION}/bin/sonar-scanner \
     -D sonar.projectKey=${PROJECT_KEY} \
     -D sonar.projectName="${JOB_ORGANIZATION}/${GHE_REPO}" \
     -D sonar.sources=. \
     -D sonar.exclusions=**/*test*,**/lock-file.c \
     -D sonar.host.url=https://sonarqube-prod.apps.wdc-sonarqube-prod.core.cirrus.ibm.com \
     -D sonar.login=${SONAR_KEY} \
     -D sonar.branch.name=${BRANCH} \
     -D sonar.scanner.truststorePath=./build/sonar_cert \
     -D sonar.scanner.truststorePassword=${SONAR_CERT_PW}