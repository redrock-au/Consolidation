CREATE OR REPLACE PACKAGE BODY xxgl_payroll_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.04/glc/1.0.0/install/sql/XXGL_PAYROLL_PKG.pkb 2486 2017-09-07 07:51:18Z svnuser $ */
/****************************************************************************
**
** CEMLI ID: GL.02.01
**
** Description: Payroll Accrual and Oncost
**
** Change History:
**
** Date        Who                  Comments
** 25/05/2017  Ryan S (RED ROCK)    Initial build.
**
****************************************************************************/

g_user_id                NUMBER;
g_debug_flag             VARCHAR2(1) := 'N';
g_rule_lookup_type       VARCHAR2(30);
g_sob_id                 NUMBER;
g_run_number             NUMBER;
g_sob_currency           gl_sets_of_books.currency_code%TYPE;
g_chart_id               NUMBER;
g_int_batch_name         dot_int_runs.src_batch_name%TYPE;
g_user_je_source         gl_je_sources.user_je_source_name%TYPE;
g_accrual_flag           VARCHAR2(1);
e_stage_exception        EXCEPTION;
e_load_exception         EXCEPTION; 

TYPE t_varchar_tab_type IS TABLE OF VARCHAR2(200) INDEX BY BINARY_INTEGER;

TYPE r_srs_request_type IS RECORD 
(
   srs_wait           BOOLEAN,
   srs_phase          VARCHAR2(30),
   srs_status         VARCHAR2(30),
   srs_dev_phase      VARCHAR2(30),
   srs_dev_status     VARCHAR2(30),
   srs_message        VARCHAR2(240)
);

TYPE t_varchar_cache_type IS TABLE OF VARCHAR2(30) INDEX BY VARCHAR2(240);
g_category_cache          t_varchar_cache_type;
g_period_year_cache       t_varchar_cache_type;
g_next_period_name_cache  t_varchar_cache_type;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      log_msg
--  PURPOSE
--       Writes a line to the concurrent log file.
-- --------------------------------------------------------------------------------------------------
PROCEDURE log_msg
(
   p_message IN VARCHAR2
) IS
BEGIN
   fnd_file.put_line(fnd_file.log, substr(p_message, 1, 2000));
END log_msg;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      debug_msg
--  PURPOSE
--       Writes a line to the concurrent log file if the debug flag is on.
-- --------------------------------------------------------------------------------------------------
PROCEDURE debug_msg
(
   p_message IN VARCHAR2
) IS
BEGIN
   IF nvl(g_debug_flag, 'N') = 'Y' THEN
      fnd_file.put_line(fnd_file.log, g_debug || substr(p_message, 1, 1990));
   END IF;
END debug_msg;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      raise_error
--  PURPOSE
--       Local wrapper of the interface framework error procedure.
--       This inserts a row into dot_int_run_phase_errors.
-- --------------------------------------------------------------------------------------------------
PROCEDURE raise_error
(
   p_error_rec      IN OUT NOCOPY dot_int_run_phase_errors%ROWTYPE
)
IS
BEGIN
   dot_common_int_pkg.raise_error
      ( p_run_id => p_error_rec.run_id,
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
        p_int_table_key_val3 => p_error_rec.int_table_key_val3 );
END raise_error;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      wait_for_request
--  PURPOSE
--       Waits for a concurrent request to complete
--       p_interval is time to wait between polls measured in seconds
-- --------------------------------------------------------------------------------------------------
PROCEDURE wait_for_request
(
   p_request_id         IN NUMBER,
   p_interval           IN NUMBER,
   p_srs_request        IN OUT NOCOPY r_srs_request_type
)
IS
   b_wait               BOOLEAN;
BEGIN
   b_wait := fnd_concurrent.wait_for_request
      ( p_request_id,
        p_interval,
        0,
        p_srs_request.srs_phase,
        p_srs_request.srs_status,
        p_srs_request.srs_dev_phase,
        p_srs_request.srs_dev_status,
        p_srs_request.srs_message);
END wait_for_request;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      get_interface_defn
--  PURPOSE
--       Selects the interface definition of the current interface.  Creates it if it doesn't exist.
-- --------------------------------------------------------------------------------------------------
PROCEDURE get_interface_defn
(
   p_int_code          IN dot_int_interfaces.int_code%TYPE,
   p_int_name          IN dot_int_interfaces.int_name%TYPE,
   p_request_id        IN NUMBER,
   p_interface_dfn     IN OUT NOCOPY dot_int_interfaces%ROWTYPE
) IS
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   SELECT * 
   INTO   p_interface_dfn
   FROM   dot_int_interfaces
   WHERE  int_code = p_int_code;
   ROLLBACK;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      INSERT INTO dot_int_interfaces VALUES
      (
         dot_int_interfaces_s.NEXTVAL,
         p_int_code,
         p_int_name,
         'IN',
         'GL',
         'Y',
         SYSDATE,
         g_user_id,
         g_user_id,
         SYSDATE,
         g_user_id,
         p_request_id
      );
   COMMIT;
END get_interface_defn;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      submit_gllezl
--  PURPOSE
--       Submits Journal Import
--  RETURNS
--       Concurrent Request Id of the submitted request
-- --------------------------------------------------------------------------------------------------
FUNCTION submit_gllezl
(
   p_source            IN VARCHAR2,
   p_group_id          IN NUMBER,
   p_sob_id            IN NUMBER
) RETURN NUMBER
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_request_id        NUMBER;
   l_run_id            NUMBER;
   l_group_id          NUMBER := p_group_id;
   l_dummy             NUMBER;

BEGIN
   gl_journal_import_pkg.populate_interface_control
      ( user_je_source_name   => p_source,
        group_id              => l_group_id,
        set_of_books_id       => p_sob_id,
        interface_run_id      => l_run_id,
        processed_data_action => gl_journal_import_pkg.SAVE_DATA );

   COMMIT;

   BEGIN
      SELECT 1
      INTO   l_dummy
      FROM   gl_interface_control
      WHERE  group_id = l_group_id;
  
      l_request_id := fnd_request.submit_request
         ( application => 'SQLGL',
           program     => 'GLLEZL',
           description => NULL,
           start_time  => NULL,
           sub_request => FALSE,
           argument1   => l_run_id,
           argument2   => p_sob_id, 
           argument3   => 'N', 
           argument4   => null, 
           argument5   => null, 
           argument6   => 'Y',  -- Summary Journals 
           argument7   => 'N' ); 

      COMMIT;
      debug_msg('journal import interface_run_id = ' || l_run_id);
   EXCEPTION
      WHEN no_data_found THEN
         debug_msg('group id ' || l_group_id || ' not found');
   END;

   RETURN l_request_id;
END submit_gllezl;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      submit_xxintifr_get_file
--  PURPOSE
--       Submits the interface framework program XXINTIFR (DEDJTR Interface Framework Get File)
--       This inserts rows into xxint_interface_ctl.
--  RETURNS
--       Concurrent Request Id of the submitted request
-- --------------------------------------------------------------------------------------------------
FUNCTION submit_xxintifr_get_file
(
   p_int_req_id        IN NUMBER,
   p_in_dir            IN VARCHAR2,
   p_file              IN VARCHAR2,
   p_appl_id           IN NUMBER
) RETURN NUMBER
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_request_id        NUMBER;
BEGIN
   l_request_id := fnd_request.submit_request
      ( application => 'FNDC',
        program     => 'XXINTIFR',
        description => NULL,
        start_time  => NULL,
        sub_request => FALSE,
        argument1   => p_int_req_id,
        argument2   => p_in_dir,
        argument3   => p_file,
        argument4   => p_appl_id );
   COMMIT;
   RETURN l_request_id;
END;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      submit_xxintsqlldr
--  PURPOSE
--       Submits the interface framework program XXINTSQLLDR (DEDJTR Interface Framework SQLLDR)
--       This loads a file into staging tables.
--  RETURNS
--       Concurrent Request Id of the submitted request
-- --------------------------------------------------------------------------------------------------
FUNCTION submit_xxintsqlldr
(
   p_inbound_directory   IN VARCHAR2,
   p_outbound_directory  IN VARCHAR2,
   p_staging_directory   IN VARCHAR2,
   p_archive_directory   IN VARCHAR2,
   p_file                IN VARCHAR2,
   p_log                 IN VARCHAR2,
   p_bad                 IN VARCHAR2,
   p_ctl                 IN VARCHAR2
) RETURN NUMBER
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_sqlldr_req_id       NUMBER;
BEGIN
   l_sqlldr_req_id := fnd_request.submit_request
      ( application => 'FNDC',
        program     => 'XXINTSQLLDR',
        description => NULL,
        start_time  => NULL,
        sub_request => FALSE,
        argument1   => p_inbound_directory,
        argument2   => p_outbound_directory,
        argument3   => p_staging_directory,
        argument4   => p_archive_directory,
        argument5   => p_file,
        argument6   => p_log,
        argument7   => p_bad,
        argument8   => p_ctl );
   COMMIT;
   RETURN l_sqlldr_req_id;
END;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      get_interface_files
--  PURPOSE
--       Selects all file names found in the interface framework control table that was populated
--       by the interface framework loader program XXINTSQLLDR.
--       Result is returned as a list of file names in a varchar2 pl/sql table.
-- --------------------------------------------------------------------------------------------------
PROCEDURE get_interface_files
(
   p_request_id        IN NUMBER,
   p_sub_req_id        IN NUMBER,
   p_files_tab         IN OUT NOCOPY t_varchar_tab_type
) IS
BEGIN
   SELECT file_name BULK COLLECT
   INTO   p_files_tab
   FROM   xxint_interface_ctl
   WHERE  interface_request_id = p_request_id
   AND    sub_request_id = p_sub_req_id
   AND    file_name IS NOT NULL;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_files_tab.delete;
END get_interface_files;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_run_number
--  PURPOSE
--      Retrives the Run Number of a batch from the header stage table
--  RETURNS
--      Run Number of the batch
-- --------------------------------------------------------------------------------------------------
FUNCTION get_run_number
(
   p_run_id            NUMBER
) RETURN NUMBER
IS
   l_run_number        NUMBER;
BEGIN
   SELECT run_number
   INTO   l_run_number
   FROM   xxgl_payroll_header_stg
   WHERE  run_id = p_run_id;
   RETURN l_run_number;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;
END get_run_number;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_gl_period_year
--  PURPOSE
--      Retrives the period year as at p_as_at_date in the set of books calendar
--  RETURNS
--      Run Number of the period
-- --------------------------------------------------------------------------------------------------
FUNCTION get_gl_period_year
(
   p_as_at_date        DATE
) RETURN NUMBER
IS
   l_period_year      NUMBER;
   z_date_format      CONSTANT VARCHAR2(11) := 'DD-MON-YYYY';
   l_date_formatted   VARCHAR2(11);
