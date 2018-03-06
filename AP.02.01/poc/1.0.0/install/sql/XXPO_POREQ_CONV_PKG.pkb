CREATE OR REPLACE PACKAGE BODY xxpo_poreq_conv_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.02.01/poc/1.0.0/install/sql/XXPO_POREQ_CONV_PKG.pkb 2466 2017-09-06 07:00:01Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: PO.00.03
**
** Description: Conversion program for importing Open Purchase Order Requsitions
**              from DSDBI. 
**
** Change History:
**
** Date        Who                  Comments
** 19/06/2017  sryan                Initial build.
**
*******************************************************************/
g_debug_flag                  VARCHAR2(1) := 'N';
g_int_batch_name              dot_int_runs.src_batch_name%TYPE;
g_org_id                      NUMBER;
g_source                      fnd_lookup_values.lookup_code%TYPE;
g_conv_emp_id                 NUMBER;
g_conv_user_id                NUMBER;

TYPE r_srs_request_type IS RECORD 
(
   srs_wait           BOOLEAN,
   srs_phase          VARCHAR2(30),
   srs_status         VARCHAR2(30),
   srs_dev_phase      VARCHAR2(30),
   srs_dev_status     VARCHAR2(30),
   srs_message        VARCHAR2(240)
);

TYPE t_varchar_tab_type IS TABLE OF VARCHAR2(200) INDEX BY BINARY_INTEGER;
TYPE t_validation_errors_type IS TABLE OF VARCHAR2(240);
TYPE t_fnd_user_tab_type IS TABLE OF fnd_user%ROWTYPE INDEX BY BINARY_INTEGER;

TYPE r_ccid_cache_entry_type IS RECORD
(
   code_combination_id     NUMBER,
   val_errors              t_validation_errors_type
);

TYPE r_tax_code_cache_entry_type IS RECORD
(
   ap_tax_codes_rec        ap_tax_codes%ROWTYPE,
   val_errors              t_validation_errors_type
);

TYPE r_uom_code_cache_entry_type IS RECORD
(
   mtl_units_of_measure_rec   mtl_units_of_measure_vl%ROWTYPE,
   val_errors                 t_validation_errors_type
);

TYPE r_category_cache_entry_type IS RECORD
(
   mtl_categories_rec      mtl_categories_b%ROWTYPE,
   val_errors              t_validation_errors_type
);

TYPE r_line_type_cache_entry_type IS RECORD
(
   po_line_types_rec       po_line_types_v%ROWTYPE,
   val_errors              t_validation_errors_type
);

TYPE r_location_cache_entry_type IS RECORD
(
   hr_locations_rec        hr_locations%ROWTYPE,
   val_errors              t_validation_errors_type
);

-- Cache Types
TYPE t_dff_defn_cache_type    IS TABLE OF fnd_descr_flex_column_usages%ROWTYPE INDEX BY VARCHAR2(30);
TYPE t_ccid_cache_type        IS TABLE OF r_ccid_cache_entry_type INDEX BY VARCHAR2(60);
TYPE t_tax_code_cache_type    IS TABLE OF r_tax_code_cache_entry_type INDEX BY VARCHAR2(30);
TYPE t_uom_code_cache_type    IS TABLE OF r_uom_code_cache_entry_type INDEX BY VARCHAR2(30);
TYPE t_category_cache_type    IS TABLE OF r_category_cache_entry_type INDEX BY VARCHAR2(40);
TYPE t_line_type_type         IS TABLE OF r_line_type_cache_entry_type INDEX BY VARCHAR2(60);
TYPE t_location_type          IS TABLE OF r_location_cache_entry_type INDEX BY VARCHAR2(60);
TYPE t_id_cache_type          IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;

-- Caches 
g_dff_cache             t_dff_defn_cache_type;
g_ccid_cache            t_ccid_cache_type;
g_tax_code_cache        t_tax_code_cache_type;
g_uom_code_cache        t_uom_code_cache_type;
g_category_cache        t_category_cache_type;
g_line_type_cache       t_line_type_type;
g_location_cache        t_location_type;
g_sequence_cache        t_id_cache_type;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      debug_msg
--  PURPOSE
--       Writes a line to the concurrent log file if the debug flag is on.
-- --------------------------------------------------------------------------------------------------
PROCEDURE debug_msg
(
   p_message            IN VARCHAR2
) IS
BEGIN
   IF nvl(g_debug_flag, 'N') = 'Y' THEN
      fnd_file.put_line(fnd_file.log, g_debug || SUBSTR(p_message, 1, 1990));
   END IF;
END debug_msg;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      log_msg
--  PURPOSE
--       Writes a line to the concurrent log file.
-- --------------------------------------------------------------------------------------------------
PROCEDURE log_msg
(
   p_message            IN VARCHAR2
) IS
BEGIN
   fnd_file.put_line(fnd_file.log, SUBSTR(p_message, 1, 2000));
END log_msg;

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
--      append_error
--  PURPOSE
--      Appends an error message to an validation error pl/sql table
-- --------------------------------------------------------------------------------------------------
PROCEDURE append_error
(
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type,
   p_error                 IN VARCHAR2
) IS
BEGIN
   IF p_errors_tab IS NULL THEN
      p_errors_tab := t_validation_errors_type(SUBSTR(p_error, 1, 240));
   ELSE
      p_errors_tab.EXTEND;
      p_errors_tab(p_errors_tab.LAST) := SUBSTR(p_error, 1, 240);
   END IF;
