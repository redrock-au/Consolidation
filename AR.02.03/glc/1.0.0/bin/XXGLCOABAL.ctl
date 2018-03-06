--$Header :$
OPTIONS (SKIP=1) 
LOAD DATA
REPLACE
INTO TABLE FMSMGR.XXGL_COA_DSDBI_BALANCES_STG 
FIELDS TERMINATED BY "," OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
   NAME,
   ACTUAL_FLAG,
   PERIOD_NAME,
   CODE_COMBINATION_ID, 
   OLD_SEGMENT1,
   OLD_SEGMENT2,
   OLD_SEGMENT3,
   OLD_SEGMENT4,
   OLD_SEGMENT5,
   OPEN_BALANCE,
   DEBIT,
   CREDIT,
   NET_MOVEMENT,
   CLOSE_BALANCE,
   CLOSE_BALANCE_DR,
   CLOSE_BALANCE_CR,
   CURRENCY_CODE, 
   CREATED_BY , 
   CREATION_DATE , 
   LAST_UPDATED_BY , 
   LAST_UPDATE_DATE , 
   RECORD_ID "FMSMGR.XXGL_COA_DSDBI_BAL_RECID_S.NEXTVAL",
   STATUS CONSTANT 'NEW', 
   RUN_ID , 
   RUN_PHASE_ID 
 )