rem $Header: svn://d02584/consolrepos/branches/AR.00.01/apc/1.0.0/install/sql/XXAP_INVOICES_RECORD_ID_S.sql 259 2017-05-03 01:49:40Z applmgr $
CREATE SEQUENCE FMSMGR.XXAP_INVOICES_RECORD_ID_S START WITH 1 INCREMENT BY 1 NOCACHE
/
CREATE OR REPLACE SYNONYM APPS.XXAP_INVOICES_RECORD_ID_S FOR FMSMGR.XXAP_INVOICES_RECORD_ID_S
/
