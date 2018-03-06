create or replace PACKAGE BODY xxar_open_invoices_conv_pkg AS
/*$Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/sql/XXAR_OPEN_INVOICES_CONV_PKG.pkb 2443 2017-09-06 00:29:43Z svnuser $*/
/****************************************************************************
**
** CEMLI ID: AR.00.02
**
** Description: This program is for conversion of Open AR Invoices
**              
**
** Change History:
**
** Date        Who                  Comments
** 20/05/2017  KWONDA (RED ROCK)   Initial build.
**
****************************************************************************/

TYPE load_rec_type IS RECORD
(
   TRX_NUMBER          ra_customer_trx.TRX_NUMBER%TYPE,
   line_number         ra_customer_trx_lines.line_number%TYPE
);

TYPE load_tab_type IS TABLE OF load_rec_type INDEX BY binary_integer;

TYPE last_number_rec_type IS RECORD
(
   record_id           VARCHAR2(60),
   last_number         NUMBER
);

TYPE prerun_error_tab_type IS TABLE OF VARCHAR2(640);

-- Interface Framework --
g_appl_short_name           VARCHAR2(10)   := 'AR';
g_debug                     VARCHAR2(30)   := 'DEBUG: ';
g_error                     VARCHAR2(30)   := 'ERROR: ';
g_staging_directory         VARCHAR2(30)   := 'WORKING';
g_src_code                  VARCHAR2(30)   := 'AR.00.02';
g_int_mode                  VARCHAR2(60)   := 'VALIDATE_TRANSFER';
g_stage                     VARCHAR2(30)   := 'STAGE';
g_transform                 VARCHAR2(30)   := 'TRANSFORM';
g_load                      VARCHAR2(30)   := 'LOAD';
g_reset_tfm_sql             VARCHAR2(1000) := 'TRUNCATE TABLE FMSMGR.xxar_open_invoices_conv_tfm';
g_int_code                  dot_int_interfaces.int_code%TYPE := 'AR.00.02';
g_int_name                  dot_int_interfaces.int_name%TYPE := 'DEDJTR AR Invoices Interface';

-- Defaulting Rules --
g_file                      VARCHAR2(150)  := '_OPEN_INVOIVE*.csv';
g_ctl                       VARCHAR2(150)  := '$ARC_TOP/bin/XXARINVCONV.ctl';
g_currency_code             VARCHAR2(15)   := 'AUD';
g_conv_type                 VARCHAR2(25)   := 'User';
g_conv_date                 DATE           := SYSDATE;
g_conv_rate                 NUMBER         := 1;
g_autoinv_grouping          VARCHAR2(30)   := 'GEN';
z_line_type                 CONSTANT VARCHAR2(25)   := 'LINE';
z_print_option              CONSTANT VARCHAR2(25)   := 'NOT';

--z_account_class        VARCHAR2(30);
/*z_rev_alloc_rule            CONSTANT VARCHAR2(50)   := 'Amount';
z_sales_credit              CONSTANT VARCHAR2(80)   := 'Quota Sales Credit';
z_sales_rep_id              CONSTANT NUMBER         := -3;
z_sales_percent             CONSTANT NUMBER         := 100;           																																						
z_crn_length                CONSTANT NUMBER         := 11;  */          																																						
z_file_temp_dir             CONSTANT VARCHAR2(150)  := 'USER_TMP_DIR';																																						
z_file_temp_path            CONSTANT VARCHAR2(150)  := '/usr/tmp';    																																						
z_file_write                CONSTANT VARCHAR2(1)    := 'w';           																																						

-- System Parameters --
g_batch_source         ra_batch_sources.name%TYPE;
g_batch_source_id      ra_batch_sources.batch_source_id%TYPE;
g_batch_prefix         ra_batch_sources.attribute1%TYPE;
g_debug_flag           VARCHAR2(1);
g_sob_id               gl_sets_of_books.set_of_books_id%TYPE;
g_org_id               NUMBER;
g_coa_id               gl_code_combinations.chart_of_accounts_id%TYPE;
g_user_id              fnd_user.user_id%TYPE;
g_login_id             NUMBER;
g_appl_id              fnd_application.application_id%TYPE;
g_user_name            fnd_user.user_name%TYPE;
g_interface_req_id     NUMBER;
g_gl_date              DATE;

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

PROCEDURE get_mapped_cust_and_site 
(
   p_dsdbi_customer_num IN VARCHAR2,
   p_dsdbi_customer_site_num IN VARCHAR2,
   o_dtpli_customer_num OUT VARCHAR2,
   o_dtpli_customer_site_num OUT VARCHAR2)
IS
   CURSOR new_cust_and_site_c IS 
      SELECT dtpli_customer_num, 
             dtpli_customer_site_num
      FROM fmsmgr.xxar_customer_conversion_tfm
      WHERE record_action = 'MAPPED'
      AND dsdbi_customer_num = p_dsdbi_customer_num
      AND dsdbi_customer_site_num = p_dsdbi_customer_site_num;
BEGIN
   
   FOR new_cust_and_site_r IN new_cust_and_site_c LOOP
      o_dtpli_customer_num := new_cust_and_site_r.dtpli_customer_num; 
      o_dtpli_customer_site_num := new_cust_and_site_r.dtpli_customer_site_num; 
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      print_debug('Error get_mapped_cust_and_site'||SQLERRM);
      print_debug('p_dsdbi_customer_num : '||p_dsdbi_customer_num);
      print_debug('p_dsdbi_customer_site_num : '||p_dsdbi_customer_site_num);
