--$Header: svn://d02584/consolrepos/branches/AP.02.03/glc/1.0.0/bin/XXGLCOAPJT.ctl 1578 2017-07-07 02:00:48Z svnuser $

LOAD DATA
REPLACE
INTO TABLE FMSMGR.XXGL_COA_PROJECT_MAP_STG
FIELDS TERMINATED BY "," OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
   DBI_PROJECT,
   DEDJTR_PROJECT,
   APPLY,
   RECORD_ID "FMSMGR.XXGL_COA_PRJMAP_RECID_S.NEXTVAL",
   STATUS CONSTANT 'NEW',
   CREATED_BY,
   CREATION_DATE SYSDATE,
   LAST_UPDATED_BY,
   LAST_UPDATE_DATE SYSDATE
)