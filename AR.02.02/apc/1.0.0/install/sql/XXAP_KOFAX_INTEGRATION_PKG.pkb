create or replace PACKAGE BODY XXAP_KOFAX_INTEGRATION_PKG AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.02/apc/1.0.0/install/sql/XXAP_KOFAX_INTEGRATION_PKG.pkb 3066 2017-11-28 06:24:56Z svnuser $ */
/****************************************************************************
**
** CEMLI ID: AP.03.01
**
** Description: Package to handle the online validations from Kofax
**              This package will be used by Kofax
**              
**
** Change History:
**
** Date         Who                  Comments
** 06/06/2017   Joy Pinto            Initial build.
**
****************************************************************************/

gv_procedure_name       VARCHAR2(150);

------------------------------------------------------------------
-- FUNCTION
--     GET_DUP_AP_INVOICE
-- Purpose
--     This function returns Y if there exists the given invoice
--     number for the given supplier/suppliersite combination. 
--     Function checks in:
--     (1) ap_invoices_all 
--     (2) xxap_inv_scanned_file 
--     (3) ap_invoices_interface
------------------------------------------------------------------

FUNCTION get_dup_ap_inv
(
   p_invoice_num       IN VARCHAR2,
   p_vendor_number     IN VARCHAR2,
   p_vendor_site_code  IN VARCHAR2,
   p_org_id            IN NUMBER
) 
RETURN VARCHAR2
IS
   ln_inv_count NUMBER := 0;
BEGIN
   SELECT COUNT(*)
   INTO   ln_inv_count
   FROM   (SELECT ai.invoice_id, 
                  ai.org_id
           FROM   ap_invoices_all ai,
                  po_vendor_sites_all pvsa,
                  po_vendors pov
           WHERE ai.vendor_id = pov.vendor_id
           AND   pov.vendor_id = pvsa.vendor_id
           AND   ai.invoice_num = p_invoice_num
           AND   ai.org_id = p_org_id
        -- arellanod FSC-6020
        -- AP_INVOICES_U2: VENDOR_ID, INVOICE_NUM, ORG_ID
        -- AND   pvsa.vendor_site_code = p_vendor_site_code
        -- AND   ai.cancelled_date IS NULL
           AND   pov.segment1 = p_vendor_number
           UNION
           SELECT to_number(invoice_id), 
                  org_id
           FROM   xxap_inv_scanned_file
           WHERE  invoice_num = p_invoice_num
           AND    org_id = p_org_id
        -- arellanod FSC-6020
        -- AP_INVOICES_U2: VENDOR_ID, INVOICE_NUM, ORG_ID
        -- AND    vendor_site_code = p_vendor_site_code
           AND    supplier_num = p_vendor_number    
           AND    NVL(active_flag,'Y') = 'Y'
           UNION
           SELECT ai.invoice_id, 
                  ai.org_id
           FROM   ap_invoices_interface ai,
                  fnd_lookup_values alc,
                  po_vendors pov
           WHERE  alc.lookup_code = ai.source
           AND    ai.vendor_name = pov.vendor_name
           AND    alc.lookup_type = 'SOURCE'
           AND    alc.attribute_category  = 'SOURCE'
           AND    NVL(alc.attribute1, 'N') = 'Y'
           AND    ai.status <> 'PROCESSED'
           AND    ai.invoice_num = p_invoice_num
           AND    ai.org_id = p_org_id
        -- arellanod FSC-6020
        -- AP_INVOICES_U2: VENDOR_ID, INVOICE_NUM, ORG_ID
        -- AND    ai.vendor_site_code = p_vendor_site_code
           AND    pov.segment1 = p_vendor_number
           UNION
           SELECT to_number(1), -- FSC 5739 
                  org_id
           FROM   xxap_kofax_inv_stg
           WHERE  invoice_num = p_invoice_num
           AND    org_id = p_org_id
        -- arellanod FSC-6020
        -- AP_INVOICES_U2: VENDOR_ID, INVOICE_NUM, ORG_ID
        -- AND    vendor_site_code = p_vendor_site_code
           AND    supplier_num = p_vendor_number
           AND    nvl(import_status,'IMPORTED') <> 'ERROR'
           );
  
   IF ln_inv_count >= 1 THEN
      RETURN 'Y';
   ELSE
      RETURN 'N';
   END IF;
  
