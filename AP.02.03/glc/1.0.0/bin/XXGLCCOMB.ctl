--$Header: svn://d02584/consolrepos/branches/AP.02.03/glc/1.0.0/bin/XXGLCCOMB.ctl 1578 2017-07-07 02:00:48Z svnuser $

LOAD DATA
REPLACE
INTO TABLE FMSMGR.XXGL_COA_DSDBI_CODE_COMB_STG 
FIELDS TERMINATED BY "," OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
   SEGMENT1,
   SEGMENT2,
   SEGMENT3,
   SEGMENT4,
   SEGMENT5,
   CODE_COMBINATION_ID,
   ACCOUNT_TYPE,
   CREATED_BY,
   CREATION_DATE,
   LAST_UPDATED_BY,
   LAST_UPDATE_DATE,
   RECORD_ID "FMSMGR.XXGL_COA_DSDBI_CODE_COMB_STG_S.NEXTVAL",
   STATUS CONSTANT 'NEW'
)