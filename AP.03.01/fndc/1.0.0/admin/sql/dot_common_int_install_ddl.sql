/****************************************************************************
**
**  $Header: svn://d02584/consolrepos/branches/AP.03.01/fndc/1.0.0/admin/sql/dot_common_int_install_ddl.sql 939 2017-06-19 23:06:48Z svnuser $
**
**  Purpose : Install custom objects for Common Interface - Run as DOT
**
**  Author: UXC Red Rock Consulting
**
**  History: Refer to Source Control
**
****************************************************************************/

PROMPT create table '"DOT_INT_DATA_SOURCES"'
CREATE TABLE FMSMGR.DOT_INT_DATA_SOURCES
(
"SRC_CODE" VARCHAR2 (10) NOT NULL,
"SRC_NAME" VARCHAR2 (240),
"CREATED_BY" NUMBER (15) NOT NULL,
"CREATION_DATE" DATE NOT NULL,
"LAST_UPDATED_BY" NUMBER (15) NOT NULL,
"LAST_UPDATE_DATE" DATE NOT NULL,
"LAST_UPDATE_LOGIN" NUMBER (15),
"REQUEST_ID" NUMBER (15)
)
;

PROMPT create table '"DOT_INT_INTERFACES"'
CREATE TABLE FMSMGR.DOT_INT_INTERFACES
(
"INT_ID" NUMBER NOT NULL,
"INT_CODE" VARCHAR2 (25),
"INT_NAME" VARCHAR2 (240),
"EBS_IN_OUT" VARCHAR2 (3),
"APPL_SHORT_NAME" VARCHAR2 (30),
"ENABLED_FLAG" VARCHAR2 (1) DEFAULT 'Y' NOT NULL,
"CREATION_DATE" DATE NOT NULL,
"CREATED_BY" NUMBER (15) NOT NULL,
"LAST_UPDATED_BY" NUMBER (15) NOT NULL,
"LAST_UPDATE_DATE" DATE NOT NULL,
"LAST_UPDATE_LOGIN" NUMBER (15),
"REQUEST_ID" NUMBER (15)
)
;

PROMPT create table '"DOT_INT_RUNS"'
CREATE TABLE FMSMGR.DOT_INT_RUNS
(
"RUN_ID" NUMBER NOT NULL,
"INT_ID" NUMBER NOT NULL,
"SRC_REC_COUNT" NUMBER,
"SRC_HASH_TOTAL" NUMBER,
"SRC_BATCH_NAME" VARCHAR2 (150),
"CREATED_BY" NUMBER (15) NOT NULL,
"CREATION_DATE" DATE NOT NULL,
"LAST_UPDATED_BY" NUMBER (15),
"LAST_UPDATE_DATE" DATE NOT NULL,
"LAST_UPDATE_LOGIN" NUMBER (15),
"REQUEST_ID" NUMBER (15)
)
;

PROMPT create table '"DOT_INT_RUN_PHASE_ERRORS"'
CREATE TABLE FMSMGR.DOT_INT_RUN_PHASE_ERRORS
(
"ERROR_ID" NUMBER (15) NOT NULL,
"RUN_ID" NUMBER (15),
"RUN_PHASE_ID" NUMBER (15),
"RECORD_ID" NUMBER,
"MSG_CODE" VARCHAR2 (15),
"ERROR_TEXT" VARCHAR (2000),
"ERROR_TOKEN_VAL1" VARCHAR2 (250),
"ERROR_TOKEN_VAL2" VARCHAR2 (250),
"ERROR_TOKEN_VAL3" VARCHAR2 (250),
"ERROR_TOKEN_VAL4" VARCHAR2 (250),
"ERROR_TOKEN_VAL5" VARCHAR2 (250),
"INT_TABLE_KEY_VAL1" VARCHAR2 (250),
"INT_TABLE_KEY_VAL2" VARCHAR2 (250),
"INT_TABLE_KEY_VAL3" VARCHAR2 (250),
"CREATED_BY" NUMBER (15) NOT NULL,
"CREATION_DATE" DATE NOT NULL,
"LAST_UPDATED_BY" NUMBER (15),
"LAST_UPDATE_DATE" DATE,
"LAST_UPDATE_LOGIN" NUMBER (15),
"REQUEST_ID" NUMBER (15)
)
;