END get_dup_ap_inv;

---------------------------------------------------------------------------------
-- FUNCTION
--     GET_POSSIBLE_DUP_AP_INVOICE
-- Purpose
--     This function returns Y if there exists a invoice for the 
--     given supplier/suppliersite/date combination. Function checks in 
--     (1) ap_invoices_all (2) xxap_inv_scanned_file (3)ap_invoices_interface
---------------------------------------------------------------------------------

FUNCTION get_possible_dup_ap_inv
(
   p_invoice_date      IN DATE,
   p_invoice_amount    IN NUMBER,
   p_vendor_number     IN VARCHAR2,
   p_vendor_site_code  IN VARCHAR2,
   p_org_id            IN NUMBER
) 
RETURN VARCHAR2
IS
   ln_inv_count NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO   ln_inv_count
  FROM   (SELECT ai.invoice_id,
                 ai.org_id
          FROM   ap_invoices_all ai,
                 po_vendor_sites_all pvsa,
                 po_vendors pov
          WHERE  ai.vendor_id = pov.vendor_id
          AND    pov.vendor_id = pvsa.vendor_id
          AND    ai.org_id = p_org_id
          AND    pvsa.vendor_site_code = p_vendor_site_code
          AND    pov.segment1 = p_vendor_number
          AND    ai.invoice_amount = p_invoice_amount
          AND    ai.invoice_date = p_invoice_date
          AND    ai.cancelled_date IS NULL
          UNION
          SELECT TO_NUMBER(invoice_id),
                 org_id
          FROM   xxap_inv_scanned_file
          WHERE  org_id = p_org_id
          AND    vendor_site_code = p_vendor_site_code
          AND    supplier_num = p_vendor_number
          AND    invoice_amount_exc_gst = p_invoice_amount
          AND    invoice_date = p_invoice_date
          AND    NVL(active_flag, 'Y') = 'Y'
          UNION
          SELECT ai.invoice_id,
                 ai.org_id
          FROM   ap_invoices_interface ai,
                 fnd_lookup_values alc,
                 po_vendors pov
          WHERE  alc.lookup_code = ai.source
          AND    ai.vendor_name = pov.vendor_name
          AND    alc.lookup_type = 'SOURCE'
          AND    ai.status <> 'PROCESSED'
          AND    ai.org_id = p_org_id
          AND    ai.vendor_site_code = p_vendor_site_code
          AND    pov.segment1 = p_vendor_number
          AND    ai.invoice_amount = p_invoice_amount
          AND    ai.invoice_date = p_invoice_date
          UNION
          SELECT to_number(1), -- FSC 5739 
                 org_id
          FROM   xxap_kofax_inv_stg 
          WHERE  org_id = p_org_id
          AND    vendor_site_code = p_vendor_site_code
          AND    supplier_num = p_vendor_number
          AND    invoice_date = p_invoice_date -- FSC-5907
          AND    invoice_amount_inc_gst = p_invoice_amount -- FSC-5907
          AND    nvl(import_status,'IMPORTED') <> 'ERROR'         
          );

   IF ln_inv_count >= 1 THEN
      RETURN 'Y';
   ELSE
      RETURN 'N';
   END IF;
  
END get_possible_dup_ap_inv;

----------------------------------------------------------
-- Function
--    Interface Path
-- Description
--    Returns the interface directory path for
--    the given application, source, and whether
--    its inbound or outbound.
----------------------------------------------------------

FUNCTION interface_path
(
   p_application     IN  VARCHAR2,
   p_source          IN  VARCHAR2,
   p_in_out          IN  VARCHAR2 DEFAULT 'INBOUND',
   p_archive         IN  VARCHAR2 DEFAULT 'N',
   p_version         IN  NUMBER,
   p_message         OUT VARCHAR2
)
RETURN VARCHAR2
IS
   l_path             VARCHAR2(240);
