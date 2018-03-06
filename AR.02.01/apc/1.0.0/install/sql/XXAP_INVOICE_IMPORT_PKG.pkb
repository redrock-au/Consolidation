create or replace PACKAGE BODY XXAP_INVOICE_IMPORT_PKG AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.01/apc/1.0.0/install/sql/XXAP_INVOICE_IMPORT_PKG.pkb 2981 2017-11-14 08:13:57Z svnuser $*/
/****************************************************************************
**
** CEMLI ID: AP.03.01
**
** Description: Package to handle the below
**              (1) Import Invoice Metadata into Oracle custom table
**              (2) Send Workflow Email to Requestor
**              (3) Attach URL of Scanned Invoice to Historical AP Invoices
**              (4) 3.5	Program to Deactivate Scanned Invoice Record in Oracle 
**              
**
** Change History:
**
** Date        Who                  Comments
** 15/05/2017  Joy Pinto            Initial build.
**
***************************************************************************/

gv_procedure_name       VARCHAR2(150);

TYPE inv_rec_type IS RECORD
(
   import_id                       NUMBER,
   import_status                   VARCHAR2(240),
   attribute1                      VARCHAR2(240),
   attribute2                      VARCHAR2(240),
   attribute3                      VARCHAR2(240),
   attribute4                      VARCHAR2(240),
   attribute5                      VARCHAR2(240),
   attribute6                      VARCHAR2(240),
   attribute7                      VARCHAR2(240),
   attribute8                      VARCHAR2(240),
   attribute9                      VARCHAR2(240),
   attribute10                     VARCHAR2(240),
   attribute11                     VARCHAR2(240),
   attribute12                     VARCHAR2(240),
   attribute13                     VARCHAR2(240),
   attribute14                     VARCHAR2(240),
   attribute15                     VARCHAR2(240),
   creation_date                   DATE,
   last_update_date                DATE,
   last_updated_by                 NUMBER,
   created_by                      NUMBER,
   payload_id                      NUMBER,
   po_header_id                    VARCHAR2(10),
   po_number_attachment            VARCHAR2(255),
   po_number                       VARCHAR2(255),
   requisition_number              VARCHAR2(255),
   requisition_id                  NUMBER,
   invoice_id                      VARCHAR2(10),
   invoice_id_attachment           VARCHAR2(255),
   invoice_num                     VARCHAR2(255),
   invoice_date                    DATE,
   invoice_received_date           DATE,
   invoice_amount_exc_gst          VARCHAR2(40),
   gst_amount                      VARCHAR2(40),
   invoice_amount_inc_gst          VARCHAR2(40),
   gst_code                        VARCHAR2(240),
   currency                        VARCHAR2(240),
   po_attachment_complete          VARCHAR2(5),
   req_prep_name                   VARCHAR2(240),
   email_sent_count                NUMBER,
   email_sent_date                 DATE,
   preparer_id                     NUMBER,
   org_id                          NUMBER,
   vendor_internal_id              NUMBER,
   vendor_site_id                  NUMBER,
   vendor_site_code                VARCHAR2(15),
   supplier_num                    VARCHAR2(30),
   abn_number                      VARCHAR2(20),
   image_url                       VARCHAR2(255),
   active_flag                     VARCHAR2(10),
   item_type                       VARCHAR2(100),
   item_key                        VARCHAR2(100),
   deleted_in_kofax                VARCHAR2(10)
);

-------------------------------------------------------
-- FUNCTION
--     CREATE_WF_INITIAL_DOC
-- Purpose
--     This procedure generates HTML dynamically that is used in the workflow notification
-------------------------------------------------------

PROCEDURE create_wf_initial_doc
(
   document_id   IN VARCHAR2,
   display_type  IN VARCHAR2,
   document      IN OUT NOCOPY VARCHAR2,
   document_type IN OUT NOCOPY VARCHAR2
)
IS
   CURSOR c_get_initial_requestors_dtl IS             
      SELECT xisf.invoice_num,
             xisf.po_number ,
             xisf.creation_date import_date,
             xisf.po_number_attachment
      FROM   xxap_inv_scanned_file xisf
      WHERE  xisf.item_key = document_id;
             
   CURSOR c_get_po_count IS             
      SELECT COUNT (DISTINCT xisf.po_number)
      FROM   xxap_inv_scanned_file xisf
      WHERE  xisf.item_key = document_id;       
             
   CURSOR c_get_invoice_count IS
      SELECT COUNT (DISTINCT xisf.invoice_num)
      FROM   xxap_inv_scanned_file xisf
      WHERE  xisf.item_key = document_id;
             
  lv_body                VARCHAR2(32767);
  ln_po_count            NUMBER := 0;
  ln_invoice_count       NUMBER := 0;
  lv_po_text             VARCHAR2(100);
  lv_invoice_text        VARCHAR2(100);
  lv_subject_token       VARCHAR2(100);
  lv_body_part1_message  VARCHAR2(100);
  lv_body_part2_message  VARCHAR2(100);
  
BEGIN
   document_type := 'text/html';  
   OPEN  c_get_po_count;
   FETCH c_get_po_count INTO ln_po_count;
   CLOSE c_get_po_count ;
   
   OPEN  c_get_invoice_count;
   FETCH c_get_invoice_count INTO ln_invoice_count;
   CLOSE c_get_invoice_count ;
     
   IF ln_invoice_count > 1 THEN
      lv_invoice_text := 'Invoices';      
      lv_body_part1_message := 'XXPO_RCPT_MUL_EMAIL_BODY_PART1';
      lv_body_part2_message := 'XXPO_RCPT_MUL_EMAIL_BODY_PART2'; 
   ELSE
      lv_invoice_text := 'Invoice';
      lv_body_part1_message := 'XXPO_RCPT_EMAIL_BODY_PART1';
      lv_body_part2_message := 'XXPO_RCPT_EMAIL_BODY_PART2';     
   END IF;   
   
   
   fnd_message.clear;
   fnd_message.set_name('POC', lv_body_part1_message);
   lv_body := fnd_message.get;
   
   FOR c_rec IN  c_get_initial_requestors_dtl LOOP
      BEGIN
         lv_body := lv_body || '<tr>    
                    <td>' || '<a href="' || c_rec.po_number_attachment || '" target="_blank">' || c_rec.invoice_num || '</a>' || '</td>     
                    <td>' || c_rec.po_number || '</td>     
                    <td>' || c_rec.import_date || '</td></tr>';
      END;
   END LOOP; 

   lv_body := lv_body || '</table>';
   fnd_message.clear;
   fnd_message.set_name('POC',lv_body_part2_message);   
   lv_body := lv_body || fnd_message.get;     

   document := lv_body;
   --
   -- Setting document type which is nothing but MIME type
   --
   document_type := 'text/html';

EXCEPTION
   WHEN OTHERS THEN
     document := '<H4>Error: '|| sqlerrm || '</H4>';
END create_wf_initial_doc;

-------------------------------------------------------
-- FUNCTION
--     CREATE_WF_REMINDER_DOC
-- Purpose
--     This procedure generates HTML dynamically that is used in the workflow reminder notification
-------------------------------------------------------

