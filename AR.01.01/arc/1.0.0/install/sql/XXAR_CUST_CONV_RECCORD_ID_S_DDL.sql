rem $Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/sql/XXAR_CUST_CONV_RECCORD_ID_S_DDL.sql 2443 2017-09-06 00:29:43Z svnuser $ 

CREATE SEQUENCE  FMSMGR.XXAR_CUST_CONV_RECCORD_ID_S  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 2056 NOCACHE  NOORDER  NOCYCLE ;

CREATE OR REPLACE SYNONYM APPS.XXAR_CUST_CONV_RECCORD_ID_S FOR FMSMGR.XXAR_CUST_CONV_RECCORD_ID_S;

