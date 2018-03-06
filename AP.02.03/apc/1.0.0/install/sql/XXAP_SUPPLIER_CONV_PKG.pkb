CREATE OR REPLACE PACKAGE BODY xxap_supplier_conv_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.02.03/apc/1.0.0/install/sql/XXAP_SUPPLIER_CONV_PKG.pkb 1806 2017-07-18 00:10:05Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: PO.00.01
**
** Description: Conversion program for importing Suppliers, Sites and
**              Site Contacts from DSDBI. 
**
** Change History:
**
** Date        Who                  Comments
** 24/05/2017  sryan                Initial build.
**
*******************************************************************/
g_debug_flag                  VARCHAR2(1) := 'N';
g_int_batch_name              dot_int_runs.src_batch_name%TYPE;
g_sob_id                      NUMBER;
g_org_id                      NUMBER;
g_source                      fnd_lookup_values.lookup_code%TYPE;
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
TYPE t_id_tab_type IS TABLE OF NUMBER INDEX BY VARCHAR2(240);
TYPE t_validation_errors_type IS TABLE OF VARCHAR2(240);

-- Caches 
g_vendor_int_id_cache          t_id_tab_type;

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
END get_employee_id;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      append_error_tab
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
--  PROCEDURE
--      query_vat_code
--  PURPOSE
--      Queries a tax code from AP_TAX_CODES and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_vat_code
(
   p_vat_name              IN VARCHAR2,
   p_tax_codes_rec         IN OUT NOCOPY ap_tax_codes%ROWTYPE
) IS
   lr_tax_codes_rec        ap_tax_codes%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_tax_codes_rec
   FROM   ap_tax_codes 
   WHERE  name = p_vat_name;
   p_tax_codes_rec := lr_tax_codes_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_tax_codes_rec.name := NULL;
END query_vat_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_country
--  PURPOSE
--      Queries a country from FND_TERRITORIES and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_country
(
   p_territory_short_name  IN VARCHAR2,
   p_territories_rec       IN OUT NOCOPY fnd_territories_vl%ROWTYPE
) IS
   lr_territories_rec      fnd_territories_vl%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_territories_rec
   FROM   fnd_territories_vl 
   WHERE  upper(territory_short_name) = upper(p_territory_short_name);
   p_territories_rec := lr_territories_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_territories_rec.territory_code := NULL;
END query_country;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_awt_group
--  PURPOSE
--      Queries an allow withholding tax group from AP_AWT_GROUPS and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_awt_group
(
   p_awt_group_name        IN VARCHAR2,
   p_awt_group_rec         IN OUT NOCOPY ap_awt_groups%ROWTYPE
) IS
   lr_awt_group_rec        ap_awt_groups%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_awt_group_rec
   FROM   ap_awt_groups 
   WHERE  name = p_awt_group_name
   AND    SYSDATE < nvl(inactive_date, SYSDATE + 1);
   p_awt_group_rec := lr_awt_group_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_awt_group_rec.group_id := NULL;
END query_awt_group;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_employee
--  PURPOSE
--      Queries an employee record from PER_PEOPLE_F and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_employee
(
   p_employee_num          IN VARCHAR2,
   p_per_people_rec        IN OUT NOCOPY per_people_f%ROWTYPE
) IS
   lr_per_people_rec       per_people_f%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_per_people_rec
   FROM   per_people_f 
   WHERE  employee_number = p_employee_num
   AND    SYSDATE BETWEEN effective_start_date AND effective_end_date;
   p_per_people_rec := lr_per_people_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_per_people_rec.person_id := NULL;
END query_employee;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_payment_terms
--  PURPOSE
--      Queries a payment terms record from AP_TERMS_VL and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_payment_terms
(
   p_term_name             IN VARCHAR2,
   p_ap_terms_rec          IN OUT NOCOPY ap_terms_vl%ROWTYPE
) IS
   lr_po_vendors_rec       ap_terms_vl%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_po_vendors_rec
   FROM   ap_terms_vl 
   WHERE  name = p_term_name;
   p_ap_terms_rec := lr_po_vendors_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_ap_terms_rec.term_id := NULL;
END query_payment_terms;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_vendor_site
--  PURPOSE
--      Queries a vendor site record from PO_VENDOR_SITES and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_vendor_site
(
   p_vendor_site_code         IN VARCHAR2,      
   p_vendor_id                IN NUMBER,
   p_po_vendor_sites_rec      IN OUT NOCOPY po_vendor_sites%ROWTYPE
) IS
   lr_po_vendor_sites_rec     po_vendor_sites%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_po_vendor_sites_rec
   FROM   po_vendor_sites 
   WHERE  vendor_site_code = p_vendor_site_code
   AND    vendor_id = p_vendor_id;
   p_po_vendor_sites_rec := lr_po_vendor_sites_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_po_vendor_sites_rec.vendor_site_id := NULL;
END query_vendor_site;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_lookup_code
--  PURPOSE
--      Queries a lookup value record from FND_LOOKUP_VALUES and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_lookup_code
(
   p_lookup_code           IN VARCHAR2,
   p_lookup_type           IN VARCHAR2,
   p_lookup_value_rec      IN OUT NOCOPY fnd_lookup_values%ROWTYPE
) IS
   lr_lookup_value_rec     fnd_lookup_values%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_lookup_value_rec
   FROM   fnd_lookup_values 
   WHERE  lookup_type = p_lookup_type
   AND    lookup_code = p_lookup_code;
   p_lookup_value_rec := lr_lookup_value_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_lookup_value_rec.lookup_code := NULL;
END query_lookup_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_vendor_by_name
--  PURPOSE
--      Queries a vendor record from PO_VENDORS and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_vendor_by_name
(
   p_vendor_name           IN VARCHAR2,
   p_po_vendors_rec        IN OUT NOCOPY po_vendors%ROWTYPE
) IS
   lr_po_vendors_rec       po_vendors%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_po_vendors_rec
   FROM   po_vendors 
   WHERE  vendor_name = p_vendor_name;
   p_po_vendors_rec := lr_po_vendors_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_po_vendors_rec.vendor_id := NULL;
END query_vendor_by_name;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_vendor
--  PURPOSE
--      Queries a vendor record from PO_VENDORS and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_vendor
(
   p_vendor_number         IN VARCHAR2,
   p_po_vendors_rec        IN OUT NOCOPY po_vendors%ROWTYPE
) IS
   lr_po_vendors_rec       po_vendors%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_po_vendors_rec
   FROM   po_vendors 
   WHERE  segment1 = p_vendor_number;
   p_po_vendors_rec := lr_po_vendors_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_po_vendors_rec.vendor_id := NULL;
END query_vendor;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_contact_last_name
--  PURPOSE
--      Validates contact last name
--  DESCRIPTION
--      1) Last name is mandatory when creating Contacts.  If any contact field is provided then make
--         sure the last name is also provided
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_contact_last_name
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF ( p_stg_rec.contact_first_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL OR
        p_stg_rec.contact_middle_name IS NOT NULL ) AND p_stg_rec.contact_last_name IS NULL 
   THEN
      append_error(p_errors_tab, 'Contact Last Name not supplied');
   END IF;
   p_tfm_rec.last_name := p_stg_rec.contact_last_name;
