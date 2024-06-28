#!/BIN/BASH

###############################################################################
#
# LICENSED MATERIALS - PROPERTY OF IBM
#
# (C) COPYRIGHT IBM CORP. 2022. ALL RIGHTS RESERVED.
#
# US GOVERNMENT USERS RESTRICTED RIGHTS - USE, DUPLICATION OR
# DISCLOSURE RESTRICTED BY GSA ADP SCHEDULE CONTRACT WITH IBM CORP.
#
###############################################################################

# VARIABLES FOR LDAP PROPERTY FILE.
LDAP_COMMON_PROPERTY=("LDAP_TYPE"
                      "LDAP_SERVER"
                      "LDAP_PORT"
                      "LDAP_BASE_DN"
                      "LDAP_BIND_DN"
                      "LDAP_BIND_DN_PASSWORD"
                      "LDAP_SSL_ENABLED"
                      "LDAP_SSL_SECRET_NAME"
                      "LDAP_SSL_CERT_FILE_FOLDER"
                      "LDAP_USER_NAME_ATTRIBUTE"
                      "LDAP_USER_DISPLAY_NAME_ATTR"
                      "LDAP_GROUP_BASE_DN"
                      "LDAP_GROUP_NAME_ATTRIBUTE"
                      "LDAP_GROUP_DISPLAY_NAME_ATTR"
                      "LDAP_GROUP_MEMBERSHIP_SEARCH_FILTER"
                      "LDAP_GROUP_MEMBER_ID_MAP")

LDAP_COMMON_CR_MAPPING=("spec.ldap_configuration.lc_selected_ldap_type"
                        "spec.ldap_configuration.lc_ldap_server"
                        "spec.ldap_configuration.lc_ldap_port"
                        "spec.ldap_configuration.lc_ldap_base_dn"
                        "null"
                        "null"
                        "spec.ldap_configuration.lc_ldap_ssl_enabled"
                        "spec.ldap_configuration.lc_ldap_ssl_secret_name"
                        "null"
                        "spec.ldap_configuration.lc_ldap_user_name_attribute"
                        "spec.ldap_configuration.lc_ldap_user_display_name_attr"
                        "spec.ldap_configuration.lc_ldap_group_base_dn"
                        "spec.ldap_configuration.lc_ldap_group_name_attribute"
                        "spec.ldap_configuration.lc_ldap_group_display_name_attr"
                        "spec.ldap_configuration.lc_ldap_group_membership_search_filter"
                        "spec.ldap_configuration.lc_ldap_group_member_id_map")

EXT_LDAP_COMMON_CR_MAPPING=("spec.ext_ldap_configuration.lc_selected_ldap_type"
                            "spec.ext_ldap_configuration.lc_ldap_server"
                            "spec.ext_ldap_configuration.lc_ldap_port"
                            "spec.ext_ldap_configuration.lc_ldap_base_dn"
                            "null"
                            "null"
                            "spec.ext_ldap_configuration.lc_ldap_ssl_enabled"
                            "spec.ext_ldap_configuration.lc_ldap_ssl_secret_name"
                            "null"
                            "spec.ext_ldap_configuration.lc_ldap_user_name_attribute"
                            "spec.ext_ldap_configuration.lc_ldap_user_display_name_attr"
                            "spec.ext_ldap_configuration.lc_ldap_group_base_dn"
                            "spec.ext_ldap_configuration.lc_ldap_group_name_attribute"
                            "spec.ext_ldap_configuration.lc_ldap_group_display_name_attr"
                            "spec.ext_ldap_configuration.lc_ldap_group_membership_search_filter"
                            "spec.ext_ldap_configuration.lc_ldap_group_member_id_map")

