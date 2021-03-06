rem $Header: svn://d02584/consolrepos/branches/AP.00.02/glc/1.0.0/install/sql/XXGL_PAYROLL_DETAIL_TFM.sql 717 2017-06-06 23:38:06Z svnuser $
CREATE TABLE FMSMGR.XXGL_PAYROLL_DETAIL_TFM
(
    RECORD_ID               NUMBER NOT NULL PRIMARY KEY,
    SOURCE_RECORD_ID        NUMBER NOT NULL,
    SET_OF_BOOKS_ID         NUMBER,
    ACCOUNTING_DATE         DATE,
    DATE_CREATED            DATE,
    CURRENCY_CODE           VARCHAR2(15),
    ACTUAL_FLAG             VARCHAR2(1),
    USER_JE_CATEGORY_NAME   VARCHAR2(25),
    USER_JE_SOURCE_NAME     VARCHAR2(25),
    SEGMENT1                VARCHAR2(25),
    SEGMENT2                VARCHAR2(25),
    SEGMENT3                VARCHAR2(25),
    SEGMENT4                VARCHAR2(25),
    SEGMENT5                VARCHAR2(25),
    SEGMENT6                VARCHAR2(25),
    SEGMENT7                VARCHAR2(25),
    ENTERED_DR              NUMBER,
    ENTERED_CR              NUMBER,
    REFERENCE1              VARCHAR2(100),
    REFERENCE2              VARCHAR2(240),
    REFERENCE4              VARCHAR2(100),
    REFERENCE5              VARCHAR2(240),
    REFERENCE6              VARCHAR2(100),
    REFERENCE7              VARCHAR2(100),
    REFERENCE8              VARCHAR2(100),
    REFERENCE10             VARCHAR2(240),
    GROUP_ID                NUMBER,
    OFFSET_FLAG             VARCHAR2(1),
    RUN_ID                  NUMBER,
    RUN_PHASE_ID            NUMBER,
    STATUS                  VARCHAR2(25),
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE
);

CREATE OR REPLACE SYNONYM APPS.XXGL_PAYROLL_DETAIL_TFM FOR FMSMGR.XXGL_PAYROLL_DETAIL_TFM; 