PROCEDURE create_wf_reminder_doc
(
   document_id   IN VARCHAR2,
   display_type  IN VARCHAR2,
   document      IN OUT nocopy VARCHAR2,
   document_type IN OUT nocopy VARCHAR2
)
IS
   CURSOR c_get_reminder_requestors_dtl IS             
      SELECT xisf.invoice_num,
             xisf.po_number ,
             xisf.creation_date import_date,
             xisf.po_number_attachment
      FROM   xxap_inv_scanned_file xisf
      WHERE  xisf.preparer_id = SUBSTR(document_id, 1, INSTR(document_id, '~') - 1)
      AND    xisf.email_sent_date IS NOT NULL
      AND    xisf.po_header_id IS NOT NULL
      AND    (select count(1) from ap_invoices_all a where a.invoice_id = xisf.invoice_id ) =0 -- Joy Pinto FSC-4197     
      AND    TRUNC(SYSDATE) - TRUNC(xisf.email_sent_date) >= SUBSTR(document_id, INSTR(document_id, '~') + 1)
      -- arellanod 11/09/2017 FSC-2583
      AND    (xisf.active_flag IS NULL OR xisf.active_flag = 'Y')
      AND    NOT EXISTS (SELECT 1
                         FROM   (SELECT h.receipt_num,
                                        t.attribute5 import_id,
                                        h.vendor_id,
                                        NVL(SUM(t.quantity), 0) quantity,
                                        NVL(SUM(t.amount), 0) amount
                                 FROM   rcv_transactions t,
                                        rcv_shipment_headers h
                                 WHERE  t.attribute5 IS NOT NULL
                                 AND    t.shipment_header_id = h.shipment_header_id
                                 AND    t.destination_context = 'RECEIVING'
                                 AND    t.transaction_type NOT IN ('DELIVER', 'RETURN TO RECEIVING')
                                 GROUP  BY h.receipt_num,
                                           t.attribute5,
                                           h.vendor_id
                                 HAVING (NVL(SUM(t.quantity), 0) + NVL(SUM(t.amount), 0)) <> 0) a
                         WHERE   a.import_id = xisf.import_id
                         AND     a.vendor_id = xisf.vendor_internal_id);
             
   CURSOR c_get_po_count IS             
      SELECT COUNT(DISTINCT xisf.po_number)
      FROM   xxap_inv_scanned_file xisf
      WHERE  xisf.preparer_id = substr(document_id,1,instr(document_id,'~')-1)
      AND    email_sent_date IS NOT NULL
      AND    NVL(active_flag, 'Y') = 'Y'
      AND    po_header_id IS NOT NULL
      AND    (select count(1) from ap_invoices_all a where a.invoice_id = xisf.invoice_id ) =0 -- Joy Pinto FSC-4197      
      AND    TRUNC(SYSDATE) - TRUNC(email_sent_date) >= SUBSTR(document_id, INSTR(document_id, '~') + 1);
             
   CURSOR c_get_invoice_count IS             
      SELECT COUNT (DISTINCT xisf.invoice_num)
      FROM   xxap_inv_scanned_file xisf
      WHERE  xisf.preparer_id = SUBSTR(document_id, 1, INSTR(document_id, '~') - 1)
      AND    email_sent_date IS NOT NULL
      AND    NVL(active_flag,'Y') = 'Y'
      AND    po_header_id IS NOT NULL
      AND    (select count(1) from ap_invoices_all a where a.invoice_id = xisf.invoice_id ) =0 -- Joy Pinto FSC-4197      
      AND    TRUNC(SYSDATE) - TRUNC(email_sent_date) >= SUBSTR(document_id, INSTR(document_id, '~') + 1);
             
   lv_body                VARCHAR2(32767);
   ln_po_count            NUMBER := 0;
   ln_invoice_count       NUMBER := 0;
   lv_invoice_text        VARCHAR2(100);
   lv_body_part1_message  VARCHAR2(100);
   lv_body_part2_message  VARCHAR2(100);
   --lv_po_text             VARCHAR2(100);
   --lv_subject_token       VARCHAR2(100);
  
BEGIN
   document_type := 'text/html';  
   OPEN  c_get_po_count;
   FETCH c_get_po_count INTO ln_po_count;
   CLOSE c_get_po_count ;
   
   OPEN  c_get_invoice_count;
   FETCH c_get_invoice_count INTO ln_invoice_count;
   CLOSE c_get_invoice_count ;
     
   IF ln_invoice_count > 1 THEN
      lv_invoice_text := 'Invoices';
      lv_body_part1_message := 'XXPO_RCPT_REM_MUL_EMAIL_BODYP1';
      lv_body_part2_message := 'XXPO_RCPT_REM_MUL_EMAIL_BODYP2';
   ELSE
      lv_invoice_text := 'Invoice';      
      lv_body_part1_message := 'XXPO_RCPT_REM_EMAIL_BODY_PART1';
      lv_body_part2_message := 'XXPO_RCPT_REM_EMAIL_BODY_PART2';
   END IF;   
   
   fnd_message.clear;
   fnd_message.set_name('POC', lv_body_part1_message);
   lv_body := fnd_message.get;

   FOR c_rec IN  c_get_reminder_requestors_dtl LOOP
      BEGIN
         lv_body := lv_body || '<tr>    
                    <td>' || '<a href="'||c_rec.po_number_attachment || '" target="_blank">' || c_rec.invoice_num || '</a>' || '</td>
                    <td>' || c_rec.po_number|| '</td>
                    <td>' || c_rec.import_date|| '</td>
                    </tr>';
      END;
   END LOOP; 

   lv_body := lv_body || '</table>';
   fnd_message.clear;
   fnd_message.set_name('POC', lv_body_part2_message);
   lv_body := lv_body || fnd_message.get;

   document := lv_body;
   --
   --Setting document type which is nothing but MIME type
   --
   document_type := 'text/html';
EXCEPTION
   WHEN OTHERS THEN
      document := '<H4>Error: '|| sqlerrm || '</H4>';

END create_wf_reminder_doc;
         
-------------------------------------------------------
-- FUNCTION
--     UPDATE_ITEM_KEY
-- Purpose
--     This procedure updates item keys to the transactions grouped by preparer
-------------------------------------------------------

PROCEDURE update_item_key
(
   p_item_type        IN VARCHAR2,
   p_item_key         IN VARCHAR2,
   p_preparer_id      IN NUMBER
)         
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   UPDATE xxap_inv_scanned_file
   SET    item_type = p_item_type,
          item_key  = p_item_key,
          last_update_date = sysdate,
          last_updated_by = gn_user_id                
   WHERE  preparer_id = p_preparer_id
   AND    email_sent_date IS NULL;

   COMMIT;

EXCEPTION
   WHEN OTHERS THEN
      RAISE;
END update_item_key;

-------------------------------------------------------
-- FUNCTION
--     UPDATE_EMAIL_SENT
-- Purpose
--     This procedure updates item keys to the transactions grouped by preparer
-------------------------------------------------------

PROCEDURE update_email_sent
(
   p_preparer_id      IN NUMBER,
   p_days_old         IN NUMBER,
   p_reminder         IN VARCHAR2
)         
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN

   IF NVL(p_reminder ,'N') = 'N' THEN
      UPDATE xxap_inv_scanned_file
      SET    email_sent_date = SYSDATE,
             email_sent_count = nvl(email_sent_count,0)+1,
             last_update_date = SYSDATE,
             last_updated_by = gn_user_id             
      WHERE  preparer_id = p_preparer_id
      AND    email_sent_date IS NULL ;
   ELSE
      UPDATE xxap_inv_scanned_file
      SET    email_sent_count = nvl(email_sent_count,0)+1,
             last_update_date = SYSDATE,
             last_updated_by = gn_user_id
      WHERE  preparer_id = p_preparer_id
      AND    email_sent_date IS NOT NULL 
      AND    (TRUNC(SYSDATE) - email_sent_date) >= p_days_old;
   END IF;    
   
   COMMIT;
   
END update_email_sent; 

-------------------------------------------------------
-- PROCEDURE
--     RUN_RCPT_REMINDER_EMAIL
-- Purpose
--     This procedure is called from the concurrent program "DEDJTR Invoice Scan Import Program" and "DEDJTR POs to Receipt Notification"
--     (1) When called from "DEDJTR Invoice Scan Import Program" , this program sends emails to requestors to receipt Purhase Orders
--     (2) When Called from "DEDJTR POs to Receipt Notification" this program sends reminders to the requestors who havent receieved 
--          the goods beyond "p_days_old" days
-------------------------------------------------------