COMMENTS_LDAP_PROPERTY=("## The possible values are: \"IBM Security Directory Server\" or \"Microsoft Active Directory\""
                        "## The hostname of the LDAP server. (Only a hostname or an IPv4 address is supported for LDAP server. Do NOT specify an IPv6 address for this property.)"
                        "## The port of the LDAP server to connect.  Some possible values are: 389, 636, etc."
                        "## The LDAP base DN.  For example, \"dc=example,dc=com\", \"dc=abc,dc=com\", etc"
                        "## The LDAP bind DN. For example, \"uid=user1,dc=example,dc=com\", \"uid=user1,dc=abc,dc=com\", etc."
                        "## The password (if password has special characters then Base64 encoded with {Base64} prefix, otherwise use plain text) for LDAP bind DN."
                        "## Enable SSL/TLS for LDAP communication. Refer to Knowledge Center for more info."
                        "## The name of the secret that contains the LDAP SSL/TLS certificate."
                        "## If enabled LDAP SSL, you need copy the SSL certificate file (named ldap-cert.crt) into this directory. Default value is <LDAP_SSL_CERT_FOLDER>"
                        "## The LDAP user name attribute. Semicolon-separated list that must include the first RDN user distinguished names. One possible value is \"*:uid\" for TDS and \"user:sAMAccountName\" for AD. Refer to Knowledge Center for more info."
                        "## The LDAP user display name attribute. One possible value is \"cn\" for TDS and \"sAMAccountName\" for AD. Refer to Knowledge Center for more info."
                        "## The LDAP group base DN.  For example, \"dc=example,dc=com\", \"dc=abc,dc=com\", etc"
                        "## The LDAP group name attribute.  One possible value is \"*:cn\" for TDS and \"*:cn\" for AD. Refer to Knowledge Center for more info."
                        "## The LDAP group display name attribute.  One possible value for both TDS and AD is \"cn\". Refer to Knowledge Center for more info."
                        "## The LDAP group membership search filter string.  One possible value is \"(|(&(objectclass=groupofnames)(member={0}))(&(objectclass=groupofuniquenames)(uniquemember={0})))\" for TDS, and \"(&(cn=%v)(objectcategory=group))\" for AD."
                        "## The LDAP group membership ID map.  One possible value is \"groupofnames:member\" for TDS and \"memberOf:member\" for AD."
                       )

AD_LDAP_PROPERTY=("LC_AD_GC_HOST"
                  "LC_AD_GC_PORT"
                  "LC_USER_FILTER"
                  "LC_GROUP_FILTER")

AD_LDAP_CR_MAPPING=("spec.ldap_configuration.ad.lc_ad_gc_host"
                    "spec.ldap_configuration.ad.lc_ad_gc_port"
                    "spec.ldap_configuration.ad.lc_user_filter"
                    "spec.ldap_configuration.ad.lc_group_filter")

EXT_AD_LDAP_CR_MAPPING=("spec.ext_ldap_configuration.ad.lc_ad_gc_host"
                        "spec.ext_ldap_configuration.ad.lc_ad_gc_port"
                        "spec.ext_ldap_configuration.ad.lc_user_filter"
                        "spec.ext_ldap_configuration.ad.lc_group_filter")

COMMENTS_AD_LDAP_PROPERTY=("## Specify the Global Catalog host for LDAP. Leave empty if not applicable, e.g. \"\""
                           "## Specify the Global Catalog port for LDAP. Leave empty if not applicable, e.g. \"\""
                           "## One possible value is \"(&(sAMAccountName=%v)(objectcategory=user))\""
                           "## One possible value is \"(&(cn=%v)(objectcategory=group))\"")

TDS_LDAP_PROPERTY=("LC_USER_FILTER"
                  "LC_GROUP_FILTER")

TDS_LDAP_CR_MAPPING=("spec.ldap_configuration.tds.lc_user_filter"
                     "spec.ldap_configuration.tds.lc_group_filter")

EXT_TDS_LDAP_CR_MAPPING=("spec.ext_ldap_configuration.tds.lc_user_filter"
                         "spec.ext_ldap_configuration.tds.lc_group_filter")

COMMENTS_TDS_LDAP_PROPERTY=("## One possible value is \"(&(cn=%v)(objectclass=person))\""
                            "## One possible value is \"(&(cn=%v)(|(objectclass=groupofnames)(objectclass=groupofuniquenames)(objectclass=groupofurls)))\"")

# VARIABLES FOR DB PROPERTY FILE.
# OVERALL PROPERTY for datasource_configuration
DATASOURCE_CFG_PROPERTY=("DATABASE_SSL_ENABLED" "DATABASE_PRECHECK")
COMMENTS_DATASOURCE_CFG_PROPERTY=("## The DATABASE_SSL_ENABLED parameter is used to support database connection over SSL for DB2/Oracle/PostgreSQL."
                                  "## The database_precheck parameter is used to enable or disable CPE/Navigator database connection check.")
