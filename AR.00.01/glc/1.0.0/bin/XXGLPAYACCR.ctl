-- $Header: svn://d02584/consolrepos/branches/AR.00.01/glc/1.0.0/bin/XXGLPAYACCR.ctl 1492 2017-07-05 07:01:42Z svnuser $
LOAD DATA
APPEND
INTO TABLE FMSMGR.XXGL_PAYROLL_HEADER_STG
WHEN (1:3) = 'HDR'
(
    RUN_NUMBER              POSITION(4:7),
    PAY_DATE                POSITION(8:15) DATE "YYYYMMDD",
    LAST_PAY_DATE           POSITION(16:21) DATE "RRMMDD",
    RECORD_ID               "XXGL_PAYROLL_RECORD_ID_S.NEXTVAL"
)
INTO TABLE FMSMGR.XXGL_PAYROLL_DETAIL_STG
WHEN (1:3) != 'HDR' AND (1:3) != 'TLR'
(
    RECORD_CATEGORY         POSITION(1:16),
    RECORD_TYPE             POSITION(17:23),
    ORGANISATION            POSITION(24),
    ACCOUNT                 POSITION(25:29),
    COST_CENTRE             POSITION(30:32),
    AUTHORITY               POSITION(33:36),
    PROJECT                 POSITION(37:40),
    OUTPUT                  POSITION(41:44),
    IDENTIFIER              POSITION(45:52),
    AMOUNT                  POSITION(53:64) DECIMAL EXTERNAL ":AMOUNT",
    LAST_PAY_DATE           POSITION(65:70) DATE "RRMMDD",
    RECORD_ID               "XXGL_PAYROLL_RECORD_ID_S.NEXTVAL"
)
INTO TABLE FMSMGR.XXGL_PAYROLL_TRAILER_STG
WHEN (1:3) = 'TLR'
(
    RECORD_COUNT            POSITION(4:8) DECIMAL EXTERNAL ":RECORD_COUNT",
    RECORD_TOTAL_AMOUNT     POSITION(9:20) DECIMAL EXTERNAL ":RECORD_TOTAL_AMOUNT",
    RECORD_ID               "XXGL_PAYROLL_RECORD_ID_S.NEXTVAL"
)
