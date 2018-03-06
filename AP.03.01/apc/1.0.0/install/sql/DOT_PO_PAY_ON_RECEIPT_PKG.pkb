create or replace PACKAGE BODY dot_po_pay_on_receipt_pkg
AS
/**************************************************************************************
**
**  $Header: svn://d02584/consolrepos/branches/AP.03.01/apc/1.0.0/install/sql/DOT_PO_PAY_ON_RECEIPT_PKG.pkb 1090 2017-06-21 06:07:37Z svnuser $
**
**  Purpose: Remediate custom ERS process DOI_PO_ERS_AUTOINVOICE_PKG. Please refer to 
**           notes below for the detailed improvements and fixes. Since none of routines
**           from the old version can be re-used, the business agree that overhaul is 
**           necessary.
**
**  Author: Dart Arellano UXC Red Rock Consulting
**
**  Date: 14-July-2015
**
**  History: Refer to Source Control
**
**************************************************************************************/

/*  Release Notes:
**
** 	New features and fixes	                   Description
** -----------------------------------------   -----------------------------------------------------
** 	1. Use a custom tracking table for Pay     Advantages:
** 	   On Receipt Invoices.                    1. Able to quickly identify new 
**                                                transactions (receive, correct or RTV).
** 	                                           2. Able to summarise receipt line transactions
**                                                to arrive with net value before creating 
**                                                invoice distribution line.
** 	                                           3. Able to accurately validate receipt transactions
**                                                against PO.
**  2. Remove command that truncates the       This is a coding issue from the old version.
**     interface rejection messages.
**  3. Fix and improve data selectivity        Add data grouping at Receipt level instead of
**                                             transaction line level. Fixes the issue with invoice
**                                             distribution item and tax lines doubling up.
**  4. Fix duplicate invoice number issue	     Invoice Number is unique at vendor level by org_id
** 	                                           AP.AP_INVOICES_U2 unique constraint 
** 	                                           (VENDOR_ID, INVOICE_NUM and ORG_ID)
**  5. Cancelled Invoice Exception Handler     Add exception handler for cancelled invoices for 
**                                             receipt correction resulting to Credit Memo.
**  6. Optimise process execution	             1. Remove repeating validations.
** 	                                           2. Tune the SQL queries to speed-up data collection.
** 	                                           3. Remove un-used SQL query that parses tree walking
**                                                (time consuming).
**                                             4. Remove unnecessary calculations:
**                                                * PO Distribution remaining quantity against 
**                                                  receiving transaction (program trying to work
**                                                  out INVOICED to PENDING to validate correction
**                                                  entries)
**                                                * Tax Calculation
**                                                * Multi-currency conversion
**  7. Error Report Persistent Flag	           Include a report flag that can be updated by user 
**                                             using a script. Script will update and remove persistent
**                                             errors from the report.
**  8. Accounting Date	                       Include Accounting Date parameter 
**                                             (default value is system date).
**  9. Payables Open/Close Period Validation   Include accounting date validation against Open/Close
**                                             Period.
** 10. Process History                         Permanently store information of processed ERS receipts
**                                             in a custom table. Useful for exception analysis.
** -----------------------------------------   -----------------------------------------------------
*/

-- Defaulting Rules
-- No point parameterizing these values
-- ERS Implementation Date 01-MAY-2015
gd_cutover_date         DATE          := TO_DATE('01-MAY-2015');
gv_source               VARCHAR2(25)  := 'ERS';
gn_application_id       NUMBER        := 200;   -- SQLAP
gv_invoiced_status      VARCHAR2(30)  := 'INVOICED';
gv_exception_status     VARCHAR2(30)  := 'ERS EXCEPTION';
-- Instance is not multi-currency hence adding
-- multi-currency routines is not required
gv_base_currency        VARCHAR2(15)  := 'AUD';
-- Global Variable
gd_gl_date              DATE;
gn_request_id           NUMBER;
gn_org_id               NUMBER;
gn_user_id              NUMBER;
gn_login_id             NUMBER;
gn_default_user         NUMBER;
gv_batch_name           ap_batches.batch_name%TYPE;
gv_procedure_name       VARCHAR2(150);
gv_auto_tax_calc_flag   VARCHAR2(1);
gv_run_import           VARCHAR2(1);
gv_desc_sql             VARCHAR2(32000) := 'SELECT COUNT(DISTINCT reql.requisition_header_id) ' ||
                                           'FROM po_requisition_lines_all reql, ' ||
                                           'po_req_distributions_all reqd, ' ||
                                           'po_distributions_all pod ' ||
                                           'WHERE pod.req_distribution_id = reqd.distribution_id ' ||
                                           'AND reqd.requisition_line_id = reql.requisition_line_id ' ||
                                           'AND pod.po_distribution_id IN (';

--                                                 1         2         3         4         5         6         7         8         9        10        11        12        13        14        15        16        17        18        19        20        21        22        23        24        25        26        27
--                                        12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345
gv_heading1             VARCHAR2(600) := 'Supplier No  Supplier Name                             Invoice Number                  Invoice Date   Invoice Amount  Dist      Dist Amount  Charge Account                            Tax Code                   PO Number        Receipt Number   Entered By            Status';
gv_heading2             VARCHAR2(600) := '-----------  ----------------------------------------  ------------------------------  ------------  ---------------  ----  ---------------  ----------------------------------------  -------------------------  ---------------  ---------------  --------------------  ------';
--                                        242666       RED ROCK CONSULTING                       8989131                         15-JUN-15       -999999999.00     1    -999999999.00  S-86004-030-2100-0000-0000-00000000       G17 Tax 10%                251885           313695           PANGALT               S
gv_end_text             VARCHAR2(150) := '*** End of Report ***';
gv_end_of_report        VARCHAR2(600) := LPAD(gv_end_text, ((LENGTH(gv_heading1) - LENGTH(gv_end_text)) / 2),  ' ');

SUBTYPE por_rec_type IS dot_po_pay_on_receipt_hist%ROWTYPE;
TYPE por_tab_type IS TABLE OF por_rec_type INDEX BY binary_integer;

TYPE interim_line_rec_type IS RECORD
(
   shipment_header_id     NUMBER,
   shipment_line_id       NUMBER,
   po_distribution_id     NUMBER,
   line_num               NUMBER,
   quantity               NUMBER,
   amount                 NUMBER,
   status                 VARCHAR2(1),
   err_message            VARCHAR2(640)
);

TYPE interim_tab_type IS TABLE OF interim_line_rec_type INDEX BY binary_integer;

TYPE tax_rec_type IS RECORD
(
   line_group_num   NUMBER,
   tax_id           NUMBER,
   tax_code         VARCHAR2(150),
   tax_rate         NUMBER,
   tax_ccid         NUMBER,
   tax_amount       NUMBER
);

TYPE tax_tab_type IS TABLE OF tax_rec_type INDEX BY binary_integer;

interim_lines     interim_tab_type;

--------------------------
PROCEDURE interface_report
(
   p_shipment_header_id   NUMBER,
   p_vendor_site_id       NUMBER,
   p_report_tab           report_line_tab_type,
   p_errors_tab           errors_tab_type,
   p_verify_only          VARCHAR2
)
IS
   PRAGMA             AUTONOMOUS_TRANSACTION;
   do_key_commit      BOOLEAN;

BEGIN
   IF p_verify_only = 'N' THEN
      IF p_report_tab.COUNT > 0 THEN
         FORALL rep IN p_report_tab.FIRST .. p_report_tab.LAST
         INSERT INTO dot_po_pay_on_receipt_report
         VALUES p_report_tab(rep);

         do_key_commit := TRUE;
      END IF;

      IF p_errors_tab.COUNT > 0 THEN
         FORALL err IN p_errors_tab.FIRST .. p_errors_tab.LAST
         INSERT INTO dot_po_pay_on_receipt_errors
         VALUES(p_shipment_header_id,
                p_vendor_site_id,
                gn_request_id,
                p_errors_tab(err),
                gn_user_id,
                SYSDATE,
                SYSDATE,
                gn_user_id);

         do_key_commit := TRUE;
      END IF;

   ELSE
      DELETE FROM dot_po_pay_on_receipt_report
      WHERE  request_id = gn_request_id;

      DELETE FROM dot_po_pay_on_receipt_errors
      WHERE  request_id = gn_request_id;

      do_key_commit := TRUE;
   END IF;

   IF do_key_commit THEN
      COMMIT;
   END IF;

END interface_report;

-----------------------------
PROCEDURE handle_other_errors
(
   p_shipment_header_id  NUMBER
)
IS
BEGIN
   NULL;
END handle_other_errors;

