--$Header: svn://d02584/consolrepos/branches/AP.02.01/poc/1.0.0/bin/XXPOCMSINT.ctl 1427 2017-07-04 07:19:13Z svnuser $
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
