{{/*
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2026 All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
*/}}
{{/*
Expand the name of the chart.
*/}}
{{- define "cp4ba-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Always returns "ibm-cp4ba-api" for consistent naming.
*/}}
{{- define "cp4ba-api.fullname" -}}
ibm-cp4ba-api
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cp4ba-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cp4ba-api.labels" -}}
helm.sh/chart: {{ include "cp4ba-api.chart" . }}
{{ include "cp4ba-api.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Pod labels - includes selector labels plus networking labels
*/}}
{{- define "cp4ba-api.podLabels" -}}
{{- include "cp4ba-api.selectorLabels" . }}
com.ibm.cp4a.networking/egress-allow-same-namespace: 'true'
com.ibm.cp4a.networking/egress-allow-cpfs: 'true'
com.ibm.cp4a.networking/egress-deny-all: 'true'
com.ibm.cp4a.ecm.networking/egress-allow-db: 'true'
com.ibm.cp4a.networking/egress-allow-k8s-services: 'true'
com.ibm.cp4a.networking/egress-allow-all: 'true'
com.ibm.cp4a.networking/egress-allow-ldap: 'true'
com.ibm.baw.networking/egress-allow-all: 'true'
com.ibm.baw.networking/egress-allow-k8s-services: 'true'
com.ibm.baw.networking/egress-allow-ldap: 'true'
com.ibm.baw.networking/egress-allow-same-namespace: 'true'
com.ibm.baw.networking/egress-allow-cpfs: 'true'
com.ibm.baw.networking/egress-deny-all: 'true'
com.ibm.baw.ecm.networking/egress-allow-db: 'true'
instana-autotrace: 'false'
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cp4ba-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cp4ba-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Fusion backup labels
*/}}
{{- define "cp4ba-api.backupLabels" -}}
cp4ba.ibm.com/backup-type: mandatory
{{- end }}


{{/*
Pod  annotations
*/}}
{{- define "cp4ba-api.annotations" -}}
cloudpakId: 94a9c8c358bb43ba8fbdea62e7e166a5
cloudpakName: IBM Cloud Pak for Business Automation
cloudpakVersion: {{ .Chart.AppVersion }}
productChargedContainers: ""
productID: 94a9c8c358bb43ba8fbdea62e7e166a5
productMetric: VIRTUAL_PROCESSOR_CORE
productName: IBM Cloud Pak for Business Automation
productVersion: {{ .Chart.AppVersion }}
{{- end }}


{{/*
Create the name of the service account to use
*/}}
{{- define "cp4ba-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cp4ba-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