-------------------------------------------------------
-- PROCEDURE
--     ATTACH_URL
-- Purpose
--         To Attach the URL to the Invoices
-------------------------------------------------------
PROCEDURE attach_url
(
   p_batch_name          IN   VARCHAR2,
   p_org_id              IN   NUMBER,
   p_user_id             IN   NUMBER,
   p_login_id            IN   NUMBER,
   p_source              IN   VARCHAR2,
   x_status              OUT  VARCHAR2
)
IS
PRAGMA AUTONOMOUS_TRANSACTION;

   CURSOR c_get_unattached_invoices IS
      SELECT aia.invoice_id,
             xxap_invoice_import_pkg.get_attachment_url(aia.invoice_id) attachment_url,
             aia.invoice_num,
             aia.vendor_id
      FROM   ap_invoices_all aia, 
             ap_batches_all aba
      WHERE  aia.org_id = p_org_id 
      AND    aia.batch_id = aba.batch_id
      AND    aia.invoice_type_lookup_code = 'STANDARD'
      AND    aba.batch_name = p_batch_name
      AND    NOT EXISTS
             (
                 SELECT 1 
                 FROM   fnd_attached_documents fad,
                        fnd_document_categories_tl fdc
                 WHERE  fad.pk1_value = aia.invoice_id
                 AND    fad.category_id = fdc.category_id
                 AND    fdc.user_name = 'Scanned Invoice'
             ); 
             
   CURSOR c_get_category_id IS
      SELECT category_id
      FROM   fnd_document_categories_tl
      WHERE  user_name = 'Scanned Invoice';

   ln_category_id          NUMBER := 0;
   ln_media_id             NUMBER;
   l_rowid                 ROWID;
   ln_document_id          NUMBER;
   ln_attached_document_id NUMBER;
   ln_seq_num              NUMBER;   
   lv_invoice_num          ap_invoices_all.invoice_num%TYPE;
   lv_description          fnd_documents_tl.description%TYPE   := 'View Invoice';
   --lv_filename             fnd_documents_tl.file_name%TYPE; -- URL of the Webpage image
   l_pk1_value             fnd_attached_documents.pk1_value%TYPE; 

BEGIN
   gv_procedure_name := 'attach_url';
   x_status          := 'S'; 
   
   OPEN c_get_category_id;
   FETCH c_get_category_id INTO ln_category_id;
   CLOSE c_get_category_id;
   
   FOR c_rec IN c_get_unattached_invoices LOOP
   
      BEGIN
      
         SELECT FND_DOCUMENTS_S.NEXTVAL,
                FND_ATTACHED_DOCUMENTS_S.NEXTVAL
         INTO   ln_document_id,
                ln_attached_document_id
         FROM   dual;

         SELECT nvl(MAX(seq_num),0) + 10
         INTO   ln_seq_num
         FROM   fnd_attached_documents
         WHERE  pk1_value = c_rec.invoice_id
         AND    entity_name = 'AP_INVOICES'; /* As this ap_invoices related and we want those attachments.*/
      
         fnd_documents_pkg.insert_row(
         x_rowid                         => l_rowid,
         x_document_id                   => ln_document_id,
         x_creation_date                 => SYSDATE,
         x_created_by                    => p_login_id,
         x_last_update_date              => SYSDATE,
         x_last_updated_by               => p_user_id,
         x_last_update_login             => p_login_id,
         x_datatype_id                   => 5, -- Web Page URL link to image
         x_category_id                   => ln_category_id,
         x_security_type                 => 2,
         x_publish_flag                  => 'Y',
         x_usage_type                    => 'O',
         x_language                      => 'US',
         x_description                   => lv_description,
         x_file_name                     => c_rec.attachment_url,
         x_media_id                      => ln_media_id
        );
      
         fnd_documents_pkg.insert_tl_row (
         x_document_id                  => ln_document_id,
         x_creation_date                => sysdate,
         x_created_by                   => p_user_id,
         x_last_update_date             => sysdate,
         x_last_updated_by              => p_user_id,
         x_last_update_login            => p_login_id,
         x_language                     => 'US',
         x_description                  => lv_description,
         x_file_name                    => c_rec.attachment_url,
         x_media_id                     => ln_media_id
         );
         
         fnd_attached_documents_pkg.insert_row (
         x_rowid                        => l_rowid,
         x_attached_document_id         => ln_attached_document_id,
         x_document_id                  => ln_document_id,
         x_creation_date                => SYSDATE,
         x_created_by                   => p_user_id,
         x_last_update_date             => SYSDATE,
         x_last_updated_by              => p_user_id,
         x_last_update_login            => p_login_id,
         x_seq_num                      => ln_seq_num,
         x_entity_name                  => 'AP_INVOICES',
         x_column1                      => NULL,
         x_pk1_value                    => c_rec.invoice_id,
         x_pk2_value                    => NULL,
         x_pk3_value                    => NULL,
         x_pk4_value                    => NULL,
         x_pk5_value                    => NULL,
         x_automatically_added_flag     => 'N',
         x_datatype_id                  => 5,
         x_category_id                  => ln_category_id,
         x_security_type                => 2,
         x_publish_flag                 => 'Y',
         x_language                     => 'US',
         x_description                  => lv_description,
         x_file_name                    => c_rec.attachment_url,
         x_media_id                     => ln_media_id
         );
         
         UPDATE xxap_inv_scanned_file
         SET    po_attachment_complete = 'Y',
                last_update_date = sysdate,
                last_updated_by = p_user_id
         WHERE  invoice_num = c_rec.invoice_num
         AND    vendor_internal_id = c_rec.vendor_id;
         
         COMMIT;
         
         FND_FILE.PUT_LINE(FND_FILE.LOG, 'Successfully attached URL '||c_rec.attachment_url||' to Invoice Number : ' || c_rec.invoice_num);
         
      EXCEPTION
      WHEN OTHERS THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Error in attaching Invoice Number           : ' || c_rec.invoice_num);
      x_status := 'F';
      END;
      
   END LOOP;   
      
EXCEPTION
   WHEN OTHERS THEN
      x_status := 'F';
      ROLLBACK;
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Unexpected Error in attach_url           : ' || SQLERRM);
      raise_application_error(-20501, gv_procedure_name || ' ' || SQLERRM);
  
END attach_url;

