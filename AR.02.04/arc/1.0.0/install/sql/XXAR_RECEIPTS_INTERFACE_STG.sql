rem $Header: svn://d02584/consolrepos/branches/AR.02.04/arc/1.0.0/install/sql/XXAR_RECEIPTS_INTERFACE_STG.sql 1569 2017-07-07 00:52:25Z svnuser $
CREATE TABLE FMSMGR.XXAR_RECEIPTS_INTERFACE_STG
(
    RECORD_ID               NUMBER NOT NULL PRIMARY KEY,
    SOURCE                  VARCHAR2(100),
    RECEIPT_TYPE            VARCHAR2(30),
    PAYMENT_METHOD          VARCHAR2(30),
    BANK_ACCOUNT_NUM        VARCHAR2(30),
    RECEIPT_NUMBER          VARCHAR2(30),
    RECEIPT_AMOUNT          VARCHAR2(30),
    RECEIPT_DATE            VARCHAR2(30),
    RECEIPT_COMMENT         VARCHAR2(240),
    PAYER_NAME              VARCHAR2(60),
    INVOICE_NUMBER          VARCHAR2(30),
    RECEIVABLE_ACTIVITY     VARCHAR2(60),
    CRN                     VARCHAR2(30),
    DRAWER_NAME             VARCHAR2(150),
    BANK_NAME               VARCHAR2(150),
    BSB_NUMBER              VARCHAR2(30),
    CHEQUE_NUMBER           VARCHAR2(30),
    CHEQUE_DATE             VARCHAR2(30),
    IVR_REF                 VARCHAR2(150),
    CREDIT_CARD_REF         VARCHAR2(150),
    EFT_REF                 VARCHAR2(150),
    BPAY_REF                VARCHAR2(150),
    AUSPOST_REF             VARCHAR2(150),
    QUICKWEB_REF            VARCHAR2(150),
    DIRECT_DEBIT_REF        VARCHAR2(150),
    CASH_REF                VARCHAR2(150),
    RUN_ID                  NUMBER,
    RUN_PHASE_ID            NUMBER,
    STATUS                  VARCHAR2(25),
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE
);

CREATE OR REPLACE SYNONYM APPS.XXAR_RECEIPTS_INTERFACE_STG FOR FMSMGR.XXAR_RECEIPTS_INTERFACE_STG;

CREATE INDEX FMSMGR.XXAR_RECEIPTS_INTERFACE_STG_N1 ON FMSMGR.XXAR_RECEIPTS_INTERFACE_STG(RUN_ID); 
