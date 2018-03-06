create or replace PACKAGE BODY dot_ar_print_invoices_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.03.01/arc/1.0.0/install/sql/DOT_AR_PRINT_INVOICES_PKG.pkb 1055 2017-06-21 03:20:11Z svnuser $ */
/******************************************************************************
**
**  Purpose: Enhance existing Invoice Print Selected Invoices customisation
**           (ARCINVBIP.rdf including templates) to address following issues:
**           (1) Report output has excessive in-between spaces before and after the
**               body region because both header and footer objects are all hooked
**               together in a subtemplate.
**           (2) Unable to control report footer (payment options) to display on
**               first page only regardless of page count.
**           (3) Hidden payment option leaves lull spaces make the report look
**               aesthetically poor.
**           (4) Multiple templates combined in one template added layer of complexity
**               for the user. Hence, minor or simple modification of layout requires
**               developer skills.
**           (5) Testing is tedious because all templates were combined in one. Regardless
**               whether only one particular template was modified all transaction types
**               have to be tested to ensure others remain intact.
**           (6) Unable to send output directly to printer.
**           (7) Unable to print in DUPLEX mode (printing front and back of page). No
**               mechanism to send instructions to printer - Print on front page for every
**               transaction (multiple invoices in one PDF file).
**           (8) No capability to email document as attachment.
**
**  Author: Dart Arellano UXC Red Rock Consulting
**
**  $Date: $
**
**  $Revision: $
**
**  Histroy  : Refer to Source Control
**    Date          Author                Description
**    -----------   --------------------  ---------------------------------------------------
**    26-Feb-2016   S.Ryan (Red Rock)     Fix to prevent PDF output from spooling to printer.
**    05-Feb-2016   S.Ryan (Red Rock)     Further prevented printing directly from Oracle by overriding Conc Copies
**
******************************************************************************/

-- Defaulting Rules
-- Static data stored in a parameter table. Can be changed in the future
-- if necessary.
gn_default_user_id     NUMBER;
gn_default_resp_id     NUMBER;
gn_default_appl_id     NUMBER;
gv_default_user_name   VARCHAR2(150);
gv_default_output      VARCHAR2(15);
gv_default_sender      VARCHAR2(240);
gv_content_type        VARCHAR2(80);
gv_common_out          VARCHAR2(80);
gn_curr_user_id        NUMBER;
gv_email_delim         VARCHAR2(1) := ',';


TYPE invtype IS REF CURSOR;
TYPE t_email_addr IS TABLE OF VARCHAR2(150) INDEX BY binary_integer;
TYPE t_ref_cur IS TABLE OF dot_ar_print_invoices_v%ROWTYPE INDEX BY binary_integer;

CURSOR c_type (p_trx_type VARCHAR2) IS
   SELECT CASE WHEN UPPER(meaning) = 'INVOICE'
                  THEN 'TAX INVOICE'
               WHEN UPPER(meaning) = 'CREDIT MEMO'
                  THEN 'CREDIT ADJUSTMENT NOTE'
               WHEN UPPER(meaning) = 'DEBIT MEMO'
                  THEN 'DEBIT ADJUSTMENT NOTE'
               ELSE UPPER(meaning) || ' '
          END
   FROM   ar_lookups
   WHERE  lookup_type = 'INV/CM'
   AND    lookup_code = p_trx_type;

PROCEDURE build_merge_command
(
   p_request_id   NUMBER
)
IS
   lf_sh_file     UTL_FILE.FILE_TYPE;
   lv_line        VARCHAR2(600);
   lv_file_name   VARCHAR2(80);
   ln_files       NUMBER;
   ln_file_ctr    NUMBER := 0;
