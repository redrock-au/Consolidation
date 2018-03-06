CREATE OR REPLACE PACKAGE BODY xxar_invoices_interface_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.01.02/arc/1.0.0/install/sql/XXAR_INVOICES_INTERFACE_PKG.pkb 2365 2017-08-30 05:13:46Z svnuser $ */

/****************************************************************************
**
** CEMLI ID: AR.02.01
**
** Description: Interface program for importing Receivable transactions from
**              various feeder systems.
**
** Change History:
**
** Date        Who                  Comments
** 18/04/2017  ARELLAD (RED ROCK)   Initial build.
**
****************************************************************************/

TYPE load_rec_type IS RECORD
(
   autonum_flag        VARCHAR2(1),
   autonum_seq         VARCHAR2(15),
   trx_number          ra_customer_trx.trx_number%TYPE,
   line_number         ra_customer_trx_lines.line_number%TYPE,
   line_number_x       NUMBER
);

TYPE load_tab_type IS TABLE OF load_rec_type INDEX BY binary_integer;

TYPE last_number_rec_type IS RECORD
(
   record_id           VARCHAR2(60),
   last_number         NUMBER
);

TYPE prerun_error_tab_type IS TABLE OF VARCHAR2(640);

TYPE autonum_rec_type IS RECORD
(
   trx_number   VARCHAR2(30),
   line_count   NUMBER
);

TYPE autonum_tab_type IS TABLE OF autonum_rec_type INDEX BY binary_integer;

-- Interface Framework --
g_appl_short_name      VARCHAR2(10)   := 'AR';
g_debug                VARCHAR2(30)   := 'DEBUG: ';
g_error                VARCHAR2(30)   := 'ERROR: ';
g_staging_directory    VARCHAR2(30)   := 'WORKING';
g_int_mode             VARCHAR2(60)   := 'VALIDATE_TRANSFER';
g_reset_tfm_sql        VARCHAR2(1000) := 'TRUNCATE TABLE FMSMGR.XXAR_INVOICES_INTERFACE_TFM';
z_stage                CONSTANT VARCHAR2(30)  := 'STAGE';
z_transform            CONSTANT VARCHAR2(30)  := 'TRANSFORM';
z_load                 CONSTANT VARCHAR2(30)  := 'LOAD';
z_src_code             CONSTANT VARCHAR2(10)  := '3PS';
z_int_code             CONSTANT VARCHAR2(25)  := 'AR.02.01';
z_int_name             CONSTANT VARCHAR2(240) := 'DEDJTR AR Invoices Interface';
z_year                 CONSTANT NUMBER := 1990;

-- Defaulting Rules --
g_file                 VARCHAR2(150) := '*INVOICE*.txt';
g_ctl                  VARCHAR2(150) := '$ARC_TOP/bin/XXARFERAXTRX.ctl';
g_currency_code        VARCHAR2(15)  := 'AUD';
g_conv_type            VARCHAR2(25)  := 'User';
g_conv_rate            NUMBER        := 1;
g_autoinv_grouping     VARCHAR2(30)  := 'GEN';
z_line_type            CONSTANT VARCHAR2(25)  := 'LINE';
z_print_option         CONSTANT VARCHAR2(25)  := 'PRI';
z_account_class        CONSTANT VARCHAR2(30)  := 'REV';
z_rev_alloc_rule       CONSTANT VARCHAR2(50)  := 'Amount';
z_sales_credit         CONSTANT VARCHAR2(80)  := 'Quota Sales Credit';
z_sales_rep_id         CONSTANT NUMBER        := -3;
z_sales_percent        CONSTANT NUMBER        := 100;
z_crn_length           CONSTANT NUMBER        := 11;
z_file_temp_dir        CONSTANT VARCHAR2(150) := 'USER_TMP_DIR';
z_file_temp_path       CONSTANT VARCHAR2(150) := '/usr/tmp';
z_file_write           CONSTANT VARCHAR2(1)   := 'w';

-- System Parameters --
g_batch_source         ra_batch_sources.name%TYPE;
g_batch_source_id      ra_batch_sources.batch_source_id%TYPE;
g_batch_prefix         ra_batch_sources.attribute1%TYPE;
g_auto_numbering_flag  ra_batch_sources.auto_trx_numbering_flag%TYPE;
g_debug_flag           VARCHAR2(1);
g_sob_id               gl_sets_of_books.set_of_books_id%TYPE;
g_coa_id               gl_code_combinations.chart_of_accounts_id%TYPE;
g_user_id              fnd_user.user_id%TYPE;
g_org_id               NUMBER;
g_login_id             NUMBER;
g_appl_id              fnd_application.application_id%TYPE;
g_user_name            fnd_user.user_name%TYPE;
g_interface_req_id     NUMBER;
g_gl_date              DATE;
g_last_number          last_number_rec_type;

-- SRS --
srs_wait               BOOLEAN;
srs_phase              VARCHAR2(30);
srs_status             VARCHAR2(30);
srs_dev_phase          VARCHAR2(30);
srs_dev_status         VARCHAR2(30);
srs_message            VARCHAR2(240);

------------------------------------------------------
-- Procedure
--     PRINT_DEBUG
-- Purpose
--     Print debug log to FND_FILE.LOG
------------------------------------------------------

PROCEDURE print_debug
(
   p_debug_text   VARCHAR2
)
IS
BEGIN
   IF g_debug_flag = 'Y' THEN
      fnd_file.put_line(fnd_file.log, g_debug || p_debug_text);
   END IF;
END print_debug;

------------------------------------------------------
-- Function
--     GENERATE_CRN
-- Purpose
--     Builds the Customer Reference Number (CRN) 
--     printed on the the tax invoice.
-------------------------------------------------------

FUNCTION generate_crn
(
   p_source             IN  VARCHAR2,
   p_customer_trx_id    IN  NUMBER,
   p_status             OUT VARCHAR2,
   p_message            OUT VARCHAR2
)
RETURN VARCHAR2
IS
   l_check_digit        NUMBER := 0;
   l_curr_val           VARCHAR2(1);
   l_num                NUMBER;
   l_crn_number         VARCHAR2(12) := null;
   l_counter            NUMBER := 1;
   l_test_number        NUMBER;

BEGIN
   BEGIN
      l_test_number := TO_NUMBER(p_source);
   EXCEPTION
      WHEN others THEN
         p_status := 'E';
         p_message := 'Invalid CRN prefix';
         RETURN NULL;
   END;

   BEGIN
      l_test_number := TO_NUMBER(p_customer_trx_id);
   EXCEPTION
      WHEN others THEN
         p_status := 'E';
         p_message := 'Invalid customer_trx_id';
         RETURN NULL;
   END;

   IF p_source IS NOT NULL THEN
      IF LENGTH(p_source) <> 3 THEN
         p_status := 'E';
         p_message := 'Invalid CRN prefix';
         RETURN NULL;
      END IF;
      IF LENGTH(p_customer_trx_id) > 8 THEN
         p_status := 'E';
         p_message := 'Invalid customer_trx_id';
         RETURN NULL;
      END IF;
      l_crn_number := p_source || LPAD(p_customer_trx_id, 8, '0');
   ELSE
      IF LENGTH(p_customer_trx_id) > 11 THEN
         p_status := 'E';
         p_message := 'Invalid customer_trx_id';
         RETURN NULL;
      END IF;
      l_crn_number := LPAD(p_customer_trx_id, 11, '0');
   END IF;

   /********************************************************/
   /*  Expected length for a transaction id is always 11.  */
   /*  This function should return an error if length is   */
   /*  not 11. Hence its pointless to put an IF statement  */
   /*  to determine whether length of transaction id is    */
   /*  odd or even.                                        */
   /********************************************************/
   l_counter := 1;

   FOR x IN 1 .. z_crn_length LOOP
      l_curr_val := SUBSTR(l_crn_number, x, 1);
      l_counter := l_counter + 1;

      IF MOD(l_counter, 2) = 1 THEN
         l_num := TO_NUMBER(l_curr_val);
      ELSE
         l_num := TO_NUMBER(l_curr_val) * 2;
      END IF;

      IF l_num > 9 THEN
         l_num := (TO_NUMBER(SUBSTR(TO_CHAR(l_num), 1, 1)) + TO_NUMBER(SUBSTR(TO_CHAR(l_num), 2, 1)));
      END IF;

      l_check_digit := l_check_digit + l_num;
      l_num := 0;
   END LOOP;

   l_check_digit := MOD(l_check_digit, 10);

   IF l_check_digit <> 0 THEN
      l_check_digit := 10 - l_check_digit;
   END IF;

   p_status := 'S';

   RETURN l_crn_number || TO_CHAR(l_check_digit);

EXCEPTION
   WHEN others THEN
      p_status := 'E';
      p_message := SQLERRM;
      RETURN NULL;

END generate_crn;

---------------------------------------------------------
-- Procedure
--     GENERATE_CRN
-- Purpose
--     Wrap up procedure to generate Customer Reference
--     Number. Used only on the Receivables Transactions
--     form.
---------------------------------------------------------

PROCEDURE generate_crn
(
   p_customer_trx_id  NUMBER
)
IS
   l_source_v          VARCHAR2(5);
   l_source_n          NUMBER;
   l_status            VARCHAR2(1);
   l_message           VARCHAR2(1000);
   l_crn               VARCHAR2(25);
   l_customer_trx_id   NUMBER := p_customer_trx_id;
   PRAGMA              autonomous_transaction;
BEGIN
   SELECT b.attribute1
   INTO   l_source_v
   FROM   ra_customer_trx t,
          ra_batch_sources b,
          ra_cust_trx_types y
   WHERE  t.customer_trx_id = p_customer_trx_id
   AND    t.attribute7 IS NULL
   AND    t.batch_source_id = b.batch_source_id
   AND    t.cust_trx_type_id = y.cust_trx_type_id
   AND    y.type = 'INV';

   l_source_n := NVL(TO_NUMBER(l_source_v), 0);

   IF l_source_n > 0 THEN
      l_crn := generate_crn(p_source => l_source_v,
                            p_customer_trx_id => l_customer_trx_id,
                            p_status => l_status,
                            p_message => l_message);

      IF l_status = 'S' THEN
         UPDATE ra_customer_trx
         SET    attribute7 = l_crn
         WHERE  customer_trx_id = l_customer_trx_id;

         COMMIT;
      END IF;
   END IF;

EXCEPTION
   WHEN others THEN
      NULL;
END generate_crn;

---------------------------------------------------------
-- Procedure
--     GENERATE_CRN_FORM
-- Purpose
--     Wrap up procedure to generate Customer Reference
--     Number. Used only on the Receivables Transactions
--     form.
---------------------------------------------------------

FUNCTION generate_crn_form
(
   p_customer_trx_id  NUMBER
)
RETURN VARCHAR2
IS
   l_source_v          VARCHAR2(5);
   l_source_n          NUMBER;
   l_status            VARCHAR2(1);
   l_message           VARCHAR2(1000);
   l_crn               VARCHAR2(25);
   l_customer_trx_id   NUMBER := p_customer_trx_id;
   PRAGMA              autonomous_transaction;
BEGIN
   SELECT b.attribute1
   INTO   l_source_v
   FROM   ra_customer_trx t,
          ra_batch_sources b,
          ra_cust_trx_types y
   WHERE  t.customer_trx_id = p_customer_trx_id
   AND    t.batch_source_id = b.batch_source_id
   AND    t.cust_trx_type_id = y.cust_trx_type_id
   AND    y.type = 'INV';

   l_source_n := NVL(TO_NUMBER(l_source_v), 0);

   IF l_source_n > 0 THEN
      l_crn := generate_crn(p_source => l_source_v,
                            p_customer_trx_id => l_customer_trx_id,
                            p_status => l_status,
                            p_message => l_message);

      IF l_status = 'S' THEN
         RETURN l_crn;
      END IF;
   ELSE
      RETURN NULL;
   END IF;

EXCEPTION
   WHEN others THEN
      RETURN NULL;
END generate_crn_form;

-------------------------------------------------------
-- Procedure
--     ASSIGN_CRN
-- Purpose
--     Generates and assigns Customer Reference Number
--     (CRN) to transactions created from interface.
-------------------------------------------------------

PROCEDURE assign_crn
(
   p_request_id   NUMBER
)
IS
   CURSOR c_for_crn (p_request_id NUMBER) IS
      SELECT t.ROWID row_id,
             t.customer_trx_id,
             t.attribute7
      FROM   ra_customer_trx t
      WHERE  t.attribute7 IS NULL
      AND    t.request_id = (SELECT r.request_id
                             FROM   fnd_concurrent_requests r,
                                    fnd_concurrent_programs p
                             WHERE  p.concurrent_program_name = 'RAXTRX'
                             AND    p.concurrent_program_id = r.concurrent_program_id
                             AND    r.parent_request_id = p_request_id)
      FOR UPDATE OF t.attribute7;

   r_for_crn             c_for_crn%ROWTYPE;
   l_crn                 VARCHAR2(25);
   l_status              VARCHAR2(1);
   l_message             VARCHAR2(1000);

BEGIN
   print_debug('generate and assign CRN number');

   -- assign crn
   OPEN c_for_crn (p_request_id);
   LOOP
      FETCH c_for_crn INTO r_for_crn;
      EXIT WHEN c_for_crn%NOTFOUND;

      IF r_for_crn.attribute7 IS NULL THEN
         l_crn := generate_crn(p_source => g_batch_prefix,
                               p_customer_trx_id => r_for_crn.customer_trx_id,
                               p_status => l_status,
                               p_message => l_message);
         IF l_status = 'E' THEN
            fnd_file.put_line(fnd_file.log, g_error || l_message);
         ELSE
            UPDATE ra_customer_trx
            SET    attribute7 = l_crn
            WHERE  CURRENT OF c_for_crn;
         END IF;
      END IF;
   END LOOP;
   CLOSE c_for_crn;

   COMMIT;

   print_debug('generate and assign CRN number... completed');

