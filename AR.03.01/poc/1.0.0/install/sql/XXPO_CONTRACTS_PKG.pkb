CREATE OR REPLACE PACKAGE BODY xxpo_contracts_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.03.01/poc/1.0.0/install/sql/XXPO_CONTRACTS_PKG.pkb 2558 2017-09-19 04:46:44Z svnuser $ */
/****************************************************************************
**
** CEMLI ID: PO.12.01
**
** Description: Contract Management System (CMS) interface file import
**
** Change History:
**
** Date        Who                  Comments
** 28/08/2017  ARELLAD (RED ROCK)   Initial build.
**
****************************************************************************/

-- Constants 
z_appl                 CONSTANT VARCHAR2(5) := 'PO';
z_src_in               CONSTANT VARCHAR2(60) := 'USER_TMP_DIR';
z_stg_dir              CONSTANT VARCHAR2(60) := '/usr/tmp';
z_file_space           CONSTANT VARCHAR2(1)   := '_';
z_date_format          CONSTANT VARCHAR2(25)  := 'YYYYMMDDHH24MISS';
z_amount_format        CONSTANT VARCHAR2(30)  := 'FM999,999,999.00';
z_delimiter_comma      CONSTANT VARCHAR2(1)   := ',';
z_delimiter_pipe       CONSTANT VARCHAR2(10)  := ' | ';
z_temp_table           VARCHAR2(30)  := 'FMSMGR.XXPO_CONTRACTS';
z_indent               VARCHAR2(1)   := ' ';

-- -- Global variables and Error Codes
g_retcode_warning      NUMBER        := 1;
g_retcode_error        NUMBER        := 2;
g_error_01             VARCHAR2(150) := 'Unable to create archive file ';
g_error_02             VARCHAR2(150) := 'File $IN_FILE does not exists';
g_error_03             VARCHAR2(150) := 'File $IN_FILE is empty';
g_error_04             VARCHAR2(150) := 'Error(s) encountered during load. Please check SQLLDR files: '
                                         || CHR(10) || '$LOG_FILE '
                                         || CHR(10) || '$BAD_FILE ';
g_error_05             VARCHAR2(150) := 'Date conversion error';
g_error_06             VARCHAR2(150) := 'Contract Number error';
g_debug                VARCHAR2(15)  := 'DEBUG:   ';
g_error                VARCHAR2(15)  := 'ERROR:   ';
g_warning              VARCHAR2(15)  := 'WARNING: ';
g_debug_flag           VARCHAR2(1);
g_run_date             DATE := SYSDATE;
g_from_date            DATE;

TYPE cursor_type IS REF CURSOR;

TYPE contract_rec_type IS RECORD
(
   contract_number   VARCHAR2(10),
   description       VARCHAR2(1000),
   start_date        VARCHAR2(25),
   end_date          VARCHAR2(25)
);

TYPE error_tab_type IS TABLE OF VARCHAR2(4000) INDEX BY binary_integer;

------------------------------------------------
-- Procedure
--     PRINT_OUTPUT
-- Purpose
--     Use output to display simple report.
------------------------------------------------

PROCEDURE print_output
(
   p_line   VARCHAR2
)
IS
BEGIN
   fnd_file.put_line(fnd_file.output, p_line);
END print_output;

------------------------------------------------
-- Procedure
--     PRINT_DEBUG
-- Purpose
--     Prints debug logs on to the standard 
--     Oracle log file (FND_FILE.LOG).
------------------------------------------------

PROCEDURE print_debug
(
   p_debug_text   VARCHAR2
)
IS
BEGIN
   IF g_debug_flag = 'Y' THEN
      fnd_file.put_line(fnd_file.log, g_debug || p_debug_text);
      dbms_output.put_line(g_debug || p_debug_text);
   END IF;
END print_debug;

------------------------------------------------
-- Procedure
--     PRINT_ERROR
-- Purpose
--     Prints errors and/or warnings on to the
--     standard Oracle log file (FND_FILE.LOG).
------------------------------------------------