PROCEDURE run_rcpt_reminder_email
(
   p_errbuf              OUT VARCHAR2,
   p_retcode             OUT NUMBER,
   p_requestor_id        IN  VARCHAR2,
   p_days_old            IN  NUMBER,
   p_notification_type   IN  VARCHAR2,
   p_send_email_flag     IN  VARCHAR2,
   p_org_id              IN  NUMBER
)
IS
   CURSOR c_get_po_count(p_preparer_id NUMBER) IS             
      SELECT COUNT (DISTINCT xisf.po_number)
      FROM   xxap_inv_scanned_file xisf             
      WHERE  xisf.email_Sent_date IS NULL
      AND    NVL(active_flag, 'Y') = 'Y'
      AND    xisf.org_id = NVL(p_org_id, xisf.org_id)
      AND    po_header_id IS NOT NULL
      AND    (select count(1) from ap_invoices_all a where a.invoice_id = xisf.invoice_id ) =0 -- Joy Pinto FSC-4197
      AND    xisf.preparer_id = p_preparer_id;      
      
   CURSOR c_get_po_count_reminder(p_preparer_id NUMBER) IS             
      SELECT COUNT (DISTINCT xisf.po_number)
      FROM   xxap_inv_scanned_file xisf             
      WHERE  xisf.email_Sent_date IS NOT NULL
      AND    NVL(active_flag, 'Y') = 'Y'
      AND    xisf.org_id = NVL(p_org_id, xisf.org_id)
      AND    po_header_id IS NOT NULL
      AND    (select count(1) from ap_invoices_all a where a.invoice_id = xisf.invoice_id ) =0 -- Joy Pinto FSC-4197      
      AND    xisf.preparer_id = p_preparer_id;

   -- arellanod 11/09/2017 FSC-2583
   CURSOR c_print_line (p_preparer_id NUMBER, p_reminder_flag VARCHAR2) IS
      SELECT xisf.invoice_num || '|' ||
             xisf.invoice_date || '|' ||
             xisf.invoice_amount_exc_gst || '|' ||
             xisf.invoice_received_date || '|' ||
             xisf.creation_date || '|' ||
             poh.segment1 || '|' || -- po_num
             pol.line_num || '|' ||
             pod.distribution_num || '|' ||
             -- amount remaining
             (pod.encumbered_amount - (SELECT DECODE(NVL(pll.amount_received, 0), 0, (NVL(pll.quantity_received, 0) * NVL(pol.unit_price, 0)), 
                                                     NVL(pll.amount_received, 0))
                                       FROM   po_line_locations_all pll
                                       WHERE  pll.line_location_id = pod.line_location_id
                                       AND    pll.po_line_id = pol.po_line_id))                                       
                                       || '|' || 
             gcc.segment1 || '|' || -- organisation
             gcc.segment2 || '|' || -- account
             gcc.segment3 || '|' || -- cost_centre
             gcc.segment4 || '|' || -- authority
             gcc.segment5 || '|' || -- project
             gcc.segment6 || '|' || -- output
             gcc.segment7 || '|' || -- identifier
             ppf.full_name || '|' || -- buyer_name
             pve.vendor_name || '|' ||
             pve.segment1 || '|' || -- vendor_num
             psi.vendor_site_code || '|' ||
             ROUND(TRUNC(SYSDATE) - TRUNC(xisf.email_sent_date), 0) || '|' --days_unreceipted
             line_text,
             xisf.import_id,
             poh.vendor_id
      FROM   po_distributions_v pod,
             po_headers poh,
             po_lines pol,
             gl_code_combinations gcc,
             xxap_inv_scanned_file xisf,
             per_all_people_f ppf,
             po_vendors pve,
             po_vendor_sites psi
      WHERE  xisf.preparer_id = p_preparer_id
      AND    (xisf.active_flag IS NULL OR xisf.active_flag = 'Y')
      AND    (pod.quantity_ordered - pod.quantity_cancelled) > pod.quantity_delivered
      AND    ((pod.quantity_ordered - pod.quantity_cancelled) - pod.quantity_delivered) > 1 -- rounding issue
      AND    pod.code_combination_id = gcc.code_combination_id
      AND    pod.po_header_id = poh.po_header_id
      AND    pod.po_line_id = pol.po_line_id
      AND    pol.po_header_id = poh.po_header_id
      AND    poh.po_header_id = xisf.po_header_id
      AND    xisf.preparer_id = poh.agent_id
      AND    poh.agent_id = ppf.person_id
      AND    TRUNC(SYSDATE) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
      AND    poh.vendor_id = pve.vendor_id
      AND    poh.vendor_site_id = psi.vendor_site_id
      AND    pve.vendor_id = psi.vendor_id
      AND    ((p_reminder_flag = 'Y' AND xisf.email_sent_date IS NOT NULL) 
               OR
              (p_reminder_flag = 'N' AND xisf.email_sent_date IS NULL))
      AND    NOT EXISTS (SELECT 1 
                         FROM   ap_invoices ain 
                         WHERE  ain.invoice_num = xisf.invoice_num 
                         AND    ain.vendor_id = poh.vendor_id)
      ORDER  BY poh.segment1, xisf.invoice_num, LPAD(pol.line_num, 3, '0'), LPAD(pod.distribution_num, 3, '0');

   -- arellanod 11/09/2017 FSC-2583
   CURSOR c_rcv (p_import_id NUMBER, p_vendor_id NUMBER) IS
      SELECT h.receipt_num,
             TO_NUMBER(t.attribute5) import_id,
             h.vendor_id,
             NVL(SUM(t.quantity), 0) quantity,
             NVL(SUM(t.amount), 0) amount
      FROM   rcv_transactions t,
             rcv_shipment_headers h
      WHERE  t.attribute5 IS NOT NULL
      AND    t.shipment_header_id = h.shipment_header_id
      AND    t.destination_context = 'RECEIVING'
      AND    t.transaction_type NOT IN ('DELIVER', 'RETURN TO RECEIVING')
      AND    TO_NUMBER(t.attribute5) = p_import_id
      AND    t.vendor_id = p_vendor_id
      GROUP  BY
             h.receipt_num,
             t.attribute5,
             h.vendor_id
      HAVING (NVL(SUM(t.quantity), 0) + NVL(SUM(t.amount), 0)) <> 0;
      
   CURSOR c_eligible_requestors IS -- FSC 5956
      SELECT xisf.preparer_id ,
             ppf.full_name preparer_name,
             fu.user_name ,
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
      AND    preparer_id = NVL(p_requestor_id, preparer_id)
      AND    org_id = NVL(p_org_id, org_id)      
      AND    xisf.email_sent_date IS NULL
      AND    NVL(active_flag, 'Y') = 'Y'
      AND    NOT EXISTS (SELECT 1
                   FROM   ap_invoices_all aia
                   WHERE  aia.invoice_num = xisf.invoice_num
                   AND    aia.vendor_id = xisf.vendor_internal_id)
      GROUP  BY
             xisf.preparer_id,
             ppf.full_name,
             fu.user_name,
             xisf.org_id;

   r_rcv                     c_rcv%ROWTYPE;
   
   lv_item_type              VARCHAR2(100) := 'POCRECNO';             
   lv_process_name           VARCHAR2(100) := 'POCRECNOTIF';
   lv_item_key               VARCHAR2(100);
   lv_subject_token          VARCHAR2(100);
   lv_email_subject          VARCHAR2(1000);
   lv_print_line             VARCHAR2(5000);
   ln_print_count            NUMBER := 0;
   lv_send_email_flag        VARCHAR2(1) := NVL(p_send_email_flag, 'N');
   ln_po_count               NUMBER := 0;
   l_document_id             CLOB;
   ln_parent_request_id      NUMBER;
   ln_request_id             NUMBER;
   ln_program_id             NUMBER;
   lv_program_name           fnd_concurrent_programs_tl.user_concurrent_program_name%TYPE;
   ln_import_id              NUMBER;
   ln_vendor_id              NUMBER;
             