END get_mapped_cust_and_site;

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
      SELECT null record_id,
       cus.customer_name customer_name,
       cus.customer_number customer_number,
       hps.party_site_number customer_site_number,
       ttyp.name trx_type,
       trx.trx_number,
       to_char(trx.trx_date) trx_date,
       trx.attribute7 CRN,
       ter.name term_name,
       tli.line_number,
       tli.line_type,
       tli.description line_description,
       tli.quantity_invoiced line_quantity,
       tli.unit_selling_price unit_selling_price,
       tdi.amount line_amount,
       vat.tax_code,
       tli.attribute14 from_period_of_service,
       tli.attribute15 to_period_of_service,
       tdi.acctd_amount dist_amount,
       gcc.concatenated_segments charge_code,
       'Success' status
      FROM ra_customer_trx_all trx,
           ra_cust_trx_types_all ttyp,
           ra_customers cus,
           ra_site_uses_ALL stu,
           ra_addresses_all cad,
           hz_party_sites hps,
           ra_customer_trx_lines_all tli,
           RA_TERMS_TL ter,
           AR_VAT_TAX_ALL_B vat,
           ra_cust_trx_line_gl_dist_ALL tdi,
           gl_code_combinations_kfv gcc
      WHERE trx.request_id = (SELECT r.request_id
                                       FROM   fnd_concurrent_requests r,
                                              fnd_concurrent_programs p
                                       WHERE  p.concurrent_program_name = 'RAXTRX'
                                       AND    p.concurrent_program_id = r.concurrent_program_id
                                       AND    r.parent_request_id = p_request_id)
      AND    trx.bill_to_customer_id = cus.customer_id
      AND    trx.bill_to_site_use_id = stu.site_use_id
      AND    trx.cust_trx_type_id = ttyp.cust_trx_type_id
      AND    trx.term_id = ter.term_id
      AND    stu.address_id = cad.address_id
      AND    cad.party_site_id = hps.party_site_id
      AND    trx.customer_trx_id = tli.customer_trx_id
      AND    tli.customer_trx_id = tdi.customer_trx_id
      AND    tli.customer_trx_line_id = tdi.customer_trx_line_id
      AND    tli.vat_tax_id = vat.vat_tax_id
      and    tdi.code_combination_id=gcc.code_combination_id
      AND    NVL(p_file_error, 'N') = 'N'
      UNION ALL
      SELECT tfm.record_id,
             stg.dsdbi_customer_name customer_name,
             stg.dsdbi_customer_number customer_number,
             stg.dsdbi_customer_site_number customer_site_number,
             stg.oracle_trx_type trx_type,
             stg.dsdbi_trx_number trx_number,
             stg.trx_date trx_date,
             stg.dsdbi_crn crn,
             stg.term_name,
             to_number(stg.line_number) line_number,
             stg.line_type line_type,
             stg.line_description line_description,
             to_number(stg.line_quantity) line_quantity,
             to_number(stg.unit_selling_price) unit_selling_price,
             to_number(stg.line_amount) line_amount,
             stg.tax_code tax_code,
             stg.period_of_service_from from_period_of_service,
             stg.period_of_service_to to_period_of_service,
             to_number(tfm.dist_amount) dist_amount,
             tfm.segment1||'-'||tfm.segment2||'-'||tfm.segment3||'-'||tfm.segment4||'-'||tfm.segment5||'-'||tfm.segment6||'-'||tfm.segment7 charge_code,
             tfm.status status
      FROM   xxar_open_invoices_conv_stg stg,
             xxar_open_invoices_conv_tfm tfm
      WHERE  stg.run_id = p_run_id
      AND    p_request_id IS NULL
      AND    stg.run_id = tfm.run_id(+)
      AND    stg.record_id = tfm.record_id(+)
      AND    NVL(p_file_error, 'N') = 'N'
      AND    EXISTS (SELECT 'x'
                     FROM   xxar_open_invoices_conv_tfm x
                     WHERE  x.run_id = tfm.run_id
                     AND    x.status IN ('ERROR', 'REJECTED'));

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
      l_text := l_text || r_trx.customer_name || p_delim;
      l_text := l_text || r_trx.customer_number || p_delim;
      l_text := l_text || r_trx.customer_site_number || p_delim;
      l_text := l_text || r_trx.trx_type || p_delim;
      l_text := l_text || r_trx.trx_number || p_delim;
      l_text := l_text || r_trx.trx_date || p_delim;
      l_text := l_text || r_trx.crn || p_delim;
      l_text := l_text || r_trx.term_name || p_delim;
      l_text := l_text || r_trx.line_number || p_delim;
      l_text := l_text || r_trx.line_type || p_delim;
      l_text := l_text || r_trx.line_description || p_delim;
      l_text := l_text || r_trx.line_quantity || p_delim;
      l_text := l_text || r_trx.unit_selling_price || p_delim;
      l_text := l_text || r_trx.line_description || p_delim;
      l_text := l_text || r_trx.line_amount || p_delim;
      l_text := l_text || r_trx.line_description || p_delim;
      l_text := l_text || r_trx.tax_code || p_delim;
      l_text := l_text || r_trx.from_period_of_service || p_delim;
      l_text := l_text || r_trx.to_period_of_service || p_delim;
      l_text := l_text || r_trx.dist_amount || p_delim;
      l_text := l_text || r_trx.charge_code || p_delim;
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
      SELECT t.TRX_NUMBER,
             l.line_number
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
      UPDATE xxar_open_invoices_conv_tfm tfm
      SET    status = 'PROCESSED'
      WHERE  tfm.run_id = p_run_id
      AND    tfm.DSDBI_TRX_NUMBER = t_load(i).TRX_NUMBER;
     -- AND    tfm.line_number = t_load(i).line_number; Commented by Joy Pinto on 08-Aug-2017 updates should happen for all lines of the transaction

   END LOOP;
   CLOSE c_load;

   UPDATE xxar_open_invoices_conv_tfm
   SET    status = 'REJECTED'
   WHERE  run_id = p_run_id
   AND    status = 'VALIDATED';

   COMMIT;

   SELECT COUNT(1)
   INTO   l_load_count
   FROM   xxar_open_invoices_conv_tfm tfm
   WHERE  tfm.run_id = p_run_id
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
      WHERE  int_code = g_int_code;

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

   r_int                 c_int%ROWTYPE;
   t_prerun_errors       prerun_error_tab_type := prerun_error_tab_type();
   t_files               xxint_common_pkg.t_files_type;

   -- Interface Framework
   l_run_id              NUMBER;
   l_run_stage_id        NUMBER;
   l_run_transform_id    NUMBER;
   l_run_load_id         NUMBER;
   l_run_report_id       NUMBER;

   stage_phase           BOOLEAN;
   transform_phase       BOOLEAN;
   load_phase            BOOLEAN;
   write_to_out          BOOLEAN;

   interface_error       EXCEPTION;
   to_date_error         EXCEPTION;
   PRAGMA                EXCEPTION_INIT(to_date_error, -1850);

