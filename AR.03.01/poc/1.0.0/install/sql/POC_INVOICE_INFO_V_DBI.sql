/*$Header: svn://d02584/consolrepos/branches/AR.03.01/poc/1.0.0/install/sql/POC_INVOICE_INFO_V_DBI.sql 1706 2017-07-12 04:37:42Z svnuser $*/
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
       po_vendors pov,
       fnd_profile_options fpo,
       fnd_profile_option_values fpov
WHERE  fpov.profile_option_id = fpo.profile_option_id
AND    fpo.profile_option_name = 'POC_KOFAX_ENABLED'
AND    fpov.level_value = aia.org_id
AND    fpov.level_id = 10006
AND    aia.vendor_site_id = pvsa.vendor_site_id
AND    aia.vendor_id      = pov.vendor_id ;

 GRANT SELECT ON APPS.poc_invoice_info_v_dbi TO KOFAX;

 CREATE OR REPLACE SYNONYM KOFAX.poc_invoice_info_v_dbi FOR APPS.poc_invoice_info_v_dbi;
