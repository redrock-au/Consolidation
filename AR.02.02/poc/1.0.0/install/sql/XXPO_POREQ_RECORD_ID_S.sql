rem $Header: svn://d02584/consolrepos/branches/AR.02.02/poc/1.0.0/install/sql/XXPO_POREQ_RECORD_ID_S.sql 2122 2017-08-16 01:17:46Z svnuser $
CREATE SEQUENCE FMSMGR.XXPO_POREQ_RECORD_ID_S START WITH 1 INCREMENT BY 1 NOCACHE
/
CREATE OR REPLACE SYNONYM APPS.XXPO_POREQ_RECORD_ID_S FOR FMSMGR.XXPO_POREQ_RECORD_ID_S
/