EXCEPTION
   WHEN others THEN
      fnd_file.put_line(fnd_file.log, g_error || SQLERRM || ' during CRN assignment');

END assign_crn;

------------------------------------------------------
-- Procedure
--     WAIT_FOR_REQUEST
-- Purpose
--     Oracle standard API for concurrent processing
------------------------------------------------------

PROCEDURE wait_for_request
(
   p_request_id   NUMBER,
   p_wait_time    NUMBER
)
IS
BEGIN
   srs_wait := fnd_concurrent.wait_for_request(p_request_id,
                                               p_wait_time,
                                               0,
                                               srs_phase,
                                               srs_status,
                                               srs_dev_phase,
                                               srs_dev_status,
                                               srs_message);
END wait_for_request;

----------------------------------------------------------
-- Procedure
--     RAISE_ERROR
-- Purpose
--     Subroutine for calling run phase errors log report
--     (Interface Framework API).
----------------------------------------------------------

PROCEDURE raise_error
(
   p_error_rec      dot_int_run_phase_errors%ROWTYPE
)
IS
BEGIN
   dot_common_int_pkg.raise_error(p_run_id => p_error_rec.run_id,
                                  p_run_phase_id => p_error_rec.run_phase_id,
                                  p_record_id => p_error_rec.record_id,
                                  p_msg_code => p_error_rec.msg_code,
                                  p_error_text => p_error_rec.error_text,
                                  p_error_token_val1 => p_error_rec.error_token_val1,
                                  p_error_token_val2 => p_error_rec.error_token_val2,
                                  p_error_token_val3 => p_error_rec.error_token_val3,
                                  p_error_token_val4 => p_error_rec.error_token_val4,
                                  p_error_token_val5 => p_error_rec.error_token_val5,
                                  p_int_table_key_val1 => p_error_rec.int_table_key_val1,
                                  p_int_table_key_val2 => p_error_rec.int_table_key_val2,
                                  p_int_table_key_val3 => p_error_rec.int_table_key_val3);
END raise_error;

-----------------------------------------------
-- Function
--    GET_FILES
-- Purpose
--    Interface Framework subprocess used for
--    checking occurrence of inbound files.
-----------------------------------------------

FUNCTION get_files
(
   p_source             IN  VARCHAR2,
   p_file_string        IN  VARCHAR2,
   p_inbound_directory  OUT VARCHAR2,
   p_files              OUT xxint_common_pkg.t_files_type,
   p_message            OUT VARCHAR2
)
RETURN BOOLEAN
IS
   l_file_req_id         NUMBER;
   l_code                VARCHAR2(15);
   l_message             VARCHAR2(1000);
   r_request             xxint_common_pkg.control_record_type;