PROMPT create table '"DOT_INT_RUN_PHASES"'
CREATE TABLE FMSMGR.DOT_INT_RUN_PHASES
(
"RUN_PHASE_ID" NUMBER (15) NOT NULL,
"RUN_ID" NUMBER NOT NULL,
"PHASE_CODE" VARCHAR2 (10),
"PHASE_MODE" VARCHAR2 (25),
"START_DATE" DATE,
"END_DATE" DATE,
"SRC_CODE" VARCHAR2 (10),
"REC_COUNT" NUMBER,
"HASH_TOTAL" NUMBER,
"BATCH_NAME" VARCHAR2 (250),
"STATUS" VARCHAR2 (15),
"ERROR_COUNT" NUMBER,
"SUCCESS_COUNT" NUMBER,
"INT_TABLE_NAME" VARCHAR2 (100),
"INT_TABLE_KEY_COL1" VARCHAR2 (25),
"INT_TABLE_KEY_COL_DESC1" VARCHAR2 (50),
"INT_TABLE_KEY_COL2" VARCHAR2 (25),
"INT_TABLE_KEY_COL_DESC2" VARCHAR2 (50),
"INT_TABLE_KEY_COL3" VARCHAR2 (25),
"INT_TABLE_KEY_COL_DESC3" VARCHAR2 (50),
"CREATION_DATE" DATE,
"CREATED_BY" NUMBER,
"LAST_UPDATE_DATE" DATE,
"LAST_UPDATED_BY" NUMBER,
"LAST_UPDATE_LOGIN" NUMBER (15),
"REQUEST_ID" NUMBER
)
;

PROMPT create table '"DOT_INT_MESSAGES"'
CREATE TABLE FMSMGR.DOT_INT_MESSAGES
(
"MSG_CODE" VARCHAR2 (15) NOT NULL,
"MSG_TEXT" VARCHAR2 (2000),
"CREATED_BY" NUMBER (15) NOT NULL,
"CREATION_DATE" DATE NOT NULL,
"LAST_UPDATED_BY" NUMBER (15) NOT NULL,
"LAST_UPDATE_DATE" DATE NOT NULL,
"LAST_UPDATE_LOGIN" NUMBER (15),
"REQUEST_ID" NUMBER (15)
)
;

PROMPT create primary key constraint on '"DOT_INT_DATA_SOURCES"'
ALTER TABLE FMSMGR.DOT_INT_DATA_SOURCES
ADD CONSTRAINT "DOT_INT_DATA_SOURCES_PK1" PRIMARY KEY
(
"SRC_CODE"
)
 ENABLE
;

PROMPT create primary key constraint on '"DOT_INT_INTERFACES"'
ALTER TABLE FMSMGR.DOT_INT_INTERFACES
ADD CONSTRAINT "DOT_CNV_CONVERSIONS_PK1" PRIMARY KEY
(
"INT_ID"
)
 ENABLE
;

PROMPT create unique key constraint on '"DOT_INT_INTERFACES"'
ALTER TABLE FMSMGR.DOT_INT_INTERFACES
ADD CONSTRAINT "DOT_INT_INTERFACES_UK1" UNIQUE
(
"INT_CODE"
)
 ENABLE
;

PROMPT create primary key constraint on '"DOT_INT_RUNS"'
ALTER TABLE FMSMGR.DOT_INT_RUNS
ADD CONSTRAINT "DOT_CNV_RUNS_PK1" PRIMARY KEY
(
"RUN_ID"
)
 ENABLE
