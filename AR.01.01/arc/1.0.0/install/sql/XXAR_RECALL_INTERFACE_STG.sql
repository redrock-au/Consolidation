rem $Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/sql/XXAR_RECALL_INTERFACE_STG.sql 1379 2017-07-03 00:43:56Z svnuser $
CREATE TABLE FMSMGR.XXAR_RECALL_INTERFACE_STG
(
    RECORD_ID               NUMBER NOT NULL PRIMARY KEY,
    SOURCE                  VARCHAR2(30),
    CRN                     VARCHAR2(30),
    RECEIPT_AMOUNT          VARCHAR2(30),
    PAYMENT_METHOD_CODE     VARCHAR2(30),
    RECEIPT_NUMBER_1        VARCHAR2(30),
    VOUCHER                 VARCHAR2(30),
    RECEIPT_NUMBER_2        VARCHAR2(30),
    TRANS_TYPE              VARCHAR2(30),
    RUN_ID                  NUMBER,
    RUN_PHASE_ID            NUMBER,
    STATUS                  VARCHAR2(25),
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE
);

CREATE OR REPLACE SYNONYM APPS.XXAR_RECALL_INTERFACE_STG FOR FMSMGR.XXAR_RECALL_INTERFACE_STG;

CREATE INDEX FMSMGR.XXAR_RECALL_INTERFACE_STG_N1 ON FMSMGR.XXAR_RECALL_INTERFACE_STG(RUN_ID); 
