rem $Header: svn://d02584/consolrepos/branches/AP.02.03/glc/1.0.0/install/sql/XXGL_PAYROLL_TRAILER_STG.sql 1027 2017-06-21 01:18:32Z svnuser $
CREATE TABLE FMSMGR.XXGL_PAYROLL_TRAILER_STG
(
    RECORD_ID               NUMBER NOT NULL PRIMARY KEY,
    RECORD_COUNT            NUMBER NOT NULL,
    RECORD_TOTAL_AMOUNT     NUMBER NOT NULL,
    RUN_ID                  NUMBER,
    RUN_PHASE_ID            NUMBER,
    STATUS                  VARCHAR2(25),
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE
);

CREATE OR REPLACE SYNONYM APPS.XXGL_PAYROLL_TRAILER_STG FOR FMSMGR.XXGL_PAYROLL_TRAILER_STG; 