BEGIN
   l_date_formatted := to_char(p_as_at_date, z_date_format);
   IF g_period_year_cache.EXISTS(l_date_formatted) THEN
      RETURN to_number(g_period_year_cache(l_date_formatted));
   ELSE
      SELECT p.period_year
      INTO   l_period_year
      FROM   gl_periods p,
             gl_sets_of_books sob
      WHERE  sob.period_set_name = p.period_set_name
      AND    sob.set_of_books_id = g_sob_id
      AND    trunc(p_as_at_date) BETWEEN p.start_date and p.end_date;
      g_period_year_cache(l_date_formatted) := to_char(l_period_year);
      RETURN l_period_year;
   END IF;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;
END get_gl_period_year;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_next_gl_period_name
--  PURPOSE
--      Retrieves the name of the period following the period that includes the p_as_at_date 
--      in the set of books calendar.
--  RETURNS
--      Period Name
-- --------------------------------------------------------------------------------------------------
FUNCTION get_next_gl_period_name
(
   p_as_at_date        DATE
) RETURN VARCHAR2
IS
   l_period_name      gl_periods.period_name%TYPE;
   z_date_format      CONSTANT VARCHAR2(11) := 'DD-MON-YYYY';
   l_date_formatted   VARCHAR2(11);
BEGIN
   l_date_formatted := to_char(p_as_at_date, z_date_format);
   IF g_next_period_name_cache.EXISTS(l_date_formatted) THEN
      RETURN g_next_period_name_cache(l_date_formatted);
   ELSE
      SELECT n.period_name
      INTO   l_period_name
      FROM   gl_periods p,
             gl_periods n,
             gl_sets_of_books sob
      WHERE  sob.period_set_name = p.period_set_name
      AND    sob.period_set_name = n.period_set_name
      AND    sob.set_of_books_id = g_sob_id
      AND    trunc(p_as_at_date) BETWEEN p.start_date and p.end_date
      AND    trunc(p.end_date+1) BETWEEN n.start_date and n.end_date;
      g_next_period_name_cache(l_date_formatted) := l_period_name;
      RETURN l_period_name;
   END IF;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;
END get_next_gl_period_name;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_journal_count
--  PURPOSE
--      Counts the number of payroll or payroll accrual runs that have been posted so far in the period year
--  RETURNS
--      Count
-- --------------------------------------------------------------------------------------------------
FUNCTION get_journal_count
(
   p_period_year       NUMBER,
   p_je_source         VARCHAR2,
   p_sob_id            NUMBER
) RETURN NUMBER
IS
   l_count              NUMBER;
BEGIN
   SELECT COUNT(DISTINCT jeh.external_reference)
   INTO   l_count
   FROM   gl_je_headers jeh,
          gl_periods glp,
          gl_sets_of_books sob,
          gl_je_sources gls
   WHERE  sob.set_of_books_id = p_sob_id
   AND    glp.period_set_name = sob.period_set_name
   AND    jeh.period_name = glp.period_name
   AND    glp.period_year = p_period_year
   AND    gls.user_je_source_name = p_je_source
   AND    jeh.je_source = gls.je_source_name
   AND    jeh.status = 'P';
   RETURN l_count;
END get_journal_count;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_chart_of_accounts
--  PURPOSE
--      Retrieves the chart of accounts id from the set of books 
--  RETURNS
--      Chart of Accounts Id
-- --------------------------------------------------------------------------------------------------
FUNCTION get_chart_of_accounts
(
   p_sob_id            NUMBER
) RETURN NUMBER
IS
   l_chart_id          NUMBER;
BEGIN
   SELECT chart_of_accounts_id
   INTO   l_chart_id
   FROM   gl_sets_of_books
   WHERE  set_of_books_id = p_sob_id;
   RETURN l_chart_id;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;
END get_chart_of_accounts;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_sob_currency
--  PURPOSE
--      Retrieves the set of books currency 
--  RETURNS
--      Currency code
-- --------------------------------------------------------------------------------------------------
FUNCTION get_sob_currency
(
   p_sob_id            NUMBER
) RETURN VARCHAR2
IS
   l_currency_code     gl_sets_of_books.currency_code%TYPE;
BEGIN
   SELECT currency_code
   INTO   l_currency_code
   FROM   gl_sets_of_books
   WHERE  set_of_books_id = p_sob_id;
   RETURN l_currency_code;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;
END get_sob_currency;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      get_journal_totals
--  PURPOSE
--      Calculates the current DR and CR totals of the journals in the transformation table.
-- --------------------------------------------------------------------------------------------------
PROCEDURE get_journal_totals
(
   p_run_id            IN   NUMBER,
   p_dr_sum            OUT  NUMBER,
   p_cr_sum            OUT  NUMBER
)
IS
BEGIN
   SELECT SUM(entered_dr), SUM(entered_cr)
   INTO   p_dr_sum, p_cr_sum
   FROM   xxgl_payroll_detail_tfm
   WHERE  run_id = p_run_id;
END get_journal_totals;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      lookup_batch_by_desc_prefix
--  PURPOSE
--       Lookups up a journal batch record based on its description
-- --------------------------------------------------------------------------------------------------
PROCEDURE lookup_batch_by_desc_prefix
(
   p_batch_prefix      IN   VARCHAR2,
   p_gl_je_batch       IN OUT NOCOPY gl_je_batches%ROWTYPE
) IS
BEGIN
   SELECT * 
   INTO   p_gl_je_batch
   FROM   gl_je_batches
   WHERE  description like p_batch_prefix || '%';
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_gl_je_batch.je_batch_id := NULL;
END lookup_batch_by_desc_prefix;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      valid_code_combination
--  PURPOSE
--      Determines whether a code combination is valid or not
--  RETURNS
--      True if valid, otherwise False
--      If False, returns the reason in p_error_text
-- --------------------------------------------------------------------------------------------------
FUNCTION valid_code_combination
(
   p_stg_rec               IN OUT NOCOPY xxgl_payroll_detail_stg%ROWTYPE,
   p_error_text            OUT VARCHAR2
) RETURN BOOLEAN
IS
   l_ccid                  NUMBER;
   l_result                BOOLEAN := FALSE;
   l_seg_array             fnd_flex_ext.SegmentArray;
BEGIN
   l_seg_array(1) := p_stg_rec.ORGANISATION;
   l_seg_array(2) := p_stg_rec.ACCOUNT;
   l_seg_array(3) := p_stg_rec.COST_CENTRE;
   l_seg_array(4) := p_stg_rec.AUTHORITY;
   l_seg_array(5) := p_stg_rec.PROJECT;
   l_seg_array(6) := p_stg_rec.OUTPUT;
   l_seg_array(7) := p_stg_rec.IDENTIFIER;

   l_result := fnd_flex_ext.get_combination_id(
         application_short_name => 'SQLGL',
         key_flex_code => 'GL#',
         structure_number => g_chart_id,
         validation_date => sysdate,
         n_segments => l_seg_array.count,
         segments => l_seg_array,
         combination_id => l_ccid );

   IF NOT l_result OR l_ccid = 0 THEN
      p_error_text := fnd_flex_ext.get_message;
      debug_msg('Invalid code combination: ' || 
            fnd_flex_ext.concatenate_segments(l_seg_array.count, l_seg_array, 
                  fnd_flex_ext.get_delimiter('SQLGL', 'GL#', g_chart_id) )
      );
      debug_msg('--> ' || p_error_text);
   ELSE
      p_error_text := NULL;
   END IF;
   RETURN l_result;
END valid_code_combination;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      map_user_category_name
--  PURPOSE
--      Maps the value of the file Record Category to the Oracle User Journal Category Name
--  RETURNS
--      User Journal Category Name
-- --------------------------------------------------------------------------------------------------
PROCEDURE map_user_category_name
(
   p_file_category       IN   VARCHAR2,
   p_user_category_name  OUT  VARCHAR2
)
IS
BEGIN
   IF g_category_cache.EXISTS(p_file_category) THEN
      p_user_category_name := g_category_cache(p_file_category);
   ELSE
      SELECT user_je_category_name
      INTO   p_user_category_name
      FROM   gl_je_categories_vl
      WHERE  upper(user_je_category_name) = upper(p_file_category);
      g_category_cache(p_file_category) := p_user_category_name;
   END IF;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_user_category_name := NULL;
END;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--       insert_offset_from_temp
--  PURPOSE
--       Copies the current OFFSET rows of the temporary table into the Transform table
-- --------------------------------------------------------------------------------------------------
PROCEDURE insert_offset_from_temp
IS
BEGIN
   INSERT INTO xxgl_payroll_detail_tfm
   SELECT  
       xxgl_payroll_record_id_s.NEXTVAL,
       SOURCE_RECORD_ID,
       SET_OF_BOOKS_ID,
       ACCOUNTING_DATE,
       DATE_CREATED,
       CURRENCY_CODE,
       ACTUAL_FLAG,
       USER_JE_CATEGORY_NAME,
       USER_JE_SOURCE_NAME,
       SEGMENT1,
       SEGMENT2,
       SEGMENT3,
       SEGMENT4,
       SEGMENT5,
       SEGMENT6,
       SEGMENT7,
       ENTERED_DR,
       ENTERED_CR,
       REFERENCE1,
       REFERENCE2,
       REFERENCE4,
       REFERENCE5,
       REFERENCE6,
       REFERENCE7,
       REFERENCE8,
       REFERENCE10,
       REFERENCE23,
       REFERENCE24,
       REFERENCE25,
       REFERENCE26,
       REFERENCE27,
       REFERENCE28,
       REFERENCE29,
       REFERENCE30,
       GROUP_ID,
       OFFSET_FLAG,
       RUN_ID,
       RUN_PHASE_ID,
       STATUS,
       CREATED_BY,
       SYSDATE
   FROM xxgl_payroll_detail_tmp
   WHERE offset_flag = 'Y';
   debug_msg('inserted ' || SQL%ROWCOUNT || ' offset rows into xxgl_payroll_detail_tfm');
END insert_offset_from_temp;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--       initialise_temp_table
--  PURPOSE
--       Inserts the current contents of the TFM table into a temporary buffer area (temporary table)
-- --------------------------------------------------------------------------------------------------
PROCEDURE initialise_temp_table
IS
BEGIN
   DELETE FROM xxgl_payroll_detail_tmp;
   INSERT INTO xxgl_payroll_detail_tmp
      SELECT * FROM xxgl_payroll_detail_tfm;
END initialise_temp_table;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      apply_delete_rules
--  PURPOSE
--      Applies configured "Delete" style journal business rules against a set of journal data.
--  PARAMETERS
--      p_run_id              Current run number
--      p_rule_lookup_type    Rule lookup type (FND_LOOKUP_VALUE.LOOKUP_TYPE)
--  DESCRIPTION
--      Rules are defined in common lookups using the Common Lookups form.
--      To maintain a proper audit of stage table data, rows are not actually deleted.  Rather, rows to
--      be deleted are inserted into a shadow stage table (xxgl_payroll_detail_del) which is then as a filter
--      in the main cursor of the transform process 
-- --------------------------------------------------------------------------------------------------
PROCEDURE apply_delete_rules
(
   p_run_id            IN   NUMBER,
   p_rule_lookup_type  IN VARCHAR2
) IS
   l_sql               VARCHAR2(600);
   t_del_rules_tab     xxgl_rule_pkg.t_rules_lookup_tab;
   t_categories_tab    xxgl_rule_pkg.t_varchar_tab_type;
