--$Header: svn://d02584/consolrepos/branches/AR.03.02/glc/1.0.0/bin/XXGLCOAENTI.ctl 1830 2017-07-18 00:26:50Z svnuser $

LOAD DATA
REPLACE
INTO TABLE FMSMGR.XXGL_COA_ENTITY_MAP_STG
FIELDS TERMINATED BY "," OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
   DBI_ENTITY,
   DEDJTR_ENTITY,
   APPLY,
   RECORD_ID "FMSMGR.XXGL_COA_ENTITYMAP_RECID_S.NEXTVAL", 
   STATUS CONSTANT 'NEW',
   CREATED_BY,
   CREATION_DATE SYSDATE,
   LAST_UPDATED_BY,
   LAST_UPDATE_DATE SYSDATE
)