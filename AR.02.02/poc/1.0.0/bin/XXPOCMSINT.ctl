--$Header: svn://d02584/consolrepos/branches/AR.02.02/poc/1.0.0/bin/XXPOCMSINT.ctl 1201 2017-06-23 05:20:06Z svnuser $
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