END validate_contact_last_name;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_tax_code
--  PURPOSE
--      Validates tax code
--  DESCRIPTION
--      1) Must exist if provided and be active in AP_TAX_CODES
--      2) Not be of type OFFSET
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_tax_code
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           ap_tax_codes%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   IF p_stg_rec.invoice_tax_code IS NULL THEN
      RETURN;
   END IF;
   query_vat_code(p_stg_rec.invoice_tax_code, lr_entity_rec);
   -- must exist
   IF lr_entity_rec.name IS NULL THEN
      append_error(lt_val_errors_tab, 'Invoice tax code ''' || p_stg_rec.invoice_tax_code || ''' does not exist');
   -- must be enabled and active
   ELSIF ( nvl(lr_entity_rec.enabled_flag, 'N') = 'N' OR
              nvl(lr_entity_rec.start_date, SYSDATE - 1) > SYSDATE OR
              nvl(lr_entity_rec.inactive_date, SYSDATE + 1) < SYSDATE 
            ) THEN 
      append_error(lt_val_errors_tab, 'Invoice tax code ''' || p_stg_rec.invoice_tax_code || ''' is either disabled or not active');
   -- must not be an offset tax code
   ELSIF lr_entity_rec.tax_type = 'OFFSET' THEN
      append_error(lt_val_errors_tab, 'Invoice tax code ''' || p_stg_rec.invoice_tax_code || ''' is an OFFSET tax code');
   END IF;
   p_tfm_rec.vat_code := lr_entity_rec.name;
   append_error_tab(p_errors_tab, lt_val_errors_tab);
END validate_tax_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_payment_method
--  PURPOSE
--      Validates payment methods
--  DESCRIPTION
--      1) Must exist if provided and be active in FND_LOOKUP_VALUES for lookup type PAYMENT METHOD
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_payment_method
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           fnd_lookup_values%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   IF p_stg_rec.payment_method IS NULL THEN
      RETURN;
   END IF;
   query_lookup_code(upper(p_stg_rec.payment_method), 'PAYMENT METHOD', lr_entity_rec);
   -- must exist
   IF lr_entity_rec.lookup_code IS NULL THEN
      append_error(lt_val_errors_tab, 'Payment Method ''' || p_stg_rec.payment_method || ''' does not exist');
   -- must be enabled and active
      ELSIF ( nvl(lr_entity_rec.enabled_flag, 'N') = 'N' OR
              nvl(lr_entity_rec.start_date_active, SYSDATE - 1) > SYSDATE OR
              nvl(lr_entity_rec.end_date_active, SYSDATE + 1) < SYSDATE 
            ) THEN 
      append_error(lt_val_errors_tab, 'Payment Method ''' || p_stg_rec.payment_method || ''' is either disabled or not active');
   END IF;
   p_tfm_rec.payment_method_lookup_code := lr_entity_rec.lookup_code;
   append_error_tab(p_errors_tab, lt_val_errors_tab);
END validate_payment_method;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_country
--  PURPOSE
--      Validates country
--  DESCRIPTION
--      1) Must exist and be active in FND_TERRITORIES
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_country
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           fnd_territories_vl%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   IF p_stg_rec.country IS NULL THEN
      RETURN;
   END IF;
   query_country(upper(p_stg_rec.country), lr_entity_rec);
   -- must exist
   IF lr_entity_rec.territory_code IS NULL THEN
      append_error(lt_val_errors_tab, 'Country ''' || p_stg_rec.country || ''' does not exist');
   END IF;
   p_tfm_rec.country := lr_entity_rec.territory_code;
   append_error_tab(p_errors_tab, lt_val_errors_tab);
END validate_country;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_city
--  PURPOSE
--      Validates city.
--  DESCRIPTION
--      1) Must be provided
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_city
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.city IS NULL THEN
      append_error(p_errors_tab, 'City not supplied');
      RETURN;
   END IF;
   p_tfm_rec.city := p_stg_rec.city;
END validate_city; 

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_address_line1
--  PURPOSE
--      Validates Address Line 1.
--  DESCRIPTION
--      1) Must be provided
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_address_line1
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.address_line1 IS NULL THEN
      append_error(p_errors_tab, 'Address Line 1 not supplied');
      RETURN;
   END IF;
   p_tfm_rec.address_line1 := p_stg_rec.address_line1;
END validate_address_line1; 

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_site_name
--  PURPOSE
--      Validates Site Name.
--  DESCRIPTION
--      1) Must be provided if the record type is NEW
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_site_name
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.record_type = G_REC_TYPE_NEW AND p_stg_rec.site_name IS NULL THEN
      append_error(p_errors_tab, 'Site Name not supplied');
      RETURN;
   END IF;
   p_tfm_rec.vendor_site_code := p_stg_rec.site_name;
   p_tfm_rec.source_site_name := p_stg_rec.site_name;
END validate_site_name; 

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_wht_group
--  PURPOSE
--      Validates WHT Group
--  DESCRIPTION
--      1) Must exist and be active in AP_AWT_GROUPS if provided
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_wht_group
(
   p_wht_group             IN VARCHAR2,
   p_level                 IN VARCHAR2,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           ap_awt_groups%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   IF p_wht_group IS NOT NULL THEN
      query_awt_group(p_wht_group, lr_entity_rec);
      -- must exist
      IF lr_entity_rec.group_id IS NULL THEN
         append_error(lt_val_errors_tab, 'WHT Group ''' || p_wht_group || ''' does not exist');
      -- must be active
      ELSIF nvl(lr_entity_rec.inactive_date, SYSDATE + 1) < SYSDATE THEN
         append_error(lt_val_errors_tab, 'WHT Group''' || p_wht_group || ''' is either disabled or not active');
      END IF;
      IF p_level = 'SUPPLIER' THEN
         p_tfm_rec.awt_group_id := lr_entity_rec.group_id;
      ELSIF p_level = 'SITE' THEN
         p_tfm_rec.site_awt_group_id := lr_entity_rec.group_id;
      END IF;
      append_error_tab(p_errors_tab, lt_val_errors_tab);
   END IF;
END validate_wht_group;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_payment_terms
--  PURPOSE
--      Validates payment terms
--  DESCRIPTION
--      1) Must exist and be active in AP_TERMS_VL
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_payment_terms
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           ap_terms_vl%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   IF p_stg_rec.payment_terms IS NULL THEN
      RETURN;
   END IF;
   query_payment_terms(p_stg_rec.payment_terms, lr_entity_rec);
   -- must exist
   IF lr_entity_rec.term_id IS NULL THEN
      append_error(lt_val_errors_tab, 'Payment terms ''' || p_stg_rec.payment_terms || ''' does not exist');
   -- must be enabled and active
      ELSIF ( nvl(lr_entity_rec.enabled_flag, 'N') = 'N' OR
              nvl(lr_entity_rec.start_date_active, SYSDATE - 1) > SYSDATE OR
              nvl(lr_entity_rec.end_date_active, SYSDATE + 1) < SYSDATE 
            ) THEN 
      append_error(lt_val_errors_tab, 'Payment terms ''' || p_stg_rec.payment_terms || ''' is either disabled or not active');
   END IF;
   p_tfm_rec.terms_id := lr_entity_rec.term_id;
   append_error_tab(p_errors_tab, lt_val_errors_tab);
END validate_payment_terms;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_tax_registration_num
--  PURPOSE
--      Validates tax registration numbers.
--  DESCRIPTION
--      1) Must be provided
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_tax_registration_num
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.tax_registration_num IS NULL THEN
      append_error(p_errors_tab, 'Tax Registration Number not supplied');
      RETURN;
   END IF;
   p_tfm_rec.vat_registration_num := p_stg_rec.tax_registration_num;
END validate_tax_registration_num; 

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_employee_number
--  PURPOSE
--      Validates employee number.
--  DESCRIPTION
--      1) Must be provided if vendor type is EMPLOYEE
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_employee_number
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           per_people_f%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   IF p_tfm_rec.vendor_type_lookup_code = 'EMPLOYEE' THEN
      IF p_stg_rec.employee_number IS NULL THEN
         append_error(p_errors_tab, 'Employee number not supplied');
         RETURN;
      ELSE
         query_employee(p_stg_rec.employee_number, lr_entity_rec);
         -- must exist
         IF lr_entity_rec.person_id IS NULL THEN
            append_error(lt_val_errors_tab, 'Employee number ''' || p_stg_rec.employee_number || ''' does not exist');
         END IF;
         p_tfm_rec.employee_id := lr_entity_rec.person_id;
         append_error_tab(p_errors_tab, lt_val_errors_tab);
      END IF;
   END IF;
END validate_employee_number; 

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_supplier_type
--  PURPOSE
--      Validates supplier type
--  DESCRIPTION
--      1) Must exist and be active in FND_LOOKUP_VALUES for lookup type VENDOR TYPE
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_supplier_type
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           fnd_lookup_values%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   IF p_stg_rec.supplier_type IS NULL THEN
      append_error(p_errors_tab, 'Supplier Type not supplied');
      RETURN;
   END IF;
   query_lookup_code(p_stg_rec.supplier_type, 'VENDOR TYPE', lr_entity_rec);
   -- must exist
   IF lr_entity_rec.lookup_code IS NULL THEN
      append_error(lt_val_errors_tab, 'Supplier Type ''' || p_stg_rec.supplier_type || ''' does not exist');
   -- must be enabled and active
      ELSIF ( nvl(lr_entity_rec.enabled_flag, 'N') = 'N' OR
              nvl(lr_entity_rec.start_date_active, SYSDATE - 1) > SYSDATE OR
              nvl(lr_entity_rec.end_date_active, SYSDATE + 1) < SYSDATE 
            ) THEN 
      append_error(lt_val_errors_tab, 'Supplier Type ''' || p_stg_rec.supplier_type || ''' is either disabled or not active');
   END IF;
   p_tfm_rec.vendor_type_lookup_code := lr_entity_rec.lookup_code;
   append_error_tab(p_errors_tab, lt_val_errors_tab);
END validate_supplier_type;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_supplier_number
--  PURPOSE
--      Validates supplier number.
--  DESCRIPTION
--      1) Must be provided
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_supplier_number
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.supplier_number IS NULL THEN
      append_error(p_errors_tab, 'Supplier number not supplied');
      RETURN;
   END IF;
   p_tfm_rec.segment1 := p_stg_rec.supplier_number;
   p_tfm_rec.source_supplier_number := p_stg_rec.supplier_number;
END validate_supplier_number; 

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_supplier_name
--  PURPOSE
--      Validates supplier name.
--  DESCRIPTION
--      1) Must be provided
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_supplier_name
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_vendor_row           po_vendors%ROWTYPE;
BEGIN
   IF p_stg_rec.supplier_name IS NULL THEN
      append_error(p_errors_tab, 'Supplier name not supplied');
      RETURN;
   END IF;
   -- for NEW suppliers, the supplier should not already exist.
   -- exclude suppliers created by the CONVERSION user
   IF p_stg_rec.record_type = 'NEW' THEN
      query_vendor_by_name(p_stg_rec.supplier_name, lr_vendor_row);
      IF lr_vendor_row.vendor_id IS NOT NULL AND lr_vendor_row.created_by <> g_conv_user_id THEN
         append_error(p_errors_tab, 'Supplier ''' || p_stg_rec.supplier_name 
            || ''' already exists, created on ' || to_char(lr_vendor_row.creation_date,'DD-MON-YYYY'));
         RETURN;
      END IF;
   END IF;   
   p_tfm_rec.vendor_name := p_stg_rec.supplier_name;
END validate_supplier_name; 

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_dtpli_site_code
--  PURPOSE
--      Validates a DTPLI vendor site code is valid
--      Maps to PO_VENDORS.VENDOR_ID if exists
--  DESCRIPTION
--        1) Must be provided 
--        2) Must exist and be active in PO_VENDORS
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_dtpli_site_code
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           po_vendor_sites%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   IF p_stg_rec.dtpli_site_code IS NULL THEN
      append_error(p_errors_tab, 'DTPLI Supplier Site not supplied');
      RETURN;
   END IF;
   query_vendor_site(p_stg_rec.dtpli_site_code, p_tfm_rec.vendor_id, lr_entity_rec);
   -- must exist
   IF lr_entity_rec.vendor_site_id IS NULL THEN
      append_error(lt_val_errors_tab, 'Supplier Site ''' || p_stg_rec.dtpli_site_code || ''' does not exist');
   -- must be enabled and active
   ELSIF nvl(lr_entity_rec.inactive_date, SYSDATE + 1) < SYSDATE THEN 
      append_error(lt_val_errors_tab, 'Supplier Site''' || p_stg_rec.dtpli_site_code || ''' is either disabled or not active');
   ELSE
      p_tfm_rec.vendor_site_id := lr_entity_rec.vendor_site_id;
      p_tfm_rec.dtpli_site_code := p_stg_rec.dtpli_site_code;
   END IF;
   append_error_tab(p_errors_tab, lt_val_errors_tab);
END validate_dtpli_site_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_dtpli_supplier_num
--  PURPOSE
--      Validates a DTPLI vendor number is valid
--      Maps to PO_VENDORS.VENDOR_ID if exists
--  DESCRIPTION
--        1) Must be provided 
--        2) Must exist and be active in PO_VENDORS
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_dtpli_supplier_num
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           po_vendors%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   IF p_stg_rec.dtpli_supplier_num IS NULL THEN
      append_error(p_errors_tab, 'DTPLI Supplier not supplied');
      RETURN;
   END IF;
   query_vendor(p_stg_rec.dtpli_supplier_num, lr_entity_rec);
   -- must exist
   IF lr_entity_rec.vendor_id IS NULL THEN
      append_error(lt_val_errors_tab, 'Supplier ''' || p_stg_rec.dtpli_supplier_num || ''' does not exist');
   -- must be enabled and active
   ELSIF ( nvl(lr_entity_rec.enabled_flag, 'N') = 'N' OR
           nvl(lr_entity_rec.start_date_active, SYSDATE - 1) > SYSDATE OR
           nvl(lr_entity_rec.end_date_active, SYSDATE + 1) < SYSDATE 
         ) THEN 
      append_error(lt_val_errors_tab, 'Supplier ''' || p_stg_rec.dtpli_supplier_num || ''' is either disabled or not active');
   ELSE
      p_tfm_rec.vendor_id := lr_entity_rec.vendor_id;
      p_tfm_rec.dtpli_supplier_num := p_stg_rec.dtpli_supplier_num;
   END IF;
   append_error_tab(p_errors_tab, lt_val_errors_tab);
END validate_dtpli_supplier_num;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_site_eft_remittance
--  PURPOSE
--      Validates that the DFF values are populated correctly for the EFT Remittance Type
--  DESCRIPTION
--      1) If type is EMAIL, an email address must also be populated 
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_site_eft_remittance
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.notification_method = 'EMAIL' THEN
      p_tfm_rec.site_attribute2 := p_stg_rec.notification_method;
      IF p_stg_rec.remittance_email IS NULL THEN
         append_error(p_errors_tab, 'Remittance Email not provided. This is mandatory for Remittance Type EMAIL');
      ELSIF NOT regexp_like(p_stg_rec.remittance_email,'^(\S+)\@(\S+)\.(\S+)$') THEN
         append_error(p_errors_tab, 'Invalid Remittance Email');
      ELSE
         p_tfm_rec.site_attribute3 := p_stg_rec.remittance_email;
      END IF;
   ELSE
      p_tfm_rec.site_attribute2 := 'NONE'; -- eft remittance type
      p_tfm_rec.site_attribute3 := NULL; -- eft email
      p_tfm_rec.site_attribute4 := NULL; -- eft fax number
   END IF;
END validate_site_eft_remittance;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_site_flags
--  PURPOSE
--      Validates site flags
--  DESCRIPTION
--      1) There must be at least one pay site for each new supplier
--      2) There must be at least one purchasing site for each new supplier
--      3) There can only be one primary purchasing site for each new supplier
--      Validation error are raised through the error framework.
--      Offending rows will be updated to ERROR status
--      TFM and VAL_ERROR counts will be decrememnted/incremented appropriately
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_site_flags
(
   p_run_id                IN NUMBER,
   p_run_phase_id          IN NUMBER,
   p_tfm_count             IN OUT NOCOPY NUMBER,
   p_val_err_count         IN OUT NOCOPY NUMBER
) IS
   CURSOR c_sup(p_run_id IN NUMBER) IS
      SELECT vendor_interface_id, 
             SUM(decode(purchasing_site_flag,'Y',1,0)) as purchasing_site_count,
             SUM(decode(pay_site_flag,'Y',1,0)) as pay_site_count, 
             SUM(decode(primary_pay_site_flag,'Y',1,0)) as primary_pay_site_count 
      FROM   xxap_supplier_conv_tfm
      WHERE  run_id = p_run_id
      AND    vendor_interface_id IS NOT NULL
      AND    site_status = 'NEW'
      GROUP BY vendor_interface_id;

   CURSOR c_tfm(p_vendor_interface_id IN NUMBER) IS
      SELECT * 
      FROM   xxap_supplier_conv_tfm
      WHERE  vendor_interface_id = p_vendor_interface_id
      AND    site_status = 'NEW'
      ORDER BY record_id
      FOR UPDATE OF status;

   r_error                 dot_int_run_phase_errors%ROWTYPE;
BEGIN
   FOR r_sup IN c_sup(p_run_id)
   LOOP
      r_error.error_text := NULL;
      --
      -- Purchasing Site Flag
      --
      IF r_sup.purchasing_site_count = 0 THEN
         r_error.run_id := p_run_id;
         r_error.run_phase_id := p_run_phase_id;
         r_error.error_text := 'There must be at least one PURCHASING site specified';
         FOR r_tfm IN c_tfm(r_sup.vendor_interface_id)
         LOOP
            r_error.int_table_key_val1 := nvl(r_tfm.segment1, r_error.int_table_key_val1);
            r_error.int_table_key_val2 := r_tfm.vendor_site_code;
            r_error.record_id := r_tfm.record_id;
            raise_error(r_error);
            log_msg(g_error || r_error.error_text);
            UPDATE xxap_supplier_conv_tfm
            SET    status = 'ERROR'
            WHERE CURRENT OF c_tfm;
         END LOOP;
      END IF;
      --
      -- Pay Site Flag
      --
      IF r_sup.pay_site_count = 0 THEN
         r_error.run_id := p_run_id;
         r_error.run_phase_id := p_run_phase_id;
         r_error.error_text := 'There must be at least one PAY site specified';
         FOR r_tfm IN c_tfm(r_sup.vendor_interface_id)
         LOOP
            r_error.int_table_key_val1 := nvl(r_tfm.segment1, r_error.int_table_key_val1);
            r_error.int_table_key_val2 := r_tfm.vendor_site_code;
            r_error.record_id := r_tfm.record_id;
            raise_error(r_error);
            log_msg(g_error || r_error.error_text);
            UPDATE xxap_supplier_conv_tfm
            SET    status = 'ERROR'
            WHERE CURRENT OF c_tfm;
         END LOOP;
      END IF;
      --
      -- Primary Pay Site Flag
      --
      IF r_sup.primary_pay_site_count > 1 THEN
         r_error.run_id := p_run_id;
         r_error.run_phase_id := p_run_phase_id;
         r_error.error_text := 'There can only be one PRIMARY PAY site specified';
         FOR r_tfm IN c_tfm(r_sup.vendor_interface_id)
         LOOP
            r_error.int_table_key_val1 := nvl(r_tfm.segment1, r_error.int_table_key_val1);
            r_error.int_table_key_val2 := r_tfm.vendor_site_code;
            r_error.record_id := r_tfm.record_id;
            raise_error(r_error);
            log_msg(g_error || r_error.error_text);
            UPDATE xxap_supplier_conv_tfm
            SET    status = 'ERROR'
            WHERE CURRENT OF c_tfm;
         END LOOP;
      END IF;
      --
      IF r_error.error_text IS NOT NULL THEN
         p_tfm_count := p_tfm_count - 1;
         p_val_err_count := p_val_err_count + 1;
      END IF;
   END LOOP;
END validate_site_flags;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      map_contact_tfm
--  PURPOSE
--      Maps supplier site contact values from staging table to transform table
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE map_contact_tfm
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   -- validations 
   validate_contact_last_name(p_stg_rec, p_tfm_rec, p_errors_tab);
   -- verbatim mapping   
   p_tfm_rec.first_name := p_stg_rec.contact_first_name;
   p_tfm_rec.middle_name := p_stg_rec.contact_middle_name;
   p_tfm_rec.prefix := p_stg_rec.prefix;
   p_tfm_rec.title := p_stg_rec.title;
   p_tfm_rec.department := p_stg_rec.department;
   p_tfm_rec.mail_stop := p_stg_rec.mail_stop;
   p_tfm_rec.contact_area_code := p_stg_rec.phone_area_code;
   p_tfm_rec.contact_phone := p_stg_rec.phone_number;
   p_tfm_rec.contact_alt_area_code := p_stg_rec.phone_area_code_alt;
   p_tfm_rec.contact_alt_phone := p_stg_rec.phone_number_alt;
   p_tfm_rec.contact_fax_area_code := p_stg_rec.contact_fax_area_code;
   p_tfm_rec.contact_fax := p_stg_rec.contact_fax_number;
   p_tfm_rec.email_address := p_stg_rec.contact_email;
   p_tfm_rec.url := p_stg_rec.contact_url;
   p_tfm_rec.contact_name_alt := p_stg_rec.contact_name_alt;
   -- defaults
   IF p_stg_rec.contact_last_name IS NOT NULL THEN
      p_tfm_rec.contact_status := 'NEW';
   END IF;
END map_contact_tfm;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      map_new_site_tfm
--  PURPOSE
--      Maps supplier site values from staging table to transform table
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE map_new_site_tfm
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   -- validations and derivations
   validate_site_name(p_stg_rec, p_tfm_rec, p_errors_tab);
   validate_address_line1(p_stg_rec, p_tfm_rec, p_errors_tab);
   validate_city(p_stg_rec, p_tfm_rec, p_errors_tab);
   validate_payment_terms(p_stg_rec, p_tfm_rec, p_errors_tab);
   validate_country(p_stg_rec, p_tfm_rec, p_errors_tab);
   validate_payment_method(p_stg_rec, p_tfm_rec, p_errors_tab);
   validate_tax_code(p_stg_rec, p_tfm_rec, p_errors_tab);
   validate_wht_group(p_stg_rec.site_wht_group, 'SITE', p_tfm_rec, p_errors_tab);
   validate_site_eft_remittance(p_stg_rec, p_tfm_rec, p_errors_tab);
   -- verbatim mapping   
   p_tfm_rec.vendor_site_code_alt := p_stg_rec.site_alt_name;
   p_tfm_rec.address_line2 := p_stg_rec.address_line2;
   p_tfm_rec.address_line3 := p_stg_rec.address_line3;
   p_tfm_rec.address_line4 := p_stg_rec.address_line4;
   p_tfm_rec.address_lines_alt := p_stg_rec.address_lines_alt;
   p_tfm_rec.state := p_stg_rec.state;
   p_tfm_rec.province := p_stg_rec.province;
   p_tfm_rec.county := p_stg_rec.county;
   p_tfm_rec.zip := p_stg_rec.postal_code;
   p_tfm_rec.pay_site_flag := p_stg_rec.pay_site_flag;
   p_tfm_rec.primary_pay_site_flag := p_stg_rec.primary_pay_site_flag;
   p_tfm_rec.purchasing_site_flag := p_stg_rec.purchasing_site_flag;
   p_tfm_rec.area_code := p_stg_rec.voice_area_code;
   p_tfm_rec.phone := p_stg_rec.voice_number;
   p_tfm_rec.fax_area_code := p_stg_rec.fax_area_code;
   p_tfm_rec.fax := p_stg_rec.fax_number;
   p_tfm_rec.telex := p_stg_rec.telex;
   p_tfm_rec.site_hold_all_payments_flag := p_stg_rec.hold_all_payments_flag;
   p_tfm_rec.exclusive_payment_flag := p_stg_rec.pay_alone_flag;
   p_tfm_rec.attention_ar_flag := p_stg_rec.attention_ar_flag;
   p_tfm_rec.site_allow_awt_flag := p_stg_rec.site_allow_wht_flag;
   p_tfm_rec.site_vat_reg_num := p_stg_rec.site_tax_reg_num;
   -- defaults
   p_tfm_rec.accts_pay_code_combination_id := 56066;  -- Y-30101-000-0000-0000-0000-00000000
   p_tfm_rec.prepay_code_combination_id := 1028;      -- S-17401-000-0000-0000-0000-00000000
   p_tfm_rec.invoice_currency_code := 'AUD';
   p_tfm_rec.payment_currency_code := 'AUD';
   p_tfm_rec.site_payment_priority := 99;
   p_tfm_rec.site_attribute5 := 'PRINT';     -- PO Transmission Method
   p_tfm_rec.site_status := 'NEW';
   -- flexfields
   p_tfm_rec.site_attribute13 := p_stg_rec.rcti_agreement_flag;
   p_tfm_rec.site_attribute10 := p_stg_rec.rcti_agreement_num;
   -- banking
   p_tfm_rec.bank := p_stg_rec.bank;
   p_tfm_rec.branch := p_stg_rec.branch;
   p_tfm_rec.bank_account_name := p_stg_rec.bank_account_name;
   p_tfm_rec.bank_account_number := p_stg_rec.bank_account_number;
   p_tfm_rec.bank_account_description := p_stg_rec.bank_account_description;
   p_tfm_rec.bank_account_name_alt := p_stg_rec.bank_account_name_alt;
   p_tfm_rec.account_holder_name := p_stg_rec.account_holder_name;
   p_tfm_rec.allow_multi_assign_flag := p_stg_rec.allow_multi_assign_flag;
END map_new_site_tfm;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      map_new_supplier_tfm
--  PURPOSE
--      Maps supplier header values from staging table to transform table
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE map_new_supplier_tfm
(
   p_stg_rec               IN OUT NOCOPY xxap_supplier_conv_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   -- validations and derivations
   SELECT ap_suppliers_int_s.NEXTVAL 
   INTO   p_tfm_rec.vendor_interface_id 
   FROM   DUAL;
   validate_supplier_name(p_stg_rec, p_tfm_rec, p_errors_tab);
   validate_supplier_number(p_stg_rec, p_tfm_rec, p_errors_tab);
   validate_supplier_type(p_stg_rec, p_tfm_rec, p_errors_tab);
   validate_employee_number(p_stg_rec, p_tfm_rec, p_errors_tab); -- depends on validate_supplier_type running first
   validate_tax_registration_num(p_stg_rec, p_tfm_rec, p_errors_tab);
   validate_wht_group(p_stg_rec.wht_group, 'SUPPLIER', p_tfm_rec, p_errors_tab);
   -- verbatim mapping   
   p_tfm_rec.vendor_name_alt := p_stg_rec.supplier_alt_name;
   p_tfm_rec.attribute15 := p_stg_rec.related_party; 
   p_tfm_rec.allow_awt_flag := p_stg_rec.allow_wht_flag; 
   -- defaults
   p_tfm_rec.summary_flag := 'N';
   p_tfm_rec.enabled_flag := 'Y';
   p_tfm_rec.one_time_flag := 'N';
   p_tfm_rec.hold_all_payments_flag := 'N';
   p_tfm_rec.hold_future_payments_flag := 'N';
   p_tfm_rec.one_time_flag := 'Y';
   p_tfm_rec.payment_priority := 99;
   p_tfm_rec.vendor_status := 'NEW';
   -- add the new vendor id to the cache
   g_vendor_int_id_cache(p_stg_rec.supplier_name) := p_tfm_rec.vendor_interface_id;
END map_new_supplier_tfm;

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
--      insert_sup_site_contact_int
--  PURPOSE
--      Inserts a row into the standard open interface table AP_SUP_SITE_CONTACT_INT.
-- --------------------------------------------------------------------------------------------------
PROCEDURE insert_sup_site_contact_int
(
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE
) IS
BEGIN
   INSERT INTO ap_sup_site_contact_int
   (
      LAST_UPDATE_DATE,
      LAST_UPDATED_BY,
      VENDOR_SITE_ID,
      VENDOR_SITE_CODE,
      ORG_ID,
      LAST_UPDATE_LOGIN,
      CREATION_DATE,
      CREATED_BY,
      FIRST_NAME,
      MIDDLE_NAME,
      LAST_NAME,
      PREFIX,
      TITLE,
      MAIL_STOP,
      AREA_CODE,
      PHONE,
      CONTACT_NAME_ALT,
      DEPARTMENT,
      EMAIL_ADDRESS,
      URL,
      ALT_AREA_CODE,
      ALT_PHONE,
      FAX_AREA_CODE,
      FAX,
      STATUS
   )
   VALUES
   (
      p_tfm_rec.LAST_UPDATE_DATE,
      p_tfm_rec.LAST_UPDATED_BY,
      p_tfm_rec.VENDOR_SITE_ID,
      p_tfm_rec.VENDOR_SITE_CODE,
      p_tfm_rec.ORG_ID,
      p_tfm_rec.LAST_UPDATE_LOGIN,
      p_tfm_rec.CREATION_DATE,
      p_tfm_rec.CREATED_BY,
      p_tfm_rec.FIRST_NAME,
      p_tfm_rec.MIDDLE_NAME,
      p_tfm_rec.LAST_NAME,
      p_tfm_rec.PREFIX,
      p_tfm_rec.TITLE,
      p_tfm_rec.MAIL_STOP,
      p_tfm_rec.CONTACT_AREA_CODE,
      p_tfm_rec.CONTACT_PHONE,
      p_tfm_rec.CONTACT_NAME_ALT,
      p_tfm_rec.DEPARTMENT,
      p_tfm_rec.EMAIL_ADDRESS,
      p_tfm_rec.URL,
      p_tfm_rec.CONTACT_ALT_AREA_CODE,
      p_tfm_rec.CONTACT_ALT_PHONE,
      p_tfm_rec.CONTACT_FAX_AREA_CODE,
      p_tfm_rec.CONTACT_FAX,
      p_tfm_rec.CONTACT_STATUS
   );
END insert_sup_site_contact_int;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      insert_supplier_site_int
--  PURPOSE
--      Inserts a row into the standard open interface table AP_SUPPLIER_SITES_INT.
-- --------------------------------------------------------------------------------------------------
PROCEDURE insert_supplier_site_int
(
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE
) IS
BEGIN
   INSERT INTO ap_supplier_sites_int
   (
      VENDOR_INTERFACE_ID,
      LAST_UPDATE_DATE,
      LAST_UPDATED_BY,
      VENDOR_ID,
      VENDOR_SITE_CODE,
      VENDOR_SITE_CODE_ALT,
      LAST_UPDATE_LOGIN,
      CREATION_DATE,
      CREATED_BY,
      PURCHASING_SITE_FLAG,
      PAY_SITE_FLAG,
      ATTENTION_AR_FLAG,
      ADDRESS_LINE1,
      ADDRESS_LINES_ALT,
      ADDRESS_LINE2,
      ADDRESS_LINE3,
      CITY,
      STATE,
      ZIP,
      PROVINCE,
      COUNTRY,
      AREA_CODE,
      PHONE,
      FAX,
      FAX_AREA_CODE,
      TELEX,
      PAYMENT_METHOD_LOOKUP_CODE,
      VAT_CODE,
      ACCTS_PAY_CODE_COMBINATION_ID,
      PREPAY_CODE_COMBINATION_ID,
      PAYMENT_PRIORITY,
      TERMS_ID,
      INVOICE_CURRENCY_CODE,
      PAYMENT_CURRENCY_CODE,
      HOLD_ALL_PAYMENTS_FLAG,
      EXCLUSIVE_PAYMENT_FLAG,
      ATTRIBUTE2,
      ATTRIBUTE3,
      ATTRIBUTE4,
      ATTRIBUTE5,
      ATTRIBUTE6,
      ATTRIBUTE7,
      ATTRIBUTE10,
      ATTRIBUTE11,
      ATTRIBUTE13,
      VAT_REGISTRATION_NUM,
      ORG_ID,
      ADDRESS_LINE4,
      COUNTY,
      ALLOW_AWT_FLAG,
      AWT_GROUP_ID,
      PRIMARY_PAY_SITE_FLAG,
      STATUS
   )
   VALUES
   (
      p_tfm_rec.VENDOR_INTERFACE_ID,
      p_tfm_rec.LAST_UPDATE_DATE,
      p_tfm_rec.LAST_UPDATED_BY,
      p_tfm_rec.VENDOR_ID,
      p_tfm_rec.VENDOR_SITE_CODE,
      p_tfm_rec.VENDOR_SITE_CODE_ALT,
      p_tfm_rec.LAST_UPDATE_LOGIN,
      p_tfm_rec.CREATION_DATE,
      p_tfm_rec.CREATED_BY,
      p_tfm_rec.PURCHASING_SITE_FLAG,
      p_tfm_rec.PAY_SITE_FLAG,
      p_tfm_rec.ATTENTION_AR_FLAG,
      p_tfm_rec.ADDRESS_LINE1,
      p_tfm_rec.ADDRESS_LINES_ALT,
      p_tfm_rec.ADDRESS_LINE2,
      p_tfm_rec.ADDRESS_LINE3,
      p_tfm_rec.CITY,
      p_tfm_rec.STATE,
      p_tfm_rec.ZIP,
      p_tfm_rec.PROVINCE,
      p_tfm_rec.COUNTRY,
      p_tfm_rec.AREA_CODE,
      p_tfm_rec.PHONE,
      p_tfm_rec.FAX,
      p_tfm_rec.FAX_AREA_CODE,
      p_tfm_rec.TELEX,
      p_tfm_rec.PAYMENT_METHOD_LOOKUP_CODE,
      p_tfm_rec.VAT_CODE,
      p_tfm_rec.ACCTS_PAY_CODE_COMBINATION_ID,
      p_tfm_rec.PREPAY_CODE_COMBINATION_ID,
      p_tfm_rec.SITE_PAYMENT_PRIORITY,
      p_tfm_rec.TERMS_ID,
      p_tfm_rec.INVOICE_CURRENCY_CODE,
      p_tfm_rec.PAYMENT_CURRENCY_CODE,
      p_tfm_rec.SITE_HOLD_ALL_PAYMENTS_FLAG,
      p_tfm_rec.EXCLUSIVE_PAYMENT_FLAG,
      p_tfm_rec.SITE_ATTRIBUTE2,
      p_tfm_rec.SITE_ATTRIBUTE3,
      p_tfm_rec.SITE_ATTRIBUTE4,
      p_tfm_rec.SITE_ATTRIBUTE5,
      p_tfm_rec.SITE_ATTRIBUTE6,
      p_tfm_rec.SITE_ATTRIBUTE7,
      p_tfm_rec.SITE_ATTRIBUTE10,
      p_tfm_rec.SITE_ATTRIBUTE11,
      p_tfm_rec.SITE_ATTRIBUTE13,
      p_tfm_rec.SITE_VAT_REG_NUM,
      p_tfm_rec.ORG_ID,
      p_tfm_rec.ADDRESS_LINE4,
      p_tfm_rec.COUNTY,
      p_tfm_rec.SITE_ALLOW_AWT_FLAG,
      p_tfm_rec.SITE_AWT_GROUP_ID,
      p_tfm_rec.PRIMARY_PAY_SITE_FLAG,
      p_tfm_rec.SITE_STATUS
   );
END insert_supplier_site_int;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      insert_supplier_int
--  PURPOSE
--      Inserts a row into the standard open interface table AP_SUPPLIERS_INT.
-- --------------------------------------------------------------------------------------------------
PROCEDURE insert_supplier_int
(
   p_tfm_rec               IN OUT NOCOPY xxap_supplier_conv_tfm%ROWTYPE
) IS
BEGIN
   INSERT INTO ap_suppliers_int
   (
      VENDOR_INTERFACE_ID,
      LAST_UPDATE_DATE,
      LAST_UPDATED_BY,
      VENDOR_NAME,
      VENDOR_NAME_ALT,
      SEGMENT1,
      SUMMARY_FLAG,
      ENABLED_FLAG,
      LAST_UPDATE_LOGIN,
      CREATION_DATE,
      CREATED_BY,
      EMPLOYEE_ID,
      VENDOR_TYPE_LOOKUP_CODE,
      ONE_TIME_FLAG,
      SET_OF_BOOKS_ID,
      PAYMENT_PRIORITY,
      HOLD_ALL_PAYMENTS_FLAG,
      HOLD_FUTURE_PAYMENTS_FLAG,
      ATTRIBUTE15,
      VAT_REGISTRATION_NUM,
      ALLOW_AWT_FLAG,
      AWT_GROUP_ID,
      STATUS
   )
   VALUES
   (
      p_tfm_rec.VENDOR_INTERFACE_ID,
      p_tfm_rec.LAST_UPDATE_DATE,
      p_tfm_rec.LAST_UPDATED_BY,
      p_tfm_rec.VENDOR_NAME,
      p_tfm_rec.VENDOR_NAME_ALT,
      p_tfm_rec.SEGMENT1,
      p_tfm_rec.SUMMARY_FLAG,
      p_tfm_rec.ENABLED_FLAG,
      p_tfm_rec.LAST_UPDATE_LOGIN,
      p_tfm_rec.CREATION_DATE,
      p_tfm_rec.CREATED_BY,
      p_tfm_rec.EMPLOYEE_ID,
      p_tfm_rec.VENDOR_TYPE_LOOKUP_CODE,
      p_tfm_rec.ONE_TIME_FLAG,
      p_tfm_rec.SET_OF_BOOKS_ID,
      p_tfm_rec.PAYMENT_PRIORITY,
      p_tfm_rec.HOLD_ALL_PAYMENTS_FLAG,
      p_tfm_rec.HOLD_FUTURE_PAYMENTS_FLAG,
      p_tfm_rec.ATTRIBUTE15,
      p_tfm_rec.VAT_REGISTRATION_NUM,
      p_tfm_rec.ALLOW_AWT_FLAG,
      p_tfm_rec.AWT_GROUP_ID,
      p_tfm_rec.VENDOR_STATUS
   );
END insert_supplier_int;

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
         'AP',
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
--      post_conversion_update
--  PURPOSE
--      Post processing of converted suppliers.
--      Checks that suppliers and sites were created properly.
--      Updates the TFM table with supplier references and final status
-- --------------------------------------------------------------------------------------------------
PROCEDURE post_conversion_update
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_debug_flag        IN  VARCHAR2 DEFAULT 'Y'
) IS
   CURSOR c_sup IS
      SELECT tfm.*, stg.record_type, stg.record_id as stage_record_id
      FROM   xxap_supplier_conv_tfm tfm,
             xxap_supplier_conv_stg stg
      WHERE  stg.record_id = tfm.source_record_id
      ORDER BY stg.record_id
      FOR UPDATE OF tfm.status;

   lr_po_vendors_row          po_vendors%ROWTYPE;
   lr_po_vendor_sites_row     po_vendor_sites%ROWTYPE;
   l_debug_msg                VARCHAR2(2000);
BEGIN
   g_debug_flag := p_debug_flag;
   FOR r_sup IN c_sup
   LOOP
      l_debug_msg := '[' || c_sup%ROWCOUNT || '] ' || r_sup.record_type || ' ';
      IF r_sup.record_type = G_REC_TYPE_NEW THEN
         -- check that the vendor and site was created
         lr_po_vendors_row := NULL;
         lr_po_vendor_sites_row := NULL;
         query_vendor(r_sup.segment1, lr_po_vendors_row);
         IF lr_po_vendors_row.vendor_id IS NOT NULL THEN
            l_debug_msg := l_debug_msg || '[vendor_id=' || lr_po_vendors_row.vendor_id || ']';
            query_vendor_site(r_sup.vendor_site_code, lr_po_vendors_row.vendor_id, lr_po_vendor_sites_row);
            IF lr_po_vendor_sites_row.vendor_site_id IS NOT NULL THEN
               l_debug_msg := l_debug_msg || '[vendor_site_id=' || lr_po_vendor_sites_row.vendor_site_id || ']';
               -- override segment1 value with the primary key value
               UPDATE po_vendors 
               SET    segment1 = to_char(vendor_id) 
               WHERE  segment1 = r_sup.segment1;
               -- update tfm table with supplier references and status
               IF SQL%ROWCOUNT = 1 THEN
                  UPDATE xxap_supplier_conv_tfm
                  SET    dtpli_supplier_num = lr_po_vendors_row.vendor_id,
                         dtpli_site_code = lr_po_vendor_sites_row.vendor_site_code,
                         status = 'SUCCESS'
                  WHERE CURRENT OF c_sup;
               END IF;
            END IF;
         END IF;
      ELSIF r_sup.record_type = G_REC_TYPE_SITE_ONLY THEN
         -- r_sup.vendor_id would have been mapped during transformation so it should have a value
         IF r_sup.vendor_id IS NOT NULL THEN
            -- check that the vendor site was created
            lr_po_vendor_sites_row := NULL;
            query_vendor_site(r_sup.vendor_site_code, r_sup.vendor_id, lr_po_vendor_sites_row);
            IF lr_po_vendor_sites_row.vendor_site_id IS NOT NULL THEN
               l_debug_msg := l_debug_msg || '[vendor_site_id=' || lr_po_vendor_sites_row.vendor_site_id || ']';
               -- update tfm table with supplier reference and status
               UPDATE xxap_supplier_conv_tfm
               SET    dtpli_site_code = lr_po_vendor_sites_row.vendor_site_code,
                      status = 'SUCCESS'
               WHERE CURRENT OF c_sup;
            END IF;
         END IF;
      ELSIF r_sup.record_type = G_REC_TYPE_MAP THEN
         -- check that the supplier was successfully mapped
         IF r_sup.vendor_id IS NOT NULL AND r_sup.vendor_site_id IS NOT NULL THEN
            l_debug_msg := l_debug_msg || '[vendor_id=' || r_sup.vendor_id || '][vendor_site_id=' || r_sup.vendor_site_id || ']';
            -- update tfm table with supplier reference and status
            UPDATE xxap_supplier_conv_tfm
            SET    status = 'SUCCESS'
            WHERE CURRENT OF c_sup;
         END IF;
      END IF;
      debug_msg(l_debug_msg);
   END LOOP;
END post_conversion_update;

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
   UPDATE xxap_supplier_conv_stg
   SET    run_id = p_run_id,
          run_phase_id = p_run_phase_id,
          status = p_status,
          created_by = l_user_id
   WHERE  run_id || run_phase_id IS NULL;
   p_row_count := SQL%ROWCOUNT;
END update_stage_run_ids;

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
      update_stage_run_ids(l_run_id, l_run_phase_id, 'SUCCESS', l_stg_rows_loaded);
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
--       Updates the Stage row status to PROCESSED or ERROR as it goes
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
      FROM   xxap_supplier_conv_stg
      WHERE  run_id = p_run_id
      FOR UPDATE OF status
      ORDER BY record_type, supplier_number, site_name, record_id;

   r_stg                   c_stg%ROWTYPE;
   r_tfm                   xxap_supplier_conv_tfm%ROWTYPE;
   l_run_id                NUMBER := p_run_id;
   l_run_phase_id          NUMBER;
   l_total                 NUMBER;
   r_error                 dot_int_run_phase_errors%ROWTYPE;
   l_tfm_count             NUMBER := 0;
   l_stg_count             NUMBER := 0;
   b_stg_row_valid        BOOLEAN := TRUE;
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
        p_int_table_name          => 'XXAP_SUPPLIER_CONV_STG',
        p_int_table_key_col1      => 'SUPPLIER_NUMBER',
        p_int_table_key_col_desc1 => 'Supplier Number',
        p_int_table_key_col2      => 'SITE_NAME',
        p_int_table_key_col_desc2 => 'Site',
        p_int_table_key_col3      => NULL,
        p_int_table_key_col_desc3 => NULL );

   p_run_phase_id := l_run_phase_id;
   r_error.run_id := l_run_id;
   r_error.run_phase_id := l_run_phase_id;

   debug_msg('interface framework (run_transform_id=' || l_run_phase_id || ')');

   SELECT COUNT(1)
   INTO   l_total
   FROM   xxap_supplier_conv_stg
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
      r_error.int_table_key_val1 := r_stg.SUPPLIER_NUMBER;
      r_error.int_table_key_val2 := r_stg.SITE_NAME;

      /***********************************/
      /* Mapping                         */
      /***********************************/
      -- --------------------------------------------------------------------------------------------------------
      -- Record Type: NEW
      -- Brand new Vendor; new Site; and if provided, new Contact
      -- --------------------------------------------------------------------------------------------------------
      IF r_stg.record_type = G_REC_TYPE_NEW THEN
         IF g_vendor_int_id_cache.EXISTS(r_stg.supplier_name) THEN
            r_tfm.vendor_interface_id := g_vendor_int_id_cache(r_stg.supplier_name);
         ELSE
            map_new_supplier_tfm(r_stg, r_tfm, l_val_errors_tab);
         END IF;
         map_new_site_tfm(r_stg, r_tfm, l_val_errors_tab);
      -- --------------------------------------------------------------------------------------------------------
      -- Record Type: SITE_ONLY 
      -- New Site to be added to an existing Vendor; if provided, new Contact
      -- --------------------------------------------------------------------------------------------------------
      ELSIF r_stg.record_type = G_REC_TYPE_SITE_ONLY THEN
         validate_dtpli_supplier_num(r_stg, r_tfm, l_val_errors_tab);
         map_new_site_tfm(r_stg, r_tfm, l_val_errors_tab);
      -- --------------------------------------------------------------------------------------------------------
      -- Record Type: MAP 
      -- No Vendor/Site/Contact created but the supplier number and site name will be validated for existence
      -- --------------------------------------------------------------------------------------------------------
      ELSIF r_stg.record_type = G_REC_TYPE_MAP THEN
         validate_dtpli_supplier_num(r_stg, r_tfm, l_val_errors_tab);
         validate_dtpli_site_code(r_stg, r_tfm, l_val_errors_tab);
      ELSE
         append_error(l_val_errors_tab, 'Invalid Record Type');
      END IF;
      -- --------------------------------------------------------------------------------------------------------
      -- Contact mapping is always performed for NEW and SITE_ONLY types
      -- --------------------------------------------------------------------------------------------------------
      IF r_stg.record_type IN (G_REC_TYPE_NEW, G_REC_TYPE_SITE_ONLY) THEN
         map_contact_tfm(r_stg, r_tfm, l_val_errors_tab);
      END IF;

      -- get the next record_id
      SELECT xxap_supplier_conv_record_id_s.NEXTVAL
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

      -- interface framework columns
      r_tfm.SOURCE_RECORD_ID := r_stg.record_id;
      r_tfm.RUN_ID := l_run_id;
      r_tfm.RUN_PHASE_ID := l_run_phase_id;
      -- who columns
      r_tfm.CREATED_BY := l_user_id;
      r_tfm.CREATION_DATE := SYSDATE;
      r_tfm.LAST_UPDATED_BY := l_user_id;
      r_tfm.LAST_UPDATE_DATE := SYSDATE;
      -- org / book
      r_tfm.ORG_ID := g_org_id;
      r_tfm.SET_OF_BOOKS_ID := g_sob_id;

      /*************************************/
      /* Insert single row into TFM table  */
      /*************************************/
      BEGIN
         INSERT INTO xxap_supplier_conv_tfm VALUES r_tfm;
      EXCEPTION
         WHEN OTHERS THEN
            r_error.record_id := r_stg.record_id;
            r_error.msg_code := SQLCODE;
            r_error.error_text := SQLERRM;
            raise_error(r_error);
            -- Update the stage table row with error status
            UPDATE xxap_supplier_conv_stg SET status = 'ERROR' WHERE CURRENT OF c_stg;
            l_err_count := l_err_count + 1;
      END;
   END LOOP;
   
   /*************************************/
   /* Summary level validation          */
   /*************************************/
   validate_site_flags(l_run_id, l_run_phase_id, l_tfm_count, l_val_err_count);

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
--       Updates the Transform row status to PROCESSED or ERROR as it goes
--  RETURNS
--       True if successful, otherwise False
-- --------------------------------------------------------------------------------------------------
FUNCTION load
(
   p_run_id                IN  NUMBER,
   p_run_phase_id          OUT NUMBER,
   p_submit_import         IN  VARCHAR2
)  RETURN BOOLEAN
IS
   CURSOR c_tfm IS
      SELECT *
      FROM   xxap_supplier_conv_tfm
      WHERE  run_id = p_run_id
      ORDER  BY record_id
      FOR UPDATE OF status;

   r_tfm                   xxap_supplier_conv_tfm%ROWTYPE;
   l_run_id                NUMBER := p_run_id;
   l_run_phase_id          NUMBER;
   l_total                 NUMBER := 0;
   l_error_count           NUMBER := 0;
   l_tfm_count             NUMBER := 0;
   l_load_count            NUMBER := 0;
   r_error                 dot_int_run_phase_errors%ROWTYPE;
   l_status                VARCHAR2(240);
   l_apxiimpt_req_id       NUMBER;
   l_apprvl_req_id         NUMBER;
   r_srs_apxiimpt          r_srs_request_type;
   l_batch_id              NUMBER;
BEGIN
   /*******************************/
   /* Initialise Load Phase       */
   /*******************************/
   l_run_phase_id := dot_common_int_pkg.start_run_phase
      ( p_run_id                  => l_run_id,
        p_phase_code              => 'LOAD',
        p_phase_mode              => NULL,
        p_int_table_name          => 'XXAP_SUPPLIER_CONV_TFM',
        p_int_table_key_col1      => 'SEGMENT1',
        p_int_table_key_col_desc1 => 'Supplier Number',
        p_int_table_key_col2      => 'VENDOR_SITE_CODE',
        p_int_table_key_col_desc2 => 'Site',
        p_int_table_key_col3      => NULL,
        p_int_table_key_col_desc3 => NULL );

   p_run_phase_id := l_run_phase_id;
   r_error.run_id := l_run_id;
   r_error.run_phase_id := l_run_phase_id;
   debug_msg('interface framework (run_load_id=' || l_run_phase_id || ')');

   SELECT COUNT(1)
   INTO   l_total
   FROM   xxap_supplier_conv_tfm
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
      r_error.int_table_key_val1 := r_tfm.segment1;
      r_error.int_table_key_val2 := r_tfm.vendor_site_code;
      BEGIN
         IF r_tfm.vendor_status = 'NEW' THEN
            debug_msg('inserting row into supplier interface [segment1=' || r_tfm.segment1 || ']');
            insert_supplier_int(r_tfm);
         END IF;
         IF r_tfm.site_status = 'NEW' THEN
            debug_msg('inserting row into supplier site interface [vendor_site_code=' || r_tfm.vendor_site_code 
               || '][vendor_id=' || r_tfm.vendor_id 
               || '][vendor_interface_id=' || r_tfm.vendor_interface_id || ']');
            insert_supplier_site_int(r_tfm);
         END IF;
         IF r_tfm.contact_status = 'NEW' THEN
            debug_msg('inserting row into site contact interface [last_name=' || r_tfm.last_name 
               || '][vendor_site_code=' || r_tfm.vendor_site_code
               || '][vendor_id=' || r_tfm.vendor_id 
               || '][vendor_interface_id=' || r_tfm.vendor_interface_id || ']');
            insert_sup_site_contact_int(r_tfm);
         END IF;
         UPDATE xxap_supplier_conv_tfm
         SET    status = 'PROCESSED'
         WHERE CURRENT OF c_tfm;
         l_load_count := l_load_count + 1;
      EXCEPTION
         WHEN OTHERS THEN
            r_error.msg_code := SQLCODE;
            r_error.error_text := SQLERRM;
            raise_error(r_error);
            l_error_count := l_error_count + 1;
            UPDATE xxap_supplier_conv_tfm 
               SET status = 'ERROR'
             WHERE CURRENT OF c_tfm;
      END;
   END LOOP;

   COMMIT; -- required so that import program will see the rows

   debug_msg('inserted ' || l_load_count || ' rows into open interface');
   debug_msg('updated ' || l_error_count || ' transform rows to error status');

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
--      process_suppliers
--  PURPOSE
--       Concurrent Program XXAPSUPCONV (DEDJTR Supplier Conversion)
--  DESCRIPTION
--       Main program controller
-- --------------------------------------------------------------------------------------------------
PROCEDURE process_suppliers
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
   z_procedure_name           CONSTANT VARCHAR2(150) := 'xxap_supplier_conv_pkg.process_suppliers';
   z_app                      CONSTANT VARCHAR2(2) :=  'AP';
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
   --l_apxiimpt_req_id          NUMBER;
   r_srs_xxintifr             r_srs_request_type;
   l_run_error                NUMBER := 0;
   r_request                  xxint_common_pkg.CONTROL_RECORD_TYPE;
   l_message                  VARCHAR2(240);
   t_files_tab                t_varchar_tab_type;
   l_run_id                   NUMBER;
   l_run_phase_id             NUMBER;
   l_rep_req_id               NUMBER;
   l_err_req_id               NUMBER;
   e_interface_error          EXCEPTION;
BEGIN
   /******************************************/
   /* Pre-process validation                 */
   /******************************************/
   xxint_common_pkg.g_object_type := 'SUPPLIERS';
   l_req_id := fnd_global.conc_request_id;
   l_appl_id := fnd_global.resp_appl_id;
   l_user_name := fnd_profile.value('USERNAME');
   g_conv_user_id := get_employee_id('CONVERSION');
   g_sob_id := fnd_profile.value('GL_SET_OF_BKS_ID');
   g_org_id := fnd_profile.value('ORG_ID');
   g_debug_flag := nvl(p_debug_flag, 'N');
   g_source := substr(p_source, 1, 80);
   l_ctl := nvl(p_control_file, g_ctl);
   l_file := nvl(p_file_name, g_file);
   l_tfm_mode := nvl(p_int_mode, g_int_mode);

   debug_msg('procedure name ' || z_procedure_name || '.');

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
         IF NOT load(l_run_id, l_run_phase_id, p_submit_import) THEN
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

END process_suppliers;

END xxap_supplier_conv_pkg;
/
