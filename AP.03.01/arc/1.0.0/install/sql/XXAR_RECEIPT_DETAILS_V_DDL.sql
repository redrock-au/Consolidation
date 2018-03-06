REM $Header: svn://d02584/consolrepos/branches/AP.03.01/arc/1.0.0/install/sql/XXAR_RECEIPT_DETAILS_V_DDL.sql 1066 2017-06-21 04:33:20Z svnuser $
REM CEMLI ID: AR.02.04

-- Creating View

CREATE OR REPLACE VIEW xxar_receipt_details_v AS
SELECT a.crn_id, 
       a.source,
       a.crn_number,
       a.orig_amt1,
       a.orig_amt2,
       a.orig_amt3,
       a.orig_amt4,
       a.creation_date,
       r.receipt_number,
       r.receipt_date,
       r.amount
FROM   xxar_payment_notices_b a,
       ar_cash_receipts_all r,
       ar_receivables_trx_all t
WHERE  a.crn_id = r.attribute14
AND    r.type = 'MISC'
AND    r.status = 'APP'
AND    r.receivables_trx_id = t.receivables_trx_id;
