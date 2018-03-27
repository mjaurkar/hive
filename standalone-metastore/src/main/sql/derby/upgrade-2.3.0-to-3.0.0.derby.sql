-- Upgrade MetaStore schema from 2.3.0 to 3.0.0
--RUN '041-HIVE-16556.derby.sql';
CREATE TABLE "APP"."METASTORE_DB_PROPERTIES" ("PROPERTY_KEY" VARCHAR(255) NOT NULL, "PROPERTY_VALUE" VARCHAR(1000) NOT NULL, "DESCRIPTION" VARCHAR(1000));

ALTER TABLE "APP"."METASTORE_DB_PROPERTIES" ADD CONSTRAINT "PROPERTY_KEY_PK" PRIMARY KEY ("PROPERTY_KEY");
--RUN '042-HIVE-16575.derby.sql';
-- Remove the NOT NULL constraint from the CHILD_INTEGER_IDX column
ALTER TABLE "APP"."KEY_CONSTRAINTS" ALTER COLUMN "CHILD_INTEGER_IDX" NULL;

CREATE INDEX "APP"."CONSTRAINTS_CONSTRAINT_TYPE_INDEX" ON "APP"."KEY_CONSTRAINTS"("CONSTRAINT_TYPE");
--RUN '043-HIVE-16922.derby.sql';
UPDATE SERDE_PARAMS
SET PARAM_KEY='collection.delim'
WHERE PARAM_KEY='colelction.delim';
--RUN '044-HIVE-16997.derby.sql';
ALTER TABLE "APP"."PART_COL_STATS" ADD COLUMN "BIT_VECTOR" BLOB;
--RUN '045-HIVE-16886.derby.sql';
INSERT INTO "APP"."NOTIFICATION_SEQUENCE" ("NNI_ID", "NEXT_EVENT_ID") SELECT * FROM (VALUES (1,1)) tmp_table WHERE NOT EXISTS ( SELECT "NEXT_EVENT_ID" FROM "APP"."NOTIFICATION_SEQUENCE");
--RUN '046-HIVE-17566.derby.sql';
CREATE TABLE "APP"."WM_RESOURCEPLAN" (RP_ID BIGINT NOT NULL, NAME VARCHAR(128) NOT NULL, QUERY_PARALLELISM INTEGER, STATUS VARCHAR(20) NOT NULL, DEFAULT_POOL_ID BIGINT);
CREATE UNIQUE INDEX "APP"."UNIQUE_WM_RESOURCEPLAN" ON "APP"."WM_RESOURCEPLAN" ("NAME");
ALTER TABLE "APP"."WM_RESOURCEPLAN" ADD CONSTRAINT "WM_RESOURCEPLAN_PK" PRIMARY KEY ("RP_ID");

CREATE TABLE "APP"."WM_POOL" (POOL_ID BIGINT NOT NULL, RP_ID BIGINT NOT NULL, PATH VARCHAR(1024) NOT NULL, ALLOC_FRACTION DOUBLE, QUERY_PARALLELISM INTEGER, SCHEDULING_POLICY VARCHAR(1024));
CREATE UNIQUE INDEX "APP"."UNIQUE_WM_POOL" ON "APP"."WM_POOL" ("RP_ID", "PATH");
ALTER TABLE "APP"."WM_POOL" ADD CONSTRAINT "WM_POOL_PK" PRIMARY KEY ("POOL_ID");
ALTER TABLE "APP"."WM_POOL" ADD CONSTRAINT "WM_POOL_FK1" FOREIGN KEY ("RP_ID") REFERENCES "APP"."WM_RESOURCEPLAN" ("RP_ID") ON DELETE NO ACTION ON UPDATE NO ACTION;
ALTER TABLE "APP"."WM_RESOURCEPLAN" ADD CONSTRAINT "WM_RESOURCEPLAN_FK1" FOREIGN KEY ("DEFAULT_POOL_ID") REFERENCES "APP"."WM_POOL" ("POOL_ID") ON DELETE NO ACTION ON UPDATE NO ACTION;

CREATE TABLE "APP"."WM_TRIGGER" (TRIGGER_ID BIGINT NOT NULL, RP_ID BIGINT NOT NULL, NAME VARCHAR(128) NOT NULL, TRIGGER_EXPRESSION VARCHAR(1024), ACTION_EXPRESSION VARCHAR(1024), IS_IN_UNMANAGED INTEGER NOT NULL DEFAULT 0);
CREATE UNIQUE INDEX "APP"."UNIQUE_WM_TRIGGER" ON "APP"."WM_TRIGGER" ("RP_ID", "NAME");
ALTER TABLE "APP"."WM_TRIGGER" ADD CONSTRAINT "WM_TRIGGER_PK" PRIMARY KEY ("TRIGGER_ID");
ALTER TABLE "APP"."WM_TRIGGER" ADD CONSTRAINT "WM_TRIGGER_FK1" FOREIGN KEY ("RP_ID") REFERENCES "APP"."WM_RESOURCEPLAN" ("RP_ID") ON DELETE NO ACTION ON UPDATE NO ACTION;