DATASOURCE_CFG_CR_MAPPING=("spec.datasource_configuration.dc_ssl_enabled"
                           "spec.datasource_configuration.database_precheck")

# PROPERTY for dc_gcd_datasource
GCDDB_COMMON_PROPERTY=("DATABASE_TYPE"
                    #    "DATASOURCE_NAME"
                    #    "XA_DATASOURCE_NAME"
                       "DATABASE_SERVERNAME"
                       "DATABASE_PORT"
                       "GCD_DB_NAME"
                       "GCD_DB_USER_NAME"
                       "DATABASE_SSL_ENABLE"
                       "DATABASE_SSL_SECRET_NAME"
                       "DATABASE_SSL_CERT_FILE_FOLDER"
                       "ORACLE_JDBC_URL"
                       "HADR_STANDBY_SERVERNAME"
                       "HADR_STANDBY_PORT")

GCDDB_CR_MAPPING=("spec.datasource_configuration.dc_gcd_datasource.dc_database_type"
                #   "spec.datasource_configuration.dc_gcd_datasource.dc_common_gcd_datasource_name"
                #   "spec.datasource_configuration.dc_gcd_datasource.dc_common_gcd_xa_datasource_name"
                  "spec.datasource_configuration.dc_gcd_datasource.database_servername"
                  "spec.datasource_configuration.dc_gcd_datasource.database_port"
                  "spec.datasource_configuration.dc_gcd_datasource.database_name"
                  "null"
                  "spec.datasource_configuration.dc_ssl_enabled"
                  "spec.datasource_configuration.dc_gcd_datasource.database_ssl_secret_name"
                  "null"
                  "spec.datasource_configuration.dc_gcd_datasource.dc_oracle_gcd_jdbc_url"
                  "spec.datasource_configuration.dc_gcd_datasource.dc_hadr_standby_servername"
                  "spec.datasource_configuration.dc_gcd_datasource.dc_hadr_standby_port")

GCDDB_PROPERTY_COMMENTS=("## Provide the database type from your infrastructure. The possible values are \"db2\" or \"db2HADR\" or \"oracle\" or \"sqlserver\" \"postgresql\"."
                        #  "## The GCD non-XA datasource name.  The default value is \"FNGCDDS\"."
                        #  "## The GCD XA datasource name. The default value is \"FNGCDDSXA\"."
                         "## Provide the database server name or IP address of the database server. If use IPv6, the addresses need to be enclosed with the square brackets ([...]), e.g. [XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX]."
                         "## Provide the database server port. For Db2, the default is \"50000\". For Oracle, the default is \"1521\". For Postgresql, the default is \"5432\"."
                         "## Provide the name of the database for the GCD of P8Domain. For example: \"GCDDB\""
                         "## Provide the user name of the database for the GCD of P8Domain. For example: \"dbuser1\""
                         "## The parameter is used to support database connection over SSL for database. Default value is \"true\""
                         "## The name of the secret that contains the DB2/Oracle/MSSQLServer/PostgreSQL SSL certificate."
                         "## If enabled DB SSL, you need copy the SSL certificate file (named db-cert.crt) into this directory. Default value is \"<DB_SSL_CERT_FOLDER>\""
                         "## If the database type is Oracle, provide the Oracle DB connection string. For example, \"jdbc:oracle:thin:@//<oracle_server>:1521/orcl\""
                         "## If the database type is Db2 HADR, then complete the rest of the parameters below. Provide the database server name or IP address of the standby database server. If use IPv6, the addresses need to be enclosed with the square brackets ([...]), e.g. [XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX]."
                         "## Provide the standby database server port.  For Db2, the default is \"50000\".")
# PROPERTY for dc_os_datasources
OSDB_COMMON_PROPERTY=("DATABASE_TYPE"
                       "DATABASE_SERVERNAME"
                       "DATABASE_PORT"
                       "DATABASE_SSL_SECRET_NAME"
                       "ORACLE_JDBC_URL"
                       "HADR_STANDBY_SERVERNAME"
                       "HADR_STANDBY_PORT")

