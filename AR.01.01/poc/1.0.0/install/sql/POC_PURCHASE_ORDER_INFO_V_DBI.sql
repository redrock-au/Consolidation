/*$Header: svn://d02584/consolrepos/branches/AR.01.01/poc/1.0.0/install/sql/POC_PURCHASE_ORDER_INFO_V_DBI.sql 2949 2017-11-13 01:09:55Z svnuser $*/
CREATE OR REPLACE VIEW 
apps.poc_purchase_order_info_v_dbi 
(
   po_id, 
   po_number, 
   po_vendor_id, 
   po_vendor_site_id, 
   supplier_site_abn, 
   po_org_id, 
   po_status, 
   vendor_number, 
   site_name,
   po_amount,
   po_amount_remaining
) 
AS 
SELECT pha.po_header_id, 
       pha.segment1, 
       pha.vendor_id, 
       pha.vendor_site_id,
       pvsa.vat_registration_num, 
       pha.org_id, 
       nvl(pha.closed_code, 'OPEN'),
       pov.segment1, 
       pvsa.vendor_site_code,
       amount.po_amount,
       amount.po_amount_remaining - nvl(xisf.invoice_amount_exc_gst,0) po_amount_remaining
FROM   po_headers_all pha, 
       po_vendor_sites_all pvsa, 
       po_vendors pov,     
       (SELECT sum((pd.quantity_ordered - pd.quantity_cancelled - pd.quantity_delivered)*pl.unit_price) po_amount_remaining,
               sum((pd.quantity_ordered - pd.quantity_cancelled )*pl.unit_price) po_amount,
               pd.po_header_id 
        FROM   po_distributions_all pd,
               po_lines_all pl,
               po_line_locations_all pll
        WHERE  pd.po_header_id = pl.po_header_id
        AND    pd.po_header_id = pll.po_header_id
        AND    pd.line_location_id = pll.line_location_id -- Added join Joy Pinto 23/06/2017
        AND    pl.po_line_id = pll.po_line_id
        GROUP BY pd.po_header_id 
       ) amount,
       (SELECT SUM(invoice_amount_exc_gst) invoice_amount_exc_gst,
               po_header_id
        FROM   xxap_inv_scanned_file xisf
        WHERE  nvl(active_flag,'Y') = 'Y'
        AND    NOT EXISTS (SELECT 1 from rcv_transactions x where x.attribute5 = xisf.import_id)
        group by po_header_id
       ) xisf
WHERE  NVL(pha.authorization_status,'INCOMPLETE')  = 'APPROVED'
AND    pha.type_lookup_code = 'STANDARD'
AND    NVL(pha.cancel_flag, 'N') = 'N'
AND    NVL(pha.approved_flag, 'N') = 'Y'
AND    NVL(pha.closed_code, 'OPEN') NOT IN ('FINALLY CLOSED', 'CANCELLED')
AND    pha.org_id = 101
AND    pha.vendor_site_id = pvsa.vendor_site_id
AND    pha.vendor_id = pov.vendor_id
AND    amount.po_header_id = pha.po_header_id
AND    xisf.po_header_id(+) = pha.po_header_id
AND    nvl(pha.closed_code, 'OPEN') ='OPEN';

 GRANT SELECT ON APPS.poc_purchase_order_info_v_dbi TO KOFAX;
 
 CREATE OR REPLACE SYNONYM KOFAX.poc_purchase_order_info_v_dbi FOR APPS.poc_purchase_order_info_v_dbi;
