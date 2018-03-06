-- $Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/bin/XXARRECINT.ctl 1856 2017-07-18 03:25:10Z svnuser $
LOAD DATA
APPEND
INTO TABLE FMSMGR.XXAR_RECEIPTS_INTERFACE_STG
FIELDS TERMINATED BY "|" OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
    SOURCE                  CHAR,
    RECEIPT_TYPE            CHAR,
    PAYMENT_METHOD          CHAR,
    BANK_ACCOUNT_NUM        CHAR,
    RECEIPT_NUMBER          CHAR,
    RECEIPT_AMOUNT          CHAR,
    RECEIPT_DATE            CHAR,
    RECEIPT_COMMENT         CHAR,
    PAYER_NAME              CHAR,
    INVOICE_NUMBER          CHAR,
    RECEIVABLE_ACTIVITY     CHAR,
    CRN                     CHAR,
    DRAWER_NAME             CHAR,
    BANK_NAME               CHAR,
    BSB_NUMBER              CHAR,
    CHEQUE_NUMBER           CHAR,
    CHEQUE_DATE             CHAR,
    IVR_REF                 CHAR,
    CREDIT_CARD_REF         CHAR,
    EFT_REF                 CHAR,
    BPAY_REF                CHAR,
    AUSPOST_REF             CHAR,
    QUICKWEB_REF            CHAR,
    DIRECT_DEBIT_REF        CHAR,
    CASH_REF                CHAR,
    RECORD_ID               "XXAR_RECEIPTS_RECORD_ID_S.NEXTVAL",
    STATUS                  CONSTANT 'NEW',
    CREATION_DATE           SYSDATE
)
