--$Header: svn://d02584/consolrepos/branches/AR.02.03/poc/1.0.0/bin/XXPOCMSINT.ctl 1100 2017-06-21 06:55:27Z svnuser $
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
