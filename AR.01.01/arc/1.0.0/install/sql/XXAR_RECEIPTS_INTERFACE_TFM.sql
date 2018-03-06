rem $Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/sql/XXAR_RECEIPTS_INTERFACE_TFM.sql 1379 2017-07-03 00:43:56Z svnuser $
CREATE TABLE FMSMGR.XXAR_RECEIPTS_INTERFACE_TFM
(
    RECORD_ID               NUMBER NOT NULL PRIMARY KEY,
    SOURCE_RECORD_ID        NUMBER NOT NULL,
    SOURCE                  VARCHAR2(100),
    RECEIPT_TYPE            VARCHAR2(30),
    RECEIPT_METHOD_ID       NUMBER,
    REMIT_BANK_ACCOUNT_ID   NUMBER,
    RECEIPT_NUMBER          VARCHAR2(30),
    RECEIPT_AMOUNT          NUMBER,
    CURRENCY_CODE           VARCHAR2(3),
    RECEIPT_DATE            DATE,
    CUSTOMER_ID             NUMBER,
    CUSTOMER_SITE_USE_ID    NUMBER,
    CUSTOMER_TRX_ID         NUMBER,
    COMMENTS                VARCHAR2(2000),
    MISC_PAYMENT_SOURCE     VARCHAR2(30),
    RECEIVABLES_TRX_ID      NUMBER,
    GL_DATE                 DATE,
    TRX_RECEIVABLES_CCID    NUMBER,
    ACTIVITY_GL_CCID        NUMBER,
    PAYMENT_NOTICE_FLAG     VARCHAR2(1),
    ATTRIBUTE_CATEGORY      VARCHAR2(30),
    ATTRIBUTE1              VARCHAR2(150),
    ATTRIBUTE2              VARCHAR2(150),
    ATTRIBUTE3              VARCHAR2(150),
    ATTRIBUTE4              VARCHAR2(150),
    ATTRIBUTE5              VARCHAR2(150),
    ATTRIBUTE6              VARCHAR2(150),
    ATTRIBUTE7              VARCHAR2(150),
    ATTRIBUTE8              VARCHAR2(150),
    ATTRIBUTE9              VARCHAR2(150),
    ATTRIBUTE10             VARCHAR2(150),
    ATTRIBUTE11             VARCHAR2(150),
    ATTRIBUTE12             VARCHAR2(150),
    ATTRIBUTE13             VARCHAR2(150),
    ATTRIBUTE14             VARCHAR2(150),
    ATTRIBUTE15             VARCHAR2(150),
    CASH_RECEIPT_ID         NUMBER,
    RUN_ID                  NUMBER,
    RUN_PHASE_ID            NUMBER,
    STATUS                  VARCHAR2(25),
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE,
    LAST_UPDATE_DATE        DATE,
    LAST_UPDATED_BY         NUMBER
);

CREATE OR REPLACE SYNONYM APPS.XXAR_RECEIPTS_INTERFACE_TFM FOR FMSMGR.XXAR_RECEIPTS_INTERFACE_TFM;

CREATE INDEX FMSMGR.XXAR_RECEIPTS_INTERFACE_TFM_N1 ON FMSMGR.XXAR_RECEIPTS_INTERFACE_TFM(RUN_ID); 