CREATE TABLE "APP"."WM_POOL_TO_TRIGGER"  (POOL_ID BIGINT NOT NULL, TRIGGER_ID BIGINT NOT NULL);
ALTER TABLE "APP"."WM_POOL_TO_TRIGGER" ADD CONSTRAINT "WM_POOL_TO_TRIGGER_PK" PRIMARY KEY ("POOL_ID", "TRIGGER_ID");
ALTER TABLE "APP"."WM_POOL_TO_TRIGGER" ADD CONSTRAINT "WM_POOL_TO_TRIGGER_FK1" FOREIGN KEY ("POOL_ID") REFERENCES "APP"."WM_POOL" ("POOL_ID") ON DELETE NO ACTION ON UPDATE NO ACTION;
ALTER TABLE "APP"."WM_POOL_TO_TRIGGER" ADD CONSTRAINT "WM_POOL_TO_TRIGGER_FK2" FOREIGN KEY ("TRIGGER_ID") REFERENCES "APP"."WM_TRIGGER" ("TRIGGER_ID") ON DELETE NO ACTION ON UPDATE NO ACTION;

CREATE TABLE "APP"."WM_MAPPING" (MAPPING_ID BIGINT NOT NULL, RP_ID BIGINT NOT NULL, ENTITY_TYPE VARCHAR(128) NOT NULL, ENTITY_NAME VARCHAR(128) NOT NULL, POOL_ID BIGINT, ORDERING INTEGER);
CREATE UNIQUE INDEX "APP"."UNIQUE_WM_MAPPING" ON "APP"."WM_MAPPING" ("RP_ID", "ENTITY_TYPE", "ENTITY_NAME");
ALTER TABLE "APP"."WM_MAPPING" ADD CONSTRAINT "WM_MAPPING_PK" PRIMARY KEY ("MAPPING_ID");
ALTER TABLE "APP"."WM_MAPPING" ADD CONSTRAINT "WM_MAPPING_FK1" FOREIGN KEY ("RP_ID") REFERENCES "APP"."WM_RESOURCEPLAN" ("RP_ID") ON DELETE NO ACTION ON UPDATE NO ACTION;
ALTER TABLE "APP"."WM_MAPPING" ADD CONSTRAINT "WM_MAPPING_FK2" FOREIGN KEY ("POOL_ID") REFERENCES "APP"."WM_POOL" ("POOL_ID") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- Upgrades for Schema Registry objects
ALTER TABLE "APP"."SERDES" ADD COLUMN "DESCRIPTION" VARCHAR(4000);
ALTER TABLE "APP"."SERDES" ADD COLUMN "SERIALIZER_CLASS" VARCHAR(4000);
ALTER TABLE "APP"."SERDES" ADD COLUMN "DESERIALIZER_CLASS" VARCHAR(4000);
ALTER TABLE "APP"."SERDES" ADD COLUMN "SERDE_TYPE" INTEGER;

CREATE TABLE "APP"."I_SCHEMA" (
  "SCHEMA_ID" bigint primary key,
  "SCHEMA_TYPE" integer not null,
  "NAME" varchar(256) unique,
  "DB_ID" bigint references "APP"."DBS" ("DB_ID"),
  "COMPATIBILITY" integer not null,
  "VALIDATION_LEVEL" integer not null,
  "CAN_EVOLVE" char(1) not null,
  "SCHEMA_GROUP" varchar(256),
  "DESCRIPTION" varchar(4000)
);

CREATE TABLE "APP"."SCHEMA_VERSION" (
  "SCHEMA_VERSION_ID" bigint primary key,
  "SCHEMA_ID" bigint references "APP"."I_SCHEMA" ("SCHEMA_ID"),
  "VERSION" integer not null,
  "CREATED_AT" bigint not null,
  "CD_ID" bigint references "APP"."CDS" ("CD_ID"),
  "STATE" integer not null,
  "DESCRIPTION" varchar(4000),
  "SCHEMA_TEXT" clob,
  "FINGERPRINT" varchar(256),
  "SCHEMA_VERSION_NAME" varchar(256),
  "SERDE_ID" bigint references "APP"."SERDES" ("SERDE_ID")
);

CREATE UNIQUE INDEX "APP"."UNIQUE_SCHEMA_VERSION" ON "APP"."SCHEMA_VERSION" ("SCHEMA_ID", "VERSION");

-- 048-HIVE-14498
-- create mv_creation_metadata table
CREATE TABLE "APP"."MV_CREATION_METADATA" (
  "MV_CREATION_METADATA_ID" BIGINT NOT NULL,
  "DB_NAME" VARCHAR(128) NOT NULL,
  "TBL_NAME" VARCHAR(256) NOT NULL,
  "TXN_LIST" CLOB
);

