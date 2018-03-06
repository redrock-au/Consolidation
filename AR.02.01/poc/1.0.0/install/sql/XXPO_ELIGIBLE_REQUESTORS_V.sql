/*$Header: svn://d02584/consolrepos/branches/AR.02.01/poc/1.0.0/install/sql/XXPO_ELIGIBLE_REQUESTORS_V.sql 2981 2017-11-14 08:13:57Z svnuser $*/
CREATE OR REPLACE VIEW apps.xxpo_eligible_requestors_v
(
   preparer_id,
   preparer_name,
   user_name,
   org_id,
   import_id
)  AS
/*
SELECT prha.preparer_id,
       ppf.full_name,
       fu.user_name,
       pha.org_id,
       MIN(xisf.import_id) import_id
FROM   xxap_inv_scanned_file xisf,
       po_requisition_headers_all prha,
       po_requisition_lines_all prla,
       po_req_distributions_all prda,
       po_distributions_all pda,
       po_headers_all pha,
       fnd_user fu,
       per_all_people_f ppf
WHERE  xisf.import_status = 'VALIDLOAD'  
AND    xisf.email_Sent_date IS NULL
AND    xisf.po_header_id IS NOT NULL
AND    xisf.po_number = pha.segment1
AND    pda.po_header_id = pha.po_header_id
AND    prda.requisition_line_id = prla.requisition_line_id
AND    prda.distribution_id = pda.req_distribution_id
AND    prha.requisition_header_id = prla.requisition_header_id
AND    fu.employee_id = prha.preparer_id
AND    ppf.person_id = fu.employee_id
AND    TRUNC(SYSDATE) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
AND    NOT EXISTS (SELECT 1 
                   FROM   ap_invoices_all aia
                   WHERE  aia.invoice_num = xisf.invoice_num
                   AND    pha.vendor_id = aia.vendor_id)
GROUP  BY 
       prha.preparer_id,
       fu.user_name,
       ppf.full_name ,
       pha.org_id
ORDER  BY 
       fu.user_name;
*/
SELECT xisf.preparer_id,
       ppf.full_name,
       fu.user_name,
       xisf.org_id,
       MIN(xisf.import_id) import_id
FROM   xxap_inv_scanned_file xisf,
       fnd_user fu,
       per_all_people_f ppf
WHERE  xisf.import_status = 'VALIDLOAD'
AND    xisf.email_sent_date IS NULL
AND    xisf.po_header_id IS NOT NULL
AND    xisf.preparer_id = fu.employee_id
AND    fu.employee_id = ppf.person_id
AND    TRUNC(SYSDATE) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
AND    NOT EXISTS (SELECT 1
                   FROM   ap_invoices_all aia
                   WHERE  aia.invoice_num = xisf.invoice_num
                   AND    aia.vendor_id = xisf.vendor_internal_id)
GROUP  BY
       xisf.preparer_id,
       ppf.full_name,
       fu.user_name,
       xisf.org_id;


