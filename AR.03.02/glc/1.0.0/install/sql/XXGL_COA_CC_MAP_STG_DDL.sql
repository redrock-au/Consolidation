  --$Header :$
  
  CREATE TABLE FMSMGR.XXGL_COA_CC_MAP_STG 
   (	RECORD_ID NUMBER, 
	DBI_CC VARCHAR2(150), 
	DEDJTR_CC VARCHAR2(150), 
	APPLY VARCHAR2(1), 
	STATUS VARCHAR2(60), 
	CREATED_BY NUMBER, 
	CREATION_DATE DATE, 
	LAST_UPDATED_BY NUMBER, 
	LAST_UPDATE_DATE DATE, 
	RUN_ID NUMBER, 
	RUN_PHASE_ID NUMBER
   ) ;
   
   CREATE SYNONYM XXGL_COA_CC_MAP_STG FOR fmsmgr.XXGL_COA_CC_MAP_STG;