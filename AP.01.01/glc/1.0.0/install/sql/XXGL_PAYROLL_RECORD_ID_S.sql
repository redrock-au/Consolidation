rem $Header: svn://d02584/consolrepos/branches/AP.01.01/glc/1.0.0/install/sql/XXGL_PAYROLL_RECORD_ID_S.sql 1074 2017-06-21 05:34:42Z svnuser $
CREATE SEQUENCE FMSMGR.XXGL_PAYROLL_RECORD_ID_S START WITH 1 INCREMENT BY 1 NOCACHE
/
CREATE OR REPLACE SYNONYM APPS.XXGL_PAYROLL_RECORD_ID_S FOR FMSMGR.XXGL_PAYROLL_RECORD_ID_S
/
