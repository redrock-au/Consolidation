/*$Header: svn://d02584/consolrepos/branches/AR.02.01/poc/1.0.0/install/sql/POC_INVOICE_INFO_V_DBI.sql 2981 2017-11-14 08:13:57Z svnuser $*/
CREATE OR REPLACE VIEW 
apps.poc_invoice_info_v_dbi 
(
   invoice_id, 
   invoice_number, 
   invoice_date, 
   invoice_amount, 
   supplier_id, 
   supplier_site_id, 
   org_id, 
   abn_number, 
   site_name, 
   vendor_number
)
AS
SELECT aia.invoice_id,
       aia.invoice_num,
       aia.invoice_date,
       aia.invoice_amount,
       aia.vendor_id,
       aia.vendor_site_id,
       aia.org_id,
       pvsa.vat_registration_num,
       pvsa.vendor_site_code,
       pov.segment1
FROM   ap_invoices_all aia,
       po_vendor_sites_all pvsa,
       po_vendors pov
WHERE  aia.org_id = 101
AND    aia.vendor_site_id = pvsa.vendor_site_id
AND    aia.vendor_id      = pov.vendor_id ;

 GRANT SELECT ON APPS.poc_invoice_info_v_dbi TO KOFAX;

 CREATE OR REPLACE SYNONYM KOFAX.poc_invoice_info_v_dbi FOR APPS.poc_invoice_info_v_dbi;
