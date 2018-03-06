rem $Header: svn://d02584/consolrepos/branches/AR.09.03/glc/1.0.0/install/sql/XXGL_PAYROLL_DETAIL_DEL.sql 875 2017-06-18 23:27:42Z svnuser $
CREATE TABLE FMSMGR.XXGL_PAYROLL_DETAIL_DEL
(
    RECORD_ID               NUMBER NOT NULL PRIMARY KEY,
    RECORD_CATEGORY         VARCHAR2(20) NOT NULL,
    RECORD_TYPE             VARCHAR2(10) NOT NULL,
    ORGANISATION            VARCHAR2(1) NOT NULL,
    ACCOUNT                 VARCHAR2(5) NOT NULL,
    COST_CENTRE             VARCHAR2(3) NOT NULL,
    AUTHORITY               VARCHAR2(4) NOT NULL,
    PROJECT                 VARCHAR2(4) NOT NULL,
    OUTPUT                  VARCHAR2(4) NOT NULL,
    IDENTIFIER              VARCHAR2(8) NOT NULL,
    AMOUNT                  NUMBER NOT NULL,
    LAST_PAY_DATE           DATE NOT NULL,
    RUN_ID                  NUMBER,
    RUN_PHASE_ID            NUMBER,
    STATUS                  VARCHAR2(25),
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE
);

CREATE OR REPLACE SYNONYM APPS.XXGL_PAYROLL_DETAIL_DEL FOR FMSMGR.XXGL_PAYROLL_DETAIL_DEL; 