BEGIN
   p_inbound_directory := NULL;
   p_message := NULL;

   p_inbound_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                          p_source => p_source,
                                                          p_message => p_message);
   IF p_message IS NOT NULL THEN
      RETURN FALSE;
   END IF;

   l_file_req_id := fnd_request.submit_request(application => 'FNDC',
                                               program     => 'XXINTIFR',
                                               description => NULL,
                                               start_time  => NULL,
                                               sub_request => FALSE,
                                               argument1   => g_interface_req_id,
                                               argument2   => p_inbound_directory,
                                               argument3   => p_file_string,
                                               argument4   => g_appl_id);
   COMMIT;

   print_debug('fetching file ' || p_file_string || ' from ' || p_inbound_directory || ' (request_id=' || l_file_req_id || ')');

   wait_for_request(l_file_req_id, 5);

   IF NOT (srs_dev_phase = 'COMPLETE' AND
          (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
      xxint_common_pkg.get_error_message(g_error_message_02, l_code, l_message);
      l_message := REPLACE(l_message, '$INT_DIR', p_inbound_directory);
      r_request.error_message := l_message;
      r_request.status := 'ERROR';

   ELSE
      SELECT file_name BULK COLLECT
      INTO   p_files
      FROM   xxint_interface_ctl
      WHERE  interface_request_id = g_interface_req_id
      AND    sub_request_id = l_file_req_id
      AND    file_name IS NOT NULL;

      r_request.status := 'SUCCESS';
   END IF;

   -- Interface control record
   r_request.application_id := g_appl_id;
   r_request.interface_request_id := g_interface_req_id;
   r_request.sub_request_id := l_file_req_id;
   xxint_common_pkg.interface_request(r_request);

   p_message := l_message;

   IF r_request.status = 'ERROR' THEN
      RETURN FALSE;
   END IF;

   RETURN TRUE;

EXCEPTION
   WHEN others THEN
      p_message := SQLERRM;
      RETURN FALSE;
END get_files;

-----------------------------------------------
-- Function
--    GET_LAST_NUMBER
-- Purpose
--    Function to generate pseudo line number.
-----------------------------------------------

FUNCTION get_last_number
(
   p_record_id    IN VARCHAR2
)
RETURN NUMBER
IS
BEGIN
   IF p_record_id <> NVL(g_last_number.record_id, '9999999999.99') THEN
      g_last_number.record_id := p_record_id;
      g_last_number.last_number := 1;
   ELSE
      g_last_number.last_number := NVL(g_last_number.last_number, 0) + 1;
   END IF;

   RETURN g_last_number.last_number;
END get_last_number;

-----------------------------------------------
-- Procedure
--    PRINT_OUTPUT
-- Purpose
--    Procedure for creating output file.
-----------------------------------------------

PROCEDURE print_output
(
   p_run_id           NUMBER,
   p_run_phase_id     NUMBER,
   p_request_id       NUMBER,
   p_source           VARCHAR2,
   p_file             VARCHAR2,
   p_file_error       VARCHAR2,
   p_delim            VARCHAR2,
   p_write_to_out     BOOLEAN
)
IS
   CURSOR c_trx IS
      SELECT a.*,
             TO_CHAR(get_last_number(a.trx_number || '.' || a.line_number)) distribution_number,
             (a.extended_amount + a.gst_amount) line_amount
      FROM   (SELECT trx.request_id,
                     NULL record_id,
                     trx.trx_number,
                     typ.name transaction_type_name,
                     cus.customer_number,
                     cus.customer_name,
                     cad.site_number,
                     TO_CHAR(trx.trx_date, 'YYYY-MM-DD') trx_date,
                     TO_CHAR(g_gl_date, 'YYYY-MM-DD') gl_date,
                     ter.name term_name,
                     TO_CHAR(tli.line_number) line_number,
                     TO_CHAR(tli.extended_amount) extended_amount,
                     TO_CHAR(
                     (SELECT tax.extended_amount
                      FROM   ra_customer_trx_lines tax,
                             ra_cust_trx_line_gl_dist dis
                      WHERE  tax.link_to_cust_trx_line_id = tli.customer_trx_line_id
                      AND    tax.customer_trx_line_id = dis.customer_trx_line_id
                      AND    tax.line_type = 'TAX')) gst_amount,
                     TO_CHAR(tdi.amount) distribution_amount,
                     fnd_flex_ext.get_segs('SQLGL', 'GL#', g_coa_id, tdi.code_combination_id) charge_code,
                     vat.tax_code,
                     'Success' status
              FROM   ra_customer_trx trx,
                     ra_cust_trx_types typ,
                     ra_customers cus,
                     ra_site_uses stu,
                     ra_addresses cad,
                     ra_customer_trx_lines tli,
                     ra_terms ter,
                     ra_cust_trx_line_gl_dist tdi,
                     ar_vat_tax vat
              WHERE  trx.request_id = (SELECT r.request_id
                                       FROM   fnd_concurrent_requests r,
                                              fnd_concurrent_programs p
                                       WHERE  p.concurrent_program_name = 'RAXTRX'
                                       AND    p.concurrent_program_id = r.concurrent_program_id
                                       AND    r.parent_request_id = p_request_id)
              AND    trx.cust_trx_type_id = typ.cust_trx_type_id
              AND    trx.bill_to_customer_id = cus.customer_id
              AND    trx.bill_to_site_use_id = stu.site_use_id
              AND    stu.address_id = cad.address_id
              AND    trx.customer_trx_id = tli.customer_trx_id
              AND    tli.line_type = z_line_type
              AND    trx.term_id = ter.term_id
              AND    tli.customer_trx_id = tdi.customer_trx_id
              AND    tli.customer_trx_line_id = tdi.customer_trx_line_id
              AND    tli.vat_tax_id = vat.vat_tax_id
              AND    NVL(p_file_error, 'N') = 'N'
              ORDER  BY trx.trx_number,
                        tli.line_number) a
      UNION ALL
      SELECT NULL request_id,
             stg.record_id,
             stg.trx_number,
             stg.transaction_type_name,
             stg.customer_number,
             NULL customer_name,
             stg.customer_site_number site_number,
             stg.trx_date,
             TO_CHAR(g_gl_date, 'YYYY-MM-DD') gl_date,
             stg.term_name,
             stg.invoice_line_number line_number,
             stg.amount extended_amount,
             NULL gst_amount,
             stg.distribution_amount,
             stg.charge_code,
             stg.tax_code,
             INITCAP(NVL(tfm.status, 'ERROR')) status,
             stg.distribution_line_number,
             NULL line_amount
      FROM   xxar_invoices_interface_stg stg,
             xxar_invoices_interface_tfm tfm
      WHERE  stg.run_id = p_run_id
      AND    p_request_id IS NULL
      AND    stg.run_id = tfm.run_id(+)
      AND    stg.record_id = tfm.record_id(+)
      AND    NVL(p_file_error, 'N') = 'N'
      AND    EXISTS (SELECT 'x'
                     FROM   xxar_invoices_interface_tfm x
                     WHERE  x.run_id = tfm.run_id
                     AND    x.status IN ('ERROR', 'REJECTED'))
      UNION ALL
      SELECT NULL request_id,
             0    record_id,
             NULL trx_number,
             NULL transaction_type_name,
             NULL customer_number,
             NULL customer_name,
             NULL site_number,
             NULL trx_date,
             NULL gl_date,
             NULL term_name,
             NULL line_number,
             NULL extended_amount,
             NULL gst_amount,
             NULL distribution_amount,
             NULL charge_code,
             NULL tax_code,
             'Error' status,
             NULL distribution_number,
             NULL line_amount
      FROM   dual
      WHERE  NVL(p_file_error, 'N') = 'Y';

   l_file              VARCHAR2(150);
   l_outbound_path     VARCHAR2(150);
   l_text              VARCHAR2(32767);
   l_code              VARCHAR2(15);
   l_message           VARCHAR2(4000);
   r_trx               c_trx%ROWTYPE;
   f_handle            utl_file.file_type;
   f_copy              INTEGER;

   print_error         EXCEPTION;

BEGIN
   -- Comments:
   -- In case a file cannot be processed due to
   -- errors, use the parent request id for output
   -- file id.

   l_file := REPLACE(p_file, '.txt') || '_' || NVL(p_request_id, g_interface_req_id) || '.out';

   f_handle := utl_file.fopen(z_file_temp_dir, l_file, z_file_write);

   l_outbound_path := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                      p_source => p_source,
                                                      p_in_out => 'OUTBOUND',
                                                      p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE print_error;
   END IF;

   print_debug('print output to file');

   OPEN c_trx;
   LOOP
      FETCH c_trx INTO r_trx;
      EXIT WHEN c_trx%NOTFOUND;

      l_message := NULL;
      IF r_trx.status = 'Error' AND r_trx.record_id IS NOT NULL THEN
         xxint_common_pkg.get_error_message(p_run_id, p_run_phase_id, r_trx.record_id, '-', l_message);
         IF l_message IS NULL THEN
            FOR i IN (SELECT error_text
                      FROM   dot_int_run_phase_errors
                      WHERE  run_id = p_run_id
                      AND    run_phase_id = p_run_phase_id
                      AND    record_id = -1)
            LOOP
               IF l_message IS NOT NULL THEN
                  l_message := l_message || ' - ';
               END IF;
               l_message := l_message || i.error_text;
            END LOOP;
         END IF;
      END IF;

      l_text := NULL;
      l_text := l_text || r_trx.trx_number || p_delim;
      l_text := l_text || r_trx.transaction_type_name || p_delim;
      l_text := l_text || r_trx.customer_number || p_delim;
      l_text := l_text || r_trx.customer_name || p_delim;
      l_text := l_text || r_trx.site_number || p_delim;
      l_text := l_text || r_trx.trx_date || p_delim;
      l_text := l_text || r_trx.gl_date || p_delim;
      l_text := l_text || r_trx.term_name || p_delim;
      l_text := l_text || r_trx.line_number || p_delim;
      l_text := l_text || r_trx.extended_amount || p_delim;
      l_text := l_text || r_trx.gst_amount || p_delim;
      l_text := l_text || r_trx.line_amount || p_delim;
      l_text := l_text || r_trx.distribution_number || p_delim;
      l_text := l_text || r_trx.distribution_amount || p_delim;
      l_text := l_text || r_trx.charge_code || p_delim;
      l_text := l_text || r_trx.tax_code || p_delim;
      l_text := l_text || r_trx.status || p_delim;
      l_text := l_text || l_message;

      utl_file.put_line(f_handle, l_text);

      -- write output
      IF p_write_to_out THEN
         fnd_file.put_line(fnd_file.output, l_text);
      END IF;

      IF NVL(p_file_error, 'N') = 'Y' THEN
         EXIT;
      END IF;
   END LOOP;
   CLOSE c_trx;

   utl_file.fclose(f_handle);

   print_debug('print output to file... completed');
   print_debug('move output file');
   print_debug('from_path=' || z_file_temp_path || '/' || l_file);
   print_debug('to_path=' || l_outbound_path || '/' || l_file);

   f_copy := xxint_common_pkg.file_copy(p_from_path => z_file_temp_path || '/' || l_file,
                                        p_to_path => l_outbound_path || '/' || l_file);

   print_debug('f_copy=' || f_copy);
   print_debug('1=SUCCESS');
   print_debug('0=FAILURE');

   IF f_copy = 0 THEN
      xxint_common_pkg.get_error_message(g_error_message_34, l_code, l_message);
      RAISE print_error;
   END IF;

   print_debug('delete output file from temp directory');

   utl_file.fremove(z_file_temp_dir, l_file);

EXCEPTION
   WHEN print_error THEN
      IF utl_file.is_open(f_handle) THEN
         utl_file.fclose(f_handle);
      END IF;
      fnd_file.put_line(fnd_file.log, g_error || l_message);
   WHEN others THEN
      IF utl_file.is_open(f_handle) THEN
         utl_file.fclose(f_handle);
      END IF;
      fnd_file.put_line(fnd_file.log, g_error || SQLERRM);

END print_output;

------------------------------------------------------
-- Function
--    RECONCILE_TRANSACTIONS
-- Purpose
--    Compare loaded transactions against data in
--    transformation table to confirm record counts
--    between the two match.
------------------------------------------------------

FUNCTION reconcile_transactions
(
   p_run_id             IN  NUMBER,
   p_request_id         IN  NUMBER,
   p_batch_source       IN  VARCHAR2,
   p_message            OUT VARCHAR2
)
RETURN NUMBER
IS
   CURSOR c_load IS
      SELECT NVL(b.auto_trx_numbering_flag, 'N') autonum_flag,
             t.interface_header_attribute2 autonum_seq,
             t.trx_number,
             l.line_number,
             TO_NUMBER(l.interface_line_attribute3) interface_line_number
      FROM   ra_customer_trx t,
             ra_customer_trx_lines l,
             ra_batch_sources b
      WHERE  t.request_id = (SELECT r.request_id
                             FROM   fnd_concurrent_requests r,
                                    fnd_concurrent_programs p
                             WHERE  p.concurrent_program_name = 'RAXTRX'
                             AND    p.concurrent_program_id = r.concurrent_program_id
                             AND    r.parent_request_id = p_request_id)
      AND    t.customer_trx_id = l.customer_trx_id
      AND    t.batch_source_id = b.batch_source_id
      AND    l.line_type = z_line_type
      AND    b.name = p_batch_source;

   t_load             load_tab_type;
   l_load_count       NUMBER := 0;
   PRAGMA             autonomous_transaction;

BEGIN
   print_debug('reconcile loaded transactions against data in transformation table');

   OPEN c_load;
   LOOP
      t_load.DELETE;
      FETCH c_load
      BULK COLLECT INTO t_load LIMIT 100;
      EXIT WHEN t_load.COUNT = 0;

      FORALL i IN t_load.FIRST .. t_load.LAST
      UPDATE xxar_invoices_interface_tfm tfm
      SET    status = 'PROCESSED'
      WHERE  tfm.run_id = p_run_id
      AND    tfm.batch_source_name = p_batch_source
      AND    ((t_load(i).autonum_flag = 'Y' AND t_load(i).autonum_seq = tfm.interface_line_attribute2)
              OR
              (t_load(i).autonum_flag = 'N' AND t_load(i).trx_number = tfm.trx_number))
      AND    tfm.line_number = t_load(i).line_number_x;

   END LOOP;
   CLOSE c_load;

   UPDATE xxar_invoices_interface_tfm
   SET    status = 'REJECTED'
   WHERE  run_id = p_run_id
   AND    batch_source_name = p_batch_source
   AND    status = 'VALIDATED';

   COMMIT;

   SELECT COUNT(1)
   INTO   l_load_count
   FROM   xxar_invoices_interface_tfm tfm
   WHERE  tfm.run_id = p_run_id
   AND    tfm.batch_source_name = p_batch_source
   AND    tfm.status = 'PROCESSED';

   RETURN l_load_count;

EXCEPTION
   WHEN others THEN
      p_message := SQLERRM;
      RETURN 0;

END reconcile_transactions;

-------------------------------------------------------
-- Procedure
--     RUN_IMPORT
-- Purpose
--     Main program for importing Receivable invoices
--     from various feeder systems.
-------------------------------------------------------

PROCEDURE run_import
(
   p_errbuff            OUT  VARCHAR2,
   p_retcode            OUT  NUMBER,
   p_source             IN   VARCHAR2,
   p_file_name          IN   VARCHAR2,
   p_control_file       IN   VARCHAR2,
   p_gl_date            IN   VARCHAR2,
   p_debug_flag         IN   VARCHAR2,
   p_int_mode           IN   VARCHAR2
)
IS
   CURSOR c_int IS
      SELECT int_id,
             int_code,
             enabled_flag
      FROM   dot_int_interfaces
      WHERE  int_code = z_int_code;

   l_file                VARCHAR2(150);
   l_file_error          VARCHAR2(1);
   l_inbound_directory   VARCHAR2(150);
   l_ctl                 VARCHAR2(60);
   l_source              VARCHAR2(30) := p_source;
   l_code                VARCHAR2(15);
   l_message             VARCHAR2(1000);
   l_delim               VARCHAR2(1) := '|';
   l_request_id          NUMBER;
   l_period_name         gl_periods.period_name%TYPE;
   l_alloc_rule          ra_batch_sources.rev_acc_allocation_rule%TYPE;
   l_batch_source_type   ra_batch_sources.batch_source_type%TYPE;
   l_load_fail_count     NUMBER := 0;

   r_int                 c_int%ROWTYPE;
   t_prerun_errors       prerun_error_tab_type := prerun_error_tab_type();
   t_files               xxint_common_pkg.t_files_type;

   -- Interface Framework
   l_run_id              NUMBER;
   l_run_stage_id        NUMBER;
   l_run_transform_id    NUMBER;
   l_run_load_id         NUMBER;
   l_run_report_id       NUMBER;
   l_run_phase_error     NUMBER;

   stage_phase           BOOLEAN;
   transform_phase       BOOLEAN;
   load_phase            BOOLEAN;
   write_to_out          BOOLEAN;

   interface_error       EXCEPTION;
   to_date_error         EXCEPTION;
   PRAGMA                EXCEPTION_INIT(to_date_error, -1850);

BEGIN
   -- Global Variables
   xxint_common_pkg.g_object_type := 'INVOICES';
   g_debug_flag := NVL(p_debug_flag, 'N');
   g_interface_req_id := fnd_global.conc_request_id;
   g_user_name := fnd_global.user_name;
   g_org_id := fnd_global.org_id;
   g_user_id := fnd_global.user_id;
   g_login_id := fnd_global.login_id;
   g_appl_id := fnd_global.resp_appl_id;
   g_sob_id := fnd_profile.value('GL_SET_OF_BKS_ID');
   g_int_mode := NVL(p_int_mode, g_int_mode);
   g_gl_date := NVL(fnd_date.canonical_to_date(p_gl_date), SYSDATE);
   g_batch_source := p_source;
   write_to_out := TRUE;

   l_ctl := NVL(p_control_file, g_ctl);
   l_file := NVL(p_file_name, p_source || g_file);

   fnd_file.put_line(fnd_file.log, 'DEBUG_FLAG=' || g_debug_flag);

   print_debug('parameter: p_source=' || p_source);
   print_debug('parameter: p_file_name=' || l_file);
   print_debug('parameter: p_control_file=' || l_ctl);
   print_debug('parameter: p_gl_date=' || g_gl_date);
   print_debug('parameter: p_int_mode=' || g_int_mode);
   print_debug('org_id=' || g_org_id);
   print_debug('user_id=' || g_user_id);
   print_debug('login_id=' || g_login_id);
   print_debug('resp_appl_id=' || g_appl_id);
   print_debug('set_of_bks_id=' || g_sob_id);
   print_debug('pre interface run validations...');

   -- Chart of Accounts
   BEGIN
      SELECT chart_of_accounts_id
      INTO   g_coa_id
      FROM   gl_sets_of_books
      WHERE  set_of_books_id = g_sob_id;
   EXCEPTION
      WHEN no_data_found THEN
         xxint_common_pkg.get_error_message(g_error_message_38, l_code, l_message);
         t_prerun_errors.EXTEND;
         t_prerun_errors(t_prerun_errors.COUNT) := l_message;
   END;

   -- Validate GL Period
   BEGIN
      SELECT a.period_name
      INTO   l_period_name
      FROM   gl_period_statuses a,
             fnd_application b
      WHERE  g_gl_date BETWEEN a.start_date AND a.end_date
      AND    a.closing_status = 'O'
      AND    a.set_of_books_id = g_sob_id
      AND    a.application_id = b.application_id
      AND    b.application_short_name = g_appl_short_name;
   EXCEPTION
      WHEN no_data_found THEN
         xxint_common_pkg.get_error_message(g_error_message_30, l_code, l_message);
         l_message := REPLACE(l_message, '$GL_DATE', TO_CHAR(g_gl_date, 'DD/MM/YYYY'));
         t_prerun_errors.EXTEND;
         t_prerun_errors(t_prerun_errors.COUNT) := l_message;
   END;

   -- Validate Batch Source
   BEGIN
      SELECT rev_acc_allocation_rule,
             batch_source_type,
             batch_source_id,
             auto_trx_numbering_flag,
             attribute1
      INTO   l_alloc_rule,
             l_batch_source_type,
             g_batch_source_id,
             g_auto_numbering_flag,
             g_batch_prefix
      FROM   ra_batch_sources b
      WHERE  b.name = p_source;

      IF NVL(l_alloc_rule, 'NULL') <> z_rev_alloc_rule THEN
         xxint_common_pkg.get_error_message(g_error_message_33, l_code, l_message);
         t_prerun_errors.EXTEND;
         t_prerun_errors(t_prerun_errors.COUNT) := l_message;
      END IF;

      IF NVL(l_batch_source_type, 'NULL') <> 'FOREIGN' THEN
         xxint_common_pkg.get_error_message(g_error_message_36, l_code, l_message);
         t_prerun_errors.EXTEND;
         t_prerun_errors(t_prerun_errors.COUNT) := l_message;
      END IF;

   EXCEPTION
      WHEN no_data_found THEN
         xxint_common_pkg.get_error_message(g_error_message_37, l_code, l_message);
         t_prerun_errors.EXTEND;
         t_prerun_errors(t_prerun_errors.COUNT) := l_message;
   END;

   -- Interface Registry
   OPEN c_int;
   FETCH c_int INTO r_int;
   IF c_int%NOTFOUND THEN
      INSERT INTO dot_int_interfaces
      VALUES (dot_int_interfaces_s.NEXTVAL,
              z_int_code,
              z_int_name,
              'IN',
              'AR',
              'Y',
              SYSDATE,
              g_user_id,
              g_user_id,
              SYSDATE,
              g_login_id,
              g_interface_req_id);
      COMMIT;
   ELSE
      IF NVL(r_int.enabled_flag, 'N') = 'N' THEN
         xxint_common_pkg.get_error_message(g_error_message_01, l_code, l_message);
         l_message := REPLACE(l_message, '$INT_CODE', z_int_code);
         t_prerun_errors.EXTEND;
         t_prerun_errors(t_prerun_errors.COUNT) := l_message;
      END IF;
   END IF;
   CLOSE c_int;

   IF t_prerun_errors.COUNT > 0 THEN
      RAISE interface_error;
   END IF;

   print_debug('pre interface run validations... passed');

   -- Get files
   IF NOT get_files(p_source => l_source,
                    p_file_string => l_file,
                    p_inbound_directory => l_inbound_directory,
                    p_files => t_files,
                    p_message => l_message)
   THEN
      RAISE interface_error;
   END IF;

   print_debug('file_count=' || t_files.COUNT);

   IF t_files.COUNT > 1 THEN
      write_to_out := FALSE;
   END IF;

   -- Interface Run Phases
   FOR i IN 1 .. t_files.COUNT LOOP
      l_file := REPLACE(t_files(i), l_inbound_directory || '/');
      l_file_error := NULL;

      initialize(l_file,
                 l_run_id,
                 l_run_stage_id,
                 l_run_transform_id,
                 l_run_load_id);

      print_debug('====================================');
      print_debug('interface framework initialize phase');
      print_debug('====================================');
      print_debug('run_id=' || l_run_id);
      print_debug('run_stage_id=' || l_run_stage_id);
      print_debug('run_transform_id=' || l_run_transform_id);
      print_debug('run_load_id=' || l_run_load_id);
      print_debug('====================================');

      l_request_id := NULL;

      stage_phase := stage(p_run_id => l_run_id,
                           p_run_phase_id => l_run_stage_id,
                           p_source => l_source,
                           p_file => l_file,
                           p_ctl => l_ctl,
                           p_file_error => l_file_error);

      transform_phase := transform(p_run_id => l_run_id,
                                   p_run_phase_id => l_run_transform_id,
                                   p_source => l_source,
                                   p_file => l_file,
                                   p_stage_phase => stage_phase);

      load_phase := load(p_run_id => l_run_id,
                         p_run_phase_id => l_run_load_id,
                         p_file => l_file,
                         p_transform_phase => transform_phase,
                         p_request_id => l_request_id);

      l_run_report_id := dot_common_int_pkg.launch_run_report
                            (p_run_id => l_run_id,
                             p_notify_user => g_user_name);

      print_debug('run interface report (request_id=' || l_run_report_id || ')');

      print_output(l_run_id,
                   l_run_transform_id,
                   l_request_id,
                   l_source,
                   l_file,
                   l_file_error,
                   l_delim,
                   write_to_out);

      IF (load_phase AND l_request_id IS NOT NULL) THEN
         assign_crn (l_request_id);
      END IF;

      SELECT COUNT(1)
      INTO   l_run_phase_error
      FROM   dot_int_run_phases
      WHERE  run_id = l_run_id
      AND    error_count > 0;

      IF l_run_phase_error > 0 THEN
         l_load_fail_count := l_load_fail_count + 1;
      END IF;
   END LOOP;

   -- Return Error or Warning
   IF l_load_fail_count > 0 THEN
      IF t_files.COUNT = l_load_fail_count THEN
         p_retcode := 2;
      ELSIF t_files.COUNT > l_load_fail_count THEN
         p_retcode := 1;
      END IF;
   END IF;

EXCEPTION
   WHEN interface_error THEN
      print_debug('pre interface run validations... failed');
      FOR i IN 1 .. t_prerun_errors.COUNT LOOP
         fnd_file.put_line(fnd_file.log, g_error || t_prerun_errors(i));
      END LOOP;
      p_retcode := 2;

END run_import;

------------------------------------------------------
-- Procedure
--     INITIALIZE
-- Purpose
--     Initializes the interface run phases
--     STAGE-TRANSFORM-LOAD
------------------------------------------------------

PROCEDURE initialize
(
   p_file               IN VARCHAR2,
   p_run_id             IN OUT NUMBER,
   p_run_stage_id       IN OUT NUMBER,
   p_run_transform_id   IN OUT NUMBER,
   p_run_load_id        IN OUT NUMBER
)
IS
BEGIN
   -- Interface Run
   p_run_id := dot_common_int_pkg.initialise_run
                  (p_int_code       => z_int_code,
                   p_src_rec_count  => NULL,
                   p_src_hash_total => NULL,
                   p_src_batch_name => p_file);

   -- Staging
   p_run_stage_id := dot_common_int_pkg.start_run_phase
                        (p_run_id                  => p_run_id,
                         p_phase_code              => z_stage,
                         p_phase_mode              => NULL,
                         p_int_table_name          => p_file,
                         p_int_table_key_col1      => 'TRX_NUMBER',
                         p_int_table_key_col_desc1 => 'Transaction Number',
                         p_int_table_key_col2      => 'INVOICE_LINE_NUMBER',
                         p_int_table_key_col_desc2 => 'Line Num',
                         p_int_table_key_col3      => 'DISTRIBUTION_LINE_NUMBER',
                         p_int_table_key_col_desc3 => 'Distribution Line Num');

   -- Transform
   p_run_transform_id := dot_common_int_pkg.start_run_phase
                            (p_run_id                  => p_run_id,
                             p_phase_code              => z_transform,
                             p_phase_mode              => g_int_mode,
                             p_int_table_name          => 'XXAR_INVOICES_INTERFACE_STG',
                             p_int_table_key_col1      => 'TRX_NUMBER',
                             p_int_table_key_col_desc1 => 'Transaction Number',
                             p_int_table_key_col2      => 'INVOICE_LINE_NUMBER',
                             p_int_table_key_col_desc2 => 'Line Num',
                             p_int_table_key_col3      => 'DISTRIBUTION_LINE_NUMBER',
                             p_int_table_key_col_desc3 => 'Distribution Line Num');

   -- Load
   p_run_load_id := dot_common_int_pkg.start_run_phase
                       (p_run_id                  => p_run_id,
                        p_phase_code              => z_load,
                        p_phase_mode              => g_int_mode,
                        p_int_table_name          => 'XXAR_INVOICES_INTERFACE_TFM',
                        p_int_table_key_col1      => 'TRX_NUMBER',
                        p_int_table_key_col_desc1 => 'Transaction Number',
                        p_int_table_key_col2      => 'INVOICE_LINE_NUMBER',
                        p_int_table_key_col_desc2 => 'Line Num',
                        p_int_table_key_col3      => 'DISTRIBUTION_LINE_NUMBER',
                        p_int_table_key_col_desc3 => 'Distribution Line Num');

END initialize;

--------------------------------------------------------
-- Function
--     STAGE
-- Purpose
--     Interface Framework STAGE phase. This is the
--     subprocess that loads the data file from a
--     specified source into the staging area.
--------------------------------------------------------

FUNCTION stage
(
   p_run_id         IN  NUMBER,
   p_run_phase_id   IN  NUMBER,
   p_source         IN  VARCHAR2,
   p_file           IN  VARCHAR2,
   p_ctl            IN  VARCHAR2,
   p_file_error     OUT VARCHAR2
)
RETURN BOOLEAN
IS
   l_inbound_directory    VARCHAR2(150);
   l_outbound_directory   VARCHAR2(150);
   l_staging_directory    VARCHAR2(150);
   l_archive_directory    VARCHAR2(150);
   l_file                 VARCHAR2(150);
   l_bad                  VARCHAR2(150);
   l_log                  VARCHAR2(150);
   l_request_id           NUMBER;
   l_record_count         NUMBER := 0;
   l_error_count          NUMBER := 0;
   l_code                 VARCHAR2(15);
   l_message              VARCHAR2(1000);
   r_request              xxint_common_pkg.control_record_type;

   stage_error            EXCEPTION;
BEGIN
   p_file_error := 'N';

   print_debug('retrieve interface directory information');

   l_inbound_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                          p_source => p_source,
                                                          p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE stage_error;
   END IF;

   l_outbound_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                           p_source => p_source,
                                                           p_in_out => 'OUTBOUND',
                                                           p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE stage_error;
   END IF;

   l_staging_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                          p_source => p_source,
                                                          p_in_out => g_staging_directory,
                                                          p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE stage_error;
   END IF;

   l_archive_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                          p_source => p_source,
                                                          p_archive => 'Y',
                                                          p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE stage_error;
   END IF;

   l_file := p_file;
   l_log  := REPLACE(l_file, 'txt', 'log');
   l_bad  := REPLACE(l_file, 'txt', 'bad');

   print_debug('l_inbound_directory=' || l_inbound_directory);
   print_debug('l_outbound_directory=' || l_outbound_directory);
   print_debug('l_staging_directory=' || l_staging_directory);
   print_debug('l_archive_directory=' || l_archive_directory);
   print_debug('l_file=' || l_file);
   print_debug('l_log=' || l_log);
   print_debug('l_bad=' || l_bad);

   l_request_id := fnd_request.submit_request(application => 'FNDC',
                                              program     => 'XXINTSQLLDR',
                                              description => NULL,
                                              start_time  => NULL,
                                              sub_request => FALSE,
                                              argument1   => l_inbound_directory,
                                              argument2   => l_outbound_directory,
                                              argument3   => l_staging_directory,
                                              argument4   => l_archive_directory,
                                              argument5   => l_file,
                                              argument6   => l_log,
                                              argument7   => l_bad,
                                              argument8   => p_ctl);
   COMMIT;

   print_debug('load file ' || l_file || ' to staging (request_id=' || l_request_id || ')');

   wait_for_request(l_request_id, 5);
   r_request := NULL;

   IF NOT (srs_dev_phase = 'COMPLETE' AND
          (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
      xxint_common_pkg.get_error_message(g_error_message_03, l_code, l_message);
      l_message := REPLACE(l_message, '$INT_FILE', l_file);
      r_request.error_message := l_message;
      r_request.status := 'ERROR';
      p_file_error := 'Y';

   ELSE
      UPDATE xxar_invoices_interface_stg
      SET    run_id = p_run_id,
             run_phase_id = p_run_phase_id,
             status = 'PROCESSED',
             created_by = g_user_id,
             creation_date = SYSDATE
      WHERE  status = 'NEW';

      l_record_count := sql%ROWCOUNT;

      IF l_record_count > 0 THEN
         COMMIT;
      END IF;

      r_request.status := 'SUCCESS';

      /* Update Run Phase */
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => z_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      /* End Run Phase */
      dot_common_int_pkg.end_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_status => r_request.status,
          p_error_count => 0,
          p_success_count => l_record_count);
   END IF;

   print_debug('stage: record_count=' || l_record_count);
   print_debug('stage: success_count=' || l_record_count);
   print_debug('stage: error_count=' || l_error_count);

   -- Interface control record
   r_request.application_id := g_appl_id;
   r_request.interface_request_id := g_interface_req_id;
   r_request.file_name := l_file;
   r_request.sub_request_id := l_request_id;
   xxint_common_pkg.interface_request(r_request);

   IF r_request.status = 'ERROR' THEN
      RAISE stage_error;
   END IF;

   RETURN TRUE;

EXCEPTION
   WHEN stage_error THEN
      fnd_file.put_line(fnd_file.log, g_error || l_message);

      /* Update Run Phase */
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => z_src_code,
          p_rec_count    => 0,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      /* End Run Phase */
      dot_common_int_pkg.end_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_status => 'ERROR',
          p_error_count => 0,
          p_success_count => 0);

      RETURN FALSE;

   WHEN others THEN
      xxint_common_pkg.get_error_message(g_error_message_04, l_code, l_message);
      l_message := l_message || ' ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, g_error || l_message);

      /* Update Run Phase */
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => z_src_code,
          p_rec_count    => 0,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      /* End Run Phase */
      dot_common_int_pkg.end_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_status => 'ERROR',
          p_error_count => 0,
          p_success_count => 0);

      RETURN FALSE;
END stage;

------------------------------------------------------------
-- Function
--     TRANSFORM
-- Purpose
--     Interface Framework TRANSFORM phase. This is the
--     sub-process that performs data transformation,
--     derivation and validation. Checks system parameters
--     and global variables for defaulting and processing
--     rules involved to successfully load feeder systems
--     invoice transactions.
------------------------------------------------------------

FUNCTION transform
(
   p_run_id         IN  NUMBER,
   p_run_phase_id   IN  NUMBER,
   p_source         IN  VARCHAR2,
   p_file           IN  VARCHAR2,
   p_stage_phase    IN  BOOLEAN
)
RETURN BOOLEAN
IS
   CURSOR c_stg IS
      SELECT stg.record_id,
             stg.customer_number,
             stg.customer_site_number,
             stg.transaction_type_name,
             TRIM(stg.trx_number) trx_number,
             stg.trx_date,
             stg.term_name,
             stg.comments,
             stg.po_number,
             TRIM(stg.invoice_line_number) invoice_line_number,
             stg.description,
             stg.quantity,
             stg.unit_selling_price,
             stg.amount,
             stg.tax_code,
             TRIM(stg.distribution_line_number) distribution_line_number,
             stg.distribution_amount,
             stg.charge_code,
             stg.header_attribute_context,
             stg.customer_contact,
             stg.customer_email,
             stg.internal_contact_name,
             stg.line_attribute_context,
             stg.period_service_from_date,
             stg.period_service_to_date
      FROM   xxar_invoices_interface_stg stg
      WHERE  stg.run_id = p_run_id
      AND    stg.status = 'PROCESSED';

   CURSOR c_site (p_site_number VARCHAR2) IS
      SELECT rad.orig_system_reference orig_system_address_ref
      FROM   ra_addresses rad
      WHERE  rad.site_number = p_site_number;

   CURSOR c_cust (p_customer_number VARCHAR2, p_site_number VARCHAR2) IS
      SELECT rac.orig_system_reference orig_system_customer_ref,
             rad.orig_system_reference orig_system_address_ref
      FROM   ra_customers rac,
             ra_addresses rad,
             ra_site_uses rsu
      WHERE  rac.customer_id = rad.customer_id
      AND    rac.customer_number = p_customer_number
      AND    rad.site_number = p_site_number
      AND    rad.address_id = rsu.address_id
      AND    rad.bill_to_flag IN ('P', 'Y')
      AND    rsu.site_use_code = 'BILL_TO'
      AND    rsu.status = 'A'
      ORDER  BY DECODE(rsu.primary_flag, 'Y', 1, 2);

   CURSOR c_trx_type (p_trx_type VARCHAR2) IS
      SELECT name,
             cust_trx_type_id
      FROM   ra_cust_trx_types
      WHERE  name = p_trx_type;

   CURSOR c_term (p_term VARCHAR2) IS
      SELECT name,
             term_id
      FROM   ra_terms_vl
      WHERE  name = p_term;

   CURSOR c_tax (p_tax_code VARCHAR2) IS
      SELECT tax_code
      FROM   ar_vat_tax
      WHERE  tax_code = p_tax_code;

   CURSOR c_inv_dup IS
      SELECT a.trx_number,
             a.invoice_line_number,
             a.distribution_line_number,
             COUNT(1) line_count
      FROM   xxar_invoices_interface_stg a
      WHERE  a.run_id = p_run_id
      AND    TRIM(a.trx_number) IS NOT NULL
      GROUP  BY
             a.trx_number,
             a.invoice_line_number,
             a.distribution_line_number
      HAVING COUNT(1) > 1;

   CURSOR c_inv_site IS
      SELECT a.trx_number,
             COUNT(1) line_count
      FROM   xxar_invoices_interface_stg a
      WHERE  a.run_id = p_run_id
      AND    TRIM(a.trx_number) IS NOT NULL
      AND    EXISTS (SELECT b.trx_number,
                            COUNT(DISTINCT b.customer_site_number)
                     FROM   xxar_invoices_interface_stg b
                     WHERE  b.run_id = a.run_id
                     AND    b.trx_number = a.trx_number
                     GROUP  BY b.trx_number
                     HAVING COUNT(DISTINCT b.customer_site_number) > 1)
      GROUP  BY a.trx_number;

   CURSOR c_inv_trx_date IS
      SELECT a.trx_number,
             COUNT(1) line_count
      FROM   xxar_invoices_interface_stg a
      WHERE  a.run_id = p_run_id
      AND    TRIM(a.trx_number) IS NOT NULL
      AND    EXISTS (SELECT b.trx_number,
                            COUNT(DISTINCT b.trx_date)
                     FROM   xxar_invoices_interface_stg b
                     WHERE  b.run_id = a.run_id
                     AND    b.trx_number = a.trx_number
                     GROUP  BY b.trx_number
                     HAVING COUNT(DISTINCT b.trx_date) > 1)
      GROUP  BY a.trx_number;

   CURSOR c_inv_trx_type IS
      SELECT a.trx_number,
             COUNT(1) line_count
      FROM   xxar_invoices_interface_stg a
      WHERE  a.run_id = p_run_id
      AND    TRIM(a.trx_number) IS NOT NULL
      AND    EXISTS (SELECT b.trx_number,
                            COUNT(DISTINCT b.transaction_type_name)
                     FROM   xxar_invoices_interface_stg b
                     WHERE  b.run_id = a.run_id
                     AND    b.trx_number = a.trx_number
                     GROUP  BY b.trx_number
                     HAVING COUNT(DISTINCT b.transaction_type_name) > 1)
      GROUP  BY a.trx_number;

   CURSOR c_inv_neg IS
      SELECT a.trx_number,
             COUNT(1) line_count
      FROM   xxar_invoices_interface_stg a
      WHERE  a.run_id = p_run_id
      AND    TRIM(a.trx_number) IS NOT NULL
      AND    EXISTS (SELECT b.trx_number,
                            SUM(TO_NUMBER(REGEXP_REPLACE(b.distribution_amount,'[^[0-9,.]]*')))
                     FROM   xxar_invoices_interface_stg b
                     WHERE  b.run_id = a.run_id
                     AND    b.trx_number = a.trx_number
                     GROUP  BY b.trx_number
                     HAVING SIGN(SUM(TO_NUMBER(REGEXP_REPLACE(b.distribution_amount,'[^[0-9,.]]*')))) = -1)
      GROUP  BY a.trx_number;

   CURSOR c_inv_amount IS
      SELECT a.trx_number,
             a.invoice_line_number,
             COUNT(DISTINCT a.amount) amount
      FROM   xxar_invoices_interface_stg a
      WHERE  a.run_id = p_run_id
      AND    TRIM(a.trx_number) IS NOT NULL
      GROUP  BY
             a.trx_number,
             a.invoice_line_number
      HAVING COUNT(DISTINCT a.amount) > 1;

   CURSOR c_inv_dists IS
      SELECT a.trx_number,
             a.invoice_line_number,
             TO_NUMBER(REGEXP_REPLACE(a.amount,'[^[0-9,.]]*')) amount,
             SUM(TO_NUMBER(REGEXP_REPLACE(a.distribution_amount,'[^[0-9,.]]*'))) distribution_total,
             COUNT(1) distribution_count
      FROM   xxar_invoices_interface_stg a
      WHERE  a.run_id = p_run_id
      AND    TRIM(a.trx_number) IS NOT NULL
      GROUP  BY
             a.trx_number,
             a.invoice_line_number,
             TO_NUMBER(REGEXP_REPLACE(a.amount,'[^[0-9,.]]*'))
      HAVING COUNT(1) > 1;

   CURSOR c_acctseg (p_sob_id NUMBER) IS
      SELECT fseg.segment_num,
             fseg.segment_name,
             fseg.display_size segment_length
      FROM   fnd_id_flex_structures fstr,
             fnd_id_flex_segments_vl fseg,
             gl_sets_of_books gsob
      WHERE  gsob.set_of_books_id = p_sob_id
      AND    fstr.application_id = fseg.application_id
      AND    fstr.id_flex_code = fseg.id_flex_code
      AND    fstr.id_flex_num = fseg.id_flex_num
      AND    fstr.id_flex_code = 'GL#'
      AND    fstr.id_flex_num = gsob.chart_of_accounts_id
      ORDER  BY fseg.segment_num;

   l_record_count        NUMBER := 0;
   l_success_count       NUMBER := 0;
   l_error_count         NUMBER := 0;
   l_code                VARCHAR2(15);
   l_message             VARCHAR2(1000);
   l_tfm_status          VARCHAR2(30) := 'SUCCESS';
   l_tfm_error           NUMBER := 0;
   l_date_tl             DATE;
   l_error_count_inv     NUMBER;
   l_segs                NUMBER;
   l_percent             NUMBER;
   l_year                NUMBER;
 --l_batch_source_id     ra_batch_sources.batch_source_id%TYPE;
   l_trx_number          xxar_invoices_interface_stg.trx_number%TYPE;
   l_run_report_id       NUMBER;
   l_autonum_seq         NUMBER;

   r_stg                 c_stg%ROWTYPE;
   r_inv_dup             c_inv_dup%ROWTYPE;
   r_inv_amount          c_inv_amount%ROWTYPE;
   r_inv_dists           c_inv_dists%ROWTYPE;
   r_tfm                 xxar_invoices_interface_tfm%ROWTYPE;
   r_error               dot_int_run_phase_errors%ROWTYPE;
   r_acctseg             c_acctseg%ROWTYPE;
   t_segments            fnd_flex_ext.SegmentArray;
   t_autonum             autonum_tab_type;

   transform_error       EXCEPTION;
   transform_status      BOOLEAN := TRUE;
   calculate_amount      BOOLEAN;

   PROCEDURE error_token_init
   IS
   BEGIN
      r_error.error_token_val1 := NULL;
      r_error.error_token_val2 := NULL;
      r_error.error_token_val3 := NULL;
      r_error.error_token_val4 := NULL;
      r_error.error_token_val5 := NULL;
   END error_token_init;

   PROCEDURE set_to_error (p_trx_number VARCHAR2, p_line_number NUMBER)
   IS
   BEGIN
      UPDATE xxar_invoices_interface_tfm
      SET    status = 'ERROR'
      WHERE  trx_number = p_trx_number
      AND    line_number = NVL(p_line_number, line_number)
      AND    NVL(status, 'NEW') <> 'ERROR'
      AND    run_id = p_run_id;
   END set_to_error;

   -- Defaulting Rules
BEGIN
   IF NOT p_stage_phase THEN
      l_tfm_status := 'ERROR';
      transform_status := FALSE;
      GOTO update_run_phase;
   END IF;

   print_debug('reset transformation table');

   EXECUTE IMMEDIATE g_reset_tfm_sql;

   print_debug('run transformation routines');
   print_debug('run line level validations');

   SELECT COUNT(1)
   INTO   l_record_count
   FROM   xxar_invoices_interface_stg
   WHERE  run_id = p_run_id;

   IF l_record_count = 0 THEN
      GOTO update_run_phase;
   END IF;

   /* Update Run Phase */
   dot_common_int_pkg.update_run_phase
      (p_run_phase_id => p_run_phase_id,
       p_src_code     => z_src_code,
       p_rec_count    => l_record_count,
       p_hash_total   => NULL,
       p_batch_name   => p_file);

   ---------------------------
   -- Line level validation --
   ---------------------------

   OPEN c_stg;
   LOOP
      FETCH c_stg INTO r_stg;
      EXIT WHEN c_stg%NOTFOUND;

      l_tfm_error := 0;
      r_error := NULL;
      calculate_amount := TRUE;

      r_error.run_id := p_run_id;
      r_error.run_phase_id := p_run_phase_id;
      r_error.record_id := r_stg.record_id;
      r_error.int_table_key_val1 := r_stg.trx_number;
      r_error.int_table_key_val2 := r_stg.invoice_line_number;
      r_error.int_table_key_val3 := r_stg.distribution_line_number;

      -- TFM Record
      r_tfm := NULL;
      r_tfm.record_id := r_stg.record_id;
      r_tfm.run_id := p_run_id;
      r_tfm.run_phase_id := p_run_phase_id;
      r_tfm.batch_source_name := p_source;
      r_tfm.comments := SUBSTR(r_stg.comments, 1, 240);
      r_tfm.purchase_order := SUBSTR(r_stg.po_number, 1, 50);
      r_tfm.header_attribute1 := SUBSTR(r_stg.customer_contact, 1, 150);
      r_tfm.header_attribute8 := SUBSTR(r_stg.customer_email, 1, 150);
      r_tfm.attribute_category := SUBSTR(r_stg.line_attribute_context, 1, 30);
      r_tfm.attribute14 := SUBSTR(r_stg.period_service_from_date, 1, 150);
      r_tfm.attribute15 := SUBSTR(r_stg.period_service_to_date, 1, 150);
      r_tfm.gl_date := g_gl_date;
      r_tfm.line_type := z_line_type;
      r_tfm.primary_salesrep_id := z_sales_rep_id;
      r_tfm.printing_option := z_print_option;
      r_tfm.set_of_books_id := g_sob_id;
      r_tfm.org_id := g_org_id;
      r_tfm.created_by := g_user_id;
      r_tfm.creation_date := SYSDATE;
      r_tfm.last_updated_by := g_user_id;
      r_tfm.last_update_date := SYSDATE;
      r_tfm.currency_code := g_currency_code;
      r_tfm.conversion_type := g_conv_type;
      r_tfm.conversion_rate := g_conv_rate;
      r_tfm.conversion_date := g_gl_date;

      -- Grouping Rules
      r_tfm.interface_line_context := g_autoinv_grouping;
      r_tfm.interface_line_attribute1 := g_batch_source;
      r_tfm.interface_line_attribute2 := r_stg.trx_number;
      r_tfm.interface_line_attribute3 := r_stg.invoice_line_number;

      -- Customer Number and Site Number
      error_token_init;
      r_error.error_token_val1 := r_stg.customer_site_number;
      IF r_stg.customer_site_number IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'CUSTOMER SITE NUMBER');
         raise_error(r_error);
      ELSE
         OPEN c_site (r_stg.customer_site_number);
         FETCH c_site INTO r_tfm.orig_system_bill_address_ref;
         IF c_site%NOTFOUND THEN
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_09, r_error.msg_code, r_error.error_text);
            r_error.error_text := REPLACE(r_error.error_text, '$CUSTOMER_SITE_NUMBER', r_stg.customer_site_number);
            raise_error(r_error);
         ELSE
            r_error.error_token_val2 := r_stg.customer_number;
            IF r_stg.customer_number IS NULL THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'CUSTOMER NUMBER');
               raise_error(r_error);
            ELSE
               OPEN c_cust (r_stg.customer_number, r_stg.customer_site_number);
               FETCH c_cust INTO r_tfm.orig_system_bill_customer_ref, r_tfm.orig_system_bill_address_ref;
               IF c_cust%NOTFOUND THEN
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_10, r_error.msg_code, r_error.error_text);
                  r_error.error_text := REPLACE(r_error.error_text, '$CUSTOMER_SITE_NUMBER', r_stg.customer_site_number);
                  r_error.error_text := REPLACE(r_error.error_text, '$CUSTOMER_NUMBER', r_stg.customer_number);
                  raise_error(r_error);
               END IF;
               CLOSE c_cust;
            END IF;
         END IF;
         CLOSE c_site;
      END IF;

      -- Transaction Type
      error_token_init;
      r_error.error_token_val1 := r_stg.transaction_type_name;
      IF r_stg.transaction_type_name IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'TRANSACTION TYPE NAME');
         raise_error(r_error);
      ELSE
         OPEN c_trx_type (r_stg.transaction_type_name);
         FETCH c_trx_type INTO r_tfm.cust_trx_type_name, r_tfm.cust_trx_type_id;
         IF c_trx_type%NOTFOUND THEN
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_11, r_error.msg_code, r_error.error_text);
            r_error.error_text := REPLACE(r_error.error_text, '$TRANSACTION_TYPE_NAME', r_stg.transaction_type_name);
            raise_error(r_error);
         END IF;
         CLOSE c_trx_type;
      END IF;

      -- Transaction Number
      error_token_init;
      r_error.error_token_val1 := r_stg.trx_number;
      IF r_stg.trx_number IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'TRX NUMBER');
         raise_error(r_error);
      ELSE
         IF LENGTH(TRIM(r_stg.trx_number)) > 20 THEN
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_08, r_error.msg_code, r_error.error_text);
            r_error.error_text := REPLACE(r_error.error_text, '$TRX_NUMBER', r_stg.trx_number);
            raise_error(r_error);
         ELSE
            r_tfm.trx_number := r_stg.trx_number;
         END IF;
      END IF;

      -- Trx Date
      error_token_init;
      r_error.error_token_val1 := r_stg.trx_date;
      IF r_stg.trx_date IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'TRX DATE');
         raise_error(r_error);
      ELSE
         BEGIN
            r_tfm.trx_date := TO_DATE(r_stg.trx_date, 'YYYY-MM-DD');
            l_year := TO_NUMBER(TO_CHAR(TO_DATE(r_stg.trx_date, 'YYYY-MM-DD'), 'YYYY'));
            IF l_year < z_year THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_07, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$TRX_DATE', r_stg.trx_date);
               raise_error(r_error);
            END IF;
         EXCEPTION
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_07, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$TRX_DATE', r_stg.trx_date);
               raise_error(r_error);
         END;
      END IF;

      -- Term Name
      error_token_init;
      r_error.error_token_val1 := r_stg.term_name;
      IF r_stg.term_name IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'TERM NAME');
         raise_error(r_error);
      ELSE
         OPEN c_term (r_stg.term_name);
         FETCH c_term INTO r_tfm.term_name, r_tfm.term_id;
         IF c_term%NOTFOUND THEN
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_12, r_error.msg_code, r_error.error_text);
            r_error.error_text := REPLACE(r_error.error_text, '$TERM_NAME', r_stg.term_name);
            raise_error(r_error);
         END IF;
         CLOSE c_term;
      END IF;

      -- Department Internal Contact Name
      error_token_init;
      r_error.error_token_val1 := r_stg.internal_contact_name;
      IF r_stg.internal_contact_name IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'DEPARTMENT INTERNAL CONTACT');
         raise_error(r_error);
      ELSE
         r_tfm.header_attribute2 := SUBSTR(r_stg.internal_contact_name, 1, 150);
      END IF;

      -- Invoice Line Number
      error_token_init;
      r_error.error_token_val1 := r_stg.invoice_line_number;
      IF r_stg.invoice_line_number IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'INVOICE LINE NUMBER');
         raise_error(r_error);
      ELSE
         BEGIN
            r_tfm.line_number := TO_NUMBER(r_stg.invoice_line_number);
         EXCEPTION
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_13, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$INVOICE_LINE_NUMBER', r_stg.invoice_line_number);
               raise_error(r_error);
         END;
      END IF;

      -- Description
      error_token_init;
      r_error.error_token_val1 := r_stg.description;
      IF r_stg.description IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'DESCRIPTION');
         raise_error(r_error);
      ELSE
         r_tfm.description := SUBSTR(r_stg.description, 1, 240);
      END IF;

      -- Quantity
      error_token_init;
      r_error.error_token_val1 := r_stg.quantity;
      IF r_stg.quantity IS NULL THEN
         calculate_amount := FALSE;
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'QUANTITY');
         raise_error(r_error);
      ELSE
         BEGIN
            r_tfm.quantity := TO_NUMBER(r_stg.quantity);
         EXCEPTION
            WHEN others THEN
               calculate_amount := FALSE;
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_15, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$QUANTITY', r_stg.quantity);
               raise_error(r_error);
         END;
      END IF;

      -- Unit Selling Price
      error_token_init;
      r_error.error_token_val1 := r_stg.unit_selling_price;
      IF r_stg.unit_selling_price IS NULL THEN
         calculate_amount := FALSE;
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'UNIT SELLING PRICE');
         raise_error(r_error);
      ELSE
         BEGIN
            r_tfm.unit_selling_price := TO_NUMBER(r_stg.unit_selling_price);
         EXCEPTION
            WHEN others THEN
               calculate_amount := FALSE;
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_16, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$UNIT_SELLING_PRICE', r_stg.unit_selling_price);
               raise_error(r_error);
         END;
      END IF;

      -- Line Amount Calculation
      error_token_init;
      r_error.error_token_val1 := r_stg.amount;
      IF r_stg.amount IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'AMOUNT');
         raise_error(r_error);
      ELSE
         BEGIN
            IF (TO_NUMBER(r_stg.amount) > 0) AND calculate_amount THEN
               r_tfm.amount := ROUND((TO_NUMBER(r_stg.quantity) * TO_NUMBER(r_stg.unit_selling_price)), 2);
               IF INSTR(r_stg.amount, '.') > 0 THEN
                  IF (LENGTH(r_stg.amount) - INSTR(r_stg.amount, '.')) > 2 THEN
                     l_tfm_error := l_tfm_error + 1;
                     xxint_common_pkg.get_error_message(g_error_message_18, r_error.msg_code, r_error.error_text);
                     r_error.error_text := REPLACE(r_error.error_text, '$AMOUNT', r_stg.amount);
                     r_error.error_text := r_error.error_text || ' Please check currency precision is 2.';
                     raise_error(r_error);
                  END IF;
               END IF;
               -- Compare calculated amount
               IF r_tfm.amount <> ROUND(TO_NUMBER(r_stg.amount), 2) THEN
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_17, r_error.msg_code, r_error.error_text);
                  r_error.error_text := REPLACE(r_error.error_text, '$AMOUNT', r_stg.amount);
                  raise_error(r_error);
               END IF;
            END IF;
         EXCEPTION
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_18, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$AMOUNT', r_stg.amount);
               raise_error(r_error);
         END;
      END IF;

      -- Tax code
      error_token_init;
      r_error.error_token_val1 := r_stg.tax_code;
      IF r_stg.tax_code IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'TAX CODE');
         raise_error(r_error);
      ELSE
         OPEN c_tax (r_stg.tax_code);
         FETCH c_tax INTO r_tfm.tax_code;
         IF c_tax%NOTFOUND THEN
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_19, r_error.msg_code, r_error.error_text);
            r_error.error_text := REPLACE(r_error.error_text, '$TAX_CODE', r_stg.tax_code);
            raise_error(r_error);
         END IF;
         CLOSE c_tax;
      END IF;

      -- Distribution Line Number
      error_token_init;
      r_error.error_token_val1 := r_stg.distribution_line_number;
      IF r_stg.distribution_line_number IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'DISTRIBUTION LINE NUMBER');
         raise_error(r_error);
      ELSE
         BEGIN
            r_tfm.distribution_number := TO_NUMBER(r_stg.distribution_line_number);
         EXCEPTION
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_20, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$DISTRIBUTION_LINE_NUMBER', r_stg.distribution_line_number);
               raise_error(r_error);
         END;
      END IF;

      -- Distribution Amount
      error_token_init;
      r_error.error_token_val1 := r_stg.distribution_amount;
      IF r_stg.distribution_amount IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'DISTRIBUTION AMOUNT');
         raise_error(r_error);
      ELSE
         BEGIN
            r_tfm.distribution_amount := TO_NUMBER(r_stg.distribution_amount);
         EXCEPTION
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_21, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$DISTRIBUTION_AMOUNT', r_stg.distribution_amount);
               raise_error(r_error);
         END;
      END IF;

      -- Account
      error_token_init;
      r_error.error_token_val1 := r_stg.charge_code;
      IF r_stg.charge_code IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'CHARGE CODE');
         raise_error(r_error);
      ELSE
         r_tfm.code_combination_id := fnd_flex_ext.get_ccid(application_short_name => 'SQLGL',
                                                            key_flex_code => 'GL#',
                                                            structure_number => g_coa_id,
                                                            validation_date => NULL,
                                                            concatenated_segments => r_stg.charge_code);
         IF r_tfm.code_combination_id = 0 THEN
            l_tfm_error := l_tfm_error + 1;
            r_error.msg_code := '-1';
            r_error.error_text := fnd_flex_ext.get_message;
            raise_error(r_error);
         ELSE
            l_segs := fnd_flex_ext.breakup_segments(concatenated_segs => r_stg.charge_code,
                                                    delimiter         => '-',
                                                    segments          => t_segments);
            IF l_segs = 7 THEN
               r_tfm.segment1 := t_segments(1);
               r_tfm.segment2 := t_segments(2);
               r_tfm.segment3 := t_segments(3);
               r_tfm.segment4 := t_segments(4);
               r_tfm.segment5 := t_segments(5);
               r_tfm.segment6 := t_segments(6);
               r_tfm.segment7 := t_segments(7);

               -- Bug: FSC-3568
               -- Revalidate account segments
               OPEN c_acctseg (g_sob_id);
               LOOP
                  FETCH c_acctseg INTO r_acctseg;
                  EXIT WHEN c_acctseg%NOTFOUND;

                  IF LENGTH(t_segments(r_acctseg.segment_num)) <> r_acctseg.segment_length THEN
                     l_tfm_error := l_tfm_error + 1;
                     xxint_common_pkg.get_error_message(g_error_message_39, r_error.msg_code, r_error.error_text);
                     r_error.error_text := REPLACE(r_error.error_text, '$SEGMENT', r_acctseg.segment_name || ':' || t_segments(r_acctseg.segment_num));
                     raise_error(r_error);
                  END IF;
               END LOOP;
               CLOSE c_acctseg;
            END IF;
         END IF;
      END IF;

      -- Period of Service: From Date
      error_token_init;
      r_error.error_token_val1 := r_stg.period_service_from_date;
      IF r_stg.period_service_from_date IS NOT NULL THEN
         BEGIN
            l_date_tl := TO_DATE(r_stg.period_service_from_date, 'DD/MM/YYYY');
            r_tfm.attribute14 := SUBSTR(r_stg.period_service_from_date, 1, 150);
         EXCEPTION
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_22, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$PERIOD_SERVICE_FROM_DATE', r_stg.period_service_from_date);
               raise_error(r_error);
         END;
      END IF;

      -- Period of Service: To Date
      error_token_init;
      r_error.error_token_val1 := r_stg.period_service_from_date;
      IF r_stg.period_service_from_date IS NOT NULL THEN
         BEGIN
            l_date_tl := TO_DATE(r_stg.period_service_to_date, 'DD/MM/YYYY');
            r_tfm.attribute15 := SUBSTR(r_stg.period_service_to_date, 1, 150);
         EXCEPTION
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_23, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$PERIOD_SERVICE_TO_DATE', r_stg.period_service_to_date);
               raise_error(r_error);
         END;
      END IF;

      IF l_tfm_error > 0 THEN
         r_tfm.status := 'ERROR';
      ELSE
         r_tfm.status := 'VALIDATED';
      END IF;

      IF NVL(g_auto_numbering_flag, 'N') = 'Y' THEN
         r_tfm.trx_number := NULL;
      END IF;

      INSERT INTO xxar_invoices_interface_tfm
      VALUES r_tfm;

   END LOOP;
   CLOSE c_stg;

   ------------------------------
   -- Invoice level validation --
   ------------------------------

   print_debug('run invoice level validations');

   r_error.run_id := p_run_id;
   r_error.run_phase_id := p_run_phase_id;
   r_error.record_id := -1;

   -- Transaction Number already exists
   FOR i IN (SELECT x.trx_number,
                    COUNT(1) line_count
             FROM   xxar_invoices_interface_stg x
             WHERE  x.run_id = p_run_id
             AND    TRIM(x.trx_number) IS NOT NULL
             GROUP  BY x.trx_number)
   LOOP
      SELECT COUNT(1)
      INTO   l_error_count_inv
      FROM   ra_customer_trx t
      WHERE  t.batch_source_id = g_batch_source_id
      AND    t.trx_number = i.trx_number;

      IF l_error_count_inv > 0 THEN
         r_error.int_table_key_val1 := i.trx_number;
         r_error.int_table_key_val2 := NULL;
         r_error.int_table_key_val3 := NULL;
         xxint_common_pkg.get_error_message(g_error_message_24, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$TRX_NUMBER', i.trx_number);
         raise_error(r_error);
         set_to_error(i.trx_number, NULL);
      END IF;
   END LOOP;

   -- Duplicate distribution line
   OPEN c_inv_dup;
   LOOP
      FETCH c_inv_dup INTO r_inv_dup;
      EXIT WHEN c_inv_dup%NOTFOUND;
      r_error.int_table_key_val1 := r_inv_dup.trx_number;
      r_error.int_table_key_val2 := r_inv_dup.invoice_line_number;
      r_error.int_table_key_val3 := r_inv_dup.distribution_line_number;
      xxint_common_pkg.get_error_message(g_error_message_25, r_error.msg_code, r_error.error_text);
      raise_error(r_error);
      set_to_error(r_inv_dup.trx_number, NULL);
   END LOOP;
   CLOSE c_inv_dup;

   -- Site Number not unique
   OPEN c_inv_site;
   LOOP
      FETCH c_inv_site INTO l_trx_number, l_error_count_inv;
      EXIT WHEN c_inv_site%NOTFOUND;
      r_error.int_table_key_val1 := l_trx_number;
      r_error.int_table_key_val2 := NULL;
      r_error.int_table_key_val3 := NULL;
      xxint_common_pkg.get_error_message(g_error_message_26, r_error.msg_code, r_error.error_text);
      raise_error(r_error);
      set_to_error(l_trx_number, NULL);
   END LOOP;
   CLOSE c_inv_site;

   -- Trx Date not unique
   OPEN c_inv_trx_date;
   LOOP
      FETCH c_inv_trx_date INTO l_trx_number, l_error_count_inv;
      EXIT WHEN c_inv_trx_date%NOTFOUND;
      r_error.int_table_key_val1 := l_trx_number;
      r_error.int_table_key_val2 := NULL;
      r_error.int_table_key_val3 := NULL;
      xxint_common_pkg.get_error_message(g_error_message_27, r_error.msg_code, r_error.error_text);
      raise_error(r_error);
      set_to_error(l_trx_number, NULL);
   END LOOP;
   CLOSE c_inv_trx_date;

   -- Transaction Type not unique
   OPEN c_inv_trx_type;
   LOOP
      FETCH c_inv_trx_type INTO l_trx_number, l_error_count_inv;
      EXIT WHEN c_inv_trx_type%NOTFOUND;
      r_error.int_table_key_val1 := l_trx_number;
      r_error.int_table_key_val2 := NULL;
      r_error.int_table_key_val3 := NULL;
      xxint_common_pkg.get_error_message(g_error_message_28, r_error.msg_code, r_error.error_text);
      raise_error(r_error);
      set_to_error(l_trx_number, NULL);
   END LOOP;
   CLOSE c_inv_trx_type;

   -- Negative transaction amount
   OPEN c_inv_neg;
   LOOP
      FETCH c_inv_neg INTO l_trx_number, l_error_count_inv;
      EXIT WHEN c_inv_neg%NOTFOUND;
      r_error.int_table_key_val1 := l_trx_number;
      r_error.int_table_key_val2 := NULL;
      r_error.int_table_key_val3 := NULL;
      xxint_common_pkg.get_error_message(g_error_message_29, r_error.msg_code, r_error.error_text);
      raise_error(r_error);
      set_to_error(l_trx_number, NULL);
   END LOOP;
   CLOSE c_inv_neg;

   -- Inconsistent invoice line amount
   OPEN c_inv_amount;
   LOOP
      FETCH c_inv_amount INTO r_inv_amount;
      EXIT WHEN c_inv_amount%NOTFOUND;
      r_error.int_table_key_val1 := r_inv_amount.trx_number;
      r_error.int_table_key_val2 := r_inv_amount.invoice_line_number;
      r_error.int_table_key_val3 := NULL;
      xxint_common_pkg.get_error_message(g_error_message_35, r_error.msg_code, r_error.error_text);
      raise_error(r_error);
      set_to_error(r_inv_amount.trx_number, r_inv_amount.invoice_line_number);
   END LOOP;
   CLOSE c_inv_amount;

   -- Invoice line amount against distribution total
   OPEN c_inv_dists;
   LOOP
      FETCH c_inv_dists INTO r_inv_dists;
      EXIT WHEN c_inv_dists%NOTFOUND;

      IF r_inv_dists.amount <> r_inv_dists.distribution_total THEN
         r_error.int_table_key_val1 := r_inv_dists.trx_number;
         r_error.int_table_key_val2 := r_inv_dists.invoice_line_number;
         r_error.int_table_key_val3 := NULL;
         xxint_common_pkg.get_error_message(g_error_message_31, r_error.msg_code, r_error.error_text);
         raise_error(r_error);
         set_to_error(r_inv_dists.trx_number, r_inv_dists.invoice_line_number);
      ELSE
         FOR i IN (SELECT x.distribution_number,
                          x.distribution_amount
                   FROM   xxar_invoices_interface_tfm x
                   WHERE  x.run_id = p_run_id
                   AND    x.trx_number = r_inv_dists.trx_number
                   AND    x.line_number = r_inv_dists.invoice_line_number)
         LOOP
            --Batch Source: Revenue Allocation Rule must be set to AMOUNT
            l_percent := ROUND(((i.distribution_amount/r_inv_dists.amount) * 100), 4);

            UPDATE xxar_invoices_interface_tfm tfm
            SET    tfm.percent = l_percent
            WHERE  tfm.run_id = p_run_id
            AND    tfm.trx_number IS NOT NULL
            AND    tfm.trx_number = r_inv_dists.trx_number
            AND    tfm.line_number = r_inv_dists.invoice_line_number
            AND    tfm.distribution_number = i.distribution_number;
         END LOOP;
      END IF;
   END LOOP;
   CLOSE c_inv_dists;

   SELECT SUM(DECODE(status, 'VALIDATED', 1, 0)),
          SUM(DECODE(status, 'ERROR', 1, 0))
   INTO   l_success_count,
          l_error_count
   FROM   xxar_invoices_interface_tfm
   WHERE  run_id = p_run_id;

   IF l_error_count > 0 THEN
      l_run_report_id := dot_common_int_pkg.launch_error_report
                            (p_run_id => p_run_id,
                             p_run_phase_id => p_run_phase_id);
      l_tfm_status := 'ERROR';
      transform_status := FALSE;
      print_debug('run error report (request_id=' || l_run_report_id || ')');
   ELSE
      /*************************************************/
      /* Transaction Source is Auto Numbering enabled  */
      /*************************************************/
      IF l_success_count > 0 AND 
         g_auto_numbering_flag = 'Y' THEN
         BEGIN
            SELECT interface_line_attribute2,
                   COUNT(1) trx_line_count
                   BULK COLLECT INTO
                   t_autonum
            FROM   xxar_invoices_interface_tfm
            WHERE  run_id = p_run_id
            AND    run_phase_id = p_run_phase_id
            GROUP  BY interface_line_attribute2;

            FOR i IN 1 .. t_autonum.COUNT LOOP
               SELECT xxar_invoices_int_autonum_s.NEXTVAL
               INTO   l_autonum_seq
               FROM   dual;

               UPDATE xxar_invoices_interface_tfm
               SET    interface_line_attribute2 = l_autonum_seq
               WHERE  interface_line_attribute2 = t_autonum(i).trx_number
               AND    run_id = p_run_id
               AND    run_phase_id = p_run_phase_id;

            END LOOP;
         EXCEPTION
            WHEN others THEN RAISE;
         END;
      END IF;
      /*************************************************/
   END IF;

   print_debug('transformation and validation completed');

   COMMIT;

   <<update_run_phase>>

   print_debug('transform: record_count=' || l_record_count);
   print_debug('transform: success_count=' || l_success_count);
   print_debug('transform: error_count=' || l_error_count);

   /* Update Run Phase */
   dot_common_int_pkg.update_run_phase
      (p_run_phase_id => p_run_phase_id,
       p_src_code     => z_src_code,
       p_rec_count    => l_record_count,
       p_hash_total   => NULL,
       p_batch_name   => p_file);

   /* End Run Phase */
   dot_common_int_pkg.end_run_phase
      (p_run_phase_id => p_run_phase_id,
       p_status => l_tfm_status,
       p_error_count => l_error_count,
       p_success_count => l_success_count);

   RETURN transform_status;

EXCEPTION
   WHEN others THEN
      xxint_common_pkg.get_error_message(g_error_message_05, l_code, l_message);
      l_message := l_message || ' ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, g_error || l_message);

      /* Update Run Phase */
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => z_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => p_file);

      /* End Run Phase */
      dot_common_int_pkg.end_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_status => 'ERROR',
          p_error_count => l_error_count,
          p_success_count => l_success_count);

      RETURN FALSE;

