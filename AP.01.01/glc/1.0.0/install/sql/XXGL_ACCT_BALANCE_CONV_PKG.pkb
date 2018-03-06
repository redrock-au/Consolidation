create or replace PACKAGE BODY xxgl_acct_balance_conv_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.01.01/glc/1.0.0/install/sql/XXGL_ACCT_BALANCE_CONV_PKG.pkb 2674 2017-10-05 01:02:16Z svnuser $*/
/****************************************************************************
**
** CEMLI ID: GL.00.02
**
** Description: DEDJTR GL Account Balances Conversion
**              Import Conversion Journal based on newly mapped COA
**
**
** Change History:
**
** Date        Who                  Comments
**
****************************************************************************/

TYPE prerun_error_tab_type IS TABLE OF VARCHAR2(640);

-- Interface Framework --
g_appl_short_name           VARCHAR2(10)   := 'GL';
g_debug                     VARCHAR2(30)   := 'DEBUG: ';
g_error                     VARCHAR2(30)   := 'ERROR: ';
g_staging_directory         VARCHAR2(30)   := 'WORKING';
g_src_code                  VARCHAR2(30)   := 'GL.00.02';
g_int_mode                  VARCHAR2(60)   := 'VALIDATE_TRANSFER';
g_stage                     VARCHAR2(30)   := 'STAGE';
g_transform                 VARCHAR2(30)   := 'TRANSFORM';
g_load                      VARCHAR2(30)   := 'LOAD';
g_reset_tfm_sql             VARCHAR2(1000) := 'TRUNCATE TABLE FMSMGR.XXGL_COA_DSDBI_BALANCES_TFM';
g_int_code                  dot_int_interfaces.int_code%TYPE := 'GL.00.02';
g_int_name                  dot_int_interfaces.int_name%TYPE := 'DEDJTR GL Account Balances Conversion';
g_user_je_category_name     gl_interface.user_je_category_name%TYPE := 'CONVERSION';
g_user_je_source_name       gl_interface.user_je_source_name%TYPE := 'DSDBI';

-- Defaulting Rules --
z_file_temp_dir             CONSTANT VARCHAR2(150)  := 'USER_TMP_DIR';
z_file_temp_path            CONSTANT VARCHAR2(150)  := '/usr/tmp';
z_file_write                CONSTANT VARCHAR2(1)    := 'w';

-- System Parameters --
g_user_id              fnd_user.user_id%TYPE;
g_login_id             NUMBER;
g_appl_id              fnd_application.application_id%TYPE;
g_user_name            fnd_user.user_name%TYPE;
g_interface_req_id     NUMBER;
g_debug_flag           VARCHAR2(2) := 'Y';
g_sob_id               gl_sets_of_books.set_of_books_id%TYPE;

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

-----------------------------------------------------
-- Procedure
--    RUN_IMPORT
-- Purpose
--    Main calling program for loading GL Balances
--    in to the target.
-----------------------------------------------------

