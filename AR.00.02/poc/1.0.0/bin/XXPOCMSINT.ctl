--$Header: svn://d02584/consolrepos/branches/AR.00.02/poc/1.0.0/bin/XXPOCMSINT.ctl 1496 2017-07-05 07:15:13Z svnuser $
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