END append_error;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      append_error
--  PURPOSE
--      Appends one validation error pl/sql table to another
-- --------------------------------------------------------------------------------------------------
PROCEDURE append_error_tab
(
   p_target_errors_tab     IN OUT NOCOPY t_validation_errors_type,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_target_errors_tab IS NULL THEN
      p_target_errors_tab := t_validation_errors_type();
   END IF;
   IF p_errors_tab IS NOT NULL THEN
      p_target_errors_tab := p_target_errors_tab MULTISET UNION p_errors_tab;
   END IF;
END append_error_tab;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      is_number
--  PURPOSE
--      Determines whether a given value is a number.
--  RETURNS
--      True if the value is a number, else False
-- --------------------------------------------------------------------------------------------------
FUNCTION is_number
(
   p_value                 VARCHAR2
) RETURN BOOLEAN
IS
   l_number               NUMBER;
BEGIN
   l_number := to_number(p_value);
   RETURN TRUE;
EXCEPTION
   WHEN VALUE_ERROR THEN
      RETURN FALSE;
END is_number;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_fnd_employee
--  PURPOSE
--      Queries a user record from FND_USER by employee number and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_fnd_employee
(
   p_emp_id                IN VARCHAR2,
   p_fnd_user_tab          IN OUT NOCOPY t_fnd_user_tab_type
) IS
   lt_fnd_user_tab         t_fnd_user_tab_type;
BEGIN
   SELECT *
   BULK COLLECT INTO lt_fnd_user_tab
   FROM   fnd_user
   WHERE  employee_id = p_emp_id;
   p_fnd_user_tab := lt_fnd_user_tab; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_fnd_user_tab.DELETE;
END query_fnd_employee;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_person
--  PURPOSE
--      Queries a person record from PER_PEOPLE_F and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_person
(
   p_emp_num               IN VARCHAR2,
   p_per_people_f_rec      IN OUT NOCOPY per_people_f%ROWTYPE
) IS
   lr_per_people_f_rec     per_people_f%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_per_people_f_rec
   FROM   per_people_f 
   WHERE  employee_number = p_emp_num
   AND    SYSDATE BETWEEN effective_start_date AND effective_end_date
   AND    SYSDATE >= start_date;
   p_per_people_f_rec := lr_per_people_f_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      lr_per_people_f_rec.person_id := NULL;
END query_person;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_location_code
--  PURPOSE
--      Queries a location code from HR_LOCATIONS and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_location_code
(
   p_location_code               IN VARCHAR2,
   p_hr_locations_rec            IN OUT NOCOPY hr_locations%ROWTYPE
) IS
   lr_hr_locations_rec           hr_locations%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_hr_locations_rec
   FROM   hr_locations 
   WHERE  location_code = p_location_code;
   p_hr_locations_rec := lr_hr_locations_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_hr_locations_rec.location_id := NULL;
END query_location_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_category
--  PURPOSE
--      Queries a category from MTL_CATEGORIES_B and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_category
(
   p_segment1                    IN VARCHAR2,
   p_category_set_name           IN VARCHAR2,
   p_mtl_categories_rec          IN OUT NOCOPY mtl_categories_b%ROWTYPE
) IS
   lr_mtl_categories_rec         mtl_categories_b%ROWTYPE;
BEGIN
   SELECT c.*
   INTO   lr_mtl_categories_rec
   FROM   mtl_categories_b c,
          mtl_category_sets_v cs,
          mtl_category_set_valid_cats csvc
   WHERE  csvc.category_id = c.category_id
   AND    csvc.category_set_id = cs.category_set_id
   AND    cs.category_set_name = p_category_set_name
   AND    segment1 = p_segment1;
   p_mtl_categories_rec := lr_mtl_categories_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_mtl_categories_rec.segment1 := NULL;
END query_category;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_uom_code
--  PURPOSE
--      Queries a unit of measure code from MTL_UNITS_OF_MEASURE_VL and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_uom_code
(
   p_uom_code                    IN VARCHAR2,
   p_mtl_units_of_measure_rec    IN OUT NOCOPY mtl_units_of_measure_vl%ROWTYPE
) IS
   lr_mtl_units_of_measure_rec   mtl_units_of_measure_vl%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_mtl_units_of_measure_rec
   FROM   mtl_units_of_measure_vl 
   WHERE  uom_code = p_uom_code;
   p_mtl_units_of_measure_rec := lr_mtl_units_of_measure_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_mtl_units_of_measure_rec.uom_code := NULL;
END query_uom_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_line_type
--  PURPOSE
--      Queries a line type from PO_LINE_TYPES_V and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_line_type
(
   p_line_type                   IN VARCHAR2,
   p_po_line_types_rec           IN OUT NOCOPY po_line_types_v%ROWTYPE
) IS
   lr_po_line_types_rec          po_line_types_v%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_po_line_types_rec
   FROM   po_line_types_v 
   WHERE  line_type = p_line_type;
   p_po_line_types_rec := lr_po_line_types_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_po_line_types_rec.line_type_id := NULL;
END query_line_type;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_tax_name
--  PURPOSE
--      Queries a tax record from AP_TAX_CODES and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_tax_name
(
   p_tax_name              IN VARCHAR2,
   p_ap_tax_codes_rec      IN OUT NOCOPY ap_tax_codes%ROWTYPE
) IS
   lr_ap_tax_codes_rec     ap_tax_codes%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_ap_tax_codes_rec
   FROM   ap_tax_codes 
   WHERE   name = p_tax_name;
   p_ap_tax_codes_rec := lr_ap_tax_codes_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_ap_tax_codes_rec.tax_id := NULL;
END query_tax_name;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_ccid
--  PURPOSE
--      Queries a code combination id using the custom get_mapped_code_combination() API
--      The xxgl_import_coa_mapping_pkg.get_mapped_code_combination provides access to the converted COA
--      mapping between source (DSDBI) and destination (DTPLI) charge codes.
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_ccid
(
   p_account_string       IN  VARCHAR2,
   p_ccid                 OUT NUMBER,
   p_api_error_msg        OUT VARCHAR2
) IS
   l_ccid                         NUMBER;
   l_mapped_string                VARCHAR2(200);
   l_api_error                    VARCHAR2(4000);
   l_detail_posting_allowed_flag  VARCHAR2(10);
   
   CURSOR c_get_posting_flag (p_code_comb_id NUMBER) IS
      SELECT 'Y' 
      FROM   gl_code_combinations_kfv
      WHERE  code_combination_id = p_code_comb_id
      AND    detail_posting_allowed = 'Y';
BEGIN
   debug_msg('Querying mapped account string '||p_account_string);
   l_mapped_string := xxgl_import_coa_mapping_pkg.get_mapped_code_combination(p_account_string, l_ccid, l_api_error);
   IF l_ccid IS NOT NULL THEN
      OPEN c_get_posting_flag(l_ccid);
      FETCH c_get_posting_flag into l_detail_posting_allowed_flag;
      CLOSE c_get_posting_flag;
      
      IF nvl(l_detail_posting_allowed_flag,'N') = 'Y' THEN -- Added by Joy Pinto on 25-Aug-2017
         p_ccid := l_ccid;
         p_api_error_msg := NULL;
      ELSE
         p_ccid := NULL;
         p_api_error_msg := 'Detail Posting Allowed flag is set to "No" for the mapped code combination : '||l_mapped_string;
      END IF;
   ELSE
      p_ccid := NULL;
      p_api_error_msg := l_api_error;
   END IF;
END query_ccid;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_po_line_id
--  PURPOSE
--      Validates PO Line Id value
--  DESCRIPTION
--      1) Must be numeric
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_po_line_id
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.po_line_id IS NULL THEN
      append_error(p_errors_tab, 'PO Line Id not supplied');
   ELSIF NOT is_number(p_stg_rec.po_line_id) THEN
      append_error(p_errors_tab, 'PO Line Id ''' || p_stg_rec.po_line_id || ''' is not numeric');
   ELSE
      p_tfm_rec.req_dist_sequence_id := p_stg_rec.po_line_id;
      p_tfm_rec.dist_sequence_id := p_stg_rec.po_line_id;
   END IF;
END validate_po_line_id;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_dsdbi_po_num
--  PURPOSE
--      Validates DSDBI PO Number value
--  DESCRIPTION
--      1) Must not be null
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_dsdbi_po_num
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.dsdbi_po_num IS NULL THEN
      append_error(p_errors_tab, 'DSDBI PO Number not supplied');
   ELSE
      p_tfm_rec.group_code := p_stg_rec.dsdbi_po_num;
      p_tfm_rec.header_description := 'PO Number ' || p_stg_rec.dsdbi_po_num;
   END IF;
END validate_dsdbi_po_num;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_dist_qty
--  PURPOSE
--      Validates Distribution Quantity value
--  DESCRIPTION
--      1) Must be numeric
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_dist_qty
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.dist_quantity IS NULL THEN
      append_error(p_errors_tab, 'Distribution quantity not supplied');
   ELSIF NOT is_number(p_stg_rec.dist_quantity) THEN
      append_error(p_errors_tab, 'Distribution quantity ''' || p_stg_rec.dist_quantity || ''' is not numeric');
   ELSE
      p_tfm_rec.dist_quantity := p_stg_rec.dist_quantity;
   END IF;
END validate_dist_qty;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_dist_num
--  PURPOSE
--      Validates Distribution Number value
--  DESCRIPTION
--      1) Must be numeric
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_dist_num
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.distribution_num IS NULL THEN
      append_error(p_errors_tab, 'Distribution number not supplied');
   ELSIF NOT is_number(p_stg_rec.distribution_num) THEN
      append_error(p_errors_tab, 'Distribution number ''' || p_stg_rec.distribution_num || ''' is not numeric');
   ELSE
      p_tfm_rec.distribution_num := p_stg_rec.distribution_num;
   END IF;
END validate_dist_num;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_unit_price
--  PURPOSE
--      Validates Unit Price value
--  DESCRIPTION
--      1) Must be numeric
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_unit_price
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.price IS NULL THEN
      append_error(p_errors_tab, 'Price not supplied');
   ELSIF NOT is_number(p_stg_rec.price) THEN
      append_error(p_errors_tab, 'Price ''' || p_stg_rec.price || ''' is not numeric');
   ELSE
      p_tfm_rec.unit_price := p_stg_rec.price;
   END IF;
END validate_unit_price;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_quantity
--  PURPOSE
--      Validates Item Quantity value
--  DESCRIPTION
--      1) Must be numeric
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_quantity
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   ln_dist_qty NUMBER;
BEGIN
   SELECT nvl(sum(dist_quantity),0) 
   INTO   ln_dist_qty
   FROM   fmsmgr.xxpo_poreq_conv_stg 
   WHERE  po_line_id = p_stg_rec.po_line_id 
   AND    run_id =  p_stg_rec.run_id;     

   IF p_stg_rec.quantity IS NULL THEN
      append_error(p_errors_tab, 'Quantity not supplied');
   ELSIF NOT is_number(p_stg_rec.quantity) THEN
      append_error(p_errors_tab, 'Quantity ''' || p_stg_rec.quantity || ''' is not numeric');
   ELSIF p_stg_rec.quantity = 0 THEN
      append_error(p_errors_tab, 'Quantity is Zero');
   ELSIF nvl(ln_dist_qty,0) <> nvl(p_stg_rec.quantity,0)*nvl(p_stg_rec.price,0) THEN
      -- Added by Joy Pinto on 25-Aug-2017 .. Ensuring that line qty matches dist Qty
      append_error(p_errors_tab, 'Line Amount : '||nvl(p_stg_rec.quantity,0)*nvl(p_stg_rec.price,0)||' does not match sum of distribution amounts : '||ln_dist_qty);
   ELSE
      p_tfm_rec.quantity := p_stg_rec.quantity;
   END IF;
END validate_quantity;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_line_type
--  PURPOSE
--      Validates Line Type.
--  DESCRIPTION
--      First searches the line type cache to see if it has been queried before
--      If not in the cache, the function queries the database for it
--      Category is then validated:
--        1) Must exist in PO_LINE_TYPES_V
--        2) Must be active
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_line_type
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           po_line_types_v%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   -- first check whether line type was supplied
   IF p_stg_rec.line_type IS NULL THEN
      append_error(p_errors_tab, 'Line Type not supplied');
      RETURN;
   END IF;
   -- look into the cache first and query the database only if it is not there
   IF NOT g_line_type_cache.EXISTS(p_stg_rec.line_type) THEN
      query_line_type(p_stg_rec.line_type, lr_entity_rec);
      -- must exist
      IF lr_entity_rec.line_type_id IS NULL THEN
         append_error(lt_val_errors_tab, 'Line Type ''' || p_stg_rec.line_type || ''' does not exist');
      -- must be active
      ELSIF nvl(lr_entity_rec.inactive_date, SYSDATE + 1) < SYSDATE THEN
         append_error(lt_val_errors_tab, 'Line Type ''' || p_stg_rec.line_type || ''' is inactive');
      END IF;
      -- insert new entry into cache
      g_line_type_cache(p_stg_rec.line_type).po_line_types_rec := lr_entity_rec;
      g_line_type_cache(p_stg_rec.line_type).val_errors := lt_val_errors_tab;
   END IF;
   -- set the output params to the cached values
   p_tfm_rec.line_type_id := g_line_type_cache(p_stg_rec.line_type).po_line_types_rec.line_type_id;
   append_error_tab(p_errors_tab, g_line_type_cache(p_stg_rec.line_type).val_errors);
END validate_line_type;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_category
--  PURPOSE
--      Validates Item Category.
--  DESCRIPTION
--      First searches the category code cache to see if it has been queried before
--      If not in the cache, the function queries the database for it
--      Category is then validated:
--        1) Must not be longe than 40 characters
--        2) Must exist in MTL_CATEGORIES_B
--        3) Must be active
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_category
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           mtl_categories_b%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   -- first check whether category was supplied
   IF p_stg_rec.category IS NULL THEN
      append_error(p_errors_tab, 'Category not supplied');
      RETURN;
   ELSIF length(p_stg_rec.category) > 40 THEN
      append_error(p_errors_tab, 'Category ''' || p_stg_rec.category ||''' too long.  Must be 40 characters or less');
      RETURN;
   END IF;
   -- look into the cache first and query the database only if it is not there
   IF NOT g_category_cache.EXISTS(p_stg_rec.category) THEN
      query_category(p_stg_rec.category, 'DOI', lr_entity_rec);
      -- must exist
      IF lr_entity_rec.segment1 IS NULL THEN
         append_error(lt_val_errors_tab, 'Category ''' || p_stg_rec.category || ''' does not exist as a valid category in category set ''DOI''');
      -- must be active
      ELSIF nvl(lr_entity_rec.disable_date, SYSDATE + 1) < SYSDATE THEN
         append_error(lt_val_errors_tab, 'Category ''' || p_stg_rec.category || ''' is disabled');
      END IF;
      -- insert new entry into cache
      g_category_cache(p_stg_rec.category).mtl_categories_rec := lr_entity_rec;
      g_category_cache(p_stg_rec.category).val_errors := lt_val_errors_tab;
   END IF;
   -- set the output params to the cached values
   p_tfm_rec.category_segment1 := g_category_cache(p_stg_rec.category).mtl_categories_rec.segment1;
   append_error_tab(p_errors_tab, g_category_cache(p_stg_rec.category).val_errors);
END validate_category;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_location_code
--  PURPOSE
--      Validates Location Codes.
--  DESCRIPTION
--      First searches the tax code cache to see if it has been queried before
--      If not in the cache, the function queries the database for it
--      Location Code is then validated:
--        1) Must exist in HR_LOCATIONS
--        2) Must be active
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_location_code
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           hr_locations%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   -- first check whether line type was supplied
   IF p_stg_rec.location IS NULL THEN
      append_error(p_errors_tab, 'Location not supplied');
      RETURN;
   END IF;
   -- look into the cache first and query the database only if it is not there
   IF NOT g_location_cache.EXISTS(p_stg_rec.location) THEN
      query_location_code(p_stg_rec.location, lr_entity_rec);
      -- must exist
      IF lr_entity_rec.location_id IS NULL THEN
         append_error(lt_val_errors_tab, 'Location ''' || p_stg_rec.location || ''' does not exist');
      -- must be active
      ELSIF nvl(lr_entity_rec.inactive_date, SYSDATE + 1) < SYSDATE THEN
         append_error(lt_val_errors_tab, 'Location ''' || p_stg_rec.location || ''' is inactive');
      END IF;
      -- insert new entry into cache
      g_location_cache(p_stg_rec.location).hr_locations_rec := lr_entity_rec;
      g_location_cache(p_stg_rec.location).val_errors := lt_val_errors_tab;
   END IF;
   -- set the output params to the cached values
   p_tfm_rec.deliver_to_location_id := g_location_cache(p_stg_rec.location).hr_locations_rec.location_id;
   append_error_tab(p_errors_tab, g_location_cache(p_stg_rec.location).val_errors);
END validate_location_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_uom_code
--  PURPOSE
--      Validates Unit of Measure codes.
--  DESCRIPTION
--      First searches the tax code cache to see if it has been queried before
--      If not in the cache, the function queries the database for it
--      UOM Code is then validated:
--        1) Must exist in MTL_UNITS_OF_MEASURE_VL
--        2) Must be active
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_uom_code
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           mtl_units_of_measure_vl%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   -- first check whether the tax code was supplied
   IF p_stg_rec.uom_code IS NULL THEN
      append_error(p_errors_tab, 'UOM Code not supplied');
      RETURN;
   END IF;
   -- look into the cache first and query the database only if it is not there
   IF NOT g_uom_code_cache.EXISTS(p_stg_rec.uom_code) THEN
      query_uom_code(p_stg_rec.uom_code, lr_entity_rec);
      -- must exist
      IF lr_entity_rec.uom_code IS NULL THEN
         append_error(lt_val_errors_tab, 'UOM Code ''' || p_stg_rec.uom_code || ''' does not exist');
      -- must be active
      ELSIF nvl(lr_entity_rec.disable_date, SYSDATE + 1) < SYSDATE THEN
         append_error(lt_val_errors_tab, 'UOM Code ''' || p_stg_rec.uom_code || ''' is disabled');
      END IF;
      -- insert new entry into cache
      g_uom_code_cache(p_stg_rec.uom_code).mtl_units_of_measure_rec := lr_entity_rec;
      g_uom_code_cache(p_stg_rec.uom_code).val_errors := lt_val_errors_tab;
   END IF;
   -- set the output params to the cached values
   p_tfm_rec.uom_code := g_uom_code_cache(p_stg_rec.uom_code).mtl_units_of_measure_rec.uom_code;
   append_error_tab(p_errors_tab, g_uom_code_cache(p_stg_rec.uom_code).val_errors);
END validate_uom_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_tax_code
--  PURPOSE
--      Validates tax codes.
--  DESCRIPTION
--      First searches the tax code cache to see if it has been queried before
--      If not in the cache, the function queries the database for it
--      Tax Code is then validated:
--        1) Must exist in AP_TAX_CODES
--        2) Must be enabled and active
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_tax_code
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           ap_tax_codes%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   -- first check whether the tax code was supplied
   IF p_stg_rec.tax_code IS NULL THEN
      append_error(p_errors_tab, 'Tax Code not supplied');
      RETURN;
   END IF;
   -- look into the cache first and query the database only if it is not there
   IF NOT g_tax_code_cache.EXISTS(p_stg_rec.tax_code) THEN
      query_tax_name(p_stg_rec.tax_code, lr_entity_rec);
      -- must exist
      IF lr_entity_rec.tax_id IS NULL THEN
         append_error(lt_val_errors_tab, 'Tax Code ''' || p_stg_rec.tax_code || ''' does not exist');
      -- must be enabled and active
      ELSIF ( nvl(lr_entity_rec.enabled_flag, 'N') = 'N' OR
              nvl(lr_entity_rec.start_date, SYSDATE - 1) > SYSDATE OR
              nvl(lr_entity_rec.inactive_date, SYSDATE + 1) < SYSDATE 
            ) THEN 
         append_error(lt_val_errors_tab, 'Tax Code ''' || p_stg_rec.tax_code || ''' is either disabled or not active');
      END IF;
      -- insert new entry into cache
      g_tax_code_cache(p_stg_rec.tax_code).ap_tax_codes_rec := lr_entity_rec;
      g_tax_code_cache(p_stg_rec.tax_code).val_errors := lt_val_errors_tab;
   END IF;
   -- set the output params to the cached values
   p_tfm_rec.tax_code_id := g_tax_code_cache(p_stg_rec.tax_code).ap_tax_codes_rec.tax_id;
   append_error_tab(p_errors_tab, g_tax_code_cache(p_stg_rec.tax_code).val_errors);
END validate_tax_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_requester
--  PURPOSE
--      Validates requestor is a valid employee.  
--  DESCRIPTION
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_requester
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           per_people_f%ROWTYPE;
   lt_fnd_user_tab         t_fnd_user_tab_type;
BEGIN
   -- first check whether the requestor employee was supplied
   IF p_stg_rec.requester_emp_num IS NULL THEN
      append_error(p_errors_tab, 'Requester employee number not supplied');
      RETURN;
   END IF;
   query_person(p_stg_rec.requester_emp_num, lr_entity_rec);
   IF lr_entity_rec.person_id IS NULL THEN
      append_error(p_errors_tab, 'Requester employee number ' || p_stg_rec.requester_emp_num || ' does not exist');
   ELSE
      -- check that the employee is a valid applications user
      query_fnd_employee(lr_entity_rec.person_id, lt_fnd_user_tab);
      IF lt_fnd_user_tab.COUNT = 0 THEN
         append_error(p_errors_tab, 'Requester employee number ' || p_stg_rec.requester_emp_num || ' is not an FND User');
      ELSIF lt_fnd_user_tab.COUNT > 1 THEN
         append_error(p_errors_tab, 'Requester employee number ' || p_stg_rec.requester_emp_num || ' is linked to more than one FND User');
      ELSIF lt_fnd_user_tab.COUNT = 1 THEN
         IF nvl(lt_fnd_user_tab(1).end_date, SYSDATE + 1) <= SYSDATE THEN
            append_error(p_errors_tab, 'Requester employee number ' || p_stg_rec.requester_emp_num || ' has been end dated as an FND User');
         ELSE
            p_tfm_rec.deliver_to_requestor_id := lr_entity_rec.person_id;
         END IF;
      END IF;
   END IF;
END validate_requester;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_preparer
--  PURPOSE
--      Validates preparer is a valid employee.  The buyer will be the preparer
--  DESCRIPTION
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_preparer
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           per_people_f%ROWTYPE;
   lt_fnd_user_tab         t_fnd_user_tab_type;
BEGIN
   -- first check whether the buyer was supplied
   IF p_stg_rec.buyer_emp_num IS NULL THEN
      append_error(p_errors_tab, 'Buyer (Preparer) employee number not supplied');
      RETURN;
   END IF;
   query_person(p_stg_rec.buyer_emp_num, lr_entity_rec);
   IF lr_entity_rec.person_id IS NULL THEN
      append_error(p_errors_tab, 'Buyer (Preparer) employee number ' || p_stg_rec.buyer_emp_num || ' does not exist');
   ELSE
      -- check that the employee is a valid applications user
      query_fnd_employee(lr_entity_rec.person_id, lt_fnd_user_tab);
      IF lt_fnd_user_tab.COUNT = 0 THEN
         append_error(p_errors_tab, 'Buyer (Preparer) employee number ' || p_stg_rec.buyer_emp_num || ' is not an FND User');
      ELSIF lt_fnd_user_tab.COUNT > 1 THEN
         append_error(p_errors_tab, 'Buyer (Preparer) employee number ' || p_stg_rec.buyer_emp_num || ' is linked to more than one FND User');
      ELSIF lt_fnd_user_tab.COUNT = 1 THEN
         IF nvl(lt_fnd_user_tab(1).end_date, SYSDATE + 1) <= SYSDATE THEN
            append_error(p_errors_tab, 'Buyer (Preparer) employee number ' || p_stg_rec.buyer_emp_num || ' has been end dated as an FND User');
         ELSE
            p_tfm_rec.preparer_id := lr_entity_rec.person_id;
         END IF;
      END IF;
   END IF;
END validate_preparer;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_charge_code
--  PURPOSE
--      Validates account code combination string.
--  DESCRIPTION
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_charge_code
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   l_ccid                 NUMBER;
   l_src_cc_string        VARCHAR2(200);
   lt_val_errors_tab      t_validation_errors_type := t_validation_errors_type();
   l_api_error            VARCHAR2(4000);
   b_val_error            BOOLEAN := FALSE;
BEGIN
   -- first check whether the account combination was supplied
   IF p_stg_rec.charge_account_seg1 IS NULL THEN
      append_error(p_errors_tab, 'Charge code segment1 value not supplied');
      b_val_error := TRUE;
   END IF;
   IF p_stg_rec.charge_account_seg2 IS NULL THEN
      append_error(p_errors_tab, 'Charge code segment2 value not supplied');
      b_val_error := TRUE;
   END IF;
   IF p_stg_rec.charge_account_seg3 IS NULL THEN
      append_error(p_errors_tab, 'Charge code segment3 value not supplied');
      b_val_error := TRUE;
   END IF;
   IF p_stg_rec.charge_account_seg4 IS NULL THEN
      append_error(p_errors_tab, 'Charge code segment4 value not supplied');
      b_val_error := TRUE;
   END IF;
   IF p_stg_rec.charge_account_seg5 IS NULL THEN
      append_error(p_errors_tab, 'Charge code segment5 value not supplied');
      b_val_error := TRUE;
   END IF;
   -- Return if one of the errors was found
   IF b_val_error THEN
      RETURN;
   END IF;
   -- format the source code combination string
   l_src_cc_string := p_stg_rec.charge_account_seg1 || '-' || p_stg_rec.charge_account_seg2 || '-'
      || p_stg_rec.charge_account_seg3 || '-' || p_stg_rec.charge_account_seg4 
      || '-' || p_stg_rec.charge_account_seg5;
   -- look into the cache first and query the database only if it is not there
   IF NOT g_ccid_cache.EXISTS(l_src_cc_string) THEN
      query_ccid(l_src_cc_string, l_ccid, l_api_error);
      -- must be returned by API
      IF l_ccid IS NULL THEN
         append_error(lt_val_errors_tab, 'Invalid charge code: ' || l_api_error);
      END IF;
      -- insert new entry into cache
      g_ccid_cache(l_src_cc_string).code_combination_id := l_ccid;
      g_ccid_cache(l_src_cc_string).val_errors := lt_val_errors_tab;
   END IF;
   -- set the output params to the cached values
   p_tfm_rec.charge_code_id := g_ccid_cache(l_src_cc_string).code_combination_id;
   append_error_tab(p_errors_tab, g_ccid_cache(l_src_cc_string).val_errors);
END validate_charge_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_dff_segments
--  PURPOSE
--      Validates descriptive flexfield values
--  DESCRIPTION
--      Currently is limited to checking mandatory fields against stage row values.
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_dff_segments
(
   p_stg_row               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_flexfield_title       IN VARCHAR2,
   p_context               IN VARCHAR2,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   z_dff_length            CONSTANT NUMBER := 150;
BEGIN
   IF p_stg_row.dff_context IN ('CONSULTANTS/CONTRACTORS', 'OTHER') THEN
      p_tfm_rec.HEADER_ATTRIBUTE3 := p_stg_row.attribute14; -- CMS Contract Number
   ELSIF p_stg_row.dff_context = 'AGENCY STAFF' THEN
      p_tfm_rec.HEADER_ATTRIBUTE3 := p_stg_row.attribute13; -- CMS Contract Number
   END IF;
   -- defaults
   p_tfm_rec.HEADER_ATTRIBUTE1 := 'PRINT'; -- Transmission Method
   p_tfm_rec.HEADER_ATTRIBUTE8 := 'N'; -- Contract Variation Flag
END validate_dff_segments;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_vendor
--  PURPOSE
--      Validates vendors.
--  DESCRIPTION
--      Queries the database for the vendor
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_vendor
(
   p_stg_rec               IN OUT NOCOPY xxpo_poreq_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   SELECT DISTINCT pov.vendor_id, 
          pos.vendor_site_id
   INTO   p_tfm_rec.suggested_vendor_id,
          p_tfm_rec.suggested_vendor_site_id
   FROM   xxap_supplier_conv_tfm s,
          po_vendors pov,
          po_vendor_sites pos
   WHERE  s.source_supplier_number = p_stg_rec.dsdbi_supplier_num
   AND    s.source_site_name = p_stg_rec.dsdbi_supplier_site
   AND    s.status = 'SUCCESS'
   AND    pov.segment1 = s.dtpli_supplier_num
   AND    pos.vendor_site_code = s.dtpli_site_code
   AND    pos.vendor_id = pov.vendor_id;
   debug_msg('found vendor_id=' || p_tfm_rec.suggested_vendor_id);
   debug_msg('found vendor_site_id=' || p_tfm_rec.suggested_vendor_site_id);
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      append_error(p_errors_tab, 'DSDBI Supplier/Site not mapped');
END validate_vendor;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      approve_requisitions
--  PURPOSE
--      Finds open PO Requisition Approval notifications and approves them.
-- --------------------------------------------------------------------------------------------------
PROCEDURE approve_requisitions
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   CURSOR c_notif
   IS
      SELECT notification_id 
      FROM   wf_notifications
      WHERE  message_type = 'REQAPPRV'
      AND    recipient_role = 'CONVERSION'
      AND    status = 'OPEN'
      ORDER BY notification_id; 
BEGIN
   FOR r_notif IN c_notif
   LOOP
      log_msg('Notification Id ' || r_notif.notification_id ||' approved');
      wf_notification.respond(r_notif.notification_id, NULL, 'CONVERSION');
   END LOOP;
   COMMIT;
END approve_requisitions;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      approve_requisitions_cp
--  PURPOSE
--      Concurrent Program wrapper for approve_requisitions
--      Program name: XXPO_POREQ_APPROVE
-- --------------------------------------------------------------------------------------------------
PROCEDURE approve_requisitions_cp
(
   p_errbuff            OUT VARCHAR2,
   p_retcode            OUT NUMBER
)
IS
BEGIN
   approve_requisitions;
   p_retcode := 0;
END approve_requisitions_cp;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      retry_poreq_wf_approval
--  PURPOSE
--      Identifies requisition workflow errors and retries them
-- --------------------------------------------------------------------------------------------------
PROCEDURE retry_poreq_wf_approval
(
   p_item_type          IN  VARCHAR2,
   p_activity           IN  VARCHAR2,
   p_user_id            IN  NUMBER DEFAULT NULL
)  
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   CURSOR c_por(p_item_type IN VARCHAR2, p_activity in VARCHAR2, p_user_id IN NUMBER)
   IS
      SELECT prh.segment1, 
             prh.wf_item_type, 
             prh.wf_item_key, 
             ias.activity_result_code, 
             pa.instance_label
      FROM   po_requisition_headers prh,
             wf_item_activity_statuses ias,
             wf_process_activities pa
      WHERE  ias.item_type = prh.wf_item_type
      AND    ias.item_key = prh.wf_item_key
      AND    ias.activity_status = 'ERROR'
      AND    pa.instance_id = ias.process_activity
      AND    pa.instance_label = upper(p_activity)
      AND    prh.created_by = nvl(p_user_id, prh.created_by) ;
BEGIN
   FOR r_por IN c_por(p_item_type, p_activity, p_user_id)
   LOOP
      log_msg('Requisition ' || r_por.segment1 ||', item key ' || r_por.wf_item_key 
         || ' retrying from activity ' || r_por.instance_label);
      wf_engine.handleerror(r_por.wf_item_type, r_por.wf_item_key, r_por.instance_label, 'RETRY', null);
   END LOOP;
   COMMIT;
END retry_poreq_wf_approval;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      retry_poreq_wf_approval_cp
--  PURPOSE
--      Concurrent Program wrapper for retry_poreq_wf_approval
--      Program name: XXPO_POREQ_WF_RETRY
-- --------------------------------------------------------------------------------------------------
PROCEDURE retry_poreq_wf_approval_cp
(
   p_errbuff            OUT VARCHAR2,
   p_retcode            OUT NUMBER,
   p_item_type          IN  VARCHAR2,
   p_activity           IN  VARCHAR2,
   p_user_id            IN  NUMBER DEFAULT NULL
)
IS
BEGIN
   log_msg('Parameters:');
   log_msg('p_item_type='||p_item_type);
   log_msg('p_activity='||p_activity);
   log_msg('p_user_id='||p_user_id);
   log_msg(' ');
   retry_poreq_wf_approval(p_item_type, p_activity, p_user_id);
   p_retcode := 0;
END retry_poreq_wf_approval_cp;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      validate_load
--  PURPOSE
--      Validates and determines the the final status of transform records against base tables
--  RETURNS
--      Number of successfully imported records into PO
-- --------------------------------------------------------------------------------------------------
FUNCTION validate_load
(
   p_run_id             IN  NUMBER,
   p_run_phase_id       IN  NUMBER,
   p_request_id         IN  NUMBER
)  RETURN NUMBER
IS
   CURSOR c_tfm(p_run_id IN NUMBER, p_request_id IN NUMBER) IS
    /*  SELECT tfm.record_id, -- Commented by Joy Pinto on 16-Aug-2017
             tfm.dsdbi_po_num,
             tfm.req_dist_sequence_id,
             tfm.status,
             prh.requisition_header_id,
             pie.error_message as error_message
      FROM   xxpo_poreq_conv_tfm tfm,
             po_requisition_headers prh,
             po_interface_errors pie,
             po_requisitions_interface pri
      WHERE  run_id IN p_run_id
      AND    prh.request_id(+) = p_request_id
      AND    prh.description(+) = 'PO Number '|| tfm.dsdbi_po_num
      AND    pri.req_dist_sequence_id(+) = tfm.req_dist_sequence_id
      AND    pri.request_id(+) = p_request_id
      AND    pie.interface_transaction_id(+) = pri.transaction_id
      AND    pie.interface_type(+) = 'REQIMPORT'
      FOR UPDATE OF status;
      */
      SELECT tfm.record_id,
             tfm.dsdbi_po_num,
             tfm.req_dist_sequence_id,
             tfm.status,
             pieh.error_message as error_message
      FROM   po_requisitions_interface_all pri, 
             po_interface_errors pieh, 
             fmsmgr.xxpo_poreq_conv_tfm tfm
      WHERE  pri.process_flag = 'ERROR'
      AND    pri.request_id = p_request_id
      AND    pieh.interface_transaction_id = pri.transaction_id
      AND    pieh.table_name = 'PO_REQUISITIONS_INTERFACE'
      AND    tfm.req_dist_sequence_id = pri.req_dist_sequence_id
      AND    tfm.run_id = p_run_id
      FOR UPDATE OF status;
      
   CURSOR c_tfm_dist(p_run_id IN NUMBER, p_request_id IN NUMBER) IS
      SELECT tfm.record_id,
             tfm.dsdbi_po_num,
             tfm.req_dist_sequence_id,
             tfm.status,
             pied.error_message as error_message
      FROM   po_req_dist_interface_all prdi, 
             po_interface_errors pied, 
             fmsmgr.xxpo_poreq_conv_tfm tfm
      WHERE  prdi.process_flag = 'ERROR'
      AND    prdi.request_id = p_request_id
      AND    pied.interface_transaction_id = prdi.transaction_id
      AND    pied.table_name = 'PO_REQ_DIST_INTERFACE'
      AND    tfm.dist_sequence_id = prdi.dist_sequence_id
      AND    tfm.run_id = p_run_id
      FOR UPDATE OF status;   
      

   l_status               xxpo_poreq_conv_tfm.status%TYPE;
   l_error_msg            dot_int_run_phase_errors.error_text%TYPE;
   r_error                dot_int_run_phase_errors%ROWTYPE;
   r_error_dist           dot_int_run_phase_errors%ROWTYPE;
   l_success_count        NUMBER := 0;
   l_rejected_count       NUMBER := 0;
BEGIN
   FOR r_tfm IN c_tfm(p_run_id, p_request_id)
   LOOP
         l_status := 'REJECTED';
         l_rejected_count := l_rejected_count + 1;
         l_error_msg := nvl(r_tfm.error_message, 'Rejected by Requisition Import');
         r_error.run_id := p_run_id;
         r_error.run_phase_id := p_run_phase_id;
         r_error.int_table_key_val1 := r_tfm.dsdbi_po_num;
         r_error.int_table_key_val2 := r_tfm.req_dist_sequence_id;
         r_error.record_id := r_tfm.record_id;
         r_error.error_text := l_error_msg;
         raise_error(r_error);
      UPDATE xxpo_poreq_conv_tfm
         SET status = l_status
           , run_phase_id = p_run_phase_id
       WHERE CURRENT OF c_tfm;
   END LOOP;
   
   FOR r_tfm IN c_tfm_dist(p_run_id, p_request_id)
   LOOP
         l_status := 'REJECTED';
         l_rejected_count := l_rejected_count + 1;
         l_error_msg := nvl(r_tfm.error_message, 'Rejected by Requisition Import');
         r_error_dist.run_id := p_run_id;
         r_error_dist.run_phase_id := p_run_phase_id;
         r_error_dist.int_table_key_val1 := r_tfm.dsdbi_po_num;
         r_error_dist.int_table_key_val2 := r_tfm.req_dist_sequence_id;
         r_error_dist.record_id := r_tfm.record_id;
         r_error_dist.error_text := l_error_msg;
         raise_error(r_error);
      UPDATE xxpo_poreq_conv_tfm
         SET status = l_status
           , run_phase_id = p_run_phase_id
       WHERE CURRENT OF c_tfm;
   END LOOP;   
   
   UPDATE xxpo_poreq_conv_tfm tfm
      SET status = 'SUCCESS'
    WHERE tfm.run_id = p_run_id
    AND   tfm.status  = 'LOADED';
   
   SELECT SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) ,
          SUM(CASE WHEN status = 'REJECTED' THEN 1 ELSE 0 END)
   INTO   l_success_count,
           l_rejected_count
   FROM   xxpo_poreq_conv_tfm tfm
   WHERE  tfm.run_id = p_run_id;
   
   debug_msg('updated ' || l_success_count || ' transform rows to status success');
   debug_msg('updated ' || l_rejected_count || ' transform rows to status rejected');
   RETURN l_success_count;
END validate_load;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_fnd_user_id
--  PURPOSE
--      Queries the ID of FND_USER from the user name
-- --------------------------------------------------------------------------------------------------
FUNCTION get_fnd_user_id
(
   p_user_name         IN VARCHAR2
) RETURN NUMBER
IS
   l_user_id         NUMBER;
BEGIN
   SELECT user_id
   INTO   l_user_id
   FROM   fnd_user
   WHERE  user_name = p_user_name
   AND    SYSDATE <= nvl(end_date, SYSDATE + 1);
   RETURN l_user_id;
EXCEPTION 
   WHEN OTHERS THEN
      RETURN NULL;
END get_fnd_user_id;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_employee_id
--  PURPOSE
--      Queries the ID of employee based on the employee number
-- --------------------------------------------------------------------------------------------------
FUNCTION get_employee_id
(
   p_emp_number         IN VARCHAR2
) RETURN NUMBER
IS
   l_emp_id       NUMBER;
BEGIN
   SELECT person_id
   INTO   l_emp_id
   FROM   per_people_f
   WHERE  employee_number = p_emp_number
   AND    SYSDATE BETWEEN effective_start_date AND effective_end_date
   AND    SYSDATE >= start_date;
   RETURN l_emp_id;
EXCEPTION
  WHEN OTHERS THEN 
     RETURN NULL;
END get_employee_id;

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
      p_files_tab.DELETE;
END get_interface_files;

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
   b_wait              BOOLEAN;
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
--  FUNCTION
--      submit_xxpoporeq_wf_retry
--  PURPOSE
--       Submits the interface framework program XXINTSQLLDR (DEDJTR Interface Framework SQLLDR)
--       This loads a file into staging tables.
--  RETURNS
--       Concurrent Request Id of the submitted request
-- --------------------------------------------------------------------------------------------------
FUNCTION submit_xxpoporeq_wf_retry
(
   p_item_type          IN  VARCHAR2,
   p_activity           IN  VARCHAR2,
   p_user_id            IN  NUMBER DEFAULT NULL,
   p_wait               IN  NUMBER DEFAULT 0 -- minutes
) RETURN NUMBER
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_retry_req_id       NUMBER;
BEGIN
   l_retry_req_id := fnd_request.submit_request
      ( application => 'POC',
        program     => 'XXPO_POREQ_WF_RETRY',
        description => NULL,
        start_time  => fnd_conc_date.string_to_date(SYSDATE+(1/24/60*p_wait)),
        sub_request => FALSE,
        argument1   => p_item_type,
        argument2   => p_activity,
        argument3   => p_user_id );
   COMMIT;
   RETURN l_retry_req_id;
END submit_xxpoporeq_wf_retry;

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
   l_sqlldr_req_id     NUMBER;
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
   p_int_req_id         IN NUMBER,
   p_in_dir             IN VARCHAR2,
   p_file               IN VARCHAR2,
   p_appl_id            IN NUMBER
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
--  PROCEDURE
--      get_interface_defn
--  PURPOSE
--       Selects the interface definition of the current interface.  Creates it if it doesn't exist.
-- --------------------------------------------------------------------------------------------------
PROCEDURE get_interface_defn
(
   p_int_code           IN dot_int_interfaces.int_code%TYPE,
   p_int_name           IN dot_int_interfaces.int_name%TYPE,
   p_request_id         IN NUMBER,
   p_interface_dfn      IN OUT NOCOPY dot_int_interfaces%ROWTYPE
) IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_user_id              NUMBER := fnd_profile.value('USER_ID');
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
         'PO',
         'Y',
         SYSDATE,
         l_user_id,
         l_user_id,
         SYSDATE,
         l_user_id,
         p_request_id
      );
   COMMIT;
END get_interface_defn;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      update_stage_run_ids
--  PURPOSE
--      Updates the stage tables with values for run_id, run_phase_id, status, created_by and 
--      creation_date where these values are NULL.  They would be NULL if they have only just been 
--      loaded.
-- --------------------------------------------------------------------------------------------------
PROCEDURE update_stage_run_ids
(
   p_run_id              IN   NUMBER,
   p_run_phase_id        IN   NUMBER,
   p_status              IN   VARCHAR2,
   p_row_count           OUT  NUMBER
)
IS
   l_user_id            NUMBER := fnd_profile.value('USER_ID');
BEGIN
   UPDATE xxpo_poreq_conv_stg
   SET    run_id = p_run_id,
          run_phase_id = p_run_phase_id,
          status = p_status,
          created_by = l_user_id
   WHERE  run_id || run_phase_id IS NULL;
   p_row_count := SQL%ROWCOUNT;
END update_stage_run_ids;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      initialise_dff_cache
--  PURPOSE
--      Initialises the DFF cache.
--  DESCRIPTION
--      This populates the DFF associative array cache with valuess so that they can be
--      accessed using application column names
-- --------------------------------------------------------------------------------------------------
PROCEDURE initialise_dff_cache
(
   p_flex_appl_id          IN NUMBER,
   p_flexfield_name        IN VARCHAR2,
   p_flex_context          IN VARCHAR2
) IS
   TYPE lt_dff_col_usage_tab_type IS TABLE OF fnd_descr_flex_column_usages%ROWTYPE INDEX BY BINARY_INTEGER;
   lr_dff_col_usage_tab    lt_dff_col_usage_tab_type;
BEGIN
   SELECT * BULK COLLECT
   INTO   lr_dff_col_usage_tab
   FROM   fnd_descr_flex_column_usages
   WHERE  application_id = p_flex_appl_id
   AND    descriptive_flexfield_name = p_flexfield_name
   AND    descriptive_flex_context_code = p_flex_context
   AND    enabled_flag = 'Y'
   ORDER BY column_seq_num;
   --
   IF lr_dff_col_usage_tab.COUNT > 0 THEN
      FOR i IN lr_dff_col_usage_tab.FIRST..lr_dff_col_usage_tab.LAST
      LOOP
         g_dff_cache(lr_dff_col_usage_tab(i).application_column_name) := lr_dff_col_usage_tab(i);
      END LOOP;
   END IF;
END initialise_dff_cache;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      submit_reqimport
--  PURPOSE
--       Submits the standard import program REQIMPORT (Requisition Import)
--  RETURNS
--       Concurrent Request Id of the submitted request
-- --------------------------------------------------------------------------------------------------
FUNCTION submit_reqimport
(
   p_source              IN VARCHAR2 
) RETURN NUMBER
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_reqimport_req_id    NUMBER;
BEGIN
   l_reqimport_req_id := fnd_request.submit_request
      ( application => 'PO',
        program     => 'REQIMPORT',
        description => NULL,
        start_time  => NULL,
        sub_request => FALSE,
        argument1   => p_source,
        argument2   => NULL,    -- import batch id 
        argument3   => 'ALL',   -- group by
        argument4   => NULL,    -- last requisition number
        argument5   => 'Y',     -- multiple distributions
        argument6   => 'Y'     -- initiate approval
        );
   COMMIT;
   RETURN l_reqimport_req_id;
END submit_reqimport;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      insert_interface_dist
--  PURPOSE
--      Inserts a row into the open interface table PO_REQ_DIST_INTERFACE.
-- --------------------------------------------------------------------------------------------------
PROCEDURE insert_interface_dist
(
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE
) IS
BEGIN
   insert into po_req_dist_interface
   (
      charge_account_id,
      destination_organization_id,
      distribution_number,
      dist_sequence_id,
      interface_source_code,
      org_id,
      quantity,
      destination_type_code,
      gl_date
   )
   values
   (
      p_tfm_rec.charge_code_id,
      p_tfm_rec.destination_organization_id,
      p_tfm_rec.distribution_num,
      p_tfm_rec.dist_sequence_id,
      p_tfm_rec.interface_source_code,
      p_tfm_rec.org_id,
      p_tfm_rec.dist_quantity,
      p_tfm_rec.destination_type_code,
      p_tfm_rec.dist_gl_date
   );
END insert_interface_dist;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      insert_interface
--  PURPOSE
--      Inserts a row into the open interface table PO_REQUISITIONS_INTERFACE.
-- --------------------------------------------------------------------------------------------------
PROCEDURE insert_interface
(
   p_tfm_rec               IN OUT NOCOPY xxpo_poreq_conv_tfm%ROWTYPE
) IS
BEGIN
   insert into po_requisitions_interface
   (      
      interface_source_code,
      source_type_code,
      destination_type_code,
      item_description,
      quantity,
      unit_price,
      authorization_status,
      group_code,
      approver_id,
      preparer_id,
      header_description,
      header_attribute1,
      header_attribute3,
      header_attribute7,
      header_attribute8,
      category_segment1,
      uom_code,
      line_type_id,
      destination_organization_id,
      deliver_to_location_id,
      deliver_to_requestor_id,
      suggested_vendor_id,
      suggested_vendor_site_id,
      org_id,
      multi_distributions,
      req_dist_sequence_id,
      tax_code_id
   )
   values
   (
      p_tfm_rec.interface_source_code,
      p_tfm_rec.source_type_code,
      p_tfm_rec.destination_type_code,
      p_tfm_rec.item_description,
      p_tfm_rec.quantity,
      p_tfm_rec.unit_price,
      p_tfm_rec.authorization_status,
      p_tfm_rec.group_code,
      p_tfm_rec.approver_id,
      p_tfm_rec.preparer_id,
      p_tfm_rec.header_description,
      p_tfm_rec.header_attribute1,
      p_tfm_rec.header_attribute3,
      p_tfm_rec.header_attribute7,
      p_tfm_rec.header_attribute8,
      p_tfm_rec.category_segment1,
      p_tfm_rec.uom_code,
      p_tfm_rec.line_type_id,
      p_tfm_rec.destination_organization_id,
      p_tfm_rec.deliver_to_location_id,
      p_tfm_rec.deliver_to_requestor_id,
      p_tfm_rec.suggested_vendor_id,
      p_tfm_rec.suggested_vendor_site_id,
      p_tfm_rec.org_id,
      p_tfm_rec.multi_distributions,
      p_tfm_rec.req_dist_sequence_id,
      p_tfm_rec.tax_code_id
   );
END insert_interface;

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
   /* End run phase              */
   /******************************/
   dot_common_int_pkg.end_run_phase
             (p_run_phase_id  => l_run_phase_id,
              p_status        => 'SUCCESS',
              p_error_count   => 0,
              p_success_count => l_stg_rows_loaded);

   /******************************/
   /* Wait for request           */
   /******************************/
   wait_for_request(l_sqlldr_req_id, 5, r_srs_xxintsqlldr);

   IF NOT ( r_srs_xxintsqlldr.srs_dev_phase = 'COMPLETE' AND
            r_srs_xxintsqlldr.srs_dev_status IN ('NORMAL','WARNING') ) THEN
      l_message := replace(SUBSTR(g_error_message_03, 11, 100), '$INT_FILE', p_file);
      log_msg(g_error || l_message);
      p_request.error_message := l_message;
      p_request.status := 'ERROR';
   ELSE
      p_request.status := 'SUCCESS';
      -- Update the stage rows with run ids
      update_stage_run_ids(l_run_id, l_run_phase_id, 'PROCESSED', l_stg_rows_loaded);
      debug_msg('updated ' || l_stg_rows_loaded || ' stage runs ids with run_id '||l_run_id);
   END IF;

   /******************************/
   /* Interface Control Record   */
   /******************************/
   xxint_common_pkg.interface_request(p_request);
   debug_msg('file staging (status=' || p_request.status || ')');

   /******************************/
   /* Update run phase           */
   /******************************/
   dot_common_int_pkg.update_run_phase
          (p_run_phase_id => l_run_phase_id,
           p_src_code     => g_src_code,
           p_rec_count    => l_stg_rows_loaded,
           p_hash_total   => NULL,
           p_batch_name   => g_int_batch_name);

   /******************************/
   /* End run phase              */
   /******************************/
   dot_common_int_pkg.end_run_phase
             (p_run_phase_id  => l_run_phase_id,
              p_status        => 'SUCCESS',
              p_error_count   => 0,
              p_success_count => l_stg_rows_loaded);

   /******************************/
   /* Return status              */
   /******************************/
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
--       Updates the Stage row status to VALIDATED or ERROR as it goes
--  RETURNS
--       True if successful, otherwise False
-- --------------------------------------------------------------------------------------------------
FUNCTION transform
(
   p_run_id        IN   NUMBER,
   p_run_phase_id  OUT  NUMBER,
   p_file_name     IN   VARCHAR2,
   p_int_mode      IN   VARCHAR2
) RETURN BOOLEAN
IS
   CURSOR c_stg(p_run_id IN NUMBER) IS
      SELECT *
      FROM   xxpo_poreq_conv_stg
      WHERE  run_id = p_run_id
      FOR UPDATE OF status
      ORDER BY record_id;

   r_stg                   c_stg%ROWTYPE;
   r_tfm                   xxpo_poreq_conv_tfm%ROWTYPE;
   l_run_id                NUMBER := p_run_id;
   l_run_phase_id          NUMBER;
   l_total                 NUMBER;
   r_error                 dot_int_run_phase_errors%ROWTYPE;
   l_tfm_count             NUMBER := 0;
   l_stg_count             NUMBER := 0;
   b_stg_row_valid         BOOLEAN := TRUE;
   l_val_err_count         NUMBER := 0;
   l_err_count             NUMBER := 0;
   l_user_id               NUMBER := fnd_profile.value('USER_ID');
   l_status                VARCHAR2(30);
   -- validation variables
   l_val_errors_tab        t_validation_errors_type;
BEGIN
   /************************************/
   /* Initialize Transform Run Phase   */
   /************************************/
   l_run_phase_id := dot_common_int_pkg.start_run_phase
      ( p_run_id                  => l_run_id,
        p_phase_code              => 'TRANSFORM',
        p_phase_mode              => p_int_mode,
        p_int_table_name          => 'XXPO_POREQ_CONV_STG',
        p_int_table_key_col1      => 'DSDBI_PO_NUM',
        p_int_table_key_col_desc1 => 'PO Number',
        p_int_table_key_col2      => 'PO_LINE_ID',
        p_int_table_key_col_desc2 => 'Line Id',
        p_int_table_key_col3      => NULL,
        p_int_table_key_col_desc3 => NULL );

   p_run_phase_id := l_run_phase_id;
   r_error.run_id := l_run_id;
   r_error.run_phase_id := l_run_phase_id;

   debug_msg('interface framework (run_transform_id=' || l_run_phase_id || ')');

   SELECT COUNT(1)
   INTO   l_total
   FROM   xxpo_poreq_conv_stg
   WHERE  run_id = l_run_id;

   /******************************/
   /* Update run phase           */
   /******************************/
   dot_common_int_pkg.update_run_phase
      ( p_run_phase_id => l_run_phase_id,
        p_src_code     => g_src_code,
        p_rec_count    => l_total,
        p_hash_total   => NULL,
        p_batch_name   => g_int_batch_name );

   /**********************/
   /* Process STG rows   */
   /**********************/
   OPEN c_stg(l_run_id);
   LOOP
      FETCH c_stg INTO r_stg;
      EXIT WHEN c_stg%NOTFOUND;
      -- initilise and increment 
      l_stg_count := l_stg_count + 1;
      b_stg_row_valid := TRUE;
      r_tfm := NULL;
      r_error.int_table_key_val1 := r_stg.dsdbi_po_num;
      r_error.int_table_key_val2 := r_stg.po_line_id;

      /***********************************/
      /* Validation and Mapping          */
      /***********************************/
      debug_msg('Validating [dsdbi_po_num=' || r_stg.dsdbi_po_num || '][po_line_id=' || r_stg.po_line_id || ']');
      validate_dsdbi_po_num(r_stg, r_tfm, l_val_errors_tab);
      validate_vendor(r_stg, r_tfm, l_val_errors_tab);
      validate_line_type(r_stg, r_tfm, l_val_errors_tab);
      validate_charge_code(r_stg, r_tfm, l_val_errors_tab);
      validate_preparer(r_stg, r_tfm, l_val_errors_tab);
      validate_requester(r_stg, r_tfm, l_val_errors_tab);
      validate_tax_code(r_stg, r_tfm, l_val_errors_tab);
      validate_uom_code(r_stg, r_tfm, l_val_errors_tab);
      validate_quantity(r_stg, r_tfm, l_val_errors_tab);
      validate_unit_price(r_stg, r_tfm, l_val_errors_tab);
      validate_dist_num(r_stg, r_tfm, l_val_errors_tab);
      validate_dist_qty(r_stg, r_tfm, l_val_errors_tab);
      validate_po_line_id(r_stg, r_tfm, l_val_errors_tab);
      validate_location_code(r_stg, r_tfm, l_val_errors_tab);
      validate_category(r_stg, r_tfm, l_val_errors_tab);
      validate_dff_segments(r_stg, 'Requisition Headers', g_source, r_tfm, l_val_errors_tab);
      
      -- get the next record_id
      SELECT xxpo_poreq_record_id_s.NEXTVAL
      INTO   r_tfm.RECORD_ID
      FROM   dual;

      /*****************************************/
      /* Raise validation errors if they exist */
      /*****************************************/
      r_error.record_id := r_tfm.RECORD_ID;
      IF l_val_errors_tab.COUNT > 0 THEN
         FOR i IN l_val_errors_tab.FIRST..l_val_errors_tab.LAST
         LOOP
            r_error.error_text := l_val_errors_tab(i);
            raise_error(r_error);
            log_msg(g_error || r_error.error_text);
         END LOOP;
         l_val_err_count := l_val_err_count + 1;
         r_tfm.STATUS := 'ERROR';
         l_val_errors_tab.DELETE;
      ELSE
         l_tfm_count := l_tfm_count + 1;
         r_tfm.STATUS := 'VALIDATED';
      END IF;
      
      /***********************************/
      /* Transform / Mapping             */
      /***********************************/
      -- interface framework columns
      r_tfm.SOURCE_RECORD_ID := r_stg.record_id;
      r_tfm.RUN_ID := l_run_id;
      r_tfm.RUN_PHASE_ID := l_run_phase_id;
      -- who columns
      r_tfm.CREATED_BY := l_user_id;
      r_tfm.CREATION_DATE := SYSDATE;
      r_tfm.LAST_UPDATED_BY := l_user_id;
      r_tfm.LAST_UPDATE_DATE := SYSDATE;
      -- audit columns
      r_tfm.DSDBI_SUPPLIER_NUM := r_stg.dsdbi_supplier_num;
      r_tfm.DSDBI_SUPPLIER_ID := r_stg.dsdbi_supplier_id;
      r_tfm.DSDBI_SUPPLIER_NAME := r_stg.dsdbi_supplier_name;
      r_tfm.DSDBI_SUPPLIER_SITE_ID := r_stg.dsdbi_supplier_id;
      r_tfm.DSDBI_SUPPLIER_SITE := r_stg.dsdbi_supplier_site;
      r_tfm.DSDBI_PO_NUM := r_stg.dsdbi_po_num;
      r_tfm.DSDBI_PO_HEADER_ID := r_stg.po_header_id;
      r_tfm.DSDBI_PO_LINE_ID := r_stg.po_line_id;
      -- other columns
      r_tfm.INTERFACE_SOURCE_CODE := 'CONVERSION';
      r_tfm.SOURCE_TYPE_CODE := 'VENDOR';
      r_tfm.DESTINATION_TYPE_CODE := 'EXPENSE';
      r_tfm.ITEM_DESCRIPTION := r_stg.line_description;
      r_tfm.AUTHORIZATION_STATUS := 'INCOMPLETE';
      r_tfm.APPROVER_ID := g_conv_emp_id;
      r_tfm.DESTINATION_ORGANIZATION_ID := g_org_id;
      r_tfm.ORG_ID := g_org_id;
      r_tfm.MULTI_DISTRIBUTIONS := 'Y';
      r_tfm.DIST_GL_DATE := SYSDATE;
      
      /*************************************/
      /* Insert single row into TFM table  */
      /*************************************/
      BEGIN
         INSERT INTO xxpo_poreq_conv_tfm VALUES r_tfm;
      EXCEPTION
         WHEN OTHERS THEN
            r_error.record_id := r_stg.record_id;
            r_error.msg_code := SQLCODE;
            r_error.error_text := SQLERRM;
            raise_error(r_error);
            -- Update the stage table row with error status
            UPDATE xxpo_poreq_conv_stg SET status = 'ERROR' WHERE CURRENT OF c_stg;
            l_err_count := l_err_count + 1;
      END;

   END LOOP;

   debug_msg('inserted ' || l_tfm_count || ' transform rows with status validated');
   debug_msg('inserted ' || l_val_err_count || ' transform rows with status error');
   debug_msg('updated ' || l_err_count || ' stage rows with status error');

   IF (l_val_err_count > 0) OR (l_err_count > 0) THEN
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
        p_error_count   => l_val_err_count + l_err_count,
        p_success_count => l_tfm_count);

   IF l_status = 'ERROR' THEN
      RETURN FALSE;
   END IF;
   RETURN TRUE;
END transform;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      load
--  PURPOSE
--       Loads data from the Transform table to the Open Interface table (GL_INTERFACE).
--  DESCRIPTION
--       Updates the Transform row status to LOADED or ERROR as it goes
--  RETURNS
--       True if successful, otherwise False
-- --------------------------------------------------------------------------------------------------
FUNCTION load
(
   p_run_id                IN  NUMBER,
   p_run_phase_id          OUT NUMBER
)  RETURN BOOLEAN
IS
   CURSOR c_tfm IS
      SELECT *
      FROM   xxpo_poreq_conv_tfm
      WHERE  run_id = p_run_id
      AND    status = 'VALIDATED'
      ORDER  BY group_code, dist_sequence_id 
      FOR UPDATE OF status;

   r_tfm                   xxpo_poreq_conv_tfm%ROWTYPE;
   l_run_id                NUMBER := p_run_id;
   l_run_phase_id          NUMBER;
   l_total                 NUMBER := 0;
   l_error_count           NUMBER := 0;
   l_tfm_count             NUMBER := 0;
   l_load_count            NUMBER := 0;
   l_load_success_cnt      NUMBER := 0;
   r_error                 dot_int_run_phase_errors%ROWTYPE;
   r_srs_reqimport         r_srs_request_type;
   l_status                VARCHAR2(240);
   l_wip_invoice_id        NUMBER := 0;
   l_reqimport_req_id      NUMBER;
   l_batch_id              NUMBER;
BEGIN
   /*******************************/
   /* Initialise Load Phase       */
   /*******************************/
   l_run_phase_id := dot_common_int_pkg.start_run_phase
      ( p_run_id                  => l_run_id,
        p_phase_code              => 'LOAD',
        p_phase_mode              => NULL,
        p_int_table_name          => 'XXPO_POREQ_CONV_TFM',
        p_int_table_key_col1      => 'DSDBI_PO_NUM',
        p_int_table_key_col_desc1 => 'PO Number',
        p_int_table_key_col2      => 'PO_LINE_ID',
        p_int_table_key_col_desc2 => 'Line Id',
        p_int_table_key_col3      => NULL,
        p_int_table_key_col_desc3 => NULL );

   p_run_phase_id := l_run_phase_id;
   r_error.run_id := l_run_id;
   r_error.run_phase_id := l_run_phase_id;
   debug_msg('interface framework (run_load_id=' || l_run_phase_id || ')');

   SELECT COUNT(1)
   INTO   l_total
   FROM   xxpo_poreq_conv_tfm
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
      r_error.int_table_key_val1 := r_tfm.dsdbi_po_num;
      r_error.int_table_key_val2 := r_tfm.req_dist_sequence_id;
      BEGIN
         IF NOT g_sequence_cache.EXISTS(r_tfm.dist_sequence_id) THEN
            insert_interface(r_tfm);
            g_sequence_cache(r_tfm.dist_sequence_id) := r_tfm.dist_sequence_id;
         END IF;
         insert_interface_dist(r_tfm);
         l_load_count := l_load_count + 1;
         UPDATE xxpo_poreq_conv_tfm 
            SET status = 'LOADED'
          WHERE CURRENT OF c_tfm;
      EXCEPTION
         WHEN OTHERS THEN
            r_error.msg_code := SQLCODE;
            r_error.error_text := SQLERRM;
            raise_error(r_error);
            l_error_count := l_error_count + 1;
            UPDATE xxpo_poreq_conv_tfm 
               SET status = 'ERROR'
             WHERE CURRENT OF c_tfm;
      END;
   END LOOP;
   -- release the cache memory as it's no longer needed
   g_sequence_cache.DELETE;

   COMMIT; -- required so that import program will see the rows

   debug_msg('inserted ' || l_load_count || ' rows into open interface');
   debug_msg('updated ' || l_error_count || ' transform rows to error status');

   /**********************************/
   /* Determine status               */
   /**********************************/
   IF l_error_count > 0 THEN
      l_status := 'ERROR';
   ELSE
      /*********************************/
      /* Submit Requisition Import        */
      /*********************************/
      l_reqimport_req_id := submit_reqimport('CONVERSION');
      debug_msg('Requisition Import (request_id=' || l_reqimport_req_id || ')');
      /******************************/
      /* Wait for request           */
      /******************************/
      wait_for_request(l_reqimport_req_id, 5, r_srs_reqimport);
      IF NOT ( r_srs_reqimport.srs_dev_phase = 'COMPLETE' AND
               r_srs_reqimport.srs_dev_status IN ('NORMAL','WARNING') ) THEN
         log_msg(g_error || 'Requisition Import failed');
         l_status := 'ERROR';
         l_error_count := l_total; -- effectively all have failed
      ELSE
         -- check that the import program actually created the invoices
         l_load_success_cnt := validate_load(p_run_id, l_run_phase_id, l_reqimport_req_id);
         IF l_load_success_cnt = l_total THEN
            l_status := 'SUCCESS';
            l_error_count := 0;
         ELSE
            l_status := 'ERROR';
            l_error_count := l_total - l_load_success_cnt;
         END IF;
      END IF;
   END IF;
   
   /*******************/
   /* End run phase   */
   /*******************/
   dot_common_int_pkg.end_run_phase
      ( p_run_phase_id  => l_run_phase_id,
        p_status        => l_status,
        p_error_count   => l_error_count,
        p_success_count => l_load_success_cnt);

   IF l_status = 'ERROR' THEN
      RETURN FALSE;
   END IF;
   RETURN TRUE;
END load;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      process_reqs
--  PURPOSE
--       Concurrent Program XXPO_POREQ_CONV (DEDJTR Requisition Conversion)
--  DESCRIPTION
--       Main program controller
-- --------------------------------------------------------------------------------------------------
PROCEDURE process_reqs
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_source            IN  VARCHAR2,
   p_file_name         IN  VARCHAR2,
   p_control_file      IN  VARCHAR2,
   p_submit_import     IN  VARCHAR2,
   p_debug_flag        IN  VARCHAR2,
   p_int_mode          IN  VARCHAR2
) IS
   z_procedure_name           CONSTANT VARCHAR2(150) := 'xxpo_poreq_conv_pkg.process_reqs';
   z_app                      CONSTANT VARCHAR2(2) :=  'PO';
   l_user_name                VARCHAR2(60);
   l_req_id                   NUMBER;
   l_appl_id                  NUMBER;
   l_file                     VARCHAR2(150);
   l_log                      VARCHAR2(150);
   l_bad                      VARCHAR2(150);
   l_ctl                      VARCHAR2(150);
   l_inbound_directory        fnd_flex_values_tl.description%TYPE;
   l_outbound_directory       fnd_flex_values_tl.description%TYPE;
   l_staging_directory        fnd_flex_values_tl.description%TYPE;
   l_archive_directory        fnd_flex_values_tl.description%TYPE;
   x_message                  VARCHAR2(1000);
   l_tfm_mode                 VARCHAR2(60);
   lr_interface_dfn           dot_int_interfaces%ROWTYPE;
   l_getfile_req_id           NUMBER;
   r_srs_xxintifr             r_srs_request_type;
   l_run_error                NUMBER := 0;
   r_request                  xxint_common_pkg.CONTROL_RECORD_TYPE;
   l_message                  VARCHAR2(240);
   t_files_tab                t_varchar_tab_type;
   l_run_id                   NUMBER;
   l_run_phase_id             NUMBER;
   l_rep_req_id               NUMBER;
   l_err_req_id               NUMBER;
   l_wf_retry_req_id          NUMBER;
   e_interface_error          EXCEPTION;
BEGIN
   /******************************************/
   /* Pre-process validation                 */
   /******************************************/
   xxint_common_pkg.g_object_type := 'REQUISITIONS';
   l_req_id := fnd_global.conc_request_id;
   l_appl_id := fnd_global.resp_appl_id;
   l_user_name := fnd_profile.value('USERNAME');
   g_conv_emp_id := get_employee_id('CONVERSION');
   g_conv_user_id := get_fnd_user_id('CONVERSION');
   g_org_id := fnd_profile.value('ORG_ID');
   g_debug_flag := nvl(p_debug_flag, 'N');
   g_source := SUBSTR(p_source, 1, 80);
   l_ctl := nvl(p_control_file, g_ctl);
   l_file := nvl(p_file_name, g_file);
   l_tfm_mode := nvl(p_int_mode, g_int_mode);

   debug_msg('procedure name ' || z_procedure_name || '.');
   
   /****************************/
   /* Validate User running    */
   /****************************/
   IF l_user_name <> 'CONVERSION' THEN
      log_msg('User running this conversion is not CONVERSION (expected CONVERSION, actual ' || upper(l_user_name) || ')');
      p_retcode := 2;
      RETURN;
   END IF;

   /****************************/
   /* Get Interface ID         */
   /****************************/
   debug_msg('check interface registry for ' || g_int_code || '.');
   get_interface_defn(g_int_code, g_int_name, l_req_id, lr_interface_dfn);
   IF nvl(lr_interface_dfn.enabled_flag, 'Y') = 'N' THEN
      log_msg(g_error || replace(SUBSTR(g_error_message_01, 11, 100), '$INT_CODE', g_int_code));
      p_retcode := 2;
      RETURN;
   END IF;

   /****************************/
   /* Get Directory Info       */
   /****************************/
   debug_msg('retrieving interface directory information');

   l_inbound_directory := xxint_common_pkg.interface_path
      ( p_application => z_app,
        p_source  => p_source,
        p_in_out  => 'INBOUND',
        p_message => x_message );
   IF x_message IS NOT NULL THEN
      log_msg(g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_outbound_directory := xxint_common_pkg.interface_path
      ( p_application => z_app,
        p_source  => p_source,
        p_in_out  => 'OUTBOUND',
        p_message => x_message );
   IF x_message IS NOT NULL THEN
      log_msg(g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_staging_directory := xxint_common_pkg.interface_path
      ( p_application => z_app,
        p_source  => p_source,
        p_in_out  => 'WORKING',
        p_message => x_message );
   IF x_message IS NOT NULL THEN
      log_msg(g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_archive_directory := xxint_common_pkg.interface_path
      ( p_application => z_app,
        p_source  => p_source,
        p_archive => 'Y',
        p_message => x_message );
   IF x_message IS NOT NULL THEN
      log_msg(g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   debug_msg('p_source=' || p_source);
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
      l_message := replace(SUBSTR(g_error_message_02, 11, 100), '$INT_DIR', l_inbound_directory);
      log_msg(g_error || l_message);
      r_request.error_message := l_message;
      r_request.status := 'ERROR';
   ELSE
      r_request.status := 'SUCCESS';
   END IF;

   /*****************************/
   /* Interface Control Record  */
   /*****************************/
   r_request.application_id := l_appl_id;
   r_request.interface_request_id := l_req_id;
   r_request.sub_request_id := l_getfile_req_id;
   xxint_common_pkg.interface_request(r_request);

   /*****************************/
   /* Get list of file names    */
   /*****************************/
   get_interface_files(l_req_id, l_getfile_req_id, t_files_tab);

   IF l_run_error > 0 OR t_files_tab.COUNT = 0 THEN
      RAISE e_interface_error;
   END IF;

   /*****************************/
   /* Initialise DFF cache      */
   /*****************************/
   initialise_dff_cache(201, 'PO_REQUISITION_HEADERS', 'Global Data Elements');

   /*****************************/
   /* Process each file         */
   /*****************************/
   FOR i IN 1..t_files_tab.LAST
   LOOP
      l_file := replace(t_files_tab(i), l_inbound_directory || '/');
      l_log  := replace(l_file, 'csv', 'log');
      l_bad  := replace(l_file, 'csv', 'bad');
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
      IF NOT transform(l_run_id, l_run_phase_id, l_file, l_tfm_mode) THEN
         RAISE e_interface_error;
      END IF;

      /******************************************/
      /* Load                                   */
      /******************************************/
      debug_msg('interface framework (int_mode=' || l_tfm_mode || ')');
      IF l_tfm_mode = g_int_mode THEN
         IF NOT load(l_run_id, l_run_phase_id) THEN
            RAISE e_interface_error;
         END IF;
      END IF;

      /*********************************/
      /* Interface report              */
      /*********************************/
      l_rep_req_id := dot_common_int_pkg.launch_run_report
         ( p_run_id      => l_run_id,
           p_notify_user => l_user_name);

      debug_msg('interface framework completion report (request_id=' || l_rep_req_id || ')');
      
   END LOOP;

   /*******************************************/
   /* Submit PO Req Approval for Errored Reqs */
   /*******************************************/
   l_wf_retry_req_id := submit_xxpoporeq_wf_retry('REQAPPRV', 'BUILD_DEFAULT_APPROVAL_LIST', g_conv_user_id);
   debug_msg('submitted request ' || l_wf_retry_req_id || ' to retry errored approval workflows (work around for bug #5081532, see note 394328.1'); 

EXCEPTION
   WHEN e_interface_error THEN
      /*********************************/
      /* Interface report              */
      /*********************************/
      l_err_req_id := dot_common_int_pkg.launch_error_report
         ( p_run_id       => l_run_id,
           p_run_phase_id => l_run_phase_id );

      l_rep_req_id := dot_common_int_pkg.launch_run_report
         ( p_run_id      => l_run_id,
           p_notify_user => l_user_name);

      p_retcode := 1;

END process_reqs;

END xxpo_poreq_conv_pkg;
/
