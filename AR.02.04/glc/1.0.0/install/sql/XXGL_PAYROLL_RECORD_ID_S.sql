rem $Header: svn://d02584/consolrepos/branches/AR.02.04/glc/1.0.0/install/sql/XXGL_PAYROLL_RECORD_ID_S.sql 1035 2017-06-21 01:33:46Z svnuser $
CREATE SEQUENCE FMSMGR.XXGL_PAYROLL_RECORD_ID_S START WITH 1 INCREMENT BY 1 NOCACHE
/
CREATE OR REPLACE SYNONYM APPS.XXGL_PAYROLL_RECORD_ID_S FOR FMSMGR.XXGL_PAYROLL_RECORD_ID_S
/