BEGIN
   xxint_common_pkg.g_object_type := 'INVOICES'; -- Added as interface directories are repointed to NFS
   -- Global Variables
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
   --g_gl_date := p_gl_date;--NVL(to_date(p_gl_date,'DD-MON-YYYY'), SYSDATE);
   g_batch_source := l_source;--'CONV';
   write_to_out := TRUE;

   l_ctl := NVL(p_control_file, g_ctl);
   l_file := NVL(p_file_name, l_source || g_file);

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
         l_message := REPLACE(l_message, '$GL_DATE', TO_CHAR(g_gl_date, 'DD-MON-YYYY'));
         t_prerun_errors.EXTEND;
         t_prerun_errors(t_prerun_errors.COUNT) := l_message;
   END;

   -- Validate Batch Source
   BEGIN
      SELECT rev_acc_allocation_rule,
             batch_source_type,
             batch_source_id,
             attribute1
      INTO   l_alloc_rule,
             l_batch_source_type,
             g_batch_source_id,
             g_batch_prefix
      FROM   ra_batch_sources b
      WHERE  b.name = g_batch_source;


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
              g_int_code,
              g_int_name,
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
         l_message := REPLACE(l_message, '$INT_CODE', g_int_code);
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

      
   END LOOP;

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
                  (p_int_code       => g_int_code,
                   p_src_rec_count  => NULL,
                   p_src_hash_total => NULL,
                   p_src_batch_name => p_file);

   -- Staging
   p_run_stage_id := dot_common_int_pkg.start_run_phase
                        (p_run_id                  => p_run_id,
                         p_phase_code              => g_stage,
                         p_phase_mode              => NULL,
                         p_int_table_name          => p_file,
                         p_int_table_key_col1      => 'DSDBI_TRX_NUMBER',
                         p_int_table_key_col_desc1 => 'Transaction Number',
                         p_int_table_key_col2      => 'LINE_NUMBER',
                         p_int_table_key_col_desc2 => 'Line Num',
                         p_int_table_key_col3      => '',
                         p_int_table_key_col_desc3 => '');

   -- Transform
   p_run_transform_id := dot_common_int_pkg.start_run_phase
                            (p_run_id                  => p_run_id,
                             p_phase_code              => g_transform,
                             p_phase_mode              => g_int_mode,
                             p_int_table_name          => 'xxar_open_invoices_conv_stg',
                             p_int_table_key_col1      => 'DSDBI_DSDBI_TRX_NUMBER',
                             p_int_table_key_col_desc1 => 'Transaction Number',
                             p_int_table_key_col2      => 'LINE_NUMBER',
                             p_int_table_key_col_desc2 => 'Line Num',
                             p_int_table_key_col3      => '',
                             p_int_table_key_col_desc3 => '');

   -- Load
   p_run_load_id := dot_common_int_pkg.start_run_phase
                       (p_run_id                  => p_run_id,
                        p_phase_code              => g_load,
                        p_phase_mode              => g_int_mode,
                        p_int_table_name          => 'xxar_open_invoices_conv_tfm',
                        p_int_table_key_col1      => 'DSDBI_DSDBI_TRX_NUMBER',
                        p_int_table_key_col_desc1 => 'Transaction Number',
                        p_int_table_key_col2      => 'LINE_NUMBER',
                        p_int_table_key_col_desc2 => 'Line Num',
                        p_int_table_key_col3      => '',
                        p_int_table_key_col_desc3 => '');

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
   l_log  := REPLACE(l_file, 'csv', 'log');
   l_bad  := REPLACE(l_file, 'csv', 'bad');

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
      UPDATE xxar_open_invoices_conv_stg
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
          p_src_code     => g_src_code,
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
          p_src_code     => g_src_code,
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
          p_src_code     => g_src_code,
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
             stg.dsdbi_customer_name,
             stg.dsdbi_customer_number,
             stg.dsdbi_customer_site_number,
             stg.oracle_trx_type,
             TRIM(stg.DSDBI_TRX_NUMBER) DSDBI_TRX_NUMBER,
             stg.trx_date,
             stg.inv_amount,
             stg.dsdbi_crn,
             stg.term_name,
             stg.due_date,
             stg.comments,
             stg.po_number,
             stg.customer_contact_name,
             stg.invoice_email,
             stg.internal_contact_name,
             TRIM(stg.line_number) line_number,
             stg.line_type,
             stg.line_description,
             stg.sales_order,
             stg.line_quantity,
             stg.unit_selling_price,
             stg.line_amount,
             stg.tax_code,
             stg.period_of_service_from,
             stg.period_of_service_to,
             stg.dist_line_type,
             stg.dist_amount,
             regexp_replace(stg.charge_code, '[^0-9A-Za-z-]', '') charge_code,
             stg.rram_source_system_ref
      FROM   xxar_open_invoices_conv_stg stg
      WHERE  stg.run_id = p_run_id
      AND    stg.status = 'PROCESSED'
      ORDER BY DSDBI_TRX_NUMBER,stg.line_type;
      
   CURSOR c_inv_dup IS
            SELECT a.dsdbi_trx_number trx_number,
             a.line_number invoice_line_number,
             a.line_type,
             COUNT(1) line_count
      FROM   xxar_open_invoices_conv_stg a
      WHERE  a.run_id = p_run_id
      AND    TRIM(a.dsdbi_trx_number) IS NOT NULL
      GROUP  BY
             a.dsdbi_trx_number,
             a.line_number,
             a.line_type
      HAVING COUNT(1) > 1;       
   
   CURSOR c_tax (p_tax_code VARCHAR2) IS
      SELECT tax_code
      FROM   ar_vat_tax
      WHERE  tax_code = p_tax_code;    
      
   CURSOR c_get_missing_tax_code  IS
   SELECT * 
   FROM  xxar_open_invoices_conv_stg x1 
   WHERE line_type = 'LINE' 
   AND   x1.run_id = p_run_id 
   AND   ( -- Fixed by Joy Pinto on 09-Aug-2017 ERPTEST Comments
            x1.tax_code IS NULL OR  --Case 1 Tax code is Missing
           (x1.tax_code IS NOT NULL --Case 2 Tax code exists but missing tax line with corresponding tax code
            AND NOT EXISTS (
                 SELECT  1 from xxar_open_invoices_conv_stg x2 
                 WHERE  x1.line_number = x2.line_number 
                 AND    x2.dsdbi_trx_number = x1.dsdbi_trx_number
                 AND    x2.line_type = 'TAX'
                 AND    x1.tax_code = x2.tax_code
               )
           )
         )
   ORDER BY x1.dsdbi_trx_number,x1.line_number  ;
   
   CURSOR c_inv_trx_type IS
      SELECT a.dsdbi_trx_number trx_number,
             COUNT(1) line_count
      FROM   xxar_open_invoices_conv_stg a
      WHERE  a.run_id = p_run_id
      AND    TRIM(a.dsdbi_trx_number) IS NOT NULL
      AND    EXISTS (SELECT b.dsdbi_trx_number,
                            COUNT(DISTINCT b.oracle_trx_type)
                     FROM   xxar_open_invoices_conv_stg b
                     WHERE  b.run_id = a.run_id
                     AND    b.dsdbi_trx_number = a.dsdbi_trx_number
                     GROUP  BY b.dsdbi_trx_number
                     HAVING COUNT(DISTINCT b.oracle_trx_type) > 1)
      GROUP  BY a.dsdbi_trx_number; 
      
   CURSOR c_validate_remit_to(p_customer_number VARCHAR2,p_customer_site_number VARCHAR2) IS
      SELECT 'Y'
      FROM   hz_party_sites hps,
             hz_locations hl,
             ra_remit_tos_all rrta,
             xxar_customer_conversion_tfm tfm
      WHERE
             hps.location_id = hl.location_id
      AND    rrta.country=hl.COUNTRY
      AND    tfm.dtpli_customer_site_num = hps.party_site_number
      AND    tfm.status <> 'ERROR'
      AND    dsdbi_customer_num = p_customer_number
      AND    dsdbi_customer_site_num = p_customer_site_number  ;

     
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
   l_validate_remit_to   VARCHAR2(10);
   l_DSDBI_TRX_NUMBER          xxar_open_invoices_conv_stg.DSDBI_TRX_NUMBER%TYPE;
   l_run_report_id       NUMBER;
   l_tax_line_count      NUMBER;

   r_stg                 c_stg%ROWTYPE;
   r_tfm                 xxar_open_invoices_conv_tfm%ROWTYPE;
   r_error               dot_int_run_phase_errors%ROWTYPE;
   t_segments            fnd_flex_ext.SegmentArray;

   transform_error       EXCEPTION;
   transform_status      BOOLEAN := TRUE;
   calculate_amount      BOOLEAN;
   
   l_open_amount NUMBER;
   l_actual_amount NUMBER;
   v_new_line_amount NUMBER; 
   v_new_line_quantity NUMBER; 
   v_tax_rate NUMBER;
   r_inv_dup                          c_inv_dup%ROWTYPE;
   r_get_missing_tax_code             c_get_missing_tax_code%ROWTYPE;
   l_trx_number                       VARCHAR2(150);
   
   CURSOR ramaining_after_prorate_c IS
         SELECT DISTINCT tfm.dsdbi_trx_number, 
             INV_AMOUNT-SUM(LINE_AMOUNT) remaining_amount
         FROM xxar_open_invoices_conv_tfm tfm
         HAVING INV_AMOUNT-SUM(LINE_AMOUNT) <>0
         GROUP by dsdbi_trx_number, INV_AMOUNT;
         
  
   
   PROCEDURE add_remaining_to_max_amount (p_dsdbi_trx_number VARCHAR2,
                                          p_remaining_amount NUMBER)
   IS
      
      
      CURSOR main_c IS
         select line_number, dsdbi_trx_number, line_amount
         from xxar_open_invoices_conv_tfm a
         where line_amount = 
                            (select max(line_amount)
                             from xxar_open_invoices_conv_tfm b
                             where dsdbi_trx_number = p_dsdbi_trx_number)
         and dsdbi_trx_number = p_dsdbi_trx_number
         AND line_type = 'LINE';
   BEGIN
         FOR main_r IN main_c LOOP
         
         BEGIN   
            UPDATE xxar_open_invoices_conv_tfm
            SET line_amount = line_amount+p_remaining_amount,
                dist_amount = dist_amount+p_remaining_amount
            WHERE line_number = main_r.line_number
            AND dsdbi_trx_number = main_r.dsdbi_trx_number
            AND line_type = 'LINE';
         END;
         
         BEGIN
            UPDATE xxar_open_invoices_conv_tfm
            SET line_quantity = line_amount/unit_selling_price
            WHERE line_number = main_r.line_number
            AND dsdbi_trx_number = main_r.dsdbi_trx_number
            AND line_type = 'LINE';
         END;
         
         END LOOP;
      COMMIT;
   EXCEPTION
      WHEN 
         OTHERS THEN
            print_debug('ERROR WHILE add_remaining_to_max_amount '||SQLERRM);
   END add_remaining_to_max_amount;

   PROCEDURE error_token_init
   IS
   BEGIN
      r_error.error_token_val1 := NULL;
      r_error.error_token_val2 := NULL;
      r_error.error_token_val3 := NULL;
      r_error.error_token_val4 := NULL;
      r_error.error_token_val5 := NULL;
   END error_token_init;

   PROCEDURE set_to_error (p_DSDBI_TRX_NUMBER VARCHAR2, p_line_number NUMBER)
   IS
   BEGIN
      UPDATE xxar_open_invoices_conv_tfm
      SET    status = 'ERROR'
      WHERE  DSDBI_TRX_NUMBER = p_DSDBI_TRX_NUMBER
      AND    line_number = NVL(p_line_number, line_number)
      AND    NVL(status, 'NEW') <> 'ERROR'
      AND    run_id = p_run_id;
   END set_to_error;
   
   PROCEDURE get_sum_amounts (p_dsdbi_trx_number IN VARCHAR2,
                              o_open_amount OUT NUMBER,
                              o_actual_amount OUT NUMBER)
   IS   
      CURSOR open_amount_c IS
      SELECT DISTINCT dsdbi_trx_number,
             INV_AMOUNT open_amount, 
             sum(nvl(line_amount,0)) sum_actual_amount
      FROM xxar_open_invoices_conv_STG
      WHERE dsdbi_trx_number = p_dsdbi_trx_number
      GROUP BY dsdbi_trx_number, 
            INV_AMOUNT;
   
   BEGIN
      
      FOR open_amount_r IN open_amount_c LOOP
         o_open_amount   := open_amount_r.open_amount;
         o_actual_amount := open_amount_r.sum_actual_amount;
      END LOOP;
      
   END get_sum_amounts;
   
   procedure get_dtpli_coa(p_old_charg_code varchar2,
                            o_code_combination_id OUT gl_code_combinations.code_combination_id%type,     
                            o_segment1 OUT gl_code_combinations.segment1%type,                 
                            o_segment2 OUT gl_code_combinations.segment2%type,                 
                            o_segment3 OUT gl_code_combinations.segment3%type,                 
                            o_segment4 OUT gl_code_combinations.segment4%type,                 
                            o_segment5 OUT gl_code_combinations.segment5%type,                 
                            o_segment6 OUT gl_code_combinations.segment6%type,                 
                            o_segment7 OUT gl_code_combinations.segment7%type)
   IS
      x_target_cc  VARCHAR2(150);
      lv_error_msg VARCHAR2(2000);
      ln_ccid      NUMBER;
      l_segs       NUMBER;
      t_segments            fnd_flex_ext.SegmentArray;
      --EXCEPTION NO_CCID;
   BEGIN
      x_target_cc := xxgl_import_coa_mapping_pkg.get_mapped_code_combination
                        (
                            p_code_comb => p_old_charg_code,
                            x_ccid => ln_ccid,
                            x_error_msg => lv_error_msg
                        ) ;  
                        
      IF lv_error_msg IS NOT NULL OR x_target_cc IS NULL THEN
         RAISE NO_DATA_FOUND;
      END IF;
      
      l_segs := fnd_flex_ext.breakup_segments(concatenated_segs => x_target_cc,
                                                    delimiter         => '-',
                                                    segments          => t_segments);
                                                    
       o_segment1 := t_segments(1);
       o_segment2 := t_segments(2);
       o_segment3 := t_segments(3);
       o_segment4 := t_segments(4);
       o_segment5 := t_segments(5);
       o_segment6 := t_segments(6);
       o_segment7 := t_segments(7);                                                   
                                                  
   EXCEPTION
       WHEN OTHERS THEN
          l_tfm_error := l_tfm_error + 1;
          xxint_common_pkg.get_error_message(g_error_message_39||'-'||SQLERRM, r_error.msg_code, r_error.error_text);
          r_error.error_text := REPLACE(r_error.error_text, '$CHARGE_CODE', p_old_charg_code);
          raise_error(r_error);
   END;
   
   FUNCTION get_new_tax_amount(p_org_id NUMBER,
                         p_sob_id NUMBER,
                         p_dsdbi_trx_number VARCHAR2,
                         p_line_number NUMBER,
                         p_tax_code AR_VAT_TAX_ALL.TAX_CODE%TYPE/*,
                         p_new_line_amount xxar_open_invoices_conv_tfm.LINE_AMOUNT%TYPE*/
                         )
   RETURN NUMBER IS
      o_new_tax_amount xxar_open_invoices_conv_tfm.LINE_AMOUNT%TYPE;
   BEGIN
      
      /*SELECT (TAX_RATE/100 * p_new_line_amount)
      INTO o_new_tax_amount
      FROM AR_VAT_TAX_ALL A
      WHERE ORG_ID = p_org_id
      AND SET_OF_BOOKS_ID = p_sob_id
      AND ENABLED_FLAG = 'Y'
      AND TAX_CODE = p_tax_code;*/
      
      SELECT ROUND((line_amount*TAX_RATE/100),2) new_tax_amount
      INTO o_new_tax_amount
      FROM FMSMGR.xxar_open_invoices_conv_tfm tfm,
           AR_VAT_TAX_ALL tax
      WHERE line_type = 'LINE'
      AND line_number = p_line_number 
      AND dsdbi_trx_number = p_dsdbi_trx_number
      AND tax.ORG_ID = p_org_id
      AND tax.SET_OF_BOOKS_ID = p_sob_id
      AND tax.ENABLED_FLAG = 'Y'
      AND tax.TAX_CODE = tfm.TAX_CODE;
      
      RETURN o_new_tax_amount;
   
   EXCEPTION
      WHEN OTHERS THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_42||'-'||SQLERRM, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$TAX_CODE', p_tax_code);
         raise_error(r_error);
   END get_new_tax_amount;
      
   FUNCTION get_mapped_customer_ref(p_customer_number VARCHAR2)
   RETURN VARCHAR2 IS
      o_new_customer_id ra_customers.orig_system_reference%TYPE;
   BEGIN
      SELECT max(rc.orig_system_reference)
      INTO o_new_customer_id
      FROM xxar_customer_conversion_tfm tfm,
           ra_customers rc
      WHERE --tfm.record_action = 'MAPPED'
       tfm.dtpli_customer_num = rc.customer_number
      AND tfm.dsdbi_customer_num = p_customer_number;
      
      RETURN o_new_customer_id;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;       
   END get_mapped_customer_ref;
   
   FUNCTION get_mapped_bill_address_ref (p_customer_number VARCHAR2,
                                                    p_customer_site_number VARCHAR2)
   RETURN VARCHAR2 IS
      o_orig_sys_bill_address_ref  hz_cust_acct_sites_all.ORIG_SYSTEM_REFERENCE%TYPE;
   BEGIN
      SELECT max(hcas.ORIG_SYSTEM_REFERENCE)--hps.party_site_id
      INTO o_orig_sys_bill_address_ref
      FROM xxar_customer_conversion_tfm tfm,
           hz_party_sites hps,
           hz_cust_acct_sites_all hcas
      WHERE --record_action = 'MAPPED'
          dsdbi_customer_num = p_customer_number
      AND dsdbi_customer_site_num = p_customer_site_number
      AND tfm.dtpli_customer_site_num = hps.party_site_number
      AND tfm.status <> 'ERROR'
      AND hps.party_site_id = hcas.party_site_id;
      
      RETURN o_orig_sys_bill_address_ref;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;   
   END get_mapped_bill_address_ref;  
   

   FUNCTION get_mapped_customer_id (p_customer_number VARCHAR2,p_customer_site_number VARCHAR2)
   RETURN VARCHAR2 IS
      o_new_customer_id VARCHAR2(100);
   BEGIN
      /*SELECT max(nvl(hca.ORIG_SYSTEM_REFERENCE,rc.customer_id))
      INTO o_new_customer_id
      FROM xxar_customer_conversion_tfm tfm,
           ra_customers rc,
           HZ_CUST_ACCOUNTS_all hca
      WHERE tfm.dtpli_customer_num = rc.customer_number
      AND   tfm.dsdbi_customer_num = p_customer_number
      AND    hca.party_id = rc.party_id;*/
      
     SELECT max(nvl(hca.ORIG_SYSTEM_REFERENCE,rc.customer_id))
       INTO o_new_customer_id
      FROM xxar_customer_conversion_tfm tfm,
           hz_party_sites hps,
           hz_cust_acct_sites_all hcas,
           ra_customers rc,
           HZ_CUST_ACCOUNTS_all hca
      WHERE --record_action = 'MAPPED'
          dsdbi_customer_num = p_customer_number
      AND DSDBI_CUSTOMER_site_NUM = p_customer_site_number  
      AND tfm.dtpli_customer_site_num = hps.party_site_number
      AND tfm.dtpli_customer_num = rc.customer_number
      AND hps.party_id = hca.party_id
      AND tfm.status <> 'ERROR'
      AND rc.customer_id = hca.cust_account_id -- Added by Joy Pinto on 08-Aug-2017 to fix the duplicate customer accounts issue
      AND hps.party_site_id = hcas.party_site_id;      
      
      RETURN o_new_customer_id;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RETURN NULL;
      WHEN OTHERS THEN
         RETURN NULL;         
   END get_mapped_customer_id;
     
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
   FROM   xxar_open_invoices_conv_stg
   WHERE  run_id = p_run_id;

   IF l_record_count = 0 THEN
      GOTO update_run_phase;
   END IF;

   /* Update Run Phase */
   dot_common_int_pkg.update_run_phase
      (p_run_phase_id => p_run_phase_id,
       p_src_code     => g_src_code,
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
      r_error.int_table_key_val1 := r_stg.DSDBI_TRX_NUMBER;
      r_error.int_table_key_val2 := r_stg.LINE_NUMBER;
      
      
      -- TFM Record
      r_tfm := NULL;
      r_tfm.record_id := r_stg.record_id;
      r_tfm.run_id := p_run_id;
      r_tfm.run_phase_id := p_run_phase_id;
      --r_tfm.batch_source_name := p_source;
      
      r_tfm.DSDBI_CUSTOMER_NAME:= SUBSTR(r_stg.DSDBI_CUSTOMER_NAME,1,240);              
      r_tfm.DSDBI_CUSTOMER_NUMBER:= SUBSTR(r_stg.DSDBI_CUSTOMER_NUMBER,1,240);          
      r_tfm.DSDBI_CUSTOMER_SITE_NUMBER:= SUBSTR(r_stg.DSDBI_CUSTOMER_SITE_NUMBER,1,240);
      r_tfm.ORACLE_TRX_TYPE:= SUBSTR(r_stg.ORACLE_TRX_TYPE,1,20);                      
      r_tfm.DSDBI_TRX_NUMBER:= SUBSTR(r_stg.DSDBI_TRX_NUMBER,1,20);                    
      --r_tfm.TRX_DATE:= to_date(r_stg.TRX_DATE,'DD-MON-RRRR');                                    
      r_tfm.INV_AMOUNT:= r_stg.INV_AMOUNT;                                
      r_tfm.DSDBI_CRN:= SUBSTR(r_stg.DSDBI_CRN,1,150);                                  
      r_tfm.TERM_NAME:= SUBSTR(r_stg.TERM_NAME,1,15);                                  
      r_tfm.COMMENTS:= SUBSTR(r_stg.COMMENTS,1,240);                                    
      r_tfm.PO_NUMBER:= SUBSTR(r_stg.PO_NUMBER,1,50);                                  
      r_tfm.CUSTOMER_CONTACT_NAME:= SUBSTR(r_stg.CUSTOMER_CONTACT_NAME,1,150);
      r_tfm.RRAM_SOURCE_SYSTEM_REF:= SUBSTR(r_stg.RRAM_SOURCE_SYSTEM_REF,1,30); -- RRAM_SOURCE_SYSTEM_REF was added
      r_tfm.INVOICE_EMAIL:= SUBSTR(r_stg.INVOICE_EMAIL,1,150);  -- Fixed by Joy Pinto on 31-Aug-2017                        
      r_tfm.INTERNAL_CONTACT_NAME:= SUBSTR(r_stg.INTERNAL_CONTACT_NAME,1,150);          
      r_tfm.LINE_NUMBER:= SUBSTR(r_stg.LINE_NUMBER,1,30);                              
      r_tfm.LINE_TYPE:= SUBSTR(r_stg.LINE_TYPE,1,20);                                  
      r_tfm.LINE_DESCRIPTION:= SUBSTR(r_stg.LINE_DESCRIPTION,1,240);                    
      r_tfm.SALES_ORDER:= SUBSTR(r_stg.SALES_ORDER,1,50);                                                           
      r_tfm.UNIT_SELLING_PRICE:= r_stg.UNIT_SELLING_PRICE;   
      r_tfm.orig_system_bill_customer_ref:= get_mapped_customer_id(r_stg.dsdbi_customer_number,r_stg.dsdbi_customer_site_number);
      r_tfm.orig_system_sold_customer_ref:= get_mapped_customer_id(r_stg.dsdbi_customer_number,r_stg.dsdbi_customer_site_number); 
      r_tfm.orig_system_bill_address_ref := get_mapped_bill_address_ref(r_stg.dsdbi_customer_number ,r_stg.dsdbi_customer_site_number);           
      r_tfm.TAX_CODE:= SUBSTR(r_stg.TAX_CODE,1,50);                                    
      r_tfm.PERIOD_OF_SERVICE_FROM:= SUBSTR(r_stg.PERIOD_OF_SERVICE_FROM,1,150);        
      r_tfm.PERIOD_OF_SERVICE_TO:= SUBSTR(r_stg.PERIOD_OF_SERVICE_TO,1,150);            
      r_tfm.DIST_LINE_TYPE:= SUBSTR(r_stg.DIST_LINE_TYPE,1,20);   
      r_tfm.CHARGE_CODE:= SUBSTR(r_stg.CHARGE_CODE,1,500);
      r_tfm.created_by := g_user_id;                             
      r_tfm.creation_date := SYSDATE;   
  
      -- Validate Line Amount      
      error_token_init;
      r_error.error_token_val1 := r_stg.LINE_AMOUNT;
      BEGIN
         IF TO_NUMBER(r_stg.LINE_AMOUNT) IS NOT NULL THEN
            r_tfm.LINE_AMOUNT:= r_stg.LINE_AMOUNT; 
         END IF;      
      EXCEPTION
         WHEN OTHERS THEN
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_48, r_error.msg_code, r_error.error_text);
            r_error.error_text := REPLACE(r_error.error_text, '$INVALID_VALUE', r_stg.LINE_AMOUNT);
            r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'LINE AMOUNT');
            raise_error(r_error);         
      END;      
      
      -- Validate Distribution Amount      
      error_token_init;
      r_error.error_token_val1:=r_stg.DIST_AMOUNT;
      BEGIN
         IF TO_NUMBER(r_stg.DIST_AMOUNT) IS NOT NULL THEN
            r_tfm.DIST_AMOUNT:= r_stg.DIST_AMOUNT; 
         END IF;      
      EXCEPTION
         WHEN OTHERS THEN
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_48, r_error.msg_code, r_error.error_text);
            r_error.error_text := REPLACE(r_error.error_text, '$INVALID_VALUE', r_stg.DIST_AMOUNT);
            r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'DIST AMOUNT');            
            raise_error(r_error);         
      END; 
      
      -- Validate LINE_QUANTITY     
      error_token_init;
      r_error.error_token_val1:=r_stg.LINE_QUANTITY;
      BEGIN
         IF TO_NUMBER(r_stg.LINE_QUANTITY) IS NOT NULL THEN
            r_tfm.LINE_QUANTITY:= r_stg.LINE_QUANTITY; 
         END IF;      
      EXCEPTION
         WHEN OTHERS THEN
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_48, r_error.msg_code, r_error.error_text);
            r_error.error_text := REPLACE(r_error.error_text, '$INVALID_VALUE', r_stg.LINE_QUANTITY);
            r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'LINE QUANTITY');              
            raise_error(r_error);         
      END;   
      
      
      
      -- Due Date
      
      error_token_init;
      r_error.error_token_val1 := r_stg.DUE_DATE;
      BEGIN
         IF TO_DATE(r_stg.DUE_DATE, 'DD/MM/RRRR') IS NOT NULL THEN
            r_tfm.DUE_DATE:= TO_DATE(r_stg.DUE_DATE, 'DD/MM/RRRR');
         END IF;      
      EXCEPTION
         WHEN OTHERS THEN
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_47, r_error.msg_code, r_error.error_text);
            raise_error(r_error);         
      END;
      
      -- Customer Number and Site Number
      error_token_init;
      r_error.error_token_val1 := r_stg.DSDBI_CUSTOMER_SITE_NUMBER;
      IF r_stg.DSDBI_CUSTOMER_SITE_NUMBER IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'CUSTOMER SITE NUMBER');
         raise_error(r_error);
      END IF;
      
      -- Validate orig_sys_bill_customer_ref
      error_token_init;
      r_error.error_token_val1 := r_tfm.orig_system_bill_customer_ref;
      IF r_tfm.orig_system_bill_customer_ref IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_43, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$CUSTOMER_NUM' , r_stg.dsdbi_customer_number);
         raise_error(r_error);
      END IF;      
      
      -- Validate orig_sys_sold_customer_ref
      error_token_init;
      r_error.error_token_val1 := r_tfm.orig_system_sold_customer_ref;
      IF r_tfm.orig_system_sold_customer_ref IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_44, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$CUSTOMER_NUM' , r_stg.dsdbi_customer_number);
         raise_error(r_error);
      END IF;  
      
      -- Validate orig_sys_bill_address_ref
      error_token_init;
      r_error.error_token_val1 := r_tfm.orig_system_bill_address_ref;
      IF r_tfm.orig_system_bill_address_ref IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_45, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$CUSTOMER_SITE_NUMBER' , r_stg.dsdbi_customer_site_number);
         r_error.error_text := REPLACE(r_error.error_text, '$CUSTOMER_NUM' , r_stg.dsdbi_customer_number);
         raise_error(r_error);
      END IF;        

      -- Transaction Type
      error_token_init;
      r_error.error_token_val1 := r_stg.ORACLE_TRX_TYPE;
      IF r_stg.ORACLE_TRX_TYPE IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'TRANSACTION TYPE NAME');
         raise_error(r_error);
      END IF;

      -- Transaction Number
      error_token_init;
      r_error.error_token_val1 := r_stg.DSDBI_TRX_NUMBER;
      IF r_stg.DSDBI_TRX_NUMBER IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'TRX NUMBER');
         raise_error(r_error);
      ELSE
         IF LENGTH(TRIM(r_stg.DSDBI_TRX_NUMBER)) > 20 THEN
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_08, r_error.msg_code, r_error.error_text);
            r_error.error_text := REPLACE(r_error.error_text, '$TRX_NUMBER', r_stg.DSDBI_TRX_NUMBER);
            raise_error(r_error);
         ELSE
            r_tfm.DSDBI_TRX_NUMBER := r_stg.DSDBI_TRX_NUMBER;
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
            r_tfm.trx_date := TO_DATE(r_stg.trx_date, 'DD/MM/RRRR'); -- Modifed the date formt Joy Pinto 21-Jul-2017
         EXCEPTION
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_07, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$TRX_DATE', r_stg.trx_date);
               raise_error(r_error);
         END;
      END IF;

      -- Invoice Line Number
      error_token_init;
      r_error.error_token_val1 := r_stg.LINE_NUMBER;
      IF r_stg.LINE_TYPE IN ('LINE','TAX') AND r_stg.LINE_NUMBER IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'INVOICE LINE NUMBER');
         raise_error(r_error);
      ELSE
         BEGIN
            r_tfm.line_number := TO_NUMBER(r_stg.LINE_NUMBER);
         EXCEPTION
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_13, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$LINE_NUMBER', r_stg.LINE_NUMBER);
               raise_error(r_error);
         END;
      END IF;

      -- Description
      error_token_init;
      r_error.error_token_val1 := r_stg.LINE_DESCRIPTION;
      IF r_stg.LINE_TYPE = 'LINE' AND r_stg.LINE_DESCRIPTION IS NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'LINE_DESCRIPTION');
         raise_error(r_error);
      ELSE
         r_tfm.LINE_DESCRIPTION := SUBSTR(r_stg.LINE_DESCRIPTION, 1, 240);
      END IF;

      -- Quantity
      error_token_init;
      r_error.error_token_val1 := r_stg.LINE_QUANTITY;
      IF r_stg.LINE_TYPE IN ('LINE','TAX') AND  r_stg.LINE_QUANTITY IS NULL THEN
         calculate_amount := FALSE;
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'LINE_QUANTITY');
         raise_error(r_error);
      END IF;

      -- Unit Selling Price
      error_token_init;
      r_error.error_token_val1 := r_stg.unit_selling_price;
      IF r_stg.LINE_TYPE = 'LINE' AND r_stg.unit_selling_price IS NULL THEN
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

      -- Account
      error_token_init;
      r_error.error_token_val1 := r_stg.charge_code;
      IF r_stg.line_type = 'LINE' THEN -- Added the code by Joy Pinto on 27-Jul-2017
         IF r_stg.charge_code IS NULL THEN
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_14, r_error.msg_code, r_error.error_text);
            r_error.error_text := REPLACE(r_error.error_text, '$COLUMN_NAME', 'CHARGE CODE');
            raise_error(r_error);
         ELSE
          -- 
                 get_dtpli_coa( r_stg.charge_code,
                                r_tfm.code_combination_id,
                                r_tfm.segment1,
                                r_tfm.segment2,
                                r_tfm.segment3,
                                r_tfm.segment4,
                                r_tfm.segment5,
                                r_tfm.segment6,
                                r_tfm.segment7
                              );
         END IF;
      END IF;
      -- Period of Service: From Date
      error_token_init;
      r_error.error_token_val1 := r_stg.PERIOD_OF_SERVICE_FROM;
      IF r_stg.PERIOD_OF_SERVICE_FROM IS NOT NULL THEN
         BEGIN
            l_date_tl := TO_DATE(r_stg.PERIOD_OF_SERVICE_FROM, 'DD/MM/YYYY');
            r_tfm.PERIOD_OF_SERVICE_FROM := SUBSTR(r_stg.PERIOD_OF_SERVICE_FROM, 1, 150);
         EXCEPTION
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_22, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$PERIOD_OF_SERVICE_FROM', r_stg.PERIOD_OF_SERVICE_FROM);
               raise_error(r_error);
         END;
      END IF;

      -- Period of Service: To Date
      error_token_init;
      r_error.error_token_val1 := r_stg.PERIOD_OF_SERVICE_TO;
      IF r_stg.PERIOD_OF_SERVICE_TO IS NOT NULL THEN
         BEGIN
            l_date_tl := TO_DATE(r_stg.PERIOD_OF_SERVICE_TO, 'DD/MM/YYYY');
            r_tfm.PERIOD_OF_SERVICE_TO := SUBSTR(r_stg.PERIOD_OF_SERVICE_TO, 1, 150);
         EXCEPTION
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_23, r_error.msg_code, r_error.error_text);
               r_error.error_text := REPLACE(r_error.error_text, '$PERIOD_OF_SERVICE_TO', r_stg.PERIOD_OF_SERVICE_TO);
               raise_error(r_error);
         END;
      END IF;
      

      
      -- Invalid tax code
      error_token_init;
      IF r_stg.tax_code IS NOT NULL THEN  
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
      
      -- Validate remit to to Country Added by Joy Pinto on 08-Aug-2017      
      error_token_init;
      l_validate_remit_to := 'N';
      OPEN c_validate_remit_to(r_stg.dsdbi_customer_number,r_stg.dsdbi_customer_site_number);
      FETCH c_validate_remit_to INTO l_validate_remit_to;
      CLOSE c_validate_remit_to  ;
      
      IF nvl(l_validate_remit_to,'N') = 'N' THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_49, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$CUSTOMER_NUM' , r_stg.dsdbi_customer_number);
         raise_error(r_error);
      END IF;        
          

      IF l_tfm_error > 0 THEN
         r_tfm.status := 'ERROR';
      ELSE
         r_tfm.status := 'VALIDATED';
      END IF;
      
      
      INSERT INTO xxar_open_invoices_conv_tfm
      VALUES r_tfm;
            

   END LOOP;
   CLOSE c_stg;
   
   /*
   FOR ramaining_after_prorate_r IN ramaining_after_prorate_c 
   LOOP
      add_remaining_to_max_amount (ramaining_after_prorate_r.dsdbi_trx_number,
                                   ramaining_after_prorate_r.remaining_amount);
   END LOOP;
   */
   ------------------------------
   -- Invoice level validation --
   ------------------------------

   print_debug('run invoice level validations');

   r_error.run_id := p_run_id;
   r_error.run_phase_id := p_run_phase_id;
   r_error.record_id := -1;

   -- Transaction Number already exists
   FOR i IN (SELECT x.DSDBI_TRX_NUMBER,
                    COUNT(1) line_count
             FROM   xxar_open_invoices_conv_stg x
             WHERE  x.run_id = p_run_id
             AND    TRIM(x.DSDBI_TRX_NUMBER) IS NOT NULL
             GROUP  BY x.DSDBI_TRX_NUMBER)
   LOOP
      SELECT COUNT(1)
      INTO   l_error_count_inv
      FROM   ra_customer_trx t
      WHERE  t.batch_source_id = g_batch_source_id
      AND    t.TRX_NUMBER = i.DSDBI_TRX_NUMBER;

      IF l_error_count_inv > 0 THEN
         r_error.int_table_key_val1 := i.DSDBI_TRX_NUMBER;
         r_error.int_table_key_val2 := NULL;
         r_error.int_table_key_val3 := NULL;
         xxint_common_pkg.get_error_message(g_error_message_24, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text, '$TRX_NUMBER', i.DSDBI_TRX_NUMBER);
         raise_error(r_error);
         set_to_error(i.DSDBI_TRX_NUMBER, NULL);
      END IF;
   END LOOP;
   
   error_token_init;
   r_error.record_id := -1;      
   -- Duplicate distribution line
   OPEN c_inv_dup;      
   LOOP
      FETCH c_inv_dup INTO r_inv_dup;
      EXIT WHEN c_inv_dup%NOTFOUND;
      r_error.int_table_key_val1 := r_inv_dup.trx_number;
      r_error.int_table_key_val2 := NULL;
      xxint_common_pkg.get_error_message(g_error_message_25, r_error.msg_code, r_error.error_text);
      raise_error(r_error);
      set_to_error(r_inv_dup.trx_number, NULL);
   END LOOP;
   CLOSE c_inv_dup;  
   
   
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
   
      -- Missing Tax Code
      error_token_init;
      r_error.record_id := -1; 
      --l_tax_line_count :=1;
      OPEN c_get_missing_tax_code;
      LOOP
         FETCH c_get_missing_tax_code INTO r_get_missing_tax_code;
         EXIT WHEN c_get_missing_tax_code%NOTFOUND;
         r_error.int_table_key_val1 := r_get_missing_tax_code.dsdbi_trx_number;
         r_error.int_table_key_val2 := r_get_missing_tax_code.line_number;
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_46, r_error.msg_code, r_error.error_text);
         raise_error(r_error);
      END LOOP;       
   

   SELECT SUM(DECODE(status, 'VALIDATED', 1, 0)),
          SUM(DECODE(status, 'ERROR', 1, 0))
   INTO   l_success_count,
          l_error_count
   FROM   xxar_open_invoices_conv_tfm
   WHERE  run_id = p_run_id;

   IF l_error_count > 0 THEN
      l_run_report_id := dot_common_int_pkg.launch_error_report
                            (p_run_id => p_run_id,
                             p_run_phase_id => p_run_phase_id);
      l_tfm_status := 'ERROR';
      transform_status := FALSE;

      print_debug('run error report (request_id=' || l_run_report_id || ')');
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
       p_src_code     => g_src_code,
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
          p_src_code     => g_src_code,
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
   
   v_link_to_line_context ra_interface_lines_all.link_to_line_context%TYPE;
   v_link_to_line_attribute1 ra_interface_lines_all.link_to_line_attribute1%TYPE;      
   v_link_to_line_attribute2 ra_interface_lines_all.link_to_line_attribute2%TYPE;      
   v_link_to_line_attribute3 ra_interface_lines_all.link_to_line_attribute3%TYPE;
   
   
   
   CURSOR c_int_lines IS
      SELECT RECORD_ID,
             RUN_ID,
             RUN_PHASE_ID,              
             DSDBI_CUSTOMER_NAME,       
             DSDBI_CUSTOMER_NUMBER,     
             DSDBI_CUSTOMER_SITE_NUMBER,
             ORACLE_TRX_TYPE,           
             DSDBI_TRX_NUMBER,          
             TRX_DATE,                  
             INV_AMOUNT,                
             DECODE(line_type,'LINE',DSDBI_CRN,NULL) DSDBI_CRN,  -- ARLRUL14               
             TERM_NAME,                 
             DUE_DATE,  
             DECODE(line_type,'LINE',COMMENTS,NULL) COMMENTS,    --ARLRUL16   
             PO_NUMBER,  
             DECODE(line_type,'LINE',CUSTOMER_CONTACT_NAME,NULL) CUSTOMER_CONTACT_NAME,  -- ARLRUL12   
             DECODE(line_type,'LINE',INVOICE_EMAIL, NULL) INVOICE_EMAIL,    -- ARLRUL15
             DECODE(line_type,'LINE',INTERNAL_CONTACT_NAME,NULL) INTERNAL_CONTACT_NAME, -- ARLRUL13         
             LINE_NUMBER,               
             LINE_TYPE,                 
             DECODE(line_type,'LINE',LINE_DESCRIPTION,'TAX','TAX',NULL) LINE_DESCRIPTION,  -- ARLRUL07
             SALES_ORDER,               
             LINE_QUANTITY,             
             UNIT_SELLING_PRICE,        
             LINE_AMOUNT,               
             TAX_CODE, --DECODE(LINE_TYPE,'TAX',TAX_CODE,NULL) TAX_CODE,   -- Doc ID 405051.1 Tax Code should NOT be populated for line_type LINE , FREIGHT or CHARGES in ra_interface_lines_all      
             DECODE(line_type,'LINE',PERIOD_OF_SERVICE_FROM,NULL) PERIOD_OF_SERVICE_FROM, -- ARLRUL10, ARLRUL11         
             DECODE(line_type,'LINE',PERIOD_OF_SERVICE_TO,NULL) PERIOD_OF_SERVICE_TO,                  
             STATUS,                    
             CREATED_BY,
             CREATION_DATE,
             DECODE(line_type,'TAX',g_autoinv_grouping,NULL) link_to_line_context, -- ARLRUL03
             DECODE(line_type,'TAX',g_batch_source,NULL) link_to_line_attribute1,-- ARLRUL03
             DECODE(line_type,'TAX',dsdbi_trx_number,NULL) link_to_line_attribute2,-- ARLRUL03
             DECODE(line_type,'TAX',line_number,NULL) link_to_line_attribute3,-- ARLRUL03
             DECODE(line_type,'LINE','NOT') printing_option, -- ARLRUL05
             DECODE(line_type,'TAX',line_number||'T', line_number) interface_line_attribute3,-- ARLRUL06 
             DECODE(line_type,'LINE','N',NULL) amount_includes_tax_flag,
             orig_system_bill_customer_ref,
             orig_system_bill_address_ref,
             orig_system_sold_customer_ref
      FROM   xxar_open_invoices_conv_tfm tfm
      WHERE  tfm.run_id = p_run_id
      --AND    tfm.line_type = 'LINE'
      AND    tfm.line_type in ( 'LINE', 'TAX', 'FREIGHT', 'CHARGES')
      AND    tfm.status = 'VALIDATED'
      AND    LINE_NUMBER IS NOT NULL;

   
   CURSOR c_int_dists IS
      SELECT 'GEN' INTERFACE_LINE_CONTEXT,
             g_batch_source INTERFACE_LINE_ATTRIBUTE1,
             DSDBI_TRX_NUMBER,
             LINE_NUMBER,
             DIST_LINE_TYPE,    
             DECODE(DIST_LINE_TYPE,'REC',NULL,DIST_AMOUNT) DIST_AMOUNT,-- ARDRUL02  
             CODE_COMBINATION_ID,
             SEGMENT1,
             SEGMENT2,
             SEGMENT3,
             SEGMENT4,
             SEGMENT5,
             SEGMENT6,
             SEGMENT7,
             DECODE(DIST_LINE_TYPE,'REC',100,NULL) percent,-- ARDRUL03
             CREATED_BY,
             CREATION_DATE
      FROM   xxar_open_invoices_conv_tfm
      WHERE  run_id = p_run_id
      AND    line_type = 'LINE' -- 09/06/207 Mark's Comment : I think that all that needs to be done to meet the new requirement is to only insert the Distribution interface lines for Line Type = LINE, i.e no longer do this for Tax and Rec.
      AND    status = 'VALIDATED';

   CURSOR c_int_rej IS
      SELECT record_id,
             DSDBI_TRX_NUMBER,
             line_number
      FROM   xxar_open_invoices_conv_tfm
      WHERE  run_id = p_run_id
      AND    status = 'REJECTED'
      ORDER  BY 2, 3;
    
   
  SUBTYPE int_lines_rec_type IS c_int_lines%ROWTYPE;
   TYPE    int_lines_tab_type IS TABLE OF int_lines_rec_type INDEX BY binary_integer;
  
  SUBTYPE int_dists_rec_type IS c_int_dists%ROWTYPE;
   TYPE    int_dists_tab_type IS TABLE OF int_dists_rec_type INDEX BY binary_integer;

   t_int_lines         c_int_lines%ROWTYPE;
   t_int_dists         c_int_dists%ROWTYPE;
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
   
   v_orig_sys_bill_customer_ref ra_interface_lines_all.orig_system_bill_customer_ref%TYPE := NULL;
   v_orig_sys_sold_customer_ref ra_interface_lines_all.orig_system_sold_customer_ref%TYPE := NULL;
   v_orig_sys_bill_address_ref ra_interface_lines_all.orig_system_bill_address_ref%TYPE := NULL;
   v_interface_line_attribute3 ra_interface_distributions_all.interface_line_attribute3%TYPE := NULL;

