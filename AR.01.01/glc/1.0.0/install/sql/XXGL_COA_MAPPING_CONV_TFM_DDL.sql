/* $Header: svn://d02584/consolrepos/branches/AR.01.01/glc/1.0.0/install/sql/XXGL_COA_MAPPING_CONV_TFM_DDL.sql 2318 2017-08-28 04:51:18Z svnuser $ */
  
CREATE TABLE FMSMGR.XXGL_COA_MAPPING_CONV_TFM 
(
   RUN_ID               NUMBER,
   RUN_PHASE_ID         NUMBER,
   RECORD_ID            NUMBER, 
   SOURCE_CCID          VARCHAR2(150), 
   SOURCE_ENTITY        VARCHAR2(150), 
   SOURCE_SOURCE        VARCHAR2(150), 
   SOURCE_COST_CENTRE   VARCHAR2(150), 
   SOURCE_ACCOUNT       VARCHAR2(150), 
   SOURCE_PROJECT       VARCHAR2(150), 
   TARGET_CCID          VARCHAR2(150), 
   TARGET_ORGANISATION  VARCHAR2(150), 
   TARGET_ACCOUNT       VARCHAR2(150), 
   TARGET_COST_CENTRE   VARCHAR2(150), 
   TARGET_AUTHORITY     VARCHAR2(150), 
   TARGET_PROJECT       VARCHAR2(150), 
   TARGET_OUTPUT        VARCHAR2(150), 
   TARGET_IDENTIFIER    VARCHAR2(150), 
   STATUS               VARCHAR2(60), 
   CREATED_BY           NUMBER, 
   CREATION_DATE        DATE, 
   LAST_UPDATED_BY      NUMBER, 
   LAST_UPDATE_DATE     DATE, 
   ERROR_MESSAGE        VARCHAR2(2000)
);
   
CREATE SYNONYM XXGL_COA_MAPPING_CONV_TFM FOR FMSMGR.XXGL_COA_MAPPING_CONV_TFM;

CREATE INDEX FMSMGR.XXGL_COA_MAPPING_CONV_TFM_N1 ON FMSMGR.XXGL_COA_MAPPING_CONV_TFM
(SOURCE_ENTITY, SOURCE_SOURCE, SOURCE_COST_CENTRE, SOURCE_ACCOUNT, SOURCE_PROJECT);

CREATE INDEX FMSMGR.XXGL_COA_MAPPING_CONV_TFM_N2 ON FMSMGR.XXGL_COA_MAPPING_CONV_TFM
(TARGET_ORGANISATION, TARGET_ACCOUNT, TARGET_COST_CENTRE, TARGET_AUTHORITY, TARGET_PROJECT, TARGET_OUTPUT, TARGET_IDENTIFIER);


