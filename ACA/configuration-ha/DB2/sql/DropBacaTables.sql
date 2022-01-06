--
-- Licensed Materials - Property of IBM
-- 5737-I23
-- Copyright IBM Corp. 2018 - 2021. All Rights Reserved.
-- U.S. Government Users Restricted Rights:
-- Use, duplication or disclosure restricted by GSA ADP Schedule
-- Contract with IBM Corp.
--
drop VIEW audit_sys_report;
drop table audit_integration_activity;
drop table audit_system_activity;
drop table audit_api_activity;
drop table audit_user_activity;
drop table audit_processed_files;
drop table audit_login_activity;
drop table audit_ontology;
drop table error_log;
drop table processed_file;
drop table key_spacing;
drop table fonts_transid;
drop table fonts;
drop table smartpages_options;
drop table api_integrations_objectsstore;
drop table import_ontology;
drop table integration;
drop table login_detail;
drop table user_detail;
drop table heading_alias;
drop table heading;
drop table attribute_alias;
drop table implementation_kc;
drop table key_alias;
drop table cword;
drop table key_class;
drop table implementation;
drop table object_type;
drop table doc_alias;
drop table feature;
drop table doc_class;
drop table published_models;
drop table models;
drop table training_log;
drop table kvp_model_detail;
drop table runtime_page;
drop table runtime_doc;
drop table systemt_model_metadata;
drop table systemt_models;
drop table feedback;
drop sequence MINOR_VER_SEQ;
