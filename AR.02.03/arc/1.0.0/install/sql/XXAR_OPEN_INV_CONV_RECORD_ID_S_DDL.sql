rem $Header: svn://d02584/consolrepos/branches/AR.02.03/arc/1.0.0/install/sql/XXAR_OPEN_INV_CONV_RECORD_ID_S_DDL.sql 2395 2017-08-31 06:23:22Z svnuser $

CREATE SEQUENCE  FMSMGR.XXAR_OPEN_INV_CONV_RECORD_ID_S  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1083 NOCACHE  NOORDER  NOCYCLE ;

CREATE OR REPLACE SYNONYM APPS.XXAR_OPEN_INV_CONV_RECORD_ID_S FOR FMSMGR.XXAR_OPEN_INV_CONV_RECORD_ID_S;