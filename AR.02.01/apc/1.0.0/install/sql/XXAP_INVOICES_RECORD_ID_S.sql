rem $Header: svn://d02584/consolrepos/branches/AR.02.01/apc/1.0.0/install/sql/XXAP_INVOICES_RECORD_ID_S.sql 1005 2017-06-20 23:55:31Z svnuser $
CREATE SEQUENCE FMSMGR.XXAP_INVOICES_RECORD_ID_S START WITH 1 INCREMENT BY 1 NOCACHE
/
CREATE OR REPLACE SYNONYM APPS.XXAP_INVOICES_RECORD_ID_S FOR FMSMGR.XXAP_INVOICES_RECORD_ID_S
/
