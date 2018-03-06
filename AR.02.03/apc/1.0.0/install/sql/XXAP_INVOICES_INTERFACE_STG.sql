rem $Header: svn://d02584/consolrepos/branches/AR.02.03/apc/1.0.0/install/sql/XXAP_INVOICES_INTERFACE_STG.sql 1451 2017-07-04 23:01:51Z svnuser $
CREATE TABLE FMSMGR.XXAP_INVOICES_INTERFACE_STG
(
    RECORD_ID               NUMBER NOT NULL PRIMARY KEY,
    INVOICE_NUMBER          VARCHAR2(100),
    INVOICE_DATE            VARCHAR2(30),
    VENDOR_NUMBER           VARCHAR2(30),
    VENDOR_SITE_NAME        VARCHAR2(30),
    INVOICE_TYPE            VARCHAR2(30),
    INVOICE_AMOUNT          VARCHAR2(30),
    INVOICE_DESCRIPTION     VARCHAR2(240),
    LINE_NUMBER             VARCHAR2(10),
    LINE_AMOUNT             VARCHAR2(30),
    LINE_DESCRIPTION        VARCHAR2(240),
    TAX_CODE                VARCHAR2(30),
    CHARGE_CODE             VARCHAR2(100),
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
    RUN_ID                  NUMBER,
    RUN_PHASE_ID            NUMBER,
    STATUS                  VARCHAR2(25),
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE
);

CREATE OR REPLACE SYNONYM APPS.XXAP_INVOICES_INTERFACE_STG FOR FMSMGR.XXAP_INVOICES_INTERFACE_STG; 
