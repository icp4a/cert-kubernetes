--object type tables
create table object_type
(
	object_type_id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	name VARCHAR (512) NOT NULL,
	symbolic_name VARCHAR (512) NOT NULL,
	scope VARCHAR (512) NOT NULL,
	type INTEGER NOT NULL,
	parent_type INTEGER NOT NULL,
	flags INTEGER,
	version INTEGER,
	description VARCHAR(1024),
	
	CONSTRAINT object_type_object_type_id_key UNIQUE (object_type_id),
	CONSTRAINT object_type_pkey PRIMARY KEY (scope, symbolic_name)
);

GRANT ALTER ON TABLE $tenant_ontology.object_type TO USER $tenant_db_user ;

insert into object_type 
(name, symbolic_name, scope, type, parent_type, flags, version, description) 
values 
( 'Object', 'Object', 'sys', 1, 1, 0, 1, 'Default type - Object'),
( 'Numeric', 'Numeric', 'sys', 1, 1, 0, 1, 'Default type - Numeric'), 
( 'Alphabetic', 'Alphabetic', 'sys', 1, 1, 0, 1, 'Default type - Alphabetic'),
( 'ExtendedNumeric', 'ExtendedNumeric', 'sys', 1, 2, 0, 1, 'Default type - Extended Numeric'), 
( 'ExtendedAlphabetic', 'ExtendedAlphabetic', 'sys', 1, 3, 0, 1, 'Default type - Extended Alphabetic');

reorg table object_type;

create table implementation
(
	impl_id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 NO CYCLE),
	name VARCHAR (512) NOT NULL,
	symbolic_name VARCHAR (512) NOT NULL,
	object_type_id INTEGER NOT NULL,
	impl_type SMALLINT NOT NULL,
	extraction_tool SMALLINT NOT NULL,
	flags SMALLINT NOT NULL,
	description VARCHAR(1024),
	config BLOB (10M) NOT NULL,
	
	CONSTRAINT implementation_pkey PRIMARY KEY (object_type_id, symbolic_name),
	
	CONSTRAINT implementation_object_type_id_fkey FOREIGN KEY (object_type_id) REFERENCES object_type (object_type_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,
	
	CONSTRAINT implementation_impl_id_key UNIQUE (impl_id)
);

GRANT ALTER ON TABLE $tenant_ontology.implementation TO USER $tenant_db_user ;

create table implementation_kc
(
	impl_id INTEGER NOT NULL,
	key_class_id INTEGER NOT NULL,
	flags SMALLINT NOT NULL,
	
	CONSTRAINT implementation_kc_pkey PRIMARY KEY (impl_id, key_class_id),
	
	CONSTRAINT implementation_kc_impl_id_fkey FOREIGN KEY (impl_id) REFERENCES implementation (impl_id)
	ON UPDATE RESTRICT,

	CONSTRAINT implementation_kc_key_class_id_fkey FOREIGN KEY (key_class_id) REFERENCES key_class (key_class_id)
	ON UPDATE RESTRICT ON DELETE CASCADE
);

-- Change the values of column datatype to point to the ids in object_type table; then alter column type
update key_class set datatype = '4' where datatype = 'number';
update key_class set datatype = '5' where datatype = 'char';

alter table key_class alter column datatype set data type INTEGER;
reorg table key_class;

alter table key_class add column config BLOB(10M) NOT NULL default empty_blob();
reorg table key_class;

alter table key_class add constraint key_class_object_type_fkey FOREIGN KEY (datatype) REFERENCES object_type (object_type_id) ON UPDATE RESTRICT ON DELETE CASCADE;
reorg table key_class;

-- Modified processed_file to support kvpml feature
create table kvp_model_detail
(
  template_check_sum VARCHAR(1024),
  document_id        INTEGER NOT NULL,
  num_kvp_defined    SMALLINT,
  num_kvp_found      SMALLINT,
  num_kvp_trained    SMALLINT,
  kvp_json           BLOB(50M),
  CONSTRAINT document_id_fkey FOREIGN KEY (document_id) REFERENCES document (id) ON UPDATE RESTRICT ON DELETE CASCADE
);

-- Modifed documenet table column added kvp review status - 0  NOT REVIEWED. 1. REVIEW DONE and used run time.
alter table document add column kvp_status smallint default 0;
reorg table document;

-- Modified processed_file to support kvpml feature
alter table processed_file add column doc_class_id INTEGER;
alter table processed_file add column classifier_id INTEGER;
alter table processed_file add column confidence  real;
alter table processed_file add column num_kvp_defined SMALLINT;
alter table processed_file add column num_kvp_found SMALLINT;
alter table processed_file add foreign key classifier_id_fkey(classifier_id)  REFERENCES classifier(id);
reorg table processed_file;
-- END kvp/ml feature changes

--replace mongo DB2 tables
create table runtime_doc
(
 	transaction_id VARCHAR(256) NOT NULL ,
  initial_upload_time bigint,
  file_name VARCHAR(1024),
  org_content BLOB(250M) INLINE LENGTH 5120,
  utf_content BLOB(250M) INLINE LENGTH 5120,
  pdf_content BLOB(250M) INLINE LENGTH 5120,
  wds_content BLOB(250M) INLINE LENGTH 5120,
  params      BLOB(250M) INLINE LENGTH 5120,
  CONSTRAINT runtime_doc_pkey PRIMARY KEY (transaction_id)
);

create table runtime_page
(
  transaction_id VARCHAR(256) NOT NULL,
  page_id        SMALLINT     NOT NULL,
  jpg_content    BLOB(250M) INLINE LENGTH 5120,
  params         BLOB(250M) INLINE LENGTH 5120,

  CONSTRAINT runtime_page_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES runtime_doc (transaction_id)
	ON UPDATE RESTRICT ON DELETE CASCADE,

  CONSTRAINT runtime_page_pkey PRIMARY KEY (transaction_id, page_id)
);
--End replace mongo DB2 tables