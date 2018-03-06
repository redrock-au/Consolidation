REM $Header: svn://d02584/consolrepos/branches/AP.02.03/arc/1.0.0/install/sql/XXAR_PAYMENT_STATUS_V_DDL.sql 1442 2017-07-04 22:35:02Z svnuser $
REM CEMLI ID: AR.02.04

-- Create View

CREATE OR REPLACE VIEW xxar_payment_status_v AS
SELECT a.crn_id, 
       a.source,
       a.crn_number,
       a.orig_amt1,
       a.orig_amt2,
       a.orig_amt3,
       a.orig_amt4,
       a.creation_date,
       NVL(b.total_receipt_amount, 0) total_receipt_amount,
       CASE WHEN a.archive_flag = 'Y' THEN 'Archived'
            WHEN a.orig_amt1 = NVL(b.total_receipt_amount, 0) THEN 'Paid'
            WHEN a.orig_amt2 = NVL(b.total_receipt_amount, 0) THEN 'Paid'
            WHEN a.orig_amt3 = NVL(b.total_receipt_amount, 0) THEN 'Paid'
            WHEN a.orig_amt4 = NVL(b.total_receipt_amount, 0) THEN 'Paid'
            ELSE 'New'
       END open_item_status
FROM   xxar_payment_notices_b a,
      (SELECT x.crn_id,
              SUM(r.amount) total_receipt_amount
       FROM   ar_cash_receipts_all r,
              ar_receivables_trx_all t,
              xxar_payment_notices_b x
       WHERE  r.type = 'MISC'
       AND    r.status = 'APP'
       AND    r.attribute14 = x.crn_id
       AND    r.receivables_trx_id = t.receivables_trx_id
       GROUP  BY x.crn_id) b
WHERE  a.crn_id = b.crn_id(+);