CREATE TABLE "APP"."MV_TABLES_USED" (
  "MV_CREATION_METADATA_ID" BIGINT NOT NULL,
  "TBL_ID" BIGINT NOT NULL
);

ALTER TABLE "APP"."MV_CREATION_METADATA" ADD CONSTRAINT "MV_CREATION_METADATA_PK" PRIMARY KEY ("MV_CREATION_METADATA_ID");

CREATE UNIQUE INDEX "APP"."MV_UNIQUE_TABLE" ON "APP"."MV_CREATION_METADATA" ("TBL_NAME", "DB_NAME");

ALTER TABLE "APP"."MV_TABLES_USED" ADD CONSTRAINT "MV_TABLES_USED_FK1" FOREIGN KEY ("MV_CREATION_METADATA_ID") REFERENCES "APP"."MV_CREATION_METADATA" ("MV_CREATION_METADATA_ID") ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE "APP"."MV_TABLES_USED" ADD CONSTRAINT "MV_TABLES_USED_FK2" FOREIGN KEY ("TBL_ID") REFERENCES "APP"."TBLS" ("TBL_ID") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- modify completed_txn_components table
ALTER TABLE "APP"."COMPLETED_TXN_COMPONENTS" ADD "CTC_TIMESTAMP" timestamp;

UPDATE "APP"."TBLS" SET "IS_REWRITE_ENABLED" = CURRENT_TIMESTAMP;

ALTER TABLE "APP"."COMPLETED_TXN_COMPONENTS" ALTER COLUMN "CTC_TIMESTAMP" SET DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "APP"."COMPLETED_TXN_COMPONENTS" ALTER COLUMN "CTC_TIMESTAMP" NOT NULL;

CREATE INDEX "APP"."COMPLETED_TXN_COMPONENTS_IDX" ON "APP"."COMPLETED_TXN_COMPONENTS" ("CTC_DATABASE", "CTC_TABLE", "CTC_PARTITION");

-- 049-HIVE-18489.derby.sql
UPDATE FUNC_RU
  SET RESOURCE_URI = 's3a' || SUBSTR(RESOURCE_URI, 4)
  WHERE RESOURCE_URI LIKE 's3n://%' ;

UPDATE SKEWED_COL_VALUE_LOC_MAP
  SET LOCATION = 's3a' || SUBSTR(LOCATION, 4)
  WHERE LOCATION LIKE 's3n://%' ;

UPDATE SDS
  SET LOCATION = 's3a' || SUBSTR(LOCATION, 4)
  WHERE LOCATION LIKE 's3n://%' ;

UPDATE DBS
  SET DB_LOCATION_URI = 's3a' || SUBSTR(DB_LOCATION_URI, 4)
  WHERE DB_LOCATION_URI LIKE 's3n://%' ;

-- 050-HIVE-18192.derby.sql
CREATE TABLE TXN_TO_WRITE_ID (
  T2W_TXNID bigint NOT NULL,
  T2W_DATABASE varchar(128) NOT NULL,
  T2W_TABLE varchar(256) NOT NULL,
  T2W_WRITEID bigint NOT NULL
);

CREATE UNIQUE INDEX TBL_TO_TXN_ID_IDX ON TXN_TO_WRITE_ID (T2W_DATABASE, T2W_TABLE, T2W_TXNID);
CREATE UNIQUE INDEX TBL_TO_WRITE_ID_IDX ON TXN_TO_WRITE_ID (T2W_DATABASE, T2W_TABLE, T2W_WRITEID);

CREATE TABLE NEXT_WRITE_ID (
  NWI_DATABASE varchar(128) NOT NULL,
  NWI_TABLE varchar(256) NOT NULL,
  NWI_NEXT bigint NOT NULL
);

CREATE UNIQUE INDEX NEXT_WRITE_ID_IDX ON NEXT_WRITE_ID (NWI_DATABASE, NWI_TABLE);

RENAME COLUMN COMPACTION_QUEUE.CQ_HIGHEST_TXN_ID TO CQ_HIGHEST_WRITE_ID;

RENAME COLUMN COMPLETED_COMPACTIONS.CC_HIGHEST_TXN_ID TO CC_HIGHEST_WRITE_ID;

-- Modify txn_components/completed_txn_components tables to add write id.
ALTER TABLE TXN_COMPONENTS ADD TC_WRITEID bigint;
ALTER TABLE COMPLETED_TXN_COMPONENTS ADD CTC_WRITEID bigint;

-- HIVE-18726
-- add a new column to support default value for DEFAULT constraint
ALTER TABLE "APP"."KEY_CONSTRAINTS" ADD COLUMN "DEFAULT_VALUE" VARCHAR(400);

ALTER TABLE "APP"."HIVE_LOCKS" ALTER COLUMN "HL_TXNID" NOT NULL;

-- This needs to be the last thing done.  Insert any changes above this line.
UPDATE "APP".VERSION SET SCHEMA_VERSION='3.0.0', VERSION_COMMENT='Hive release version 3.0.0' where VER_ID=1;