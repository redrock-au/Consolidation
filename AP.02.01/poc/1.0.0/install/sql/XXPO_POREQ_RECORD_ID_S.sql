rem $Header: svn://d02584/consolrepos/branches/AP.02.01/poc/1.0.0/install/sql/XXPO_POREQ_RECORD_ID_S.sql 2126 2017-08-16 04:27:46Z svnuser $
CREATE SEQUENCE FMSMGR.XXPO_POREQ_RECORD_ID_S START WITH 1 INCREMENT BY 1 NOCACHE
/
CREATE OR REPLACE SYNONYM APPS.XXPO_POREQ_RECORD_ID_S FOR FMSMGR.XXPO_POREQ_RECORD_ID_S
/