OSDB_CR_MAPPING=("dc_database_type"
                 "database_servername"
                 "database_port"
                 "database_ssl_secret_name"
                 "dc_oracle_os_jdbc_url"
                 "dc_hadr_standby_servername"
                 "dc_hadr_standby_port")

OSDB_PROPERTY_COMMENTS=("## Provide the database type from your infrastructure.  The possible values are \"db2\" or \"db2HADR\" or \"oracle\" or \"sqlserver\" \"postgresql\"."
                        "## Provide the object store label for the object store.  The default value is \"os\" or not defined."
                        "## The ObjectStore non-XA datasource name.  The default value is \"FNOS1DS\"."
                        "## The ObjectStore XA datasource name. The default value is \"FNOS1DSXA\"."
                        "## Provide the database server name or IP address of the database server. If use IPv6, the addresses need to be enclosed with the square brackets ([...]), e.g. [XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX]."
                        "## Provide the database server port.  For Db2, the default is \"50000\".  For Oracle, the default is \"1521\""
                        "## Provide the name of the database for the Object Store of P8Domain.  For example: \"OS1DB\""
                        "## Provide the user name of the database for the Object Store of P8Domain.  For example: \"dbuser1\""
                        "## The name of the secret that contains the DB2/Oracle/PostgreSQL SSL certificate."
                        "## If the database type is Oracle, provide the Oracle DB connection string.  For example, \"jdbc:oracle:thin:@//<oracle_server>:1521/orcl\""
                        "## If the database type is Db2 HADR, then complete the rest of the parameters below. Provide the database server name or IP address of the standby database server. If use IPv6, the addresses need to be enclosed with the square brackets ([...]), e.g. [XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX]."
                        "## Provide the standby database server port.  For Db2, the default is \"50000\".")

# PROPERTY for ICN
ICNDB_COMMON_PROPERTY=("DATABASE_TYPE"
                    #    "DATASOURCE_NAME"
                    #    "XA_DATASOURCE_NAME"
                       "DATABASE_SERVERNAME"
                       "DATABASE_PORT"
                       "ICN_DB_NAME"
                       "ICN_DB_USER_NAME"
                       "DATABASE_SSL_ENABLE"
                       "DATABASE_SSL_SECRET_NAME"
                       "DATABASE_SSL_CERT_FILE_FOLDER"
                       "ORACLE_JDBC_URL"
                       "HADR_STANDBY_SERVERNAME"
                       "HADR_STANDBY_PORT")

ICNDB_CR_MAPPING=("spec.datasource_configuration.dc_icn_datasource.dc_database_type"
                #   "spec.datasource_configuration.dc_icn_datasource.dc_common_gcd_datasource_name"
                #   "spec.datasource_configuration.dc_icn_datasource.dc_common_gcd_xa_datasource_name"
                  "spec.datasource_configuration.dc_icn_datasource.database_servername"
                  "spec.datasource_configuration.dc_icn_datasource.database_port"
                  "spec.datasource_configuration.dc_icn_datasource.database_name"
                  "null"
                  "spec.datasource_configuration.dc_ssl_enabled"
                  "spec.datasource_configuration.dc_icn_datasource.database_ssl_secret_name"
                  "null"
                  "spec.datasource_configuration.dc_icn_datasource.dc_oracle_icn_jdbc_url"
                  "spec.datasource_configuration.dc_icn_datasource.dc_hadr_standby_servername"
                  "spec.datasource_configuration.dc_icn_datasource.dc_hadr_standby_port")


