--$Header: svn://d02584/consolrepos/branches/AP.02.02/poc/1.0.0/bin/XXPOCMSINT.ctl 1607 2017-07-10 01:20:42Z svnuser $
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