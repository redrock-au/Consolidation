rem $Header: svn://d02584/consolrepos/branches/AR.02.02/poc/1.0.0/install/sql/XXPO_POREQ_CONV_STG.sql 2122 2017-08-16 01:17:46Z svnuser $
CREATE TABLE FMSMGR.XXPO_POREQ_CONV_STG
(
    RECORD_ID               NUMBER NOT NULL PRIMARY KEY,
    -- Supplier --
    DSDBI_SUPPLIER_NUM      VARCHAR2(30),
    DSDBI_SUPPLIER_ID       VARCHAR2(15),
    DSDBI_SUPPLIER_NAME     VARCHAR2(240),
    DSDBI_SUPPLIER_SITE_ID  VARCHAR2(15),
    DSDBI_SUPPLIER_SITE     VARCHAR2(30),
    -- Purhase Order --
    DSDBI_PO_NUM            VARCHAR2(30),
    PO_HEADER_ID            VARCHAR2(30),
    ORDER_DATE              VARCHAR2(30),
    HEADER_DESCRIPTION      VARCHAR2(240),
    BUYER_NAME              VARCHAR2(60),
    BUYER_EMP_NUM           VARCHAR2(15),
    DFF_CONTEXT             VARCHAR2(150),
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
    -- Line --
    PO_LINE_ID              VARCHAR2(15),
    LINE_NUMBER             VARCHAR2(15),
    LINE_TYPE               VARCHAR2(60),
    CATEGORY                VARCHAR2(60),
    LINE_DESCRIPTION        VARCHAR2(240),
    UOM_CODE                VARCHAR2(30),
    QUANTITY                VARCHAR2(15),
    PRICE                   VARCHAR2(15),
    TAX_CODE                VARCHAR2(30),
    REQUESTER_NAME          VARCHAR2(60),
    REQUESTER_EMP_NUM       VARCHAR2(15),
    LOCATION                VARCHAR2(30),
    -- Distribution --
    PO_DISTRIBUTION_ID      VARCHAR2(15),
    DISTRIBUTION_NUM        VARCHAR2(15),
    CHARGE_ACCOUNT_SEG1     VARCHAR2(30),
    CHARGE_ACCOUNT_SEG2     VARCHAR2(30),
    CHARGE_ACCOUNT_SEG3     VARCHAR2(30),
    CHARGE_ACCOUNT_SEG4     VARCHAR2(30),
    CHARGE_ACCOUNT_SEG5     VARCHAR2(30),
    DIST_QUANTITY           VARCHAR2(15),
    -- Framework --
    RUN_ID                  NUMBER,
    RUN_PHASE_ID            NUMBER,
    STATUS                  VARCHAR2(25),
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE
);

CREATE OR REPLACE SYNONYM APPS.XXPO_POREQ_CONV_STG FOR FMSMGR.XXPO_POREQ_CONV_STG; 
