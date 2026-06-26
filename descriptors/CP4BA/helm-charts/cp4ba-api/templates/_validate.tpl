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
Validate required values and fail with helpful error messages
*/}}
{{- define "cp4ba-api.validateRequiredValues" -}}

{{- /* Validate operandNamespace */ -}}
{{- if or (not .Values.serviceAccount.operandNamespace) (eq .Values.serviceAccount.operandNamespace "<Required>") -}}
{{- fail "\n\n❌ ERROR: serviceAccount.operandNamespace is required!\n\nPlease set the namespace where CP4BA operands run.\n\nExample in values.yaml:\n  serviceAccount:\n    operandNamespace: \"cp4ba-operand\"\n\nOr via command line:\n  helm install ... --set serviceAccount.operandNamespace=cp4ba-operand\n" -}}
{{- end -}}

{{- /* Validate operatorNamespace - only if not empty string */ -}}
{{- if eq .Values.serviceAccount.operatorNamespace "<Required>" -}}
{{- fail "\n\n❌ ERROR: serviceAccount.operatorNamespace must be configured!\n\nIf CP4BA operators and operands are in the SAME namespace:\n  Set operatorNamespace to empty string: \"\"\n\nIf CP4BA operators are in a DIFFERENT namespace:\n  Set operatorNamespace to the operator namespace name\n\nExample in values.yaml:\n  serviceAccount:\n    operatorNamespace: \"\"  # Same namespace as operands\n    # OR\n    operatorNamespace: \"cp4ba-operators\"  # Different namespace\n\nOr via command line:\n  helm install ... --set serviceAccount.operatorNamespace=\"\"\n" -}}
{{- end -}}

{{- /* Validate route hostname if route is enabled */ -}}
{{- if .Values.route.enabled -}}
{{- if or (not .Values.route.hostname) (eq .Values.route.hostname "<Required>") -}}
{{- fail "\n\n❌ ERROR: route.hostname is required when route.enabled=true!\n\nThe hostname must match the hostname in your TLS certificate.\n\nRecommended format: cp4ba-api-<namespace>.apps.<cluster-domain>\n\nExample in values.yaml:\n  route:\n    hostname: \"cp4ba-api-cp4ba.apps.mycluster.example.com\"\n\nOr via command line:\n  helm install ... --set route.hostname=cp4ba-api-cp4ba.apps.mycluster.example.com\n\nTo disable route creation:\n  helm install ... --set route.enabled=false\n" -}}
{{- end -}}
{{- end -}}

{{- /* Validate TLS secret exists if TLS is required */ -}}
{{- if and .Values.tls.enabled (eq .Values.tls.validationMode "required") -}}
{{- if not .Values.tls.secretName -}}
{{- fail "\n\n❌ ERROR: tls.secretName is required when tls.enabled=true and tls.validationMode=required!\n\nPlease create a Kubernetes secret with your TLS certificates:\n\n  kubectl create secret generic cp4ba-installer-upgrade-tls \\\n    --from-file=server-cert.pem=/path/to/tls.crt \\\n    --from-file=server-key.pem=/path/to/tls.key \\\n    -n <namespace>\n\nOr set a different secret name in values.yaml:\n  tls:\n    secretName: \"your-tls-secret-name\"\n" -}}
{{- end -}}
{{- end -}}

{{- /* Validate persistence configuration */ -}}
{{- if .Values.persistence.enabled -}}
  {{- /* Case 1: Using existing PVC - must provide existingClaim */ -}}
  {{- if and (not .Values.persistence.existingClaim) (or (not .Values.persistence.storageClass) (eq .Values.persistence.storageClass "<Required>")) -}}
{{- fail "\n\n❌ ERROR: persistence.storageClass is required when persistence.enabled=true!\n\nWhen persistence is enabled, you must either:\n\n1. Provide a storageClass to create a new PVC:\n   persistence:\n     storageClass: \"rook-cephfs\"  # or \"rook-ceph-block\", \"ocs-storagecluster-cephfs\", etc.\n\n2. Use an existing PVC:\n   persistence:\n     existingClaim: \"my-existing-pvc-name\"\n\nStorage class requirements:\n  - Must support ReadWriteOnce (RWO) access mode\n  - Must be POSIX-compliant\n\nExample via command line:\n  helm install ... --set persistence.storageClass=rook-cephfs\n  # OR\n  helm install ... --set persistence.existingClaim=my-pvc\n\nTo disable persistence:\n  helm install ... --set persistence.enabled=false\n" -}}
  {{- end -}}
  {{- /* Case 2: Both existingClaim and storageClass provided - warn user */ -}}
  {{- if and .Values.persistence.existingClaim .Values.persistence.storageClass (ne .Values.persistence.storageClass "<Required>") -}}
{{- fail "\n\n⚠️  WARNING: Both persistence.existingClaim and persistence.storageClass are set!\n\nWhen persistence.existingClaim is provided, the storageClass setting is ignored.\nThe chart will use the existing PVC and will NOT create a new one.\n\nTo fix this:\n  - If using existing PVC: Remove or comment out storageClass\n  - If creating new PVC: Remove or comment out existingClaim\n\nCurrent configuration:\n  existingClaim: {{ .Values.persistence.existingClaim }}\n  storageClass: {{ .Values.persistence.storageClass }}\n" -}}
  {{- end -}}
{{- end -}}

{{- end -}}