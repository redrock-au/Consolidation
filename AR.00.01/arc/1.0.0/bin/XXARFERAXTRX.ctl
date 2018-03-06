--$Header: svn://d02584/consolrepos/branches/AR.00.01/arc/1.0.0/bin/XXARFERAXTRX.ctl 1492 2017-07-05 07:01:42Z svnuser $

LOAD DATA
REPLACE
INTO TABLE xxar_invoices_interface_stg fields terminated by '|'
trailing nullcols
(
   CUSTOMER_NUMBER,
   CUSTOMER_SITE_NUMBER,
   TRANSACTION_TYPE_NAME,
   TRX_NUMBER,
   TRX_DATE,
   TERM_NAME,
   COMMENTS,
   PO_NUMBER,
   INVOICE_LINE_NUMBER,
   DESCRIPTION,
   QUANTITY,
   UNIT_SELLING_PRICE,
   AMOUNT,
   TAX_CODE,
   DISTRIBUTION_LINE_NUMBER,
   DISTRIBUTION_AMOUNT,
   CHARGE_CODE,
   HEADER_ATTRIBUTE_CONTEXT,
   CUSTOMER_CONTACT,
   CUSTOMER_EMAIL,
   INTERNAL_CONTACT_NAME,
   LINE_ATTRIBUTE_CONTEXT,
   PERIOD_SERVICE_FROM_DATE,
   PERIOD_SERVICE_TO_DATE,
   RECORD_ID "xxar_invoices_int_record_id_s.NEXTVAL",
   STATUS CONSTANT 'NEW'
)
