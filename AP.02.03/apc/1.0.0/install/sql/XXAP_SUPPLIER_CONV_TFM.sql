rem $Header: svn://d02584/consolrepos/branches/AP.02.03/apc/1.0.0/install/sql/XXAP_SUPPLIER_CONV_TFM.sql 1578 2017-07-07 02:00:48Z svnuser $
CREATE TABLE FMSMGR.XXAP_SUPPLIER_CONV_TFM
(
    RECORD_ID                       NUMBER NOT NULL PRIMARY KEY,
    SOURCE_RECORD_ID                NUMBER NOT NULL,
    DTPLI_SUPPLIER_NUM              VARCHAR2(30),
    DTPLI_SITE_CODE                 VARCHAR2(15),
    SOURCE_SUPPLIER_NUMBER          VARCHAR2(30),
    VENDOR_INTERFACE_ID             NUMBER,  
    LAST_UPDATE_DATE                DATE,
    LAST_UPDATED_BY                 NUMBER,
    VENDOR_NAME                     VARCHAR2(240),
    VENDOR_NAME_ALT                 VARCHAR2(320),
    SEGMENT1                        VARCHAR2(30),
    SUMMARY_FLAG                    VARCHAR2(1),
    ENABLED_FLAG                    VARCHAR2(1),
    LAST_UPDATE_LOGIN               NUMBER,
    EMPLOYEE_ID                     NUMBER,
    VENDOR_TYPE_LOOKUP_CODE         VARCHAR2(30),
    ONE_TIME_FLAG                   VARCHAR2(1),
    SET_OF_BOOKS_ID                 NUMBER,
    PAYMENT_PRIORITY                NUMBER,
    HOLD_ALL_PAYMENTS_FLAG          VARCHAR2(1),
    HOLD_FUTURE_PAYMENTS_FLAG       VARCHAR2(1),
    ATTRIBUTE1                      VARCHAR2(150),
    ATTRIBUTE2                      VARCHAR2(150),
    ATTRIBUTE3                      VARCHAR2(150),
    ATTRIBUTE4                      VARCHAR2(150),
    ATTRIBUTE5                      VARCHAR2(150),
    ATTRIBUTE6                      VARCHAR2(150),
    ATTRIBUTE7                      VARCHAR2(150),
    ATTRIBUTE8                      VARCHAR2(150),
    ATTRIBUTE9                      VARCHAR2(150),
    ATTRIBUTE10                     VARCHAR2(150),
    ATTRIBUTE11                     VARCHAR2(150),
    ATTRIBUTE12                     VARCHAR2(150),
    ATTRIBUTE13                     VARCHAR2(150),
    ATTRIBUTE14                     VARCHAR2(150),
    ATTRIBUTE15                     VARCHAR2(150),
    ATTRIBUTE_CATEGORY              VARCHAR2(30),
    VAT_REGISTRATION_NUM            VARCHAR2(20),
    ALLOW_AWT_FLAG                  VARCHAR2(1),
    AWT_GROUP_ID                    NUMBER,
    VENDOR_STATUS                   VARCHAR2(30),
    -- SITE --
    VENDOR_ID                       NUMBER,
    VENDOR_SITE_CODE                VARCHAR2(15),
    VENDOR_SITE_CODE_ALT            VARCHAR2(320),
    SOURCE_SITE_NAME                VARCHAR2(15),
    PURCHASING_SITE_FLAG            VARCHAR2(1),
    PAY_SITE_FLAG                   VARCHAR2(1),
    ATTENTION_AR_FLAG               VARCHAR2(1),
    ADDRESS_LINE1                   VARCHAR2(240),
    ADDRESS_LINES_ALT               VARCHAR2(560),
    ADDRESS_LINE2                   VARCHAR2(240),
    ADDRESS_LINE3                   VARCHAR2(240),
    ADDRESS_LINE4                   VARCHAR2(240),
    CITY                            VARCHAR2(25),
    STATE                           VARCHAR2(150),
    ZIP                             VARCHAR2(20),
    PROVINCE                        VARCHAR2(150),
    COUNTRY                         VARCHAR2(25),
    COUNTY                          VARCHAR2(150),
    AREA_CODE                       VARCHAR2(10),
    PHONE                           VARCHAR2(15),
    FAX                             VARCHAR2(15),
    FAX_AREA_CODE                   VARCHAR2(10),
    TELEX                           VARCHAR2(15),
    PAYMENT_METHOD_LOOKUP_CODE      VARCHAR2(25),
    VAT_CODE                        VARCHAR2(20),
    ACCTS_PAY_CODE_COMBINATION_ID   NUMBER,
    PREPAY_CODE_COMBINATION_ID      NUMBER,
    SITE_PAYMENT_PRIORITY           NUMBER,
    TERMS_ID                        NUMBER,
    INVOICE_CURRENCY_CODE           VARCHAR2(15),
    PAYMENT_CURRENCY_CODE           VARCHAR2(15),
    SITE_HOLD_ALL_PAYMENTS_FLAG     VARCHAR2(1),
    EXCLUSIVE_PAYMENT_FLAG          VARCHAR2(1),
    SITE_ATTRIBUTE1                 VARCHAR2(150),
    SITE_ATTRIBUTE2                 VARCHAR2(150),
    SITE_ATTRIBUTE3                 VARCHAR2(150),
    SITE_ATTRIBUTE4                 VARCHAR2(150),
    SITE_ATTRIBUTE5                 VARCHAR2(150),
    SITE_ATTRIBUTE6                 VARCHAR2(150),
    SITE_ATTRIBUTE7                 VARCHAR2(150),
    SITE_ATTRIBUTE8                 VARCHAR2(150),
    SITE_ATTRIBUTE9                 VARCHAR2(150),
    SITE_ATTRIBUTE10                VARCHAR2(150),
    SITE_ATTRIBUTE11                VARCHAR2(150),
    SITE_ATTRIBUTE12                VARCHAR2(150),
    SITE_ATTRIBUTE13                VARCHAR2(150),
    SITE_ATTRIBUTE14                VARCHAR2(150),
    SITE_ATTRIBUTE15                VARCHAR2(150),
    SITE_ATTRIBUTE_CATEGORY         VARCHAR2(30),
    SITE_VAT_REG_NUM                VARCHAR2(20),
    ORG_ID                          NUMBER,
    SITE_ALLOW_AWT_FLAG             VARCHAR2(1),
    SITE_AWT_GROUP_ID               NUMBER,
    PRIMARY_PAY_SITE_FLAG           VARCHAR2(1),
    SITE_STATUS                     VARCHAR2(30),
    -- CONTACT --
    VENDOR_SITE_ID                  NUMBER,
    FIRST_NAME                      VARCHAR2(15),
    MIDDLE_NAME                     VARCHAR2(15),
    LAST_NAME                       VARCHAR2(20),
    PREFIX                          VARCHAR2(5),
    TITLE                           VARCHAR2(30),
    MAIL_STOP                       VARCHAR2(35),
    CONTACT_AREA_CODE               VARCHAR2(10),
    CONTACT_PHONE                   VARCHAR2(15),
    CONTACT_NAME_ALT                VARCHAR2(320),
    DEPARTMENT                      VARCHAR2(230),
    EMAIL_ADDRESS                   VARCHAR2(2000),
    URL                             VARCHAR2(2000),
    CONTACT_ALT_AREA_CODE           VARCHAR2(10),
    CONTACT_ALT_PHONE               VARCHAR2(15),
    CONTACT_FAX_AREA_CODE           VARCHAR2(10),
    CONTACT_FAX                     VARCHAR2(15),  
    CONTACT_STATUS                  VARCHAR2(30),
    -- BANK --
    BANK                            VARCHAR2(60),
    BRANCH                          VARCHAR2(60),
    BANK_ACCOUNT_NAME               VARCHAR2(80),
    BANK_ACCOUNT_NUMBER             VARCHAR2(30),
    BANK_ACCOUNT_DESCRIPTION        VARCHAR2(240),
    BANK_ACCOUNT_NAME_ALT           VARCHAR2(320),
    ACCOUNT_HOLDER_NAME             VARCHAR2(240),
    ALLOW_MULTI_ASSIGN_FLAG         VARCHAR2(1),
    -- FRAMEWORK --
    RUN_ID                          NUMBER,
    RUN_PHASE_ID                    NUMBER,
    STATUS                          VARCHAR2(25),
    CREATED_BY                      NUMBER,
    CREATION_DATE                   DATE
);

CREATE OR REPLACE SYNONYM APPS.XXAP_SUPPLIER_CONV_TFM FOR FMSMGR.XXAP_SUPPLIER_CONV_TFM; 