BEGIN
   gv_procedure_name := 'run_rcpt_reminder_email';
   ln_request_id := fnd_global.conc_request_id;
   ln_program_id := fnd_global.conc_program_id;

   -- arellanod 11/09/2017 FSC-2583
   fnd_file.put_line(fnd_file.log, 'Send Email (Y/N)? = ' || lv_send_email_flag);

   -- arellanod 11/09/2017 FSC-2583
   IF ln_program_id IS NOT NULL THEN
      SELECT user_concurrent_program_name
      INTO   lv_program_name
      FROM   fnd_concurrent_programs_tl
      WHERE  concurrent_program_id = ln_program_id;
   END IF;

   lv_print_line := 'Invoice Number|' ||
                    'Invoice Date|' ||
                    'Invoice Amount(Exc GST)|' ||
                    'Date Received|' ||
                    'Date Processed|' ||
                    'Purchase Order No|' ||
                    'Line Number|' ||
                    'Distribution Number|' ||
                    'Remaining Distribution Amount|' ||
                    'Organization|' ||
                    'Account|' ||
                    'Cost Centre|' ||
                    'Authority|' ||
                    'Project|' ||
                    'Output|' ||
                    'Identifier|' || 
                    'Buyer Name|' ||
                    'Vendor Name|' ||
                    'Vendor Number|' ||
                    'Vendor Site|' ||
                    'Number of Unreceipted Days';

   fnd_file.put_line(fnd_file.output, '');
   fnd_file.put_line(fnd_file.output, 'Program Name:|' || lv_program_name);
   fnd_file.put_line(fnd_file.output, 'Request ID:|' || ln_request_id);
   fnd_file.put_line(fnd_file.output, 'Rundate:|' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
   fnd_file.put_line(fnd_file.output, '');
   fnd_file.put_line(fnd_file.output, lv_print_line);
   
   IF NVL(UPPER(p_notification_type), 'INITIAL') = 'INITIAL' THEN
      FOR c_rec IN c_eligible_requestors -- FSC 5956
      LOOP

         -- arellanod 11/09/2017 FSC-2583
         OPEN c_print_line(c_rec.preparer_id, 'N');
         LOOP
            FETCH c_print_line INTO lv_print_line, ln_import_id, ln_vendor_id;
            EXIT WHEN c_print_line%NOTFOUND;
            fnd_file.put_line(fnd_file.output, lv_print_line);
            ln_print_count := ln_print_count + 1;
         END LOOP;
         CLOSE c_print_line;

         SELECT xxap_req_email_item_key_s.NEXTVAL
         INTO   lv_item_key 
         FROM   dual;
         
         fnd_file.put_line(fnd_file.log, 'wf_notification=POCRECNO-' || lv_item_key || ' import_id=' || c_rec.import_id);
         fnd_file.put_line(fnd_file.log, 'preparer_id=' || c_rec.preparer_id);

         update_item_key(p_item_type    => 'POCRECNO',
                         p_item_key     => lv_item_key,
                         p_preparer_id  => c_rec.preparer_id);
                        
         OPEN  c_get_po_count(c_rec.preparer_id);
         FETCH c_get_po_count INTO ln_po_count;
         CLOSE c_get_po_count ;
   
         IF ln_po_count > 1 THEN
            lv_subject_token := 'Purchase Orders';
         ELSE
            lv_subject_token := 'Purchase Order';
         END IF;           
         
         fnd_message.clear;
         fnd_message.set_name('POC','XXPO_RCPT_EMAIL_SUBJECT');
         fnd_message.set_token('PO',lv_subject_token);
         lv_email_subject := fnd_message.get;          
         
         wf_engine.createprocess('POCRECNO',
                                 lv_item_key,
                                 'POCRECNOTIF');

         wf_engine.setitemattrtext(itemtype => 'POCRECNO' ,
                                   itemkey  => lv_item_key,
                                   aname    => 'POC_RECEIPT_RECIPIENT' ,
                                   avalue   => c_rec.user_name);

         wf_engine.setitemattrtext(itemtype => 'POCRECNO',
                                   itemkey  => lv_item_key,
                                   aname    => 'HTML_SUBJECT',
                                   avalue   => lv_email_subject);

         l_document_id := 'PLSQL:XXAP_INVOICE_IMPORT_PKG.CREATE_WF_INITIAL_DOC/' || lv_item_key;

         wf_engine.setitemattrtext(itemtype => 'POCRECNO',
                                   itemkey  => lv_item_key,
                                   aname    => 'HTML_BODY',
                                   avalue   => l_document_id);

         wf_engine.setitemattrtext(itemtype => 'POCRECNO',
                                   itemkey  => lv_item_key,
                                   aname    => '#FROM_ROLE',
                                   avalue   => 'SYSADMIN');

         wf_engine.startprocess('POCRECNO', lv_item_key);
         
         update_email_sent(p_preparer_id => c_rec.preparer_id,
                           p_days_old    => p_days_old,
                           p_reminder    => 'N');

      END LOOP;

   ELSE 
      -- Reminder Email
      FOR c_rec IN (SELECT preparer_id,
                           user_name,
                           COUNT(1) record_count
                    FROM   xxap_inv_scanned_file xisf,
                           fnd_user fu
                    WHERE  email_sent_date IS NOT NULL
                    AND    TRUNC(SYSDATE) - trunc(email_sent_date) >= p_days_old
                    AND    fu.employee_id = xisf.preparer_id
                    AND    NVL(active_flag, 'Y') = 'Y'
                    AND    preparer_id = NVL(p_requestor_id, xisf.preparer_id)
                    AND    xisf.org_id = NVL(p_org_id, xisf.org_id)
                    /* arellanod 11/09/2017 FSC-2583
                    AND    NOT EXISTS (SELECT 1 
                                       FROM   rcv_transactions x 
                                       WHERE  x.attribute5 = xisf.import_id 
                                       AND    x.transaction_type <> 'CORRECT') 
                    -- Ensure no reminder email is sent out if 
                    -- scanned file has already been receipted.
                    */
                    AND    NOT EXISTS (SELECT 1
                                       FROM   (SELECT h.receipt_num,
                                                      t.attribute5 import_id,
                                                      h.vendor_id,
                                                      NVL(SUM(t.quantity), 0) quantity,
                                                      NVL(SUM(t.amount), 0) amount
                                               FROM   rcv_transactions t,
                                                      rcv_shipment_headers h
                                               WHERE  t.attribute5 IS NOT NULL
                                               AND    t.shipment_header_id = h.shipment_header_id
                                               AND    t.destination_context = 'RECEIVING'
                                               AND    t.transaction_type NOT IN ('DELIVER', 'RETURN TO RECEIVING')
                                               GROUP  BY
                                                      h.receipt_num,
                                                      t.attribute5,
                                                      h.vendor_id
                                               HAVING (NVL(SUM(t.quantity), 0) + NVL(SUM(t.amount), 0)) <> 0) a
                                       WHERE   a.import_id = xisf.import_id
                                       AND     a.vendor_id = xisf.vendor_internal_id)
                    AND    NOT EXISTS (SELECT 1 
                                       FROM   ap_invoices_all x 
                                       WHERE  x.invoice_num = xisf.invoice_num 
                                       AND    x.vendor_id = xisf.vendor_internal_id)
                    GROUP  BY preparer_id,
                              user_name) 
      LOOP
         -- arellanod 11/09/2017 FSC-2583
         OPEN c_print_line(c_rec.preparer_id, 'Y');
         LOOP
            FETCH c_print_line INTO lv_print_line, ln_import_id, ln_vendor_id;
            EXIT WHEN c_print_line%NOTFOUND;

            OPEN c_rcv (ln_import_id, ln_vendor_id);
            FETCH c_rcv INTO r_rcv;
            IF c_rcv%NOTFOUND THEN
               fnd_file.put_line(fnd_file.output, lv_print_line);
               ln_print_count := ln_print_count + 1;
            END IF;
            CLOSE c_rcv;
         END LOOP;
         CLOSE c_print_line;

         SELECT xxap_req_email_item_key_s.nextval
         INTO   lv_item_key 
         FROM   dual;

         OPEN  c_get_po_count_reminder(c_rec.preparer_id);
         FETCH c_get_po_count_reminder INTO ln_po_count;
         CLOSE c_get_po_count_reminder ;
   
         IF ln_po_count > 1 THEN
            lv_subject_token := 'Purchase Orders';
         ELSE
            lv_subject_token := 'Purchase Order';
         END IF;           
         
         fnd_message.clear;
         fnd_message.set_name('POC', 'XXPO_RCPT_REM_EMAIL_SUBJECT');
         fnd_message.set_token('PO', lv_subject_token);
         lv_email_subject := fnd_message.get;          
         
         IF lv_send_email_flag = 'Y' THEN

            wf_engine.createprocess('POCRECNO',
                                    lv_item_key,
                                    'POCRECNOTIF');

            wf_engine.setitemattrtext(itemtype => 'POCRECNO',
                                      itemkey  => lv_item_key,
                                      aname    => 'POC_RECEIPT_RECIPIENT',
                                      avalue   => c_rec.user_name);

            wf_engine.setitemattrtext(itemtype => 'POCRECNO',
                                      itemkey  => lv_item_key,
                                      aname    => 'HTML_SUBJECT',
                                      avalue   => lv_email_subject);

            l_document_id := 'PLSQL:XXAP_INVOICE_IMPORT_PKG.CREATE_WF_REMINDER_DOC/' || c_rec.preparer_id || '~' || p_days_old;         

            wf_engine.setitemattrtext(itemtype => 'POCRECNO',
                                      itemkey  => lv_item_key,
                                      aname    => 'HTML_BODY',
                                      avalue   => l_document_id);

            wf_engine.setitemattrtext(itemtype => 'POCRECNO',
                                      itemkey  => lv_item_key,
                                      aname    => '#FROM_ROLE',
                                      avalue   => 'SYSADMIN');

            wf_engine.startprocess('POCRECNO', lv_item_key);
         
            update_email_sent(p_preparer_id => c_rec.preparer_id,
                              p_days_old    => p_days_old,
                              p_reminder    => 'Y'); 
         END IF;
      END LOOP;

   END IF;

   IF ln_print_count = 0 THEN
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'No data found');
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20501, gv_procedure_name || ' ' || SQLERRM);

END run_rcpt_reminder_email;

-------------------------------------------------------
-- FUNCTION
--     GET_ATTACHMENT_URL
-- Purpose
--     This function derives the attachment for a given invoice
-------------------------------------------------------
FUNCTION get_attachment_url
(
   p_invoice_id      IN NUMBER
)         
RETURN VARCHAR2
IS
   CURSOR c_get_url_from_stg IS
      SELECT nvl(nvl(image_url,po_number_attachment),invoice_id_attachment)
      FROM   xxap_inv_scanned_file
      WHERE  invoice_id = p_invoice_id
      AND    nvl(active_flag,'Y') = 'Y';
      
   CURSOR c_get_url_from_po IS
      SELECT nvl(nvl(image_url,po_number_attachment),invoice_id_attachment)
      FROM   xxap_inv_scanned_file xisf,
             po_headers_all poh,
             ap_invoices_all aia
      WHERE  aia.invoice_id = p_invoice_id
      AND    aia.invoice_num = upper(xisf.invoice_num)
      AND    aia.vendor_id  = poh.vendor_id
      AND    poh.segment1 = xisf.po_number
      AND    aia.org_id = poh.org_id
      AND    nvl(active_flag,'Y') = 'Y';    
      
   lv_url              VARCHAR2(2000) ;        
BEGIN
   OPEN  c_get_url_from_stg;
   FETCH c_get_url_from_stg into lv_url;
   CLOSE c_get_url_from_stg;
   
   IF lv_url IS NOT NULL THEN
      RETURN lv_url;
   ELSE
      OPEN  c_get_url_from_po;
      FETCH c_get_url_from_po into lv_url;
      CLOSE c_get_url_from_po;
   END IF;
   
   RETURN lv_url;
