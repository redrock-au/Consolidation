rem $Header: svn://d02584/consolrepos/branches/AR.09.03/arc/1.0.0/install/sql/XXAR_CUST_CONV_RECCORD_ID_S_DDL.sql 2689 2017-10-05 04:37:59Z svnuser $ 

CREATE SEQUENCE  FMSMGR.XXAR_CUST_CONV_RECCORD_ID_S  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 2056 NOCACHE  NOORDER  NOCYCLE ;

CREATE OR REPLACE SYNONYM APPS.XXAR_CUST_CONV_RECCORD_ID_S FOR FMSMGR.XXAR_CUST_CONV_RECCORD_ID_S;