BEGIN
   -- Clear out the temporary table
   DELETE FROM xxgl_payroll_detail_del WHERE run_id = p_run_id;

   -- Get the list of Delete rules
   xxgl_rule_pkg.lookup_rules('DEL', p_rule_lookup_type, t_del_rules_tab);

   FOR i IN 1..t_del_rules_tab.COUNT
   LOOP
      log_msg(' ');
      log_msg('Rule: ' || t_del_rules_tab(i).lookup_code);
      log_msg('Filter SQL: ' || t_del_rules_tab(i).filter_sql);
      log_msg('Categories: ' || t_del_rules_tab(i).category1 || '|' 
              || t_del_rules_tab(i).category2 || '|' || t_del_rules_tab(i).category3 
              || '|' || t_del_rules_tab(i).category4 || '|' || t_del_rules_tab(i).category5 
              || '|' || t_del_rules_tab(i).category6);

      l_sql := 'insert into xxgl_payroll_detail_del select * from xxgl_payroll_detail_stg where 1=1';
      -- Filter SQL
      IF t_del_rules_tab(i).filter_sql IS NOT NULL THEN
         l_sql := l_sql || ' and ' || t_del_rules_tab(i).filter_sql;
      END IF;
      -- Categories filter
      t_categories_tab := xxgl_rule_pkg.parse_rule_categories(t_del_rules_tab(i));
      IF t_categories_tab.COUNT > 0 THEN
         l_sql := l_sql || ' and upper(record_category) in ' || xxgl_rule_pkg.format_sql_in_set(t_categories_tab, TRUE);
      END IF;
      log_msg('  - SQL: ' || l_sql);
      -- Execute the SQL
      EXECUTE IMMEDIATE l_sql;
      log_msg('  - Row Count: ' || SQL%ROWCOUNT || ' rows');
   END LOOP;
END apply_delete_rules;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      apply_journal_rules
--  PURPOSE
--      Applies configured journal business rules against a set of journal data.
--      This procedure name is a bit of a misnomer because OFFSET rules are actually insertions, not updates.
--      Nevertheless they operate on a set of data in the same way.
--      At the time of implementation this procedure is used for Extract (EXT) rules and Offset (OFF) rules
--  PARAMETERS
--      p_run_id              Current run number
--      p_rule_type           Rule type (e.g. EXT, OFF), corresponds to FND_LOOKUP_VALUE.TAG
--      p_rule_lookup_type    Rule lookup type (FND_LOOKUP_VALUE.LOOKUP_TYPE)
--      p_target_table        The table holding the data to which the rules are applied (i.e. updated)
--                            The table must be of the same structure as the TFM table.
--  DESCRIPTION
--      Rules are defined in common lookups using the Common Lookups form.
--      Flexfields of the lookup code are used to specify actions against the target table data
--        1) update_sql (attribute7) contains a fragment of SQL SET statement to set values to various columns
--           e.g. authority=to_char(to_number(authority)+1, '0000')
--        2) filter_sql (attribute8) contains a fragment of SQL WHERE clause to filter the selection of rows
--           e.g. to_number(authority) between 2000 and 2999
--        3) t_categories_tab contains a list of category names that further restrict the selection of rows
--
--      In the case of update_sql and filter_sql, segment names are translated to application column names
--      e.g. authority=to_char(to_number(authority)+1, '0000')
--      becomes SEGMENT4=to_char(to_number(SEGMENT4)+1, '0000')
-- --------------------------------------------------------------------------------------------------
PROCEDURE apply_journal_rules
(
   p_run_id            IN  NUMBER,
   p_rule_type         IN  VARCHAR2,
   p_accrual_option    IN  VARCHAR2,
   p_rule_lookup_type  IN  VARCHAR2,
   p_target_table      IN  VARCHAR2,
   p_year              IN  NUMBER,
   p_pay_num           IN  NUMBER
) IS
   CURSOR c_start_num IS
      SELECT TO_NUMBER(tag) start_num
      FROM   fnd_lookup_values
      WHERE  lookup_type = 'XXGL_CHRIS_START_RUNNO'
      AND    TO_NUMBER(SUBSTR(lookup_code, INSTR(lookup_code, ':', -1) + 1, 5)) = g_sob_id
      AND    TO_NUMBER(SUBSTR(lookup_code, 1, INSTR(lookup_code, ':', -1) - 1)) = p_year;

   l_sql               VARCHAR2(600);
   t_rules_tab         xxgl_rule_pkg.t_rules_lookup_tab;
   t_categories_tab    xxgl_rule_pkg.t_varchar_tab_type;
   l_update_sql        VARCHAR2(150);
   l_start_num         NUMBER;