EXCEPTION 
   WHEN OTHERS THEN
      RETURN NULL;   
END get_attachment_url; 

-------------------------------------------------------
-- PROCEDURE
--     ATTACH_URL_HISTORIC
-- Purpose
--         To Attach the URL to the historic Invoices
-------------------------------------------------------
PROCEDURE attach_url_historic
(
   p_org_id              IN   NUMBER,
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
             xxap_inv_scanned_file xisf
      WHERE  aia.org_id = nvl(p_org_id,aia.org_id) 
      AND    aia.invoice_id = xisf.invoice_id
      AND    nvl(active_flag,'Y') = 'Y'
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
   lv_description          fnd_documents_tl.description%TYPE   := 'View Invoice';
   l_pk1_value             fnd_attached_documents.pk1_value%TYPE;

   --lv_filename             fnd_documents_tl.file_name%TYPE; -- URL of the Webpage image
   --lv_invoice_num          ap_invoices_all.invoice_num%TYPE;

BEGIN
   gv_procedure_name := 'attach_url';
   x_status          := 'S'; 
   
   OPEN  c_get_category_id;
   FETCH c_get_category_id INTO ln_category_id;
   CLOSE c_get_category_id;
   
   FOR c_rec IN c_get_unattached_invoices LOOP
   
      BEGIN
      
         SELECT fnd_documents_s.NEXTVAL,
                fnd_attached_documents_s.NEXTVAL
         INTO   ln_document_id,
                ln_attached_document_id
         FROM   dual;

         SELECT nvl(MAX(seq_num),0) + 10
         INTO   ln_seq_num
         FROM   fnd_attached_documents
         WHERE  pk1_value = l_pk1_value
         AND    entity_name = 'AP_INVOICES'; /* As this ap_invoices related and we want those attachments.*/
      
         fnd_documents_pkg.insert_row(
         x_rowid                         => l_rowid,
         x_document_id                   => ln_document_id,
         x_creation_date                 => SYSDATE,
         x_created_by                    => gn_login_id,
         x_last_update_date              => SYSDATE,
         x_last_updated_by               => gn_user_id,
         x_last_update_login             => gn_login_id,
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
         x_created_by                   => gn_user_id,
         x_last_update_date             => sysdate,
         x_last_updated_by              => gn_user_id,
         x_last_update_login            => gn_login_id,
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
         x_created_by                   => gn_user_id,
         x_last_update_date             => SYSDATE,
         x_last_updated_by              => gn_user_id,
         x_last_update_login            => gn_login_id,
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
                last_updated_by = gn_user_id         
         WHERE  invoice_num = c_rec.invoice_num
         AND    vendor_internal_id = c_rec.vendor_id; 

         COMMIT;

         FND_FILE.PUT_LINE(FND_FILE.LOG, 'Successfully attached the attachment for Invoice Number : ' || c_rec.invoice_num );

      EXCEPTION
      WHEN OTHERS THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Error in attaching Invoice Number : ' || c_rec.invoice_num ||' Encountered Error : '||SQLERRM);
      x_status := 'F';
      END;

   END LOOP;

EXCEPTION
   WHEN OTHERS THEN
      x_status := 'F';
      ROLLBACK;
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Unexpected Error in attach_url_historic           : ' || SQLERRM);
      raise_application_error(-20501, gv_procedure_name || ' ' || SQLERRM);
  
END attach_url_historic;


----------------------------------------------------------
-- Procedure
--    purge_interface_data
-- Description
--    Purges data from the Invoice staging table xxap_kofax_inv_stg
--    Data will be deleted if the CREATION_DATE is older than
--    (SYSDATE - p_retention_period)
----------------------------------------------------------
PROCEDURE purge_interface_data
(
   p_table_name            IN VARCHAR2,
   p_retention_period      IN NUMBER 
) IS
   PRAGMA       autonomous_transaction;
   l_sql        VARCHAR2(600);
BEGIN
   -- Put in some protection to avoid malicious use
   IF ( p_table_name NOT LIKE 'XX%INV%STG') THEN
      raise_application_error(-20001, 'Non-Invoice Invoice Staging table passed in. ' ||
         'The table must be a Invoice Staging table of the form XX%INV%STG%');
   ELSIF ( p_retention_period IS NULL OR p_retention_period < 1 ) THEN
      raise_application_error(-20001, 'A positive retention period (in days) must be provided');
   END IF;
   -- now that we're satisfied the table is a Invoice Staging table, do the purge
   l_sql := 'DELETE FROM ' || p_table_name || ' WHERE creation_date < (SYSDATE - :1)';
   EXECUTE IMMEDIATE l_sql USING p_retention_period;
   COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,'Unexpected Error in purge_interface_data : '||SQLERRM);
      ROLLBACK;
      RAISE;
END purge_interface_data;

-------------------------------------------------------
-- FUNCTION
--     LOAD_INVOICE_FROM_KOFAX
-- Purpose
--     This function reads the invoice data from KOFAX tables and dumps into xxap_inv_scanned_file
-------------------------------------------------------
PROCEDURE load_invoices_from_kofax
(
   p_org_id            IN   NUMBER,
   x_status            OUT  VARCHAR2,
   x_err_msg           OUT  VARCHAR2
)
IS
PRAGMA AUTONOMOUS_TRANSACTION;

   lv_error_message         VARCHAR2(2000);
   lv_rec_status            VARCHAR2(10) := 'S';
   ln_success_count         NUMBER := 0;
   ln_failure_count         NUMBER := 0;
   lv_check_vendor          VARCHAR2(10) := 'N';
   lv_check_vendor_site     VARCHAR2(10) := 'N';
   lv_check_ou              VARCHAR2(10) := 'N';
   lv_check_po              VARCHAR2(10) := 'N';
   lv_check_invoice         VARCHAR2(10) := 'N';
   lv_supplier_name         VARCHAR2(240);
   lv_requestor_name        VARCHAR2(240);
   ln_to_num                NUMBER;
   lv_sqlerrm               VARCHAR2(340);
   indx                     NUMBER := 0;   
 
 --TYPE inv_stg_tab IS TABLE OF xxap_inv_scanned_file%ROWTYPE;
   TYPE inv_stg_tab IS TABLE OF inv_rec_type INDEX BY binary_integer;
   c_rec   inv_stg_tab ;

   TYPE t_success_row IS RECORD 
   ( 
      import_id  NUMBER, 
      invoice_amount VARCHAR2(60),
      invoice_number VARCHAR2(50),
      invoice_date  VARCHAR2(50),
      supplier_number VARCHAR2(50),
      supplier_site VARCHAR2(50),
      description VARCHAR2(2000),
      po_number   VARCHAR2(100),
      requestor_name VARCHAR2(240),
      supplier_name VARCHAR2(100)
   );

   TYPE t_success_tab IS TABLE OF t_success_row;
   l_success_tab t_success_tab := t_success_tab();

   TYPE t_failure_row IS RECORD 
   (
      import_id  NUMBER, 
      invoice_amount VARCHAR2(60),
      invoice_number VARCHAR2(50),
      invoice_date  VARCHAR2(50),
      supplier_number VARCHAR2(50),
      supplier_site VARCHAR2(50),
      description VARCHAR2(2000),
      po_number   VARCHAR2(100),
      requestor_name VARCHAR2(240),
      supplier_name VARCHAR2(100)
   );

   TYPE t_failure_tab IS TABLE OF t_success_row;
   l_failure_tab t_failure_tab := t_failure_tab();   
      
   CURSOR c_get_kofax_invoices IS
      SELECT document_id import_id, 
       	     import_status,
       	     NULL attribute1,
       	     NULL attribute2,
             NULL attribute3,
             NULL attribute4,
             NULL attribute5,
             NULL attribute6,
             NULL attribute7,
             NULL attribute8,
             NULL attribute9,
             NULL attribute10,
             NULL attribute11,
             NULL attribute12,
             NULL attribute13,
             NULL attribute14,
             NULL attribute15,
       	     SYSDATE creation_date, 
	   	        SYSDATE last_update_date, 
 	     	     last_updated_by, 
 	     	     created_by, 
 	     	     document_id,
 	     	     po_header_id, 
 	     	     CASE WHEN po_header_id IS NOT NULL THEN image_url ELSE NULL END po_number_attachment,
 	     	     po_number,
 	     	     NULL requisition_number,
 	     	     NULL Requisition_Id, 
 	     	     INVOICE_ID,
 	     	     CASE WHEN invoice_id IS NOT NULL THEN image_url ELSE NULL END invoice_id_attachment,
 	     	     invoice_num,
 	     	     invoice_date, 
 	     	     invoice_received_date, 
 	     	     invoice_amount_exc_gst, 
 	     	     gst_amount, 
 	     	     invoice_amount_inc_gst, 
 	     	     gst_code, 
             currency,
 	     	     NULL po_attachment_complete, 
 	     	     NULL req_prep_name, 
 	     	     NULL email_sent_count,
 	     	     NULL email_sent_date,
             NULL preparer_id,
 	     	     org_id, 
 	     	     vendor_internal_id, 
 	     	     vendor_site_id, 
 	     	     vendor_site_code, 
 	     	     supplier_num, 
 	     	     abn_number,
 	     	     image_url,
 	     	     'Y' active_flag,
 	     	     NULL item_type,
       	     NULL item_key,
             NULL deleted_in_kofax
      FROM   xxap_kofax_inv_stg
      WHERE  NVL(invoice_imported, 'N') IN ('N')--,'E') Do not reprocess the errored records FSC-4197
      FOR UPDATE OF invoice_imported; 

   CURSOR c_check_vendor_id(p_vendor_id NUMBER) IS
      SELECT 'Y' ,
             vendor_name
      FROM   po_vendors
      WHERE  vendor_id = p_vendor_id;
      
   CURSOR c_check_vendor_site_id(p_vendor_site_id NUMBER) IS
      SELECT 'Y' 
      FROM   po_vendor_sites_all
      WHERE  vendor_site_id = p_vendor_site_id;      
      
   CURSOR c_check_ou (p_org_id NUMBER) IS
      SELECT 'Y' 
      FROM   hr_operating_units 
      WHERE  organization_id = p_org_id;
      
   CURSOR c_check_po (p_po_header_id NUMBER,p_org_id NUMBER) IS
      SELECT 'Y' 
      FROM   po_headers_all 
      WHERE  po_header_id = p_po_header_id
      AND    org_id = p_org_id;      

   CURSOR c_check_invoice (p_invoice_id NUMBER,p_org_id NUMBER) IS
      SELECT 'Y' 
      FROM   ap_invoices_all 
      WHERE  invoice_id = p_invoice_id  
      AND    org_id = p_org_id;    
      
   CURSOR c_get_requisition (p_po_header_id NUMBER) IS       
      SELECT -- arellanod 05/09/17
             -- prha.segment1,prha.requisition_header_id,prha.preparer_id 
             prha.requisition_header_id,
             prha.segment1,
             prha.preparer_id
      FROM   po_lines_all pla,
             po_headers_all pha,
             po_line_locations_all plla,
             po_requisition_lines_all prla,
             po_requisition_headers_all prha
      WHERE  pla.po_line_id = plla.po_line_id
      AND    pha.po_header_id = pla.po_header_id
      AND    plla.line_location_id = prla.line_location_id
      AND    prla.requisition_header_id = prha.requisition_header_id
      AND    pha.po_header_id = p_po_header_id;
    
   CURSOR c_get_requestor (p_po_header_id NUMBER) IS
      SELECT ppf.full_name
      FROM   per_all_people_f ppf,
             po_headers_all poh
      WHERE  ppf.person_id = poh.agent_id
      AND    poh.po_header_id = p_po_header_id
      AND    TRUNC(SYSDATE) BETWEEN ppf.effective_start_date AND ppf.effective_end_date;
      /* arellanod 06/09/2017
         FSC-4065
      SELECT ppf.full_name 
      FROM   fmsmgr.xxap_inv_scanned_file xisf,
             po_requisition_headers_all prha,
             po_requisition_lines_all prla,
             po_req_distributions_all prda,
             po_distributions_all pda,
             po_headers_all pha,
             fnd_user fu,
             per_all_people_f ppf
      WHERE  xisf.po_number = pha.segment1
      AND    pha.po_header_id = p_po_header_id
      AND    pda.po_header_id = pha.po_header_id
      AND    prda.requisition_line_id = prla.requisition_line_id
      AND    prda.distribution_id = pda.req_distribution_id
      AND    prha.requisition_header_id = prla.requisition_header_id
      AND    fu.employee_id = prha.preparer_id
      AND    ppf.person_id = fu.employee_id
      AND    TRUNC(SYSDATE) BETWEEN ppf.effective_start_date AND ppf.effective_end_date;
      */

   FUNCTION amount_to_num
   (
      p_value   VARCHAR2
   )
   RETURN VARCHAR2 IS
      ln_to_num  NUMBER;
   BEGIN
      ln_to_num := TO_NUMBER(p_value);

      IF INSTR(p_value, '.') > 0 THEN
         IF NVL(LENGTH(SUBSTR(p_value, INSTR(p_value, '.') + 1, 40)), 0) > 2 THEN
            RETURN 'Amount decimal precision is invalid';
         END IF;
      END IF;
      RETURN NULL;
   EXCEPTION
      WHEN others THEN
         RETURN 'Unable to translate amount value to number data type';
   END amount_to_num;
