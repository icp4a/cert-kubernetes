create table doc_class
(
	doc_class_id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	doc_class_name VARCHAR (512) NOT NULL,
	comment varchar(1024),
	
	CONSTRAINT doc_class_pkey PRIMARY KEY (doc_class_id),
	
	CONSTRAINT doc_class_doc_class_name_key UNIQUE (doc_class_name)
);

create table doc_alias
(
	doc_alias_id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	doc_alias_name VARCHAR (512) NOT NULL,
	language CHAR(3) NOT NULL,
	
	CONSTRAINT doc_alias_pkey PRIMARY KEY (doc_alias_id),
	
	CONSTRAINT doc_alias_doc_alias_name_key UNIQUE (doc_alias_name)
);

create table key_class
(
	key_class_id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	key_class_name VARCHAR (512) NOT NULL,
	datatype VARCHAR (256) NOT NULL,
	mandatory BOOLEAN,
	sensitive BOOLEAN,
	comment VARCHAR(1024),
	
	CONSTRAINT key_class_pkey PRIMARY KEY (key_class_id)
);

create table key_alias
(
	key_alias_id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	key_alias_name VARCHAR (512) NOT NULL,
	language CHAR(3) NOT NULL,
	
	CONSTRAINT key_alias_pkey PRIMARY KEY (key_alias_id),
	
	CONSTRAINT key_alias_key_alias_name_key UNIQUE (key_alias_name)
);

create table cword
(
	cword_id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	cword_name VARCHAR (512) NOT NULL,
	
	CONSTRAINT cword_pkey PRIMARY KEY (cword_id),
	
	CONSTRAINT cword_cword_name_key UNIQUE (cword_name)
);