ICNDB_PROPERTY_COMMENTS=("## Provide the database type from your infrastructure.  The possible values are \"db2\" or \"db2HADR\" or \"oracle\" or \"sqlserver\" \"postgresql\"."
                        #  "## The GCD non-XA datasource name.  The default value is \"FNGCDDS\"."
                        #  "## The GCD XA datasource name. The default value is \"FNGCDDSXA\"."
                         "## Provide the database server name or IP address of the database server. If use IPv6, the addresses need to be enclosed with the square brackets ([...]), e.g. [XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX]."
                         "## Provide the database server port.  For Db2, the default is \"50000\".  For Oracle, the default is \"1521\""
                         "## Provide the name of the database for ICN (Navigator).  For example: \"ICNDB\""
                         "## Provide the user name of the database for ICN (Navigator).  For example: \"dbuser1\""
                         "## The name of the secret that contains the DB2/Oracle/PostgreSQL SSL certificate."
                         "## If the database type is Oracle, provide the Oracle DB connection string.  For example, \"jdbc:oracle:thin:@//<oracle_server>:1521/orcl\""
                         "## If the database type is Db2 HADR, then complete the rest of the parameters below. Provide the database server name or IP address of the standby database server. If use IPv6, the addresses need to be enclosed with the square brackets ([...]), e.g. [XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX]."
                         "## Provide the standby database server port.  For Db2, the default is \"50000\".")

# PROPERTY for dc_odm_datasource
ODMDB_COMMON_PROPERTY=("DATABASE_TYPE"
                       "DATABASE_SERVERNAME"
                       "DATABASE_PORT"
                       "DATABASE_SSL_ENABLE")
                      #  "DATABASE_SSL_SECRET_NAME")

ODMDB_CR_MAPPING=("spec.datasource_configuration.dc_odm_datasource.dc_database_type"
                 "spec.datasource_configuration.dc_odm_datasource.database_servername"
                 "spec.datasource_configuration.dc_odm_datasource.dc_common_database_port"
                 "spec.datasource_configuration.dc_odm_datasource.dc_common_ssl_enabled")
                #  "spec.datasource_configuration.dc_odm_datasource.dc_ssl_secret_name")

# PROPERTY for dc_ca_datasource
ADPDB_COMMON_PROPERTY=("DATABASE_TYPE"
                       "DATABASE_SERVERNAME"
                       "DATABASE_PORT"
                       "DATABASE_SSL_ENABLE"
                      #  "DATABASE_SSL_SECRET_NAME"
                       "HADR_STANDBY_SERVERNAME"
                       "HADR_STANDBY_PORT")

ADPDB_CR_MAPPING=("spec.datasource_configuration.dc_ca_datasource.dc_database_type"
                 "spec.datasource_configuration.dc_ca_datasource.database_servername"
                 "spec.datasource_configuration.dc_ca_datasource.database_port"
                 "spec.datasource_configuration.dc_ca_datasource.dc_database_ssl_enabled"
                #  "spec.datasource_configuration.dc_ca_datasource.dc_ssl_secret_name"
                 "spec.datasource_configuration.dc_ca_datasource.dc_hadr_standby_servername"
                 "spec.datasource_configuration.dc_ca_datasource.dc_hadr_standby_port")

# PROPERTY for dc_ca_datasource
BASDB_COMMON_PROPERTY=("DATABASE_TYPE"
                       "DATABASE_SERVERNAME"
                       "DATABASE_PORT"
                       "DATABASE_SSL_ENABLE"
                       "DATABASE_SSL_SECRET_NAME"
                       "ORACLE_JDBC_URL"
                       "HADR_STANDBY_SERVERNAME"
                       "HADR_STANDBY_PORT")

BASDB_CR_MAPPING=("spec.bastudio_configuration.database.type"
                 "spec.bastudio_configuration.database.host"
                 "spec.bastudio_configuration.database.port"
                 "spec.bastudio_configuration.database.ssl_enabled"
                 "spec.bastudio_configuration.database.certificate_secret_name"
                 "spec.bastudio_configuration.database.oracle_url"
                 "spec.bastudio_configuration.database.alternative_host"
                 "spec.bastudio_configuration.database.alternative_port")

# PROPERTY for bastudio_configuration.playback_server
PLAYBACKDB_COMMON_PROPERTY=("DATABASE_TYPE"
                       "DATABASE_SERVERNAME"
                       "DATABASE_PORT"
                       "DATABASE_SSL_ENABLE"
                       "DATABASE_SSL_SECRET_NAME"
                       "ORACLE_URL_WITHOUT_WALLET_DIRECTORY"
                       "ORACLE_URL_WITH_WALLET_DIRECTORY"
                       "ORACLE_SSO_WALLET_SECRET_NAME"
                       "HADR_STANDBY_SERVERNAME"
                       "HADR_STANDBY_PORT")

