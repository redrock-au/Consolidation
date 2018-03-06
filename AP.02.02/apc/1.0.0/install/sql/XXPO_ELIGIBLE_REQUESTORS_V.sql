/*$Header: svn://d02584/consolrepos/branches/AP.02.02/apc/1.0.0/install/sql/XXPO_ELIGIBLE_REQUESTORS_V.sql 2999 2017-11-17 04:36:48Z svnuser $*/
CREATE OR REPLACE VIEW apps.xxpo_eligible_requestors_v
(
   preparer_id,
   preparer_name,
   user_name,
   org_id,
   import_id
)  AS
SELECT xisf.preparer_id,
       ppf.full_name,
       fu.user_name,
       xisf.org_id,
       MIN(xisf.import_id) import_id
FROM   xxap_inv_scanned_file xisf,
       fnd_user fu,
       per_all_people_f ppf
WHERE  xisf.import_status = 'VALIDLOAD'
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


