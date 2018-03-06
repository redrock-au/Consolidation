CREATE OR REPLACE PACKAGE BODY xxgl_rule_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.02.03/glc/1.0.0/install/sql/XXGL_RULE_PKG.pkb 1442 2017-07-04 22:35:02Z svnuser $ */
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
--      to_varray
--  PURPOSE
--      Converts an account code combination into a varray of segment values
-- --------------------------------------------------------------------------------------------------
FUNCTION to_varray
(
   p_account_string  IN VARCHAR2,
   p_seg_delim       IN VARCHAR2 DEFAULT '-',
   p_seg_count       IN NUMBER DEFAULT 7
) RETURN t_segment_array_type
IS
   l_seg_varr        t_segment_array_type := t_segment_array_type('','','','','','','');
   l_seg_lengths     t_segment_array_type := t_segment_array_type('1','5','3','4','4','4','8');
   l_delim_pos       NUMBER;
   l_prev_pos        NUMBER;
BEGIN
   IF regexp_count(p_account_string, p_seg_delim) <> (p_seg_count - 1) THEN
      -- incorrect number of segments
      RAISE_APPLICATION_ERROR(-20000, 'Incorrect number of segments in account string');
   END IF;
   FOR i IN 1..p_seg_count-1
   LOOP
      l_delim_pos := instr(p_account_string, p_seg_delim, 1, i);
      IF i = 1 THEN
         l_prev_pos := 0;
      ELSE
         l_prev_pos := instr(p_account_string, p_seg_delim, 1, i-1);
      END IF;
      l_seg_varr(i) := substr(p_account_string, l_prev_pos + 1, l_delim_pos - l_prev_pos - 1);
      -- validate length of the segment
      IF nvl(length(l_seg_varr(i)), to_number(l_seg_lengths(i))) <>  to_number(l_seg_lengths(i)) THEN
         RAISE_APPLICATION_ERROR(-20001, 'Segment' || i || ' should be ' || l_seg_lengths(i) || ' in length');
      END IF;
   END LOOP;
   l_seg_varr(l_seg_varr.LAST) := substr(p_account_string, l_delim_pos + 1);
   -- validate length of the final segment
   IF nvl(length(l_seg_varr(p_seg_count)), to_number(l_seg_lengths(p_seg_count))) <>  to_number(l_seg_lengths(p_seg_count)) THEN
      RAISE_APPLICATION_ERROR(-20001, 'Segment' || p_seg_count || ' should be ' || l_seg_lengths(p_seg_count) || ' in length');
   END IF;
   RETURN l_seg_varr;
END to_varray;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      get_user_category_name
--  PURPOSE
--      Retrieves the User Category Name of a Category Name
--  RETURNS
--      User Category Name
-- --------------------------------------------------------------------------------------------------
FUNCTION get_user_category_name
(
   p_category_name    IN VARCHAR2
) RETURN VARCHAR2
IS
   l_user_category_name     gl_je_categories_tl.user_je_category_name%TYPE;
BEGIN
   SELECT user_je_category_name
   INTO   l_user_category_name
   FROM   gl_je_categories_vl
   WHERE  je_category_name = p_category_name;
   RETURN l_user_category_name;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;
END get_user_category_name;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--       populate_segment_col_cache
--  PURPOSE
--       Populates the g_seg_col_cache global cache which holds mapping between segment names 
--       and applicartion column names
-- --------------------------------------------------------------------------------------------------
PROCEDURE populate_segment_col_cache
(
   p_set_of_books_id  IN NUMBER
) IS
   CURSOR c_segs IS
      SELECT ffs.application_column_name, upper(replace(ffs.segment_name,' ','_')) as segment_name
      FROM   fnd_id_flex_segments_vl ffs,
             gl_sets_of_books sob
      WHERE  ffs.id_flex_num = sob.chart_of_accounts_id
      AND    ffs.enabled_flag = 'Y'
      AND    sob.set_of_books_id = p_set_of_books_id;
BEGIN
   FOR r_segs IN c_segs
   LOOP
      g_seg_col_cache(r_segs.segment_name) := r_segs.application_column_name;
   END LOOP;
