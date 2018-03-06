rem $Header: svn://d02584/consolrepos/branches/AP.00.02/glc/1.0.0/install/sql/XXGL_PAYROLL_HEADER_STG.sql 717 2017-06-06 23:38:06Z svnuser $
CREATE TABLE FMSMGR.XXGL_PAYROLL_HEADER_STG
(
    RECORD_ID               NUMBER NOT NULL PRIMARY KEY,
    RUN_NUMBER              NUMBER NOT NULL,
    PAY_DATE                DATE NOT NULL,
    LAST_PAY_DATE           DATE NOT NULL,
    RUN_ID                  NUMBER,
    RUN_PHASE_ID            NUMBER,
    STATUS                  VARCHAR2(25),
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE
);

CREATE OR REPLACE SYNONYM APPS.XXGL_PAYROLL_HEADER_STG FOR FMSMGR.XXGL_PAYROLL_HEADER_STG;