PROCEDURE print_error
(
   p_tag          VARCHAR2,          
   p_error_text   VARCHAR2
)
IS
BEGIN
   fnd_file.put_line(fnd_file.log, p_tag || p_error_text);
END print_error;

------------------------------------------------
-- Function
--     CLOSE_IN_QUOTE
-- Purpose
--     Encapsulate text in double quotes.
------------------------------------------------

FUNCTION close_in_quote
(
   p_text   VARCHAR2
)
RETURN VARCHAR2
IS
BEGIN
   RETURN '"' || p_text || '"';
END close_in_quote;

------------------------------------------------------
-- Function
--     CONVERT_TO_DATE
-- Purpose
--     Try converting date using multiple formats.
------------------------------------------------------

FUNCTION convert_to_date
(
   p_date_in    IN VARCHAR2,
   p_date_out   OUT DATE
)
RETURN BOOLEAN
IS
   to_date_error   EXCEPTION;
   pragma          exception_init (to_date_error, -01830);
BEGIN
   BEGIN
      p_date_out := TO_DATE(p_date_in, 'DD-MON-RR');
      RETURN TRUE;
   EXCEPTION
      WHEN others THEN NULL;
   END;

   BEGIN
      p_date_out := TO_DATE(p_date_in, 'DD/MM/RR');
      RETURN TRUE;
   EXCEPTION
      WHEN others THEN NULL;
   END;

   BEGIN
      p_date_out := TO_DATE(p_date_in, 'YYYY/MM/DD');
      RETURN TRUE;
   EXCEPTION
      WHEN others THEN NULL;
   END;

   RETURN FALSE;
END convert_to_date;

--------------------------------------------------------
-- Procedure
--     REMOVE_FILE
-- Purpose
--     Remove file is a function for removing temporary
--     files stored in the user temp directory.
--------------------------------------------------------

PROCEDURE remove_file
(
   p_file   VARCHAR2
)
IS
   f_exists           BOOLEAN;
   f_len              NUMBER;
   f_bsize            NUMBER;
BEGIN
   print_debug('remove file ' || p_file);
   UTL_FILE.FGETATTR(z_src_in, p_file, f_exists, f_len, f_bsize);
   IF f_exists THEN
      UTL_FILE.FREMOVE(z_src_in, p_file);
   END IF;
EXCEPTION
   WHEN others THEN
      print_error(g_error, SQLERRM || ' removing file ' || p_file);
END remove_file;

------------------------------------------------------
-- Procedure
--     CLEAN_UP
-- Purpose
--     Clean procedures removes temporary files and 
--     used during data staging.
------------------------------------------------------

PROCEDURE clean_up
(
   p_file     VARCHAR2,
   p_dest     VARCHAR2
)
IS
   f_copy      INTEGER;
   f_exists    BOOLEAN;
   f_len       NUMBER;
   f_bsize     NUMBER;
BEGIN
   print_debug('move file=' || p_file);

   utl_file.fgetattr(z_src_in, p_file, f_exists, f_len, f_bsize);

   IF f_exists THEN
      f_copy := xxint_common_pkg.file_copy(p_from_path => z_stg_dir || '/' || p_file,
                                           p_to_path => p_dest || '/' || p_file);
      IF f_copy = 1 THEN
         utl_file.fremove(z_src_in, p_file);
      ELSE
         print_error(g_warning, g_error_01);
      END IF;
   END IF;
END clean_up;

-----------------------------------------------------
-- Procedure
--     APPEND_ERRORS
-- Purpose
--     Errors found during data validation and 
--     transformation are added into the bad.
-----------------------------------------------------

PROCEDURE append_errors
(
   p_bad_file       VARCHAR2,
   p_errors_tab     error_tab_type
)
IS
   -- UTL File
   f_handle        utl_file.file_type;
   f_exists        BOOLEAN;
   f_len           NUMBER;
   f_bsize         NUMBER;