BEGIN
   IF UPPER(p_in_out) IN ('INBOUND', 'OUTBOUND', 'WORKING') THEN
      SELECT REPLACE(v.description, '$INSTANCE', (SELECT instance_name FROM v$instance))
      INTO   l_path
      FROM   fnd_flex_values_vl v,
             fnd_flex_value_sets s
      WHERE  v.flex_value_set_id = s.flex_value_set_id
      AND    v.enabled_flag = 'Y'
      AND    s.flex_value_set_name = 'XXINT_INTERFACE_PATH'
      AND    v.flex_value = p_application;

      IF p_source IS NOT NULL THEN
         l_path := l_path || '/' || UPPER(p_source);
      END IF;

      IF p_in_out = 'WORKING' THEN
         l_path := l_path || '/' || LOWER(p_in_out);
      ELSE
         IF p_archive = 'Y' THEN
            l_path := l_path || '/' || 'archive';
         END IF;

         l_path := l_path || '/' || LOWER(p_in_out);
      END IF;
   END IF;

   RETURN l_path;
EXCEPTION
   WHEN others THEN
      p_message := SQLERRM;

END interface_path;

---------------------------------------------------------------------
-- FUNCTION
--     WRITE_KOFAX_ERROR_LOG
-- Purpose
--     This function writes error message in outbound directory 
--     This functionb is called from function deactivate_invoice
---------------------------------------------------------------------

PROCEDURE write_kofax_error_log
(
   p_text IN VARCHAR2
)
IS
   l_file              VARCHAR2(150);
   l_outbound_path     VARCHAR2(150);
   l_text              VARCHAR2(32767);
   l_code              VARCHAR2(15);
   l_message           VARCHAR2(4000);
   f_handle            utl_file.file_type;
   f_copy              INTEGER;
   z_file_temp_dir     CONSTANT VARCHAR2(150)  := 'USER_TMP_DIR';
   z_file_temp_path    CONSTANT VARCHAR2(150)  := '/usr/tmp';
   z_file_write        CONSTANT VARCHAR2(1)    := 'w';  
   l_path              VARCHAR2(240);
BEGIN
   l_file := 'KOFAX_'||to_char(SYSDATE,'YYYYMMDDHH24MISS')||'.log';
   
   f_handle := utl_file.fopen(z_file_temp_dir, l_file, z_file_write);

   l_outbound_path := interface_path(p_application => 'AP',
                                     p_source => 'APCORP',
                                     p_in_out => 'OUTBOUND',
                                     p_archive => 'Y',
                                     p_version => 0,
                                     p_message => l_message);
                                                      
   utl_file.put_line(f_handle, p_text);      
   utl_file.fclose(f_handle);
   
   f_copy := xxint_common_pkg.file_copy(p_from_path => z_file_temp_path || '/' || l_file,
                                        p_to_path =>  l_outbound_path || '/' || l_file);

   utl_file.fremove(z_file_temp_dir, l_file);
  
EXCEPTION
   WHEN OTHERS THEN
      NULL;      
END ;   

-----------------------------------------------
-- FUNCTION
--     DEACTIVATE_INVOICE
-- Purpose
--     This function marks the invoice as 
--     deleted_in_kofax = Y for the given 
--     document_id
-----------------------------------------------

FUNCTION deactivate_invoice
(
   p_document_id IN NUMBER
)
RETURN VARCHAR2 
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   ln_doc_id_count    NUMBER;    
BEGIN

   SELECT COUNT(1)
   INTO   ln_doc_id_count
   FROM   xxap_inv_scanned_file
   WHERE  to_char(import_id) = to_char(p_document_id)
   AND    nvl(active_flag,'Y') = 'N';
   
   IF ln_doc_id_count = 0 THEN
      write_kofax_error_log('Invalid document ID passed for deletion : '||p_document_id);
      COMMIT;
      RETURN 'E';
   END IF;
   
   UPDATE xxap_inv_scanned_file
   SET    deleted_in_kofax = 'Y',
          last_update_date = sysdate,
          last_updated_by = fnd_global.user_id          
   WHERE  import_id = p_document_id
   AND    nvl(active_flag,'Y') = 'N';

   COMMIT;

   RETURN 'S';

