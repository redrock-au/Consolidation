CREATE OR REPLACE PACKAGE BODY xxgl_coa_extract_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.00.01/glc/1.0.0/install/sql/XXGL_COA_EXTRACT_PKG.pkb 2499 2017-09-08 07:20:44Z svnuser $ */

/****************************************************************************
**
** CEMLI ID: GL.03.02
**
** Description: GL Chart of Accounts Extract
**
** Change History:
**
** Date        Who                  Comments
** 25/05/2017  ARELLAD (RED ROCK)   Initial build.
**
****************************************************************************/

g_debug_flag           VARCHAR2(1);
g_error                VARCHAR2(15) := 'ERROR: ';
g_debug                VARCHAR2(15) := 'DEBUG: ';
g_lookup_type          VARCHAR2(150) := 'XXGL_COA_EXTRACT_PARAMETERS';
z_appl_short_name      CONSTANT VARCHAR2(3) := 'GL';
z_file_temp_dir        CONSTANT VARCHAR2(150) := 'USER_TMP_DIR';
z_file_temp_path       CONSTANT VARCHAR2(150) := '/usr/tmp';
z_file_write           CONSTANT VARCHAR2(1)   := 'w';

TYPE cursor_type IS REF CURSOR;

TYPE extract_rec_type IS RECORD
(
   line_print    VARCHAR2(3000),
   level_1       VARCHAR2(30),
   level_2       VARCHAR2(30),
   level_3       VARCHAR2(30),
   level_4       VARCHAR2(30),
   level_5       VARCHAR2(30),
   level_6       VARCHAR2(30),
   level_7       VARCHAR2(30),
   level_8       VARCHAR2(30)
);

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

-------------------------------------------------------------
-- Procedure
--     EXTRACT_FFLEXVAL_HIERARCHY
-- Purpose
--     Process for extracting account segments hierarchy 
--     from the Cognos Materialized Views.
-------------------------------------------------------------