create table doc_alias_dc
(
	doc_alias_id INTEGER NOT NULL,
	doc_class_id INTEGER NOT NULL,
	da_count INTEGER NOT NULL,

	CONSTRAINT doc_alias_dc_pkey PRIMARY KEY (doc_alias_id, doc_class_id),

	CONSTRAINT doc_alias_dc_doc_alias_id_fkey FOREIGN KEY (doc_alias_id) REFERENCES doc_alias (doc_alias_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

	constraint doc_alias_dc_doc_class_id_fkey FOREIGN KEY (doc_class_id) REFERENCES doc_class (doc_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE

);

create table key_class_dc
(
	key_class_id INTEGER NOT NULL,
	doc_class_id INTEGER NOT NULL,
	CONSTRAINT key_class_dc_pkey PRIMARY KEY (key_class_id, doc_class_id),

	CONSTRAINT key_class_dc_key_class_id_fkey FOREIGN KEY (key_class_id) REFERENCES key_class (key_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

	CONSTRAINT key_class_dc_doc_class_id_fkey FOREIGN KEY (doc_class_id) REFERENCES doc_class (doc_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);

create table key_alias_dc
(
	key_alias_id INTEGER NOT NULL,
	doc_class_id INTEGER NOT NULL,
	ka_count INTEGER NOT NULL,

	CONSTRAINT key_alias_dc_pkey PRIMARY KEY (key_alias_id, doc_class_id),

	CONSTRAINT key_alias_dc_key_alias_id_fkey FOREIGN KEY (key_alias_id) REFERENCES key_alias (key_alias_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

	CONSTRAINT key_alias_dc_doc_class_id_fkey FOREIGN KEY (doc_class_id) REFERENCES doc_class (doc_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);

create table key_alias_kc
(
	key_alias_id INTEGER NOT NULL,

	key_class_id INTEGER NOT NULL,

	CONSTRAINT key_alias_kc_pkey PRIMARY KEY (key_alias_id, key_class_id),

	CONSTRAINT key_alias_kc_key_alias_id_fkey FOREIGN KEY (key_alias_id) REFERENCES key_alias (key_alias_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

	CONSTRAINT key_alias_kc_key_class_id_fkey FOREIGN KEY (key_class_id) REFERENCES key_class (key_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);

create table cword_dc
(
	doc_class_id INTEGER NOT NULL,
	cword_id INTEGER NOT NULL,
	cw_count INTEGER NOT NULL,

	CONSTRAINT cword_dc_pkey PRIMARY KEY (cword_id, doc_class_id),

	CONSTRAINT cword_dc_doc_class_id_fkey FOREIGN KEY (doc_class_id) REFERENCES doc_class (doc_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

	CONSTRAINT cword_dc_cword_id_fkey FOREIGN KEY (cword_id) REFERENCES cword (cword_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);

create table heading
(
	heading_id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	heading_name VARCHAR (512) NOT NULL,
	comment VARCHAR(1024),
	CONSTRAINT heading_pkey PRIMARY KEY (heading_id)
);

create table heading_alias
(
	heading_alias_id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	heading_alias_name VARCHAR (512) NOT NULL,

 	CONSTRAINT heading_alias_pkey PRIMARY KEY (heading_alias_id),

 	CONSTRAINT heading_alias_heading_alias_name_key unique (heading_alias_name)
);

create table heading_dc
(
	heading_id INTEGER NOT NULL,

	doc_class_id INTEGER NOT NULL,

	CONSTRAINT heading_dc_pkey PRIMARY KEY (heading_id, doc_class_id),

	CONSTRAINT heading_dc_heading_id_fkey FOREIGN KEY (heading_id) REFERENCES heading (heading_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

	CONSTRAINT heading_dc_doc_class_id_fkey FOREIGN KEY (doc_class_id) REFERENCES doc_class (doc_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);

create table heading_alias_h
(
	heading_alias_id INTEGER NOT NULL,
	heading_id INTEGER NOT NULL,

	CONSTRAINT heading_alias_h_pkey PRIMARY KEY (heading_alias_id, heading_id),

	CONSTRAINT heading_alias_h_heading_alias_id_fkey FOREIGN KEY (heading_alias_id) REFERENCES heading_alias (heading_alias_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

	CONSTRAINT heading_alias_h_heading_id_fkey FOREIGN KEY (heading_id) REFERENCES heading (heading_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);

create table heading_alias_dc
(
	heading_alias_id INTEGER NOT NULL,
	doc_class_id INTEGER NOT NULL,

	CONSTRAINT heading_alias_dc_pkey PRIMARY KEY (heading_alias_id, doc_class_id),

	CONSTRAINT heading_alias_dc_heading_alias_id_fkey FOREIGN KEY (heading_alias_id) REFERENCES heading_alias (heading_alias_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

	CONSTRAINT heading_alias_dc_doc_class_id_fkey FOREIGN KEY (doc_class_id) REFERENCES doc_class (doc_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);

create table user_detail
(
	user_id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	email VARCHAR(1024) NOT NULL,
	first_name VARCHAR(512) NOT NULL,
	last_name VARCHAR(512) NOT NULL,
	phone VARCHAR(256),
	company VARCHAR(512),
	expire INTEGER,
	expiry_date BIGINT,
	token VARCHAR(1024) FOR BIT DATA DEFAULT NULL,
	user_name VARCHAR(1024) NOT NULL,
	CONSTRAINT user_detail_pkey PRIMARY KEY (user_id),
	CONSTRAINT user_detail_email_key UNIQUE (email),
	CONSTRAINT user_name UNIQUE (user_name)
);

create table login_detail
(
	user_id INTEGER,
	role VARCHAR(32),
	status BOOLEAN,
	logged_in BOOLEAN DEFAULT 0,

	CONSTRAINT login_detail_user_id_fkey FOREIGN KEY (user_id) REFERENCES user_detail (user_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);

create table integration
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	type VARCHAR(32),
	url VARCHAR(1024),
	user_name VARCHAR(256) DEFAULT NULL,
	password VARCHAR(512) FOR BIT DATA DEFAULT NULL,
	label VARCHAR(256),
	status BOOLEAN,
	model_id VARCHAR(1024),
	api_key VARCHAR(1024) FOR BIT DATA DEFAULT NULL,
	flag VARCHAR(64),
	CONSTRAINT integration_pkey PRIMARY KEY (id)
);

create table integration_dc
(
	id INTEGER NOT NULL,
	doc_class_id INTEGER NOT NULL,	
	checked SMALLINT,

	CONSTRAINT integration_dc_id_fkey FOREIGN KEY (id) REFERENCES integration (id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

	CONSTRAINT integration_dc_doc_class_id_fkey FOREIGN KEY (doc_class_id) REFERENCES doc_class (doc_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

	CONSTRAINT integration_dc_pkey PRIMARY KEY (id, doc_class_id)
);

create table import_ontology
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	user_id INTEGER,
	date BIGINT,
	start_time BIGINT,
	end_time BIGINT,
	complete BOOLEAN,
	failure BOOLEAN,

	CONSTRAINT import_ontology_user_id_fkey FOREIGN KEY (user_id) REFERENCES user_detail (user_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

	CONSTRAINT import_ontology_pkey PRIMARY KEY (id)
);

create table api_integrations_objectsstore
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	user_id INTEGER NOT NULL,
	type VARCHAR(64),
	bucket_name VARCHAR(128) NOT NULL,
	endpoint VARCHAR(1024) NOT NULL,
	access_key VARCHAR(1024) NOT NULL FOR BIT DATA,
	access_id VARCHAR(1024) NOT NULL FOR BIT DATA,
	signatureversion VARCHAR(128) NOT NULL,
	forcestylepath boolean,
	
	CONSTRAINT api_integrations_objectsstore_id_pk PRIMARY KEY (id),
	
	CONSTRAINT api_integrations_objectsstore_user_detail_user_id_fk FOREIGN KEY (user_id) REFERENCES user_detail (user_id)
);

create table smartpages_options
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	outputname VARCHAR(6),
	company VARCHAR(512),
	selections VARCHAR(256),
	CONSTRAINT smartpages_options_pkey PRIMARY KEY (id)
);

create table fonts
(
	font_id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	font_size VARCHAR(256) NOT NULL,
	total_no_of_observations INTEGER,
	sum_of_observations_by_no_of_pixels DOUBLE,
	sum_of_square_of_observations DOUBLE,
	
	CONSTRAINT fonts_pkey PRIMARY KEY (font_id)
);

create table fonts_dc
(
	font_id INTEGER NOT NULL,
	doc_class_id INTEGER NOT NULL,
	
	CONSTRAINT fonts_dc_pkey PRIMARY KEY (font_id, doc_class_id),
		
	CONSTRAINT fonts_dc_font_id_fkey FOREIGN KEY (font_id) REFERENCES fonts (font_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,
	
	CONSTRAINT fonts_dc_doc_class_id_fkey FOREIGN KEY (doc_class_id) REFERENCES doc_class (doc_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);

create table fonts_transid
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	transid VARCHAR(256) NOT NULL,
	
	CONSTRAINT fonts_transid_pkey PRIMARY KEY (id),
	
	CONSTRAINT fonts_transid_transid_key UNIQUE (transid)
);

create table db_backup
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	date BIGINT NOT NULL,
	frequency CHAR(15) NOT NULL,
	type VARCHAR(1024) NOT NULL,
	start_time BIGINT,
	end_time BIGINT,
	complete BOOLEAN DEFAULT 0,
	failure BOOLEAN DEFAULT 0,
	obj_cred_id INTEGER NOT NULL,

	CONSTRAINT db_backup_pkey PRIMARY KEY (id)
	
	--CONSTRAINT db_backup_obj_cred_id_fkey FOREIGN KEY (obj_cred_id) REFERENCES api_integrations_objectsstore (obj_cred_id)
	--ON UPDATE RESTRICT ON DELETE CASCADE
);

create table key_spacing
(
	key_class_id INTEGER NOT NULL,
	key_class_count INTEGER,
	key_class_count_doc INTEGER,
	class_total_docs INTEGER,
	sum_x INTEGER,
	sum_x_sq INTEGER,
	sum_y INTEGER,
	sum_y_sq INTEGER,
	
	CONSTRAINT key_spacing_pkey PRIMARY KEY (key_class_id),
	
	CONSTRAINT key_spacing_key_class_id_fkey FOREIGN KEY (key_class_id) REFERENCES key_class (key_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);


create table processed_file
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	transaction_id VARCHAR(256) NOT NULL,
	file_name VARCHAR(1024) NOT NULL,
	number_of_page INTEGER,
	date BIGINT,
	start_time BIGINT,
	end_time BIGINT,
	failed_ocr_pages INTEGER DEFAULT 0,
	failed_pages INTEGER DEFAULT 0,
	failed BOOLEAN DEFAULT FALSE,
	
	CONSTRAINT processed_file_pkey PRIMARY KEY (id),
	CONSTRAINT processed_file_transaction_id_key UNIQUE (transaction_id)
);

create table error_log
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	transaction_id VARCHAR(256),
	error_code CHAR(32),
	description VARCHAR(1024),
	date BIGINT,
	
	CONSTRAINT error_log_pkey PRIMARY KEY (id),
	
	CONSTRAINT error_log_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES processed_file (transaction_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);

create table db_restore
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	start_time BIGINT,
	end_time BIGINT,
	complete BOOLEAN DEFAULT FALSE,
	failure BOOLEAN DEFAULT FALSE,
	
	CONSTRAINT db_restore_pkey PRIMARY KEY (id)
);

create table audit_ontology
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	username VARCHAR(1024),
	type VARCHAR(256),
	action VARCHAR(512),
	description VARCHAR(1024),
	date BIGINT,
	time_elapsed VARCHAR(128),
	error BOOLEAN DEFAULT FALSE,
	page VARCHAR(32) DEFAULT '',
	
	CONSTRAINT audit_ontology_pkey PRIMARY KEY (id)
);

create table audit_login_activity
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	username VARCHAR(1024),
	type VARCHAR(256),
	action VARCHAR(512),
	description VARCHAR(1024),
	date BIGINT,
	time_elapsed VARCHAR(128),
	error BOOLEAN DEFAULT FALSE,
	page VARCHAR(32) DEFAULT '',
	
	CONSTRAINT audit_login_activity_pkey PRIMARY KEY (id)
);

create table audit_processed_files
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	username VARCHAR(1024),
	type VARCHAR(256),
	action VARCHAR(512),
	description VARCHAR(1024),
	date BIGINT,
	time_elapsed VARCHAR(128),
	transaction_id VARCHAR(256),
	error BOOLEAN DEFAULT FALSE,
	page VARCHAR(32) DEFAULT '',
	
	CONSTRAINT audit_processed_files_pkey PRIMARY KEY (id)
);

create table audit_user_activity
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	username VARCHAR(1024),
	type VARCHAR(256),
	action VARCHAR(512),
	description VARCHAR(1024),
	date BIGINT,
	time_elapsed VARCHAR(128),
	error BOOLEAN DEFAULT FALSE,
	page VARCHAR(32) DEFAULT '',
	
	CONSTRAINT audit_user_activity_pkey PRIMARY KEY (id)
);

create table  audit_api_activity
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	username  VARCHAR(1024),
	type  VARCHAR(256),
	action  VARCHAR(512),
	description  VARCHAR(1024),
	date BIGINT,
	time_elapsed  VARCHAR(128),
	error BOOLEAN DEFAULT FALSE,
	page  VARCHAR(32) DEFAULT '',
	
	CONSTRAINT audit_api_activity PRIMARY KEY (id)
);

create table  audit_system_activity
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	username  VARCHAR(1024),
	type  VARCHAR(256),
	action  VARCHAR(512),
	description  VARCHAR(1024),
	date BIGINT,
	time_elapsed  VARCHAR(128),
	error BOOLEAN DEFAULT FALSE,
	page  VARCHAR(32) DEFAULT '',
	
	CONSTRAINT audit_system_activity_pkey PRIMARY KEY (id)
);

create table audit_integration_activity
(
	id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	username VARCHAR(1024),
	type VARCHAR(256),
	action VARCHAR(512),
	description VARCHAR(1024),
	date BIGINT,
	time_elapsed VARCHAR(128),
	error BOOLEAN DEFAULT FALSE,
	page VARCHAR(32) DEFAULT '',
	
	CONSTRAINT audit_integration_activity_pkey PRIMARY KEY (id)
);

CREATE OR REPLACE VIEW audit_sys_report AS SELECT audit_ontology.username,
    audit_ontology.type,
    audit_ontology.action,
    audit_ontology.description,
    audit_ontology.date,
    audit_ontology.time_elapsed,
    audit_ontology.error,
    audit_ontology.page,
    'Ontology' AS details
   FROM audit_ontology
UNION
 SELECT audit_processed_files.username,
    audit_processed_files.type,
    audit_processed_files.action,
    audit_processed_files.description,
    audit_processed_files.date,
    audit_processed_files.time_elapsed,
    audit_processed_files.error,
    audit_processed_files.page,
    'Processed files' AS details
   FROM audit_processed_files
UNION
 SELECT audit_login_activity.username,
    audit_login_activity.type,
    audit_login_activity.action,
    audit_login_activity.description,
    audit_login_activity.date,
    audit_login_activity.time_elapsed,
    audit_login_activity.error,
    audit_login_activity.page,
    'Login activity' AS details
   FROM audit_login_activity
UNION
 SELECT audit_user_activity.username,
    audit_user_activity.type,
    audit_user_activity.action,
    audit_user_activity.description,
    audit_user_activity.date,
    audit_user_activity.time_elapsed,
    audit_user_activity.error,
    audit_user_activity.page,
    'User activity' AS details
   FROM audit_user_activity
UNION
 SELECT audit_system_activity.username,
    audit_system_activity.type,
    audit_system_activity.action,
    audit_system_activity.description,
    audit_system_activity.date,
    audit_system_activity.time_elapsed,
    audit_system_activity.error,
    audit_system_activity.page,
    'System activity' AS detailsimport_ontology
   FROM audit_system_activity
UNION
 SELECT audit_integration_activity.username,
    audit_integration_activity.type,
    audit_integration_activity.action,
    audit_integration_activity.description,
    audit_integration_activity.date,
    audit_integration_activity.time_elapsed,
    audit_integration_activity.error,
    audit_integration_activity.page,
    'Integration activity' AS details
   FROM audit_integration_activity
UNION
 SELECT audit_api_activity.username,
    audit_api_activity.type,
    audit_api_activity.action,
    audit_api_activity.description,
    audit_api_activity.date,
    audit_api_activity.time_elapsed,
    audit_api_activity.error,
    audit_api_activity.page,
    'API activity' AS details
   FROM audit_api_activity
;