;

PROMPT create primary key constraint on '"DOT_INT_RUN_PHASE_ERRORS"'
ALTER TABLE FMSMGR.DOT_INT_RUN_PHASE_ERRORS
ADD CONSTRAINT "DOT_INT_RUN_ERRORS_PK1" PRIMARY KEY
(
"ERROR_ID"
)
 ENABLE
;

PROMPT create primary key constraint on '"DOT_INT_RUN_PHASES"'
ALTER TABLE FMSMGR.DOT_INT_RUN_PHASES
ADD CONSTRAINT "DOT_INT_RUN_PHASES_PK1" PRIMARY KEY
(
"RUN_PHASE_ID"
)
 ENABLE
;

PROMPT create primary key constraint on '"DOT_INT_MESSAGES"'
ALTER TABLE FMSMGR.DOT_INT_MESSAGES
ADD CONSTRAINT "DOT_INT_MESSAGES_PK1" PRIMARY KEY
(
"MSG_CODE"
)
 ENABLE
;

COMMENT ON COLUMN FMSMGR.DOT_INT_DATA_SOURCES.SRC_CODE IS 'Data source short code'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_DATA_SOURCES.SRC_NAME IS 'Data source description'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_DATA_SOURCES.CREATED_BY IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_DATA_SOURCES.CREATION_DATE IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_DATA_SOURCES.LAST_UPDATED_BY IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_DATA_SOURCES.LAST_UPDATE_DATE IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_DATA_SOURCES.LAST_UPDATE_LOGIN IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_DATA_SOURCES.REQUEST_ID IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_INTERFACES.INT_ID IS 'Primary key for table'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_INTERFACES.INT_CODE IS 'Interface short code.'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_INTERFACES.INT_NAME IS 'Description of interface'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_INTERFACES.EBS_IN_OUT IS 'IN = Inbound Interface from R12 OUT = Outbound Interface from R12'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_INTERFACES.APPL_SHORT_NAME IS 'eBS Application Short Code'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_INTERFACES.ENABLED_FLAG IS 'Interface enabled flag'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_INTERFACES.CREATION_DATE IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_INTERFACES.CREATED_BY IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_INTERFACES.LAST_UPDATED_BY IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_INTERFACES.LAST_UPDATE_DATE IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_INTERFACES.LAST_UPDATE_LOGIN IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_INTERFACES.REQUEST_ID IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUNS.RUN_ID IS 'Primary Key'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUNS.INT_ID IS 'Foreign key to DOT_INT_INTERFACES'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUNS.SRC_REC_COUNT IS 'Data batch record count'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUNS.SRC_HASH_TOTAL IS 'Data batch hash total'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUNS.SRC_BATCH_NAME IS 'Data batch name'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUNS.CREATED_BY IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUNS.CREATION_DATE IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUNS.LAST_UPDATED_BY IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUNS.LAST_UPDATE_DATE IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUNS.LAST_UPDATE_LOGIN IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUNS.REQUEST_ID IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.ERROR_ID IS 'Primary Key'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.RUN_ID IS 'Foreign key to DOT_INT_RUNS'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.RUN_PHASE_ID IS 'Foreign key to DOT_INT_RUN_PHASES'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.RECORD_ID IS 'Record ID from interface table with error as detailed in DOT_INT_RUN_PHASES.TABLE_NAME'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.MSG_CODE IS 'Foreign key to DOT_INT_MESSAGES.'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.ERROR_TEXT IS 'For unexpected error messages for example from APIs.'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.ERROR_TOKEN_VAL1 IS 'Error message token value 1'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.ERROR_TOKEN_VAL2 IS 'Error message token value 2'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.ERROR_TOKEN_VAL3 IS 'Error message token value 3'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.ERROR_TOKEN_VAL4 IS 'Error message token value 4'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.ERROR_TOKEN_VAL5 IS 'Error message token value 5'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.INT_TABLE_KEY_VAL1 IS 'Interface table key value 1'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.INT_TABLE_KEY_VAL2 IS 'Interface table key value 2'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.INT_TABLE_KEY_VAL3 IS 'Interface table key value 3'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.CREATED_BY IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.CREATION_DATE IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.LAST_UPDATED_BY IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.LAST_UPDATE_DATE IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.LAST_UPDATE_LOGIN IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASE_ERRORS.REQUEST_ID IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.RUN_PHASE_ID IS 'Primary Key'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.RUN_ID IS 'Foreign Key to DOT_INT_RUNS'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.PHASE_CODE IS 'Run Phase Code STAGE,TRANSFORM,LOAD,EXTRACT'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.PHASE_MODE IS 'Phase Run Mode for Transform Stage: "VALIDATE" "VALIDATE_TRANSFER"'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.START_DATE IS 'Run phase start date and time'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.END_DATE IS 'Run phase end date and time'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.SRC_CODE IS 'Foreign key to DOT_INT_DATA_SOURCES'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.REC_COUNT IS 'Total data records processed  in phase'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.HASH_TOTAL IS 'Hash total for data records processed in phase'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.BATCH_NAME IS 'File name or data batch name'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.STATUS IS 'Phase status = "ERROR","SUCCESS"'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.ERROR_COUNT IS 'Number of record in error for the phase'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.SUCCESS_COUNT IS 'Number of records successfuly processed for the phase'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.INT_TABLE_NAME IS 'Interface table name upon which phase has been run.'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.INT_TABLE_KEY_COL1 IS 'Column name of table on interface table that is to be used as a key for error reporting.'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.INT_TABLE_KEY_COL_DESC1 IS 'Description of column name of table on interface table that is to be used as a key for error reporting.'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.INT_TABLE_KEY_COL2 IS 'Column name of table on interface table that is to be used as a key for error reporting.'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.INT_TABLE_KEY_COL_DESC2 IS 'Description of column name of table on interface table that is to be used as a key for error reporting.'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.INT_TABLE_KEY_COL3 IS 'Column name of table on interface table that is to be used as a key for error reporting.'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.INT_TABLE_KEY_COL_DESC3 IS 'Description of column name of table on interface table that is to be used as a key for error reporting.'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.CREATION_DATE IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.CREATED_BY IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.LAST_UPDATE_DATE IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.LAST_UPDATED_BY IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.LAST_UPDATE_LOGIN IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_RUN_PHASES.REQUEST_ID IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_MESSAGES.MSG_CODE IS 'Primary key'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_MESSAGES.MSG_TEXT IS 'Message description'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_MESSAGES.CREATED_BY IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_MESSAGES.CREATION_DATE IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_MESSAGES.LAST_UPDATED_BY IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_MESSAGES.LAST_UPDATE_DATE IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_MESSAGES.LAST_UPDATE_LOGIN IS 'Standard WHO column'
;
COMMENT ON COLUMN FMSMGR.DOT_INT_MESSAGES.REQUEST_ID IS 'Standard WHO column'
;
COMMENT ON TABLE FMSMGR.DOT_INT_DATA_SOURCES IS 'To store data sources / source systems.'
;
COMMENT ON TABLE FMSMGR.DOT_INT_INTERFACES IS 'Interface definition information.  Each interface will have a separate record.'
;
COMMENT ON TABLE FMSMGR.DOT_INT_RUNS IS 'To store interface run information.'
;
COMMENT ON TABLE FMSMGR.DOT_INT_RUN_PHASE_ERRORS IS 'To store individual errors raised for an interface run phase.'
;
COMMENT ON TABLE FMSMGR.DOT_INT_RUN_PHASES IS 'Interface Run Phases table'
;
COMMENT ON TABLE FMSMGR.DOT_INT_MESSAGES IS 'Holds interface error messages.'
;