BEGIN
   gv_procedure_name := 'load_invoices_from_kofax';
   x_status := 'S';
   lv_rec_status := 'S';
   OPEN c_get_kofax_invoices;
   LOOP
      FETCH c_get_kofax_invoices
      BULK COLLECT INTO c_rec;
      EXIT WHEN c_rec.COUNT = 0;
   
      FOR indx IN 1 .. c_rec.COUNT LOOP
         BEGIN
            lv_rec_status        := 'S';
            lv_check_vendor      := 'N';
            lv_check_vendor_site := 'N';
            lv_check_ou          := 'N';
            lv_check_po          := 'N';
            lv_check_invoice     := 'N';
            lv_error_message     := NULL;
            lv_supplier_name     := NULL;
            lv_requestor_name    := NULL;

            c_rec(indx).active_flag := 'Y';
            
            -- Added the validation by Joy pinto on 21-Aug-2017 to check if PO HEader ID and Invoice ID is Invalid
            OPEN c_check_po(c_rec(indx).po_header_id,c_rec(indx).org_id);
            FETCH c_check_po INTO lv_check_po;
            CLOSE c_check_po;
              
            OPEN c_check_invoice(c_rec(indx).invoice_id,c_rec(indx).org_id);
            FETCH c_check_invoice INTO lv_check_invoice;
            CLOSE c_check_invoice;              
   
            IF (c_rec(indx).po_header_id IS NULL AND c_rec(indx).invoice_id IS NULL) OR (nvl(lv_check_invoice,'N')='N' AND nvl(lv_check_po,'N')='N') THEN
               fnd_message.clear;
               fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_PO_INV');
               lv_error_message := lv_error_message||' '||fnd_message.get;
               x_status := 'E';
               lv_rec_status := 'E';
            END IF;

            IF c_rec(indx).po_header_id IS NOT NULL THEN
               IF c_rec(indx).invoice_num IS NULL THEN
                  fnd_message.clear;
                  fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_INVNUM');
                  lv_error_message := lv_error_message||' '||fnd_message.get;
                  x_status := 'E';
                  lv_rec_status := 'E';
               END IF;

               IF c_rec(indx).invoice_date IS NULL THEN
                  fnd_message.clear;
                  fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_INVDATE');
                  lv_error_message := lv_error_message||' '||fnd_message.get;
                  x_status := 'E';
                  lv_rec_status := 'E';
               END IF;

               IF c_rec(indx).invoice_received_date IS NULL THEN
                  fnd_message.clear;
                  fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_INVRCVDT');
                  lv_error_message := lv_error_message||' '||fnd_message.get;
                  x_status := 'E';
                  lv_rec_status := 'E';
               END IF; 

               IF c_rec(indx).invoice_amount_exc_gst IS NULL THEN
                  fnd_message.clear;
                  fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_AMT_EX_GST');
                  lv_error_message := lv_error_message||' '||fnd_message.get;
                  x_status := 'E';
                  lv_rec_status := 'E';
               ELSE
                  lv_sqlerrm := amount_to_num(c_rec(indx).invoice_amount_exc_gst);
                  IF lv_sqlerrm IS NOT NULL THEN
                     lv_error_message := lv_error_message || ' ' || lv_sqlerrm;
                     x_status := 'E';
                     lv_rec_status := 'E';
                  END IF;
               END IF;  

               IF c_rec(indx).gst_amount IS NULL THEN
                  fnd_message.clear;
                  fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_GST_AMT');
                  lv_error_message := lv_error_message||' '||fnd_message.get;
                  x_status := 'E';
                  lv_rec_status := 'E';
               ELSE
                  lv_sqlerrm := amount_to_num(c_rec(indx).gst_amount);
                  IF lv_sqlerrm IS NOT NULL THEN
                     lv_error_message := lv_error_message || ' ' || lv_sqlerrm;
                     x_status := 'E';
                     lv_rec_status := 'E';
                  END IF;
               END IF;  
               IF c_rec(indx).invoice_amount_inc_gst IS NULL THEN
                  fnd_message.clear;
                  fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_AMT_IN_GST');
                  lv_error_message := lv_error_message||' '||fnd_message.get;
                  x_status := 'E';
                  lv_rec_status := 'E';
               ELSE
                  lv_sqlerrm := amount_to_num(c_rec(indx).invoice_amount_inc_gst);
                  IF lv_sqlerrm IS NOT NULL THEN
                     lv_error_message := lv_error_message || ' ' || lv_sqlerrm;
                     x_status := 'E';
                     lv_rec_status := 'E';
                  END IF;
               END IF;  
               /* Fix for FSC-3613 Joy Pinto 22-Aug-2017
               IF c_rec(indx).gst_code IS NULL THEN
                  fnd_message.clear;
                  fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_GST_CODE');
                  lv_error_message := lv_error_message||' '||fnd_message.get;
                  x_status := 'E';
                  lv_rec_status := 'E';
               END IF;  
               IF c_rec(indx).currency IS NULL THEN
                  fnd_message.clear;
                  fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_CURR');
                  lv_error_message := lv_error_message||' '||fnd_message.get;
                  x_status := 'E';
                  lv_rec_status := 'E';
               END IF;*/
               
               OPEN  c_get_requisition(c_rec(indx).po_header_id);
               FETCH c_get_requisition 
               INTO  c_rec(indx).requisition_id,
                     c_rec(indx).requisition_number,
                     c_rec(indx).preparer_id;
               CLOSE c_get_requisition;
      
               IF nvl(c_rec(indx).requisition_id,0) = 0 OR nvl(c_rec(indx).requisition_number,'0') = '0' THEN
                  fnd_message.clear;
                  fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_REQ_NO_ID');
                  lv_error_message := lv_error_message||' '||fnd_message.get;
                  x_status      := 'E';
                  lv_rec_status := 'E';
               END IF;           
               IF c_rec(indx).preparer_id = 0 THEN
                  fnd_message.clear;
                  fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_PREP_ID');
                  lv_error_message := lv_error_message||' '||fnd_message.get;
                  x_status      := 'E';
                  lv_rec_status := 'E';
               END IF;
               
            END IF;    
      
            OPEN c_check_vendor_id(c_rec(indx).vendor_internal_id);
            FETCH c_check_vendor_id INTO lv_check_vendor,lv_supplier_name;
            CLOSE c_check_vendor_id;
      
            IF nvl(lv_check_vendor,'N') = 'N' THEN
               fnd_message.clear;
               fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_V_ID');
               lv_error_message := lv_error_message||' '||fnd_message.get;
               x_status      := 'E';
               lv_rec_status := 'E';
            END IF;
      
            OPEN c_check_vendor_site_id(c_rec(indx).vendor_site_id);
            FETCH c_check_vendor_site_id INTO lv_check_vendor_site;
            CLOSE c_check_vendor_site_id;
      
            IF nvl(lv_check_vendor_site,'N') = 'N' THEN
               fnd_message.clear;
               fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_VSITE_ID');
               lv_error_message := lv_error_message||' '||fnd_message.get;
               x_status      := 'E';
               lv_rec_status := 'E';
            END IF; 
      
            OPEN c_check_ou(c_rec(indx).org_id);
            FETCH c_check_ou INTO lv_check_ou;
            CLOSE c_check_ou;
      
            IF nvl(lv_check_ou,'N') = 'N' THEN
               fnd_message.clear;
               fnd_message.set_name('SQLAPC','XXAP_INV_IMP_MISS_OU_ID');
               lv_error_message := lv_error_message||' '||fnd_message.get;
               x_status      := 'E';
               lv_rec_status := 'E';
            END IF; 
            
            IF nvl(lv_check_po,'N') = 'Y' THEN -- FSC 4197 Fixed by Joy Pinto on 25-Sep-2017
               OPEN  c_get_requestor(c_rec(indx).po_header_id);
               FETCH c_get_requestor INTO lv_requestor_name;
               IF c_get_requestor%NOTFOUND THEN
                  lv_error_message := lv_error_message||' '||'Unable to derive requestor name';
                  x_status      := 'E';
                  lv_rec_status := 'E';                  
               ELSE
                  IF lv_requestor_name IS NULL THEN
                     lv_error_message := lv_error_message||' '||'Unable to derive requestor name';
                     x_status      := 'E';
                     lv_rec_status := 'E';                      
                  END IF;
               END IF;
               CLOSE c_get_requestor;  
            END IF;
      
            IF lv_rec_status = 'S' THEN
               UPDATE xxap_kofax_inv_stg
               SET invoice_imported = 'Y',
                   import_status = 'INTERFACED',
                   error_code = 'S',
                   last_update_date = sysdate,
                   last_updated_by = gn_user_id
               WHERE document_id = c_rec(indx).import_id;              
       
                c_rec(indx).import_status := 'VALIDLOAD';
       
                INSERT INTO XXAP_INV_SCANNED_FILE 
                VALUES c_rec(indx);
                
                ln_success_count := ln_success_count+1;
                l_success_tab.extend();
                l_success_tab(l_success_tab.last).import_id       := c_rec(indx).import_id;               
                l_success_tab(l_success_tab.last).invoice_amount  := c_rec(indx).invoice_amount_exc_gst; 
                l_success_tab(l_success_tab.last).invoice_number  := c_rec(indx).invoice_num; 
                l_success_tab(l_success_tab.last).invoice_date    := c_rec(indx).invoice_date; 
                l_success_tab(l_success_tab.last).supplier_number := c_rec(indx).supplier_num; 
                l_success_tab(l_success_tab.last).supplier_site   := c_rec(indx).vendor_site_code; 
                l_success_tab(l_success_tab.last).description     := c_rec(indx).import_id;   
                l_success_tab(l_success_tab.last).po_number       := c_rec(indx).po_number; 
                l_success_tab(l_success_tab.last).supplier_name   := lv_supplier_name;
                l_success_tab(l_success_tab.last).requestor_name  := lv_requestor_name;
                                               
            ELSE
               UPDATE xxap_kofax_inv_stg
               SET invoice_imported = 'E',
                   IMPORT_STATUS = 'ERROR',
                   error_code = 'E',
                   last_update_date = sysdate,
                   last_updated_by = gn_user_id,
                   error_message = substr(lv_error_message,1,2000)
               WHERE document_id = c_rec(indx).import_id;
             
                --fnd_file.put_line(fnd_file.log, 'Error in validating Document ID  :'||c_rec(indx).import_id ||substr(lv_error_message,1,2000));
               
               c_rec(indx).import_status := 'ERROR';
               
               ln_failure_count := ln_failure_count+1;
               l_failure_tab.extend();
               l_failure_tab(l_failure_tab.last).import_id       := c_rec(indx).import_id;
               l_failure_tab(l_failure_tab.last).invoice_amount  := c_rec(indx).invoice_amount_exc_gst;
               l_failure_tab(l_failure_tab.last).invoice_number  := c_rec(indx).invoice_num;
               l_failure_tab(l_failure_tab.last).invoice_date    := c_rec(indx).invoice_date;
               l_failure_tab(l_failure_tab.last).supplier_number := c_rec(indx).supplier_num;
               l_failure_tab(l_failure_tab.last).supplier_site   := c_rec(indx).vendor_site_code;
               l_failure_tab(l_failure_tab.last).description     := substr(lv_error_message,1,2000);
               l_failure_tab(l_failure_tab.last).po_number       := c_rec(indx).po_number; 
               l_failure_tab(l_failure_tab.last).supplier_name   := lv_supplier_name;
               l_failure_tab(l_failure_tab.last).requestor_name  := lv_requestor_name;               
            END IF;
            COMMIT;
         EXCEPTION
          WHEN OTHERS THEN 
             fnd_file.put_line(fnd_file.log, 'Unexpected Error in validating Document ID  :'||c_rec(indx).import_id ||SQLERRM);
             ROLLBACK;
         END ;
      END LOOP;
   END LOOP;
   -- Purge the records which are older than retention days
   -- Added by Joy Pinto on 20-Jun-2016 as per Email from Pankaj for deleting the records from XXAP_KOFAX_INV_STG
   fnd_file.new_line(fnd_file.log);
   fnd_file.put_line(fnd_file.log,'Purging data above retention period Start');
   purge_interface_data('XXAP_KOFAX_INV_STG',nvl(fnd_profile.value('XXINT_DEFAULT_RETENTION'),90));
   fnd_file.new_line(fnd_file.log);
   fnd_file.put_line(fnd_file.log,'Purging data above retention period End');

   fnd_file.new_line(fnd_file.log);
   fnd_file.put_line(fnd_file.log,'************************Summary of Invoice Load from Kofax Start****************************************************');
   fnd_file.new_line(fnd_file.log);
   IF ln_success_count > 0 THEN
      fnd_file.put_line(fnd_file.log,'*********************Invoices Validated and Interfaced to custom table successfully***************************'); 
      fnd_file.new_line(fnd_file.log);
      fnd_file.put_line(fnd_file.log,'Document ID   Invoice Amount   Invoice Number   Invoice Date   Supplier Name            Supplier Number   Supplier Site   PO Number   Requestor   '); 
      fnd_file.new_line(fnd_file.log);
      FOR indx in l_success_tab.FIRST .. l_success_tab.LAST LOOP
         fnd_file.put_line(fnd_file.log,
                           rpad(l_success_tab(indx).import_id,14,' ')||
                           rpad(l_success_tab(indx).invoice_amount,17,' ')||
                           rpad(l_success_tab(indx).invoice_number,17,' ')||
                           rpad(l_success_tab(indx).invoice_date,15,' ')||
                           rpad(l_success_tab(indx).supplier_name,25,' ')||
                           rpad(l_success_tab(indx).supplier_number,18,' ')||
                           rpad(l_success_tab(indx).supplier_site,16,' ')||
                           rpad(l_success_tab(indx).po_number,12,' ')||
                           l_success_tab(indx).requestor_name
                          );
      END LOOP;
      fnd_file.new_line(fnd_file.log);
   END IF;

   IF ln_failure_count > 0 THEN
      fnd_file.put_line(fnd_file.log,'************************Invoices not Validated and Interfaced to custom table**************************************'); 
      fnd_file.new_line(fnd_file.log);
      fnd_file.put_line(fnd_file.log,'Document ID   Invoice Amount   Invoice Number   Invoice Date   Supplier Name            Supplier Number   Supplier Site   PO Number   Requestor      Error Message     '); 
      fnd_file.new_line(fnd_file.log);
      FOR indx in l_failure_tab.FIRST .. l_failure_tab.LAST LOOP
         fnd_file.put_line(fnd_file.log,
                           rpad(l_failure_tab(indx).import_id,14,' ')||
                           rpad(l_failure_tab(indx).invoice_amount,17,' ')||
                           rpad(l_failure_tab(indx).invoice_number,17,' ')||
                           rpad(l_failure_tab(indx).invoice_date,15,' ')||
                           rpad(l_failure_tab(indx).supplier_name,25,' ')||
                           rpad(l_failure_tab(indx).supplier_number,18,' ')||
                           rpad(nvl(l_failure_tab(indx).supplier_site,' '),16,' ')||
                           rpad(nvl(l_failure_tab(indx).po_number,' '),12,' ')||
                           rpad(nvl(l_failure_tab(indx).requestor_name,' '),15,' ')||
                           l_failure_tab(indx).description
                          );
      END LOOP;
      fnd_file.new_line(fnd_file.log);
   END IF;
   fnd_file.put_line(fnd_file.log,'************************Summary of Invoice Load from Kofax End****************************************************');
   fnd_file.new_line(fnd_file.LOG);

   COMMIT;
