rem $Header: svn://d02584/consolrepos/branches/AP.02.03/arc/1.0.0/install/sql/XXAR_RECEIPTS_RECORD_ID_S.sql 1442 2017-07-04 22:35:02Z svnuser $
CREATE SEQUENCE FMSMGR.XXAR_RECEIPTS_RECORD_ID_S START WITH 1 INCREMENT BY 1 NOCACHE
/
CREATE OR REPLACE SYNONYM APPS.XXAR_RECEIPTS_RECORD_ID_S FOR FMSMGR.XXAR_RECEIPTS_RECORD_ID_S
/