PROMPT create foreign key constraint on '"DOT_INT_RUNS"'
ALTER TABLE FMSMGR.DOT_INT_RUNS
ADD CONSTRAINT "DOT_INT_RUNS_FK1" FOREIGN KEY
(
"INT_ID"
)
REFERENCES "DOT_INT_INTERFACES"
(
"INT_ID"
) ENABLE
;
PROMPT create foreign key constraint on '"DOT_INT_RUN_PHASE_ERRORS"'
ALTER TABLE FMSMGR.DOT_INT_RUN_PHASE_ERRORS
ADD CONSTRAINT "DOT_INT_RUN_ERRORS_FK1" FOREIGN KEY
(
"RUN_PHASE_ID"
)
REFERENCES "DOT_INT_RUN_PHASES"
(
"RUN_PHASE_ID"
) ENABLE
;
PROMPT create foreign key constraint on '"DOT_INT_RUN_PHASE_ERRORS"'
ALTER TABLE FMSMGR.DOT_INT_RUN_PHASE_ERRORS
ADD CONSTRAINT "DOT_INT_RUN_ERRORS_FK2" FOREIGN KEY
(
"MSG_CODE"
)
REFERENCES "DOT_INT_MESSAGES"
(
"MSG_CODE"
) ENABLE
;
PROMPT create foreign key constraint on '"DOT_INT_RUN_PHASES"'
ALTER TABLE FMSMGR.DOT_INT_RUN_PHASES
ADD CONSTRAINT "DOT_INT_RUN_PHASES_FK1" FOREIGN KEY
(
"RUN_ID"
)
REFERENCES "DOT_INT_RUNS"
(
"RUN_ID"
) ENABLE
;
PROMPT create foreign key constraint on '"DOT_INT_RUN_PHASES"'
ALTER TABLE FMSMGR.DOT_INT_RUN_PHASES
ADD CONSTRAINT "DOT_INT_RUN_PHASES_XXC_FK1" FOREIGN KEY
(
"SRC_CODE"
)
REFERENCES "DOT_INT_DATA_SOURCES"
(
"SRC_CODE"
) ENABLE
;
PROMPT create check constraint on '"DOT_INT_INTERFACES"'
ALTER TABLE FMSMGR.DOT_INT_INTERFACES
ADD CONSTRAINT "DOT_INT_INTERFACES_CHK1" CHECK
(EBS_IN_OUT IN ('IN','OUT'))
 ENABLE