PROCEDURE extract_fflexval_hierarchy
(
   p_errbuff            OUT VARCHAR2,
   p_retcode            OUT NUMBER,
   p_set_of_books_id    IN  NUMBER,
   p_segment            IN  VARCHAR2,
   p_parent_value       IN  VARCHAR2,
   p_levels             IN  NUMBER,
   p_debug_flag         IN  VARCHAR2
)
IS
   CURSOR c_flex IS
      SELECT gsob.set_of_books_id,
             --DECODE(gsob.short_name, 'DOI', 'DEDJTR', gsob.short_name) set_of_books_name,
             gsob.short_name set_of_books_name,
             fseg.application_column_name,
             fseg.segment_name,
             fseg.flex_value_set_id
      FROM   fnd_id_flex_structures fstr,
             fnd_id_flex_segments_vl fseg,
             gl_sets_of_books gsob
      WHERE  gsob.set_of_books_id = p_set_of_books_id
      AND    gsob.set_of_books_id <> 85 -- id 85 is disabled
      AND    fstr.application_id = fseg.application_id
      AND    fstr.id_flex_code = fseg.id_flex_code
      AND    fseg.segment_name = p_segment
      AND    fstr.id_flex_num = fseg.id_flex_num
      AND    fstr.id_flex_code = 'GL#'
      AND    fstr.id_flex_num = gsob.chart_of_accounts_id;

   CURSOR c_attr (p_ffset_id NUMBER, p_ffval VARCHAR2) IS
      SELECT CHR(9) || TO_CHAR(end_date_active, 'DD/MM/YYYY HH:MI:SS AM') || 
             CHR(9) || attribute5 line_desc
      FROM   fnd_flex_values_vl
      WHERE  flex_value_set_id = p_ffset_id
      AND    flex_value = p_ffval;

   CURSOR c_unassigned (p_flex_vset_id NUMBER) IS
      SELECT fv.flex_value || CHR(9) ||
             fv.flex_value || ' - ' || fv.description || CHR(9) || 
             TO_CHAR(end_date_active, 'DD/MM/YYYY HH:MI:SS AM') || CHR(9) || 
             attribute5 unassigned_value
      FROM   fnd_flex_values_vl fv
      WHERE  fv.flex_value_set_id = p_flex_vset_id
      AND    fv.enabled_flag = 'Y'
      AND    SUBSTR(fv.compiled_value_attributes, (INSTR(fv.compiled_value_attributes, CHR(10), 1) + 1), 1) = 'Y'
      AND    NOT EXISTS (SELECT ffnh.flex_value_set_id,
                                ffvc.flex_value_id,
                                ffvc.flex_value,
                                ffnh.range_attribute,
                                ffvp.flex_value_id parent_flex_value_id,
                                ffnh.parent_flex_value
                         FROM   fnd_flex_value_norm_hierarchy ffnh,
                                fnd_flex_values ffvp,
                                fnd_flex_values ffvc
                         WHERE  ffnh.flex_value_set_id = ffvp.flex_value_set_id
                         AND    ffnh.flex_value_set_id = ffvc.flex_value_set_id
                         AND    (ffvc.flex_value BETWEEN ffnh.child_flex_value_low AND ffnh.child_flex_value_high)
                         AND    ffvc.flex_value_id = fv.flex_value_id
                         AND    ffvc.flex_value_set_id = fv.flex_value_set_id
                         AND    ffnh.parent_flex_value = ffvp.flex_value
                         AND    ((ffnh.range_attribute = 'C' AND NVL(ffvc.summary_flag, 'N') = 'N') OR
                                 (ffnh.range_attribute = 'P' AND NVL(ffvc.summary_flag, 'N') = 'Y')));

   c_hier            cursor_type;
   r_line            extract_rec_type;
   r_flex            c_flex%ROWTYPE;
   r_unassigned      c_unassigned%ROWTYPE;
   l_flex_value      fnd_flex_values_vl.flex_value%TYPE;
   l_flex_attr       VARCHAR2(360);
   l_line_print      VARCHAR2(5000);
   l_line_count      NUMBER := 0;
   l_levels          NUMBER := NVL(p_levels, 8);
   l_sql             VARCHAR2(32767);
   l_table           VARCHAR2(60);
   l_file            VARCHAR2(150);
   l_heading_line    VARCHAR2(5000);
   l_heading_lab1    VARCHAR2(1000);
   l_heading_lab2    VARCHAR2(1000);
   l_source          VARCHAR2(15) := 'COA';
   l_out_dir         VARCHAR2(240);
   l_arc_dir         VARCHAR2(240);
   l_message         VARCHAR2(500);
   l_timestamp       VARCHAR2(30);
   l_text            VARCHAR2(5000);
   e_process_error   EXCEPTION;

   -- UTL File
   f_handle          utl_file.file_type;
   f_copy            INTEGER;

