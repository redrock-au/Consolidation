/*$Header: svn://d02584/consolrepos/branches/AR.02.03/apc/1.0.0/sql/INV_AMT_MISMATCH_RPT.sql 1451 2017-07-04 23:01:51Z svnuser $*/
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
SET LINESIZE 500
TTITLE 'DEDJTR Invoice Amount Mis-match Report'
COLUMN supplier_num HEADING 'Suppier Number' FORMAT A30
COLUMN supplier_name HEADING 'Supplier Name' FORMAT A25
COLUMN supplier_name WORD_WRAPPED
COLUMN supplier_site HEADING 'Supplier Site' FORMAT A20
COLUMN inv_frm_ip5 HEADING 'Invoice Number Received from IP5' FORMAT A40
COLUMN inv_creation_date_ip5 HEADING 'Invoice Creation Date in AP' FORMAT A40
COLUMN inv_date_ip5 HEADING 'Invoice Date in IP5' FORMAT A20
COLUMN file_import_id FORMAT A20
COLUMN file_import_id HEADING 'Import Id' FORMAT 9999999999
COLUMN kfx_inv_num HEADING 'Kofax Invoice Number' FORMAT A30
COLUMN kfx_inv_dt HEADING 'Kofax Invoice Date' FORMAT A20
COLUMN kfx_inv_rec_dt HEADING 'Kofax Invoice Received Date' FORMAT A30
COLUMN inv_amt_ip5 FORMAT A30
COLUMN inv_amt_ip5 HEADING 'IP5 Invoice Amount' FORMAT 9999999999.99
COLUMN kfx_inv_amt FORMAT A30
COLUMN kfx_inv_amt HEADING 'Kofax Invoice Amount' FORMAT 9999999999.99
COLUMN DIFFERENCE FORMAT A30
COLUMN DIFFERENCE HEADING 'Difference'FORMAT 9999999999.99
COLUMN inv_amt_paid_ip5 FORMAT A30
COLUMN inv_amt_paid_ip5 HEADING 'Invoice Amount Paid'FORMAT 9999999999.99
COLUMN receipt_by HEADING 'Receipt created By' FORMAT A30
COLUMN receipt_num HEADING 'Receipt Number' FORMAT A30
SELECT
e.segment1 supplier_num,
  e.vendor_name supplier_name,
  f.vendor_site_code supplier_site,
  a.invoice_num inv_frm_ip5,
  a.creation_date inv_creation_date_ip5,
  a.invoice_date inv_date_ip5,
  d.import_id file_import_id,
  d.invoice_num kfx_inv_num,
  d.invoice_date kfx_inv_dt,
  d.invoice_received_date kfx_inv_rec_dt,
  a.invoice_amount inv_amt_ip5,
  nvl(INVOICE_AMOUNT_INC_GST,0) kfx_inv_amt,
  (a.invoice_amount -to_number(nvl(INVOICE_AMOUNT_INC_GST,0))) DIFFERENCE,
  a.amount_paid inv_amt_paid_ip5,
  i.full_name receipt_by,
  h.receipt_num receipt_num
FROM ap_invoices a,
  ap_invoice_distributions b,
  po_distributions c,
  xxap_inv_scanned_file d,
  po_vendors e,
  po_vendor_sites f,
  rcv_transactions g,
  rcv_shipment_headers h,
  per_all_people_f i
WHERE a.invoice_id = b.invoice_id
 AND b.po_distribution_id = c.po_distribution_id
 AND c.po_header_id = d.po_header_id
 AND d.invoice_num LIKE a.invoice_num || '%'
 AND e.vendor_id = f.vendor_id
 AND a.vendor_id = e.vendor_id
 and a.vendor_site_id =f.vendor_site_id
 AND c.po_distribution_id = g.po_distribution_id
      and h.shipment_header_id         = g.shipment_header_id 
    AND g.destination_type_code    = 'RECEIVING' 
    AND g.transaction_type         ='RECEIVE'
    and a.invoice_num = h.attribute2
 and g.employee_id =i.person_id
 and trunc(sysdate) between i.effective_start_date and i.effective_end_date
 and (a.invoice_amount -to_number(nvl(INVOICE_AMOUNT_INC_GST,0))) <> 0
 and TRUNC(a.creation_date) >= TRUNC(to_date('&&1','YYYY/MM/DD HH24:MI:SS') )
 and TRUNC(a.creation_date) <= TRUNC(to_date('&&2','YYYY/MM/DD HH24:MI:SS'))
 UNION ALL
  SELECT
 ' ' supplier_num,
  ' ' supplier_name,
  '**No**Data**Found**' supplier_site,
  NULL inv_frm_ip5,
  NULL inv_creation_date_ip5,
  NULL inv_date_ip5,
  NULL file_import_id,
  NULL  kfx_inv_num,
 NULL kfx_inv_dt,
  NULL kfx_inv_rec_dt,
 NULL inv_amt_ip5,
 NULL kfx_inv_amt,
  NULL DIFFERENCE,
  NULL inv_amt_paid_ip5,
  NULL receipt_by,
  NULL receipt_num
  FROM DUAL 
  where
  (SELECT COUNT(1)
  FROM ap_invoices a,
  ap_invoice_distributions b,
  po_distributions c,
  xxap_inv_scanned_file d,
  po_vendors e,
  po_vendor_sites f,
  rcv_transactions g,
  rcv_shipment_headers h,
  per_all_people_f i
WHERE a.invoice_id = b.invoice_id
 AND b.po_distribution_id = c.po_distribution_id
 AND c.po_header_id = d.po_header_id
 AND d.invoice_num LIKE a.invoice_num || '%'
 AND e.vendor_id = f.vendor_id
 AND a.vendor_id = e.vendor_id
 and a.vendor_site_id =f.vendor_site_id
 AND c.po_distribution_id = g.po_distribution_id
      and h.shipment_header_id         = g.shipment_header_id 
    AND g.destination_type_code    = 'RECEIVING' 
    AND g.transaction_type         ='RECEIVE'
    and a.invoice_num = h.attribute2
 and g.employee_id =i.person_id
 and trunc(sysdate) between i.effective_start_date and i.effective_end_date
 and (a.invoice_amount -to_number(nvl(INVOICE_AMOUNT_INC_GST,0))) <> 0
 and TRUNC(a.creation_date) >= TRUNC(to_date('&&1','YYYY/MM/DD HH24:MI:SS') )
 and TRUNC(a.creation_date) <= TRUNC(to_date('&&2','YYYY/MM/DD HH24:MI:SS'))
  ) =0;