PROCEDURE run_import
(
   p_errbuff            OUT  VARCHAR2,
   p_retcode            OUT  NUMBER,
   p_source             IN   VARCHAR2,
   p_file_name          IN   VARCHAR2,
   p_control_file       IN   VARCHAR2,
   p_int_mode           IN   VARCHAR2,
   p_draft              IN   VARCHAR2
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
   l_source              VARCHAR2(30) := UPPER(p_source);
   l_code                VARCHAR2(15);
   l_message             VARCHAR2(1000);
   l_delim               VARCHAR2(1) := '|';
   l_request_id          NUMBER;

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

   r_int                 c_int%ROWTYPE;
   t_prerun_errors       prerun_error_tab_type := prerun_error_tab_type();
   t_files               xxint_common_pkg.t_files_type;

BEGIN
   -- Global Variables
   g_debug_flag := 'Y';
   g_interface_req_id := fnd_global.conc_request_id;
   g_user_name := fnd_global.user_name;
   g_user_id := fnd_global.user_id;
   g_login_id := fnd_global.login_id;
   g_appl_id := fnd_global.resp_appl_id;
   g_int_mode := NVL(p_int_mode, g_int_mode);
   g_sob_id := fnd_profile.value('GL_SET_OF_BKS_ID');

   l_ctl := p_control_file;
   l_file := p_file_name;
   
   write_to_out := TRUE;

   print_debug('parameter: p_source=' || p_source);
   print_debug('parameter: p_file_name=' || l_file);
   print_debug('parameter: p_control_file=' || l_ctl);
   print_debug('parameter: p_int_mode=' || g_int_mode);
   print_debug('user_id=' || g_user_id);
   print_debug('login_id=' || g_login_id);
   print_debug('resp_appl_id=' || g_appl_id);
   print_debug('pre interface run validations...');

   xxint_common_pkg.g_object_type := 'JOURNALS';

   -- Interface Registry
   OPEN c_int;
   FETCH c_int INTO r_int;
   IF c_int%NOTFOUND THEN
      INSERT INTO dot_int_interfaces
      VALUES (dot_int_interfaces_s.NEXTVAL,
              g_int_code,
              g_int_name,
              'IN',
              'GL',
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
      print_debug('draft_mode=' || p_draft);
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
    
      IF p_draft = 'Y' THEN
         print_debug('Submit Journal Import after completing data verification.');
        
         print_output_draft(l_run_id,
                            l_run_transform_id,
                            l_request_id,
                            l_source,
                            l_file,
                            l_file_error,
                            l_delim,
                            write_to_out);
      ELSE
         print_debug('Progam will load data into GL_INTERFACE and run Journal Import ');

         load_phase := load(p_run_id => l_run_id,
                            p_run_phase_id => l_run_load_id,
                            p_file => l_file,
                            p_transform_phase => transform_phase,
                            p_request_id => l_request_id);
         /*
         print_output(l_run_id,
                      l_run_transform_id,
                      l_request_id,
                      l_source,
                      l_file,
                      l_file_error,
                      l_delim,
                      write_to_out);
         */
      END IF;
    
      l_run_report_id := dot_common_int_pkg.launch_run_report
                            (p_run_id => l_run_id,
                             p_notify_user => g_user_name);

      print_debug('run interface report (request_id=' || l_run_report_id || ')');
   END LOOP;

EXCEPTION
   WHEN interface_error THEN
      print_debug('pre interface run validations... failed');
      FOR i IN 1 .. t_prerun_errors.COUNT LOOP
         fnd_file.put_line(fnd_file.log, g_error || t_prerun_errors(i));
      END LOOP;
      p_retcode := 2;
END run_import;

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

      UPDATE xxgl_coa_dsdbi_balances_stg
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

      -- Update Run Phase
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => g_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      -- End Run Phase
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

      -- Update Run Phase
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => g_src_code,
          p_rec_count    => 0,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      -- End Run Phase
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

      -- Update Run Phase
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => g_src_code,
          p_rec_count    => 0,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      -- End Run Phase
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
--     rules involved to successfully load transactions.
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
             stg.name,
             stg.actual_flag,
             stg.period_name,
             stg.code_combination_id,
             stg.old_segment1,
             stg.old_segment2,
             stg.old_segment3,
             stg.old_segment4,
             stg.old_segment5,
             stg.close_balance_dr,
             stg.close_balance_cr,
             stg.currency_code,
             stg.status,
             stg.created_by,
             stg.creation_date,
             stg.last_updated_by,
             'Period : ' || stg.period_name || ' Entity: ' || stg.old_segment1 reference1,
             'Period : ' || stg.period_name reference2,
             'Period : ' || stg.period_name reference4,
             'Period : ' || stg.period_name reference5,
             'Period : ' || stg.period_name || '-DSDBI COA:' ||
                            stg.old_segment1 || '.' ||
                            stg.old_segment2 || '.' ||
                            stg.old_segment3 || '.' ||
                            stg.old_segment4 || '.' ||
                            stg.old_segment5 reference10
      FROM   xxgl_coa_dsdbi_balances_stg stg
      WHERE  stg.status = 'PROCESSED'
      AND    stg.run_id = p_run_id;
   
   l_record_count        NUMBER := 0;
   l_success_count       NUMBER := 0;
   l_error_count         NUMBER := 0;
   l_code                VARCHAR2(15);
   l_message             VARCHAR2(1000);
   l_error_message       VARCHAR2(2000);
   l_tfm_status          VARCHAR2(30) := 'SUCCESS';
   l_tfm_error           NUMBER := 0;
   l_run_report_id       NUMBER;
   r_stg                 c_stg%ROWTYPE;
   r_tfm                 xxgl_coa_dsdbi_balances_tfm%ROWTYPE;
   r_error               dot_int_run_phase_errors%ROWTYPE;
   
   l_target_seg1         gl_code_combinations.segment1%TYPE;
   l_target_seg2         gl_code_combinations.segment2%TYPE;
   l_target_seg3         gl_code_combinations.segment3%TYPE;
   l_target_seg4         gl_code_combinations.segment4%TYPE;
   l_target_seg5         gl_code_combinations.segment5%TYPE;
   l_target_seg6         gl_code_combinations.segment6%TYPE;
   l_target_seg7         gl_code_combinations.segment7%TYPE;
   l_new_ccid            gl_code_combinations.code_combination_id%TYPE; 

   transform_error       EXCEPTION;
   transform_status      BOOLEAN := TRUE;

   PROCEDURE error_token_init
   IS
   BEGIN
      r_error.error_token_val1 := NULL;
      r_error.error_token_val2 := NULL;
      r_error.error_token_val3 := NULL;
      r_error.error_token_val4 := NULL;
      r_error.error_token_val5 := NULL;
   END error_token_init;
   
   PROCEDURE check_unbalanced_segment 
   (
      p_run_id NUMBER
   ) 
   IS
      CURSOR c_check_balance IS
         SELECT new_segment1,
                reference1,
                reference2,
                reference4,
                reference5,
                SUM(NVL(close_balance_dr, 0)) sum_dr,
                SUM(NVL(close_balance_cr, 0)) sum_cr,
                SUM(NVL(close_balance_dr, 0))-SUM(NVL(close_balance_cr,0)) DR_CR_DIFF
         FROM   xxgl_coa_dsdbi_balances_tfm
         WHERE  run_id = p_run_id
         GROUP  BY 
                new_segment1,
                reference1,
                reference2,
                reference4,
                reference5
         HAVING SUM(NVL(close_balance_dr, 0)) - SUM(NVL(close_balance_cr, 0)) != 0;
      
      r_check_balance       c_check_balance%ROWTYPE;
   BEGIN
      print_debug('p_run_id = ' || p_run_id);
      OPEN c_check_balance;
      LOOP
         FETCH c_check_balance INTO r_check_balance;
         EXIT WHEN c_check_balance%NOTFOUND;

         UPDATE xxgl_coa_dsdbi_balances_tfm
         SET    status = 'ERROR'
         WHERE  new_segment1 = r_check_balance.new_segment1
         AND    reference1 = r_check_balance.reference1
         AND    reference2 = r_check_balance.reference2
         AND    reference4 = r_check_balance.reference4
         AND    reference5 = r_check_balance.reference5;

         l_tfm_error := l_tfm_error + 1;

         xxint_common_pkg.get_error_message(g_error_message_12, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text || l_error_message, '$new_segment1', r_check_balance.new_segment1);
         raise_error(r_error);      
      END LOOP;
     
      CLOSE c_check_balance;
   EXCEPTION 
      WHEN OTHERS THEN
         print_debug('c_check_balance'||SQLERRM);
   END check_unbalanced_segment;

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
   FROM   xxgl_coa_dsdbi_balances_stg
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
      
      r_error.run_id := p_run_id;
      r_error.run_phase_id := p_run_phase_id;
      r_error.record_id := r_stg.record_id;
      r_error.int_table_key_val1 := r_stg.code_combination_id;
      
      -- TFM Record
      r_tfm := NULL;
      r_tfm.record_id := r_stg.record_id;
      r_tfm.run_id := p_run_id;
      r_tfm.actual_flag := SUBSTR(r_stg.actual_flag, 1, 1);
      r_tfm.period_name := SUBSTR(r_stg.period_name, 1, 15);
      r_tfm.old_code_combination_id := SUBSTR(r_stg.code_combination_id, 1, 15);
      r_tfm.old_segment1 := r_stg.old_segment1;
      r_tfm.old_segment2 := r_stg.old_segment2;
      r_tfm.old_segment3 := r_stg.old_segment3;
      r_tfm.old_segment4 := r_stg.old_segment4;
      r_tfm.old_segment5 := r_stg.old_segment5;
      
      xxgl_import_coa_mapping_pkg.get_mapping
                (r_stg.old_segment1,
                 r_stg.old_segment2,
                 r_stg.old_segment3,
                 r_stg.old_segment4,
                 r_stg.old_segment5,
                 NULL,
                 l_target_seg1,
                 l_target_seg2,
                 l_target_seg3,
                 l_target_seg4,
                 l_target_seg5,
                 l_target_seg6,
                 l_target_seg7,
                 l_new_ccid,
                 l_error_message
                );
    
      IF l_error_message IS NOT NULL THEN
         l_tfm_error := l_tfm_error + 1;
         xxint_common_pkg.get_error_message(g_error_message_09, r_error.msg_code, r_error.error_text);
         r_error.error_text := REPLACE(r_error.error_text || l_error_message, '$RECORD_ID', r_stg.record_id);
         raise_error(r_error);
      END IF;
      
      -- Assign target account
      r_tfm.new_code_combination_id := l_new_ccid;
      r_tfm.new_segment1 := l_target_seg1;
      r_tfm.new_segment2 := l_target_seg2;
      r_tfm.new_segment3 := l_target_seg3;
      r_tfm.new_segment4 := l_target_seg4;
      r_tfm.new_segment5 := l_target_seg5;
      r_tfm.new_segment6 := l_target_seg6;
      r_tfm.new_segment7 := l_target_seg7;
      r_tfm.reference1 := r_stg.reference1;
      r_tfm.reference2 := r_stg.reference2;
      r_tfm.reference4 := r_stg.reference4;
      r_tfm.reference5 := r_stg.reference5;
      r_tfm.reference10 :=r_stg.reference10;
      r_tfm.close_balance_dr := r_stg.close_balance_dr;
      r_tfm.close_balance_cr := r_stg.close_balance_cr;
      r_tfm.currency_code := SUBSTR(r_stg.currency_code, 1, 5);
      r_tfm.created_by := g_user_id;
      r_tfm.creation_date := SYSDATE;
      r_tfm.last_updated_by := g_user_id;
      r_tfm.last_update_date := SYSDATE;
      r_tfm.group_id := p_run_id;

      IF l_tfm_error > 0 THEN
         r_tfm.status := 'ERROR';
      ELSE
         r_tfm.status := 'VALIDATED';
      END IF;

      INSERT INTO xxgl_coa_dsdbi_balances_tfm
      VALUES r_tfm;
   END LOOP;
   CLOSE c_stg;
   
   print_debug('Start check_unbalanced_segment. Run ID : ' || p_run_id);
   check_unbalanced_segment(p_run_id);
   print_debug('End check_unbalanced_segment. Run ID : ' || p_run_id);
         
   r_error.run_id := p_run_id;
   r_error.run_phase_id := p_run_phase_id;
   r_error.record_id := -1;

   SELECT SUM(DECODE(status, 'VALIDATED', 1, 0)),
          SUM(DECODE(status, 'ERROR', 1, 0))
   INTO   l_success_count,
          l_error_count
   FROM   xxgl_coa_dsdbi_balances_tfm
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

------------------------------------------------------------
-- Function
--     LOAD
-- Purpose
--     Interface Framework LOAD phase. This sub-process
--     loads validated account balances into GL_INTERFACE,
--     it automatically submits the standard Journal Import
--     program at the end of the load.
------------------------------------------------------------

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
   CURSOR c_int_journal IS
      SELECT 'NEW' status,
             currency_code,
             period_name,
             g_user_je_category_name user_je_category_name,
             g_user_je_source_name user_je_source_name,
             LAST_DAY(TO_DATE(period_name, 'MON-RRRR')) accounting_date,
             new_segment1,
             new_segment2,
             new_segment3,
             new_segment4,
             new_segment5,
             new_segment6,
             new_segment7,
             close_balance_dr entered_dr,
             close_balance_cr entered_cr,
             close_balance_dr accounted_dr,
             close_balance_cr accounted_cr,
             reference1,
             reference2,
             reference4,
             reference5,
             reference10,
             group_id
      FROM   xxgl_coa_dsdbi_balances_tfm tfm
      WHERE  tfm.run_id = p_run_id
      AND    tfm.status = 'VALIDATED';
   
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
   l_run_id            NUMBER := p_run_id;
   l_control_run_id    NUMBER;

BEGIN
   
   IF NOT p_transform_phase THEN
      l_load_status := 'ERROR';
      load_status := FALSE;
      GOTO update_run_phase;
   END IF;

   print_debug('load process initiated');

   SELECT COUNT(1)
   INTO   l_record_count
   FROM   xxgl_coa_dsdbi_balances_tfm
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

      DELETE FROM gl_interface
      WHERE  user_je_source_name = 'DSDBI'
      AND    user_je_category_name = 'CONVERSION'
      AND    set_of_books_id = g_sob_id;

      print_debug('insert tfm data to interface tables');

      FOR r_int_journal IN c_int_journal LOOP
         INSERT INTO gl_interface
                (status,
                 set_of_books_id,
                 period_name,
                 accounting_date,
                 currency_code,
                 date_created,
                 created_by,
                 actual_flag,
                 user_je_category_name,
                 user_je_source_name,
                 segment1,
                 segment2,
                 segment3,
                 segment4,
                 segment5,
                 segment6,
                 segment7,
                 entered_dr,
                 entered_cr,
                 accounted_dr,
                 accounted_cr,
                 reference1,
                 reference2,
                 reference4,
                 reference5,
                 reference10,
                 group_id)
         VALUES (r_int_journal.status,
                 g_sob_id,
                 r_int_journal.period_name,
                 r_int_journal.accounting_date,
                 r_int_journal.currency_code,
                 sysdate,
                 g_user_id,
                 'A',
                 r_int_journal.user_je_category_name,
                 r_int_journal.user_je_source_name,
                 r_int_journal.new_segment1,
                 r_int_journal.new_segment2,
                 r_int_journal.new_segment3,
                 r_int_journal.new_segment4,
                 r_int_journal.new_segment5,
                 r_int_journal.new_segment6,
                 r_int_journal.new_segment7,
                 r_int_journal.entered_dr,
                 r_int_journal.entered_cr,
                 r_int_journal.accounted_dr,
                 r_int_journal.accounted_cr,
                 r_int_journal.reference1,
                 r_int_journal.reference2,
                 r_int_journal.reference4,
                 r_int_journal.reference5,
                 r_int_journal.reference10,
                 r_int_journal.group_id);
      END LOOP;
      
      COMMIT;
      
      print_debug('insert tfm data to interface tables... completed');

      gl_journal_import_pkg.populate_interface_control(user_je_source_name =>g_user_je_source_name,
                                                       group_id => l_run_id,
                                                       set_of_books_id => g_sob_id,
                                                       interface_run_id => l_control_run_id,
                                                       processed_data_action => gl_journal_import_pkg.SAVE_DATA);
      
      print_debug('Populate interface control... completed');                                                          

      l_req_id := fnd_request.submit_request (application => 'SQLGL',
                                              program => 'GLLEZL',
                                              description => NULL,
                                              start_time => NULL,
                                              sub_request => FALSE,
                                              argument1 => l_control_run_id,
                                              argument2 => g_sob_id,
                                              argument3 => 'N',
                                              argument4 => NULL,
                                              argument5 => NULL,
                                              argument6 => 'N',
                                              argument7 => 'N');
                                                                   
      COMMIT;
      
      print_debug('control_run_id=' || l_control_run_id);
      print_debug('submit GL IMPORT Program (request_id=' || l_req_id || ')');

      wait_for_request(l_req_id, 30);

      r_error.run_id := p_run_id;
      r_error.run_phase_id := p_run_phase_id;
      r_error.record_id := -1;
      r_error.int_table_key_val1 := -1;
      r_error.int_table_key_val2 := -1;
      r_error.int_table_key_val3 := -1;

      IF NOT (srs_dev_phase = 'COMPLETE' AND
             (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
         xxint_common_pkg.get_error_message(g_error_message_08, l_code, l_message);
         r_request.error_message := l_message;
         r_request.status := 'ERROR';
         r_error.error_text := l_message;
         raise_error(r_error);
      ELSE
         p_request_id := l_req_id;
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
   CURSOR c_results IS
      SELECT *
      FROM   xxgl_coa_dsdbi_balances_tfm;

   l_file              VARCHAR2(150);
   l_outbound_path     VARCHAR2(150);
   l_text              VARCHAR2(32767);
   l_message           VARCHAR2(4000);
   r_results           c_results%ROWTYPE;
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

   OPEN c_results;
   LOOP
      FETCH c_results INTO r_results;
      EXIT WHEN c_results%NOTFOUND;

      l_text := NULL;

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
   CLOSE c_results;

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

-----------------------------------------------
-- Procedure
--    PRINT_OUTPUT_DRAFT
-- Purpose
--    Print output for draft option.
-----------------------------------------------

PROCEDURE print_output_draft
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
   CURSOR c_results IS
      SELECT status,
             period_name,
             actual_flag,
             old_segment1 || '-' || 
             old_segment2 || '-' ||
             old_segment3 || '-' ||
             old_segment4 || '-' ||
             old_segment5 old_code_combination,
             old_code_combination_id,
             new_code_combination_id,
             new_segment1 || '-' ||
             new_segment2 || '-' ||
             new_segment3 || '-' ||
             new_segment4 || '-' ||
             new_segment5 || '-' ||
             new_segment6 || '-' ||
             new_segment7 new_code_combination,
             close_balance_dr,
             close_balance_cr,
             currency_code,
             record_id
      FROM   xxgl_coa_dsdbi_balances_tfm
      WHERE  run_id = p_run_id;

   l_file              VARCHAR2(150);
   l_outbound_path     VARCHAR2(150);
   l_text              VARCHAR2(32767);
   l_message           VARCHAR2(4000);
   r_results           c_results%ROWTYPE;
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
   fnd_file.put_line(fnd_file.output,'Status|Period Name|Actual Flag|Old Code Combination ID|Old Code Combination|New Code Combination ID|New Code Combination|DR Amount|CR Amount|');
   OPEN c_results;
   LOOP
      FETCH c_results INTO r_results;
      EXIT WHEN c_results%NOTFOUND;

      l_message := NULL;
      IF r_results.status = 'ERROR' AND r_results.record_id IS NOT NULL THEN
         xxint_common_pkg.get_error_message(p_run_id, p_run_phase_id, r_results.record_id, '-', l_message);
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
      l_text := l_text || r_results.STATUS || p_delim;
      l_text := l_text || r_results.period_name || p_delim;
      l_text := l_text || r_results.actual_flag || p_delim;
      l_text := l_text || r_results.old_code_combination_id || p_delim;
      l_text := l_text || r_results.OLD_code_combination || p_delim;
      l_text := l_text || r_results.NEW_code_combination_ID || p_delim;
      l_text := l_text || r_results.NEW_code_combination || p_delim;
      l_text := l_text || r_results.close_balance_dr || p_delim;
      l_text := l_text || r_results.close_balance_cr || p_delim;
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
   CLOSE c_results;

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

END print_output_draft;

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
                         p_int_table_key_col1      => 'CODE_COMBINATION_ID ',
                         p_int_table_key_col_desc1 => 'Code Combination ID',
                         p_int_table_key_col2      => 'DISTRIBUTION  ',
                         p_int_table_key_col_desc2 => 'Concatenated Code Combinations',
                         p_int_table_key_col3      => '',
                         p_int_table_key_col_desc3 => '');

   -- Transform
   p_run_transform_id := dot_common_int_pkg.start_run_phase
                            (p_run_id                  => p_run_id,
                             p_phase_code              => g_transform,
                             p_phase_mode              => g_int_mode,
                             p_int_table_name          => 'XXGL_COA_DSDBI_BALANCES_STG',
                             p_int_table_key_col1      => 'CODE_COMBINATION_ID ',
                             p_int_table_key_col_desc1 => 'Code Combination ID',
                             p_int_table_key_col2      => '',
                             p_int_table_key_col_desc2 => '',
                             p_int_table_key_col3      => '',
                             p_int_table_key_col_desc3 => '');

   -- Load
   p_run_load_id := dot_common_int_pkg.start_run_phase
                       (p_run_id                  => p_run_id,
                        p_phase_code              => g_load,
                        p_phase_mode              => g_int_mode,
                        p_int_table_name          => 'XXGL_COA_DSDBI_BALANCES_TFM',
                        p_int_table_key_col1      => 'OLD_CODE_COMBINATION_ID',
                        p_int_table_key_col_desc1 => 'Old Code Combination ID',
                        p_int_table_key_col2      => 'OLD_CODE_COMBINATION',
                        p_int_table_key_col_desc2 => 'Concatenated DSDBI Code Combinations',
                        p_int_table_key_col3      => '',
                        p_int_table_key_col_desc3 => '');

END initialize;

END xxgl_acct_balance_conv_pkg;
/