END transform;

----------------------------------------------------------
-- Function
--     LOAD
-- Purpose
--     Interface Framework LOAD phase. This is the
--     sub-process that performs the actual data load to
--     Receivables application tables. LOAD utilizes
--     standard Oracle Open Interface/API.
----------------------------------------------------------

FUNCTION load
(
   p_run_id            IN  NUMBER,
   p_run_phase_id      IN  NUMBER,
   p_file              IN  VARCHAR2,
   p_transform_phase   IN  BOOLEAN,
   p_request_id        OUT NUMBER
)
RETURN BOOLEAN
IS
   CURSOR c_int_lines IS
      SELECT tfm.batch_source_name,
             tfm.description,
             tfm.trx_number,
             tfm.trx_date,
             tfm.gl_date,
             tfm.line_type,
             tfm.amount,
             tfm.unit_selling_price,
             tfm.cust_trx_type_name,
             tfm.cust_trx_type_id,
             tfm.quantity,
             tfm.uom_code,
             tfm.orig_system_bill_customer_ref,
             tfm.orig_system_bill_address_ref,
             tfm.interface_line_context,
             tfm.interface_line_attribute1,
             tfm.interface_line_attribute2,
             tfm.interface_line_attribute3,
             tfm.primary_salesrep_id,
             tfm.printing_option,
             tfm.term_name,
             tfm.term_id,
             tfm.conversion_type,
             tfm.conversion_date,
             tfm.conversion_rate,
             tfm.currency_code,
             tfm.tax_code,
             tfm.set_of_books_id,
             tfm.created_by,
             tfm.creation_date,
             tfm.last_updated_by,
             tfm.last_update_date,
             tfm.org_id,
             tfm.header_attribute_category,
             tfm.header_attribute1,
             tfm.header_attribute2,
             tfm.header_attribute3,
             tfm.header_attribute4,
             tfm.header_attribute5,
             tfm.header_attribute6,
             tfm.header_attribute7,
             tfm.header_attribute8,
             tfm.header_attribute9,
             tfm.header_attribute10,
             tfm.header_attribute11,
             tfm.header_attribute12,
             tfm.header_attribute13,
             tfm.header_attribute14,
             tfm.header_attribute15,
             tfm.comments,
             tfm.purchase_order,
             tfm.line_number,
             tfm.attribute_category,
             tfm.attribute1,
             tfm.attribute2,
             tfm.attribute3,
             tfm.attribute4,
             tfm.attribute5,
             tfm.attribute6,
             tfm.attribute7,
             tfm.attribute8,
             tfm.attribute9,
             tfm.attribute10,
             tfm.attribute11,
             tfm.attribute12,
             tfm.attribute13,
             tfm.attribute14,
             tfm.attribute15
      FROM   xxar_invoices_interface_tfm tfm
      WHERE  tfm.run_id = p_run_id
      AND    tfm.status = 'VALIDATED'
      AND    tfm.distribution_number = (SELECT MIN(tfx.distribution_number)
                                        FROM   xxar_invoices_interface_tfm tfx
                                        WHERE  tfx.run_id = tfm.run_id
                                        AND    tfx.interface_line_context = tfm.interface_line_context
                                        AND    tfx.interface_line_attribute1 = tfm.interface_line_attribute1
                                        AND    tfx.interface_line_attribute2 = tfm.interface_line_attribute2
                                        AND    tfx.interface_line_attribute3 = tfm.interface_line_attribute3);

   CURSOR c_int_sale IS
      SELECT tfm.interface_line_context,
             tfm.interface_line_attribute1,
             tfm.interface_line_attribute2,
             tfm.interface_line_attribute3,
             z_sales_rep_id salesrep_number,
             z_sales_credit sales_credit_type_name,
             z_sales_percent sales_credit_percent_split,
             tfm.created_by,
             tfm.creation_date,
             tfm.last_updated_by,
             tfm.last_update_date,
             tfm.org_id
      FROM   xxar_invoices_interface_tfm tfm
      WHERE  tfm.run_id = p_run_id
      AND    tfm.status = 'VALIDATED'
      AND    tfm.distribution_number = (SELECT MIN(tfx.distribution_number)
                                        FROM   xxar_invoices_interface_tfm tfx
                                        WHERE  tfx.run_id = tfm.run_id
                                        AND    tfx.interface_line_context = tfm.interface_line_context
                                        AND    tfx.interface_line_attribute1 = tfm.interface_line_attribute1
                                        AND    tfx.interface_line_attribute2 = tfm.interface_line_attribute2
                                        AND    tfx.interface_line_attribute3 = tfm.interface_line_attribute3);

   CURSOR c_int_dists IS
      SELECT interface_line_context,
             interface_line_attribute1,
             interface_line_attribute2,
             interface_line_attribute3,
             z_account_class account_class,
             distribution_amount,
             code_combination_id,
             percent,
             segment1,
             segment2,
             segment3,
             segment4,
             segment5,
             segment6,
             segment7,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date,
             org_id
      FROM   xxar_invoices_interface_tfm
      WHERE  run_id = p_run_id
      AND    status = 'VALIDATED';

   CURSOR c_int_rej IS
      SELECT record_id,
             trx_number,
             line_number,
             distribution_number
      FROM   xxar_invoices_interface_tfm
      WHERE  run_id = p_run_id
      AND    status = 'REJECTED'
      ORDER  BY 2, 3, 4;

   SUBTYPE int_lines_rec_type IS c_int_lines%ROWTYPE;
   TYPE    int_lines_tab_type IS TABLE OF int_lines_rec_type INDEX BY binary_integer;

   SUBTYPE int_sale_rec_type IS c_int_sale%ROWTYPE;
   TYPE    int_sale_tab_type IS TABLE OF int_sale_rec_type INDEX BY binary_integer;

   SUBTYPE int_dists_rec_type IS c_int_dists%ROWTYPE;
   TYPE    int_dists_tab_type IS TABLE OF int_dists_rec_type INDEX BY binary_integer;

   t_int_lines         int_lines_tab_type;
   t_int_sale          int_sale_tab_type;
   t_int_dists         int_dists_tab_type;
   l_record_count      NUMBER := 0;
   l_success_count     NUMBER := 0;
   l_error_count       NUMBER := 0;
   l_code              VARCHAR2(15);
   l_message           VARCHAR2(1000);
   l_load_status       VARCHAR2(30) := 'SUCCESS';
   l_req_id            NUMBER;
   l_run_report_id     NUMBER;

   r_request           xxint_common_pkg.control_record_type;
   r_error             dot_int_run_phase_errors%ROWTYPE;

   load_status         BOOLEAN := TRUE;

