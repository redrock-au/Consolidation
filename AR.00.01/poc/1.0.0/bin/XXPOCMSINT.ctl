--$Header: svn://d02584/consolrepos/branches/AR.00.01/poc/1.0.0/bin/XXPOCMSINT.ctl 1492 2017-07-05 07:01:42Z svnuser $
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