BEGIN
   -- Get the list of Extract rules
   xxgl_rule_pkg.lookup_rules(p_rule_type, p_rule_lookup_type, t_rules_tab);

   FOR i IN 1..t_rules_tab.COUNT
   LOOP
      log_msg(' ');
      log_msg('Rule: ' || t_rules_tab(i).lookup_code);
      log_msg('Accrual Option: ' || p_accrual_option);
      log_msg('Update SQL: ' || t_rules_tab(i).update_sql);
      log_msg('Prepay Update SQL: ' || t_rules_tab(i).prepay_update_sql);
      log_msg('Filter SQL: ' || t_rules_tab(i).filter_sql);
      log_msg('Categories: ' || t_rules_tab(i).category1 || '|' || t_rules_tab (i).category2 || '|' 
              || t_rules_tab(i).category3 || '|' || t_rules_tab(i).category4 || '|' 
              || t_rules_tab(i).category5|| '|' || t_rules_tab(i).category6);

      -- If the program is run in Prepayment mode, then use the prepayment update
      -- configuration instead of the normal (i.e. Accrual) update
      -- This is only for OFF set rules
      IF ( p_rule_type = 'OFF' AND 
           p_accrual_option = 'P' AND 
           t_rules_tab(i).prepay_update_sql IS NOT NULL )
      THEN
         debug_msg('Setting Update Clause to Prepay Update Clause');
         l_update_sql := t_rules_tab(i).prepay_update_sql;
      ELSE
         l_update_sql := t_rules_tab(i).update_sql;
      END IF;

      IF l_update_sql IS NOT NULL THEN
         -- Build SQL Clause
         l_sql := 'update ' || p_target_table || ' set reference23 = ''' || p_rule_type || ''', ';
         IF t_rules_tab(i).lookup_code LIKE '%OFF%' THEN
            -- Offset rows must be flagged as such so that they are copied into the transform table
            -- The entered_cr and entered_dr values need to be swapped, but only if it hasn't already been swapped
            l_sql := l_sql || 'offset_flag = ''Y'', entered_dr = decode(nvl(offset_flag,''N''), ''Y'', entered_dr, entered_cr), entered_cr = decode(nvl(offset_flag,''N''), ''Y'', entered_cr, entered_dr), ';
         END IF;

         -- Special logic for date/run sequence substitution
         OPEN c_start_num;
         FETCH c_start_num INTO l_start_num;
         IF c_start_num%FOUND THEN
            l_start_num := NVL(p_pay_num, 0) - l_start_num;
            l_update_sql := replace(l_update_sql, 'YYYYXX', p_year || LPAD(l_start_num, 2, '0'));
         ELSE
            log_msg('Unable to determine start number from lookup XXGL_CHRIS_START_RUNNO.');
         END IF;
         CLOSE c_start_num;

         -- Replace segment names with application column names
         l_sql := l_sql || xxgl_rule_pkg.replace_segment_name(l_update_sql, g_sob_id); 
         l_sql := l_sql || ' where 1=1'; -- ease of use to keep the next bit simple

         -- Append configured Filter clause
         IF t_rules_tab(i).filter_sql IS NOT NULL THEN
            l_sql := l_sql || ' and ' || xxgl_rule_pkg.replace_segment_name(t_rules_tab(i).filter_sql, g_sob_id);
         END IF;

         -- Append configured Category filter clause
         t_categories_tab := xxgl_rule_pkg.parse_rule_categories(t_rules_tab(i));
         IF t_categories_tab.COUNT > 0 THEN
            l_sql := l_sql || ' and upper(user_je_category_name) in ' || xxgl_rule_pkg.format_sql_in_set(t_categories_tab, TRUE);
         END IF;
         log_msg('  - SQL: ' || l_sql);

         -- Execute the SQL
         EXECUTE IMMEDIATE l_sql;
         log_msg('  - Row Count: ' || SQL%ROWCOUNT || ' rows');
      END IF;
   END LOOP;
END apply_journal_rules;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      apply_intercompany_rules
--  PURPOSE
--      Applies configured intercompany business rules against a set of journal data.
--  PARAMETERS
--      p_run_id              Current run number
--      p_rule_lookup_type    Rule lookup type (FND_LOOKUP_VALUE.LOOKUP_TYPE)
--  DESCRIPTION
--      Rules are defined in common lookups using the Common Lookups form.
--      Flexfields of the lookup code are used to specify actions against the target table data
--        1) update_sql (attribute7) contains an overlay account code combination 
--           e.g. -92011-000-0000-0000-REMUSAUT
--           this would override segments2-7 with the values shown, but keep segment1
--        2) filter_sql (attribute8) contains a fragment of SQL WHERE clause to filter the selection of rows
--           e.g. to_number(authority) between 2000 and 2999
--        3) t_categories_tab contains a list of category names that further restrict the selection of rows
--      Rows are selected by a GROUP BY clause, the account is overlayed, then the result inserted
--      back into the TFM table.
-- --------------------------------------------------------------------------------------------------
PROCEDURE apply_intercompany_rules
(
   p_run_id            IN  NUMBER,
   p_rule_lookup_type  IN  VARCHAR2
) IS
   TYPE t_int_tab_type           IS TABLE OF xxgl_payroll_detail_tfm%rowtype INDEX BY BINARY_INTEGER;
   TYPE t_int_ref_cur_type       IS REF CURSOR;
   t_int                   t_int_tab_type;
   c_int                   t_int_ref_cur_type;
   t_overlay_account_varr  xxgl_rule_pkg.t_segment_array_type;
   l_sql                   VARCHAR2(10000);
   t_rules_tab             xxgl_rule_pkg.t_rules_lookup_tab;
   t_categories_tab        xxgl_rule_pkg.t_varchar_tab_type;
   --
   -- Convenience procedure to format segment values into selection columns
   --
   PROCEDURE format_overlay_values(p_varr IN OUT NOCOPY xxgl_rule_pkg.t_segment_array_type)
   IS
   BEGIN
      FOR j IN p_varr.FIRST..p_varr.LAST
      LOOP
         IF p_varr(j) IS NOT NULL THEN
            -- wrap with quotes to make it a literal value
            p_varr(j) := '''' || p_varr(j) || '''';
         ELSE
            -- replace with column name
            p_varr(j) := 'SEGMENT'||j;
         END IF;
      END LOOP;
   END format_overlay_values;
   --
   -- Convenience procedure to calculate amounts and generate primary keys
   --
   PROCEDURE calculate_amounts(p_int IN OUT NOCOPY t_int_tab_type)
   IS 
      l_amount   NUMBER;

   BEGIN
      FOR i IN p_int.FIRST..p_int.LAST
      LOOP
         /*
         IF p_int(i).entered_dr > p_int(i).entered_cr THEN
            p_int(i).entered_cr := p_int(i).entered_dr - p_int(i).entered_cr;
            p_int(i).entered_dr := 0;
         ELSIF p_int(i).entered_cr > p_int(i).entered_dr THEN
            p_int(i).entered_dr := p_int(i).entered_cr - p_int(i).entered_dr;
            p_int(i).entered_cr := 0;
         END IF;
         */
         l_amount := NVL(p_int(i).entered_dr, 0) - NVL(p_int(i).entered_cr, 0);
         IF SIGN(l_amount) = 1 THEN
            p_int(i).entered_dr := l_amount;
            p_int(i).entered_cr := NULL;
         ELSE
            p_int(i).entered_dr := NULL;
            p_int(i).entered_cr := ABS(l_amount);
         END IF;
         -- Update the RECORD_ID for each row
         SELECT xxgl_payroll_record_id_s.NEXTVAL
         INTO p_int(i).record_id
         FROM DUAL;
      END LOOP;
   END calculate_amounts;
   --
   -- Convenience procedure for building the base query
   --
   PROCEDURE build_base_query(p_varr IN OUT NOCOPY xxgl_rule_pkg.t_segment_array_type, p_sql OUT VARCHAR2)
   IS
   BEGIN
      p_sql := 
        'SELECT 1 AS RECORD_ID, 
            MIN(record_id) AS SOURCE_RECORD_ID,
            SET_OF_BOOKS_ID,
            ACCOUNTING_DATE,
            SYSDATE,
            CURRENCY_CODE,
            ACTUAL_FLAG,
            USER_JE_CATEGORY_NAME,
            USER_JE_SOURCE_NAME,
            ' || p_varr(1) || ',
            ' || p_varr(2) || ',
            ' || p_varr(3) || ',
            ' || p_varr(4) || ',
            ' || p_varr(5) || ',
            ' || p_varr(6) || ',
            ' || p_varr(7) || ',
            SUM(ENTERED_DR) as dr_total,
            SUM(ENTERED_CR) as cr_total,
            REFERENCE1,
            REFERENCE2,
            REFERENCE4,
            REFERENCE5,
            REFERENCE6,
            REFERENCE7,
            REFERENCE8,
            REFERENCE10,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            GROUP_ID,
            OFFSET_FLAG,
            RUN_ID,
            RUN_PHASE_ID,
            STATUS,
            CREATED_BY,
            SYSDATE
         FROM xxgl_payroll_detail_tfm
         WHERE 1=1';
   END build_base_query;
   --
   -- Convenience procedure for adding the GROUP BY clause
   --
   PROCEDURE append_group_by(p_varr IN OUT NOCOPY xxgl_rule_pkg.t_segment_array_type, p_sql IN OUT NOCOPY VARCHAR2)
   IS
   BEGIN
      p_sql := p_sql || ' GROUP BY 1,
            SET_OF_BOOKS_ID,
            ACCOUNTING_DATE,
            SYSDATE,
            CURRENCY_CODE,
            ACTUAL_FLAG,
            USER_JE_CATEGORY_NAME,
            USER_JE_SOURCE_NAME,
            ' || p_varr(1) || ',
            ' || p_varr(2) || ',
            ' || p_varr(3) || ',
            ' || p_varr(4) || ',
            ' || p_varr(5) || ',
            ' || p_varr(6) || ',
            ' || p_varr(7) || ',
            REFERENCE1,
            REFERENCE2,
            REFERENCE4,
            REFERENCE5,
            REFERENCE6,
            REFERENCE7,
            REFERENCE8,
            REFERENCE10,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            GROUP_ID,
            OFFSET_FLAG,
            RUN_ID,
            RUN_PHASE_ID,
            STATUS,
            CREATED_BY,
            SYSDATE
            HAVING NVL(SUM(ENTERED_DR), 0) <> NVL(SUM(ENTERED_CR), 0)';
   END append_group_by;
BEGIN
   -- Get the list of Extract rules
   xxgl_rule_pkg.lookup_rules('INT', p_rule_lookup_type, t_rules_tab);
   IF t_rules_tab.COUNT = 0 THEN
      RETURN;
   END IF;
   -- Process each rule
   FOR i IN 1..t_rules_tab.COUNT
   LOOP
      log_msg(' ');
      log_msg('Rule: ' || t_rules_tab(i).lookup_code);
      log_msg('Update SQL: ' || t_rules_tab(i).update_sql);
      log_msg('Filter SQL: ' || t_rules_tab(i).filter_sql);
      log_msg('Categories: ' || t_rules_tab(i).category1 || '|' || t_rules_tab (i).category2 || '|' 
              || t_rules_tab(i).category3 || '|' || t_rules_tab(i).category4 || '|' 
              || t_rules_tab(i).category5|| '|' || t_rules_tab(i).category6);

      -- Override segments from configured Update clause
      IF t_rules_tab(i).update_sql IS NOT NULL THEN
         t_overlay_account_varr := xxgl_rule_pkg.to_varray(t_rules_tab(i).update_sql);
         format_overlay_values(t_overlay_account_varr);
      END IF;
      -- Build the base query
      build_base_query(t_overlay_account_varr, l_sql);
      -- Append configured Filter clause
      IF t_rules_tab(i).filter_sql IS NOT NULL THEN
         l_sql := l_sql || ' AND ' || xxgl_rule_pkg.replace_segment_name(t_rules_tab(i).filter_sql, g_sob_id);
      END IF;
      -- Append configured Category filter clause
      t_categories_tab := xxgl_rule_pkg.parse_rule_categories(t_rules_tab(i));
      IF t_categories_tab.COUNT > 0 THEN
         l_sql := l_sql || ' and upper(user_je_category_name) in ' || xxgl_rule_pkg.format_sql_in_set(t_categories_tab, TRUE);
      END IF;
      -- Append the GROUP BY
      append_group_by(t_overlay_account_varr, l_sql);
      log_msg('  - SQL: ' || l_sql);
      -- Execute the SQL collecting the result
      OPEN  c_int FOR l_sql;
      FETCH c_int BULK COLLECT INTO t_int;
      CLOSE c_int;
      debug_msg('intercompany select fetched ' || t_int.COUNT || ' rows');
      IF t_int.COUNT > 0 THEN
         calculate_amounts(t_int);
         -- Now insert these back into the TFM table
         FORALL i IN t_int.FIRST..t_int.LAST
            INSERT INTO xxgl_payroll_detail_tfm values t_int(i);
         log_msg('  - Intercompany Insert Row Count: ' || SQL%ROWCOUNT || ' rows');
      END IF;
   END LOOP;
END apply_intercompany_rules;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      delete_fwk_table_data
--  PURPOSE
--      Deletes all data from the intermediary framework tables.
-- --------------------------------------------------------------------------------------------------
PROCEDURE delete_fwk_table_data
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   DELETE FROM xxgl_payroll_header_stg;
   DELETE FROM xxgl_payroll_detail_stg;
   DELETE FROM xxgl_payroll_detail_del;
   DELETE FROM xxgl_payroll_trailer_stg;
   DELETE FROM xxgl_payroll_detail_tfm;
   COMMIT;
END delete_fwk_table_data;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      update_stage_run_ids
--  PURPOSE
--      Updates the stage tables with values for run_id, run_phase_id, status, created_by and 
--      creation_date where these values are null.  They would be null if they have only just been 
--      loaded.
-- --------------------------------------------------------------------------------------------------
PROCEDURE update_stage_run_ids
(
   p_run_id              IN   NUMBER,
   p_run_phase_id        IN   NUMBER,
   p_status              IN   VARCHAR2,
   p_detail_row_count    OUT  NUMBER
)
IS
BEGIN
   UPDATE xxgl_payroll_header_stg
   SET    run_id = p_run_id,
          run_phase_id = p_run_phase_id,
          status = p_status,
          created_by = g_user_id,
          creation_date = SYSDATE
   WHERE  run_id || run_phase_id || status IS NULL;

   UPDATE xxgl_payroll_trailer_stg
   SET    run_id = p_run_id,
          run_phase_id = p_run_phase_id,
          status = p_status,
          created_by = g_user_id,
          creation_date = SYSDATE
   WHERE  run_id || run_phase_id || status IS NULL;

   UPDATE xxgl_payroll_detail_stg
   SET    run_id = p_run_id,
          run_phase_id = p_run_phase_id,
          status = p_status,
          created_by = g_user_id,
          creation_date = SYSDATE
   WHERE  run_id || run_phase_id || status IS NULL;
    p_detail_row_count := SQL%ROWCOUNT;
END update_stage_run_ids;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      deletion_report
--  PURPOSE
--      Provides a simple report of which records were deleted from the CHRIS21 file
-- --------------------------------------------------------------------------------------------------
PROCEDURE deletion_report
(
   p_run_id              IN   NUMBER
) IS
   CURSOR c_del IS
      SELECT *
      FROM   xxgl_payroll_detail_del
      WHERE  run_id = p_run_id
      ORDER BY record_category;
   l_catgory_sub_total        NUMBER := 0;
   l_wip_category             xxgl_payroll_detail_del.record_category%TYPE;
   l_format_mask              VARCHAR2(30);
BEGIN
   fnd_file.put_line(fnd_file.output, '                      Deletions Report                                     ');
   fnd_file.put_line(fnd_file.output, '---------------------------------------------------------------------------');
   l_format_mask := fnd_currency.get_format_mask(g_sob_currency, 20);
   FOR r_del IN c_del
   LOOP
      IF r_del.record_category <> nvl(l_wip_category, 'x') THEN
         IF l_wip_category IS NOT NULL THEN
            fnd_file.put_line(fnd_file.output, rpad(' ', 50, ' ') 
               || lpad('-', 17, '-'));
            fnd_file.put_line(fnd_file.output, rpad('Total:', 49, ' ') 
               || lpad(to_char(l_catgory_sub_total, l_format_mask), 17, ' '));
            fnd_file.put_line(fnd_file.output,' ');
         END IF;
         fnd_file.put_line(fnd_file.output, 'Category: ' || r_del.record_category);
         l_wip_category := r_del.record_category;
         l_catgory_sub_total := 0;
      END IF;
      fnd_file.put_line(fnd_file.output, '  ' || rpad(r_del.record_type, 12, ' ') 
         || r_del.organisation || '-' || r_del.account || '-' || r_del.cost_centre || '-'
         || r_del.authority || '-' || r_del.project || '-' || r_del.output || '-'
         || r_del.identifier || lpad(to_char(r_del.amount, l_format_mask), 17, ' '));
      l_catgory_sub_total := l_catgory_sub_total + r_del.amount;
   END LOOP;
   IF l_catgory_sub_total > 0 THEN
      fnd_file.put_line(fnd_file.output, rpad(' ', 50, ' ') || lpad('-', 17, '-'));
      fnd_file.put_line(fnd_file.output, rpad('Total:', 49, ' ') 
                        || lpad(to_char(l_catgory_sub_total, l_format_mask), 17, ' '));
      fnd_file.put_line(fnd_file.output,' ');
      fnd_file.put_line(fnd_file.output, '            **      End of Report    **            ');
   ELSE
      fnd_file.put_line(fnd_file.output, '            **    No records deleted    **         ');
   END IF;
END deletion_report;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      update_stage_tables_status
--  PURPOSE
--      Updates the stage tables with a new status.
-- --------------------------------------------------------------------------------------------------
PROCEDURE update_stage_tables_status
(
   p_run_id              IN   NUMBER,
   p_status              IN VARCHAR2
)
IS
BEGIN
   UPDATE xxgl_payroll_header_stg 
   SET    status = p_status 
   WHERE  run_id = p_run_id;
   debug_msg('updated ' || SQL%ROWCOUNT || ' header stage rows to processed status');

   UPDATE xxgl_payroll_trailer_stg 
   SET    status = p_status 
   WHERE  run_id = p_run_id;
   debug_msg('updated ' || SQL%ROWCOUNT || ' trailer stage rows to processed status');

   UPDATE xxgl_payroll_detail_stg 
   SET    status = p_status 
   WHERE  run_id = p_run_id;
   debug_msg('updated ' || SQL%ROWCOUNT || ' detail stage rows to processed status');
END update_stage_tables_status;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      stage
--  PURPOSE
--       Loads file data into the staging tables.
--  DESCRIPTION
--       Common Interface Framework program XXINTSQLLDR is used to load data into the stage tables
--  RETURNS
--       True if successful, otherwise False
-- --------------------------------------------------------------------------------------------------
FUNCTION stage
(
   p_run_id              IN   NUMBER,
   p_run_phase_id        OUT  NUMBER,
   p_request             IN OUT NOCOPY xxint_common_pkg.CONTROL_RECORD_TYPE,
   p_inbound_directory   IN VARCHAR2,
   p_outbound_directory  IN VARCHAR2,
   p_staging_directory   IN VARCHAR2,
   p_archive_directory   IN VARCHAR2,
   p_file                IN VARCHAR2,
   p_log                 IN VARCHAR2,
   p_bad                 IN VARCHAR2,
   p_ctl                 IN VARCHAR2
)  RETURN BOOLEAN
IS
   l_run_id              NUMBER := p_run_id;
   l_run_phase_id        NUMBER;
   l_sqlldr_req_id       NUMBER;
   l_message             VARCHAR2(240);
   l_stg_rows_loaded     NUMBER := 0;
   r_srs_xxintsqlldr     r_srs_request_type;
BEGIN
   /**************************/
   /* Initialize run phase   */
   /**************************/
   l_run_phase_id := dot_common_int_pkg.start_run_phase
      ( p_run_id                  => l_run_id,
        p_phase_code              => 'STAGE',
        p_phase_mode              => NULL,
        p_int_table_name          => p_file,
        p_int_table_key_col1      => NULL,
        p_int_table_key_col_desc1 => NULL,
        p_int_table_key_col2      => NULL,
        p_int_table_key_col_desc2 => NULL,
        p_int_table_key_col3      => NULL,
        p_int_table_key_col_desc3 => NULL);

   debug_msg('interface framework (run_stage_id=' || l_run_phase_id || ')');
   p_run_phase_id := l_run_phase_id;

   /****************************/
   /* Framework SQL*Loader     */
   /****************************/
   l_sqlldr_req_id := submit_xxintsqlldr
      ( p_inbound_directory,
        p_outbound_directory,
        p_staging_directory,
        p_archive_directory,
        p_file,
        p_log,
        p_bad,
        p_ctl );
   
   debug_msg('load file ' || p_file || ' to staging (request_id=' || l_sqlldr_req_id || ')');

   /******************************/
   /* Interface Control Record   */
   /******************************/
   p_request.file_name := p_file;
   p_request.sub_request_id := l_sqlldr_req_id;
   p_request.sub_request_program_id := NULL;
   xxint_common_pkg.interface_request(p_request);

   /******************************/
   /* Wait for request           */
   /******************************/
   wait_for_request(l_sqlldr_req_id, 5, r_srs_xxintsqlldr);

   IF NOT ( r_srs_xxintsqlldr.srs_dev_phase = 'COMPLETE' AND
            r_srs_xxintsqlldr.srs_dev_status IN ('NORMAL','WARNING') ) THEN
      l_message := replace(substr(g_error_message_03, 11, 100), '$INT_FILE', p_file);
      log_msg(g_error || l_message);
      p_request.error_message := l_message;
      p_request.status := 'ERROR';
   ELSE
      p_request.status := 'SUCCESS';
      /***************************************/
      /* Update the stage rows with run ids  */
      /***************************************/
      update_stage_run_ids(l_run_id, l_run_phase_id, 'NEW', l_stg_rows_loaded);
      debug_msg('updated ' || l_stg_rows_loaded || ' stage runs ids with run_id '||l_run_id);
   END IF;

   /******************************/
   /* Interface Control Record   */
   /******************************/
   xxint_common_pkg.interface_request(p_request);
   debug_msg('file staging (status=' || p_request.status || ')');

   /**********************/
   /* Update run phase   */
   /**********************/
   dot_common_int_pkg.update_run_phase
          (p_run_phase_id => l_run_phase_id,
           p_src_code     => g_src_code,
           p_rec_count    => l_stg_rows_loaded,
           p_hash_total   => NULL,
           p_batch_name   => g_int_batch_name);

   /*******************/
   /* End run phase   */
   /*******************/
   dot_common_int_pkg.end_run_phase
             (p_run_phase_id  => l_run_phase_id,
              p_status        => 'SUCCESS',
              p_error_count   => 0,
              p_success_count => l_stg_rows_loaded);

   /*******************/
   /* Return status   */
   /*******************/
   IF (p_request.status = 'SUCCESS') THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;

END stage;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      transform
--  PURPOSE
--       Transforms data from Staging tables to the Transform table.
--  DESCRIPTION
--       The function applies the business rules defined in the lookup in the following order
--         1) DEL (delete) rules
--         2) EXT (extract) rules
--         3) OFF (offset) rules
--       Updates the Stage row status to PROCESSED or ERROR as it goes
--  RETURNS
--       True if successful, otherwise False
-- --------------------------------------------------------------------------------------------------
FUNCTION transform
(
   p_run_id          IN   NUMBER,
   p_run_phase_id    OUT  NUMBER,
   p_file_name       IN   VARCHAR2,
   p_int_mode        IN   VARCHAR2,
   p_accrual_option  IN   VARCHAR2
) RETURN BOOLEAN
IS
   l_run_id                 NUMBER := p_run_id;
   l_run_phase_id           NUMBER;
   l_total                  NUMBER := 0;
   l_total_amount           NUMBER := 0;
   l_format_mask            VARCHAR2(20);
   r_error                  dot_int_run_phase_errors%ROWTYPE;
   b_stg_row_valid          BOOLEAN := TRUE;
   l_val_err_count          NUMBER := 0;
   l_tfm_count              NUMBER := 0;
   l_stg_count              NUMBER := 0;
   l_status                 VARCHAR2(30);
   l_new_record_id          NUMBER;
   l_period_year            NUMBER;
   l_pay_count              NUMBER;
   l_entered_amount         NUMBER;
   l_flex_ext_msg           VARCHAR2(200);
   l_category_msg           VARCHAR2(200);
   l_user_category_name     gl_je_categories_tl.user_je_category_name%TYPE;
   l_next_period_name       gl_periods.period_name%TYPE;
   r_gl_je_batch            gl_je_batches%ROWTYPE;
   l_batch_desc_prefix      gl_je_batches.description%TYPE;
   l_batch_description      gl_je_batches.description%TYPE;
   r_header_rec             xxgl_payroll_header_stg%ROWTYPE;
   r_trailer_rec            xxgl_payroll_trailer_stg%ROWTYPE;
   z_non_detail_record_id   CONSTANT NUMBER := -1;
   b_validation_errors      BOOLEAN := FALSE;
   e_file_validation_error  EXCEPTION;
   l_dr_total               NUMBER := 0;
   l_cr_total               NUMBER := 0;

   CURSOR c_stg(p_run_id IN NUMBER) IS
      SELECT *
      FROM   xxgl_payroll_detail_stg
      WHERE  run_id = p_run_id
        AND  record_id NOT IN 
          ( SELECT  record_id 
              FROM  xxgl_payroll_detail_del 
             WHERE  run_id = p_run_id )
      FOR UPDATE OF status
      ORDER  BY 1; -- record_id

   r_stg              c_stg%ROWTYPE;
   r_tfm              xxgl_payroll_detail_tfm%ROWTYPE;

BEGIN
   /************************************/
   /* Initialize Transform Run Phase   */
   /************************************/
   l_run_phase_id := dot_common_int_pkg.start_run_phase
      ( p_run_id                  => l_run_id,
        p_phase_code              => 'TRANSFORM',
        p_phase_mode              => p_int_mode,
        p_int_table_name          => 'XXGL_PAYROLL_DETAIL_STG',
        p_int_table_key_col1      => 'RECORD_TYPE',
        p_int_table_key_col_desc1 => 'PIN',
        p_int_table_key_col2      => NULL,
        p_int_table_key_col_desc2 => NULL,
        p_int_table_key_col3      => NULL,
        p_int_table_key_col_desc3 => NULL );

   p_run_phase_id := l_run_phase_id;
   r_error.run_id := l_run_id;
   r_error.run_phase_id := l_run_phase_id;

   debug_msg('interface framework (run_transform_id=' || l_run_phase_id || ')');

   SELECT COUNT(1), SUM(amount)
   INTO   l_total, l_total_amount
   FROM   xxgl_payroll_detail_stg
   WHERE  run_id = l_run_id;

   /**********************/
   /* Update run phase   */
   /**********************/
   dot_common_int_pkg.update_run_phase
          (p_run_phase_id => l_run_phase_id,
           p_src_code     => g_src_code,
           p_rec_count    => l_total,
           p_hash_total   => NULL,
           p_batch_name   => g_int_batch_name);

   /***********************************/
   /* Validate file control contents  */
   /***********************************/
   /*
   -- Header record
   -- 1) Must have a single header record
   -- 2) Run number must be valid
   */
   IF g_run_number IS NULL THEN
      SELECT NVL(MAX(DECODE(NVL(g_accrual_flag, 'N'), 'N', r.payroll_runno, r.payaccr_runno)), 0) + 1
      INTO   g_run_number
      FROM   xxgl_payroll_run_numbers r
      WHERE  r.set_of_books_id = g_sob_id;
   END IF;

   BEGIN
      SELECT * 
      INTO   r_header_rec
      FROM   xxgl_payroll_header_stg
      WHERE  run_id = l_run_id;

      IF g_run_number <> r_header_rec.run_number THEN
         r_error.record_id := z_non_detail_record_id;
         r_error.error_text := 'Run number is out of sequence';
         raise_error(r_error);
         log_msg(g_error || r_error.error_text);
         b_validation_errors := TRUE;
      END IF;

   EXCEPTION
      WHEN TOO_MANY_ROWS THEN
         r_error.record_id := z_non_detail_record_id;
         r_error.error_text := 'Duplicate Header records';
         raise_error(r_error);
         log_msg(g_error || r_error.error_text);
         b_validation_errors := TRUE;
   END;

   /*
   -- Trailer record
   -- 1) Must have a single trailer record
   -- 2) Record Total Amount must equal the sum of the detail amounts
   -- 3) Record Count must equal the number of detail lines
   */
   BEGIN
      SELECT * 
      INTO   r_trailer_rec
      FROM   xxgl_payroll_trailer_stg
      WHERE  run_id = l_run_id;
   EXCEPTION
      WHEN TOO_MANY_ROWS THEN
         r_error.record_id := z_non_detail_record_id;
         r_error.error_text := 'Duplicate Trailer records';
         raise_error(r_error);
         log_msg(g_error || r_error.error_text);
         b_validation_errors := TRUE;
   END;
   /*
   --  If unique Header or Trailer records cannot be determined stop here
   --  Otherwise keeep validating
   */
   IF b_validation_errors THEN
      RAISE e_file_validation_error;
   END IF;
   /*
   -- Record Total Amount
   */
   IF r_trailer_rec.record_total_amount <> l_total_amount THEN
      r_error.record_id := z_non_detail_record_id;
      l_format_mask := fnd_currency.get_format_mask(g_sob_currency, 20);
      r_error.error_text := 'Trailer Record Total Amount '
                            || to_char(r_trailer_rec.record_total_amount, l_format_mask)
                            || ' is not equal to the sum of Detail amount '
                            || to_char(l_total_amount, l_format_mask);
      raise_error(r_error);
      log_msg(g_error || r_error.error_text);
      b_validation_errors := TRUE;
   END IF;
   /*
   -- Record Count
   */
   IF r_trailer_rec.record_count <> l_total THEN
      r_error.record_id := z_non_detail_record_id;
      r_error.error_text := 'Trailer Record Count ' || r_trailer_rec.record_count 
                            || ' is not equal to the number of Detail lines ' || l_total;
      raise_error(r_error);
      log_msg(g_error || r_error.error_text);
      b_validation_errors := TRUE;
   END IF;
   /*
   -- Run Number
   -- 1) Must not have been processed by Oracle before.  
   -- Run number destination is the Batch Description, so check this.
   */
   IF g_accrual_flag = 'Y' THEN
      l_batch_desc_prefix := 'Payroll Accruals Journal Import ' || to_char(r_header_rec.run_number);
   ELSE
      l_batch_desc_prefix := 'Payroll Journal Import ' || to_char(r_header_rec.run_number);
   END IF;
   l_batch_description := l_batch_desc_prefix || ' ' || p_file_name;
   lookup_batch_by_desc_prefix(l_batch_desc_prefix, r_gl_je_batch);
   IF r_gl_je_batch.je_batch_id IS NOT NULL THEN
      r_error.record_id := z_non_detail_record_id;
      r_error.error_text := 'Run Number ' || r_header_rec.run_number || ' has already been processed on '  
                            || to_char(r_gl_je_batch.creation_date,'DD-MON-YYYY');
      raise_error(r_error);
      log_msg(g_error || r_error.error_text);
      b_validation_errors := TRUE;
   END IF;
   
   IF b_validation_errors THEN
      RAISE e_file_validation_error;
   END IF;

   /***********************************/
   /* Apply Delete (DEL) Rules        */
   /***********************************/
   apply_delete_rules(p_run_id, g_rule_lookup_type);

   /**********************/
   /* Process STG rows   */
   /**********************/
   OPEN c_stg(l_run_id);
   LOOP
      FETCH c_stg INTO r_stg;
      EXIT WHEN c_stg%NOTFOUND;
      -- initilise and increment 
      l_stg_count := l_stg_count + 1;
      l_entered_amount := NULL;
      b_stg_row_valid := TRUE;
      r_tfm := NULL;
      
      /***********************************/
      /* Validate                        */
      /***********************************/
      r_error.record_id := r_stg.record_id;
      r_error.int_table_key_val1 := r_stg.record_type; -- pin number (employee num)
      /*
      -- Validate Record Category 
      -- 1) Must be defined as a Journal Category
      */
      map_user_category_name(r_stg.record_category, l_user_category_name);
      IF l_user_category_name IS NULL THEN
         l_category_msg := 'Record Category ''' || r_stg.record_category 
                           || ''' is not defined as a Journal Category';
         log_msg(g_error || l_category_msg);
         -- only raise the error if the phase mode is a validation type mode
         IF p_int_mode = g_int_mode THEN
            r_error.error_text := l_category_msg;
            raise_error(r_error);
            b_stg_row_valid := FALSE;
         ELSE
            -- allow the invalid value through so it can be corrected in Oracle
            l_user_category_name := r_stg.record_category;
         END IF;
      END IF;
      /*
      -- Validate Code Combination 
      -- 1) Must exist, can be dynamically inserted if configured.
      */
      IF p_int_mode = g_int_mode AND NOT valid_code_combination(r_stg, l_flex_ext_msg) THEN
         log_msg(g_error || l_flex_ext_msg);
         -- only raise the error if the phase mode is a validation type mode
         IF p_int_mode = g_int_mode THEN
            r_error.error_text := l_flex_ext_msg;
            raise_error(r_error);
            b_stg_row_valid := FALSE;
         END IF;
      END IF;
      
      /***********************************/
      /* Transform / Mapping             */
      /***********************************/
      -- get the next record_id
      SELECT xxgl_payroll_record_id_s.NEXTVAL
      INTO   l_new_record_id
      FROM   DUAL;

      l_period_year := get_gl_period_year(r_stg.LAST_PAY_DATE);
      l_next_period_name := get_next_gl_period_name(r_stg.LAST_PAY_DATE);

      -- interface framework columns
      r_tfm.RECORD_ID := l_new_record_id;
      r_tfm.SOURCE_RECORD_ID := r_stg.RECORD_ID;
      r_tfm.RUN_ID := l_run_id;
      r_tfm.RUN_PHASE_ID := l_run_phase_id;
      r_tfm.STATUS := 'NEW';
      -- who columns
      r_tfm.CREATED_BY := g_user_id;
      r_tfm.CREATION_DATE := SYSDATE;
      -- interface columns
      r_tfm.SET_OF_BOOKS_ID := g_sob_id;
      r_tfm.ACCOUNTING_DATE := r_stg.LAST_PAY_DATE;
      r_tfm.DATE_CREATED := SYSDATE;
      r_tfm.CURRENCY_CODE := g_sob_currency;
      r_tfm.ACTUAL_FLAG := 'A';
      r_tfm.USER_JE_CATEGORY_NAME := l_user_category_name;
      r_tfm.USER_JE_SOURCE_NAME := g_user_je_source;
      r_tfm.SEGMENT1 := r_stg.ORGANISATION;
      r_tfm.SEGMENT2 := r_stg.ACCOUNT;
      r_tfm.SEGMENT3 := r_stg.COST_CENTRE;
      r_tfm.SEGMENT4 := r_stg.AUTHORITY;
      r_tfm.SEGMENT5 := r_stg.PROJECT;
      r_tfm.SEGMENT6 := r_stg.OUTPUT;
      r_tfm.SEGMENT7 := r_stg.IDENTIFIER;
      IF r_stg.AMOUNT > 0 THEN
         r_tfm.ENTERED_DR := r_stg.AMOUNT;
         r_tfm.ENTERED_CR := NULL;
      ELSE
         r_tfm.ENTERED_DR := NULL;
         r_tfm.ENTERED_CR := ABS(r_stg.AMOUNT);
      END IF;
      -- References
      r_tfm.REFERENCE1 := null; -- Batch Name to default during import
      r_tfm.REFERENCE2 := l_batch_description; -- Batch Description 
      IF g_accrual_flag = 'Y' THEN
         r_tfm.REFERENCE4 := 'Payroll Accruals as at ' || to_char(r_stg.last_pay_date, 'DD-MON-YYYY'); -- Journal Name 
         r_tfm.REFERENCE5 := 'Payroll Accrual ' || p_file_name; -- Journal Entry Description
         r_tfm.REFERENCE6 := 'PAY ACCRUAL ' ||  to_char(r_stg.last_pay_date,'DD-MON-YYYY') || ' SEQ '|| to_char(r_header_rec.run_number); -- Reference name or number
         r_tfm.REFERENCE7 := 'Yes'; -- Reversal flag
         r_tfm.REFERENCE8 := l_next_period_name; --Reversal period
      ELSE
         r_tfm.REFERENCE4 := 'Payroll as at ' || to_char(r_stg.last_pay_date, 'DD-MON-YYYY'); -- Journal Name 
         r_tfm.REFERENCE5 := 'Payroll and Oncost ' || p_file_name; -- Journal Entry Description
         r_tfm.REFERENCE6 := 'PAYROLL ' ||  to_char(r_stg.last_pay_date,'DD-MON-YYYY') || ' SEQ '|| to_char(r_header_rec.run_number); -- Reference name or number
         r_tfm.REFERENCE7 := NULL; -- Reversal flag
         r_tfm.REFERENCE8 := NULL; --Reversal period
      END IF;
      r_tfm.REFERENCE10 := r_tfm.REFERENCE5;
      r_tfm.GROUP_ID := l_run_id;
      -- GL Import References columns
      r_tfm.REFERENCE24 := r_stg.RECORD_TYPE;
      r_tfm.REFERENCE25 := SYSDATE;
      r_tfm.REFERENCE26 := r_stg.AMOUNT;
      r_tfm.REFERENCE27 := r_stg.COST_CENTRE;
      r_tfm.REFERENCE28 := to_char(r_header_rec.run_number);
      r_tfm.REFERENCE29 := r_tfm.ACCOUNTING_DATE;
      r_tfm.REFERENCE30 := r_tfm.USER_JE_SOURCE_NAME;
      
      /*************************************/
      /* Insert single row into TFM table  */
      /*************************************/
      IF (b_stg_row_valid) THEN
         BEGIN
            INSERT INTO xxgl_payroll_detail_tfm VALUES r_tfm;
            l_tfm_count := l_tfm_count + 1;
         EXCEPTION
            WHEN OTHERS THEN
               r_error.msg_code := SQLCODE;
               r_error.error_text := SQLERRM;
               raise_error(r_error);
               l_val_err_count := l_val_err_count + 1;
         END;
      ELSE
         UPDATE xxgl_payroll_detail_stg SET status = 'ERROR' WHERE CURRENT OF c_stg;
         l_val_err_count := l_val_err_count + 1;
      END IF;
   END LOOP;
   
   IF l_val_err_count > 0 THEN
      l_status := 'ERROR';
   ELSE
      -- initialise segment cache, which is used to map segment names to application columns
      xxgl_rule_pkg.populate_segment_col_cache(g_sob_id);
      -- copy rows from TFM to TMP
      initialise_temp_table; 
      -- get the number of payroll (or accrual) journal batches created this period year
      l_pay_count := get_journal_count(l_period_year, g_user_je_source, g_sob_id);

      /****************************************************/
      /* Apply Extract (EXT) Rules to the TFM table       */
      /****************************************************/
      apply_journal_rules(p_run_id, 'EXT', p_accrual_option, g_rule_lookup_type, 'XXGL_PAYROLL_DETAIL_TFM', l_period_year, r_header_rec.run_number); -- l_pay_count + 1);

      /****************************************************/
      /* Apply Offset (OFF) Rules to the temporary table  */
      /* then insert them into the TFM                    */
      /****************************************************/
      apply_journal_rules(p_run_id, 'OFF', p_accrual_option, g_rule_lookup_type, 'XXGL_PAYROLL_DETAIL_TMP', l_period_year, r_header_rec.run_number); -- l_pay_count + 1);
      insert_offset_from_temp;

      /****************************************************/
      /* Check that journal balances before applying      */
      /* offsets - otherwise the offset will incorporate  */
      /* this inbalance when calculating and hide the     */
      /* problem.  If the journal is not balanced at this */
      /* point it could indicate the EXT rules are        */
      /* are not working correctly                        */
      /****************************************************/
      get_journal_totals(p_run_id, l_dr_total, l_cr_total);
      IF l_dr_total <>  l_cr_total THEN
         l_format_mask := fnd_currency.get_format_mask(g_sob_currency, 20);
         r_error.record_id := z_non_detail_record_id;
         r_error.error_text := 'Journal does not balance after applying Extract rules. '
                               || 'DR total ' || to_char(l_dr_total, l_format_mask) 
                               || ', CR total ' || to_char(l_cr_total, l_format_mask);
         raise_error(r_error);
         log_msg(g_error || r_error.error_text);
         l_status := 'ERROR';
      ELSE
         /****************************************************/
         /* Apply Intercompany (INT) Rules                   */
         /****************************************************/
         apply_intercompany_rules(p_run_id, g_rule_lookup_type);

         /****************************************************/
         /* Update stage rows status                         */
         /****************************************************/
         update_stage_tables_status(p_run_id, 'PROCESSED');
         l_status := 'SUCCESS';
      END IF;
      
   END IF;

   /*******************/
   /* End run phase   */
   /*******************/
   dot_common_int_pkg.end_run_phase
      ( p_run_phase_id  => l_run_phase_id,
        p_status        => l_status,
        p_error_count   => l_val_err_count,
        p_success_count => l_tfm_count);

   IF l_status = 'ERROR' THEN
      RETURN FALSE;
   END IF;
   RETURN TRUE;

EXCEPTION
   WHEN e_file_validation_error THEN
      dot_common_int_pkg.end_run_phase
         ( p_run_phase_id  => l_run_phase_id,
           p_status        => 'ERROR',
           p_error_count   => l_total,
           p_success_count => 0);
      RETURN FALSE;      
END transform;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      load
--  PURPOSE
--       Loads data from the Transform table to the Open Interface table (GL_INTERFACE).
--  DESCRIPTION
--       Updates the Transform row status to PROCESSED or ERROR as it goes
--  RETURNS
--       True if successful, otherwise False
-- --------------------------------------------------------------------------------------------------
FUNCTION load
(
   p_run_id        IN   NUMBER,
   p_run_phase_id  OUT  NUMBER
)  RETURN BOOLEAN
IS
   CURSOR c_tfm IS
      SELECT *
      FROM   xxgl_payroll_detail_tfm
      WHERE  run_id = p_run_id
      ORDER  BY record_id
      FOR UPDATE OF status;

   r_tfm              c_tfm%ROWTYPE;
   l_run_id           NUMBER := p_run_id;
   l_run_phase_id     NUMBER;
   l_total            NUMBER := 0;
   l_error_count      NUMBER := 0;
   l_tfm_count        NUMBER := 0;
   l_load_count       NUMBER := 0;
   r_error            dot_int_run_phase_errors%ROWTYPE;
   l_status           VARCHAR2(240);
BEGIN
   /*******************************/
   /* Initialise Load Phase       */
   /*******************************/
   l_run_phase_id := dot_common_int_pkg.start_run_phase
      ( p_run_id                  => l_run_id,
        p_phase_code              => 'LOAD',
        p_phase_mode              => NULL,
        p_int_table_name          => 'XXGL_PAYROLL_DETAIL_TFM',
        p_int_table_key_col1      => 'RECORD_ID',
        p_int_table_key_col_desc1 => 'Record Id',
        p_int_table_key_col2      => NULL,
        p_int_table_key_col_desc2 => NULL,
        p_int_table_key_col3      => NULL,
        p_int_table_key_col_desc3 => NULL );

   p_run_phase_id := l_run_phase_id;
   r_error.run_id := l_run_id;
   r_error.run_phase_id := l_run_phase_id;
   debug_msg('interface framework (run_load_id=' || l_run_phase_id || ')');

   SELECT COUNT(1)
   INTO   l_total
   FROM   xxgl_payroll_detail_tfm
   WHERE  run_id = l_run_id;

   /*******************************/
   /* Update Load phase           */
   /*******************************/
   dot_common_int_pkg.update_run_phase
      ( p_run_phase_id => l_run_phase_id,
        p_src_code     => g_src_code,
        p_rec_count    => l_total,
        p_hash_total   => NULL,
        p_batch_name   => g_int_batch_name );

   OPEN c_tfm;
   LOOP
      FETCH c_tfm INTO r_tfm;
      EXIT WHEN c_tfm%NOTFOUND;
      l_tfm_count := l_tfm_count + 1;
      r_error.record_id := r_tfm.record_id;
      r_error.int_table_key_val1 := r_tfm.record_id;
      BEGIN
         INSERT INTO GL_INTERFACE
         (
             STATUS,
             SET_OF_BOOKS_ID,
             ACCOUNTING_DATE,
             DATE_CREATED,
             CURRENCY_CODE,
             ACTUAL_FLAG,
             USER_JE_CATEGORY_NAME,
             USER_JE_SOURCE_NAME,
             SEGMENT1,
             SEGMENT2,
             SEGMENT3,
             SEGMENT4,
             SEGMENT5,
             SEGMENT6,
             SEGMENT7,
             ENTERED_DR,
             ENTERED_CR,
             REFERENCE1,
             REFERENCE2,
             REFERENCE4,
             REFERENCE5,
             REFERENCE6,
             REFERENCE7,
             REFERENCE8,
             REFERENCE10,
             REFERENCE23,
             REFERENCE24,
             REFERENCE25,
             REFERENCE26,
             REFERENCE27,
             REFERENCE28,
             REFERENCE29,
             REFERENCE30,
             GROUP_ID,
             CREATED_BY
         ) VALUES
         (
             'NEW',
             r_tfm.SET_OF_BOOKS_ID,
             r_tfm.ACCOUNTING_DATE,
             r_tfm.DATE_CREATED,
             r_tfm.CURRENCY_CODE,
             r_tfm.ACTUAL_FLAG,
             decode(r_tfm.USER_JE_CATEGORY_NAME, 'Bonus', 'Payroll', r_tfm.USER_JE_CATEGORY_NAME),
             r_tfm.USER_JE_SOURCE_NAME,
             r_tfm.SEGMENT1,
             r_tfm.SEGMENT2,
             r_tfm.SEGMENT3,
             r_tfm.SEGMENT4,
             r_tfm.SEGMENT5,
             r_tfm.SEGMENT6,
             r_tfm.SEGMENT7,
             r_tfm.ENTERED_DR,
             r_tfm.ENTERED_CR,
             r_tfm.REFERENCE1,
             r_tfm.REFERENCE2,
             r_tfm.REFERENCE4,
             r_tfm.REFERENCE5,
             r_tfm.REFERENCE6,
             r_tfm.REFERENCE7,
             r_tfm.REFERENCE8,
             r_tfm.REFERENCE10,
             r_tfm.REFERENCE23,
             r_tfm.REFERENCE24,
             r_tfm.REFERENCE25,
             r_tfm.REFERENCE26,
             r_tfm.REFERENCE27,
             r_tfm.REFERENCE28,
             r_tfm.REFERENCE29,
             r_tfm.REFERENCE30,
             r_tfm.GROUP_ID,
             r_tfm.CREATED_BY
         );
         l_load_count := l_load_count + 1;
         /*********************************/
         /* Update Transform table status */
         /*********************************/
          UPDATE xxgl_payroll_detail_tfm 
             SET status = 'PROCESSED'
           WHERE CURRENT OF c_tfm;
      EXCEPTION
         WHEN OTHERS THEN
            r_error.msg_code := SQLCODE;
            r_error.error_text := SQLERRM;
            raise_error(r_error);
            l_error_count := l_error_count + 1;
          UPDATE xxgl_payroll_detail_tfm 
             SET status = 'ERROR'
           WHERE CURRENT OF c_tfm;
      END;
   END LOOP;

   /**********************************/
   /* Determine status               */
   /**********************************/
   IF l_error_count > 0 THEN
      l_status := 'ERROR';
   ELSE
      l_status := 'SUCCESS';
   END IF;
   
   /*******************/
   /* End run phase   */
   /*******************/
   dot_common_int_pkg.end_run_phase
      ( p_run_phase_id  => l_run_phase_id,
        p_status        => l_status,
        p_error_count   => l_error_count,
        p_success_count => l_load_count);

   IF l_status = 'ERROR' THEN
      RETURN FALSE;
   END IF;
   RETURN TRUE;
END load;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      process_journal
--  PURPOSE
--       Concurrent Program XXGL_PAY_ACCR_INT (DEDJTR CHRIS21 Payroll Accrual Interface)
--  DESCRIPTION
--       Main program
-- --------------------------------------------------------------------------------------------------
PROCEDURE process_journal
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_sob_id            IN  NUMBER,
   p_rule_lookup_type  IN  VARCHAR2,
   p_source            IN  VARCHAR2,
   p_file_name         IN  VARCHAR2,
   p_accrual_option    IN  VARCHAR2,
   p_control_file      IN  VARCHAR2,
   p_debug_flag        IN  VARCHAR2,
   p_int_mode          IN  VARCHAR2,
   p_use_runno         IN  NUMBER
)  IS

   CURSOR c_arc IS
      SELECT description archive_directory
      FROM   fnd_lookup_values_vl l,
             v$instance i
      WHERE  l.lookup_type = 'XXGL_CHRIS_BACKUP'
      AND    l.lookup_code = i.instance_name;

   r_srs_xxintifr        r_srs_request_type;
   r_srs_gllezl          r_srs_request_type;
   l_req_id              NUMBER;
   l_conc_prog_id        NUMBER;
   l_appl_id             NUMBER;
   l_gllezl_req_id       NUMBER;
   l_rep_req_id          NUMBER;
   l_err_req_id          NUMBER;
   l_run_id              NUMBER;
   l_run_phase_id        NUMBER;
   l_user_name           VARCHAR2(60);
   l_message             VARCHAR2(240);
   lr_interface_dfn      dot_int_interfaces%ROWTYPE;
   z_procedure_name      CONSTANT VARCHAR2(150) := 'xxgl_payroll_pkg.process_journal';
   l_inbound_directory   fnd_flex_values_tl.description%TYPE;
   l_outbound_directory  fnd_flex_values_tl.description%TYPE;
   l_staging_directory   fnd_flex_values_tl.description%TYPE;
   l_archive_directory   fnd_flex_values_tl.description%TYPE;
   x_message             VARCHAR2(1000);
   l_getfile_req_id      NUMBER;
   l_run_error           NUMBER := 0;
   r_request             xxint_common_pkg.CONTROL_RECORD_TYPE;
   t_files_tab           t_varchar_tab_type;
   l_file                VARCHAR2(150);
   l_log                 VARCHAR2(150);
   l_bad                 VARCHAR2(150);
   l_ctl                 VARCHAR2(150);
   l_tfm_mode            VARCHAR2(60);

   e_interface_error     EXCEPTION;
BEGIN
   /******************************************/
   /* Pre-process validation                 */
   /******************************************/
   xxint_common_pkg.g_object_type := 'JOURNALS';
   l_req_id := fnd_global.conc_request_id;
   l_conc_prog_id := fnd_global.conc_program_id;
   l_appl_id := fnd_global.resp_appl_id;
   g_user_id := fnd_profile.value('USER_ID');
   l_user_name := fnd_profile.value('USERNAME');
   g_debug_flag := nvl(p_debug_flag, 'N');
   l_tfm_mode := nvl(p_int_mode, g_int_mode);
   g_sob_id := p_sob_id;
   l_ctl := nvl(p_control_file, g_ctl);
   l_file := nvl(p_file_name, g_file);
   g_rule_lookup_type := p_rule_lookup_type;
   g_sob_currency := get_sob_currency(g_sob_id);
   g_chart_id := get_chart_of_accounts(g_sob_id);

   IF p_use_runno IS NOT NULL THEN
      g_run_number := p_use_runno;
   END IF;

   debug_msg('procedure name ' || z_procedure_name || '.');
   
   -- Determine whether this is an accrual file or not
   IF l_file LIKE 'payrollacc%' THEN
      g_accrual_flag := 'Y';
      g_user_je_source := 'Payroll Accrual';
   ELSE
      g_accrual_flag := 'N';
      g_user_je_source := 'Payroll';
   END IF;
   
   /****************************/
   /* Get Interface ID         */
   /****************************/
   debug_msg('check interface registry for ' || g_int_code || '.');
   get_interface_defn(g_int_code, g_int_name, l_req_id, lr_interface_dfn);
   IF nvl(lr_interface_dfn.enabled_flag, 'Y') = 'N' THEN
      log_msg(g_error || replace(substr(g_error_message_01, 11, 100), '$INT_CODE', g_int_code));
      p_retcode := 2;
      RETURN;
   END IF;

   /****************************/
   /* Get Directory Info       */
   /****************************/
   debug_msg('retrieving interface directory information');

   l_inbound_directory := xxint_common_pkg.interface_path
      ( p_application => 'GL',
        p_source  => p_source,
        p_in_out  => 'INBOUND',
        p_message => x_message );
   IF x_message IS NOT NULL THEN
      log_msg(g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_outbound_directory := xxint_common_pkg.interface_path
      ( p_application => 'GL',
        p_source  => p_source,
        p_in_out  => 'OUTBOUND',
        p_message => x_message );
   IF x_message IS NOT NULL THEN
      log_msg(g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_staging_directory := xxint_common_pkg.interface_path
      ( p_application => 'GL',
        p_source  => p_source,
        p_in_out  => 'WORKING',
        p_message => x_message );
   IF x_message IS NOT NULL THEN
      log_msg(g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   /* Bug: FSC-3576 16-Aug-2017
   l_archive_directory := xxint_common_pkg.interface_path
      ( p_application => 'GL',
        p_source  => p_source,
        p_archive => 'Y',
        p_message => x_message );
   IF x_message IS NOT NULL THEN
      log_msg(g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;
   */

   OPEN c_arc;
   FETCH c_arc INTO l_archive_directory;
   IF c_arc%NOTFOUND THEN
      log_msg(g_error || 'Unable to determine archive directory path.');
      p_retcode := 2;
      RETURN;
   END IF;

   debug_msg('p_source=' || p_source);
   debug_msg('p_accrual_option='||p_accrual_option);
   debug_msg('p_use_runno='||p_use_runno);
   debug_msg('l_file=' || l_file);
   debug_msg('l_ctl=' || l_ctl);
   debug_msg('l_inbound_directory=' || l_inbound_directory);
   debug_msg('l_outbound_directory=' || l_outbound_directory);
   debug_msg('l_staging_directory=' || l_staging_directory);
   debug_msg('l_archive_directory=' || l_archive_directory);

   /****************************/
   /* Submit Get File          */
   /****************************/
   l_getfile_req_id := submit_xxintifr_get_file(l_req_id, l_inbound_directory, l_file, l_appl_id);
   debug_msg('fetching file ' || l_file || ' from ' || l_inbound_directory || ' (request_id=' || l_getfile_req_id || ')');

   /****************************/
   /* Wait for request         */
   /****************************/
   wait_for_request(l_getfile_req_id, 5, r_srs_xxintifr);
   IF NOT ( r_srs_xxintifr.srs_dev_phase = 'COMPLETE' AND
            r_srs_xxintifr.srs_dev_status IN ('NORMAL','WARNING') ) THEN
      l_run_error := l_run_error + 1;
      l_message := replace(substr(g_error_message_02, 11, 100), '$INT_DIR', l_inbound_directory);
      log_msg(g_error || l_message);
      r_request.error_message := l_message;
      r_request.status := 'ERROR';
   ELSE
      r_request.status := 'SUCCESS';
   END IF;

   r_request.application_id := l_appl_id;
   r_request.interface_request_id := l_req_id;
   r_request.sub_request_id := l_getfile_req_id;

   /*****************************/
   /* Interface Control Record  */
   /*****************************/
   xxint_common_pkg.interface_request(r_request);

   /*****************************/
   /* Get list of file names    */
   /*****************************/
   get_interface_files(l_req_id, l_getfile_req_id, t_files_tab);

   IF l_run_error > 0 OR t_files_tab.COUNT = 0 THEN
      RAISE e_interface_error;
   END IF;

   /*********************************/
   /* Clear out framework tables    */
   /*********************************/
   delete_fwk_table_data;

   /*****************************/
   /* Process each file         */
   /*****************************/
   FOR i IN 1..t_files_tab.LAST
   LOOP
      l_file := replace(t_files_tab(i), l_inbound_directory || '/');
      l_log  := replace(l_file, 'txt', 'log');
      l_bad  := replace(l_file, 'txt', 'bad');
      g_int_batch_name := l_file;
      
      /******************************************/
      /* Interface Run ID                       */
      /******************************************/
      l_run_id := dot_common_int_pkg.initialise_run
         ( p_int_code       => g_int_code,
           p_src_rec_count  => NULL,
           p_src_hash_total => NULL,
           p_src_batch_name => g_int_batch_name);

      debug_msg('interface framework (run_id=' || l_run_id || ')');

      /******************************************/
      /* Staging                                */
      /******************************************/
      IF NOT stage (
            l_run_id,
            l_run_phase_id,
            r_request,
            l_inbound_directory,
            l_outbound_directory,
            l_staging_directory,
            l_archive_directory,
            l_file,
            l_log,
            l_bad,
            l_ctl )
      THEN
         RAISE e_interface_error;
      END IF;

      /******************************************/
      /* Transformation                         */
      /******************************************/
      IF NOT transform(l_run_id, l_run_phase_id, l_file, l_tfm_mode, p_accrual_option) THEN
         RAISE e_interface_error;
      END IF;

      /******************************************/
      /* Load                                   */
      /******************************************/
      debug_msg('interface framework (int_mode=' || l_tfm_mode || ')');
      IF l_tfm_mode IN (g_int_mode, g_int_trans_mode) THEN
         IF NOT load(l_run_id, l_run_phase_id) THEN
            RAISE e_interface_error;
         ELSE
            /*********************************/
            /* Update Run Numbers            */
            /*********************************/
            INSERT INTO xxgl_payroll_run_numbers
            VALUES (DECODE(NVL(g_accrual_flag, 'N'), 'N', g_run_number, NULL),
                    DECODE(NVL(g_accrual_flag, 'N'), 'Y', g_run_number, NULL),
                    g_sob_id,
                    TRUNC(SYSDATE),
                    SYSDATE,
                    g_user_id,
                    SYSDATE,
                    g_user_id);
            COMMIT;
         END IF;
      END IF;

      /*********************************/
      /* Interface report              */
      /*********************************/
      l_rep_req_id := dot_common_int_pkg.launch_run_report
         ( p_run_id      => l_run_id,
           p_notify_user => l_user_name);

      debug_msg('interface framework completion report (request_id=' || l_rep_req_id || ')');


      /*********************************/
      /* Submit Journal Import         */
      /*********************************/
      l_gllezl_req_id := submit_gllezl(g_user_je_source, l_run_id, p_sob_id);

      debug_msg('Journal Import (request_id=' || l_gllezl_req_id || ')');

      /*********************************/
      /* Output Deletion Report        */
      /*********************************/
      deletion_report(l_run_id);
   END LOOP;

EXCEPTION
   WHEN e_interface_error THEN
      /*********************************/
      /* Interface report              */
      /*********************************/
      l_err_req_id := dot_common_int_pkg.launch_error_report
                              (p_run_id => l_run_id,
                               p_run_phase_id => l_run_phase_id);

      l_rep_req_id := dot_common_int_pkg.launch_run_report
                              (p_run_id      => l_run_id,
                               p_notify_user => l_user_name);

      p_retcode := 1;
END process_journal;

end xxgl_payroll_pkg;
/