BEGIN
   SELECT parent_file_name, COUNT(1)
   INTO   lv_file_name, ln_files
   FROM   dot_ar_print_invoices
   WHERE  request_id = p_request_id
   GROUP  BY parent_file_name;

   -- Start file write
   lf_sh_file := UTL_FILE.FOPEN('TMP_DIR', 'DOTINVPSMERGE.tmp', 'W');

   UTL_FILE.PUT_LINE(lf_sh_file, 'PATH=$PATH:/usr/sfw/bin; export PATH');
   UTL_FILE.PUT_LINE(lf_sh_file, '');
   UTL_FILE.PUT_LINE(lf_sh_file, 'rm $ARC_TOP/out/DOTINVPSMERGE.PDF');
   UTL_FILE.PUT_LINE(lf_sh_file, '');
   UTL_FILE.PUT_LINE(lf_sh_file, 'gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -sOutputFile=$ARC_TOP/out/DOTINVPSMERGE.PDF \');

   FOR i IN (SELECT p.parent_file_name,
                    p.sub_request_id
             FROM   dot_ar_print_invoices p
             WHERE  p.request_id = p_request_id
             AND    p.status = 'S'
             ORDER  BY p.merge_sequence)
   LOOP
      ln_file_ctr := ln_file_ctr + 1;
      IF ln_file_ctr = ln_files THEN
         lv_line := '$APPLCSF/$APPLOUT/DOTINVPSREM_' || i.sub_request_id || '_1.PDF';
      ELSE
         lv_line := '$APPLCSF/$APPLOUT/DOTINVPSREM_' || i.sub_request_id || '_1.PDF \';
      END IF;
      UTL_FILE.PUT_LINE(lf_sh_file, lv_line);
   END LOOP;

   lv_line := '';
   UTL_FILE.PUT_LINE(lf_sh_file, lv_line);

   UTL_FILE.PUT_LINE(lf_sh_file, 'if [ -s $ARC_TOP/out/DOTINVPSMERGE.PDF ]; then');
   lv_line := '   cp $ARC_TOP/out/DOTINVPSMERGE.PDF $APPLCSF/$APPLOUT/' || lv_file_name;
   UTL_FILE.PUT_LINE(lf_sh_file, lv_line);
   UTL_FILE.PUT_LINE(lf_sh_file, 'else');
   UTL_FILE.PUT_LINE(lf_sh_file, '   echo "Error collecting output files"');
   UTL_FILE.PUT_LINE(lf_sh_file, '   exit 1');
   UTL_FILE.PUT_LINE(lf_sh_file, 'fi');
   UTL_FILE.PUT_LINE(lf_sh_file, '');
   UTL_FILE.FCLOSE(lf_sh_file);
   -- End file write

END build_merge_command;


PROCEDURE dispatch_invoices
(
   p_errbuff               OUT VARCHAR2,
   p_retcode               OUT NUMBER,
   p_order_by              IN  VARCHAR2,
   p_trx_class             IN  VARCHAR2,
   p_cust_trx_type_id      IN  NUMBER,
   p_trx_number_low        IN  VARCHAR2,
   p_trx_number_high       IN  VARCHAR2,
   p_date_low              IN  VARCHAR2,
   p_date_high             IN  VARCHAR2,
   p_customer_class_code   IN  VARCHAR2,
   p_customer_id           IN  NUMBER,
   p_installment_num       IN  NUMBER,
   p_open_only             IN  VARCHAR2,
   p_tax_reg               IN  VARCHAR2,
   p_new_trx_only          IN  VARCHAR2,
   p_batch_id              IN  VARCHAR2,
   p_printer_name          IN  VARCHAR2,
   p_print_command_line    IN  VARCHAR2,
   p_email_function        IN  VARCHAR2
)
IS
   CURSOR c_req_out (p_this_request NUMBER) IS
      SELECT sub_request_id request_id,
            (SELECT user_name
             FROM   fnd_user
             WHERE  user_id = gn_default_user_id) requested_by,
             trx_number,
             DECODE(status,
                    'S', 'Success',
                    'E', 'Error',
                    'Unknown') status,
             DECODE(delivery_option,
                    NULL, DECODE(p_email_function, 'Y', 'Email', 'Not specified'),
                    'E', 'Email',
                    'P', 'Print',
                    'Not specified') delivery_option
      FROM   dot_ar_print_invoices
      WHERE  request_id = p_this_request;

   CURSOR c_prt_line (p_this_request NUMBER) IS
      SELECT 'DOTINVPSREM_' || p.sub_request_id || '_1.PDF' file_name
      FROM   dot_ar_print_invoices p
      WHERE  p.request_id = p_this_request
      AND    p.status = 'S'
      AND    p.delivery_option = 'P'
      ORDER  BY p.merge_sequence;

   --arellanod 11-Sep-2014
   CURSOR c_email (p_this_request NUMBER) IS
      SELECT p.sub_request_id
      FROM   dot_ar_print_invoices p,
             dot_ar_print_invoices_v v
      WHERE  p.customer_trx_id = v.customer_trx_id
      AND    p.request_id = p_this_request
      AND    p.status = 'S'
      AND    v.email_address IS NOT NULL
      AND    v.transmission_method = 'EMAIL'
      AND    p.delivery_option IS NULL;

   lv_username          VARCHAR2(100);
   ln_this_request      NUMBER;
   ln_org_id            NUMBER;
   ln_trx_id_low        NUMBER;
   ln_trx_id_high       NUMBER;
   lv_sql               VARCHAR2(10000);
   ln_sub_req_id        NUMBER;
   ln_par_req_id        NUMBER;
   ln_wait              NUMBER;
   lv_parent_file       VARCHAR2(150);
   lv_log               VARCHAR2(340);
   lv_delivery          VARCHAR2(1);
   lv_remit_email       VARCHAR2(240);
   ln_process_limit     NUMBER := 100;
 --ln_c_rec_count       NUMBER := 0;
   ln_merge_order       NUMBER;
   lv_batch             ra_batches_all.name%TYPE;
   lt_ref_cur           t_ref_cur;

 --b_deliver            BOOLEAN;
   b_layout             BOOLEAN;
   b_print              BOOLEAN;
   sw_rec               NUMBER := 1;
   c_inv                invtype;
   x_inv                invtype;
   r_inv                dot_ar_print_invoices_v%ROWTYPE;

   lv_desc              VARCHAR2(240);

   -- SRS
   srs_wait             BOOLEAN;
   srs_phase            VARCHAR2(30);
   srs_status           VARCHAR2(30);
   srs_dev_phase        VARCHAR2(30);
   srs_dev_status       VARCHAR2(30);
   srs_message          VARCHAR2(240);

BEGIN
   FND_PROFILE.GET('ARCINVPS_EFT_REMIT_EMAIL', lv_remit_email);
   lv_remit_email := 'no-reply' || SUBSTR(lv_remit_email, INSTR(lv_remit_email, '@'), 150);

   -- Get default parameters
   SELECT dispatch_user_id,
          dispatch_resp_id,
          dispatch_appl_id,
          default_output_type,
          default_sender,
          content_type,
          common_out_directory
   INTO   gn_default_user_id,
          gn_default_resp_id,
          gn_default_appl_id,
          gv_default_output,
          gv_default_sender,
          gv_content_type,
          gv_common_out
   FROM   dot_ar_print_parameters;

   --gv_default_sender := lv_remit_email;
   --Instructions from Tina P: Use applmgr@doi.vic.gov.au email account
   --to be able to receive back bounced emails due to incorrect recipient
   --email address.

   SELECT user_name
   INTO   gv_default_user_name
   FROM   fnd_user
   WHERE  user_id = gn_default_user_id;

   FND_FILE.PUT_LINE(FND_FILE.LOG, '');
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Default Parameters (DOT_AR_PRINT_PARAMETERS)');
   FND_FILE.PUT_LINE(FND_FILE.LOG, '--------------------------------------------');
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'dispatch_user_id       : ' || gn_default_user_id);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'dispatch_resp_id       : ' || gn_default_resp_id);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'dispatch_appl_id       : ' || gn_default_appl_id);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'default_output_type    : ' || gv_default_output);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'default_sender         : ' || gv_default_sender);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'content_type           : ' || gv_content_type);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'common_out_directory   : ' || gv_common_out);
   FND_FILE.PUT_LINE(FND_FILE.LOG, '');
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Run Arguments');
   FND_FILE.PUT_LINE(FND_FILE.LOG, '-------------');
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_order_by             : ' || p_order_by);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_trx_class            : ' || p_trx_class);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_cust_trx_type_id     : ' || p_cust_trx_type_id);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_trx_number_low       : ' || p_trx_number_low);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_trx_number_high      : ' || p_trx_number_high);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_date_low             : ' || p_date_low);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_date_high            : ' || p_date_high);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_customer_class_code  : ' || p_customer_class_code);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_customer_id          : ' || p_customer_id);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_installment_num      : ' || p_installment_num);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_open_only            : ' || p_open_only);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_tax_reg              : ' || p_tax_reg);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_new_trx_only         : ' || p_new_trx_only);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_batch_id             : ' || p_batch_id);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_printer_name         : ' || p_printer_name);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_print_command_line   : ' || p_print_command_line);
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'p_email_function       : ' || p_email_function);

   FND_PROFILE.GET('RESP_ID', gn_default_resp_id);
   FND_PROFILE.GET('USER_ID', gn_curr_user_id);
   FND_PROFILE.GET('ORG_ID', ln_org_id);
   FND_PROFILE.GET('USERNAME', lv_username);
   ln_this_request := FND_GLOBAL.CONC_REQUEST_ID;

   lv_sql := 'SELECT * FROM dot_ar_print_invoices_v WHERE 1 = 1';

   IF p_trx_class IS NOT NULL THEN
      lv_sql := lv_sql || ' AND trx_type = ''' || p_trx_class || '''';
   END IF;

   IF p_cust_trx_type_id IS NOT NULL THEN
      lv_sql := lv_sql || ' AND cust_trx_type_id = ' || p_cust_trx_type_id;
   END IF;

   IF p_trx_number_low IS NOT NULL THEN
      BEGIN
         SELECT customer_trx_id
         INTO   ln_trx_id_low
         FROM   ra_customer_trx_all
         WHERE  trx_number = p_trx_number_low
         AND    org_id = ln_org_id;
      EXCEPTION
         WHEN no_data_found THEN NULL;
         WHEN others THEN
            FND_FILE.PUT_LINE(FND_FILE.LOG, '');
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'Error selecting Transaction Number ' || p_trx_number_low || '. ' || SQLERRM);
            p_retcode := 2;
            RETURN;
      END;
   END IF;

   IF p_trx_number_high IS NOT NULL THEN
      BEGIN
         SELECT customer_trx_id
         INTO   ln_trx_id_high
         FROM   ra_customer_trx_all
         WHERE  trx_number = p_trx_number_high
         AND    org_id = ln_org_id;
      EXCEPTION
         WHEN no_data_found THEN NULL;
            FND_FILE.PUT_LINE(FND_FILE.LOG, '');
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'Error selecting Transaction Number ' || p_trx_number_high || '. ' || SQLERRM);
            p_retcode := 2;
            RETURN;
      END;
   END IF;

   IF ln_trx_id_low IS NOT NULL THEN
      lv_sql := lv_sql || ' AND trx_number >= ''' || p_trx_number_low || '''';
   END IF;

   IF ln_trx_id_high IS NOT NULL THEN
      lv_sql := lv_sql || ' AND trx_number <= ''' || p_trx_number_high || '''';
   END IF;

   --lv_sql := lv_sql || ' AND customer_trx_id BETWEEN ' || ln_trx_id_low || ' AND ' || ln_trx_id_high;

   IF p_date_low IS NOT NULL THEN
      lv_sql := lv_sql || ' AND trx_date >= TO_DATE(''' || p_date_low || '''' || ', ' || '''' || 'YYYY/MM/DD HH24:MI:SS' || ''')';
   END IF;

   IF p_date_high IS NOT NULL THEN
      lv_sql := lv_sql || ' AND trx_date <= TO_DATE(''' || p_date_high || '''' || ', ' || '''' || 'YYYY/MM/DD HH24:MI:SS' || ''')';
   END IF;

   IF p_customer_class_code IS NOT NULL THEN
      lv_sql := lv_sql || ' AND customer_class_code = ''' || p_customer_class_code || '''';
   END IF;

   IF p_customer_id IS NOT NULL THEN
      lv_sql := lv_sql || ' AND customer_id = ' || p_customer_id;
   END IF;

   IF p_open_only = 'Y' THEN
      lv_sql := lv_sql || ' AND status_trx = ''' || 'OP' || '''';
   END IF;

   IF p_new_trx_only = 'Y' THEN
      lv_sql := lv_sql || ' AND printing_count = 0';
   END IF;

   IF p_batch_id IS NOT NULL THEN
      lv_sql := lv_sql || ' AND batch_id = ' || p_batch_id;
   END IF;

   -- Order by
   IF p_order_by = 'CUSTOMER' THEN
      lv_sql := lv_sql || ' ORDER BY customer_name, trx_number_order';
   ELSIF p_order_by = 'POSTAL_CODE' THEN
      lv_sql := lv_sql || ' ORDER BY postal_code, trx_number_order';
   ELSIF p_order_by = 'TRX_NUMBER' THEN
      lv_sql := lv_sql || ' ORDER BY trx_number_order';
   END IF;

   -- Determine result count before
   -- creating output files. Limit number of documents to 100
   -- to anticipate PDF merging memory error.
   -- Test if cursor is valid.
   -- FND_FILE.PUT_LINE(FND_FILE.LOG, 'DEBUG: ' || lv_sql);
   BEGIN
      OPEN x_inv FOR lv_sql;
      FETCH x_inv BULK COLLECT INTO lt_ref_cur;
      --LOOP
      --   FETCH x_inv INTO r_inv;
      --   EXIT WHEN x_inv%NOTFOUND;
      --   ln_c_rec_count := ln_c_rec_count + 1;
      --END LOOP;
      CLOSE x_inv;
   EXCEPTION
      WHEN others THEN
         FND_FILE.PUT_LINE(FND_FILE.LOG, 'c_inv                  : ' || SQLERRM);
         FND_FILE.PUT_LINE(FND_FILE.LOG, '                         ' || lv_sql);
         p_retcode := 2;
         RETURN;
   END;

   FND_FILE.PUT_LINE(FND_FILE.LOG, '');

   --IF ln_c_rec_count > ln_process_limit THEN
   IF lt_ref_cur.COUNT > ln_process_limit THEN
      IF p_batch_id IS NULL THEN
         IF NVL(p_new_trx_only, 'N') = 'Y' THEN
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'Unable to process number of new transactions (' ||
                                            --ln_c_rec_count || '). ' ||
                                            lt_ref_cur.COUNT || '). ' ||
                                            'Please use batch print or limit range to ' ||
                                            ln_process_limit ||
                                            ' transactions.');
         ELSE
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'Unable to process number of transactions (' ||
                                            --ln_c_rec_count || '). ' ||
                                            lt_ref_cur.COUNT || '). ' ||
                                            'Please limit range to ' ||
                                            ln_process_limit ||
                                            ' transactions.');
         END IF;
      ELSE
         BEGIN
            SELECT name
            INTO   lv_batch
            FROM   ra_batches_all
            WHERE  batch_id = p_batch_id;
         EXCEPTION
            WHEN no_data_found THEN NULL;
         END;

         FND_FILE.PUT_LINE(FND_FILE.LOG, 'Unable to process number of transactions in this batch ' ||
                                          NVL(lv_batch, p_batch_id) ||
                                          '. Please limit range to ' ||
                                          ln_process_limit ||
                                          ' transactions.');
      END IF;
      p_retcode := 2;
      RETURN;
   END IF;

   --halt here - used for testing
   --RETURN;

   -------------------------
   -- Dispatch invoices   --
   -------------------------
   OPEN c_inv FOR lv_sql;
   LOOP
      FETCH c_inv INTO r_inv;
      EXIT WHEN c_inv%NOTFOUND;

      IF check_invoice_range(p_trx_number_low, p_trx_number_high, r_inv.trx_number) THEN
         IF sw_rec = 1 THEN
            -- Use parent request PDF file
            -- for merging.
            b_layout := FND_REQUEST.ADD_LAYOUT(template_appl_name => 'ARC',
                                               template_code => r_inv.template_code,
                                               template_language => 'en',
                                               template_territory => 'US',
                                               output_format => gv_default_output);

          /* S.Ryan 05-May-2016
          -- Setting copies to zero to prevent spooling of PDF to printer
          -- directly from EBS.  Printing of this directly from Oracle causes
          -- gobbledegook to be printed.
          */
          b_print := FND_REQUEST.SET_PRINT_OPTIONS(copies => 0);
          if b_print then
            fnd_file.put_line(fnd_file.log, 'Concurrent Copies set to 0 on first submission of DOTINVPSREM');
          else
            fnd_file.put_line(fnd_file.log, 'Concurrent Copies NOT able to be set to 0 on first submission of DOTINVPSREM ... you will get gobbledegook printed!');
          end if;

            ln_par_req_id := FND_REQUEST.SUBMIT_REQUEST(application => 'ARC',
                                                        program     => 'DOTINVPSREM',
                                                        description => 'DTPLI Output File Collection - ' || ln_this_request,
                                                        start_time  => NULL,
                                                        sub_request => FALSE,
                                                        argument1   => p_order_by,
                                                        argument2   => NULL,
                                                        argument3   => NULL,
                                                        argument4   => r_inv.trx_number,
                                                        argument5   => r_inv.trx_number,
                                                        argument6   => NULL,
                                                        argument7   => NULL,
                                                        argument8   => NULL,
                                                        argument9   => NULL,
                                                        argument10  => NULL,
                                                        argument11  => p_open_only,
                                                        argument12  => NULL);

            lv_parent_file := 'DOTINVPSREM_' || ln_par_req_id || '_1.PDF';

            COMMIT;
         END IF;

         IF ln_par_req_id IS NOT NULL THEN
            IF sw_rec = 1 THEN
               FND_GLOBAL.APPS_INITIALIZE(USER_ID      => gn_default_user_id,
                                          RESP_ID      => gn_default_resp_id,
                                          RESP_APPL_ID => gn_default_appl_id);
               sw_rec := 0;
            END IF;

            ln_merge_order := NVL(ln_merge_order, 0) + 1;
            lv_delivery := NULL;

            lv_desc := NULL;

            OPEN c_type (r_inv.trx_type);
            FETCH c_type INTO lv_desc;
            CLOSE c_type;

            lv_desc := lv_desc || ' ' || r_inv.trx_number;

            IF p_printer_name IS NOT NULL THEN
               IF NVL(r_inv.transmission_method, 'PRINT') = 'PRINT' THEN
                  lv_delivery := 'P';
                  IF p_print_command_line = 'N' THEN
                     b_print := FND_REQUEST.SET_PRINT_OPTIONS(printer => p_printer_name, copies => 1);
                     fnd_file.put_line(fnd_file.log, 'Concurrent Copies set to 1 ('||p_printer_name||
                        ') on submission of DOTINVPSREM'); -- S.Ryan 26-Feb-2016
                  ELSE
                     /* S.Ryan 26-Feb-2016
                     -- Setting copies to zero to prevent spooling of PDF to printer
                     -- directly from EBS.  Printing is instead performed by DOTDOXPRT
                     -- when p_print_command_line = 'Y'
                     -- S.Ryan 05-May-2016: Added if/else around b_print
                     */
                     b_print := FND_REQUEST.SET_PRINT_OPTIONS(copies => 0);
                     if b_print then
                        fnd_file.put_line(fnd_file.log, 'Concurrent Copies set to 0 on submission of second submission of DOTINVPSREM');
                     else
                        fnd_file.put_line(fnd_file.log, 'Concurrent Copies NOT able to be set to 0 on second submission of DOTINVPSREM ... you will get gobbledegook printed!');
                     end if;
                  END IF;
               END IF;
            END IF;

            b_layout := FND_REQUEST.ADD_LAYOUT(template_appl_name => 'ARC',
                                               template_code => r_inv.template_code,
                                               template_language => 'en',
                                               template_territory => 'US',
                                               output_format => gv_default_output);

            ln_sub_req_id := FND_REQUEST.SUBMIT_REQUEST(application => 'ARC',
                                                        program     => 'DOTINVPSREM',
                                                        description => lv_desc,
                                                        start_time  => NULL,
                                                        sub_request => FALSE,
                                                        argument1   => p_order_by,
                                                        argument2   => NULL,
                                                        argument3   => NULL,
                                                        argument4   => r_inv.trx_number,
                                                        argument5   => r_inv.trx_number,
                                                        argument6   => NULL,
                                                        argument7   => NULL,
                                                        argument8   => NULL,
                                                        argument9   => NULL,
                                                        argument10  => NULL,
                                                        argument11  => p_open_only,
                                                        argument12  => NULL,
                                                        argument13  => 'Y');

            INSERT INTO dot_ar_print_invoices
            VALUES (
                     ln_this_request,
                     lv_username,
                     r_inv.trx_number,
                     r_inv.customer_trx_id,
                     '',
                     lv_delivery,
                     ln_merge_order,
                     ln_sub_req_id,
                     ln_par_req_id,
                     lv_parent_file
                   );

            COMMIT;
         END IF;

         -- used for testing
         -- dbms_output.put_line(r_inv.customer_id || ' : ' || r_inv.customer_name || ' : ' || r_inv.trx_number);

      END IF;
   END LOOP;
   CLOSE c_inv;

   ------------------------------------------
   -- Wait for all subprocesses to finish  --
   ------------------------------------------
   LOOP
      ln_wait := NULL;

      FOR i IN (SELECT r.request_id sub_request_id,
                       r.phase_code,
                       r.status_code
                FROM   fnd_concurrent_requests r,
                       dot_ar_print_invoices p
                WHERE  r.request_id = p.sub_request_id
                AND    p.request_id = ln_this_request) LOOP

         IF i.phase_code = 'C' THEN
            IF i.status_code = 'C' THEN
               UPDATE dot_ar_print_invoices
               SET    status = 'S'
               WHERE  request_id = ln_this_request
               AND    sub_request_id = i.sub_request_id
               AND    status IS NULL;
            ELSE
               UPDATE dot_ar_print_invoices
               SET    status = 'E'
               WHERE  request_id = ln_this_request
               AND    sub_request_id = i.sub_request_id
               AND    status IS NULL;

               FND_FILE.PUT_LINE(FND_FILE.LOG, 'Subrequest ' ||
                                               i.sub_request_id ||
                                               ' failed. Please see logs from ' ||
                                               gv_default_user_name ||
                                               ' user.');
            END IF;

            IF sql%FOUND THEN
               COMMIT;
            END IF;
         ELSE
            ln_wait := i.sub_request_id;
            EXIT;
         END IF;
      END LOOP;

      IF ln_wait IS NULL THEN
         EXIT;
      ELSE
         srs_wait := FND_CONCURRENT.WAIT_FOR_REQUEST(ln_wait,
                                                     30,
                                                     0,
                                                     srs_phase,
                                                     srs_status,
                                                     srs_dev_phase,
                                                     srs_dev_status,
                                                     srs_message);
      END IF;
   END LOOP;

   /*
   -- Note: Workaround to address CENITEX printer configuration issue. PDF output
   --       sent directly to printer spools XML characters. Unable to utilise EBS
   --       standard function FND_REQUEST.SET_PRINT_OPTIONS
   */
   -----------------------------------------------------
   -- (1) Send output to printer (use command line).  --
   -----------------------------------------------------
   IF p_print_command_line = 'Y' AND
      p_printer_name IS NOT NULL THEN
      FOR r_prt IN c_prt_line (ln_this_request) LOOP

        /* S.Ryan 26-Feb-2016
        -- Setting copies to zero to prevent concurrent request from completing
        -- with WARNING. DOTDOXPRT does not produce amy output.
        */
         b_print := FND_REQUEST.SET_PRINT_OPTIONS(copies => 0);
         fnd_file.put_line(fnd_file.log, 'Concurrent Copies set to 0 on submission of DOTDOXPRT');

         ln_sub_req_id := FND_REQUEST.SUBMIT_REQUEST(application => 'ARC',
                                                     program     => 'DOTDOXPRT',
                                                     description => NULL,
                                                     start_time  => NULL,
                                                     sub_request => FALSE,
                                                     argument1   => p_printer_name,
                                                     argument2   => r_prt.file_name);
         COMMIT;
      END LOOP;
   END IF;

   ------------------------------------------------
   -- (2) Send output to email.                  --
   ------------------------------------------------
   IF p_email_function = 'Y' THEN
      --arellanod 11-Sep-2014
      --utl_smtp unable to accommodate multiple sends in
      --a single run.
      --send_to_email(ln_this_request);
      FOR r_email IN c_email (ln_this_request) LOOP
         ln_sub_req_id := FND_REQUEST.SUBMIT_REQUEST(application => 'ARC',
                                                     program     => 'DOTSEMAIL',
                                                     description => NULL,
                                                     start_time  => NULL,
                                                     sub_request => FALSE,
                                                     argument1   => r_email.sub_request_id);
         COMMIT;
      END LOOP;
   END IF;

   --------------------------------------------------
   -- (3) Construct merge routine. Enable user     --
   --     to see all printed and emailed invoices  --
   --     in one view.                             --
   --------------------------------------------------
   --IF NVL(ln_c_rec_count, 0) > 1 THEN
   IF lt_ref_cur.COUNT > 1 THEN
      build_merge_command(ln_this_request);

      ln_sub_req_id := FND_REQUEST.SUBMIT_REQUEST(application => 'ARC',
                                                  program     => 'DOTINVPSCOPY',
                                                  description => NULL,
                                                  start_time  => NULL,
                                                  sub_request => FALSE);
      COMMIT;

      srs_wait := FND_CONCURRENT.WAIT_FOR_REQUEST(ln_sub_req_id,
                                                  10,
                                                  0,
                                                  srs_phase,
                                                  srs_status,
                                                  srs_dev_phase,
                                                  srs_dev_status,
                                                  srs_message);
      IF NOT (srs_dev_phase = 'COMPLETE' AND
             (srs_dev_status = 'NORMAL' OR
              srs_dev_Status = 'WARNING')) THEN
         FND_FILE.PUT_LINE(FND_FILE.LOG, 'Unable to copy PDF merge command to $ARC_TOP/bin');
         p_retcode := 2;
         RETURN;
      END IF;

      ln_sub_req_id := FND_REQUEST.SUBMIT_REQUEST(application => 'ARC',
                                                  program     => 'DOTINVPSMERGEF',
                                                  description => NULL,
                                                  start_time  => NULL,
                                                  sub_request => FALSE);
      COMMIT;

      srs_wait := FND_CONCURRENT.WAIT_FOR_REQUEST(ln_sub_req_id,
                                                  60,
                                                  0,
                                                  srs_phase,
                                                  srs_status,
                                                  srs_dev_phase,
                                                  srs_dev_status,
                                                  srs_message);
      IF NOT (srs_dev_phase = 'COMPLETE' AND
             (srs_dev_status = 'NORMAL' OR
              srs_dev_Status = 'WARNING')) THEN
         FND_FILE.PUT_LINE(FND_FILE.LOG, 'Unable to merge the PDF files for viewing.');
         p_retcode := 1;
      END IF;
   END IF;

   FND_FILE.PUT_LINE(FND_FILE.LOG, '');
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Output');
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Request ID   Requested By          Transaction   Status   Delivery Option');
   FND_FILE.PUT_LINE(FND_FILE.LOG, '-----------  --------------------  ------------  -------  ---------------');

   FOR r_req_out IN c_req_out (ln_this_request) LOOP
      lv_log := RPAD(r_req_out.request_id, 11, ' ') || '  ' ||
                RPAD(SUBSTR(r_req_out.requested_by, 1, 20), 20, ' ') || '  ' ||
                RPAD(r_req_out.trx_number, 12, ' ') || '  ' ||
                RPAD(r_req_out.status, 7, ' ') || '  ' ||
                r_req_out.delivery_option;
      FND_FILE.PUT_LINE(FND_FILE.LOG, lv_log);
   END LOOP;
   FND_FILE.PUT_LINE(FND_FILE.LOG, '');


END dispatch_invoices;


/* send via email
IF ?email_address? IS NOT NULL THEN
   lv_subject := NULL;
   OPEN c_type (?trx_type?);
   FETCH c_type INTO lv_subject;
   CLOSE c_type;

   lv_subject := lv_subject || r_inv.trx_number;

   -- Delivery options is a new R12 feature
   -- use bursting instead.
   -- lb_deliver := FND_REQUEST.ADD_DELIVERY_OPTION(type => FND_DELIVERY.TYPE_EMAIL,
   --                                               p_argument1 => lv_subject,
   --                                               p_argument2 => 'DoNotReply@transport.vic.gov.au',
   --                                               p_argument3 => email_address,
   --                                               p_argument4 => NULL  -- cc
   --                                              );
END IF;

-- Add bursting control file to DOTINVPSREM data definition
-- Control file sample
<?xml version="1.0" encoding="utf-8"?>
<xapi:requestset xmlns:xapi="http://xmlns.oracle.com/oxp/xapi">
   <xapi:request select="/DOTINVPSREM/LIST_G_TRX_NUMBER/G_TRX_NUMBER">
      <xapi:delivery>
         <xapi:email server="d00713.doi.vic.gov.au" port="25" from="arellanod@redrock.net.au" reply-to="">
            <xapi:message id="${TRX_NUMBER}" to="arellanod@redrock.net.au" cc="" attachment="true" subject="Test">Test</xapi:message>
         </xapi:email>
      </xapi:delivery>
      <xapi:document output="test_${TRX_NUMBER}" output-type="pdf" delivery="${TRX_NUMBER}">
         <xapi:template type="rtf" location="xdo://ARC.DOTINVPSREM.en.US/?getSource=true" filter=""></xapi:template>
      </xapi:document>
   </xapi:request>
</xapi:requestset>
*/
-- Updates (02-Jul-2014):
-- Users have decided not to apply Patch 5631181.
-- Bursting in EBS XML Publisher Consolidated Reference (Doc ID 1574210.1)
-- The said patch will bring up XDOBURSTREP to a working condition but
-- because the patch has got quite a number of pre-requisites, their decision
-- was to code around it to address the emailing requirement quickly.

PROCEDURE send_to_email
(
   p_errbuff               OUT VARCHAR2,
   p_retcode               OUT NUMBER,
   p_sub_request_id        IN  NUMBER
 --p_request_id            IN  NUMBER
)
IS
   CURSOR c_out IS
      SELECT v.customer_trx_id,
             v.transmission_method,
             v.email_address,
             v.customer_number,
             v.trx_type,
             v.customer_type,
             v.trx_date,
             p.trx_number,
             p.request_id,
             p.sub_request_id,
             'DOTINVPSREM_' || p.sub_request_id || '_1.PDF' attach_file
      FROM   dot_ar_print_invoices p,
             dot_ar_print_invoices_v v
      WHERE  p.customer_trx_id = v.customer_trx_id
    --arellanod 11-Sep-2014
    --utl_smtp unable to accommodate multiple sends in
    --a single run.
    --AND    p.request_id = p_request_id /* execute program one at time */
      AND    p.sub_request_id = p_sub_request_id
      AND    p.status = 'S'
      AND    v.email_address IS NOT NULL
      AND    v.transmission_method = 'EMAIL'
      AND    p.delivery_option IS NULL;

   -- arellanod 11-Sep-2014
   CURSOR c_due_date (p_customer_trx_id NUMBER) IS
      SELECT p.due_date
      FROM   ar_payment_schedules p
      WHERE  p.customer_trx_id = p_customer_trx_id
      AND    p.terms_sequence_number = (SELECT MIN(px.terms_sequence_number)
                                        FROM   ar_payment_schedules px
                                        WHERE  px.customer_trx_id = p.customer_trx_id);

   r_out            c_out%ROWTYPE;
   lv_subject       VARCHAR2(1000);
   lv_stage         VARCHAR2(340);
   lv_trx_type      VARCHAR2(80);
   lv_attach_file   VARCHAR2(150);
   ld_stale         DATE := TRUNC(SYSDATE - 10);
   ld_due_date      DATE;  -- arellanod 11-Sep-2014
   ln_org_id        NUMBER;
   ln_lob_id        NUMBER;
   lv_org_name      hr_operating_units.name%TYPE;
   lt_email         t_email_addr;
   ln_str           NUMBER;
   ln_end           NUMBER;
   ln_ins           NUMBER;
   ln_ctr           NUMBER;
   lv_rcpt_hdr      VARCHAR2(300);

   -- BLOB Properties
   blob_id          BLOB;
   file_to_insert   BFILE;
   blob_length      INTEGER;

   -- EMAIL Properties
   c                utl_smtp.connection;
   l_host           VARCHAR2(150);
   l_raw            RAW(57);
   l_length         INTEGER := 0;
   l_buffer_size    INTEGER := 57;
   l_offset         INTEGER := 1;
   l_boundary       VARCHAR2(32) := sys_guid();
   l_body           VARCHAR2(32000);

   PROCEDURE send_header
   (
      in_label       IN  VARCHAR2,
      in_header      IN  VARCHAR2
   )  IS
   BEGIN
      utl_smtp.write_data(c, in_label || ': ' || in_header || utl_tcp.crlf);
   END;

BEGIN
   FND_PROFILE.GET('DOT_HOST_NAME', l_host);
   FND_PROFILE.GET('ORG_ID', ln_org_id);

   -- arellanod 12-Sep-2014
   -- Get default parameters
   SELECT content_type,
          common_out_directory,
          default_sender
   INTO   gv_content_type,
          gv_common_out,
          gv_default_sender
   FROM   dot_ar_print_parameters;

   SELECT DECODE(UPPER(name), 'DOI', 'DTPLI', UPPER(name))
   INTO   lv_org_name
   FROM   hr_operating_units
   WHERE  organization_id = ln_org_id;

   -- Run clean-up prior to performing
   -- emailing function.
   BEGIN
      DELETE FROM dot_fndc_lobs
      WHERE  creation_date < ld_stale;

      COMMIT;
   EXCEPTION
      WHEN others THEN
         FND_FILE.PUT_LINE(FND_FILE.LOG, 'Error: DELETE FROM DOT_FNDC_LOBS - ' || SQLERRM);
   END;

   OPEN c_out;
   LOOP
      FETCH c_out INTO r_out;
      EXIT WHEN c_out%NOTFOUND;

      -- arellanod 11-Sep-2014
      OPEN c_due_date (r_out.customer_trx_id);
      FETCH c_due_date INTO ld_due_date;
      CLOSE c_due_date;

      file_to_insert := BFILENAME(gv_common_out, r_out.attach_file);
      OPEN c_type (r_out.trx_type);
      FETCH c_type INTO lv_trx_type;
      CLOSE c_type;

      lv_subject := lv_org_name || ' ' || TRIM(lv_trx_type) || ' ' || r_out.trx_number;

      IF INSTR(r_out.email_address, gv_email_delim, 1, 1) > 0 THEN
         ln_str := 1;  -- start
         ln_end := 0;  -- end
         ln_ins := 1;  -- instance
         ln_ctr := 0;  -- email counter
         LOOP
            ln_end := INSTR(r_out.email_address, gv_email_delim, 1, ln_ins);
            IF ln_end = 0 THEN
               EXIT;
            END IF;
            ln_ctr := ln_ctr + 1;
            lt_email(ln_ctr) := TRIM(SUBSTR(r_out.email_address, ln_str, ln_end - ln_str));
            FND_FILE.PUT_LINE(FND_FILE.LOG, lt_email(ln_ctr));

            IF lv_rcpt_hdr IS NOT NULL THEN
               lv_rcpt_hdr := lv_rcpt_hdr || ', ';
            END IF;
            lv_rcpt_hdr := lv_rcpt_hdr || '<' || lt_email(ln_ctr) || '>';

            ln_str := ln_end + 1;
            ln_ins := ln_ins + 1;
         END LOOP;
      ELSE
         lt_email(1) := r_out.email_address;
         lv_rcpt_hdr := lv_rcpt_hdr || '<' || lt_email(1) || '>';
         FND_FILE.PUT_LINE(FND_FILE.LOG, lt_email(1));

      END IF;

      FND_FILE.PUT_LINE(FND_FILE.LOG, lv_rcpt_hdr);

      BEGIN
         -- Obtain the size of the blob file
         DBMS_LOB.fileopen (file_to_insert, DBMS_LOB.file_readonly);
         blob_length := DBMS_LOB.getlength(file_to_insert);
         DBMS_LOB.fileclose (file_to_insert);

         -- Insert a new record into the table containing the
         -- filename specified and the LOB LOCATOR.
         -- Return the LOB LOCATOR and assign it to blob_id.
         SELECT dot_fndc_lobs_s.NEXTVAL
         INTO   ln_lob_id
         FROM   dual;

         INSERT INTO dot_fndc_lobs
                (bdoc_id,
                 bdoc_filename,
                 bdoc,
                 content_type,
                 request_id,
                 creation_date,
                 created_by)
         VALUES (ln_lob_id,
                 r_out.attach_file,
                 empty_blob (),
                 gv_content_type,
                 r_out.sub_request_id,
                 SYSDATE,
                 gn_curr_user_id)
         RETURNING bdoc INTO blob_id;

         -- Load the file into the database as a BLOB
         DBMS_LOB.OPEN (file_to_insert, DBMS_LOB.lob_readonly);
         DBMS_LOB.OPEN (blob_id, DBMS_LOB.lob_readwrite);
         DBMS_LOB.loadfromfile (blob_id, file_to_insert, blob_length);

         -- Close handles to blob and file
         DBMS_LOB.CLOSE (blob_id);
         DBMS_LOB.CLOSE (file_to_insert);

         COMMIT;

         -- Confirm insert by querying the database
         -- for LOB length information and output results
         blob_length := 0;

         SELECT DBMS_LOB.getlength(bdoc)
         INTO   blob_length
         FROM   dot_fndc_lobs
         WHERE  bdoc_id = ln_lob_id
         AND    bdoc_filename = r_out.attach_file
         AND    request_id = r_out.sub_request_id;

         --blob_id
         --r_out.attach_file
         --Rename PDF attachment
         lv_attach_file := 'C' ||
                           r_out.customer_number ||
                           '_' ||
                           r_out.trx_type ||
                           '_' ||
                           r_out.trx_number ||
                           '.pdf';

         lv_stage := '1';
         -----------------------------------
         -- (1) Create SMTP Instance      --
         -----------------------------------
         -- use profile to store the fully qualified server name
         c := utl_smtp.open_connection(l_host);   -- smtp connection
         utl_smtp.helo(c, l_host);                -- host
         utl_smtp.mail(c, gv_default_sender);     -- sender
         -- arellanod 08-Oct-2014
         -- handle multiple recipients
         -- utl_smtp.rcpt(c, r_out.email_address);
         FOR x IN 1 .. lt_email.COUNT LOOP
            utl_smtp.rcpt(c, lt_email(x));        -- recipient(s)
         END LOOP;

         lv_stage := '2';
         -----------------------------------
         -- (2) Open data                 --
         -----------------------------------
         utl_smtp.open_data(c);

         lv_stage := '3';
         -----------------------------------
         -- (3) Set header                --
         -----------------------------------
         send_header('From'   , 'No-reply <' || gv_default_sender || '>');
         -- arellanod 08-Oct-2014
         -- handle multiple recipients
         -- send_header('To'     , '<' || r_out.email_address || '>');
         send_header('To'     , lv_rcpt_hdr);
         send_header('Subject', lv_subject);

         lv_stage := '4';
         --------------------------------------------
         -- (4) Set message to multipart/mixed     --
         --------------------------------------------
         utl_smtp.write_data(c, 'MIME-Version: 1.0' || utl_tcp.crlf);
         utl_smtp.write_data(c, 'Content-Type: multipart/mixed; ' || utl_tcp.crlf);
         utl_smtp.write_data(c, ' boundary= "' || l_boundary || '"' || utl_tcp.crlf);
         utl_smtp.write_data(c, utl_tcp.crlf);

         lv_stage := '5';
         -----------------------------------
         -- (5) Include message body      --
         -----------------------------------
         IF r_out.trx_type = 'INV' AND r_out.customer_type = 'External' THEN
            l_body := fnd_message.get_string('ARC', 'DOT_AR_DOTINVPS_EXTERNAL_INV');
         ELSIF r_out.trx_type = 'CM' AND r_out.customer_type = 'External' THEN
            l_body := fnd_message.get_string('ARC', 'DOT_AR_DOTINVPS_EXTERNAL_CM');
         ELSIF r_out.trx_type = 'INV' AND r_out.customer_type = 'Internal' THEN
            l_body := fnd_message.get_string('ARC', 'DOT_AR_DOTINVPS_INTERNAL_INV');
         ELSIF r_out.trx_type = 'CM' AND r_out.customer_type = 'Internal' THEN
            l_body := fnd_message.get_string('ARC', 'DOT_AR_DOTINVPS_INTERNAL_CM');
         END IF;

         l_body := REPLACE(l_body, '&TRX_TYPE', INITCAP(lv_trx_type));
         l_body := REPLACE(l_body, '&TRX_NUMBER', r_out.trx_number);
         l_body := REPLACE(l_body, '&TRX_DATE', TO_CHAR(r_out.trx_date, 'DD-MON-YY'));
         l_body := REPLACE(l_body, '&DUE_DATE', TO_CHAR(ld_due_date, 'DD-MON-YY')); -- arellanod 11-Sep-2014

         utl_smtp.write_data(c, '--' || l_boundary || utl_tcp.crlf);
         utl_smtp.write_data(c, 'Content-Type: text/html;' || utl_tcp.crlf);
         utl_smtp.write_data(c, ' charset=US-ASCII' || utl_tcp.crlf);
         utl_smtp.write_data(c, utl_tcp.crlf);
         utl_smtp.write_data(c, l_body || utl_tcp.crlf);
         utl_smtp.write_data(c, utl_tcp.crlf);

         lv_stage := '6';
         -----------------------------------
         -- (6) Include attachment        --
         -----------------------------------
         utl_smtp.write_data(c, '--' || l_boundary || utl_tcp.crlf);
         utl_smtp.write_data(c, 'Content-Type: ' || gv_content_type || utl_tcp.crlf);
         utl_smtp.write_data(c, 'Content-Disposition: attachment; ' || utl_tcp.crlf);
         utl_smtp.write_data(c, ' filename="' || lv_attach_file || '"' || utl_tcp.crlf);
         utl_smtp.write_data(c, 'Content-Transfer-Encoding: base64' || utl_tcp.crlf );
         utl_smtp.write_data(c, utl_tcp.crlf );

         /*********************************************************************/
         /*                                                                   */
         /*  Special routine: Segment the file into 57-byte pieces            */
         /*                   to accommodate large attachments                */
         /*                                                                   */
         /*********************************************************************/
         l_length := dbms_lob.getlength(blob_id);
         <<while_loop>>
         WHILE l_offset < l_length LOOP
            dbms_lob.read(blob_id, l_buffer_size, l_offset, l_raw);
            utl_smtp.write_raw_data(c, utl_encode.base64_encode(l_raw));
            utl_smtp.write_data(c, utl_tcp.crlf);
            l_offset := l_offset + l_buffer_size;
         END LOOP while_loop;
         utl_smtp.write_data(c, utl_tcp.crlf);

         lv_stage := '7';
         ----------------------------------
         -- (7) Close data               --
         ----------------------------------
         utl_smtp.write_data(c, '--' || l_boundary || '--' || utl_tcp.crlf );
         utl_smtp.write_data(c, utl_tcp.crlf || '.' || utl_tcp.crlf );
         utl_smtp.close_data(c);
         utl_smtp.quit(c);

         UPDATE dot_ar_print_invoices
         SET    delivery_option = 'E'
         WHERE  sub_request_id = p_sub_request_id; --r_out.sub_request_id;

         IF sql%FOUND THEN
            COMMIT;
         END IF;

      EXCEPTION
         WHEN utl_smtp.transient_error OR utl_smtp.permanent_error THEN
            BEGIN
               utl_smtp.quit(c);
            EXCEPTION
               WHEN utl_smtp.transient_error OR utl_smtp.permanent_error THEN
                  NULL;
                  /*
                  When the SMTP server is down or unavailable, we don't have
                  a connection to the server. The QUIT call will raise an
                  exception that we can ignore.
                  */
            END;
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'Send Email Stage: ' || lv_stage || ' ' || lv_subject);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'Failed to send mail due to the following error: ' || SQLERRM);

         WHEN others THEN
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'Send Email Stage: ' || lv_stage || ' ' || lv_subject);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'Failed to send mail due to the following error: ' || SQLERRM);
      END;
   END LOOP;

END send_to_email;


FUNCTION check_invoice_range
(
   p_start_inv   VARCHAR2,
   p_end_inv     VARCHAR2,
   p_check_inv   VARCHAR2
)
RETURN BOOLEAN
IS
   ln_start_inv   NUMBER := TO_NUMBER(p_start_inv);
   ln_end_inv     NUMBER := TO_NUMBER(p_end_inv);
   ln_check_inv   NUMBER := TO_NUMBER(p_check_inv);
   lv_dummy       VARCHAR2(1);
BEGIN
   SELECT 'X'
   INTO   lv_dummy
   FROM   dual
   WHERE  ln_check_inv BETWEEN ln_start_inv AND ln_end_inv;

   IF lv_dummy IS NULL THEN
      RETURN FALSE;
   END IF;

   RETURN TRUE;
EXCEPTION
   WHEN no_data_found THEN
      RETURN FALSE;
END check_invoice_range;


END dot_ar_print_invoices_pkg;