EXCEPTION
   WHEN OTHERS THEN
      write_kofax_error_log('Unexpected error encountered while deleting document id : '||p_document_id||' Error is : '||SQLERRM);
      ROLLBACK;  
      RETURN 'E';
END deactivate_invoice;

------------------------------------------------
-- Function
--    GET_OUTSTANDING_AMOUNT
-- Purpose
--    Include receiving tolerance rate on
--    the amount calculation. Apply change to
--    fix issue FSC-6021.
------------------------------------------------

FUNCTION get_outstanding_amount
(
   p_po_header_id  NUMBER,
   p_org_id        NUMBER
)
RETURN NUMBER IS
   l_inv_scan_amount     NUMBER;
   l_rcv_opt_tol         NUMBER;
   l_po_remain_amount    NUMBER := 0;

   CURSOR c_scan IS
      SELECT SUM(invoice_amount_exc_gst)
      FROM   xxap_inv_scanned_file xisf
      WHERE  NVL(active_flag, 'Y') = 'Y'
      AND    xisf.po_header_id = p_po_header_id
      AND    NOT EXISTS (SELECT 1 
                         FROM   rcv_transactions x 
                         WHERE  x.po_header_id = xisf.po_header_id
                         AND    x.attribute5 = xisf.import_id);

   CURSOR c_rcv_opt IS
      SELECT (qty_rcv_tolerance / 100)
      FROM   rcv_receiving_parameters_v
      WHERE  organization_id = p_org_id;

   CURSOR c_po IS
      SELECT (((pd.quantity_ordered - pd.quantity_cancelled) - pd.quantity_delivered) * pl.unit_price) amount,
             pll.qty_rcv_tolerance 
      FROM   po_distributions_all pd,
             po_line_locations_all pll,
             po_lines_all pl
      WHERE  pl.po_line_id = pll.po_line_id
      AND    pd.line_location_id = pll.line_location_id
      AND    pd.po_line_id = pll.po_line_id
      AND    pd.po_header_id = pll.po_header_id
      AND    pd.po_header_id = p_po_header_id;

BEGIN

   OPEN c_scan;
   FETCH c_scan INTO l_inv_scan_amount;
   CLOSE c_scan;

   OPEN c_rcv_opt;
   FETCH c_rcv_opt INTO l_rcv_opt_tol;
   CLOSE c_rcv_opt;

   FOR r_po IN c_po LOOP
      l_po_remain_amount := l_po_remain_amount + (r_po.amount * (NVL(r_po.qty_rcv_tolerance, NVL(l_rcv_opt_tol, 0)) + 1));
   END LOOP;

   IF NVL(l_inv_scan_amount, 0) > l_po_remain_amount THEN
      RETURN 0;
   ELSE
      RETURN ROUND((l_po_remain_amount - NVL(l_inv_scan_amount, 0)), 2);
   END IF;

END get_outstanding_amount;

-------------------------------------------------------
-- FUNCTION
--     GET_PO_HEADER_INFO
-- Purpose
--     This function returns a collection as a return 
--     value to the caller. This function is called by 
--     KOFAX for online validation of purchase orders 
--     with Low balances.
-------------------------------------------------------

