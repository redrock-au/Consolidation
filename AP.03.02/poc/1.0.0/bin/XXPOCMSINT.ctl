--$Header: svn://d02584/consolrepos/branches/AP.03.02/poc/1.0.0/bin/XXPOCMSINT.ctl 1472 2017-07-05 00:35:27Z svnuser $
LOAD DATA
APPEND
INTO TABLE FMSMGR.XXPO_CONTRACTS_STG FIELDS TERMINATED BY "|" OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
   CONTRACT_NUMBER,
   DESCRIPTION,
   START_DATE,
   END_DATE
)