END populate_segment_col_cache;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      lookup_rules
--  PURPOSE
--      Looks up the rows of FND_LOOKUP_VALUES_VL for the given lookup type and tag type
--  RETURNS
--      Table of FND_LOOKUP_VALUES_VL rows 
-- --------------------------------------------------------------------------------------------------
PROCEDURE lookup_rules
(
   p_tag              IN VARCHAR2,
   p_rule_lookup_type IN VARCHAR2,
   p_rules_lookup_tab IN OUT NOCOPY t_rules_lookup_tab
) IS
BEGIN
   OPEN c_rules_lookup(p_tag, p_rule_lookup_type);
   FETCH c_rules_lookup BULK COLLECT INTO p_rules_lookup_tab;
   CLOSE c_rules_lookup;
END;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      parse_rule_categories
--  PURPOSE
--       Parses the c_payroll_rules cursor category columns into a pl/sql table
-- --------------------------------------------------------------------------------------------------
FUNCTION parse_rule_categories
(
   p_rule_rec          IN OUT NOCOPY c_rules_lookup%rowtype
) RETURN t_varchar_tab_type
IS
   l_category_tab      t_varchar_tab_type;
BEGIN
   IF p_rule_rec.category1 IS NOT NULL THEN
      l_category_tab(l_category_tab.COUNT+1) := get_user_category_name(p_rule_rec.category1);
   END IF;
   IF p_rule_rec.category2 IS NOT NULL THEN
      l_category_tab(l_category_tab.COUNT+1) := get_user_category_name(p_rule_rec.category2);
   END IF;
   IF p_rule_rec.category3 IS NOT NULL THEN
      l_category_tab(l_category_tab.COUNT+1) := get_user_category_name(p_rule_rec.category3);
   END IF;
   IF p_rule_rec.category4 IS NOT NULL THEN
      l_category_tab(l_category_tab.COUNT+1) := get_user_category_name(p_rule_rec.category4);
   END IF;
   IF p_rule_rec.category5 IS NOT NULL THEN
      l_category_tab(l_category_tab.COUNT+1) := get_user_category_name(p_rule_rec.category5);
   END IF;
   IF p_rule_rec.category6 IS NOT NULL THEN
      l_category_tab(l_category_tab.COUNT+1) := get_user_category_name(p_rule_rec.category6);
   END IF;
   RETURN l_category_tab;
END parse_rule_categories;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--       replace_segment_name
--  PURPOSE
--       Searches a string for Segment Names (e.g. 'Authority') and replaces occurences with the 
--       mapped application column name (e.g. SEGMENT4)
--  DESCRIPTION
--       Uses a global segment mapping cache (assocoiative array) which must be initialised 
--       prior to using it, using xxgl_rule_pkg.populate_segment_col_cache
-- --------------------------------------------------------------------------------------------------
FUNCTION replace_segment_name
(
   p_string            IN  VARCHAR2,
   p_set_of_books_id   IN  NUMBER DEFAULT NULL
) RETURN VARCHAR2
IS
   l_replaced           VARCHAR2(1000);
   l_idx                VARCHAR2(30);
   l_sob_id             NUMBER := nvl(p_set_of_books_id, fnd_profile.value('GL_SET_OF_BKS_ID'));
BEGIN
   IF g_seg_col_cache.COUNT = 0 THEN
      populate_segment_col_cache(l_sob_id);
   END IF;
   l_replaced := upper(p_string);
   l_idx := g_seg_col_cache.FIRST;
   WHILE l_idx IS NOT NULL
   LOOP
      l_replaced := replace(l_replaced, l_idx, g_seg_col_cache(l_idx));
      l_idx := g_seg_col_cache.NEXT(l_idx);
   END LOOP;
   RETURN l_replaced;
END replace_segment_name;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      is_rule_valid
--  PURPOSE
--      Validates the syntax of a rule description
--  RETURNS
--      'Y' if the rule is able to be parsed
--      'N' if not.
-- --------------------------------------------------------------------------------------------------
FUNCTION is_rule_valid
(
   p_tag                   IN VARCHAR2,
   p_update_sql_fragment   IN VARCHAR2 DEFAULT NULL,
   p_prepay_upd_sql_fragment  IN VARCHAR2 DEFAULT NULL,
   p_filter_sql_fragment   IN VARCHAR2 DEFAULT NULL,
   p_set_of_books_id       IN  NUMBER DEFAULT NULL
) RETURN VARCHAR2
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_sql                   VARCHAR2(300);
   l_sob                   NUMBER := nvl(p_set_of_books_id, fnd_profile.value('GL_SET_OF_BKS_ID'));
   t_overlay_account_varr  t_segment_array_type;
   l_update_sql_fragment   VARCHAR2(150);