BEGIN
   IF NOT p_transform_phase THEN
      l_load_status := 'ERROR';
      load_status := FALSE;
      GOTO update_run_phase;
   END IF;

   print_debug('load process initiated');

   SELECT COUNT(1)
   INTO   l_record_count
   FROM   xxar_open_invoices_conv_tfm
   WHERE  run_id = p_run_id;

   /* Update Run Phase */
   dot_common_int_pkg.update_run_phase
      (p_run_phase_id => p_run_phase_id,
       p_src_code     => g_src_code,
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

      DELETE FROM ra_interface_distributions_all
      WHERE  interface_status IS NULL
      AND    interface_line_context = g_autoinv_grouping
      AND    interface_line_attribute1 = g_batch_source;

      print_debug('insert tfm data to interface tables');

      -- Interface Table: Header and Lines

      OPEN c_int_lines;
      LOOP
         FETCH c_int_lines INTO t_int_lines ;
         EXIT WHEN c_int_lines%NOTFOUND;        
         
         INSERT INTO ra_interface_lines_all
                (
                 amount,                       
                 attribute14,                  
                 attribute15,                  
                 batch_source_name,            
                 comments,                     
                 conversion_date,              
                 conversion_rate,              
                 conversion_type,              
                 created_by,                   
                 creation_date,                
                 currency_code,                
                 cust_trx_type_name,           
                 description,
                 gl_date,
                 header_attribute1,            
                 header_attribute2,            
                 header_attribute7,            
                 header_attribute8,            
                 interface_line_context,
                 interface_line_attribute1,    
                 interface_line_attribute2,    
                 interface_line_attribute3,    
                 last_update_date,             
                 last_updated_by,              
                 line_type,    
                 link_to_line_context,                 
                 link_to_line_attribute1,      
                 link_to_line_attribute2,      
                 link_to_line_attribute3,      
                 org_id,                       
                 orig_system_bill_address_ref, 
                 orig_system_bill_customer_ref,
                 orig_system_sold_customer_ref,
                 printing_option,              
                 purchase_order,               
                 quantity,                     
                 sales_order,                  
                 set_of_books_id,              
                 tax_code,                     
                 term_name,                    
                 trx_date,                     
                 trx_number,                   
                 unit_selling_price,
                 amount_includes_tax_flag
                 )                
         VALUES (
                 t_int_lines.line_amount,                       
                 t_int_lines.period_of_service_from,                  
                 t_int_lines.period_of_service_to ,                  
                 g_batch_source,--'takeon' ,            
                 t_int_lines.comments,                     
                 SYSDATE ,              
                 1 ,              
                 'User' ,              
                 t_int_lines.created_by,                   
                 t_int_lines.creation_date,                
                 'AUD' ,                
                 t_int_lines.oracle_trx_type ,           
                 t_int_lines.line_description,
                 NULL, -- ARLRUL04 : GL Date Should be null                 
                 t_int_lines.customer_contact_name ,            
                 t_int_lines.internal_contact_name ,            
                 t_int_lines.dsdbi_crn ,            
                 t_int_lines.invoice_email ,            
                 'GEN' ,  
                 g_batch_source,--'takeon' ,    
                 t_int_lines.dsdbi_trx_number ,    
                 t_int_lines.interface_line_attribute3 ,    
                 t_int_lines.creation_date,             
                 t_int_lines.created_by,              
                 t_int_lines.line_type,  
                 t_int_lines.link_to_line_context,                  
                 t_int_lines.link_to_line_attribute1,      
                 t_int_lines.link_to_line_attribute2,      
                 t_int_lines.link_to_line_attribute3,      
                 g_org_id,--101 ,                       
                 t_int_lines.orig_system_bill_address_ref,--t_int_lines.dsdbi_customer_site_number , 
                 t_int_lines.orig_system_bill_customer_ref,
                 t_int_lines.orig_system_sold_customer_ref,
                 t_int_lines.printing_option ,              
                 t_int_lines.po_number,               
                 t_int_lines.line_quantity,                     
                 t_int_lines.sales_order,                  
                 g_sob_id,              
                 t_int_lines.tax_code,                     
                 t_int_lines.term_name,                    
                 t_int_lines.trx_date,                     
                 t_int_lines.dsdbi_trx_number ,                   
                 t_int_lines.unit_selling_price,
                 t_int_lines.amount_includes_tax_flag
                );
      END LOOP;
      CLOSE c_int_lines;

      -- Interface Table: Sales Credits

      
      -- Interface Table: Distributions

      OPEN c_int_dists;
      LOOP
         FETCH c_int_dists INTO t_int_dists;
         EXIT WHEN c_int_dists%NOTFOUND;
         -- ARDRUL01 
         IF t_int_dists.DIST_LINE_TYPE = 'REC' THEN
               SELECT MIN(line_number)
               INTO V_INTERFACE_LINE_ATTRIBUTE3
               FROM fmsmgr.xxar_open_invoices_conv_tfm
               WHERE LINE_TYPE = 'LINE'
               AND dsdbi_trx_number =  t_int_dists.DSDBI_TRX_NUMBER;
         ELSIF t_int_dists.DIST_LINE_TYPE = 'TAX' THEN
            V_INTERFACE_LINE_ATTRIBUTE3 := t_int_dists.LINE_NUMBER||'T';	
         ELSE
            V_INTERFACE_LINE_ATTRIBUTE3 := t_int_dists.LINE_NUMBER;
         END IF;
         
         INSERT INTO ra_interface_distributions_all
                (
                INTERFACE_LINE_CONTEXT,   
                INTERFACE_LINE_ATTRIBUTE1,
                INTERFACE_LINE_ATTRIBUTE2,
                INTERFACE_LINE_ATTRIBUTE3,
                ACCOUNT_CLASS,            
                AMOUNT,                   
                PERCENT,                  
                CODE_COMBINATION_ID,      
                SEGMENT1,                 
                SEGMENT2,                 
                SEGMENT3,                 
                SEGMENT4,                 
                SEGMENT5,                 
                SEGMENT6,                 
                SEGMENT7,                 
                CREATED_BY,               
                CREATION_DATE,            
                LAST_UPDATED_BY,          
                LAST_UPDATE_DATE,         
                ORG_ID
                )
         VALUES (
                 'GEN',
                 g_batch_source,
                 t_int_dists.DSDBI_TRX_NUMBER,
                 V_INTERFACE_LINE_ATTRIBUTE3,--t_int_dists.LINE_NUMBER,
                 t_int_dists.DIST_LINE_TYPE,
                 t_int_dists.DIST_AMOUNT,
                 t_int_dists.percent,
                 t_int_dists.CODE_COMBINATION_ID,      
                 t_int_dists.SEGMENT1,                 
                 t_int_dists.SEGMENT2,                 
                 t_int_dists.SEGMENT3,                 
                 t_int_dists.SEGMENT4,                 
                 t_int_dists.SEGMENT5,                 
                 t_int_dists.SEGMENT6,                 
                 t_int_dists.SEGMENT7,
                 t_int_dists.created_by,
                 t_int_dists.creation_date,
                 t_int_dists.created_by,
                 t_int_dists.creation_date,
                 g_org_id-- 101
                 );
      END LOOP;
      CLOSE c_int_dists;

      COMMIT;

      print_debug('insert tfm data to interface tables... completed');
      print_debug('ORG ID for RAXMTR '||g_org_id);
      print_debug('to_date g_gl_date for RAXMTR '||to_date(to_char(g_gl_date,'DD-MON-YYYY'),'DD-MON-YYYY'));

      l_req_id := fnd_request.submit_request(application => 'AR',
                                             program     => 'RAXMTR',
                                             description => NULL,
                                             start_time  => NULL,
                                             sub_request => FALSE,
                                             argument1   => 1,
                                             argument2   => g_batch_source_id,
                                             argument3   => g_batch_source,
                                             argument4   => fnd_date.date_to_canonical(g_gl_date),
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
                                             argument26  => NULL,
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
                  r_error.int_table_key_val1 := rej.DSDBI_TRX_NUMBER;
                  r_error.int_table_key_val2 := rej.line_number;
                  --r_error.int_table_key_val3 := rej.distribution_number;
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
          p_src_code     => g_src_code,
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

END xxar_open_invoices_conv_pkg;
/