EXCEPTION 
   WHEN OTHERS THEN
      x_status :='E';  
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Unexpected Error Encountered in the procedure  '||gv_procedure_name || SQLERRM );
      x_err_msg := SQLERRM;
      ROLLBACK;
END load_invoices_from_kofax; 

-------------------------------------------------------
-- PROCEDURE
--     IMPORT_INVOICES
-- Purpose
--     This procedure is called from the concurrent program - DEDJTR Invoice Scan Import Program XXAPINVIMPORT
--     This program kicks off 
--        (1) the import of released invoices from Kofax, 
--        (2) sending emails to requestors to receipt the POs
--        (3) Attaching the Scanned Invoice URL to historic Invoices
-------------------------------------------------------
PROCEDURE import_invoices
(
   p_errbuf            OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_org_id            IN  NUMBER
)
IS
   -- SRS
   srs_wait                   BOOLEAN;
   srs_phase                  VARCHAR2(30);
   srs_status                 VARCHAR2(30);
   srs_dev_phase              VARCHAR2(30);
   srs_dev_status             VARCHAR2(30);
   srs_message                VARCHAR2(240);
   ln_request_id              NUMBER;
   lv_completion_text         fnd_concurrent_requests.completion_text%TYPE; 
   
   lv_status                  VARCHAR2(30);
   lv_err_msg                 VARCHAR2(2000);
