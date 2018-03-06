CREATE OR REPLACE PACKAGE BODY xxar_open_items_interface_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.04/arc/1.0.0/install/sql/XXAR_OPEN_ITEMS_INTERFACE_PKG.pkb 2485 2017-09-07 07:50:08Z dart $ */

/****************************************************************************
**
** CEMLI ID: AR.02.04
**
** Description: Data import program for Open Items coming from an external
**              system.
**
** Change History:
**
** Date        Who                  Comments
** 18/04/2017  ARELLAD (RED ROCK)   Initial build.
**
****************************************************************************/

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

------------------------------------------------------
-- Procedure
--     PRINT_DEBUG
-- Purpose
--     Print debug log to FND_FILE.LOG 
------------------------------------------------------

PROCEDURE print_debug
(
   p_text   VARCHAR2
)
IS
BEGIN
   IF g_debug_flag = 'Y' THEN
      fnd_file.put_line(fnd_file.log, g_debug || p_text);
   END IF;
END print_debug;

-------------------------------------------------------
-- Function
--    GET_OBJECT_VERSION
-- Purpose
--    Object Version ID aids in tracing history
--    of a transaction record. Since effectivity of a
--    transaction depends on the period from the time
--    it was issued, validity becomes a question if 
--    system is not able to track this hence version
--    added as a reference.
-------------------------------------------------------

FUNCTION get_object_version
(
   p_crn_number  VARCHAR2
)
RETURN NUMBER
IS
   l_retval   NUMBER;

   CURSOR c_obj IS
      SELECT MAX(object_version_id)
      FROM   xxar_payment_notices_b
      WHERE  crn_number = p_crn_number;
BEGIN
   OPEN c_obj;
   FETCH c_obj INTO l_retval;
   CLOSE c_obj;

   l_retval := NVL(l_retval, 0) + 1;

   RETURN l_retval;
END get_object_version;

----------------------------------------------------------
-- Procedure
--     OPEN_ITEMS_IMPORT
-- Purpose
--     Main program that imports data from an external
--     source.
----------------------------------------------------------

PROCEDURE open_items_import
(
   p_errbuff          OUT  VARCHAR2,
   p_retcode          OUT  NUMBER,
   p_source           IN   VARCHAR2,
   p_file_name        IN   VARCHAR2,
   p_control_file     IN   VARCHAR2,
   p_archive_flag     IN   VARCHAR2,
   p_debug_flag       IN   VARCHAR2,
   p_int_mode         IN   VARCHAR2
)
IS
   CURSOR c_int IS
      SELECT int_id,
             int_code,
             enabled_flag
      FROM   dot_int_interfaces
      WHERE  int_code = z_int_code;

   CURSOR c_stg (p_run_id NUMBER) IS
      SELECT *
      FROM   xxar_open_items_stg
      WHERE  run_id = p_run_id;

   l_user_name           VARCHAR2(60);
   l_user_id             NUMBER;
   l_login_id            NUMBER;
   l_appl_id             NUMBER;
   l_interface_req_id    NUMBER;
   l_file                VARCHAR2(150);
   l_file_req_id         NUMBER;
   l_text                VARCHAR2(32767);
   l_sqlldr_req_id       NUMBER;
   l_record_count        NUMBER;
   l_success_count       NUMBER := 0;
   l_error_count         NUMBER := 0;
   l_inbound_directory   VARCHAR2(150);
   l_outbound_directory  VARCHAR2(150);
   l_staging_directory   VARCHAR2(150);
   l_archive_directory   VARCHAR2(150);
   l_log                 VARCHAR2(150);
   l_bad                 VARCHAR2(150);
   l_ctl                 VARCHAR2(150);
   l_tfm_mode            VARCHAR2(60);
   l_tfm_error           NUMBER;
   l_int_status          VARCHAR2(25);
   l_dup                 NUMBER;
   l_message             VARCHAR2(1000);
   l_convert_temp        VARCHAR2(500);
   x_message             VARCHAR2(1000);
   x_status              VARCHAR2(1);

   r_int                 c_int%ROWTYPE;
   r_stg                 c_stg%ROWTYPE;
   r_error               dot_int_run_phase_errors%ROWTYPE;
   r_tfm                 xxar_open_items_tfm%ROWTYPE;
   r_request             xxint_common_pkg.control_record_type;
   t_files               xxint_common_pkg.t_files_type;

   -- SRS
   srs_wait              BOOLEAN;
   srs_phase             VARCHAR2(30);
   srs_status            VARCHAR2(30);
   srs_dev_phase         VARCHAR2(30);
   srs_dev_status        VARCHAR2(30);
   srs_message           VARCHAR2(240);

   -- Interface Framework
   l_run_id              NUMBER;
   l_run_phase_id        NUMBER;
   l_run_report_id       NUMBER;
   l_run_error           NUMBER := 0;

   interface_error       EXCEPTION;
   number_error          EXCEPTION;
   pragma                EXCEPTION_INIT(number_error, -6502);

   PROCEDURE wait_for_request
   (
      p_request_id_x   NUMBER,
      p_wait_time      NUMBER
   )
   IS
   BEGIN
      srs_wait := fnd_concurrent.wait_for_request(p_request_id_x,
                                                  p_wait_time,
                                                  0,
                                                  srs_phase,
                                                  srs_status,
                                                  srs_dev_phase,
                                                  srs_dev_status,
                                                  srs_message);
   END wait_for_request;

