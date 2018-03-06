/*$Header: svn://d02584/consolrepos/branches/AR.03.02/arc/1.0.0/bin/XXARINVCONV.ctl 1830 2017-07-18 00:26:50Z svnuser $*/

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
RRAM_SOURCE_SYSTEM_REF,
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
RECORD_ID "XXAR_OPEN_INV_CONV_RECORD_ID_S.NEXTVAL",
STATUS CONSTANT 'NEW'
)