BEGIN
   -- Step 1 load Invoices from KOFAX
   fnd_file.put_line(fnd_file.log,'Stage 1 Start - Validating and Importing of invoice metadata into the custom scan table started');
   fnd_file.new_line(fnd_file.log);

   load_invoices_from_kofax(p_org_id  => p_org_id,
                            x_status  => lv_status,
                            x_err_msg => lv_err_msg);   
   
   -- Step 2 Send Initial Email
   IF nvl(lv_status,'F') != 'S' THEN
      p_retcode := 1;
      fnd_file.put_line(fnd_file.log,'Stage 1 End - Importing of invoice metadata from Kofax has ended in a warning Please refer to the above log for details - '||lv_err_msg);
   ELSE
      fnd_file.put_line(fnd_file.log,'Stage 1 End - Validating and Importing of invoice metadata into the custom scan table completed');
   END IF;
   fnd_file.put_line(fnd_file.log,'Stage 2 Start - "DEDJTR POs to Receipt Notification" program started');

   ln_request_id := fnd_request.submit_request(application => 'POC',
                                               program     => 'XXPORECNOTIF',
                                               description => NULL,
                                               start_time  => NULL,
                                               sub_request => FALSE,
                                               argument1   => NULL,        -- Requestor Name
                                               argument2   => 0,           -- Days Old
                                               argument3   => 'Initial',   -- Notification Type
                                               argument4   => 'Y',         -- Send Email arellanod 12/09/2017 FSC-
                                               argument5   => p_org_id
                                              );

   COMMIT;

   fnd_file.new_line(fnd_file.LOG);
   fnd_file.put_line(fnd_file.LOG, 'Requestor Email  Request ID (' || ln_request_id || ')');  
      
   srs_wait := fnd_concurrent.wait_for_request(ln_request_id,
                                               10,
                                               0,
                                               srs_phase,
                                               srs_status,
                                               srs_dev_phase,
                                               srs_dev_status,
                                               srs_message
                                              );      
      
   IF NOT (srs_dev_phase = 'COMPLETE' AND
          (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
      SELECT completion_text
      INTO   lv_completion_text
      FROM   fnd_concurrent_requests
      WHERE  request_id = ln_request_id;
         
      fnd_file.put_line(fnd_file.log, lv_completion_text);
      fnd_file.put_line(fnd_file.log,'Stage 2 End - "DEDJTR POs to Receipt Notification" program failed, Please refer to the log file of request ID '||ln_request_id);
      p_retcode := 1;
   ELSE
      -- Success Attach Invoices to historic Invoices
      fnd_file.put_line(fnd_file.log, lv_completion_text);
      fnd_file.put_line(fnd_file.log,'Stage 2 End - "DEDJTR POs to Receipt Notification" program completed - request ID '||ln_request_id);
   END IF;

   fnd_file.put_line(fnd_file.log,'Stage 3 Start - Attach Historic Invoice process started');

   attach_url_historic(p_org_id => p_org_id,
                       x_status => lv_status);

   IF nvl(lv_status,'F') = 'S' THEN
      fnd_file.new_line(fnd_file.LOG);
      fnd_file.put_line(fnd_file.log,'Stage 3 End - Attach Historic Invoice process completed ');
   ELSE
      p_retcode := 1;
      fnd_file.put_line(fnd_file.log,'Stage 3 End - Attach Historic Invoice process is unsuccessful, please refer to the preceeding log file ');          
   END IF;
   
EXCEPTION 
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,'Unexpected Error Occurred in import_invoices- '|| SQLERRM);
      p_retcode := 2;
      raise_application_error(-20501, gv_procedure_name || ' ' || SQLERRM);  
      
END import_invoices; 

-------------------------------------------------------
-- PROCEDURE
--     DEACTIVATE_INVOICE
-- Purpose
--     This procedure is called from the concurrent program - DEDJTR Deactivate Scanned Invoice XXAP_DEL_KOFAX_INVOICE
--     This program 
--     (1) updates xxap_inv_scanned_file.ACTIVE_FLAG = 'N'
--     (2) Calls a Stored procedure from KOFAX to delete the invoice in KOFAX
-------------------------------------------------------
PROCEDURE deactivate_invoice
(
   p_errbuf            OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_payload_id    IN  NUMBER
)
IS

BEGIN
   UPDATE xxap_inv_scanned_file
   SET    active_flag = 'N',
          last_update_date = sysdate,
          last_updated_by = gn_user_id   
   WHERE  payload_id  = p_payload_id
   AND    nvl(active_flag,'Y') = 'Y';
   
   UPDATE xxap_kofax_inv_stg
   SET    invoice_imported = 'D',
          last_update_date = sysdate,
          last_updated_by = gn_user_id   
   WHERE  document_id  = p_payload_id;
     
   COMMIT;
   
   FND_FILE.PUT_LINE(FND_FILE.LOG,'Successfully deactivated the Invoice Corresponding to Payload_id = '|| p_payload_id);
EXCEPTION 
   WHEN OTHERS THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Unexpected Error Occurred - '|| SQLERRM);
      p_retcode := 2;
      raise_application_error(-20501, gv_procedure_name || ' ' || SQLERRM);        
END deactivate_invoice; 

END XXAP_INVOICE_IMPORT_PKG;
/
