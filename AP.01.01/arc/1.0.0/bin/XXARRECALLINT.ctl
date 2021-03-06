-- $Header: svn://d02584/consolrepos/branches/AP.01.01/arc/1.0.0/bin/XXARRECALLINT.ctl 1471 2017-07-05 00:34:40Z svnuser $
LOAD DATA
APPEND
INTO TABLE FMSMGR.XXAR_RECALL_INTERFACE_HDR_STG
WHEN (1:1) = '0'
(
    RECALL_NUMBER           POSITION(2:6),
    BILLER_NAME             POSITION(7:34)     CHAR "TRIM(:BILLER_NAME)",
    STATE                   POSITION(35),
    BILLER_BSB              POSITION(36:41),
    BILLER_ACCOUNT          POSITION(42:47),
    UNIT_CHARGE             POSITION(48:52),
    PROCESSING_DATE         POSITION(53:60),
    SOURCE                  CONSTANT 'RECALL',
    RECORD_ID               "XXAR_RECEIPTS_RECORD_ID_S.NEXTVAL",
    STATUS                  CONSTANT 'NEW',
    CREATION_DATE           SYSDATE
)
INTO TABLE FMSMGR.XXAR_RECALL_INTERFACE_STG
WHEN (1:1) = '1'
(
    CRN                     POSITION(2:30)      CHAR "TRIM(:CRN)",
    RECEIPT_AMOUNT          POSITION(32:42),
    PAYMENT_METHOD_CODE     POSITION(43:44),
    RECEIPT_NUMBER_1        POSITION(45:52),
    VOUCHER                 POSITION(53:68)     CHAR "TRIM(:VOUCHER)",
    RECEIPT_NUMBER_2        POSITION(69:89),
    TRANS_TYPE              POSITION(90:93),
    SOURCE                  CONSTANT 'RECALL',
    RECORD_ID               "XXAR_RECEIPTS_RECORD_ID_S.NEXTVAL",
    STATUS                  CONSTANT 'NEW',
    CREATION_DATE           SYSDATE
)