----------------------------
PROCEDURE run_pay_on_receipt
(
   p_errbuf            OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_receipt_num       IN  VARCHAR2,
   p_aging_period      IN  NUMBER,
   p_run_import        IN  VARCHAR2,
   p_validate_batch    IN  VARCHAR2,
   p_gl_date           IN  VARCHAR2
)
IS
   CURSOR c_por IS
      SELECT 1 rec_type,
             r.shipment_header_id,
             r.vendor_site_id,
             r.shipment_line_id,
             r.po_distribution_id,
             COUNT(1) rcv_line_count
      FROM   rcv_transactions r,
             rcv_shipment_headers s,
             po_headers_all p
      WHERE  (
               TRUNC(r.transaction_date) >= gd_cutover_date 
               AND
               r.transaction_date <= (SYSDATE - NVL(p_aging_period, 0))
             )
      AND    r.transaction_type NOT IN ('DELIVER', 'RETURN TO RECEIVING')
      AND    r.destination_context = 'RECEIVING'
      AND    r.shipment_header_id = s.shipment_header_id
      AND    s.receipt_num = NVL(p_receipt_num, s.receipt_num)
      AND    r.po_header_id = p.po_header_id
      AND    p.org_id = gn_org_id
      AND    p.pay_on_code = 'RECEIPT'
      AND    NOT EXISTS (SELECT 'x'
                         FROM   dot_po_pay_on_receipt_hist h
                         WHERE  h.transaction_id = r.transaction_id)
      GROUP  BY 
             r.shipment_header_id, 
             r.vendor_site_id,
             r.shipment_line_id, 
             r.po_distribution_id
      UNION ALL
      SELECT  2 rec_type,
             -1 shipment_header_id,
             -1 vendor_site_id,
             -1 shipment_line_id,
             -1 po_distribution_id,
              0 rcv_line_count
      FROM   dual
      ORDER  BY 1, 2, 3, 4;

   CURSOR c_rcv_status (p_transaction_id  NUMBER) IS
      SELECT NVL(status, gv_exception_status) status
      FROM   dot_po_pay_on_receipt_hist
      WHERE  transaction_id = p_transaction_id;

   CURSOR c_req (p_request_id  NUMBER) IS
      SELECT r.request_date,
             p.user_concurrent_program_name
      FROM   fnd_concurrent_requests r,
             fnd_concurrent_programs_tl p
      WHERE  r.concurrent_program_id = p.concurrent_program_id
      AND    r.request_id = p_request_id;

   CURSOR c_prep IS
      SELECT shipment_header_id,
             vendor_site_id,
             request_id,
             COUNT(1) line_count
      FROM   dot_po_pay_on_receipt_report
      WHERE  persist_flag = 'Y'
      AND    status = 'E'
      GROUP  BY shipment_header_id,
                vendor_site_id,
                request_id
      ORDER  BY request_id;

   r_por                      c_por%ROWTYPE;
   r_req                      c_req%ROWTYPE;
   r_prep                     c_prep%ROWTYPE;

   ln_index                   NUMBER := 0;
   ln_curr_ship_id            NUMBER;
   ln_curr_ven_site_id        NUMBER;
   lv_group_id                VARCHAR2(150);
   lv_receipt_num             rcv_shipment_headers.receipt_num%TYPE;
   lv_invoice_num             ap_invoices_all.invoice_num%TYPE;
   lv_invoice_date            VARCHAR2(60);
   ln_vendor_id               NUMBER;
   ln_vendor_site_id          NUMBER;
   ln_invoice_count           NUMBER := 0;
   ln_invoice_batch_count     NUMBER;
   lv_pay_on_receipt_flag     VARCHAR2(1);
   lv_status                  VARCHAR2(1);
   lv_rcv_status              VARCHAR2(60);
   lv_completion_text         fnd_concurrent_requests.completion_text%TYPE;
   ln_batch_id                NUMBER;
   ln_ap_batch_id             NUMBER;  -- usually not consistent with group
   ln_set_of_books_id         NUMBER;
   ln_apxiimpt_req_id         NUMBER;
   ln_apprvl_req_id           NUMBER;
   lv_log                     VARCHAR2(600);
   lv_interface_status        VARCHAR2(30);
   lv_period_name             VARCHAR2(30);

   --line
   ln_line_num                NUMBER;
   ln_quantity                NUMBER;
   ln_amount                  NUMBER;
   ln_exception               NUMBER;

   validate_batch             BOOLEAN;
   adjust_invoice             BOOLEAN;
   por_hist_tab               por_tab_type;  
   report_line_tab            report_line_tab_type;
   preimport_errors_tab       errors_tab_type;

   -- SRS
   srs_wait                   BOOLEAN;
   srs_phase                  VARCHAR2(30);
   srs_status                 VARCHAR2(30);
   srs_dev_phase              VARCHAR2(30);
   srs_dev_status             VARCHAR2(30);
   srs_message                VARCHAR2(240);
   
   -- ERS Enhancements Joy Pinto 18-May-2017
   lv_url_attachment_status VARCHAR2(240);
   
   PROCEDURE print_output
   IS
      lv_output               VARCHAR2(1000);
   BEGIN
      IF report_line_tab.COUNT > 0 THEN
         FOR r IN 1 .. report_line_tab.COUNT LOOP
            lv_output := RPAD(SUBSTR(NVL(report_line_tab(r).vendor_number, ' '), 1, 11), 11, ' ') || '  ' || 
                         RPAD(SUBSTR(NVL(report_line_tab(r).vendor_name, ' '), 1, 40), 40, ' ') || '  ' ||
                         RPAD(SUBSTR(NVL(report_line_tab(r).invoice_number, ' '), 1, 30), 30, ' ') || '  ' ||
                         RPAD(NVL(TO_CHAR(report_line_tab(r).invoice_date, 'DD-MON-RR'), ' '), 12, ' ') || '  ' ||
                         LPAD(NVL(TO_CHAR(report_line_tab(r).invoice_amount, 'fm999999999.00'), ' '), 15, ' ') || '  ' ||
                         LPAD(NVL(TO_CHAR(report_line_tab(r).distribution_num, 'fm999'), ' '), 4, ' ') || '  ' ||
                         LPAD(NVL(TO_CHAR(report_line_tab(r).distribution_amount, 'fm999999999.00'), ' '), 15, ' ') || '  ' ||
                         RPAD(NVL(report_line_tab(r).charge_account, ' '), 40, ' ') || '  ' ||
                         RPAD(NVL(report_line_tab(r).tax_code, ' '), 25, ' ') || '  ' ||
                         RPAD(NVL(report_line_tab(r).po_number, ' '), 15, ' ') || '  ' ||
                         RPAD(NVL(report_line_tab(r).receipt_number, ' '), 15, ' ') || '  ' ||
                         RPAD(NVL(SUBSTR(report_line_tab(r).entered_by, 1, 20), ' '), 20, ' ') || '  ' ||
                         report_line_tab(r).status;
            FND_FILE.PUT_LINE(FND_FILE.OUTPUT, lv_output);
         END LOOP;
      END IF;

      IF lv_status = 'E' THEN
         IF preimport_errors_tab.COUNT = 1 THEN
            lv_output := 'Error: ' || preimport_errors_tab(1); 
            FND_FILE.PUT_LINE(FND_FILE.OUTPUT, lv_output);
         ELSIF preimport_errors_tab.COUNT > 1 THEN
            FOR err IN 1 .. preimport_errors_tab.COUNT LOOP
               IF err = 1 THEN
                  lv_output := 'Errors: ' || err || '. ' || preimport_errors_tab(err);
                  FND_FILE.PUT_LINE(FND_FILE.OUTPUT, lv_output);
               ELSE
                  FND_FILE.PUT_LINE(FND_FILE.OUTPUT, '        ' || err || '. ' || preimport_errors_tab(err));
               END IF;
            END LOOP;
         END IF;
      END IF;

      FND_FILE.NEW_LINE(FND_FILE.OUTPUT);
   END print_output;

