--$Header :$
OPTIONS (SKIP=1)
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