BEGIN
   xxint_common_pkg.g_object_type := 'RENEWALS';
   l_tfm_mode := NVL(p_int_mode, g_int_mode);
   l_ctl := NVL(p_control_file, g_ctl);
   l_user_name := fnd_profile.value('USERNAME');
   l_user_id := fnd_profile.value('USER_ID');
   l_login_id := fnd_profile.value('LOGIN_ID');
   l_appl_id := fnd_global.resp_appl_id;
   l_interface_req_id := fnd_global.conc_request_id;
   l_file := NVL(p_file_name, p_source || g_file);

   g_debug_flag := NVL(p_debug_flag, 'N');
   g_source_directory := NVL(p_source, g_source_directory);

   fnd_file.put_line(fnd_file.log, 'DEBUG_FLAG=' || NVL(p_debug_flag, 'N'));

   /* Debug Log */
   print_debug('procedure name ' || g_procedure_name || '.');

   /* Debug Log */
   print_debug('check interface registry for ' || z_int_code || '.');

   /* Interface Registry */
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
              l_user_id,
              l_user_id,
              SYSDATE,
              l_login_id,
              l_interface_req_id);

      COMMIT;
   ELSE
      IF NVL(r_int.enabled_flag, 'N') = 'N' THEN
         fnd_file.put_line(fnd_file.log, g_error || REPLACE(SUBSTR(g_error_message_01, 11, 100), '$INT_CODE', z_int_code));
         p_retcode := 2;
         RETURN;
      END IF;
   END IF;
   CLOSE c_int;

   /* Debug Log */
   print_debug('retrieving interface directory information');

   l_inbound_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                          p_source => g_source_directory,
                                                          p_message => x_message);
   IF x_message IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log, g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_outbound_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                           p_source => g_source_directory,
                                                           p_in_out => 'OUTBOUND',
                                                           p_message => x_message);
   IF x_message IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log, g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_staging_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                          p_source => g_source_directory,
                                                          p_in_out => g_staging_directory,
                                                          p_message => x_message);
   IF x_message IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log, g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_archive_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                          p_source => g_source_directory,
                                                          p_archive => 'Y',
                                                          p_message => x_message);
   IF x_message IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log, g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   /* Debug Log */
   print_debug('p_source=' || p_source);
   print_debug('p_file_name=' || l_file);
   print_debug('p_control_file=' || l_ctl);
   print_debug('p_archive_flag=' || NVL(p_archive_flag, 'N'));
   print_debug('l_inbound_directory=' || l_inbound_directory);
   print_debug('l_outbound_directory=' || l_outbound_directory);
   print_debug('l_staging_directory=' || l_staging_directory);
   print_debug('l_archive_directory=' || l_archive_directory);

   IF (p_source IS NOT NULL) AND
      (INSTR(l_file, p_source) = 0) AND
      (INSTR(l_file, '*') > 0) THEN
      fnd_file.put_line(fnd_file.log, g_error || 'unable to resolve source and file to process');
      p_retcode := 2;
      RETURN;
   END IF;

   l_file_req_id := fnd_request.submit_request(application => 'FNDC',
                                               program     => 'XXINTIFR',
                                               description => NULL,
                                               start_time  => NULL,
                                               sub_request => FALSE,
                                               argument1   => l_interface_req_id,
                                               argument2   => l_inbound_directory,
                                               argument3   => l_file,
                                               argument4   => l_appl_id);
   COMMIT;

   /* Debug Log */
   print_debug('fetching file ' || l_file || ' from ' || l_inbound_directory || ' (request_id=' || l_file_req_id || ')');

   wait_for_request(l_file_req_id, 5);
   r_request := NULL;

   IF NOT (srs_dev_phase = 'COMPLETE' AND
          (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
      l_run_error := l_run_error + 1;
      l_message := REPLACE(SUBSTR(g_error_message_02, 11, 100), '$INT_DIR', l_inbound_directory);
      fnd_file.put_line(fnd_file.log, g_error || l_message);

      r_request.error_message := l_message;
      r_request.status := 'ERROR';

   ELSE
      r_request.status := 'SUCCESS';

      SELECT file_name BULK COLLECT
      INTO   t_files
      FROM   xxint_interface_ctl
      WHERE  interface_request_id = l_interface_req_id
      AND    sub_request_id = l_file_req_id
      AND    file_name IS NOT NULL;
   END IF;

   /* Interface control record */
   r_request.application_id := l_appl_id;
   r_request.interface_request_id := l_interface_req_id;
   r_request.sub_request_id := l_file_req_id;
   xxint_common_pkg.interface_request(r_request);

   IF l_run_error > 0 THEN
      fnd_file.put_line(fnd_file.log, g_error || l_message);
      p_retcode := 2;
      RETURN;
   END IF;

   IF t_files.COUNT = 0 THEN
      fnd_file.put_line(fnd_file.log, g_error || 'File not found');
      p_retcode := 2;
      RETURN;
   END IF;

   FOR i IN 1 .. t_files.COUNT LOOP
      l_file := REPLACE(t_files(i), l_inbound_directory || '/');
      l_log  := REPLACE(l_file, 'txt', 'log');
      l_bad  := REPLACE(l_file, 'txt', 'bad');

      /* Initialize Interface Run */
      l_run_id := dot_common_int_pkg.initialise_run
                     (p_int_code       => z_int_code,
                      p_src_rec_count  => NULL,
                      p_src_hash_total => NULL,
                      p_src_batch_name => l_file);

      /* Debug Log */
      print_debug('interface framework (run_id=' || l_run_id || ')');

      ------------------------------------------------------------------------------------------------
      ------------------------------------ STAGE PHASE START -----------------------------------------
      ------------------------------------------------------------------------------------------------

      l_run_phase_id := dot_common_int_pkg.start_run_phase
                           (p_run_id                  => l_run_id,
                            p_phase_code              => z_stage,
                            p_phase_mode              => NULL,
                            p_int_table_name          => l_file,
                            p_int_table_key_col1      => 'CRN_NUMBER',
                            p_int_table_key_col_desc1 => 'CRN Number',
                            p_int_table_key_col2      => NULL,
                            p_int_table_key_col_desc2 => NULL,
                            p_int_table_key_col3      => NULL,
                            p_int_table_key_col_desc3 => NULL);

      /* Debug Log */
      print_debug('interface framework (run_stage_id=' || l_run_phase_id || ')');

      l_sqlldr_req_id := fnd_request.submit_request(application => 'FNDC',
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
                                                    argument8   => l_ctl);
      COMMIT;

      /* Debug Log */
      print_debug('load file ' || l_file || ' to staging (request_id=' || l_sqlldr_req_id || ')');

      wait_for_request(l_sqlldr_req_id, 5);
      r_request := NULL;
      l_success_count := 0;
      l_error_count := 0;

      IF NOT (srs_dev_phase = 'COMPLETE' AND
             (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
         l_run_error := l_run_error + 1;
         l_message := REPLACE(SUBSTR(g_error_message_03, 11, 100), '$INT_FILE', l_file);
         fnd_file.put_line(fnd_file.log, g_error || l_message);

         r_request.error_message := l_message;
         r_request.status := 'ERROR';

      ELSE
         r_request.status := 'SUCCESS';

         UPDATE xxar_open_items_stg
         SET    run_id = l_run_id,
                run_phase_id = l_run_phase_id,
                status = 'PROCESSED',
                created_by = l_user_id,
                creation_date = SYSDATE;

         SELECT COUNT(1)
         INTO   l_record_count
         FROM   xxar_open_items_stg
         WHERE  run_id = l_run_id
         AND    run_phase_id = l_run_phase_id;

         IF sql%FOUND THEN
            l_success_count := l_record_count;
            COMMIT;
         END IF;
      END IF;

      /* Interface control record */
      r_request.application_id := l_appl_id;
      r_request.interface_request_id := l_interface_req_id;
      r_request.file_name := t_files(i);
      r_request.sub_request_id := l_sqlldr_req_id;
      xxint_common_pkg.interface_request(r_request);

      /* Debug Log */
      print_debug('file staging (status=' || r_request.status || ')');

      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => l_run_phase_id,
          p_src_code     => z_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      dot_common_int_pkg.end_run_phase
         (p_run_phase_id => l_run_phase_id,
          p_status => r_request.status,
          p_error_count => l_error_count,
          p_success_count => l_success_count);

      ----------------------------------------------------------------------------------------------
      ----------------------------------- STAGE PHASE END ------------------------------------------
      ----------------------------------------------------------------------------------------------

      IF l_run_error > 0 THEN
         RAISE interface_error;
      END IF;

      /* Debug Log */
      print_debug('executing transformation and validation');

      ----------------------------------------------------------------------------------------------
      ---------------------------------- TRANSFORM PHASE START -------------------------------------
      ----------------------------------------------------------------------------------------------

      l_run_phase_id := dot_common_int_pkg.start_run_phase
                           (p_run_id                  => l_run_id,
                            p_phase_code              => z_transform,
                            p_phase_mode              => g_int_mode,
                            p_int_table_name          => 'XXAR_OPEN_ITEMS_STG',
                            p_int_table_key_col1      => 'CRN_NUMBER',
                            p_int_table_key_col_desc1 => 'CRN Number',
                            p_int_table_key_col2      => NULL,
                            p_int_table_key_col_desc2 => NULL,
                            p_int_table_key_col3      => NULL,
                            p_int_table_key_col_desc3 => NULL);

      /* Debug Log */
      print_debug('interface framework (run_transform_id=' || l_run_phase_id || ')');
      print_debug('reset transformation table');

      EXECUTE IMMEDIATE g_reset_tfm_sql;
      l_success_count := 0;
      l_error_count := 0;
      l_int_status := 'SUCCESS';

      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => l_run_phase_id,
          p_src_code     => z_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      OPEN c_stg(l_run_id);
      LOOP
         FETCH c_stg INTO r_stg;
         EXIT WHEN c_stg%NOTFOUND;

         l_tfm_error := 0;
         l_text := NULL;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := r_stg.record_id;
         r_error.int_table_key_val1 := NVL(r_stg.crn_number, 'NULL');

         l_text := TRIM(r_stg.crn_number) || 
                   TRIM(r_stg.orig_amt1) ||
                   TRIM(r_stg.orig_amt2) ||
                   TRIM(r_stg.orig_amt3) ||
                   TRIM(r_stg.orig_amt4);

         IF l_text IS NULL THEN
            GOTO next_line;
         END IF;

         -- Transform
         r_tfm := NULL;
         r_tfm.record_id := r_stg.record_id;
         r_tfm.run_id := l_run_id;
         r_tfm.run_phase_id := l_run_phase_id;

         r_error.error_token_val1 := 'CRN_NUMBER';
         r_tfm.crn_number := SUBSTR(r_stg.crn_number, 1, 12);
         IF LENGTH(r_stg.crn_number) = 11 THEN
            r_tfm.crn_number := xxar_invoices_interface_pkg.generate_crn('', r_stg.crn_number, x_status, x_message);
            IF x_status = 'E' THEN
               l_tfm_error := l_tfm_error + 1;
               r_error.msg_code := NULL;
               r_error.error_text := x_message;
               raise_error(r_error);
            END IF;
         ELSE
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_04, r_error.msg_code, r_error.error_text);
            raise_error(r_error);
         END IF;

         SELECT COUNT(1)
         INTO   l_dup
         FROM   xxar_open_items_stg
         WHERE  run_id = l_run_id
         AND    crn_number IS NOT NULL
         AND    crn_number = r_stg.crn_number;

         IF l_dup > 1 THEN
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_05, r_error.msg_code, r_error.error_text);
            raise_error(r_error);
         END IF;

         IF NVL(p_archive_flag, 'N') = 'N' THEN
            SELECT COUNT(1)
            INTO   l_dup
            FROM   xxar_payment_notices_b
            WHERE  crn_number = r_tfm.crn_number
            AND    NVL(archive_flag, 'N') = 'N';

            IF l_dup > 0 THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_06, r_error.msg_code, r_error.error_text);
               raise_error(r_error);
            END IF;
         END IF;

         r_error.error_token_val1 := 'ORIG_AMT1';
         BEGIN
            l_convert_temp := xxint_common_pkg.strip_value(r_stg.orig_amt1);
            r_tfm.orig_amt1 := ROUND(TO_NUMBER(l_convert_temp), 2);
         EXCEPTION
            WHEN number_error THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_07, r_error.msg_code, l_message);
               r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
               raise_error(r_error);
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               r_error.msg_code := REPLACE(SQLCODE, '-');
               r_error.error_text := r_stg.orig_amt1 || ' ' || SQLERRM;
               raise_error(r_error);
         END;

         r_error.error_token_val1 := 'ORIG_AMT2';
         BEGIN
            l_convert_temp := xxint_common_pkg.strip_value(r_stg.orig_amt2);
            r_tfm.orig_amt2 := ROUND(TO_NUMBER(l_convert_temp), 2);
         EXCEPTION
            WHEN number_error THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_07, r_error.msg_code, l_message);
               r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
               raise_error(r_error);
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               r_error.msg_code := REPLACE(SQLCODE, '-');
               r_error.error_text := SQLERRM;
               raise_error(r_error);
         END;

         r_error.error_token_val1 := 'ORIG_AMT3';
         BEGIN
            l_convert_temp := xxint_common_pkg.strip_value(r_stg.orig_amt3);
            r_tfm.orig_amt3 := ROUND(TO_NUMBER(l_convert_temp), 2);
         EXCEPTION
            WHEN number_error THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_07, r_error.msg_code, l_message);
               r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
               raise_error(r_error);
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               r_error.msg_code := REPLACE(SQLCODE, '-');
               r_error.error_text := SQLERRM;
               raise_error(r_error);
         END;

         r_error.error_token_val1 := 'ORIG_AMT4';
         BEGIN
            l_convert_temp := xxint_common_pkg.strip_value(r_stg.orig_amt4);
            r_tfm.orig_amt4 := ROUND(TO_NUMBER(l_convert_temp), 2);
         EXCEPTION
            WHEN number_error THEN
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_07, r_error.msg_code, l_message);
               r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
               raise_error(r_error);
            WHEN others THEN
               l_tfm_error := l_tfm_error + 1;
               r_error.msg_code := REPLACE(SQLCODE, '-');
               r_error.error_text := SQLERRM;
               raise_error(r_error);
         END;

         IF l_tfm_error > 0 THEN
            l_error_count := l_error_count + 1;
            r_tfm.status := 'ERROR';
         ELSE
            l_success_count := l_success_count + 1;
            r_tfm.object_version_id := get_object_version(r_tfm.crn_number);
            r_tfm.status := 'PROCESSED';
         END IF;

         r_tfm.created_by := l_user_id;
         r_tfm.creation_date := SYSDATE;

         INSERT INTO xxar_open_items_tfm
         VALUES r_tfm;

         <<next_line>>
         NULL;
      END LOOP;
      CLOSE c_stg;

      COMMIT;

      IF l_error_count > 0 THEN
         l_int_status := 'ERROR';
      END IF;

      dot_common_int_pkg.end_run_phase
         (p_run_phase_id => l_run_phase_id,
          p_status => l_int_status,
          p_error_count => l_error_count,
          p_success_count => l_success_count);

      ----------------------------------------------------------------------------------------------
      ------------------------------------ TRANSFORM PHASE END -------------------------------------
      ----------------------------------------------------------------------------------------------

      /* Debug Log */
      print_debug('interface framework (int_mode=' || l_tfm_mode || ')');

      IF l_error_count > 0 THEN
         RAISE interface_error;
      END IF;

      ----------------------------------------------------------------------------------------------
      ------------------------------------- LOAD PHASE START ---------------------------------------
      ----------------------------------------------------------------------------------------------

      IF l_tfm_mode = g_int_mode THEN
         SELECT COUNT(1)
         INTO   l_record_count
         FROM   xxar_open_items_tfm
         WHERE  run_id = l_run_id
         AND    run_phase_id = l_run_phase_id;

         l_run_phase_id := dot_common_int_pkg.start_run_phase
                              (p_run_id                  => l_run_id,
                               p_phase_code              => z_load,
                               p_phase_mode              => g_int_mode,
                               p_int_table_name          => 'XXAR_OPEN_ITEMS_TFM',
                               p_int_table_key_col1      => 'CRN_NUMBER',
                               p_int_table_key_col_desc1 => 'CRN Number',
                               p_int_table_key_col2      => NULL,
                               p_int_table_key_col_desc2 => NULL,
                               p_int_table_key_col3      => NULL,
                               p_int_table_key_col_desc3 => NULL);

         /* Debug Log */
         print_debug('interface framework (run_load_id=' || l_run_phase_id || ')');

         dot_common_int_pkg.update_run_phase
            (p_run_phase_id => l_run_phase_id,
             p_src_code     => z_src_code,
             p_rec_count    => l_record_count,
             p_hash_total   => NULL,
             p_batch_name   => l_file);

         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := -1;
         l_success_count := 0;
         l_error_count := 0;

         BEGIN
            IF NVL(p_archive_flag, 'N') = 'Y' THEN
               /* Debug Log */
               print_debug('archiving records');

               UPDATE xxar_payment_notices_b
               SET    archive_flag = 'Y',
                      archive_date = SYSDATE,
                      last_update_date = SYSDATE,
                      last_updated_by = l_user_id
               WHERE  NVL(archive_flag, 'N') = 'N'
               AND    source = p_source;
            END IF;

            /* Debug Log */
            print_debug('updating Payment Notices table');

            -- Update Payment Notices
            INSERT INTO xxar_payment_notices_b
            SELECT NULL,
                   p_source,
                   crn_number,
                   orig_amt1,
                   orig_amt2,
                   orig_amt3,
                   orig_amt4,
                   object_version_id,
                   l_file,
                   l_user_id,
                   SYSDATE,
                   'N',
                   NULL,
                   l_user_id,
                   SYSDATE
            FROM   xxar_open_items_tfm
            WHERE  run_id = l_run_id
            AND    status = 'PROCESSED';

            l_success_count := sql%ROWCOUNT;
            l_int_status := 'SUCCESS';

            COMMIT;

         EXCEPTION
            WHEN others THEN
               ROLLBACK;
               l_error_count := l_record_count;
               l_int_status := 'ERROR';
               r_error.msg_code := REPLACE(SQLCODE, '-');
               r_error.error_text := SQLERRM;
               raise_error(r_error);
         END;

         dot_common_int_pkg.end_run_phase
            (p_run_phase_id => l_run_phase_id,
             p_status => l_int_status,
             p_error_count => l_error_count,
             p_success_count => l_success_count);

         IF l_error_count > 0 THEN
            RAISE interface_error;
         END IF;

      END IF;

      ----------------------------------------------------------------------------------------------
      ------------------------------------- LOAD PHASE END -----------------------------------------
      ----------------------------------------------------------------------------------------------

      l_run_report_id := dot_common_int_pkg.launch_run_report
                              (p_run_id      => l_run_id,
                               p_notify_user => l_user_name);

      /* Debug Log */
      print_debug('interface framework completion report (request_id=' || l_run_report_id || ')');

      /*-------------------------------------------------*/
      /*-- Exit loop regardless of the number of files --*/
      /*-- fetched. Business rule is to process one    --*/
      /*-- file at a time.                             --*/
      /*-------------------------------------------------*/

      EXIT;

   END LOOP;