BEGIN
   xxint_common_pkg.g_object_type := 'SEGMENTS';
   g_debug_flag := p_debug_flag;

   fnd_file.put_line(fnd_file.log, 'DEBUG_FLAG=' || g_debug_flag);

   /* debug */
   print_debug('parameter: p_set_of_books_id=' || p_set_of_books_id);
   print_debug('parameter: p_segment=' || p_segment);
   print_debug('parameter: p_parent_value=' || p_parent_value);
   print_debug('parameter: p_levels=' || p_levels);

   IF l_levels = 0 THEN
      fnd_file.put_line(fnd_file.log, g_error || 'Expecting a valid hierarchy level (must be greater than 0)');
      p_retcode := 2;
      RETURN;
   END IF;

   l_out_dir := xxint_common_pkg.interface_path(p_application => z_appl_short_name,
                                                p_source => l_source,
                                                p_in_out => 'OUTBOUND',
                                                p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE e_process_error;
   END IF;

   l_arc_dir := xxint_common_pkg.interface_path(p_application => z_appl_short_name,
                                                p_source => l_source,
                                                p_in_out => 'OUTBOUND',
                                                p_archive => 'Y',
                                                p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE e_process_error;
   END IF;

   l_sql := 'SELECT level_1 || '' - '' || level_1_desc || ' ||
            'DECODE(SIGN(#LEVEL - 2), ' ||
            '0, CHR(9) || level_2 || CHR(9) || DECODE(level_2, NULL, NULL, level_2 || '' - '' || level_2_desc), ' ||
            '1, CHR(9) || DECODE(level_2, NULL, NULL, level_2 || '' - '' || level_2_desc)) || ' ||
            'DECODE(SIGN(#LEVEL - 3), ' ||
            '0, CHR(9) || level_3 || CHR(9) || DECODE(level_3, NULL, NULL, level_3 || '' - '' || level_3_desc), ' ||
            '1, CHR(9) || DECODE(level_3, NULL, NULL, level_3 || '' - '' || level_3_desc)) || ' ||
            'DECODE(SIGN(#LEVEL - 4), ' ||
            '0, CHR(9) || level_4 || CHR(9) || DECODE(level_4, NULL, NULL, level_4 || '' - '' || level_4_desc), ' ||
            '1, CHR(9) || DECODE(level_4, NULL, NULL, level_4 || '' - '' || level_4_desc)) || ' ||
            'DECODE(SIGN(#LEVEL - 5), ' ||
            '0, CHR(9) || level_5 || CHR(9) || DECODE(level_5, NULL, NULL, level_5 || '' - '' || level_5_desc), ' ||
            '1, CHR(9) || DECODE(level_5, NULL, NULL, level_5 || '' - '' || level_5_desc)) || ' ||
            'DECODE(SIGN(#LEVEL - 6), ' ||
            '0, CHR(9) || level_6 || CHR(9) || DECODE(level_6, NULL, NULL, level_6 || '' - '' || level_6_desc), ' ||
            '1, CHR(9) || DECODE(level_6, NULL, NULL, level_6 || '' - '' || level_6_desc)) || ' ||
            'DECODE(SIGN(#LEVEL - 7), ' ||
            '0, CHR(9) || level_7 || CHR(9) || DECODE(level_7, NULL, NULL, level_7 || '' - '' || level_7_desc), ' ||
            '1, CHR(9) || DECODE(level_7, NULL, NULL, level_7 || '' - '' || level_7_desc)) || ' ||
            'DECODE(SIGN(#LEVEL - 8), ' ||
            '0, CHR(9) || level_8 || CHR(9) || DECODE(level_8, NULL, NULL, level_8 || '' - '' || level_8_desc), ' ||
            '1, CHR(9) || DECODE(level_8, NULL, NULL, level_8 || '' - '' || level_8_desc)), ' ||
            'level_1, level_2, level_3, level_4, level_5, level_6, level_7, level_8 ';

   CASE p_segment
      WHEN 'Organisation' THEN
         l_table := 'APPSSQL.DOT_GL_COA_ORGANISATION_DW';
      WHEN 'Account' THEN
         l_table := 'APPSSQL.DOT_GL_COA_ACCOUNT_DW';
      WHEN 'Cost Centre' THEN
         l_table := 'APPSSQL.DOT_GL_COA_COST_CENTRE_DW';
      WHEN 'Authority' THEN
         l_table := 'APPSSQL.DOT_GL_COA_AUTHORITY_DW';
      WHEN 'Project' THEN
         l_table := 'APPSSQL.DOT_GL_COA_PROJECT_DW';
      WHEN 'Output' THEN
         l_table := 'APPSSQL.DOT_GL_COA_OUTPUT_DW';
      WHEN 'Identifier' THEN
         l_table := 'APPSSQL.DOT_GL_COA_IDENTIFIER_DW';
   END CASE;

   l_sql := l_sql || ' FROM ' || l_table || ' WHERE set_of_books_id = ' || p_set_of_books_id;

   IF p_parent_value IS NOT NULL THEN
      l_sql := l_sql || ' AND level_1 = ''' || p_parent_value || '''';
   END IF;

   l_sql := l_sql || ' ORDER  BY level_1, level_2, level_3, level_4, level_5, level_6, level_7, level_8';
   l_sql := REPLACE(l_sql, '#LEVEL', l_levels);

   l_heading_lab1 := NULL;
   l_heading_lab2 := 'FLEX_VALUE' || CHR(9) || 'FLEX_DESCRIPTION' || CHR(9) || 'END_DATE_ACTIVE' || CHR(9) || 'COMMENTS';

   IF l_levels > 1 THEN
      FOR l IN 1 .. (l_levels - 1) LOOP
         l_heading_lab1 := l_heading_lab1 || 'FLEX_VALUE_L' || l || CHR(9);
      END LOOP;
   END IF;

   l_heading_line := l_heading_lab1 || l_heading_lab2;

   /* debug */
   --print_debug('sql=' || l_sql);
   print_debug('output=' || l_out_dir);
   print_debug('archive=' || l_arc_dir);
   print_debug('determine chart of accounts structure ...');

   OPEN c_flex;
   FETCH c_flex INTO r_flex;
   IF c_flex%FOUND THEN

      /* debug */
      print_debug('determine chart of accounts structure ... success');
      print_debug('flex_value_set_id=' || r_flex.flex_value_set_id);
      print_debug('print output to file...');
      print_debug('open utl file');

      l_file := r_flex.set_of_books_name || '_' 
                || REPLACE(p_segment, ' ', '_') || '_' 
                || NVL(p_parent_value, 'All') -- || '_' || l_levels 
                || '.txt';

      f_handle := utl_file.fopen(z_file_temp_dir, l_file, z_file_write);

      utl_file.put_line(f_handle, l_heading_line);
      fnd_file.put_line(fnd_file.output, l_heading_line);

      OPEN c_hier FOR l_sql;
      LOOP
         FETCH c_hier INTO r_line;
         EXIT WHEN c_hier%NOTFOUND;

         l_flex_value := NULL;
         l_flex_attr := NULL;
         l_line_count := l_line_count + 1;

         IF r_line.level_8 IS NOT NULL THEN
            l_flex_value := r_line.level_8;
         ELSIF r_line.level_7 IS NOT NULL THEN
            l_flex_value := r_line.level_7; 
         ELSIF r_line.level_6 IS NOT NULL THEN
            l_flex_value := r_line.level_6; 
         ELSIF r_line.level_5 IS NOT NULL THEN
            l_flex_value := r_line.level_5; 
         ELSIF r_line.level_4 IS NOT NULL THEN
            l_flex_value := r_line.level_4; 
         ELSIF r_line.level_3 IS NOT NULL THEN
            l_flex_value := r_line.level_3; 
         ELSIF r_line.level_2 IS NOT NULL THEN
            l_flex_value := r_line.level_2;
         END IF;

         OPEN c_attr (r_flex.flex_value_set_id, l_flex_value);
         FETCH c_attr INTO l_flex_attr;
         CLOSE c_attr;

         l_line_print := r_line.line_print || NVL(l_flex_attr, CHR(9) || CHR(9));
         utl_file.put_line(f_handle, l_line_print);
         fnd_file.put_line(fnd_file.output, l_line_print);

      END LOOP;
      CLOSE c_hier;

      -- Unassigned child values
      IF l_levels > 1 THEN
         FOR i IN 1 .. (l_levels - 1) LOOP
            l_text := l_text || 'UK' || i || ' - Need to be allocated under a group' || CHR(9);
         END LOOP;
      END IF;

      OPEN c_unassigned(r_flex.flex_value_set_id);
      LOOP
         FETCH c_unassigned INTO r_unassigned;
         EXIT WHEN c_unassigned%NOTFOUND;

         l_line_print := l_text || r_unassigned.unassigned_value;
         utl_file.put_line(f_handle, l_line_print);
         fnd_file.put_line(fnd_file.output, l_line_print);
      END LOOP;
      CLOSE c_unassigned;

      utl_file.fclose(f_handle);

      l_timestamp := TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS');

      /* debug */
      print_debug('close utl file');
      print_debug('print output to file... completed');
      print_debug('timestamp=' || l_timestamp);
      print_debug('output_file=' || l_file);
      print_debug('archive_file=' || l_file || '.' || l_timestamp);
      print_debug('move output file');
      print_debug('from_path=' || z_file_temp_path || '/' || l_file);
      print_debug('to_path=' || l_out_dir || '/' || l_file);

      f_copy := xxint_common_pkg.file_copy(p_from_path => z_file_temp_path || '/' || l_file,
                                           p_to_path => l_out_dir || '/' || l_file);

      /* debug */
      print_debug('output_file=' || f_copy);

      f_copy := xxint_common_pkg.file_copy(p_from_path => z_file_temp_path || '/' || l_file,
                                           p_to_path => l_arc_dir || '/' || l_file || '.' || l_timestamp);

      /* debug */
      print_debug('archive_file=' || f_copy);
      print_debug('1=SUCCESS');
      print_debug('0=FAILURE');
      print_debug('delete output file from temp directory');

      utl_file.fremove(z_file_temp_dir, l_file);

   ELSE
      fnd_file.put_line(fnd_file.log, g_error || 'Unable to determine chart of accounts for this set of books.');
      p_retcode := 2;

   END IF;

   /* debug */
   IF p_retcode IS NULL THEN
      print_debug('completed with no errors');
   END IF;

EXCEPTION
   WHEN e_process_error THEN
      fnd_file.put_line(fnd_file.log, g_error || l_message);
      p_retcode := 2;

   WHEN others THEN
      IF utl_file.is_open(f_handle) THEN
         utl_file.fclose(f_handle);
      END IF;

      fnd_file.put_line(fnd_file.log, g_error || SQLERRM);
      p_retcode := 2;

END extract_fflexval_hierarchy;

-------------------------------------------------------------
-- Procedure
--     EXTRACT_ALL
-- Purpose
--     Wrapper function to run all the extracts in one call. 
--     Uses a Common Lookup setup for the run parameters.
-------------------------------------------------------------

PROCEDURE extract_all
(
   p_errbuff            OUT VARCHAR2,
   p_retcode            OUT NUMBER,
   p_lookup_type        IN  VARCHAR2,
   p_debug_flag         IN  VARCHAR2
)
IS
   CURSOR c_batch IS
      SELECT lookup_code,
             description,
             TO_NUMBER(attribute1) set_of_books_id,
             attribute2 account_segment,
             attribute3 parent_value,
             attribute4 levels
      FROM   fnd_lookup_values_vl
      WHERE  lookup_type = NVL(p_lookup_type, g_lookup_type)
      AND    NVL(end_date_active, SYSDATE + 1) > SYSDATE
      AND    NVL(enabled_flag, 'N') = 'Y'
      ORDER  BY 1;

   l_debug_flag    VARCHAR2(1) := NVL(p_debug_flag, 'N');
   l_errbuff       VARCHAR2(240);
   l_retcode       NUMBER;
BEGIN

   FOR r IN c_batch LOOP
      fnd_file.put_line(fnd_file.log, 'Parameter: ' || r.lookup_code || ':' || r.description);

      extract_fflexval_hierarchy(p_errbuff => l_errbuff,
                                 p_retcode => l_retcode,
                                 p_set_of_books_id => r.set_of_books_id,
                                 p_segment => r.account_segment,
                                 p_parent_value => r.parent_value,
                                 p_levels => r.levels,
                                 p_debug_flag => l_debug_flag
                                );
   END LOOP;

EXCEPTION
   WHEN others THEN
      RAISE;

END extract_all;


END xxgl_coa_extract_pkg;
/
