#!/bin/bash
# set -x
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2022. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################

# PROPERTY for UMS
UMSDB_OAUTH_COMMON_PROPERTY=(
    "DATABASE_TYPE"
    "DATABASE_SERVERNAME"
    "DATABASE_PORT"
    "UMS_DB_SID"
    "UMS_DB_SERVICE_NAME"
    "DATABASE_SSL_ENABLE"
    "DATABASE_SSL_SECRET_NAME"
    "HADR_STANDBY_SERVERNAME"
    "HADR_STANDBY_PORT")

UMSDB_OAUTH_CR_MAPPING=(
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_oauth_type"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_oauth_host"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_oauth_port"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_oauth_name"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_oauth_oracle_service_name"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_oauth_ssl"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_oauth_ssl_secret_name"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_oauth_alternate_hosts"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_oauth_alternate_ports")

UMSDB_TS_COMMON_PROPERTY=(
    "DATABASE_TYPE"
    "DATABASE_SERVERNAME"
    "DATABASE_PORT"
    "UMS_DB_SID"
    "UMS_DB_SERVICE_NAME"
    "DATABASE_SSL_ENABLE"
    "DATABASE_SSL_SECRET_NAME"
    "HADR_STANDBY_SERVERNAME"
    "HADR_STANDBY_PORT")

UMSDB_TS_CR_MAPPING=(
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_teamserver_type"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_teamserver_host"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_teamserver_port"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_teamserver_name"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_teamserver_oracle_service_name"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_teamserver_ssl"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_teamserver_ssl_secret_name"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_teamserver_alternate_hosts"
    "spec.datasource_configuration.dc_ums_datasource.dc_ums_teamserver_alternate_ports")

###########################################################
#               Profile Size Configurations               #
###########################################################
# FNCM - CPE profile size
FNCM_CPE_FOOTPRINT_PROFILE_SMALL=(
    "spec.ecm_configuration.cpe.replica_count:1"
    "spec.ecm_configuration.cpe.resources.requests.cpu:1"
    "spec.ecm_configuration.cpe.resources.requests.memory:3072Mi"
    "spec.ecm_configuration.cpe.resources.limits.cpu:1"
    "spec.ecm_configuration.cpe.resources.limits.memory:3072Mi"
)

FNCM_CPE_FOOTPRINT_PROFILE_MEDIUM=(
    "spec.ecm_configuration.cpe.replica_count:2"
    "spec.ecm_configuration.cpe.resources.requests.cpu:1.5"
    "spec.ecm_configuration.cpe.resources.requests.memory:3072Mi"
    "spec.ecm_configuration.cpe.resources.limits.cpu:2"
    "spec.ecm_configuration.cpe.resources.limits.memory:3072Mi"
)

FNCM_CPE_FOOTPRINT_PROFILE_LARGE=(
    "spec.ecm_configuration.cpe.replica_count:2"
    "spec.ecm_configuration.cpe.resources.requests.cpu:3"
    "spec.ecm_configuration.cpe.resources.requests.memory:8192Mi"
    "spec.ecm_configuration.cpe.resources.limits.cpu:4"
    "spec.ecm_configuration.cpe.resources.limits.memory:8192Mi"
)

# FNCM - CMIS profile size
FNCM_CMIS_FOOTPRINT_PROFILE_SMALL=(
    "spec.ecm_configuration.cmis.replica_count:1"
    "spec.ecm_configuration.cmis.resources.requests.cpu:0.5"
    "spec.ecm_configuration.cmis.resources.requests.memory:1536Mi"
    "spec.ecm_configuration.cmis.resources.limits.cpu:1"
    "spec.ecm_configuration.cmis.resources.limits.memory:1536Mi"
)

FNCM_CMIS_FOOTPRINT_PROFILE_MEDIUM=(
    "spec.ecm_configuration.cmis.replica_count:2"
    "spec.ecm_configuration.cmis.resources.requests.cpu:0.5"
    "spec.ecm_configuration.cmis.resources.requests.memory:1536Mi"
    "spec.ecm_configuration.cmis.resources.limits.cpu:1"
    "spec.ecm_configuration.cmis.resources.limits.memory:1536Mi"
)

FNCM_CMIS_FOOTPRINT_PROFILE_LARGE=(
    "spec.ecm_configuration.cmis.replica_count:2"
    "spec.ecm_configuration.cmis.resources.requests.cpu:0.5"
    "spec.ecm_configuration.cmis.resources.requests.memory:1536Mi"
    "spec.ecm_configuration.cmis.resources.limits.cpu:1"
    "spec.ecm_configuration.cmis.resources.limits.memory:1536Mi"
)

# FNCM - GRAPHQL profile size
FNCM_GRAPHQL_FOOTPRINT_PROFILE_SMALL=(
    "spec.ecm_configuration.graphql.replica_count:1"
    "spec.ecm_configuration.graphql.resources.requests.cpu:0.5"
    "spec.ecm_configuration.graphql.resources.requests.memory:1536Mi"
    "spec.ecm_configuration.graphql.resources.limits.cpu:1"
    "spec.ecm_configuration.graphql.resources.limits.memory:1536Mi"
)

FNCM_GRAPHQL_FOOTPRINT_PROFILE_MEDIUM=(
    "spec.ecm_configuration.graphql.replica_count:3"
    "spec.ecm_configuration.graphql.resources.requests.cpu:0.5"
    "spec.ecm_configuration.graphql.resources.requests.memory:3072Mi"
    "spec.ecm_configuration.graphql.resources.limits.cpu:2"
    "spec.ecm_configuration.graphql.resources.limits.memory:3072Mi"
)

FNCM_GRAPHQL_FOOTPRINT_PROFILE_LARGE=(
    "spec.ecm_configuration.graphql.replica_count:6"
    "spec.ecm_configuration.graphql.resources.requests.cpu:1"
    "spec.ecm_configuration.graphql.resources.requests.memory:3072Mi"
    "spec.ecm_configuration.graphql.resources.limits.cpu:2"
    "spec.ecm_configuration.graphql.resources.limits.memory:3072Mi"
)

# BAN profile size
BAN_FOOTPRINT_PROFILE_SMALL=(
    "spec.navigator_configuration.replica_count:1"
    "spec.navigator_configuration.resources.requests.cpu:1"
    "spec.navigator_configuration.resources.requests.memory:3072Mi"
    "spec.navigator_configuration.resources.limits.cpu:1"
    "spec.navigator_configuration.resources.limits.memory:3072Mi")

BAN_FOOTPRINT_PROFILE_MEDIUM=(
    "spec.navigator_configuration.replica_count:2"
    "spec.navigator_configuration.resources.requests.cpu:2"
    "spec.navigator_configuration.resources.requests.memory:4096Mi"
    "spec.navigator_configuration.resources.limits.cpu:3"
    "spec.navigator_configuration.resources.limits.memory:4096Mi")

BAN_FOOTPRINT_PROFILE_LARGE=(
    "spec.navigator_configuration.replica_count:10"
    "spec.navigator_configuration.resources.requests.cpu:2"
    "spec.navigator_configuration.resources.requests.memory:6144Mi"
    "spec.navigator_configuration.resources.limits.cpu:4"
    "spec.navigator_configuration.resources.limits.memory:6144Mi")

# RR profile size
RR_FOOTPRINT_PROFILE_SMALL=(
    "spec.resource_registry_configuration.replica_size:1"
    "spec.resource_registry_configuration.resource.requests.cpu:100m"
    "spec.resource_registry_configuration.resource.requests.memory:256Mi"
    "spec.resource_registry_configuration.resource.limits.cpu:500m"
    "spec.resource_registry_configuration.resource.limits.memory:512Mi"
)

RR_FOOTPRINT_PROFILE_MEDIUM=(
    "spec.resource_registry_configuration.replica_size:3"
    "spec.resource_registry_configuration.resource.requests.cpu:100m"
    "spec.resource_registry_configuration.resource.requests.memory:256Mi"
    "spec.resource_registry_configuration.resource.limits.cpu:500m"
    "spec.resource_registry_configuration.resource.limits.memory:512Mi"
)

RR_FOOTPRINT_PROFILE_LARGE=(
    "spec.resource_registry_configuration.replica_size:3"
    "spec.resource_registry_configuration.resource.requests.cpu:100m"
    "spec.resource_registry_configuration.resource.requests.memory:256Mi"
    "spec.resource_registry_configuration.resource.limits.cpu:500m"
    "spec.resource_registry_configuration.resource.limits.memory:512Mi"
)

# AE profile size
AE_FOOTPRINT_PROFILE_SMALL=(
    "spec.application_engine_configuration[*].replica_size:1"
    "spec.application_engine_configuration[*].resource_ae.requests.cpu:300m"
    "spec.application_engine_configuration[*].resource_ae.requests.memory:256Mi"
    "spec.application_engine_configuration[*].resource_ae.limits.cpu:500m"
    "spec.application_engine_configuration[*].resource_ae.limits.memory:1Gi"
)

AE_FOOTPRINT_PROFILE_MEDIUM=(
    "spec.application_engine_configuration[*].replica_size:3"
    "spec.application_engine_configuration[*].resource_ae.requests.cpu:300m"
    "spec.application_engine_configuration[*].resource_ae.requests.memory:256Mi"
    "spec.application_engine_configuration[*].resource_ae.limits.cpu:500m"
    "spec.application_engine_configuration[*].resource_ae.limits.memory:1Gi"
)

AE_FOOTPRINT_PROFILE_LARGE=(
    "spec.application_engine_configuration[*].replica_size:6"
    "spec.application_engine_configuration[*].resource_ae.requests.cpu:300m"
    "spec.application_engine_configuration[*].resource_ae.requests.memory:256Mi"
    "spec.application_engine_configuration[*].resource_ae.limits.cpu:500m"
    "spec.application_engine_configuration[*].resource_ae.limits.memory:1Gi"
)

# BAW profile size
BAW_STD_FOOTPRINT_PROFILE_SMALL=(
    "spec.baw_configuration[*].replicas:1"
    "spec.baw_configuration[*].resources.requests.cpu:500m"
    "spec.baw_configuration[*].resources.requests.memory:2048Mi"
    "spec.baw_configuration[*].resources.limits.cpu:2"
    "spec.baw_configuration[*].resources.limits.memory:3060Mi"
    "spec.baw_configuration[*].jms.resources.requests.cpu:100m"
    "spec.baw_configuration[*].jms.resources.requests.memory:512Mi"
    "spec.baw_configuration[*].jms.resources.limits.cpu:1000m"
    "spec.baw_configuration[*].jms.resources.limits.memory:1Gi"
)

BAW_STD_FOOTPRINT_PROFILE_MEDIUM=(
    "spec.baw_configuration[*].replicas:2"
    "spec.baw_configuration[*].resources.requests.cpu:500m"
    "spec.baw_configuration[*].resources.requests.memory:2560Mi"
    "spec.baw_configuration[*].resources.limits.cpu:2"
    "spec.baw_configuration[*].resources.limits.memory:3512Mi"
    "spec.baw_configuration[*].jms.resources.requests.cpu:100m"
    "spec.baw_configuration[*].jms.resources.requests.memory:512Mi"
    "spec.baw_configuration[*].jms.resources.limits.cpu:1000m"
    "spec.baw_configuration[*].jms.resources.limits.memory:1Gi"    
)

BAW_STD_FOOTPRINT_PROFILE_LARGE=(
    "spec.baw_configuration[*].replicas:4"
    "spec.baw_configuration[*].resources.requests.cpu:1"
    "spec.baw_configuration[*].resources.requests.memory:3060Mi"
    "spec.baw_configuration[*].resources.limits.cpu:2"
    "spec.baw_configuration[*].resources.limits.memory:4000Mi"
    "spec.baw_configuration[*].jms.resources.requests.cpu:500m"
    "spec.baw_configuration[*].jms.resources.requests.memory:512Mi"
    "spec.baw_configuration[*].jms.resources.limits.cpu:1000m"
    "spec.baw_configuration[*].jms.resources.limits.memory:1Gi"    
)

# PFS profile size
PFS_FOOTPRINT_PROFILE_SMALL=(
    "spec.pfs_configuration.replicas:1"
    "spec.pfs_configuration.resources.requests.cpu:200m"
    "spec.pfs_configuration.resources.requests.memory:512Mi"
    "spec.pfs_configuration.resources.limits.cpu:1"
    "spec.pfs_configuration.resources.limits.memory:1024Mi"
)

PFS_FOOTPRINT_PROFILE_MEDIUM=(
    "spec.pfs_configuration.replicas:2"
    "spec.pfs_configuration.resources.requests.cpu:200m"
    "spec.pfs_configuration.resources.requests.memory:512Mi"
    "spec.pfs_configuration.resources.limits.cpu:1"
    "spec.pfs_configuration.resources.limits.memory:1024Mi"
)

PFS_FOOTPRINT_PROFILE_LARGE=(
    "spec.pfs_configuration.replicas:2"
    "spec.pfs_configuration.resources.requests.cpu:300m"
    "spec.pfs_configuration.resources.requests.memory:750Mi"
    "spec.pfs_configuration.resources.limits.cpu:1"
    "spec.pfs_configuration.resources.limits.memory:1512Mi"
)

# ES profile size
ES_FOOTPRINT_PROFILE_SMALL=(
    "spec.elasticsearch_configuration.replicas:1"
    "spec.elasticsearch_configuration.resources.requests.cpu:500m"
    "spec.elasticsearch_configuration.resources.requests.memory:820Mi"
    "spec.elasticsearch_configuration.resources.limits.cpu:800m"
    "spec.elasticsearch_configuration.resources.limits.memory:2Gi"
)

ES_FOOTPRINT_PROFILE_MEDIUM=(
    "spec.elasticsearch_configuration.replicas:3"
    "spec.elasticsearch_configuration.resources.requests.cpu:500m"
    "spec.elasticsearch_configuration.resources.requests.memory:3512Mi"
    "spec.elasticsearch_configuration.resources.limits.cpu:1000m"
    "spec.elasticsearch_configuration.resources.limits.memory:5120Mi"
)

ES_FOOTPRINT_PROFILE_LARGE=(
    "spec.elasticsearch_configuration.replicas:3"
    "spec.elasticsearch_configuration.resources.requests.cpu:1000m"
    "spec.elasticsearch_configuration.resources.requests.memory:3512Mi"
    "spec.elasticsearch_configuration.resources.limits.cpu:2000m"
    "spec.elasticsearch_configuration.resources.limits.memory:5128Mi"
)