FUNCTION get_po_header_info
(
   p_po_number IN VARCHAR2,
   p_org_id    IN NUMBER
) 
RETURN xxap_po_header_info_tab PIPELINED
AS
   CURSOR po_header_info_cur IS
      SELECT poh.comments po_description,
             poh.po_header_id po_id,
             poh.vendor_id po_vendor_id,
             pov.segment1 vendor_number,
             pov.vendor_name,
             pov.vendor_name_alt,
             poh.vendor_site_id,
             pvsa.vendor_site_code,
             poh.org_id po_org_id,
             h.name org_short_name,
             NVL(poh.closed_code, 'OPEN') closed_code,
             p.email_address buyer_email,
             preparer.email_address preparer_email,
             requestor.email_address requestor_email,
             -- FSC-6021 Outstanding Amount rounding (arellanod 2017/11/22)
             /*
             (SELECT SUM(((pd.quantity_ordered - pd.quantity_cancelled) - pd.quantity_delivered ) * pl.unit_price) 
              FROM   po_distributions_all pd,
                     po_line_locations_all pll,
                     po_lines_all pl
              WHERE  pl.po_line_id = pll.po_line_id
              AND    pd.line_location_id = pll.line_location_id
              AND    pd.po_line_id = pll.po_line_id
              AND    pd.po_header_id = pll.po_header_id
              AND    pd.po_header_id = poh.po_header_id
             ) - NVL( (SELECT NVL(SUM(invoice_amount_exc_gst), 0) -- Added Sum condition Joy Pinto 23/06/2017
                       FROM   xxap_inv_scanned_file xisf
                       WHERE  NVL(active_flag,'Y') = 'Y'
                       AND    xisf.po_header_id = poh.po_header_id
                       AND    NOT EXISTS (SELECT 1 
                                          FROM   rcv_transactions x 
                                          WHERE  x.po_header_id = poh.po_header_id -- arellanod 09/10/2017 FSC-5411
                                          AND    x.attribute5 = xisf.import_id))
                     , 0) po_outstanding_amount,
             */
             0 po_outstanding_amount,
             poh.attribute_category,
             poh.attribute1,
             poh.attribute2,
             poh.attribute3,
             poh.attribute4,
             poh.attribute5,
             poh.attribute6,
             poh.attribute7,
             poh.attribute8,
             poh.attribute9,
             poh.attribute10,
             poh.attribute11,
             poh.attribute12,
             poh.attribute13,
             poh.attribute14,
             poh.attribute15  
      FROM   po_headers_all poh,
             po_vendor_sites_all pvsa,
             po_vendors pov,
             /* -- arellanod 09/10/2017 FSC-5411
             (SELECT COUNT(item_id) item_id,
                     po_header_id,
                     org_id
              FROM   po_lines_all
              GROUP  BY po_header_id, org_id) lines, 
             */
             per_people_x p,
             hr_operating_units h,
             gl_sets_of_books s,
             (SELECT DISTINCT
                     pod.po_header_id,
                     prh.preparer_id,
                     ppf.email_address
              FROM   po_distributions_all pod,
                     po_req_distributions_all prd,
                     po_requisition_lines_all prl,
                     po_requisition_headers_all prh,
                     per_all_people_f ppf
              WHERE  pod.req_distribution_id = prd.distribution_id
              AND    prl.requisition_line_id = prd.requisition_line_id
              AND    prh.requisition_header_id = prl.requisition_header_id
              AND    prh.preparer_id = ppf.person_id(+)
              AND    TRUNC(SYSDATE) BETWEEN TRUNC(NVL(ppf.effective_start_date(+), SYSDATE - 1)) 
                                    AND     TRUNC(NVL(ppf.effective_end_date(+), SYSDATE + 1))) preparer,
             (SELECT pod.po_header_id,
                     pod.deliver_to_person_id,
                     papf.email_address
              FROM   po_distributions_all pod,
                     /* -- arellanod 09/10/2017 FSC-5411
                     po_line_locations_all poll,
                     po_lines_all pol, 
                     */
                     per_all_people_f papf
              WHERE  1 = 1
              /* -- arellanod 09/10/2017 FSC-5411
              AND    pol.po_line_id = poll.po_line_id
              AND    pod.line_location_id = poll.line_location_id
              AND    pod.po_line_id = poll.po_line_id
              AND    pod.po_header_id = poll.po_header_id
              AND    pod.org_id = pol.org_id
              AND    pod.org_id = poll.org_id
              */
              AND    pod.deliver_to_person_id = papf.person_id(+)
              AND    TRUNC(SYSDATE) BETWEEN TRUNC(NVL(papf.effective_start_date(+), SYSDATE - 1)) 
                                    AND     TRUNC(NVL(papf.effective_end_date(+), SYSDATE + 1))
              /* -- arellanod 09/10/2017 FSC-5411
              AND    pol.line_num = (SELECT MIN(pol1.line_num)
                                     FROM   po_lines_all pol1
                                     WHERE  pol1.po_header_id = pod.po_header_id)
              AND    poll.shipment_num = (SELECT MIN(poll1.shipment_num)
                                          FROM   po_line_locations_all poll1
                                          WHERE  poll1.po_header_id = pod.po_header_id
                                          AND    poll1.po_line_id = poll.po_line_id
                                          AND    poll1.org_id = pod.org_id)
              */
              AND    pod.distribution_num = (SELECT MIN(pod1.distribution_num)
                                             FROM   po_distributions_all pod1
                                             WHERE  pod1.po_header_id = pod.po_header_id
                                             /* -- arellanod 09/10/2017 FSC-5411
                                             AND    pod1.po_line_id = poll.po_line_id
                                             AND    pod1.line_location_id = poll.line_location_id
                                             */
                                             AND    pod1.org_id = pod.org_id)) requestor
      WHERE  poh.vendor_site_id = pvsa.vendor_site_id
      AND    poh.vendor_id = pov.vendor_id
      AND    p.person_id = poh.agent_id
      /* -- arellanod 09/10/2017 FSC-5411
      AND    lines.po_header_id = poh.po_header_id
      */
      AND    poh.po_header_id = requestor.po_header_id(+)
      AND    poh.po_header_id = preparer.po_header_id(+)
      AND    poh.org_id = h.organization_id(+)
      AND    h.set_of_books_id = s.set_of_books_id(+) 
      AND    NVL(poh.authorization_status, 'INCOMPLETE') = 'APPROVED'
      AND    poh.type_lookup_code = 'STANDARD'
      AND    NVL(poh.cancel_flag, 'N') = 'N'
      AND    NVL(poh.approved_flag, 'N') = 'Y'
      AND    NVL(poh.closed_code, 'OPEN') NOT IN ('FINALLY CLOSED', 'CANCELLED')
      AND    poh.segment1 = p_po_number
      AND    poh.org_id = NVL(p_org_id, poh.org_id);

   lt_data              xxap_po_header_info_tab := xxap_po_header_info_tab();
   ln_po_header_id      po_headers_all.po_header_id%TYPE;
   ln_org_id            po_headers_all.org_id%TYPE;
   ln_amount_remain     NUMBER;