BEGIN
   IF NOT p_transform_phase THEN
      l_load_status := 'ERROR';
      load_status := FALSE;
      GOTO update_run_phase;
   END IF;

   print_debug('load process initiated');

   SELECT COUNT(1)
   INTO   l_record_count
   FROM   xxar_invoices_interface_tfm
   WHERE  run_id = p_run_id;

   /* Update Run Phase */
   dot_common_int_pkg.update_run_phase
      (p_run_phase_id => p_run_phase_id,
       p_src_code     => z_src_code,
       p_rec_count    => l_record_count,
       p_hash_total   => NULL,
       p_batch_name   => p_file);

   print_debug('record_count=' || l_record_count);

   IF l_record_count = 0 THEN
      GOTO update_run_phase;
   END IF;

   IF g_int_mode = 'VALIDATE_TRANSFER' THEN
      load_status := FALSE;

      print_debug('initialize interface tables');

      -- Initialize Interface Tables

      DELETE FROM ra_interface_lines_all
      WHERE  interface_status IS NULL
      AND    interface_line_context = g_autoinv_grouping
      AND    interface_line_attribute1 = g_batch_source;

      DELETE FROM ra_interface_salescredits_all
      WHERE  interface_status IS NULL
      AND    interface_line_context = g_autoinv_grouping
      AND    interface_line_attribute1 = g_batch_source;

      DELETE FROM ra_interface_distributions_all
      WHERE  interface_status IS NULL
      AND    interface_line_context = g_autoinv_grouping
      AND    interface_line_attribute1 = g_batch_source;

      print_debug('insert tfm data to interface tables');

      -- Interface Table: Header and Lines

      OPEN c_int_lines;
      LOOP
         t_int_lines.DELETE;
         FETCH c_int_lines
         BULK COLLECT INTO t_int_lines LIMIT 100;
         EXIT WHEN t_int_lines.COUNT = 0;

         FORALL i IN t_int_lines.FIRST .. t_int_lines.LAST
         INSERT INTO ra_interface_lines_all
                (batch_source_name,
                 description,
                 trx_number,
                 trx_date,
                 gl_date,
                 line_type,
                 amount,
                 unit_selling_price,
                 cust_trx_type_name,
                 cust_trx_type_id,
                 quantity,
                 uom_code,
                 orig_system_bill_customer_ref,
                 orig_system_bill_address_ref,
                 interface_line_context,
                 interface_line_attribute1,
                 interface_line_attribute2,
                 interface_line_attribute3,
                 primary_salesrep_id,
                 printing_option,
                 term_name,
                 term_id,
                 conversion_type,
                 conversion_date,
                 conversion_rate,
                 currency_code,
                 tax_code,
                 set_of_books_id,
                 created_by,
                 creation_date,
                 last_updated_by,
                 last_update_date,
                 org_id,
                 header_attribute_category,
                 header_attribute1,
                 header_attribute2,
                 header_attribute3,
                 header_attribute4,
                 header_attribute5,
                 header_attribute6,
                 header_attribute7,
                 header_attribute8,
                 header_attribute9,
                 header_attribute10,
                 header_attribute11,
                 header_attribute12,
                 header_attribute13,
                 header_attribute14,
                 header_attribute15,
                 comments,
                 purchase_order,
                 line_number,
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
                 attribute15)
         VALUES (t_int_lines(i).batch_source_name,
                 t_int_lines(i).description,
                 t_int_lines(i).trx_number,
                 t_int_lines(i).trx_date,
                 t_int_lines(i).gl_date,
                 t_int_lines(i).line_type,
                 t_int_lines(i).amount,
                 t_int_lines(i).unit_selling_price,
                 t_int_lines(i).cust_trx_type_name,
                 t_int_lines(i).cust_trx_type_id,
                 t_int_lines(i).quantity,
                 t_int_lines(i).uom_code,
                 t_int_lines(i).orig_system_bill_customer_ref,
                 t_int_lines(i).orig_system_bill_address_ref,
                 t_int_lines(i).interface_line_context,
                 t_int_lines(i).interface_line_attribute1,
                 t_int_lines(i).interface_line_attribute2,
                 t_int_lines(i).interface_line_attribute3,
                 t_int_lines(i).primary_salesrep_id,
                 t_int_lines(i).printing_option,
                 t_int_lines(i).term_name,
                 t_int_lines(i).term_id,
                 t_int_lines(i).conversion_type,
                 t_int_lines(i).conversion_date,
                 t_int_lines(i).conversion_rate,
                 t_int_lines(i).currency_code,
                 t_int_lines(i).tax_code,
                 t_int_lines(i).set_of_books_id,
                 t_int_lines(i).created_by,
                 t_int_lines(i).creation_date,
                 t_int_lines(i).last_updated_by,
                 t_int_lines(i).last_update_date,
                 t_int_lines(i).org_id,
                 t_int_lines(i).header_attribute_category,
                 t_int_lines(i).header_attribute1,
                 t_int_lines(i).header_attribute2,
                 t_int_lines(i).header_attribute3,
                 t_int_lines(i).header_attribute4,
                 t_int_lines(i).header_attribute5,
                 t_int_lines(i).header_attribute6,
                 t_int_lines(i).header_attribute7,
                 t_int_lines(i).header_attribute8,
                 t_int_lines(i).header_attribute9,
                 t_int_lines(i).header_attribute10,
                 t_int_lines(i).header_attribute11,
                 t_int_lines(i).header_attribute12,
                 t_int_lines(i).header_attribute13,
                 t_int_lines(i).header_attribute14,
                 t_int_lines(i).header_attribute15,
                 t_int_lines(i).comments,
                 t_int_lines(i).purchase_order,
                 t_int_lines(i).line_number,
                 t_int_lines(i).attribute_category,
                 t_int_lines(i).attribute1,
                 t_int_lines(i).attribute2,
                 t_int_lines(i).attribute3,
                 t_int_lines(i).attribute4,
                 t_int_lines(i).attribute5,
                 t_int_lines(i).attribute6,
                 t_int_lines(i).attribute7,
                 t_int_lines(i).attribute8,
                 t_int_lines(i).attribute9,
                 t_int_lines(i).attribute10,
                 t_int_lines(i).attribute11,
                 t_int_lines(i).attribute12,
                 t_int_lines(i).attribute13,
                 t_int_lines(i).attribute14,
                 t_int_lines(i).attribute15);
      END LOOP;
      CLOSE c_int_lines;

      -- Interface Table: Sales Credits

      OPEN c_int_sale;
      LOOP
         t_int_sale.DELETE;
         FETCH c_int_sale
         BULK COLLECT INTO t_int_sale LIMIT 100;
         EXIT WHEN t_int_sale.COUNT = 0;

         FORALL i IN t_int_sale.FIRST .. t_int_sale.LAST
         INSERT INTO ra_interface_salescredits_all
                (interface_line_context,
                 interface_line_attribute1,
                 interface_line_attribute2,
                 interface_line_attribute3,
                 salesrep_number,
                 sales_credit_type_name,
                 sales_credit_percent_split,
                 created_by,
                 creation_date,
                 last_updated_by,
                 last_update_date,
                 org_id)
         VALUES (t_int_sale(i).interface_line_context,
                 t_int_sale(i).interface_line_attribute1,
                 t_int_sale(i).interface_line_attribute2,
                 t_int_sale(i).interface_line_attribute3,
                 t_int_sale(i).salesrep_number,
                 t_int_sale(i).sales_credit_type_name,
                 t_int_sale(i).sales_credit_percent_split,
                 t_int_sale(i).created_by,
                 t_int_sale(i).creation_date,
                 t_int_sale(i).last_updated_by,
                 t_int_sale(i).last_update_date,
                 t_int_sale(i).org_id);
      END LOOP;
      CLOSE c_int_sale;

      -- Interface Table: Distributions

      OPEN c_int_dists;
      LOOP
         t_int_dists.DELETE;
         FETCH c_int_dists
         BULK COLLECT INTO t_int_dists LIMIT 100;
         EXIT WHEN t_int_dists.COUNT = 0;

         FORALL i IN t_int_dists.FIRST .. t_int_dists.LAST
         INSERT INTO ra_interface_distributions_all
                (interface_line_context,
                 interface_line_attribute1,
                 interface_line_attribute2,
                 interface_line_attribute3,
                 account_class,
                 amount,
                 code_combination_id,
                 percent,
                 segment1,
                 segment2,
                 segment3,
                 segment4,
                 segment5,
                 segment6,
                 segment7,
                 created_by,
                 creation_date,
                 last_updated_by,
                 last_update_date,
                 org_id)
         VALUES (t_int_dists(i).interface_line_context,
                 t_int_dists(i).interface_line_attribute1,
                 t_int_dists(i).interface_line_attribute2,
                 t_int_dists(i).interface_line_attribute3,
                 t_int_dists(i).account_class,
                 t_int_dists(i).distribution_amount,
                 t_int_dists(i).code_combination_id,
                 t_int_dists(i).percent,
                 t_int_dists(i).segment1,
                 t_int_dists(i).segment2,
                 t_int_dists(i).segment3,
                 t_int_dists(i).segment4,
                 t_int_dists(i).segment5,
                 t_int_dists(i).segment6,
                 t_int_dists(i).segment7,
                 t_int_dists(i).created_by,
                 t_int_dists(i).creation_date,
                 t_int_dists(i).last_updated_by,
                 t_int_dists(i).last_update_date,
                 t_int_dists(i).org_id);
      END LOOP;
      CLOSE c_int_dists;

      COMMIT;

      print_debug('insert tfm data to interface tables... completed');

      l_req_id := fnd_request.submit_request(application => 'AR',
                                             program     => 'RAXMTR',
                                             description => NULL,
                                             start_time  => NULL,
                                             sub_request => FALSE,
                                             argument1   => 1,
                                             argument2   => g_batch_source_id,
                                             argument3   => g_batch_source,
                                             argument4   => g_gl_date,
                                             argument5   => NULL,
                                             argument6   => NULL,
                                             argument7   => NULL,
                                             argument8   => NULL,
                                             argument9   => NULL,
                                             argument10  => NULL,
                                             argument11  => NULL,
                                             argument12  => NULL,
                                             argument13  => NULL,
                                             argument14  => NULL,
                                             argument15  => NULL,
                                             argument16  => NULL,
                                             argument17  => NULL,
                                             argument18  => NULL,
                                             argument19  => NULL,
                                             argument20  => NULL,
                                             argument21  => NULL,
                                             argument22  => NULL,
                                             argument23  => NULL,
                                             argument24  => NULL,
                                             argument25  => 'Y',
                                             argument27  => g_org_id);
      COMMIT;

      print_debug('submit AutoInvoice Program (request_id=' || l_req_id || ')');

      wait_for_request(l_req_id, 30);

      r_error.run_id := p_run_id;
      r_error.run_phase_id := p_run_phase_id;
      r_error.record_id := -1;
      r_error.int_table_key_val1 := -1;
      r_error.int_table_key_val2 := -1;
      r_error.int_table_key_val3 := -1;

      IF NOT (srs_dev_phase = 'COMPLETE' AND
             (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
         xxint_common_pkg.get_error_message(g_error_message_32, l_code, l_message);
         r_request.error_message := l_message;
         r_request.status := 'ERROR';
         r_error.error_text := l_message;
         raise_error(r_error);

      ELSE
         p_request_id := l_req_id;

         -- reconcile transactions
         l_success_count := reconcile_transactions(p_run_id, l_req_id, g_batch_source, l_message);
         IF l_message IS NOT NULL THEN
            r_request.error_message := l_message;
            r_request.status := 'ERROR';
            r_error.error_text := l_message;
            raise_error(r_error);
         ELSE
            IF l_success_count <> l_record_count THEN
               l_error_count := (l_record_count - l_success_count);
               xxint_common_pkg.get_error_message(g_error_message_99, l_code, l_message);
               r_request.error_message := l_message;
               r_request.status := 'ERROR';

               FOR rej IN c_int_rej LOOP
                  r_error.record_id := rej.record_id;
                  r_error.int_table_key_val1 := rej.trx_number;
                  r_error.int_table_key_val2 := rej.line_number;
                  r_error.int_table_key_val3 := rej.distribution_number;
                  r_error.msg_code := l_code;
                  r_error.error_text := l_message;
                  raise_error(r_error);
               END LOOP;

            ELSE
               r_request.status := 'SUCCESS';
               load_status := TRUE;
            END IF;

         END IF;
      END IF;

      -- Interface control record
      r_request.application_id := g_appl_id;
      r_request.interface_request_id := g_interface_req_id;
      r_request.file_name := p_file;
      r_request.sub_request_id := l_req_id;
      xxint_common_pkg.interface_request(r_request);

      IF (r_request.status = 'ERROR') THEN
         fnd_file.put_line(fnd_file.log, g_error || l_message);

         l_run_report_id := dot_common_int_pkg.launch_error_report
                               (p_run_id => p_run_id,
                                p_run_phase_id => p_run_phase_id);

         print_debug('run error report (request_id=' || l_run_report_id || ')');
         l_load_status := 'ERROR';
      END IF;

   END IF;

   <<update_run_phase>>

   print_debug('load: record_count=' || l_record_count);
   print_debug('load: success_count=' || l_success_count);
   print_debug('load: error_count=' || l_error_count);

   /* End Run Phase */
   dot_common_int_pkg.end_run_phase
      (p_run_phase_id => p_run_phase_id,
       p_status => l_load_status,
       p_error_count => l_error_count,
       p_success_count => l_success_count);

   RETURN load_status;

EXCEPTION
   WHEN others THEN
      xxint_common_pkg.get_error_message(g_error_message_06, l_code, l_message);
      l_message := l_message || ' ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, g_error || l_message);

      /* Update Run Phase */
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => z_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => p_file);

      /* End Run Phase */
      dot_common_int_pkg.end_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_status => 'ERROR',
          p_error_count => l_error_count,
          p_success_count => l_success_count);

      RETURN FALSE;

END load;

END xxar_invoices_interface_pkg;
/
