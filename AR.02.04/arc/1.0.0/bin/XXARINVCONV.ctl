--$Header: svn://d02584/consolrepos/branches/AR.02.04/arc/1.0.0/bin/XXARINVCONV.ctl 2108 2017-08-10 08:21:57Z svnuser $
OPTIONS(SKIP=1)
LOAD DATA
REPLACE
INTO TABLE XXAR_OPEN_INVOICES_CONV_STG
FIELDS TERMINATED BY "," OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
DSDBI_CUSTOMER_NAME,
DSDBI_CUSTOMER_NUMBER,
DSDBI_CUSTOMER_SITE_NUMBER,
ORACLE_TRX_TYPE,
DSDBI_TRX_NUMBER,
TRX_DATE,
INV_AMOUNT,
DSDBI_CRN,
TERM_NAME,
DUE_DATE,
COMMENTS,
PO_NUMBER,
CUSTOMER_CONTACT_NAME,
INVOICE_EMAIL,
INTERNAL_CONTACT_NAME,
LINE_NUMBER,
LINE_TYPE,
LINE_DESCRIPTION,
SALES_ORDER,
LINE_QUANTITY,
UNIT_SELLING_PRICE,
LINE_AMOUNT,
TAX_CODE,
PERIOD_OF_SERVICE_FROM,
PERIOD_OF_SERVICE_TO,
DIST_LINE_TYPE,
DIST_AMOUNT,
CHARGE_CODE,
RRAM_SOURCE_SYSTEM_REF,
RECORD_ID "XXAR_OPEN_INV_CONV_RECORD_ID_S.NEXTVAL",
STATUS CONSTANT 'NEW'
)