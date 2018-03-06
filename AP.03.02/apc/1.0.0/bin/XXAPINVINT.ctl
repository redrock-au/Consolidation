-- $Header: svn://d02584/consolrepos/branches/AP.03.02/apc/1.0.0/bin/XXAPINVINT.ctl 1820 2017-07-18 00:18:19Z svnuser $
OPTIONS (SKIP=1)
LOAD DATA
TRUNCATE
INTO TABLE FMSMGR.XXAP_INVOICES_INTERFACE_STG
FIELDS TERMINATED BY "," OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
    INVOICE_NUMBER          CHAR,
    INVOICE_DATE            CHAR,
    VENDOR_NUMBER           CHAR,
    VENDOR_SITE_NAME        CHAR,
    INVOICE_TYPE            CHAR,
    INVOICE_AMOUNT          CHAR,
    INVOICE_DESCRIPTION     CHAR,
    LINE_NUMBER             CHAR,
    LINE_AMOUNT             CHAR,
    LINE_DESCRIPTION        CHAR,
    TAX_CODE                CHAR,
    CHARGE_CODE             CHAR,
    ATTRIBUTE1              CHAR,
    ATTRIBUTE2              CHAR,
    ATTRIBUTE3              CHAR,
    ATTRIBUTE4              CHAR,
    ATTRIBUTE5              CHAR,
    ATTRIBUTE6              CHAR,
    ATTRIBUTE7              CHAR,
    ATTRIBUTE8              CHAR,
    ATTRIBUTE9              CHAR,
    ATTRIBUTE10             CHAR,
    ATTRIBUTE11             CHAR,
    ATTRIBUTE12             CHAR,
    ATTRIBUTE13             CHAR,
    ATTRIBUTE14             CHAR,
    ATTRIBUTE15             CHAR,
    RECORD_ID               "XXAP_INVOICES_RECORD_ID_S.NEXTVAL",
    STATUS                  CONSTANT 'NEW',
    CREATION_DATE           SYSDATE
)
