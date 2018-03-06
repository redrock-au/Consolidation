CREATE OR REPLACE PACKAGE xxgl_rule_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.01.02/glc/1.0.0/install/sql/XXGL_RULE_PKG.pks 1368 2017-07-02 23:54:39Z svnuser $ */
g_error                  CONSTANT VARCHAR2(10) := 'ERROR: ';

TYPE t_varchar_tab_type IS TABLE OF VARCHAR2(200) INDEX BY BINARY_INTEGER;

TYPE t_segment_column_cache_type IS TABLE OF VARCHAR2(30) INDEX BY VARCHAR2(30);
g_seg_col_cache          t_segment_column_cache_type;

TYPE t_segment_array_type IS VARRAY(7) OF VARCHAR2(30);

CURSOR c_rules_lookup
(
   p_tag              IN VARCHAR2,
   p_rule_lookup_type IN VARCHAR2
) IS
   SELECT lookup_code,
          attribute1 as category1,
          attribute2 as category2,
          attribute3 as category3,
          attribute4 as category4,
          attribute5 as category5,
          attribute6 as category6,
          attribute7 as update_sql,
          attribute9 as prepay_update_sql,
          attribute8 as filter_sql
   FROM   fnd_lookup_values_vl
   WHERE  lookup_type = p_rule_lookup_type
   AND    enabled_flag = 'Y'
   AND    SYSDATE BETWEEN start_date_active AND NVL(end_date_active, SYSDATE+1)
   AND    tag = nvl(p_tag, tag)
   AND    attribute_category = p_rule_lookup_type
   ORDER BY lookup_code;

TYPE t_rules_lookup_tab IS TABLE OF c_rules_lookup%ROWTYPE INDEX BY BINARY_INTEGER;

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
) RETURN t_segment_array_type;

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
);

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
) RETURN VARCHAR2;

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
   p_tag                      IN VARCHAR2,
   p_update_sql_fragment      IN VARCHAR2 DEFAULT NULL,
   p_prepay_upd_sql_fragment  IN VARCHAR2 DEFAULT NULL,
   p_filter_sql_fragment      IN VARCHAR2 DEFAULT NULL,
   p_set_of_books_id          IN  NUMBER DEFAULT NULL
) RETURN VARCHAR2;

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
);

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      parse_rule_categories
--  PURPOSE
--       Parses the c_payroll_rules cursor category columns into a pl/sql table
-- --------------------------------------------------------------------------------------------------
FUNCTION parse_rule_categories
(
   p_rule_rec         IN OUT NOCOPY c_rules_lookup%rowtype
) RETURN t_varchar_tab_type;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      lookup_segment_column
--  PURPOSE
--       Accepts a chart segment name and lookups the SEGMENT column that it relates to.
--       e.g. Organisation is mapped to SEGMENT1 in the DOI set of books
-- --------------------------------------------------------------------------------------------------
FUNCTION lookup_segment_column
(
   p_segment_name     IN VARCHAR2,
   p_sob_id           IN NUMBER DEFAULT NULL
) RETURN VARCHAR2;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      format_sql_in_set
--  PURPOSE
--       Accepts a list of varchar2 values and returns them in a comma separated list useful for 
--       a SQL statement.  e.g. ('Category1','Category2','Category3')
-- --------------------------------------------------------------------------------------------------
FUNCTION format_sql_in_set
(
   p_value_list       IN OUT NOCOPY t_varchar_tab_type,
   p_upper_case       IN BOOLEAN DEFAULT FALSE
) RETURN VARCHAR2;

END xxgl_rule_pkg;
/