EXCEPTION
   WHEN interface_error THEN
      l_run_report_id := dot_common_int_pkg.launch_error_report
                            (p_run_id => l_run_id,
                             p_run_phase_id => l_run_phase_id);
      print_debug('interface framework error report (request_id=' || l_run_report_id || ')');

      p_retcode := 2;
END open_items_import;

----------------------------------------------------------
-- Procedure
--     OPEN_ITEMS_EXTRACT
-- Purpose
--     Main program that merges outstanding Receivables
--     invoices with open items from external source(s),
--     and extracts data into the prescribed bank upload
--     format.
----------------------------------------------------------

PROCEDURE open_items_extract
(
   p_errbuff   OUT VARCHAR2,
   p_retcode   OUT NUMBER,
   p_source    IN  VARCHAR2
)
IS
   CURSOR c_items IS
      SELECT rct.attribute7 crn_number,
             aps.amount_due_remaining orig_amt1,
             0 orig_amt2,
             0 orig_amt3,
             0 orig_amt4
      FROM   ra_customer_trx rct,
             ra_batch_sources bas,
             ar_payment_schedules aps
      WHERE  rct.customer_trx_id = aps.customer_trx_id
      AND    rct.batch_source_id = bas.batch_source_id
      AND    NVL(aps.amount_due_remaining, 0) > 0
      AND    aps.status = 'OP'
      AND    rct.attribute7 IS NOT NULL -- CRN
      AND    p_source IS NULL
      AND    bas.name NOT IN (SELECT lookup_code
                              FROM   fnd_lookup_values
                              WHERE  lookup_type LIKE 'XXAR_TXNTYPE_OPEN_ITEM_EXCLUDE')
      UNION ALL
      SELECT xx.crn_number,
             xx.orig_amt1,
             xx.orig_amt2,
             xx.orig_amt3,
             xx.orig_amt4
      FROM   xxar_payment_status_v xx
      WHERE  UPPER(xx.open_item_status) = 'NEW'
      AND    xx.source = NVL(p_source, xx.source);

   l_line              VARCHAR2(2000);
   l_delim             VARCHAR2(25) := CHR(9);
BEGIN
   FOR rec IN c_items LOOP
      l_line := rec.crn_number || l_delim ||
                rec.orig_amt1  || l_delim ||
                rec.orig_amt2  || l_delim ||
                rec.orig_amt3  || l_delim ||
                rec.orig_amt4;
      fnd_file.put_line(fnd_file.output, l_line);
   END LOOP;

END open_items_extract;

END xxar_open_items_interface_pkg;
/
