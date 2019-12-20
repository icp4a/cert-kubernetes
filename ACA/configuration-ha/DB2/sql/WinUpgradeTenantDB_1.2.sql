alter table integration alter column model_id set data type varchar(1024);

reorg table integration;

--pattern tables
create table pattern
(
	pattern_id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	pattern_name VARCHAR (512) NOT NULL,
	description VARCHAR(1024),
	namespace SMALLINT NOT NULL,
	extraction_tool SMALLINT NOT NULL,
	pattern VARCHAR(1024) NOT NULL,
	predefined SMALLINT DEFAULT 0,

	CONSTRAINT pattern_pkey PRIMARY KEY (pattern_id),

	CONSTRAINT pattern_pattern_name_key UNIQUE (pattern_name)
);

GRANT ALTER ON TABLE $tenant_ontology.PATTERN TO USER $tenant_db_user ;

create table pattern_kc
(
	pattern_id INTEGER NOT NULL,
	key_class_id INTEGER NOT NULL,
    pattern_type SMALLINT NOT NULL,

	CONSTRAINT pattern_kc_pkey PRIMARY KEY (pattern_id, key_class_id),

	CONSTRAINT pattern_kc_pattern_id_fkey FOREIGN KEY (pattern_id) REFERENCES pattern (pattern_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

	CONSTRAINT pattern_kc_key_class_id_fkey FOREIGN KEY (key_class_id) REFERENCES key_class (key_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);

---classification schema changes

--flags -0 user defined and default 1. will  be training set detected
--rank -relative importance number 0.0 to 1.0
create table feature
(
  doc_class_id INTEGER  NOT NULL,
  name  VARCHAR (512) NOT NULL,
  flags SMALLINT NOT NULL DEFAULT  0,
  rank REAL DEFAULT 1.0,

  CONSTRAINT feature_doc_class_id_flags_name_key UNIQUE  (doc_class_id ,flags, name),

  CONSTRAINT feature_doc_class_id_fkey FOREIGN KEY (doc_class_id) REFERENCES doc_class (doc_class_id)
  ON UPDATE RESTRICT ON DELETE CASCADE

);

--status 0.uploaded  1.processing 2.text (completed status) 3.error
create table document
(
  id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
  name VARCHAR(1024) NOT NULL,
  doc_class_id INTEGER NOT NULL,
  num_pages SMALLINT NOT NULL,
  upload_date BIGINT NOT NULL,
  user_uploaded INTEGER NOT NULL,
  status SMALLINT NOT NULL,
  error_info VARCHAR(1024),
  content BLOB(250M),

  CONSTRAINT doc_doc_class_id_fkey FOREIGN KEY (doc_class_id) REFERENCES doc_class (doc_class_id)
  ON UPDATE RESTRICT ON DELETE CASCADE,

  CONSTRAINT document_pkey PRIMARY KEY (id)
);

--1. initialized  2. running  3.error 4.trained
--createdby user
--minor_version user initiated(clicked on train)
--major_version developer controled

create table training_log
(
  id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
  status SMALLINT NOT NULL,
  created_date BIGINT NOT NULL,
  major_version SMALLINT NOT NULL,
  minor_version SMALLINT NOT NULL,
  error_info VARCHAR(1024),
  created_by INTEGER NOT NULL,
  json_model_input_detail BLOB(250M),
  global_feature_vector BLOB(250M),

  CONSTRAINT training_log_pkey PRIMARY KEY (id)
);

--create a sequence for minor version
CREATE SEQUENCE MINOR_VER_SEQ AS SMALLINT START WITH 1 INCREMENT BY 1 NO CYCLE NO CACHE ORDER;

--version developer of classifier specifies
create table classifier
(
  id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
  training_id INTEGER NOT NULL,
  displayname VARCHAR(1024) NOT NULL,
  algorithm SMALLINT NOT NULL,
  accuracy real,
  version SMALLINT,
  model_output BLOB(250M),
  json_feature_vector BLOB(250M),
  json_report BLOB(250M),

  CONSTRAINT classifier_pkey PRIMARY KEY (id),

  CONSTRAINT classifier_fkey FOREIGN KEY (training_id) REFERENCES training_log (id)
  ON UPDATE RESTRICT ON DELETE CASCADE
);

--published_status  active ,inactive
create table ontology
(
  vid INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
  default_classifier_id INTEGER NOT NULL,
  name VARCHAR(128) NOT NULL,
  published_status SMALLINT default 0,
  published_date BIGINT NOT NULL,
  published_user INTEGER NOT NULL,

  CONSTRAINT ontology_fkey FOREIGN KEY (default_classifier_id) REFERENCES classifier(id)
  ON UPDATE RESTRICT ON DELETE RESTRICT
);