PLAYBACKDB_CR_MAPPING=("spec.bastudio_configuration.playback_server.database.type"
                 "spec.bastudio_configuration.playback_server.database.host"
                 "spec.bastudio_configuration.playback_server.database.port"
                 "spec.bastudio_configuration.playback_server.database.enable_ssl"
                 "spec.bastudio_configuration.playback_server.database.db_cert_secret_name"
                 "spec.bastudio_configuration.playback_server.database.oracle_url_without_wallet_directory"
                 "spec.bastudio_configuration.playback_server.database.oracle_url_with_wallet_directory"
                 "spec.bastudio_configuration.playback_server.database.oracle_sso_wallet_secret_name"
                 "spec.bastudio_configuration.playback_server.database.alternative_host"
                 "spec.bastudio_configuration.playback_server.database.alternative_port")

# PROPERTY for application_engine_configuration.[*].database
AEDB_COMMON_PROPERTY=("DATABASE_TYPE"
                       "DATABASE_SERVERNAME"
                       "DATABASE_PORT"
                       "DATABASE_SSL_ENABLE"
                       "DATABASE_SSL_SECRET_NAME"
                       "ORACLE_URL_WITHOUT_WALLET_DIRECTORY"
                       "ORACLE_URL_WITH_WALLET_DIRECTORY"
                       "ORACLE_SSO_WALLET_SECRET_NAME"
                       "HADR_STANDBY_SERVERNAME"
                       "HADR_STANDBY_PORT")

AEDB_CR_MAPPING=("spec.application_engine_configuration.[0].database.type"
                 "spec.application_engine_configuration.[0].database.host"
                 "spec.application_engine_configuration.[0].database.port"
                 "spec.application_engine_configuration.[0].database.enable_ssl"
                 "spec.application_engine_configuration.[0].database.db_cert_secret_name"
                 "spec.application_engine_configuration.[0].database.oracle_url_without_wallet_directory"
                 "spec.application_engine_configuration.[0].database.oracle_url_with_wallet_directory"
                 "spec.application_engine_configuration.[0].database.oracle_sso_wallet_secret_name"
                 "spec.application_engine_configuration.[0].database.alternative_host"
                 "spec.application_engine_configuration.[0].database.alternative_port")                 

# PROPERTY for baw_configuration.[*].database
BAW_RUNTIME_COMMON_PROPERTY=("DATABASE_TYPE"
                       "DATABASE_SERVERNAME"
                       "DATABASE_PORT"
                       "DATABASE_SSL_ENABLE"
                       "DATABASE_SSL_SECRET_NAME"
                       "HADR_STANDBY_SERVERNAME"
                       "HADR_STANDBY_PORT")

BAW_RUNTIME_CR_MAPPING=("spec.baw_configuration.[0].database.type"
                 "spec.baw_configuration.[0].database.server_name"
                 "spec.baw_configuration.[0].database.port"
                 "spec.baw_configuration.[0].database.enable_ssl"
                 "spec.baw_configuration.[0].database.db_cert_secret_name"
                 "spec.baw_configuration.[0].database.hadr.standbydb_host"
                 "spec.baw_configuration.[0].database.hadr.standbydb_port")


# PROPERTY for baw_configuration.[*].database
AWS_COMMON_PROPERTY=("DATABASE_TYPE"
                       "DATABASE_SERVERNAME"
                       "DATABASE_PORT"
                       "DATABASE_SSL_ENABLE"
                       "DATABASE_SSL_SECRET_NAME"
                       "HADR_STANDBY_SERVERNAME"
                       "HADR_STANDBY_PORT")

AWS_CR_MAPPING=("spec.baw_configuration.[1].database.type"
                 "spec.baw_configuration.[1].database.server_name"
                 "spec.baw_configuration.[1].database.port"
                 "spec.baw_configuration.[1].database.enable_ssl"
                 "spec.baw_configuration.[1].database.db_cert_secret_name"
                 "spec.baw_configuration.[1].database.hadr.standbydb_host"
                 "spec.baw_configuration.[1].database.hadr.standbydb_port")

