-- $Header: svn://d02584/consolrepos/branches/AP.01.01/poc/1.0.0/bin/XXPOPOCONV.ctl 2674 2017-10-05 01:02:16Z svnuser $
OPTIONS (SKIP=1)
LOAD DATA
TRUNCATE
INTO TABLE FMSMGR.XXPO_POREQ_CONV_STG
FIELDS TERMINATED BY "," OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
    DSDBI_SUPPLIER_NUM          CHAR,
    DSDBI_SUPPLIER_ID           CHAR,
    DSDBI_SUPPLIER_NAME         CHAR,
    DSDBI_SUPPLIER_SITE_ID      CHAR,
    DSDBI_SUPPLIER_SITE         CHAR,
    DSDBI_PO_NUM                CHAR,
    PO_HEADER_ID                CHAR,
    ORDER_DATE                  CHAR,
    HEADER_DESCRIPTION          CHAR,
    BUYER_NAME                  CHAR,
    BUYER_EMP_NUM               CHAR,
    DFF_CONTEXT                 CHAR,
    ATTRIBUTE1                  CHAR,
    ATTRIBUTE2                  CHAR,
    ATTRIBUTE3                  CHAR,
    ATTRIBUTE4                  CHAR,
    ATTRIBUTE5                  CHAR,
    ATTRIBUTE6                  CHAR,
    ATTRIBUTE7                  CHAR,
    ATTRIBUTE8                  CHAR,
    ATTRIBUTE9                  CHAR,
    ATTRIBUTE10                 CHAR,
    ATTRIBUTE11                 CHAR,
    ATTRIBUTE12                 CHAR,
    ATTRIBUTE13                 CHAR,
    ATTRIBUTE14                 CHAR,
    ATTRIBUTE15                 CHAR,
    PO_LINE_ID                  CHAR,
    LINE_NUMBER                 CHAR,
    LINE_TYPE                   CHAR,
    CATEGORY                    CHAR,
    LINE_DESCRIPTION            CHAR,
    UOM_CODE                    CHAR,
    QUANTITY                    CHAR,
    PRICE                       CHAR,
    TAX_CODE                    CHAR,
    REQUESTER_NAME              CHAR,
    REQUESTER_EMP_NUM           CHAR,
    LOCATION                    CHAR,
    PO_DISTRIBUTION_ID          CHAR,
    DISTRIBUTION_NUM            CHAR,
    CHARGE_ACCOUNT_SEG1         CHAR,
    CHARGE_ACCOUNT_SEG2         CHAR,
    CHARGE_ACCOUNT_SEG3         CHAR,
    CHARGE_ACCOUNT_SEG4         CHAR,
    CHARGE_ACCOUNT_SEG5         CHAR,
    DIST_QUANTITY               CHAR,
    RECORD_ID                   "XXPO_POREQ_RECORD_ID_S.NEXTVAL",
    STATUS                      CONSTANT 'NEW',
    CREATION_DATE               SYSDATE
)
