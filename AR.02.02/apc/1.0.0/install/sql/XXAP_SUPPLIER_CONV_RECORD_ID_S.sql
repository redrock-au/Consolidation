rem $Header: svn://d02584/consolrepos/branches/AR.02.02/apc/1.0.0/install/sql/XXAP_SUPPLIER_CONV_RECORD_ID_S.sql 1849 2017-07-18 02:20:57Z svnuser $
CREATE SEQUENCE FMSMGR.XXAP_SUPPLIER_CONV_RECORD_ID_S START WITH 1 INCREMENT BY 1 NOCACHE
/
CREATE OR REPLACE SYNONYM APPS.XXAP_SUPPLIER_CONV_RECORD_ID_S FOR FMSMGR.XXAP_SUPPLIER_CONV_RECORD_ID_S
/