AWS_ONLY_CR_MAPPING=("spec.baw_configuration.[0].database.type"
                 "spec.baw_configuration.[0].database.server_name"
                 "spec.baw_configuration.[0].database.port"
                 "spec.baw_configuration.[0].database.enable_ssl"
                 "spec.baw_configuration.[0].database.db_cert_secret_name"
                 "spec.baw_configuration.[0].database.hadr.standbydb_host"
                 "spec.baw_configuration.[0].database.hadr.standbydb_port")

SCIM_PROPERTY=("SCIM.USER_UNIQUE_ID_ATTRIBUTE"
                      "SCIM.USER_NAME_ATTRIBUTE"
                      "SCIM.USER_PRINCIPAL_NAME_ATTRIBUTE"
                      "SCIM.USER_DISPLAY_NAME_ATTRIBUTE"
                      "SCIM.USER_GIVEN_NAME_ATTRIBUTE"
                      "SCIM.USER_FAMILY_NAME_ATTRIBUTE"
                      "SCIM.USER_FULL_NAME_ATTRIBUTE"
                      "SCIM.USER_EXTERNAL_ID_ATTRIBUTE"
                      "SCIM.USER_EMAILS_ATTRIBUTE"
                      "SCIM.USER_CREATED_ATTRIBUTE"
                      "SCIM.USER_LASTMODIFIED_ATTRIBUTE"
                      "SCIM.USER_PHONENUMBERS_VALUE1"
                      "SCIM.USER_PHONENUMBERS_TYPE1"
                      "SCIM.USER_PHONENUMBERS_VALUE2"
                      "SCIM.USER_PHONENUMBERS_TYPE2"
                      "SCIM.USER_OBJECT_CLASS_ATTRIBUTE"
                      "SCIM.USER_GROUPS_ATTRIBUTE"
                      "SCIM.GROUP_UNIQUE_ID_ATTRIBUTE"
                      "SCIM.GROUP_NAME_ATTRIBUTE"
                      "SCIM.GROUP_PRINCIPAL_NAME_ATTRIBUTE"
                      "SCIM.GROUP_DISPLAY_NAME_ATTRIBUTE"
                      "SCIM.GROUP_EXTERNAL_ID_ATTRIBUTE"
                      "SCIM.GROUP_CREATED_ATTRIBUTE"
                      "SCIM.GROUP_LASTMODIFIED_ATTRIBUTE"
                      "SCIM.GROUP_OBJECT_CLASS_ATTRIBUTE"
                      "SCIM.GROUP_MEMBERS_ATTRIBUTE")

SCIM_CR_MAPPING=("spec.scim_configuration_iam.user_unique_id_attribute"
                        "spec.scim_configuration_iam.user_name_attribute"
                        "spec.scim_configuration_iam.user_principal_name_attribute"
                        "spec.scim_configuration_iam.user_display_name_attribute"
                        "spec.scim_configuration_iam.user_given_name_attribute"
                        "spec.scim_configuration_iam.user_family_name_attribute"
                        "spec.scim_configuration_iam.user_full_name_attribute"
                        "spec.scim_configuration_iam.user_external_id_attribute"
                        "spec.scim_configuration_iam.user_emails_attribute"
                        "spec.scim_configuration_iam.user_created_attribute"
                        "spec.scim_configuration_iam.user_lastmodified_attribute"
                        "spec.scim_configuration_iam.user_phonenumbers.[0].value"
                        "spec.scim_configuration_iam.user_phonenumbers.[0].type"
                        "spec.scim_configuration_iam.user_phonenumbers.[1].value"
                        "spec.scim_configuration_iam.user_phonenumbers.[1].type"
                        "spec.scim_configuration_iam.user_object_class_attribute"
                        "spec.scim_configuration_iam.user_groups_attribute"
                        "spec.scim_configuration_iam.group_unique_id_attribute"
                        "spec.scim_configuration_iam.group_name_attribute"
                        "spec.scim_configuration_iam.group_principal_name_attribute"
                        "spec.scim_configuration_iam.group_display_name_attribute"
                        "spec.scim_configuration_iam.group_external_id_attribute"
                        "spec.scim_configuration_iam.group_created_attribute"
                        "spec.scim_configuration_iam.group_lastmodified_attribute"
                        "spec.scim_configuration_iam.group_object_class_attribute"
                        "spec.scim_configuration_iam.group_members_attribute")