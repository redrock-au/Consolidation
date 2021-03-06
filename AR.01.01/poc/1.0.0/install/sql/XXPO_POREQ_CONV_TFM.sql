rem $Header: svn://d02584/consolrepos/branches/AR.01.01/poc/1.0.0/install/sql/XXPO_POREQ_CONV_TFM.sql 2318 2017-08-28 04:51:18Z svnuser $
CREATE TABLE FMSMGR.XXPO_POREQ_CONV_TFM
(
    RECORD_ID               NUMBER NOT NULL PRIMARY KEY,
    SOURCE_RECORD_ID        NUMBER NOT NULL,
    -- Supplier --
    DSDBI_SUPPLIER_NUM      VARCHAR2(30),
    DSDBI_SUPPLIER_ID       VARCHAR2(15),
    DSDBI_SUPPLIER_NAME     VARCHAR2(240),
    DSDBI_SUPPLIER_SITE_ID  VARCHAR2(15),
    DSDBI_SUPPLIER_SITE     VARCHAR2(30),
    DSDBI_PO_NUM            VARCHAR2(30),
    DSDBI_PO_HEADER_ID      VARCHAR2(30),
    DSDBI_PO_LINE_ID        VARCHAR2(15),
    -- Interface --
    INTERFACE_SOURCE_CODE   VARCHAR2(25),
    SOURCE_TYPE_CODE        VARCHAR2(30),
    DESTINATION_TYPE_CODE   VARCHAR2(30),
    SUGGESTED_VENDOR_ID     NUMBER,
    SUGGESTED_VENDOR_SITE_ID NUMBER,
    AUTHORIZATION_STATUS    VARCHAR2(25),
    GROUP_CODE              VARCHAR2(30),
    APPROVER_ID             NUMBER,
    PREPARER_ID             NUMBER,
    HEADER_DESCRIPTION      VARCHAR2(240),
    HEADER_ATTRIBUTE_CATEGORY   VARCHAR2(30),
    HEADER_ATTRIBUTE1       VARCHAR2(150),
    HEADER_ATTRIBUTE2       VARCHAR2(150),
    HEADER_ATTRIBUTE3       VARCHAR2(150),
    HEADER_ATTRIBUTE4       VARCHAR2(150),
    HEADER_ATTRIBUTE5       VARCHAR2(150),
    HEADER_ATTRIBUTE6       VARCHAR2(150),
    HEADER_ATTRIBUTE7       VARCHAR2(150),
    HEADER_ATTRIBUTE8       VARCHAR2(150),
    HEADER_ATTRIBUTE9       VARCHAR2(150),
    HEADER_ATTRIBUTE10      VARCHAR2(150),
    HEADER_ATTRIBUTE11      VARCHAR2(150),
    HEADER_ATTRIBUTE12      VARCHAR2(150),
    HEADER_ATTRIBUTE13      VARCHAR2(150),
    HEADER_ATTRIBUTE14      VARCHAR2(150),
    HEADER_ATTRIBUTE15      VARCHAR2(150),
    -- Line --
    CATEGORY_SEGMENT1       VARCHAR2(40),
    ITEM_DESCRIPTION        VARCHAR2(240),
    QUANTITY                NUMBER,
    UNIT_PRICE              NUMBER,
    UOM_CODE                VARCHAR2(3),
    LINE_TYPE_ID            NUMBER,
    DESTINATION_ORGANIZATION_ID  NUMBER,
    DELIVER_TO_LOCATION_ID  NUMBER,
    DELIVER_TO_REQUESTOR_ID NUMBER,
    ORG_ID                  NUMBER,
    MULTI_DISTRIBUTIONS     VARCHAR2(1),
    REQ_DIST_SEQUENCE_ID    NUMBER,
    TAX_CODE_ID             NUMBER,
    -- Distribution --
    DISTRIBUTION_NUM        NUMBER,
    DIST_SEQUENCE_ID        NUMBER,
    DIST_QUANTITY           NUMBER,
    CHARGE_CODE_ID          NUMBER,
    DIST_GL_DATE            DATE,
    -- Framework --
    RUN_ID                  NUMBER,
    RUN_PHASE_ID            NUMBER,
    STATUS                  VARCHAR2(25),
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE,
    LAST_UPDATED_BY         NUMBER,
    LAST_UPDATE_DATE        DATE
);

CREATE OR REPLACE SYNONYM APPS.XXPO_POREQ_CONV_TFM FOR FMSMGR.XXPO_POREQ_CONV_TFM; 
