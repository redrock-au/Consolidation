rem $Header: svn://d02584/consolrepos/branches/AP.02.01/arc/1.0.0/install/sql/XXAR_RECEIPTS_RECORD_ID_S.sql 1427 2017-07-04 07:19:13Z svnuser $
CREATE SEQUENCE FMSMGR.XXAR_RECEIPTS_RECORD_ID_S START WITH 1 INCREMENT BY 1 NOCACHE
/
CREATE OR REPLACE SYNONYM APPS.XXAR_RECEIPTS_RECORD_ID_S FOR FMSMGR.XXAR_RECEIPTS_RECORD_ID_S
/