rem $Header: svn://d02584/consolrepos/branches/AP.01.01/arc/1.0.0/install/sql/XXAR_OPEN_INV_CONV_RECORD_ID_S_DDL.sql 2674 2017-10-05 01:02:16Z svnuser $

CREATE SEQUENCE  FMSMGR.XXAR_OPEN_INV_CONV_RECORD_ID_S  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1083 NOCACHE  NOORDER  NOCYCLE ;

CREATE OR REPLACE SYNONYM APPS.XXAR_OPEN_INV_CONV_RECORD_ID_S FOR FMSMGR.XXAR_OPEN_INV_CONV_RECORD_ID_S;