/*$Header: svn://d02584/consolrepos/branches/AR.00.02/arc/1.0.0/install/sql/XXAR_CUSTOMER_INT_RECORD_ID_S_DDL.sql 1496 2017-07-05 07:15:13Z svnuser $*/

CREATE SEQUENCE  FMSMGR.XXAR_CUSTOMER_INT_RECORD_ID_S  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 927 NOCACHE  NOORDER  NOCYCLE ;

CREATE OR REPLACE SYNONYM APPS.XXAR_CUSTOMER_INT_RECORD_ID_S FOR FMSMGR.XXAR_CUSTOMER_INT_RECORD_ID_S;