BEGIN
   IF g_seg_col_cache.COUNT = 0 THEN
      populate_segment_col_cache(l_sob);
   END IF;
   IF p_tag = 'INT' THEN
      -- intercompany rule; the update_sql_fragment will be an account code combination
      -- try to convert it to a varray of segment values; this will raise an exception if unsuccessful
      t_overlay_account_varr := to_varray(p_update_sql_fragment, '-', 7);
   ELSE
      l_update_sql_fragment := p_update_sql_fragment;
   END IF;
   IF l_update_sql_fragment IS NOT NULL OR p_filter_sql_fragment IS NOT NULL THEN
      l_sql := 'update xxgl_payroll_detail_tfm set ' 
         || nvl(replace_segment_name(l_update_sql_fragment), 'creation_date = sysdate') 
         || ' where ' || nvl(replace_segment_name(p_filter_sql_fragment), '1=2'); 
      EXECUTE IMMEDIATE l_sql;
   END IF;
   IF p_prepay_upd_sql_fragment IS NOT NULL OR p_filter_sql_fragment IS NOT NULL THEN
      l_update_sql_fragment := p_prepay_upd_sql_fragment;
      l_sql := 'update xxgl_payroll_detail_tfm set ' 
         || nvl(replace_segment_name(l_update_sql_fragment), 'creation_date = sysdate') 
         || ' where ' || nvl(replace_segment_name(p_filter_sql_fragment), '1=2'); 
      EXECUTE IMMEDIATE l_sql;
   END IF;
   ROLLBACK;
   RETURN 'Y';
EXCEPTION 
   WHEN OTHERS THEN
      ROLLBACK;
      RETURN 'N';
END is_rule_valid;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      lookup_segment_column
--  PURPOSE
--       Accepts a chart segment name and lookups the SEGMENT column that it relates to.
--       e.g. Organisation is mapped to SEGMENT1 in the DOI set of books
-- --------------------------------------------------------------------------------------------------
FUNCTION lookup_segment_column
(
   p_segment_name      IN VARCHAR2,
   p_sob_id            IN NUMBER DEFAULT NULL
) RETURN VARCHAR2
IS
   l_segment_column   VARCHAR2(30);
   l_sob_id           NUMBER := nvl(p_sob_id, fnd_profile.value('GL_SET_OF_BKS_ID'));
BEGIN
   SELECT ffs.application_column_name
   INTO   l_segment_column
   FROM   fnd_id_flex_segments_vl ffs,
          gl_sets_of_books sob
   WHERE  upper(ffs.segment_name) = upper(p_segment_name)
   AND    ffs.id_flex_num = sob.chart_of_accounts_id
   AND    ffs.enabled_flag = 'Y'
   AND    sob.set_of_books_id = l_sob_id;
   RETURN l_segment_column;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;
END lookup_segment_column;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      format_sql_in_set
--  PURPOSE
--       Accepts a list of varchar2 values and returns them in a comma separated list useful for 
--       a SQL statement.  e.g. ('Category1','Category2','Category3')
-- --------------------------------------------------------------------------------------------------
FUNCTION format_sql_in_set
(
   p_value_list        IN OUT NOCOPY t_varchar_tab_type,
   p_upper_case        IN BOOLEAN DEFAULT FALSE
) RETURN VARCHAR2
IS
   l_set               VARCHAR2(800);
BEGIN
   l_set := '(';
   FOR i IN 1..p_value_list.COUNT
   LOOP
      IF p_upper_case THEN
         p_value_list(i) := upper(p_value_list(i));
      END IF;
      IF (i = 1) THEN
         l_set :=  l_set || '''' || p_value_list(i) || '''';
      ELSE
         l_set :=  l_set || ',''' || p_value_list(i) || '''';
      END IF;
   END LOOP;
   l_set := l_set || ')';
   RETURN l_set;
END format_sql_in_set;

END xxgl_rule_pkg;
/
