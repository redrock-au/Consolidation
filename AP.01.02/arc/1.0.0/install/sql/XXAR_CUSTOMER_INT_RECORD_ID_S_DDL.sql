/*$Header: svn://d02584/consolrepos/branches/AP.01.02/arc/1.0.0/install/sql/XXAR_CUSTOMER_INT_RECORD_ID_S_DDL.sql 1081 2017-06-21 05:49:47Z svnuser $*/

CREATE SEQUENCE  FMSMGR.XXAR_CUSTOMER_INT_RECORD_ID_S  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 927 NOCACHE  NOORDER  NOCYCLE ;

CREATE OR REPLACE SYNONYM APPS.XXAR_CUSTOMER_INT_RECORD_ID_S FOR FMSMGR.XXAR_CUSTOMER_INT_RECORD_ID_S;