BEGIN
   UTL_FILE.FGETATTR(z_src_in,
                     p_bad_file,
                     f_exists,
                     f_len,
                     f_bsize);

   IF f_exists THEN
      f_handle := utl_file.fopen(z_src_in, p_bad_file, 'a');
   ELSE
      f_handle := utl_file.fopen(z_src_in, p_bad_file, 'w');
   END IF;

   FOR r IN 1 .. p_errors_tab.COUNT LOOP
      utl_file.put_line(f_handle, p_errors_tab(r));
   END LOOP;

   utl_file.fclose(f_handle);
EXCEPTION
   WHEN others THEN
     IF utl_file.is_open(f_handle) THEN
        utl_file.fclose(f_handle);
     END IF;

     print_error(g_error, SQLERRM || ' append_errors');

END append_errors;

-------------------------------------------------------
-- Function
--     IMPORT_FILE
-- Purpose
--     Import data file using ACCESS_DRIVER into a 
--     temporary storage. Run clean-up routine to 
--     delete and drop temp files and storage.
-------------------------------------------------------

FUNCTION import_file
(
   p_file          IN  VARCHAR2,
   p_bad_file      IN  VARCHAR2,
   p_log_file      IN  VARCHAR2,
   p_request_id    IN  NUMBER,
   p_count         OUT NUMBER,
   p_temp_table    OUT VARCHAR2,
   p_message       OUT VARCHAR2
)
RETURN BOOLEAN
IS
   l_sql         VARCHAR2(4000);
   l_sql_row     NUMBER;
