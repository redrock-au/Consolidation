rem $Header: svn://d02584/consolrepos/branches/AR.01.01/apc/1.0.0/install/sql/XXAP_SUPPLIER_CONV_RECORD_ID_S.sql 1856 2017-07-18 03:25:10Z svnuser $
CREATE SEQUENCE FMSMGR.XXAP_SUPPLIER_CONV_RECORD_ID_S START WITH 1 INCREMENT BY 1 NOCACHE
/
CREATE OR REPLACE SYNONYM APPS.XXAP_SUPPLIER_CONV_RECORD_ID_S FOR FMSMGR.XXAP_SUPPLIER_CONV_RECORD_ID_S
/