BEGIN
   -- FSC-6021 arellanod 2017/11/22
   SELECT po_header_id,
          org_id
   INTO   ln_po_header_id,
          ln_org_id
   FROM   po_headers_all
   WHERE  segment1 = p_po_number
   AND    org_id = p_org_id;

   ln_amount_remain := get_outstanding_amount(ln_po_header_id, ln_org_id);

   FOR p IN po_header_info_cur LOOP
      PIPE ROW (xxap_po_header_info_type
                  (p.po_org_id,
                   p.po_description,
                   p.requestor_email,
                   p.preparer_email,
                   p.buyer_email,
                 --FSC-6021 arellanod 2017/11/22
                 --p.po_outstanding_amount,
                   ln_amount_remain,
                   p.vendor_site_code,
                   p.vendor_number,
                   p.vendor_name,
                   p.vendor_name_alt,
                   p.org_short_name,
                   p.closed_code,
                   p.attribute_category,
                   p.attribute1,
                   p.attribute2,
                   p.attribute3,
                   p.attribute4,
                   p.attribute5,
                   p.attribute6,
                   p.attribute7,
                   p.attribute8,
                   p.attribute9,
                   p.attribute10,
                   p.attribute11,
                   p.attribute12,
                   p.attribute13,
                   p.attribute14,
                   p.attribute15,
                   p.po_id)
               ); 
   END LOOP;
    
   RETURN;
EXCEPTION
   WHEN others THEN
      RETURN;
END get_po_header_info;

END XXAP_KOFAX_INTEGRATION_PKG;
/