;
PROMPT create check constraint on '"DOT_INT_INTERFACES"'
ALTER TABLE FMSMGR.DOT_INT_INTERFACES
ADD CONSTRAINT "DOT_INT_INTERFACES_CHK2" CHECK
(ENABLED_FLAG IN ('Y','N'))
 ENABLE
;
PROMPT create check constraint on '"DOT_INT_RUN_PHASES"'
ALTER TABLE FMSMGR.DOT_INT_RUN_PHASES
ADD CONSTRAINT "DOT_INT_RUN_PHASES_CHK1" CHECK
(PHASE_MODE IN('VALIDATE','VALIDATE_TRANSFER','TRANSFER'))
 ENABLE
;
PROMPT create check constraint on '"DOT_INT_RUN_PHASES"'
ALTER TABLE FMSMGR.DOT_INT_RUN_PHASES
ADD CONSTRAINT "DOT_INT_RUN_PHASES_CHK2" CHECK
(PHASE_CODE IN('STAGE','TRANSFORM','LOAD','EXTRACT'))
 ENABLE
;
PROMPT create check constraint on '"DOT_INT_RUN_PHASES"'
ALTER TABLE FMSMGR.DOT_INT_RUN_PHASES
ADD CONSTRAINT "DOT_INT_RUN_PHASES_CHK3" CHECK
(STATUS IN('SUCCESS','ERROR','WARNING'))
 ENABLE
;