BEGIN
   p_temp_table := z_temp_table || z_file_space || p_request_id;

   l_sql := ' (contract_number VARCHAR2(10), ' ||
              'description VARCHAR2(1000), ' ||
              'start_date VARCHAR2(25), ' ||
              'end_date VARCHAR2(25)) ' ||
              'ORGANIZATION EXTERNAL ' ||
              '(TYPE ORACLE_LOADER ' ||
              'DEFAULT DIRECTORY ' || z_src_in || ' ' ||
              'ACCESS PARAMETERS (' ||
              'RECORDS DELIMITED BY NEWLINE CHARACTERSET US7ASCII ' ||
              'BADFILE ' || z_src_in || ': ''' || p_bad_file || ''' ' ||
              'LOGFILE ' || z_src_in || ': ''' || p_log_file || ''' ' ||
              'SKIP 0 ' ||
              'READSIZE 1048576 ' ||
              'FIELDS TERMINATED BY "|" OPTIONALLY ENCLOSED BY ''"'' ' ||
              'MISSING FIELD VALUES ARE NULL) ' ||
              'LOCATION (''' || p_file || ''')) ' ||
              'REJECT LIMIT UNLIMITED ';

   -- Temporary external table
   l_sql := 'CREATE TABLE ' || p_temp_table || l_sql;
   EXECUTE IMMEDIATE l_sql;

   -- Row count from external table
   l_sql := 'SELECT COUNT(1) FROM ' || p_temp_table;
   EXECUTE IMMEDIATE l_sql INTO l_sql_row;

   p_count := l_sql_row;

   IF NVL(l_sql_row, 0 ) = 0 THEN
      p_message := REPLACE(g_error_03, '$IN_FILE', p_file);
      RETURN FALSE;
   END IF;

   RETURN TRUE;

EXCEPTION
   WHEN others THEN
      p_message := SQLERRM;
      RETURN FALSE;

END import_file;

-------------------------------------------------------
-- PROCEDURE
--     LOAD_CONTRACTS
-- Purpose
--     Main calling program for importing contracts
--     into XXPO_CONTRACTS_ALL custom table.
-------------------------------------------------------

PROCEDURE load_contracts
(
   p_errbuff     OUT VARCHAR2,
   p_retcode     OUT NUMBER,
   p_source      IN  VARCHAR2,
   p_filename    IN  VARCHAR2,
   p_debug       IN  VARCHAR2
)
IS
   l_in_file          VARCHAR2(150);
   l_in_file_ext      VARCHAR2(15);
   l_in_file_use      VARCHAR2(150);
   l_bad_file         VARCHAR2(150);
   l_log_file         VARCHAR2(150);
   l_arc_file         VARCHAR2(150);
   l_arc_date         VARCHAR2(30);
   l_temp_table       VARCHAR2(150);
   l_program_name     fnd_concurrent_programs_tl.user_concurrent_program_name%TYPE;
   l_program_id       NUMBER;
   l_request_id       NUMBER;
   l_org_id           NUMBER;
   l_user_id          fnd_user.user_id%TYPE;
   l_user_name        fnd_user.user_name%TYPE;
   l_message          VARCHAR2(600);
   l_ref_cur          VARCHAR2(600) := 'SELECT * FROM ' || z_temp_table || z_file_space;
   l_sql              VARCHAR2(600);
   l_contract_number  xxpo_contracts_all.contract_number%TYPE;
   l_description      xxpo_contracts_all.description%TYPE;
   l_start_date       DATE;
   l_end_date         DATE;
   l_err              NUMBER := 0;
   l_rec_count        NUMBER;
   l_merge_count      NUMBER := 0;

   -- Interface Framework
   l_in_dir           VARCHAR2(150);
   l_out_dir          VARCHAR2(150);
   l_arc_dir          VARCHAR2(150);
   c_con              cursor_type;
   r_con              contract_rec_type;
   t_errors           error_tab_type;

   -- UTL File
   f_copy             INTEGER;
   f_exists           BOOLEAN;
   f_len              NUMBER;
   f_bsize            NUMBER;

   sql_error          EXCEPTION;

BEGIN
   xxint_common_pkg.g_object_type := 'CONTRACTS';

   l_program_id := fnd_global.conc_program_id;
   l_request_id := fnd_global.conc_request_id;
   l_user_name := fnd_global.user_name;
   l_user_id := fnd_profile.value('USER_ID');
   l_org_id := fnd_profile.value('ORG_ID');
   l_ref_cur := l_ref_cur || l_request_id;
   g_debug_flag := p_debug;

   /****************************/
   /* Get Directory Info       */
   /****************************/
   print_debug('retrieving interface directory information');

   l_in_dir := xxint_common_pkg.interface_path(p_application => z_appl,
                                               p_source => p_source,
                                               p_in_out => 'INBOUND',
                                               p_message => l_message );
   IF l_message IS NOT NULL THEN
      print_error(g_error, l_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_out_dir := xxint_common_pkg.interface_path(p_application => z_appl,
                                                p_source => p_source,
                                                p_in_out => 'OUTBOUND',
                                                p_message => l_message);
   IF l_message IS NOT NULL THEN
      print_error(g_error, l_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_arc_dir := xxint_common_pkg.interface_path(p_application => z_appl,
                                                p_source => p_source,
                                                p_archive => 'Y',
                                                p_message => l_message);
   IF l_message IS NOT NULL THEN
      print_error(g_error, l_message);
      p_retcode := 2;
      RETURN;
   END IF;

   print_debug('l_in_dir=' || l_in_dir);
   print_debug('l_out_dir=' || l_out_dir);
   print_debug('l_arc_dir=' || l_arc_dir);
   print_debug('z_stg_dir=' || z_stg_dir);

   IF p_filename IS NOT NULL THEN
      l_in_file := p_filename;
      l_in_file_ext := SUBSTR(l_in_file, (INSTR(l_in_file, '.', -1) + 1), 15);
      l_in_file_use := SUBSTR(l_in_file, 1, (INSTR(l_in_file, '.', -1) - 1));
      l_arc_date := TO_CHAR(SYSDATE, z_date_format);
      l_arc_file := l_in_file_use || z_file_space || l_arc_date || '.' || l_in_file_ext;
      l_bad_file := l_in_file_use || z_file_space || l_request_id || '.bad';
      l_log_file := l_in_file_use || z_file_space || l_request_id || '.log';

      print_debug('l_in_file=' || l_in_file);
      print_debug('l_in_file_ext=' || l_in_file_ext);
      print_debug('l_in_file_use=' || l_in_file_use);
      print_debug('l_arc_date=' || l_arc_date);
      print_debug('l_arc_file=' || l_arc_file);
      print_debug('l_bad_file=' || l_bad_file);
      print_debug('l_log_file=' || l_log_file);

      f_copy := xxint_common_pkg.file_copy(p_from_path => l_in_dir || '/' || l_in_file,
                                           p_to_path => l_out_dir || '/' || l_arc_file);

      print_debug('creating archive f_copy=' || f_copy);

      f_copy := xxint_common_pkg.file_copy(p_from_path => l_in_dir || '/' || l_in_file,
                                           p_to_path => z_stg_dir || '/' || l_in_file);

      print_debug('creating temp load file f_copy=' || f_copy);

      IF f_copy = 1 THEN
         UTL_FILE.FGETATTR(z_src_in, l_in_file, f_exists, f_len, f_bsize);

         IF f_exists THEN
            print_debug('file_exists=' || l_in_file);

            IF import_file(l_in_file, 
                           l_bad_file,
                           l_log_file,
                           l_request_id, 
                           l_rec_count, 
                           l_temp_table, 
                           l_message) 
            THEN
               IF l_rec_count > 0 THEN
                  OPEN c_con FOR l_ref_cur;
                  LOOP
                     FETCH c_con INTO r_con;
                     EXIT WHEN c_con%NOTFOUND;

                     l_start_date := NULL;
                     l_end_date := NULL;
                     l_message := NULL;
                     l_contract_number := NULL;
                     l_description := SUBSTR(REGEXP_REPLACE(REPLACE(r_con.description, '"'), '[[:cntrl:]]{1}'), 1, 255);

                     BEGIN
                        IF NOT convert_to_date(r_con.start_date, l_start_date) THEN
                           l_message := g_error_05;
                           RAISE sql_error;
                        END IF;

                        IF NOT convert_to_date(r_con.end_date, l_end_date) THEN
                           l_message := g_error_05;
                           RAISE sql_error;
                        END IF;

                        IF r_con.contract_number IS NULL THEN
                           l_message := g_error_06;
                           RAISE sql_error;
                        ELSE
                           l_message := g_error_06;
                           l_contract_number := TO_NUMBER(r_con.contract_number);
                        END IF;

                        MERGE INTO xxpo_contracts_all c
                        USING DUAL ON (c.contract_number = l_contract_number AND
                                       c.org_id = l_org_id)
                        WHEN MATCHED THEN
                           UPDATE SET c.description = l_description,
                                      c.start_date = l_start_date,
                                      c.end_date = l_end_date,
                                      c.last_updated_by = l_user_id,
                                      c.last_update_date = g_run_date
                        WHEN NOT MATCHED THEN
                           INSERT (contract_number,
                                   description,
                                   org_id,
                                   start_date,
                                   end_date,
                                   created_by,
                                   creation_date,
                                   last_updated_by,
                                   last_update_date)
                           VALUES (l_contract_number,
                                   l_description,
                                   l_org_id,
                                   l_start_date,
                                   l_end_date,
                                   l_user_id,
                                   g_run_date,
                                   l_user_id,
                                   g_run_date);

                        l_merge_count := l_merge_count + 1;

                     EXCEPTION
                        WHEN sql_error THEN
                           l_err := l_err + 1;
                           t_errors(l_err) := close_in_quote(r_con.contract_number) || z_delimiter_comma ||
                                              close_in_quote(REPLACE(r_con.description, '"')) || z_delimiter_comma ||
                                              close_in_quote(r_con.start_date) || z_delimiter_comma ||
                                              close_in_quote(r_con.end_date) || z_delimiter_comma ||
                                              close_in_quote(l_message);
                        WHEN others THEN
                           l_message := LTRIM(l_message || ' ') || SQLERRM;
                           l_err := l_err + 1;
                           t_errors(l_err) := close_in_quote(r_con.contract_number) || z_delimiter_comma ||
                                              close_in_quote(REPLACE(r_con.description, '"')) || z_delimiter_comma ||
                                              close_in_quote(r_con.start_date) || z_delimiter_comma ||
                                              close_in_quote(r_con.end_date) || z_delimiter_comma ||
                                              close_in_quote(l_message);
                     END;
                  END LOOP;
                  CLOSE c_con;

                  print_debug('l_merge_count=' || l_merge_count);

               ELSE
                  l_message := g_error_03;
                  l_message := REPLACE(l_message, '$IN_FILE', l_in_file);
                  print_error(g_warning, l_message);
                  p_retcode := g_retcode_warning;
               END IF;

            ELSE
               l_message := g_error_04;
               l_message := REPLACE(l_message, '$LOG_FILE', l_log_file);
               l_message := REPLACE(l_message, '$BAD_FILE', l_bad_file);
               print_error(g_error, l_message);
               p_retcode := g_retcode_error;
            END IF;

            -- Append errors to bad file
            IF t_errors.COUNT > 0 THEN
               print_debug('l_error_count=' || l_err);
               append_errors(l_bad_file, t_errors);
               p_retcode := g_retcode_warning;
            END IF;

            -- Clean up temp data file and storage
            clean_up(l_bad_file, l_out_dir);
            clean_up(l_log_file, l_out_dir);
            l_sql := 'DROP TABLE ' || l_temp_table;
            EXECUTE IMMEDIATE l_sql;

         ELSE
            l_message := g_error_02;
            l_message := REPLACE(l_message, '$IN_FILE', l_in_file);
            print_error(g_warning, l_message);
            p_retcode := g_retcode_warning;
         END IF;
      ELSE
         l_message := g_error_02;
         l_message := REPLACE(l_message, '$IN_FILE', l_in_file);
         print_error(g_error, l_message);
         p_retcode := g_retcode_error;
      END IF;
   END IF;

   IF l_program_id IS NOT NULL THEN
      SELECT user_concurrent_program_name
      INTO   l_program_name
      FROM   fnd_concurrent_programs_tl
      WHERE  concurrent_program_id = l_program_id;

      -- Summary
      fnd_file.put_line(fnd_file.output, z_indent);
      fnd_file.put_line(fnd_file.output, z_indent || l_program_name);
      fnd_file.put_line(fnd_file.output, z_indent || TO_CHAR(g_run_date, 'DD/MM/YYYY HH24:MI:SS'));
      fnd_file.put_line(fnd_file.output, z_indent || l_user_name);
      fnd_file.put_line(fnd_file.output, z_indent);
      fnd_file.put_line(fnd_file.output, z_indent || 'Input File     : ' || l_in_dir || '/' || l_in_file);

      IF l_err > 0 THEN
         fnd_file.put_line(fnd_file.output, z_indent || 'LOG File       : ' || l_out_dir || '/' || l_log_file);
         fnd_file.put_line(fnd_file.output, z_indent || 'BAD File       : ' || l_out_dir || '/' || l_bad_file);
         IF l_err < l_rec_count THEN
            p_retcode := 1;
         ELSIF l_err = l_rec_count THEN
            p_retcode := 2;
         END IF;
      END IF;
      fnd_file.put_line(fnd_file.output, z_indent || 'Record Count   : ' || l_rec_count);
      fnd_file.put_line(fnd_file.output, z_indent || 'Update Count   : ' || l_merge_count);
      fnd_file.put_line(fnd_file.output, z_indent || 'Error Count    : ' || l_err);
   END IF;

END load_contracts;

END xxpo_contracts_pkg;
/