BEGIN
   gv_procedure_name := 'run_pay_on_receipt';

   gn_request_id := FND_GLOBAL.CONC_REQUEST_ID;

   lv_pay_on_receipt_flag := FND_PROFILE.VALUE('POC_PAY_ON_RECEIPT');  
   ln_set_of_books_id := FND_PROFILE.VALUE('GL_SET_OF_BKS_ID');

   gn_org_id := FND_PROFILE.VALUE('ORG_ID');
   gn_user_id := FND_PROFILE.VALUE('USER_ID');
   gn_login_id := FND_PROFILE.VALUE('LOGIN_ID');
   gv_run_import := NVL(p_run_import, 'N');

   SELECT auto_tax_calc_flag
   INTO   gv_auto_tax_calc_flag
   FROM   ap_system_parameters;

   SELECT user_id
   INTO   gn_default_user
   FROM   fnd_user
   WHERE  user_name = 'FEEDER_SYSTEM';

   OPEN c_req (gn_request_id);
   FETCH c_req INTO r_req;
   CLOSE c_req;

   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Request ID           : ' || gn_request_id);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Request Date         : ' || TO_CHAR(r_req.request_date, 'DD/MM/YYYY HH24:MI:SS'));
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Receipt Number       : ' || p_receipt_num);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Aging Period         : ' || p_aging_period);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Create Batch         : ' || p_run_import);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Validate Batch       : ' || p_validate_batch);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'GL Date              : ' || p_gl_date);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Set of Books ID      : ' || ln_set_of_books_id);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Pay On Receipt (Y/N) : ' || NVL(lv_pay_on_receipt_flag, 'N'));
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Payables Options     : Automatic Tax Calculation (' || gv_auto_tax_calc_flag || ')');

   -- Output Report
   -------------------------------------------------------------------------------------------------------------------------
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'Concurrent Program       : ' || r_req.user_concurrent_program_name);
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'Request ID               : ' || gn_request_id);
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'Request Date             : ' || TO_CHAR(r_req.request_date, 'DD/MM/YYYY HH24:MI:SS'));
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'Set of Books ID          : ' || ln_set_of_books_id);
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'Pay On Receipt Enabled   : ' || NVL(lv_pay_on_receipt_flag, 'N'));
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, '');
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'Run Parameters');
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'Receipt Number    : ' || p_receipt_num);
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'Aging Period      : ' || p_aging_period);
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'Create Batch      : ' || p_run_import);
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'Validate Batch    : ' || p_validate_batch);
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'GL Date           : ' || p_gl_date);
   -------------------------------------------------------------------------------------------------------------------------

   validate_batch := FALSE;

   gd_gl_date := TRUNC(SYSDATE);
   IF p_gl_date IS NOT NULL THEN
      gd_gl_date := FND_DATE.CANONICAL_TO_DATE(p_gl_date);
   END IF;

   BEGIN
      SELECT period_name
      INTO   lv_period_name
      FROM   gl_period_statuses
      WHERE  set_of_books_id = ln_set_of_books_id
      AND    application_id = gn_application_id
      AND    gd_gl_date BETWEEN start_date AND end_date
      AND    closing_status = 'O';
   EXCEPTION
      WHEN no_data_found THEN
         -- Output Report
         ------------------------------------------------------------------------------------------------
         FND_FILE.NEW_LINE(FND_FILE.OUTPUT);
         FND_FILE.PUT_LINE(FND_FILE.OUTPUT, gv_heading1);
         FND_FILE.PUT_LINE(FND_FILE.OUTPUT, gv_heading2);
         FND_FILE.NEW_LINE(FND_FILE.OUTPUT);
         FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'Accounting date ' || gd_gl_date || ' not in an open period.');
         FND_FILE.NEW_LINE(FND_FILE.OUTPUT);
         FND_FILE.PUT_LINE(FND_FILE.OUTPUT, gv_end_of_report);
         ------------------------------------------------------------------------------------------------
         p_retcode := 2;
         RETURN;
   END;

   IF NVL(lv_pay_on_receipt_flag, 'N') = 'N' THEN
      -- Output Report
      ------------------------------------------------------------
      FND_FILE.NEW_LINE(FND_FILE.OUTPUT);
      FND_FILE.PUT_LINE(FND_FILE.OUTPUT, gv_heading1);
      FND_FILE.PUT_LINE(FND_FILE.OUTPUT, gv_heading2);
      FND_FILE.NEW_LINE(FND_FILE.OUTPUT);
      FND_FILE.PUT_LINE(FND_FILE.OUTPUT, gv_end_of_report);
      ------------------------------------------------------------
      RETURN;
   ELSE
      FND_MESSAGE.SET_NAME('PO', 'PO_INV_CR_ERS_BATCH_DESC');
      gv_batch_name := FND_MESSAGE.GET;
    
      SELECT ap_batches_s.NEXTVAL
      INTO   ln_batch_id 
      FROM   dual;
    
      gv_batch_name := gv_batch_name || '/' || TO_CHAR(SYSDATE) || '/' || TO_CHAR(ln_batch_id);     
      -- Output Report
      ----------------------------------------------------------------------------
      FND_FILE.PUT_LINE(FND_FILE.OUTPUT, 'Batch Name        : ' || gv_batch_name);
      ----------------------------------------------------------------------------
   END IF;

   -- Output Report
   --------------------------------------------------
   FND_FILE.NEW_LINE(FND_FILE.OUTPUT);
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, gv_heading1);
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, gv_heading2);
   --------------------------------------------------

   /*************************************************************/
   /* Print Persistent Error Report                             */
   /* Admin script is provided to update persistent error       */
   /* report.                                                   */
   /*************************************************************/
   OPEN c_prep;
   LOOP
      FETCH c_prep INTO r_prep;
      EXIT WHEN c_prep%NOTFOUND;

      report_line_tab.DELETE;
      preimport_errors_tab.DELETE;

      lv_status := 'E';

      SELECT shipment_header_id,
             vendor_site_id,
             request_id,
             vendor_number,
             vendor_name,
             invoice_number,
             invoice_date,
             invoice_amount,
             distribution_num,
             distribution_amount,
             charge_account,
             tax_code,
             po_number,
             receipt_number,
             entered_by,
             persist_flag,
             status,
             created_by,
             creation_date
             BULK COLLECT
      INTO   report_line_tab       
      FROM   dot_po_pay_on_receipt_report
      WHERE  shipment_header_id = r_prep.shipment_header_id
      AND    vendor_site_id = r_prep.vendor_site_id
      AND    request_id = r_prep.request_id;

      SELECT error_text BULK COLLECT
      INTO   preimport_errors_tab
      FROM   dot_po_pay_on_receipt_errors
      WHERE  shipment_header_id = r_prep.shipment_header_id
      AND    vendor_site_id = r_prep.vendor_site_id
      AND    request_id = r_prep.request_id;

      print_output;
   END LOOP;
   CLOSE c_prep;
   /*************************************************************/

   OPEN c_por;
   LOOP
      FETCH c_por INTO r_por;
      EXIT WHEN c_por%NOTFOUND;

      IF lv_group_id IS NULL THEN
         lv_group_id := (r_por.shipment_header_id || '-' || r_por.vendor_site_id);

         IF r_por.rec_type = 2 THEN
            EXIT;
         END IF;
            
         ln_curr_ship_id := r_por.shipment_header_id;
         ln_curr_ven_site_id := r_por.vendor_site_id;
         ln_line_num := 0;
         adjust_invoice := FALSE;
         interim_lines.DELETE;
      ELSE
         IF lv_group_id <> (r_por.shipment_header_id || '-' || r_por.vendor_site_id) THEN
            lv_status := NULL;
            lv_interface_status := NULL;
            report_line_tab.DELETE;
            preimport_errors_tab.DELETE;

            IF interim_lines.COUNT > 0 THEN
               create_invoice_interface(lv_invoice_num,
                                        lv_invoice_date,
                                        ln_curr_ship_id,
                                        ln_vendor_id,
                                        ln_vendor_site_id,
                                        adjust_invoice,
                                        report_line_tab,
                                        preimport_errors_tab,
                                        lv_status);

               interface_report(ln_curr_ship_id, 
                                ln_curr_ven_site_id, 
                                report_line_tab, 
                                preimport_errors_tab,
                                'N');

               IF lv_status = 'S' THEN
                  COMMIT;
                  ln_invoice_count := ln_invoice_count + 1;
                  lv_interface_status := gv_invoiced_status;
               ELSE
                  ROLLBACK;
                  lv_interface_status := gv_exception_status;
               END IF;

               print_output;
            END IF;

            IF por_hist_tab.COUNT > 0 THEN
               FOR trx IN 1 .. por_hist_tab.COUNT LOOP
                  IF por_hist_tab(trx).shipment_header_id = ln_curr_ship_id AND
                     por_hist_tab(trx).vendor_site_id = ln_curr_ven_site_id THEN
                     por_hist_tab(trx).status := lv_interface_status;
                  END IF;
               END LOOP;
            END IF;

            lv_group_id := (r_por.shipment_header_id || '-' || r_por.vendor_site_id);

            IF r_por.rec_type = 2 THEN
               EXIT;
            END IF;

            ln_curr_ship_id := r_por.shipment_header_id;
            ln_curr_ven_site_id := r_por.vendor_site_id;
            ln_line_num := 0;
            adjust_invoice := FALSE;
            interim_lines.DELETE;
         END IF;
      END IF;

      ln_quantity := 0;
      ln_amount := 0;
      ln_exception := 0;
      lv_receipt_num := NULL;

      SELECT COUNT(1)
      INTO   ln_exception
      FROM   dot_po_pay_on_receipt_hist
      WHERE  vendor_site_id = r_por.vendor_site_id
      AND    shipment_header_id = r_por.shipment_header_id
      AND    shipment_line_id = r_por.shipment_line_id
      AND    status = gv_exception_status;

      FOR rcv IN (SELECT rsh.receipt_num,
                         rec.shipment_header_id,
                         rec.shipment_line_id,
                         rec.transaction_id,
                         rec.parent_transaction_id,
                         rec.quantity,
                         rec.amount,
                         rec.transaction_type,
                         rec.po_distribution_id,
                         rec.destination_context,
                         rec.attribute2,
                         rec.attribute3,
                         rec.vendor_id,
                         rec.vendor_site_id
                  FROM   rcv_transactions rec,
                         rcv_shipment_headers rsh
                  WHERE  rec.shipment_header_id = rsh.shipment_header_id 
                  AND    rec.shipment_header_id = r_por.shipment_header_id
                  AND    rec.vendor_site_id = r_por.vendor_site_id
                  AND    rec.shipment_line_id = r_por.shipment_line_id
                  AND    rec.po_distribution_id = r_por.po_distribution_id
                  AND    rec.transaction_type NOT IN ('DELIVER', 'RETURN TO RECEIVING')
                  AND    rec.destination_context = 'RECEIVING'
                  ORDER  BY rec.transaction_id)
      LOOP
         IF lv_receipt_num IS NULL THEN
            lv_receipt_num := rcv.receipt_num;
         END IF;

         OPEN c_rcv_status (rcv.transaction_id);
         FETCH c_rcv_status INTO lv_rcv_status;
         IF c_rcv_status%NOTFOUND THEN
            lv_rcv_status := 'NEW';
         END IF;
         CLOSE c_rcv_status;                    

         IF rcv.transaction_type = 'RECEIVE' THEN
            lv_invoice_num    := rcv.attribute2;
            lv_invoice_date   := rcv.attribute3;
            ln_vendor_id := rcv.vendor_id;
            ln_vendor_site_id := rcv.vendor_site_id;
         END IF;

         IF lv_rcv_status = gv_invoiced_status THEN
            IF rcv.transaction_type = 'RECEIVE' THEN
               adjust_invoice := TRUE;
            END IF;
         ELSIF lv_rcv_status = gv_exception_status THEN
            NULL;
         ELSE
            ln_index := ln_index + 1;
            ln_quantity := ln_quantity + rcv.quantity;
            ln_amount := ln_amount + rcv.amount;
            por_hist_tab(ln_index).receipt_num := rcv.receipt_num;
            por_hist_tab(ln_index).shipment_header_id := rcv.shipment_header_id;
            por_hist_tab(ln_index).vendor_site_id := rcv.vendor_site_id;
            por_hist_tab(ln_index).shipment_line_id := rcv.shipment_line_id;
            por_hist_tab(ln_index).transaction_id := rcv.transaction_id;
            por_hist_tab(ln_index).invoice_num := rcv.attribute2;
            por_hist_tab(ln_index).invoice_date := rcv.attribute3;           
            por_hist_tab(ln_index).request_id := gn_request_id;
            por_hist_tab(ln_index).created_by := gn_user_id;
            por_hist_tab(ln_index).creation_date := SYSDATE;
            por_hist_tab(ln_index).last_update_date := SYSDATE;
            por_hist_tab(ln_index).last_updated_by := gn_user_id;

            --IF ln_exception > 0 THEN
            --   por_hist_tab(ln_index).status := gv_exception_status;
            --END IF;
         END IF;
      END LOOP;

      --IF ln_exception > 0 THEN
      --   ln_quantity := 0;
      --   ln_amount := 0;
      --END IF;

      IF ln_quantity <> 0 OR ln_amount <> 0 THEN
         ln_line_num := ln_line_num + 1;
         interim_lines(ln_line_num).shipment_header_id := r_por.shipment_header_id;
         interim_lines(ln_line_num).shipment_line_id := r_por.shipment_line_id;
         interim_lines(ln_line_num).po_distribution_id := r_por.po_distribution_id;
         interim_lines(ln_line_num).line_num := ln_line_num;
         interim_lines(ln_line_num).quantity := ln_quantity;
         interim_lines(ln_line_num).amount := ln_amount;
      END IF;

   END LOOP;
   CLOSE c_por;

   -- Output Report
   --------------------------------------------------------
   FND_FILE.NEW_LINE(FND_FILE.OUTPUT);
   FND_FILE.PUT_LINE(FND_FILE.OUTPUT, gv_end_of_report);
   --------------------------------------------------------

   FND_FILE.NEW_LINE(FND_FILE.LOG);

   lv_log := 'Receipt Number  Transaction ID  Status';
   FND_FILE.PUT_LINE(FND_FILE.LOG, lv_log);

   lv_log := '--------------  --------------  ------';
   FND_FILE.PUT_LINE(FND_FILE.LOG, lv_log);

   IF por_hist_tab.COUNT > 0 THEN
      FOR trx IN 1 .. por_hist_tab.COUNT LOOP
         lv_log := NULL;
         lv_log := lv_log || RPAD(por_hist_tab(trx).receipt_num, 16, ' ');
         lv_log := lv_log || RPAD(por_hist_tab(trx).transaction_id, 16, ' ');
         lv_log := lv_log || RPAD(por_hist_tab(trx).status, 8, ' ');
         FND_FILE.PUT_LINE(FND_FILE.LOG, lv_log);
      END LOOP;
   END IF;

   IF NVL(p_run_import, 'N') = 'Y' THEN
      -- Update history table
      FORALL trx IN por_hist_tab.FIRST .. por_hist_tab.LAST
      INSERT INTO dot_po_pay_on_receipt_hist
      VALUES por_hist_tab(trx);
      -- Explicitly commit transactions
      COMMIT;

      IF ln_invoice_count > 0 THEN
         ln_apxiimpt_req_id := FND_REQUEST.SUBMIT_REQUEST(application => 'SQLAP',
                                                          program     => 'APXIIMPT',
                                                          description => NULL,
                                                          start_time  => NULL,
                                                          sub_request => FALSE,
                                                          argument1   => gv_source,       -- Source
                                                          argument2   => gv_batch_name,   -- Group
                                                          argument3   => gv_batch_name,   -- Batch Name
                                                          argument4   => NULL,            -- Hold Name
                                                          argument5   => NULL,            -- Hold Reason
                                                          argument6   => NULL,            -- GL Date
                                                          argument7   => 'N',             -- Purge
                                                          argument8   => 'N',             -- Trace Switch
                                                          argument9   => 'N',             -- Debug Switch
                                                          argument10  => 'N',             -- Summary Report
                                                          argument11  => '1000',          -- Commit Batch Size
                                                          argument12  => gn_user_id,      -- User ID
                                                          argument13  => gn_login_id,     -- Login ID
                                                          argument14  => NULL             -- Skip Validation
                                                         );
         COMMIT;

         FND_FILE.NEW_LINE(FND_FILE.LOG);
         FND_FILE.PUT_LINE(FND_FILE.LOG, 'Payables Open Interface Request ID (' || ln_apxiimpt_req_id || ')');

         srs_wait := fnd_concurrent.wait_for_request(ln_apxiimpt_req_id,
                                                     10,
                                                     0,
                                                     srs_phase,
                                                     srs_status,
                                                     srs_dev_phase,
                                                     srs_dev_status,
                                                     srs_message);

         IF NOT (srs_dev_phase = 'COMPLETE' AND
                (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
            SELECT completion_text
            INTO   lv_completion_text
            FROM   fnd_concurrent_requests
            WHERE  request_id = ln_apxiimpt_req_id;

            FND_FILE.PUT_LINE(FND_FILE.LOG, lv_completion_text);
            p_retcode := 2;
         ELSE
            validate_batch := TRUE;
         END IF;

      END IF;
      
      -- Added by Joy Pinto on 11-May-2017 ER Enhancements
      IF lv_pay_on_receipt_flag = 'Y' THEN 
         attach_url (p_batch_name          => gv_batch_name,
                     p_org_id              => gn_org_id,
                     p_user_id             => gn_user_id,
                     p_login_id            => gn_login_id,
                     p_source              => gv_source,
                       x_status              => lv_url_attachment_status
                    );
      END IF;
      
      IF lv_url_attachment_status = 'F' THEN
         p_retcode := 2;
      END IF;

      IF NVL(p_validate_batch, 'N') = 'Y' AND 
         validate_batch THEN

         BEGIN
            SELECT b.batch_id,
                   COUNT(1) invoice_count
            INTO   ln_ap_batch_id,
                   ln_invoice_batch_count
            FROM   ap_batches_all b,
                   ap_invoices_all i
            WHERE  b.batch_name = gv_batch_name
            AND    b.org_id = gn_org_id
            AND    b.batch_id = i.batch_id
            AND    b.org_id = i.org_id
            GROUP  BY b.batch_id;

            IF ln_ap_batch_id IS NOT NULL AND
               ln_invoice_batch_count > 0 
            THEN
               ln_apprvl_req_id := FND_REQUEST.SUBMIT_REQUEST(application => 'SQLAP',
                                                              program     => 'APPRVL',
                                                              description => NULL,
                                                              start_time  => NULL,
                                                              sub_request => FALSE,
                                                              argument1   => 'New',
                                                              argument2   => ln_ap_batch_id,
                                                              argument3   => NULL,
                                                              argument4   => NULL,
                                                              argument5   => NULL,
                                                              argument6   => NULL,
                                                              argument7   => NULL,
                                                              argument8   => NULL,
                                                              argument9   => ln_set_of_books_id,
                                                              argument10  => 'N',
                                                              argument11  => gn_org_id,
                                                              argument12  => '1000',
                                                              argument13  => NULL, 
                                                              argument14  => NULL);
               COMMIT;

               FND_FILE.PUT_LINE(FND_FILE.LOG, 'Invoice Validation Request ID (' || ln_apprvl_req_id || ')');
            END IF;

         EXCEPTION
            WHEN others THEN
               p_retcode := 1;
               FND_FILE.PUT_LINE(FND_FILE.LOG, 'Invoice validation failed. Unable to find batch ' || gv_batch_name || ' ' || SQLERRM);
         END;
      END IF;

   ELSE
      interface_report(ln_curr_ship_id, 
                       ln_curr_ven_site_id, 
                       report_line_tab, 
                       preimport_errors_tab,
                       'Y');
   END IF;

EXCEPTION
   WHEN others THEN
      raise_application_error(-20501, gv_procedure_name || ' ' || SQLERRM);

END run_pay_on_receipt;

---------------------------
PROCEDURE check_invoice_num
(
   p_invoice_num         IN   VARCHAR2,
   p_vendor_id           IN   NUMBER,
   p_adjust_invoice      IN   BOOLEAN,
   p_from_invoice_id     OUT  NUMBER,
   p_approval_status     OUT  VARCHAR2,
   p_count               OUT  NUMBER
)
IS
   ln_exists            NUMBER := 0;
   ln_invoice_id        NUMBER;
   lv_invoice_num       ap_invoices_all.invoice_num%TYPE;
   lv_approval_status   VARCHAR2(150);
BEGIN
   gv_procedure_name := 'check_invoice_num';

   ---------------------------------------
   -- AP.AP_INVOICES_U2 unique constraint 
   -- (VENDOR_ID, INVOICE_NUM and ORG_ID) 
   ---------------------------------------

   lv_invoice_num := p_invoice_num;

   IF p_adjust_invoice THEN
      SELECT COUNT(1)
      INTO   ln_exists
      FROM   ap_invoices_all
      WHERE  (  
                (INSTR(lv_invoice_num, '-ADJ-') > 0 AND invoice_num LIKE lv_invoice_num || '%') 
                OR
                (INSTR(lv_invoice_num, 'CM-') > 0 AND invoice_num LIKE lv_invoice_num || '%') 
             )
      AND    vendor_id = p_vendor_id
      AND    org_id = gn_org_id;

      BEGIN
         SELECT invoice_id,
                ap_invoices_pkg.get_approval_status(ai.invoice_id,
                                                    ai.invoice_amount,
                                                    ai.payment_status_flag,
                                                    ai.invoice_type_lookup_code) approval_status
         INTO   ln_invoice_id,
                lv_approval_status
         FROM   ap_invoices_all ai
         WHERE  ai.invoice_num = REPLACE(REPLACE(lv_invoice_num, '-ADJ-'), 'CM-')
         AND    ai.vendor_id = p_vendor_id
         AND    ai.org_id = gn_org_id;
   
         p_from_invoice_id := ln_invoice_id;
         p_approval_status := lv_approval_status;

      EXCEPTION
         WHEN no_data_found THEN NULL;
      END;

   ELSE
      SELECT COUNT(1)
      INTO   ln_exists
      FROM   ap_invoices_all
      WHERE  invoice_num = lv_invoice_num
      AND    vendor_id = p_vendor_id
      AND    org_id = gn_org_id;
   END IF;

   p_count := ln_exists;

EXCEPTION
   WHEN others THEN
      raise_application_error(-20501, gv_procedure_name || ' ' || SQLERRM);
  
END check_invoice_num;

----------------------------------
PROCEDURE create_invoice_interface
(
   p_invoice_num         IN  VARCHAR2,
   p_invoice_date        IN  VARCHAR2, 
   p_shipment_header_id  IN  NUMBER,
   p_vendor_id           IN  NUMBER,
   p_vendor_site_id      IN  NUMBER,
   p_adjust_invoice      IN  BOOLEAN,
   p_report_out          OUT report_line_tab_type,
   p_error_out           OUT errors_tab_type,
   p_status              OUT VARCHAR2
)
IS
   CURSOR c_vendor (p_vendor_site_id  NUMBER) IS
      SELECT ve.vendor_name,
             ve.segment1 vendor_number,
             si.vendor_id, 
             si.vendor_site_id,
             si.default_pay_site_id,
             NVL(si.pay_group_lookup_code, ve.pay_group_lookup_code) pay_group_lookup_code,
             param.accts_pay_code_combination_id,
             si.payment_method_lookup_code,
             NVL(si.exclusive_payment_flag, ve.exclusive_payment_flag) exclusive_payment_flag,
             si.payment_priority,
             si.terms_date_basis,
             si.allow_awt_flag,
             si.awt_group_id,
             si.exclude_freight_from_discount,
             NVL(si.purchasing_site_flag, 'N') purchasing_site_flag,
             NVL(si.pay_site_flag, 'N') pay_site_flag,
             NVL(si.auto_tax_calc_flag, 'X') auto_tax_calc_flag,
             NVL(si.payment_currency_code, si.invoice_currency_code) payment_currency_code,
             si.inactive_date
      FROM   po_vendors ve,
             po_vendor_sites si,
             financials_system_parameters param
      WHERE  si.vendor_site_id = p_vendor_site_id
      AND    si.vendor_id = ve.vendor_id;

   CURSOR c_po (p_po_distribution_id NUMBER) IS
      SELECT  poh.segment1 po_number,
              poh.po_header_id,
              pol.po_line_id,
              pll.line_location_id,
              pod.po_distribution_id,
              pol.unit_price,
              pol.matching_basis,
              pll.match_option,
              CASE WHEN pll.terms_id IS NOT NULL THEN pll.terms_id
                   WHEN poh.terms_id IS NOT NULL THEN poh.terms_id
                   ELSE psi.terms_id
              END terms_id,
              pod.project_id,
              pod.task_id,
              pod.expenditure_type,
              pod.expenditure_organization_id,
              pod.project_accounting_context,
              pod.expenditure_item_date,
              DECODE(pod.destination_type_code, 'EXPENSE', 
                     DECODE(pod.accrue_on_receipt_flag, 'Y', pod.accrual_account_id, pod.code_combination_id), 
                     pod.accrual_account_id) code_combination_id,
              DECODE(gcc.account_type, 'A', 'Y', 'N') assets_tracking_flag,
              DECODE(pll.taxable_flag, 'Y', pll.tax_code_id, NULL) tax_code_id,
              pod.accrue_on_receipt_flag,
             (SELECT 'Y'
              FROM   gl_code_combinations gcc
              WHERE  gcc.code_combination_id = pod.code_combination_id
              AND    pod.project_id IS NOT NULL
              AND    pod.task_id IS NOT NULL
              AND    gcc.segment3 IN (SELECT SUBSTR(name, 1, 3)
                                      FROM   hr_organization_units_v
                                      WHERE  organization_type = 'COST CENTRE'
                                      AND    attribute2 = 'YES')
              AND    ROWNUM = 1) aor_at_cost_centre,
              pod.attribute_category,
              pod.attribute1,
              pod.attribute2,
              pod.attribute3,
              pod.attribute4,
              pod.attribute5,
              pod.attribute6,
              pod.attribute7,
              pod.attribute8,
              pod.attribute9,
              pod.attribute10,
              pod.attribute11,
              pod.attribute12,
              pod.attribute13,
              pod.attribute14,
              pod.attribute15
      FROM    po_headers_all poh,
              po_lines_all pol,
              po_line_locations_all pll,
              po_distributions_all pod,
              po_vendor_sites_all psi,
              gl_code_combinations gcc
      WHERE   poh.vendor_site_id = psi.vendor_site_id
      AND     poh.po_header_id = pol.po_header_id
      AND     pol.po_line_id = pll.po_line_id
      AND     pll.line_location_id = pod.line_location_id
      AND     pol.po_line_id = pod.po_line_id
      AND     poh.po_header_id = pod.po_header_id
      AND     pod.code_combination_id = gcc.code_combination_id
      AND     pod.po_distribution_id = p_po_distribution_id;

   CURSOR c_tax (p_tax_code_id  NUMBER) IS
      SELECT name tax_code,
             tax_id,
             tax_rate,
             tax_code_combination_id
      FROM   ap_tax_codes_all
      WHERE  tax_id = p_tax_code_id
      AND    inactive_date IS NULL
      AND    org_id = gn_org_id;

   CURSOR c_desc 
   (
      p_po_distribution_id   NUMBER,
      p_level                VARCHAR2
   )  IS
      SELECT DECODE(p_level, 'HEADER', 
                             reqh.description, 
                             reql.item_description) description
      FROM   po_requisition_lines_all reql,
             po_requisition_headers_all reqh,
             po_req_distributions_all reqd,
             po_distributions_all pod
      WHERE  pod.po_distribution_id = p_po_distribution_id
      AND    pod.req_distribution_id = reqd.distribution_id
      AND    reqd.requisition_line_id = reql.requisition_line_id
      AND    reql.requisition_header_id = reqh.requisition_header_id
      AND    reqh.org_id = gn_org_id;

   r_vendor                c_vendor%ROWTYPE;
   r_po                    c_po%ROWTYPE;
   r_tax                   c_tax%ROWTYPE;
   r                       NUMBER := 0;

   ln_invoice_id           NUMBER;
   ln_invoice_num_count    NUMBER;
   ln_po_distribution_id   NUMBER;
   ln_requisition_count    NUMBER;
   ln_quantity             NUMBER;
   ln_amount               NUMBER;
   ln_related_invoice_id   NUMBER;
   ln_invoice_amount       NUMBER := 0;
   ln_total_line_amount    NUMBER := 0;
   ln_total_tax_amount     NUMBER := 0;
   ln_error                NUMBER := 0;
   ln_line_num             NUMBER;
   lv_vendor_name          po_vendors.vendor_name%TYPE;
   lv_vendor_num           po_vendors.segment1%TYPE;
   lv_invoice_num          ap_invoices_all.invoice_num%TYPE;
   lv_approval_status      VARCHAR2(150);
   lv_description          VARCHAR2(240);
   ld_invoice_date         DATE;
   lv_desc_sql             VARCHAR2(32000);
   lv_tax_code             VARCHAR2(150);
   lv_tax_flag             VARCHAR2(1);
   lv_dummy                VARCHAR2(1);
   line_tax_tab            tax_tab_type;
   ln_tax                  NUMBER := 0;
   lv_persist              VARCHAR2(1) := 'N';
   lv_status               VARCHAR2(1) := 'S';

BEGIN
   gv_procedure_name := 'create_invoice_interface';

   -- No need to determine whether type is INV or CM.
   -- Type will depend on the invoice amount.
   p_status := 'S';

   OPEN c_vendor (p_vendor_site_id);
   FETCH c_vendor INTO r_vendor;
   IF c_vendor%FOUND THEN
      BEGIN
         -- <Start of Pre-Import Validation>
         IF r_vendor.purchasing_site_flag = 'N' OR
            r_vendor.pay_site_flag = 'N' THEN
            ln_error := ln_error + 1;
            p_error_out(ln_error) := 'Not a valid purchasing site/pay site.';
            lv_persist := 'Y';
         END IF;

         IF r_vendor.inactive_date IS NOT NULL AND
            r_vendor.inactive_date <= TRUNC(SYSDATE) THEN
            ln_error := ln_error + 1;
            p_error_out(ln_error) := 'Not a valid purchasing site/pay site.';
            lv_persist := 'Y';
         END IF;

         lv_invoice_num := p_invoice_num;
         IF TRIM(lv_invoice_num) IS NULL THEN
            ln_error := ln_error + 1;
            p_error_out(ln_error) := 'Invoice number is null.';
         END IF;

         IF TRIM(p_invoice_date) IS NULL THEN
            ln_error := ln_error + 1;
            p_error_out(ln_error) := 'Invoice Date is null.';
         ELSE
            BEGIN
               ld_invoice_date := TO_DATE(UPPER(p_invoice_date), 'DD-MON-RR');
            EXCEPTION
               WHEN others THEN
                  ln_error := ln_error + 1;
                  p_error_out(ln_error) := 'Invoice Date error [' || p_invoice_date || '] ' || SQLERRM;
                  lv_persist := 'Y';
            END;
         END IF;

         BEGIN
            SELECT 'x'
            INTO   lv_dummy
            FROM   rcv_shipment_headers
            WHERE  shipment_header_id = p_shipment_header_id
            AND    creation_date < gd_cutover_date;

            ln_error := ln_error + 1;
            p_error_out(ln_error) := 'Receipt entered prior to ERS implementation date (' || TO_CHAR(gd_cutover_date, 'DD-Mon-YYYY') || ').';

         EXCEPTION
            WHEN no_data_found THEN
               NULL;
         END;

         /* Validate lines */
         FOR l IN 1 .. interim_lines.COUNT LOOP
            r := r + 1;
            p_report_out(r).shipment_header_id := p_shipment_header_id;
            p_report_out(r).vendor_site_id := p_vendor_site_id;
            p_report_out(r).request_id := gn_request_id;
            p_report_out(r).vendor_number := r_vendor.vendor_number;
            p_report_out(r).vendor_name := r_vendor.vendor_name;
            p_report_out(r).distribution_num := interim_lines(l).line_num;

            OPEN c_po (interim_lines(l).po_distribution_id);
            FETCH c_po INTO r_po;
            IF c_po%FOUND THEN
               IF r_po.matching_basis = 'AMOUNT' AND
                  interim_lines(l).amount IS NOT NULL THEN
                  NULL;
               ELSIF r_po.matching_basis = 'QUANTITY' AND
                  interim_lines(l).quantity IS NOT NULL THEN
                  NULL;
               ELSE
                  ln_error := ln_error + 1;
                  interim_lines(l).status := 'E';
                  interim_lines(l).err_message := 'Matching basis (' || r_po.matching_basis || ') not consistent with receiving transaction data.';
                  p_error_out(ln_error) := interim_lines(l).err_message;
                  lv_persist := 'Y';
               END IF;

               IF r_po.match_option <> 'P' THEN
                  ln_error := ln_error + 1;
                  interim_lines(l).status := 'E';
                  interim_lines(l).err_message := 'Match Option is not PO.';
                  p_error_out(ln_error) := interim_lines(l).err_message;
               END IF;

               IF NVL(r_po.accrue_on_receipt_flag, 'N') = 'Y' OR
                  NVL(r_po.aor_at_cost_centre, 'N') = 'Y' THEN
                  ln_error := ln_error + 1;
                  interim_lines(l).status := 'E';
                  interim_lines(l).err_message := 'PO Distribution Line is flagged as accrue on receipt.';
                  p_error_out(ln_error) := interim_lines(l).err_message;
                  lv_persist := 'Y';
               END IF;

               ln_amount := 0;
               ln_quantity := 0;

               IF r_po.matching_basis = 'AMOUNT' THEN
                  ln_amount := interim_lines(l).amount;
                  ln_total_line_amount := ln_total_line_amount + ln_amount;
               ELSIF r_po.matching_basis = 'QUANTITY' THEN
                  ln_quantity := interim_lines(l).quantity;
                  ln_amount := (r_po.unit_price * ln_quantity);
                  ln_total_line_amount := ln_total_line_amount + (r_po.unit_price * ln_quantity);
               END IF;

               ln_amount := ap_utilities_pkg.ap_round_currency(ln_amount, gv_base_currency);

               OPEN c_tax (r_po.tax_code_id);
               FETCH c_tax INTO r_tax;
               IF c_tax%FOUND THEN
                  p_report_out(r).tax_code := r_tax.tax_code;

                  IF ln_amount <> 0 THEN
                     ln_total_tax_amount := ln_total_tax_amount + (ln_amount * (r_tax.tax_rate / 100));
                  END IF;
               END IF;
               CLOSE c_tax;

               BEGIN
                  SELECT concatenated_segments
                  INTO   p_report_out(r).charge_account
                  FROM   gl_code_combinations_kfv
                  WHERE  code_combination_id = r_po.code_combination_id;
               EXCEPTION
                  WHEN others THEN NULL;
               END;

               p_report_out(r).po_number := r_po.po_number;
               p_report_out(r).distribution_amount := ln_amount;

            ELSE
               ln_error := ln_error + 1;
               interim_lines(l).status := 'E';
               interim_lines(l).err_message := 'Unexpected error - unable to find Purchase Order distribution line (po_distribution_id = ' || interim_lines(l).po_distribution_id || ').';
               p_error_out(ln_error) := interim_lines(l).err_message;
            END IF;
            CLOSE c_po;

            BEGIN
               SELECT rsh.receipt_num,
                      fu.user_name
               INTO   p_report_out(r).receipt_number,
                      p_report_out(r).entered_by
               FROM   rcv_shipment_headers rsh,
                      fnd_user fu
               WHERE  rsh.created_by = fu.user_id(+)
               AND    rsh.shipment_header_id = interim_lines(l).shipment_header_id;
            EXCEPTION
               WHEN others THEN NULL;
            END;

         END LOOP;

         ln_invoice_amount := ln_total_line_amount + ln_total_tax_amount;
         ln_invoice_amount := ap_utilities_pkg.ap_round_currency(ln_invoice_amount, gv_base_currency);

         IF p_adjust_invoice THEN
            IF SIGN(ln_invoice_amount) = -1 THEN
               lv_invoice_num := 'CM-' || lv_invoice_num;
               check_invoice_num(lv_invoice_num, 
                                 p_vendor_id, 
                                 TRUE,
                                 ln_related_invoice_id, 
                                 lv_approval_status,
                                 ln_invoice_num_count);

               IF ln_related_invoice_id IS NOT NULL THEN
                  IF lv_approval_status = 'CANCELLED' THEN
                     ln_error := ln_error + 1;
                     p_error_out(ln_error) := 'Related invoice number ' || REPLACE(lv_invoice_num, 'CM-') || ' has been cancelled.';
                     lv_persist := 'Y';
                  ELSE
                     lv_invoice_num := lv_invoice_num || '-' || (ln_invoice_num_count + 1);
                  END IF;

               ELSE
                  ln_error := ln_error + 1;
                  p_error_out(ln_error) := 'Unexpected error: unable to find related invoice for ' || lv_invoice_num || '.';
                  lv_persist := 'Y';
               END IF;

            ELSE
               lv_invoice_num := lv_invoice_num || '-ADJ-';
               check_invoice_num(lv_invoice_num, 
                                 p_vendor_id, 
                                 TRUE,
                                 ln_related_invoice_id,
                                 lv_approval_status,
                                 ln_invoice_num_count);

               IF ln_related_invoice_id IS NULL THEN
                  ln_error := ln_error + 1;
                  p_error_out(ln_error) := 'Unexpected error: unable to find related invoice for ' || lv_invoice_num || '.';
                  lv_persist := 'Y';
               ELSE
                  lv_invoice_num := lv_invoice_num || (ln_invoice_num_count + 1);
               END IF;

            END IF;
         ELSE
            BEGIN
               SELECT vendor_name,
                      segment1
               INTO   lv_vendor_name,
                      lv_vendor_num
               FROM   po_vendors
               WHERE  vendor_id = p_vendor_id;

               check_invoice_num(lv_invoice_num, 
                                 p_vendor_id, 
                                 FALSE,
                                 ln_related_invoice_id,
                                 lv_approval_status,
                                 ln_invoice_num_count);

               IF ln_invoice_num_count > 0 THEN
                  ln_error := ln_error + 1;
                  p_error_out(ln_error) := 'Invoice number ' || lv_invoice_num || ' already been used for this vendor ' || lv_vendor_name || ' (' || lv_vendor_num || ').';
                  lv_persist := 'Y';
               END IF;

            EXCEPTION
               WHEN others THEN
                  ln_error := ln_error + 1;
                  p_error_out(ln_error) := 'Unexpected error - unable to find vendor (vendor_id ' || p_vendor_id || ').';
            END;
         END IF;

         IF ln_error > 0 THEN
            lv_status := 'E';
         END IF;

         IF r > 0 THEN
            FOR rec IN 1 .. r LOOP
               p_report_out(rec).invoice_number := lv_invoice_num;
               p_report_out(rec).invoice_amount := ln_invoice_amount;
               p_report_out(rec).invoice_date := ld_invoice_date;
               p_report_out(rec).persist_flag := lv_persist;
               p_report_out(rec).status := lv_status;
               p_report_out(rec).created_by := gn_user_id;
               p_report_out(rec).creation_date := SYSDATE;
            END LOOP;
         END IF;
         -- <End of Pre-Import Validation>

         /*********************************************************/
         /* Create Interface                                      */
         /*********************************************************/
         IF ln_error = 0 THEN
            IF gv_run_import = 'Y' THEN

               ln_total_line_amount := 0;
               ln_total_tax_amount := 0;

               -- Validate if Receipt is for multiple requisitions
               FOR s IN 1 .. interim_lines.COUNT LOOP
                  IF lv_desc_sql IS NOT NULL THEN
                     lv_desc_sql := lv_desc_sql || ', ';
                  END IF;
                  lv_desc_sql := lv_desc_sql || interim_lines(s).po_distribution_id;
               END LOOP;

               IF lv_desc_sql IS NOT NULL THEN
                  lv_desc_sql := gv_desc_sql || lv_desc_sql || ')';
                  EXECUTE IMMEDIATE lv_desc_sql INTO ln_requisition_count;
               END IF;

               IF NVL(ln_requisition_count, 0) > 1 THEN
                  lv_description := 'ERS Invoice from multiple requisitions';
               ELSE
                  ln_po_distribution_id := interim_lines(1).po_distribution_id;
                  OPEN c_desc (ln_po_distribution_id, 'HEADER');
                  FETCH c_desc INTO lv_description;
                  CLOSE c_desc;
               END IF;

               SELECT ap_invoices_interface_s.NEXTVAL
               INTO   ln_invoice_id
               FROM   dual;

               INSERT INTO ap_invoices_interface
                      (invoice_id,
                       invoice_num,
                       invoice_date,
                       vendor_id,
                       vendor_site_id,
                       invoice_amount,
                       invoice_currency_code,
                       description,
                       last_update_date,
                       last_updated_by,
                       last_update_login,
                       creation_date,
                       created_by,
                       source,
                       org_id,
                       group_id,
                       invoice_received_date,
                       gl_date,
                       accts_pay_code_combination_id,
                       exclusive_payment_flag,
                       terms_id,
                       attribute1,
                       attribute13,
                       attribute15)
               VALUES (ln_invoice_id,
                       lv_invoice_num,
                       ld_invoice_date,
                       r_vendor.vendor_id,
                       r_vendor.vendor_site_id,
                       ln_invoice_amount,
                       gv_base_currency,      --NVL(r_vendor.payment_currency_code, 'AUD'),
                       lv_description,
                       SYSDATE,
                       gn_default_user,       --gn_user_id,
                       gn_login_id,
                       SYSDATE,
                       gn_default_user,       --gn_user_id,
                       gv_source,
                       gn_org_id,
                       gv_batch_name,
                       SYSDATE,
                       gd_gl_date,
                       r_vendor.accts_pay_code_combination_id,
                       r_vendor.exclusive_payment_flag,
                       r_po.terms_id,
                       'N',
                       'INVOICE INTERFACE',
                       gv_batch_name);

               FOR l IN 1 .. interim_lines.COUNT LOOP
                  lv_tax_code := NULL;
                  lv_tax_flag := NULL;
                  ln_quantity := NULL;
                  ln_amount := NULL;
                  ln_line_num := l;

                  OPEN c_po (interim_lines(l).po_distribution_id);
                  FETCH c_po INTO r_po;
                  CLOSE c_po;

                  OPEN c_desc (interim_lines(l).po_distribution_id, 'LINE');
                  FETCH c_desc INTO lv_description;
                  CLOSE c_desc;

                  IF r_po.matching_basis = 'AMOUNT' THEN
                     ln_amount := interim_lines(l).amount;
                     ln_total_line_amount := ln_total_line_amount + ln_amount;
                  ELSIF r_po.matching_basis = 'QUANTITY' THEN
                     ln_quantity := interim_lines(l).quantity;
                     ln_amount := (r_po.unit_price * ln_quantity);
                     ln_total_line_amount := ln_total_line_amount + (r_po.unit_price * ln_quantity);
                  END IF;

                  OPEN c_tax (r_po.tax_code_id);
                  FETCH c_tax INTO r_tax;
                  IF c_tax%FOUND THEN
                     -- Pre-calculate tax amount
                     IF NVL(r_tax.tax_rate, 0) > 0 THEN
                        ln_tax := ln_tax + 1;
                        line_tax_tab(ln_tax).line_group_num := interim_lines(l).line_num; 
                        line_tax_tab(ln_tax).tax_id := r_tax.tax_id;
                        line_tax_tab(ln_tax).tax_code := r_tax.tax_code; 
                        line_tax_tab(ln_tax).tax_rate := r_tax.tax_rate;
                        line_tax_tab(ln_tax).tax_ccid := r_tax.tax_code_combination_id;

                        IF ln_amount IS NOT NULL THEN
                           line_tax_tab(ln_tax).tax_amount := (ln_amount * (r_tax.tax_rate / 100));
                        END IF;

                        IF ln_quantity IS NOT NULL THEN
                           line_tax_tab(ln_tax).tax_amount := ((r_po.unit_price * ln_quantity) * (r_tax.tax_rate / 100));
                        END IF;

                        ln_total_tax_amount := ln_total_tax_amount + line_tax_tab(ln_tax).tax_amount;

                     END IF;
                  END IF;
                  CLOSE c_tax;

                  ln_amount := ap_utilities_pkg.ap_round_currency(ln_amount, gv_base_currency);

                  INSERT INTO ap_invoice_lines_interface 
                         (invoice_id,
                          invoice_line_id,
                          line_number,
                          line_type_lookup_code,
                          line_group_number,
                          amount,
                          description,
                          accounting_date,
                          tax_code,
                          amount_includes_tax_flag,
                          po_header_id,
                          po_line_id,
                          po_line_location_id,
                          po_distribution_id,
                          quantity_invoiced,
                          expenditure_item_date,
                          expenditure_type,
                          expenditure_organization_id,
                          project_accounting_context,
                          pa_quantity,
                          pa_addition_flag,
                          unit_price,
                          assets_tracking_flag,
                          attribute_category,
                          attribute1,
                          attribute2,
                          attribute3,
                          attribute4,
                          attribute5,
                          attribute6,
                          attribute7,
                          attribute8,
                          attribute9,
                          attribute10,
                          attribute11,
                          attribute12,
                          attribute13,
                          attribute14,
                          attribute15,
                          match_option,
                          org_id,
                          last_update_date,
                          last_updated_by,
                          creation_date,
                          created_by)
                  VALUES (ln_invoice_id,
                          ap_invoice_lines_interface_s.NEXTVAL,
                          interim_lines(l).line_num,
                          'ITEM',
                          interim_lines(l).line_num,
                          ln_amount,
                          lv_description,
                          gd_gl_date,
                          lv_tax_code,
                          lv_tax_flag,
                          r_po.po_header_id,
                          r_po.po_line_id,
                          r_po.line_location_id,
                          r_po.po_distribution_id,
                          ln_quantity,
                          r_po.expenditure_item_date,
                          r_po.expenditure_type,
                          r_po.expenditure_organization_id,
                          r_po.project_accounting_context,
                          ln_quantity,
                          'N',
                          r_po.unit_price,
                          r_po.assets_tracking_flag,
                          r_po.attribute_category,
                          r_po.attribute1,
                          r_po.attribute2,
                          r_po.attribute3,
                          r_po.attribute4,
                          r_po.attribute5,
                          r_po.attribute6,
                          r_po.attribute7,
                          r_po.attribute8,
                          r_po.attribute9,
                          r_po.attribute10,
                          r_po.attribute11,
                          r_po.attribute12,
                          r_po.attribute13,
                          r_po.attribute14,
                          r_po.attribute15,
                          r_po.match_option,
                          gn_org_id,
                          SYSDATE,
                          gn_default_user,  -- gn_user_id,
                          SYSDATE,
                          gn_default_user   -- gn_user_id
                         );
               END LOOP;

               IF gv_auto_tax_calc_flag = 'L' AND 
                  gv_auto_tax_calc_flag = r_vendor.auto_tax_calc_flag 
               THEN
                  line_tax_tab.DELETE;
               END IF;

               IF line_tax_tab.COUNT > 0 THEN
                  FOR t IN 1 .. line_tax_tab.COUNT LOOP
                     ln_line_num := ln_line_num + 1;

                     INSERT INTO ap_invoice_lines_interface
                            (invoice_id,
                             invoice_line_id,
                             line_number,
                             line_type_lookup_code,
                             line_group_number,
                             amount,
                             accounting_date,
                             description,
                             tax_code,
                             item_description,
                             dist_code_combination_id,
                             last_updated_by,
                             last_update_date,
                             last_update_login,
                             created_by,
                             creation_date)
                     VALUES (ln_invoice_id,
                             ap_invoice_lines_interface_s.NEXTVAL,
                             ln_line_num,
                             'TAX',
                             line_tax_tab(t).line_group_num,
                             line_tax_tab(t).tax_amount,
                             gd_gl_date,
                             NULL,
                             line_tax_tab(t).tax_code,
                             '',
                             line_tax_tab(t).tax_ccid,
                             gn_default_user,
                             SYSDATE,
                             gn_login_id,
                             gn_default_user,
                             SYSDATE);

                  END LOOP;  -- tax interface
               END IF;       -- tax table
            END IF;          -- run import

         ELSE
            p_status := 'E';
         END IF;          -- no errors

      EXCEPTION
         WHEN others THEN
            ln_error := ln_error + 1;
            p_error_out(ln_error) := SQLERRM;
            p_status := 'E';
      END;

   ELSE
      ln_error := ln_error + 1;
      p_error_out(ln_error) := 'Unexpected error - unable to find Vendor and Vendor Site (vendor_id = ' || p_vendor_id || ' vendor_site_id = ' || p_vendor_site_id || ')';
      p_status := 'E';
   END IF;
   CLOSE c_vendor;

EXCEPTION
   WHEN others THEN
      raise_application_error(-20501, gv_procedure_name || ' ' || SQLERRM);

END create_invoice_interface;

END dot_po_pay_on_receipt_pkg;
/
