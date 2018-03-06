create or replace PACKAGE BODY xxap_invoice_interface_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.02.02/apc/1.0.0/install/sql/XXAP_INVOICE_INTERFACE_PKG.pkb 2999 2017-11-17 04:36:48Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: AP.02.01
**
** Description: Interface program for importing Payables 
**              invoices from various feeder systems. 
**
** Change History:
**
** Date        Who                  Comments
** 27/04/2017  sryan (Red Rock)     Initial build
**
*******************************************************************/

g_debug_flag                  VARCHAR2(1) := 'N';
g_accounting_date             DATE;
g_sob_id                      NUMBER;
g_org_id                      NUMBER;
g_chart_id                    NUMBER;
g_int_batch_name              dot_int_runs.src_batch_name%TYPE;
g_source                      fnd_lookup_values.lookup_code%TYPE;
g_sob_currency                fnd_currencies.currency_code%TYPE;

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

-- Cache Entry Types
TYPE r_inv_type_cache_entry_type IS RECORD
(
   fnd_lookup_values_rec   fnd_lookup_values%ROWTYPE,
   val_errors              t_validation_errors_type
);
TYPE r_tax_code_cache_entry_type IS RECORD
(
   ap_tax_codes_rec        ap_tax_codes%ROWTYPE,
   val_errors              t_validation_errors_type
);
TYPE r_ccid_cache_entry_type IS RECORD
(
   code_combination_id     NUMBER,
   val_errors              t_validation_errors_type
);
/*
TYPE r_vendor_cache_entry_type IS RECORD
(
   po_vendors_rec       po_vendors%ROWTYPE,
   val_errors           t_validation_errors_type
);
TYPE r_vendor_site_cache_entry_type IS RECORD
(
   po_vendor_site_rec   po_vendor_sites%ROWTYPE,
   val_errors           t_validation_errors_type
);
*/

-- Cache Types
TYPE t_inv_type_cache_type    IS TABLE OF r_inv_type_cache_entry_type INDEX BY VARCHAR2(30);
TYPE t_tax_code_cache_type    IS TABLE OF r_tax_code_cache_entry_type INDEX BY VARCHAR2(30);
TYPE t_ccid_cache_type        IS TABLE OF r_ccid_cache_entry_type INDEX BY VARCHAR2(60);
TYPE t_dff_defn_cache_type    IS TABLE OF fnd_descr_flex_column_usages%ROWTYPE INDEX BY VARCHAR2(30);
/*
TYPE t_period_cache_type      IS TABLE OF gl_period_statuses.period_name%TYPE INDEX BY VARCHAR2(11);
TYPE t_vendor_cache_type      IS TABLE OF r_vendor_cache_entry_type INDEX BY VARCHAR2(30);
TYPE t_vendor_site_cache_type IS TABLE OF r_vendor_site_cache_entry_type INDEX BY VARCHAR2(30);
*/

-- Caches 
g_inv_type_cache        t_inv_type_cache_type;
g_tax_code_cache        t_tax_code_cache_type;
g_ccid_cache            t_ccid_cache_type;
g_dff_cache             t_dff_defn_cache_type;
/*
g_vendor_cache          t_vendor_cache_type;
g_vendor_site_cache     t_vendor_site_cache_type;
g_period_cache          t_period_cache_type;
*/

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
   fnd_file.put_line(fnd_file.log, p_message);
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
--      insert_interface_header
--  PURPOSE
--      Inserts a row into the open interface table AP_INVOICES_INTERFACES.
-- --------------------------------------------------------------------------------------------------
PROCEDURE insert_interface_header
(
   p_tfm_rec               IN OUT NOCOPY xxap_invoices_interface_tfm%ROWTYPE
) IS
BEGIN
   INSERT INTO ap_invoices_interface
   (
      INVOICE_ID,
      INVOICE_NUM,
      INVOICE_TYPE_LOOKUP_CODE,
      INVOICE_DATE,
      VENDOR_ID,
      VENDOR_SITE_ID,
      INVOICE_AMOUNT,
      INVOICE_CURRENCY_CODE,
      DESCRIPTION,
      SOURCE,
      GROUP_ID,
      INVOICE_RECEIVED_DATE,
      GL_DATE,
      TERMS_ID,
      ACCTS_PAY_CODE_COMBINATION_ID,
      ORG_ID,
      ATTRIBUTE_CATEGORY,
      ATTRIBUTE1,
      ATTRIBUTE2,
      ATTRIBUTE3,
      ATTRIBUTE4,
      ATTRIBUTE5,
      ATTRIBUTE6,
      ATTRIBUTE7,
      ATTRIBUTE8,
      ATTRIBUTE9,
      ATTRIBUTE10,
      ATTRIBUTE11,
      ATTRIBUTE12,
      ATTRIBUTE13,
      ATTRIBUTE14,
      ATTRIBUTE15,
      CREATION_DATE,
      CREATED_BY,
      LAST_UPDATE_DATE,
      LAST_UPDATED_BY
   ) 
      VALUES
   (
      p_tfm_rec.INVOICE_ID,
      p_tfm_rec.INVOICE_NUM,
      p_tfm_rec.INVOICE_TYPE_LOOKUP_CODE,
      p_tfm_rec.INVOICE_DATE,
      p_tfm_rec.VENDOR_ID,
      p_tfm_rec.VENDOR_SITE_ID,
      p_tfm_rec.INVOICE_AMOUNT,
      p_tfm_rec.INVOICE_CURRENCY_CODE,
      p_tfm_rec.DESCRIPTION,
      p_tfm_rec.SOURCE,
      p_tfm_rec.GROUP_ID,
      p_tfm_rec.INVOICE_RECEIVED_DATE,
      p_tfm_rec.GL_DATE,
      p_tfm_rec.TERMS_ID,
      p_tfm_rec.ACCTS_PAY_CODE_COMBINATION_ID,
      p_tfm_rec.ORG_ID,
      p_tfm_rec.ATTRIBUTE_CATEGORY,
      p_tfm_rec.ATTRIBUTE1,
      p_tfm_rec.ATTRIBUTE2,
      p_tfm_rec.ATTRIBUTE3,
      p_tfm_rec.ATTRIBUTE4,
      p_tfm_rec.ATTRIBUTE5,
      p_tfm_rec.ATTRIBUTE6,
      p_tfm_rec.ATTRIBUTE7,
      p_tfm_rec.ATTRIBUTE8,
      p_tfm_rec.ATTRIBUTE9,
      p_tfm_rec.ATTRIBUTE10,
      p_tfm_rec.ATTRIBUTE11,
      p_tfm_rec.ATTRIBUTE12,
      p_tfm_rec.ATTRIBUTE13,
      p_tfm_rec.ATTRIBUTE14,
      p_tfm_rec.ATTRIBUTE15,
      p_tfm_rec.CREATION_DATE,
      p_tfm_rec.CREATED_BY,
      p_tfm_rec.LAST_UPDATE_DATE,
      p_tfm_rec.LAST_UPDATED_BY
   );
END insert_interface_header;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      insert_interface_line
--  PURPOSE
--      Inserts a row into the open interface table AP_INVOICE_LINES_INTERFACE.
-- --------------------------------------------------------------------------------------------------
PROCEDURE insert_interface_line
(
   p_tfm_rec               IN OUT NOCOPY xxap_invoices_interface_tfm%ROWTYPE
) IS
BEGIN
   INSERT INTO ap_invoice_lines_interface
   (
      INVOICE_ID,
      INVOICE_LINE_ID,
      LINE_NUMBER,
      LINE_TYPE_LOOKUP_CODE,
      AMOUNT,
      AMOUNT_INCLUDES_TAX_FLAG,
      ACCOUNTING_DATE,
      DESCRIPTION,
      QUANTITY_INVOICED,
      UNIT_PRICE,
      DIST_CODE_COMBINATION_ID,
      TAX_CODE_ID,
      TAX_CODE_OVERRIDE_FLAG,
      CREATION_DATE,
      CREATED_BY,
      LAST_UPDATE_DATE,
      LAST_UPDATED_BY
   ) 
      VALUES
   (
      p_tfm_rec.INVOICE_ID,
      p_tfm_rec.INVOICE_LINE_ID,
      p_tfm_rec.LINE_NUMBER,
      p_tfm_rec.LINE_TYPE_LOOKUP_CODE,
      p_tfm_rec.LINE_AMOUNT,
      p_tfm_rec.AMOUNT_INCLUDES_TAX_FLAG,
      p_tfm_rec.ACCOUNTING_DATE,
      p_tfm_rec.LINE_DESCRIPTION,
      p_tfm_rec.QUANTITY_INVOICED,
      p_tfm_rec.UNIT_PRICE,
      p_tfm_rec.DIST_CODE_COMBINATION_ID,
      p_tfm_rec.TAX_CODE_ID,
      p_tfm_rec.TAX_CODE_OVERRIDE_FLAG,
      p_tfm_rec.CREATION_DATE,
      p_tfm_rec.CREATED_BY,
      p_tfm_rec.LAST_UPDATE_DATE,
      p_tfm_rec.LAST_UPDATED_BY
   );
END insert_interface_line;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_vendor_invoice
--  PURPOSE
--      Queries an invoice number for a specific vendor
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_vendor_invoice
(
   p_invoice_number        IN VARCHAR2,
   p_vendor_id             IN NUMBER,
   p_ap_invoices_rec       IN OUT NOCOPY ap_invoices%ROWTYPE
) IS
   l_ap_invoices_rec       ap_invoices%ROWTYPE;
BEGIN
   SELECT * 
   INTO   l_ap_invoices_rec
   FROM   ap_invoices
   WHERE  vendor_id = p_vendor_id
   AND    invoice_num = p_invoice_number;
   p_ap_invoices_rec := l_ap_invoices_rec;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      l_ap_invoices_rec.invoice_id := NULL;
END query_vendor_invoice;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_ccid
--  PURPOSE
--      Queries a code combination id using the FND_FLEX_EXT programmatic API
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_ccid
(
   p_account_string        IN  VARCHAR2,
   p_ccid                  OUT NUMBER,
   p_api_error_msg         OUT VARCHAR2
) IS
   l_ccid                 NUMBER;
BEGIN
   debug_msg('Querying account string '||p_account_string);
   l_ccid := fnd_flex_ext.get_ccid('SQLGL', 'GL#', g_chart_id
         , to_char(SYSDATE,fnd_flex_ext.date_format), p_account_string);
   IF nvl(l_ccid, 0) = 0 THEN
      p_ccid := NULL;
      p_api_error_msg := SUBSTR(fnd_flex_ext.get_message, 1, 240);
   ELSE
      p_ccid := l_ccid;
      p_api_error_msg := NULL;
   END IF;
END query_ccid;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_period_statuses
--  PURPOSE
--      Queries the period from GL_PERIOD_STATUSES for the given date, application and type
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_period_statuses
(
   p_date                     IN DATE,
   p_usr_period_type          IN VARCHAR2,
   p_application_id           IN NUMBER,
   p_gl_period_statuses_rec   IN OUT NOCOPY gl_period_statuses%ROWTYPE
) IS
   lr_gl_period_statuses_rec  gl_period_statuses%ROWTYPE;
BEGIN
   debug_msg('Querying '||p_date);
   SELECT gps.*
   INTO   lr_gl_period_statuses_rec
   FROM   gl_period_statuses gps,
          gl_period_types gpt
   WHERE  gps.set_of_books_id = g_sob_id
   AND    gps.period_type = gpt.period_type
   AND    gpt.user_period_type = p_usr_period_type
   AND    gps.application_id = p_application_id
   AND    NVL(gps.adjustment_period_flag, 'N') = 'N'
   AND    p_date between gps.start_date and gps.end_date;
   p_gl_period_statuses_rec := lr_gl_period_statuses_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_gl_period_statuses_rec.period_name := NULL;
END query_period_statuses;

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
--  FUNCTION
--      validate_load
--  PURPOSE
--      Validates and determines the the final status of transform records against base tables
--  RETURNS
--      Number of successfully imported records into AP
-- --------------------------------------------------------------------------------------------------
FUNCTION validate_load
(
   p_run_id             IN  NUMBER,
   p_run_phase_id       IN  NUMBER
)  RETURN NUMBER
IS
   CURSOR c_tfm(p_run_id IN NUMBER) IS
      SELECT tfm.record_id,
             tfm.invoice_num,
             tfm.status,
             api.invoice_id,
             nvl(flvh.meaning, flvl.meaning) as reject_reason
      FROM   xxap_invoices_interface_tfm tfm,
             ap_invoices api,
             ap_interface_rejections apirl,
             fnd_lookup_values flvl,
             ap_interface_rejections apirh,
             fnd_lookup_values flvh
      WHERE  run_id IN p_run_id
      AND    api.vendor_id(+) = tfm.vendor_id
      AND    api.invoice_num(+) = tfm.invoice_num
      AND    apirl.parent_id(+) = tfm.invoice_line_id
      AND    apirl.parent_table(+) = 'AP_INVOICE_LINES_INTERFACE'
      AND    flvl.lookup_code(+) = apirl.reject_lookup_code
      AND    flvl.lookup_type(+) = 'REJECT CODE'
      AND    apirh.parent_id(+) = tfm.invoice_id
      AND    apirh.parent_table(+) = 'AP_INVOICES_INTERFACE'
      AND    flvh.lookup_code(+) = apirh.reject_lookup_code
      AND    flvh.lookup_type(+) = 'REJECT CODE'
      FOR UPDATE OF status;

   l_status               xxap_invoices_interface_tfm.status%TYPE;
   l_error_msg            fnd_lookup_values.meaning%TYPE;
   r_error                dot_int_run_phase_errors%ROWTYPE;
   l_success_count        NUMBER := 0;
   l_rejected_count       NUMBER := 0;
BEGIN
   FOR r_tfm IN c_tfm(p_run_id)
   LOOP
      IF r_tfm.invoice_id IS NOT NULL THEN
         l_status := 'PROCESSED';
         l_success_count := l_success_count + 1;
      ELSE 
         l_status := 'REJECTED';
         l_rejected_count := l_rejected_count + 1;
         l_error_msg := nvl(r_tfm.reject_reason, 'Rejected by Payables Import');
         r_error.run_id := p_run_id;
         r_error.run_phase_id := p_run_phase_id;
         r_error.int_table_key_val1 := r_tfm.invoice_num;
         r_error.record_id := r_tfm.record_id;
         r_error.error_text := l_error_msg;
         raise_error(r_error);
      END IF;
      UPDATE xxap_invoices_interface_tfm
         SET status = l_status
           , run_phase_id = p_run_phase_id
       WHERE CURRENT OF c_tfm;
   END LOOP;
   debug_msg('updated ' || l_success_count || ' transform rows to status processed');
   debug_msg('updated ' || l_rejected_count || ' transform rows to status rejected');
   RETURN l_success_count;
END validate_load;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      validate_invoice_totals
--  PURPOSE
--      Performs invoice header level validation, currently
--      1) Invoice amount must equal the sum of lines
--  RETURNS
--      Number of validation errors found
-- --------------------------------------------------------------------------------------------------
FUNCTION validate_invoice_totals
(
   p_run_id             IN  NUMBER,
   p_run_phase_id       IN  NUMBER
) RETURN NUMBER
IS
   CURSOR c_tfm(p_run_id IN NUMBER) IS
      SELECT tfm.vendor_id,
             tfm.invoice_num,
             tfm.invoice_amount,
             sum(tfm.line_amount) as line_total,
             min(tfm.record_id) as blame_record_id
      FROM   xxap_invoices_interface_tfm tfm
      WHERE  run_id = p_run_id
      AND    tfm.vendor_id IS NOT NULL
      AND    tfm.invoice_amount IS NOT NULL
      AND    tfm.line_amount IS NOT NULL
      GROUP BY tfm.vendor_id, tfm.invoice_num, tfm.invoice_amount;

   r_error                dot_int_run_phase_errors%ROWTYPE;
   l_message              VARCHAR2(240);
   l_err_count            NUMBER := 0;
BEGIN
   FOR r_tfm IN c_tfm(p_run_id)
   LOOP
      IF r_tfm.invoice_amount <> r_tfm.line_total THEN
         l_message := 'The invoice amount ' || r_tfm.invoice_amount 
            || ' does not match the sum of line amounts ' || r_tfm.line_total;
         r_error.run_id := p_run_id;
         r_error.run_phase_id := p_run_phase_id;
         r_error.int_table_key_val1 := r_tfm.invoice_num;
         r_error.record_id := r_tfm.blame_record_id;
         r_error.error_text := l_message;
         raise_error(r_error);
         l_err_count := l_err_count + 1;
         -- update the blame record with error status
         UPDATE xxap_invoices_interface_tfm
            SET status = 'ERROR'
          WHERE record_id = r_tfm.blame_record_id;
      END IF;
   END LOOP;
   RETURN l_err_count;
END validate_invoice_totals;

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
   p_stg_row               IN OUT NOCOPY xxap_invoices_interface_stg%ROWTYPE,
   p_flexfield_title       IN VARCHAR2,
   p_context               IN VARCHAR2,
   p_tfm_rec               IN OUT NOCOPY xxap_invoices_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   z_dff_length            CONSTANT NUMBER := 150;
BEGIN
   -- The first two DFFs (attribute1-2) are global and defaulted
   p_tfm_rec.ATTRIBUTE_CATEGORY := p_context;
   p_tfm_rec.ATTRIBUTE1 := 'N'; -- Special Handling  
   p_tfm_rec.ATTRIBUTE2 := NULL; -- ExtRef

   -- Attribute3 --
   IF g_dff_cache.EXISTS('ATTRIBUTE3') AND 
         g_dff_cache('ATTRIBUTE3').required_flag = 'Y' AND 
         p_stg_row.attribute3 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE3 (' 
         || g_dff_cache('ATTRIBUTE3').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE3') AND 
         p_stg_row.attribute3 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE3 value has been provided (' || p_stg_row.attribute3 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute3 := SUBSTR(p_stg_row.attribute3, 1, z_dff_length);
   END IF;

   -- Attribute4 --
   IF g_dff_cache.EXISTS('ATTRIBUTE4') AND 
         g_dff_cache('ATTRIBUTE4').required_flag = 'Y' AND 
         p_stg_row.attribute4 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE4 (' 
         || g_dff_cache('ATTRIBUTE4').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE4') AND 
         p_stg_row.attribute4 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE4 value has been provided (' || p_stg_row.attribute4 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute4 := SUBSTR(p_stg_row.attribute4, 1, z_dff_length);
   END IF;

   -- Attribute5 --
   IF g_dff_cache.EXISTS('ATTRIBUTE5') AND 
         g_dff_cache('ATTRIBUTE5').required_flag = 'Y' AND 
         p_stg_row.attribute5 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE5 (' 
         || g_dff_cache('ATTRIBUTE5').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE5') AND 
         p_stg_row.attribute5 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE5 value has been provided (' || p_stg_row.attribute5 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute5 := SUBSTR(p_stg_row.attribute5, 1, z_dff_length);
   END IF;

   -- Attribute6 --
   IF g_dff_cache.EXISTS('ATTRIBUTE6') AND 
         g_dff_cache('ATTRIBUTE6').required_flag = 'Y' AND 
         p_stg_row.attribute6 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE6 (' 
         || g_dff_cache('ATTRIBUTE6').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE6') AND 
         p_stg_row.attribute6 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE6 value has been provided (' || p_stg_row.attribute6 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute6 := SUBSTR(p_stg_row.attribute6, 1, z_dff_length);
   END IF;

   -- Attribute7 --
   IF g_dff_cache.EXISTS('ATTRIBUTE7') AND 
         g_dff_cache('ATTRIBUTE7').required_flag = 'Y' AND 
         p_stg_row.attribute7 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE7 (' 
         || g_dff_cache('ATTRIBUTE7').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE7') AND 
         p_stg_row.attribute7 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE7 value has been provided (' || p_stg_row.attribute7 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute7 := SUBSTR(p_stg_row.attribute7, 1, z_dff_length);
   END IF;

   -- Attribute8 --
   IF g_dff_cache.EXISTS('ATTRIBUTE8') AND 
         g_dff_cache('ATTRIBUTE8').required_flag = 'Y' AND 
         p_stg_row.attribute8 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE8 (' 
         || g_dff_cache('ATTRIBUTE8').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE8') AND 
         p_stg_row.attribute8 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE8 value has been provided (' || p_stg_row.attribute8 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute8 := SUBSTR(p_stg_row.attribute8, 1, z_dff_length);
   END IF;

   -- Attribute9 --
   IF g_dff_cache.EXISTS('ATTRIBUTE9') AND 
         g_dff_cache('ATTRIBUTE9').required_flag = 'Y' AND 
         p_stg_row.attribute9 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE9 (' 
         || g_dff_cache('ATTRIBUTE9').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE9') AND 
         p_stg_row.attribute9 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE9 value has been provided (' || p_stg_row.attribute9 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute9 := SUBSTR(p_stg_row.attribute9, 1, z_dff_length);
   END IF;

   -- Attribute10 --
   IF g_dff_cache.EXISTS('ATTRIBUTE10') AND 
         g_dff_cache('ATTRIBUTE10').required_flag = 'Y' AND 
         p_stg_row.attribute10 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE10 (' 
         || g_dff_cache('ATTRIBUTE10').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE10') AND 
         p_stg_row.attribute10 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE10 value has been provided (' || p_stg_row.attribute10 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute10 := SUBSTR(p_stg_row.attribute10, 1, z_dff_length);
   END IF;

   -- Attribute11 --
   IF g_dff_cache.EXISTS('ATTRIBUTE11') AND 
         g_dff_cache('ATTRIBUTE11').required_flag = 'Y' AND 
         p_stg_row.attribute11 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE11 (' 
         || g_dff_cache('ATTRIBUTE11').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE11') AND 
         p_stg_row.attribute11 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE11 value has been provided (' || p_stg_row.attribute11 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute11 := SUBSTR(p_stg_row.attribute11, 1, z_dff_length);
   END IF;

   -- Attribute12 --
   IF g_dff_cache.EXISTS('ATTRIBUTE12') AND 
         g_dff_cache('ATTRIBUTE12').required_flag = 'Y' AND 
         p_stg_row.attribute12 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE12 (' 
         || g_dff_cache('ATTRIBUTE12').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE12') AND 
         p_stg_row.attribute12 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE12 value has been provided (' || p_stg_row.attribute12 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute12 := SUBSTR(p_stg_row.attribute12, 1, z_dff_length);
   END IF;

   -- Attribute13 --
   IF g_dff_cache.EXISTS('ATTRIBUTE13') AND 
         g_dff_cache('ATTRIBUTE13').required_flag = 'Y' AND 
         p_stg_row.attribute13 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE13 (' 
         || g_dff_cache('ATTRIBUTE13').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE13') AND 
         p_stg_row.attribute13 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE13 value has been provided (' || p_stg_row.attribute13 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute13 := SUBSTR(p_stg_row.attribute13, 1, z_dff_length);
   END IF;

   -- Attribute14 --
   IF g_dff_cache.EXISTS('ATTRIBUTE14') AND 
         g_dff_cache('ATTRIBUTE14').required_flag = 'Y' AND 
         p_stg_row.attribute14 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE14 (' 
         || g_dff_cache('ATTRIBUTE14').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE14') AND 
         p_stg_row.attribute14 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE14 value has been provided (' || p_stg_row.attribute14 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute14 := SUBSTR(p_stg_row.attribute14, 1, z_dff_length);
   END IF;

   -- Attribute15 --
   IF g_dff_cache.EXISTS('ATTRIBUTE15') AND 
         g_dff_cache('ATTRIBUTE15').required_flag = 'Y' AND 
         p_stg_row.attribute15 IS NULL THEN
      append_error(p_errors_tab, 'Mandatory field ATTRIBUTE15 (' 
         || g_dff_cache('ATTRIBUTE15').end_user_column_name || ') has not been provided');
   ELSIF NOT g_dff_cache.EXISTS('ATTRIBUTE15') AND 
         p_stg_row.attribute15 IS NOT NULL THEN
      append_error(p_errors_tab, 'ATTRIBUTE15 value has been provided (' || p_stg_row.attribute15 
         || ') but the Descriptive Flexfield for this column has not been defined for context ''' 
         || p_context || '''');
   ELSE
      p_tfm_rec.attribute15 := SUBSTR(p_stg_row.attribute15, 1, z_dff_length);
   END IF;

END validate_dff_segments;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_charge_code
--  PURPOSE
--      Validates account code combination string.
--  DESCRIPTION
--      First searches the account combination cache to see if it has been queried before
--      If not in the cache, the function queries the database for it
--      Tax Code is validated by the FND_FLEX_EXT API
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_charge_code
(
   p_stg_rec               IN OUT NOCOPY xxap_invoices_interface_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_invoices_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   l_ccid                 NUMBER;
   lt_val_errors_tab      t_validation_errors_type := t_validation_errors_type();
   l_api_error            VARCHAR2(240);
BEGIN
   -- first check whether the charge code was supplied
   IF p_stg_rec.charge_code IS NULL THEN
      append_error(p_errors_tab, 'Charge Code not supplied');
      RETURN;
   END IF;
   -- look into the cache first and query the database only if it is not there
   IF NOT g_ccid_cache.EXISTS(p_stg_rec.charge_code) THEN
      query_ccid(p_stg_rec.charge_code, l_ccid, l_api_error);
      -- must be returned by API
      IF l_ccid IS NULL THEN
         append_error(lt_val_errors_tab, 'Invalid charge code: ' || l_api_error);
      END IF;
      -- insert new entry into cache
      g_ccid_cache(p_stg_rec.charge_code).code_combination_id := l_ccid;
      g_ccid_cache(p_stg_rec.charge_code).val_errors := lt_val_errors_tab;
   END IF;
   -- set the output params to the cached values
   p_tfm_rec.dist_code_combination_id := g_ccid_cache(p_stg_rec.charge_code).code_combination_id;
   append_error_tab(p_errors_tab, g_ccid_cache(p_stg_rec.charge_code).val_errors);
END validate_charge_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_invoice_line_amount
--  PURPOSE
--      Validates the line amount.
--  DESCRIPTION
--      1) Must be provided and be a number
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_invoice_line_amount
(
   p_stg_rec               IN OUT NOCOPY xxap_invoices_interface_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_invoices_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   -- first check whether the tax code was supplied
   IF p_stg_rec.line_amount IS NULL THEN
      append_error(p_errors_tab, 'Line Amount not supplied');
   ELSIF NOT is_number(p_stg_rec.line_amount) THEN
      append_error(p_errors_tab, 'Line Amount ''' || p_stg_rec.line_amount || '''  is not a number');
   ELSE
      p_tfm_rec.line_amount := to_number(p_stg_rec.line_amount);
   END IF;
END validate_invoice_line_amount;

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
   p_stg_rec               IN OUT NOCOPY xxap_invoices_interface_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_invoices_interface_tfm%ROWTYPE,
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
--      validate_invoice_type_amount
--  PURPOSE
--      Validates an invoice amount with regards to the invoice type.
--  DESCRIPTION
--      1) Invoice Amount must have a value and be a number
--      2) If Invoice Type provided, it must exist and be enabled and active
--         2.1) Amount must then match the type
--      3) If Invoice Type not provided, default it based on the amount
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_invoice_type_amount
(
   p_stg_rec               IN OUT NOCOPY xxap_invoices_interface_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_invoices_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           fnd_lookup_values%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   -- first check whether the invoice amount was supplied and is a number
   IF p_stg_rec.invoice_amount IS NULL THEN
      append_error(p_errors_tab, 'Invoice amount not supplied');
      RETURN;
   ELSIF NOT is_number(p_stg_rec.invoice_amount) THEN
      append_error(p_errors_tab, 'Invoice amount is not a number');
      RETURN;
   ELSE
      p_tfm_rec.invoice_amount := to_number(p_stg_rec.invoice_amount);
   END IF;
   -- now validate the type
   IF p_stg_rec.invoice_type IS NULL THEN
      -- default invoice type based on the amount
      IF p_stg_rec.invoice_amount >= 0 THEN
         p_tfm_rec.invoice_type_lookup_code := 'STANDARD';
      ELSE
         p_tfm_rec.invoice_type_lookup_code := 'CREDIT';
      END IF;
   ELSE
      IF NOT g_inv_type_cache.EXISTS(p_stg_rec.invoice_type) THEN
         query_lookup_code(upper(p_stg_rec.invoice_type), 'INVOICE TYPE', lr_entity_rec);
         -- must exist
         IF lr_entity_rec.lookup_code IS NULL THEN
            append_error(lt_val_errors_tab, 'Invoice Type ''' || p_stg_rec.invoice_type || ''' does not exist');
         -- must be enabled and active
         ELSIF ( nvl(lr_entity_rec.enabled_flag, 'N') = 'N' OR
                 nvl(lr_entity_rec.start_date_active, SYSDATE - 1) > SYSDATE OR
                 nvl(lr_entity_rec.end_date_active, SYSDATE + 1) < SYSDATE 
               ) THEN 
            append_error(lt_val_errors_tab, 'Invoice Type ''' || p_stg_rec.invoice_type || ''' is either disabled or not active');
         END IF;
         -- insert new entry into cache
         g_inv_type_cache(p_stg_rec.invoice_type).fnd_lookup_values_rec := lr_entity_rec;
         g_inv_type_cache(p_stg_rec.invoice_type).val_errors := lt_val_errors_tab;
      END IF;
      p_tfm_rec.invoice_type_lookup_code := g_inv_type_cache(p_stg_rec.invoice_type).fnd_lookup_values_rec.lookup_code;
      -- now verify the amount has the correct sign
      IF p_tfm_rec.invoice_type_lookup_code = 'STANDARD' AND p_stg_rec.invoice_amount < 0 THEN
         append_error(lt_val_errors_tab, 'Invoice Amount ' || p_stg_rec.invoice_amount 
               || ' cannot be negative for ' || p_stg_rec.invoice_type || ' types');
      ELSIF p_tfm_rec.invoice_type_lookup_code = 'CREDIT' AND p_stg_rec.invoice_amount >= 0 THEN
         append_error(lt_val_errors_tab, 'Invoice Amount ' || p_stg_rec.invoice_amount 
               || ' cannot be zero or greater for ' || p_stg_rec.invoice_type || ' types');
      END IF;
   END IF;
   append_error_tab(p_errors_tab, lt_val_errors_tab);
END validate_invoice_type_amount;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_invoice_date
--  PURPOSE
--      Validates invoice date.
--  DESCRIPTION
--      1) Must have a value
--      2) Must be of the format DD-MON-YYYY
--      3) Must be in an open GL period
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_invoice_date
(
   p_stg_rec               IN OUT NOCOPY xxap_invoices_interface_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_invoices_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   z_date_format              CONSTANT VARCHAR2(11) := 'DD-MON-YYYY';
   --lr_gl_period_statuses_rec  gl_period_statuses%ROWTYPE;
BEGIN
   IF p_stg_rec.invoice_date IS NOT NULL THEN
      -- validate format
      BEGIN
         p_tfm_rec.invoice_date := to_date(p_stg_rec.invoice_date, 'FX'||z_date_format);
      EXCEPTION
         WHEN OTHERS THEN
            append_error(p_errors_tab, 'Invoice Date ''' || p_stg_rec.invoice_date 
               || ''' is not in the required format ''' || z_date_format || '''');
            --RETURN;
      END;
      /*
      -- validate it is in an open period
      IF NOT g_period_cache.EXISTS(p_stg_rec.invoice_date) THEN
         query_period_statuses(p_stg_rec.invoice_date, 'MONTH', 200, lr_gl_period_statuses_rec);
         IF ( lr_gl_period_statuses_rec.period_name IS NULL OR 
              lr_gl_period_statuses_rec.closing_status != 'O' ) 
         THEN
            append_error(p_errors_tab, 'Invoice Date ''' || p_stg_rec.invoice_date 
               || ''' is not in an open Payables period');
            RETURN;
         ELSE
            g_period_cache(p_tfm_rec.invoice_date) := lr_gl_period_statuses_rec.period_name;
         END IF;
      END IF;
      */
   ELSE
      append_error(p_errors_tab, 'Invoice date not supplied');
   END IF;
END validate_invoice_date;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_invoice_number
--  PURPOSE
--      Validates invoice numbers.
--  DESCRIPTION
--      1) Must be provided
--      2) Must not already exist in AP for the provided vendor
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_invoice_number
(
   p_stg_rec               IN OUT NOCOPY xxap_invoices_interface_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_invoices_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   l_ap_invoices_rec       ap_invoices%ROWTYPE;
BEGIN
   -- first check whether the invoice number was supplied
   IF p_stg_rec.invoice_number IS NULL THEN
      append_error(p_errors_tab, 'Invoice number not supplied');
      RETURN;
   END IF;
   -- check that the vendor has already been mapped.
   IF p_tfm_rec.vendor_id IS NULL THEN
      append_error(p_errors_tab, 'Vendor Id not mapped in validation of invoice number');
      RETURN;
   END IF;
   -- query from ap base tables
   query_vendor_invoice(p_stg_rec.invoice_number, p_tfm_rec.vendor_id, l_ap_invoices_rec);
   IF l_ap_invoices_rec.invoice_id IS NOT NULL THEN
      append_error(p_errors_tab, 'Invoice ''' || p_stg_rec.invoice_number || ''' already exists in AP, created on ' 
            || to_char(l_ap_invoices_rec.creation_date, 'DD-MON-YYYY'));
   ELSE
      p_tfm_rec.invoice_num := p_stg_rec.invoice_number;
   END IF;
END validate_invoice_number; 

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_vendor_site
--  PURPOSE
--      Validates a vendor site.
--  DESCRIPTION
--      First searches the vendor site cache to see if it has been queried before
--      If not in the vendor site cache, the function queries the database for it
--      Vendor Site is then validated:
--        1) Must exist in PO_VENDOR_SITES for the given vendor (p_vendor_id)
--        2) Must be active
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_vendor_site
(
   p_stg_rec               IN OUT NOCOPY xxap_invoices_interface_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_invoices_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           po_vendor_sites%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   -- first check whether the vendor site was supplied
   IF p_stg_rec.vendor_site_name IS NULL THEN
      append_error(p_errors_tab, 'Vendor Site Name not supplied');
      RETURN;
   END IF;
   -- check that the vendor has already been mapped.
   IF p_tfm_rec.vendor_id IS NULL THEN
      append_error(p_errors_tab, 'Vendor Id not mapped in validation of vendor site');
      RETURN;
   END IF;
   query_vendor_site(p_stg_rec.vendor_site_name, p_tfm_rec.vendor_id, lr_entity_rec);
   -- must exist
   IF lr_entity_rec.vendor_site_id IS NULL THEN
      append_error(lt_val_errors_tab, 'Vendor Site ''' || p_stg_rec.vendor_site_name || ''' does not exist');
   ELSE
      -- must be active
      IF nvl(lr_entity_rec.inactive_date, SYSDATE + 1) < SYSDATE THEN 
         append_error(lt_val_errors_tab, 'Vendor Site ''' || p_stg_rec.vendor_site_name || ''' is either disabled or not active');
      END IF;
      -- must be a pay site
      IF nvl(lr_entity_rec.pay_site_flag, 'N') = 'N' THEN 
         append_error(lt_val_errors_tab, 'Vendor Site ''' || p_stg_rec.vendor_site_name || ''' is not a pay site');
      END IF;
      -- optionally have a currency code
      IF lr_entity_rec.invoice_currency_code IS NOT NULL THEN 
         p_tfm_rec.invoice_currency_code := lr_entity_rec.invoice_currency_code;
      END IF;
      -- must have payment terms
      IF lr_entity_rec.terms_id IS NULL THEN 
         append_error(lt_val_errors_tab, 'Vendor Site ''' || p_stg_rec.vendor_site_name || ''' does not have payment terms');
      END IF;
   END IF;
   -- set the output params to the values
   p_tfm_rec.vendor_site_id := lr_entity_rec.vendor_site_id;
   p_tfm_rec.terms_id := lr_entity_rec.terms_id;
   append_error_tab(p_errors_tab, lt_val_errors_tab);
END validate_vendor_site;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_vendor
--  PURPOSE
--      Validates vendors.
--  DESCRIPTION
--      Queries the database for the vendor
--      Vendor is then validated:
--        1) Must exist in PO_VENDORS
--        2) Must be enabled and active
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_vendor
(
   p_stg_rec               IN OUT NOCOPY xxap_invoices_interface_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxap_invoices_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           po_vendors%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   -- first check whether the vendor number was supplied
   IF p_stg_rec.vendor_number IS NULL THEN
      append_error(p_errors_tab, 'Vendor number not supplied');
      RETURN;
   END IF;
   query_vendor(p_stg_rec.vendor_number, lr_entity_rec);
   -- must exist
   IF lr_entity_rec.vendor_id IS NULL THEN
      append_error(lt_val_errors_tab, 'Vendor ''' || p_stg_rec.vendor_number || ''' does not exist');
   -- must be enabled and active
   ELSIF ( nvl(lr_entity_rec.enabled_flag, 'N') = 'N' OR
           nvl(lr_entity_rec.start_date_active, SYSDATE - 1) > SYSDATE OR
           nvl(lr_entity_rec.end_date_active, SYSDATE + 1) < SYSDATE 
         ) THEN 
      append_error(lt_val_errors_tab, 'Vendor ''' || p_stg_rec.vendor_number || ''' is either disabled or not active');
   END IF;
   -- set the output params to the values
   p_tfm_rec.vendor_id := lr_entity_rec.vendor_id;
   append_error_tab(p_errors_tab, lt_val_errors_tab);
END validate_vendor;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_organisation
--  PURPOSE
--      Validates Oragnisation Code in the Charge Code.
--  DESCRIPTION
--      FSC-5552 : Added Checking logic whether multiple ORG Codes are engaged within an Invoice
-- --------------------------------------------------------------------------------------------------

PROCEDURE validate_organisation
( 
   p_sob_id                IN gl_sets_of_books.set_of_books_id%type,
   p_stg_rec               IN OUT NOCOPY xxap_invoices_interface_stg%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
)
IS
   l_delim VARCHAR2(2);
   l_number_org NUMBER;
   l_maximum_size NUMBER;
BEGIN
   
   select ffvs.maximum_size,
          ffs.concatenated_segment_delimiter
   into   l_maximum_size,
          l_delim       
   from   gl_sets_of_books sob,
          fnd_id_flex_segments_vl fseg,
          fnd_flex_value_sets ffvs,
          fnd_id_flex_structures_vl ffs
   where  sob.set_of_books_id = p_sob_id
   and    sob.chart_of_accounts_id = fseg.id_flex_num
   and    fseg.flex_value_set_id = ffvs.flex_value_set_id
   and    ffs.id_flex_num = sob.chart_of_accounts_id
   and    ffs.id_flex_code = 'GL#'
   and    ffs.application_id = fseg.application_id
   and    fseg.application_id = 101
   and    fseg.segment_name  = 'Organisation';

   select count(distinct substr(charge_code,instr(charge_code,l_delim,1,1)-1,l_maximum_size))
   into   l_number_org
   from   xxap_invoices_interface_stg
   where  invoice_number = p_stg_rec.invoice_number
   and    run_id = p_stg_rec.run_id
   group by invoice_number;

   IF l_number_org > 1 THEN
      append_error(p_errors_tab, 'Invalid charge code: Multiple Organisation Codes cannot be assigned to a single Invoice');
   END IF;

END;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_batch_id
--  PURPOSE
--      Gets the batch identifier of a batch name.
--  RETURNS
--      Batch Id
-- --------------------------------------------------------------------------------------------------
FUNCTION get_batch_id
(
   p_batch_name            IN VARCHAR2
) RETURN NUMBER
IS
   l_batch_id             NUMBER;
BEGIN
   SELECT batch_id 
   INTO   l_batch_id
   FROM   ap_batches
   WHERE  batch_name = p_batch_name;
   RETURN l_batch_id;
END get_batch_id;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_next_invoice_id
--  PURPOSE
--      Generates the next available invoice interface id.
--  RETURNS
--      Next available invoice interface id
-- --------------------------------------------------------------------------------------------------
FUNCTION get_next_invoice_id RETURN NUMBER
IS
   l_invoice_id           NUMBER;
BEGIN
   SELECT ap_invoices_interface_s.NEXTVAL 
   INTO   l_invoice_id
   FROM   dual;
   RETURN l_invoice_id;
END get_next_invoice_id;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_next_invoice_line_id
--  PURPOSE
--      Generates the next available invoice line interface id.
--  RETURNS
--      Next available invoice line interface id
-- --------------------------------------------------------------------------------------------------
FUNCTION get_next_invoice_line_id RETURN NUMBER
IS
   l_line_id              NUMBER;
BEGIN
   SELECT ap_invoice_lines_interface_s.NEXTVAL 
   INTO   l_line_id
   FROM   dual;
   RETURN l_line_id;
END get_next_invoice_line_id;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_chart_of_accounts_id
--  PURPOSE
--      Gets the chart of accounts id from the set of books
--  RETURNS
--       Chart of Accounts Id
-- --------------------------------------------------------------------------------------------------
FUNCTION get_chart_of_accounts_id
(
   p_sob_id            IN NUMBER
) RETURN NUMBER
IS
   l_coa_id            NUMBER;
BEGIN
   SELECT chart_of_accounts_id
   INTO   l_coa_id
   FROM   gl_sets_of_books
   WHERE  set_of_books_id = p_sob_id;
   RETURN l_coa_id;
END get_chart_of_accounts_id;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_sob_currency
--  PURPOSE
--      Gets the currency of a set of books
--  RETURNS
--       Currency code
-- --------------------------------------------------------------------------------------------------
FUNCTION get_sob_currency
(
   p_sob_id            IN NUMBER
) RETURN VARCHAR2
IS
   l_currency_code    fnd_currencies.currency_code%TYPE;
BEGIN
   SELECT currency_code
   INTO   l_currency_code
   FROM   gl_sets_of_books
   WHERE  set_of_books_id = p_sob_id;
   RETURN l_currency_code;
END get_sob_currency;

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
--      copy_conc_request_file
--  PURPOSE
--      Copies a LOG or OUTPUT concurrent request file to the designated target file and directory
--  DESCRIPTION
--      p_file_type must be 'LOG' or 'OUTPUT'
--      If p_target_filename is not provided the source file name is used
-- --------------------------------------------------------------------------------------------------
PROCEDURE copy_conc_request_file
(
   p_request_id        IN NUMBER,
   p_file_type         IN VARCHAR2,
   p_target_dir        IN VARCHAR2,
   p_target_filename   IN VARCHAR2 DEFAULT NULL
) IS
   l_request_file       fnd_concurrent_requests.outfile_name%TYPE; -- outfile and logfile have the same type
   l_target_file        VARCHAR2(100);
   l_file_copy          NUMBER := 0;
BEGIN
   IF upper(p_file_type) IN ('OUTPUT','LOG') THEN
      -- get the concurrent request file name
      SELECT decode(upper(p_file_type), 'OUTPUT', outfile_name, 'LOG', logfile_name) 
      INTO   l_request_file
      FROM   fnd_concurrent_requests
      WHERE  request_id = p_request_id;
      -- determine the target file name.  defaults to same name if not specified by p_target_filename
      l_target_file := nvl(p_target_filename, SUBSTR(l_request_file, INSTR(l_request_file, '/', -1) + 1));
      -- copy the file
      l_file_copy := xxint_common_pkg.file_copy(
            p_from_path => l_request_file,
            p_to_path => p_target_dir || '/' || l_target_file);
      debug_msg('file copy of ' || l_request_file || ' to ' || p_target_dir 
         || '/' || l_target_file || ' returned ' || l_file_copy);
   ELSE
      debug_msg(g_error || 'Invalid concurrent request file type ''' || p_file_type || '''');
      RETURN;
   END IF;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      debug_msg(g_error || 'could not find concurrent request '''|| p_file_type || ''' file for request ' || p_request_id);
END copy_conc_request_file;

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
--      submit_apprvl
--  PURPOSE
--       Submits the standard invoice validation program APPRVL (Invoice Validation)
--  RETURNS
--       Concurrent Request Id of the submitted request
-- --------------------------------------------------------------------------------------------------
FUNCTION submit_apprvl
(
   p_batch_id            IN NUMBER,
   p_sob_id              IN NUMBER,
   p_org_id              IN NUMBER
) RETURN NUMBER
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_apprvl_req_id    NUMBER;
BEGIN
   l_apprvl_req_id := fnd_request.submit_request
      ( application => 'SQLAP',
        program     => 'APPRVL',
        description => NULL,
        start_time  => NULL,
        sub_request => FALSE,
        argument1   => 'All',    -- option
        argument2   => p_batch_id,  -- batch id
        argument3   => NULL,     -- start invoice date
        argument4   => NULL,     -- end invoice date
        argument5   => NULL,     -- vendor id
        argument6   => NULL,     -- pay group
        argument7   => NULL,     -- invoice id
        argument8   => NULL,     -- entered by user id 
        argument9   => p_sob_id, -- set of books id
        argument10  => 'N',      -- trace option 
        argument11  => p_org_id, -- org id 
        argument12  => 1000      -- commit size
        );
   COMMIT;
   RETURN l_apprvl_req_id;
END submit_apprvl;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      submit_apxiimpt
--  PURPOSE
--       Submits the standard import program APXIIMPT (Payables Open Interface Import)
--  RETURNS
--       Concurrent Request Id of the submitted request
-- --------------------------------------------------------------------------------------------------
FUNCTION submit_apxiimpt
(
   p_user_je_source      IN VARCHAR2, 
   p_group               IN VARCHAR2,
   p_batch               IN VARCHAR2
) RETURN NUMBER
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_apxiimpt_req_id    NUMBER;
BEGIN
   l_apxiimpt_req_id := fnd_request.submit_request
      ( application => 'SQLAP',
        program     => 'APXIIMPT',
        description => NULL,
        start_time  => NULL,
        sub_request => FALSE,
        argument1   => p_user_je_source,
        argument2   => p_group,
        argument3   => p_batch,
        argument4   => NULL,     -- hold name
        argument5   => NULL,     -- hold reason
        argument6   => NULL,     -- gl date
        argument7   => 'Y',      -- purge
        argument8   => 'N',      -- trace 
        argument9   => 'N',      -- debug
        argument10  => 'N',     -- summarize report 
        argument11  => 1000,     -- commit batch size 
        argument12  => fnd_profile.value('USER_ID'), -- user id
        argument13  => fnd_profile.value('LOGIN_ID'), -- login id
        argument14  => NULL      -- skip validation
        );
   COMMIT;
   RETURN l_apxiimpt_req_id;
END submit_apxiimpt;

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
   UPDATE xxap_invoices_interface_stg
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
--  PROCEDURE
--      generate_ack_output
--  PURPOSE
--      Formats the interface acknowledgement file in the concurrent output.
-- --------------------------------------------------------------------------------------------------
PROCEDURE generate_ack_output
(
   p_run_id              IN   NUMBER,
   p_source              IN   VARCHAR2,
   p_file_name           IN   VARCHAR2,
   p_file_dir            IN   VARCHAR2
) IS
   z_sep                 CONSTANT VARCHAR2(1) := ','; -- separator
   z_err_sep             CONSTANT VARCHAR2(3) := ' - '; -- error message separator
   z_enc                 CONSTANT VARCHAR2(1) := '"'; -- enclosing character
   l_buffer              VARCHAR2(2000);
   l_error_buffer        VARCHAR2(1000);
   z_file_temp_dir       CONSTANT VARCHAR2(150)  := 'USER_TMP_DIR';
   z_file_temp_name      CONSTANT VARCHAR2(150) := p_file_name || '.tmp';
   lf_file_handle        utl_file.file_type;
   l_file_copy           INTEGER;

   CURSOR c_ack(p_run_id IN NUMBER) IS
      SELECT nvl(tfm.record_id, stg.record_id) as record_id,
             stg.run_id,
             stg.invoice_number,
             stg.invoice_date,
             stg.vendor_number,
             stg.vendor_site_name,
             tfm.vendor_site_id,
             stg.invoice_amount,
             stg.invoice_description,
             stg.line_number,
             stg.line_amount,
             stg.line_description,
             stg.charge_code,
             p_source as source,
             ai.created_by,
             decode(tfm.status
              , 'ERROR', 'Error'
              , 'VALIDATED', 'Validated'
              , 'PROCESSED', 'Success'
              , 'REJECTED', 'Rejected'
              ) as status
      FROM   xxap_invoices_interface_stg stg, 
             xxap_invoices_interface_tfm tfm,
             ap_invoices ai
      WHERE  stg.run_id = p_run_id
      AND    tfm.source_record_id(+) = stg.record_id
      AND    ai.vendor_id(+) = tfm.vendor_id
      AND    ai.invoice_num(+) = tfm.invoice_num;

   CURSOR c_error(p_run_id IN NUMBER, p_record_id IN NUMBER) IS
      SELECT error_text
      FROM   dot_int_run_phase_errors
      WHERE  run_id = p_run_id
      AND    record_id = p_record_id;

BEGIN
   lf_file_handle := utl_file.fopen(z_file_temp_dir, z_file_temp_name, 'w');
   FOR r_ack IN c_ack(p_run_id)
   LOOP
      l_buffer :=  
         z_enc || r_ack.invoice_number       || z_enc || z_sep ||
         z_enc || r_ack.invoice_date         || z_enc || z_sep ||
         z_enc || r_ack.vendor_number        || z_enc || z_sep ||
         z_enc || r_ack.vendor_site_name     || z_enc || z_sep ||
                  r_ack.vendor_site_id       || z_sep ||
                  r_ack.invoice_amount       || z_sep ||
         z_enc || r_ack.invoice_description  || z_enc || z_sep || 
                  r_ack.line_number          || z_sep ||
                  r_ack.line_amount          || z_sep ||
         z_enc || r_ack.line_description     || z_enc || z_sep ||
         z_enc || r_ack.charge_code          || z_enc || z_sep ||
         z_enc || r_ack.source               || z_enc || z_sep ||
                  r_ack.created_by           || z_sep ||
         z_enc || r_ack.status || z_enc ;
      FOR r_error IN c_error(r_ack.run_id, r_ack.record_id)
      LOOP
         IF c_error%ROWCOUNT > 1 THEN
            l_error_buffer := l_error_buffer || z_err_sep || r_error.error_text;
         ELSE
            l_error_buffer := r_error.error_text;
         END IF;
      END LOOP;
      IF l_error_buffer IS NOT NULL THEN
         l_buffer := l_buffer || z_sep || z_enc || l_error_buffer || z_enc;
         l_error_buffer := NULL;
      END IF;
      utl_file.put_line(lf_file_handle, l_buffer);
      fnd_file.put_line(fnd_file.output, l_buffer);
   END LOOP;
   utl_file.fclose(lf_file_handle);
   debug_msg('copying /usr/tmp/' || z_file_temp_name || ' to ' || p_file_dir || '/' || p_file_name);
   l_file_copy := xxint_common_pkg.file_copy(
         p_from_path => '/usr/tmp/' || z_file_temp_name,
         p_to_path => p_file_dir || '/' || p_file_name);
   debug_msg('file copy return code ' || l_file_copy);
   IF nvl(l_file_copy,0) > 0 THEN
      utl_file.fremove(z_file_temp_dir, z_file_temp_name);
   END IF;
END generate_ack_output;

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
      FROM   xxap_invoices_interface_stg
      WHERE  run_id = p_run_id
      FOR UPDATE OF status
      ORDER BY vendor_number, invoice_number, line_number;

   r_stg                   c_stg%ROWTYPE;
   r_tfm                   xxap_invoices_interface_tfm%ROWTYPE;
   l_run_id                NUMBER := p_run_id;
   l_run_phase_id          NUMBER;
   l_total                 NUMBER;
   r_error                 dot_int_run_phase_errors%ROWTYPE;
   l_tfm_count             NUMBER := 0;
   l_stg_count             NUMBER := 0;
   b_stg_row_valid         BOOLEAN := TRUE;
   l_val_err_count         NUMBER := 0;
   l_err_count             NUMBER := 0;
   l_header_err_count      NUMBER := 0;
 --l_new_record_id         NUMBER;
   l_user_id               NUMBER := fnd_profile.value('USER_ID');
   l_status                VARCHAR2(30);
   z_default_inv_type      CONSTANT VARCHAR2(15) := 'STANDARD';
   z_default_cr_type       CONSTANT VARCHAR2(15) := 'CREDIT';
   l_wip_invoice_num       xxap_invoices_interface_stg.invoice_number%TYPE;
   l_wip_vendor_num        xxap_invoices_interface_stg.vendor_number%TYPE;
   l_wip_invoice_id        NUMBER := 0;
   l_default_line_number   NUMBER := 0;
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
        p_int_table_name          => 'XXAP_INVOICES_INTERFACE_STG',
        p_int_table_key_col1      => 'INVOICE_NUMBER',
        p_int_table_key_col_desc1 => 'Invoice Number',
        p_int_table_key_col2      => NULL,
        p_int_table_key_col_desc2 => NULL,
        p_int_table_key_col3      => NULL,
        p_int_table_key_col_desc3 => NULL );

   p_run_phase_id := l_run_phase_id;
   r_error.run_id := l_run_id;
   r_error.run_phase_id := l_run_phase_id;

   debug_msg('interface framework (run_transform_id=' || l_run_phase_id || ')');

   SELECT COUNT(1)
   INTO   l_total
   FROM   xxap_invoices_interface_stg
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
      IF trim(r_stg.INVOICE_NUMBER)||trim(r_stg.INVOICE_DATE)||trim(r_stg.VENDOR_NUMBER)||trim(r_stg.VENDOR_SITE_NAME)||trim(r_stg.VENDOR_SITE_NAME)||
         trim(r_stg.INVOICE_TYPE)||trim(r_stg.INVOICE_AMOUNT)||trim(r_stg.INVOICE_DESCRIPTION)||trim(r_stg.LINE_NUMBER)||trim(r_stg.LINE_AMOUNT)||
         trim(r_stg.LINE_DESCRIPTION)||trim(r_stg.TAX_CODE)||trim(r_stg.CHARGE_CODE)||trim(r_stg.ATTRIBUTE1)||trim(r_stg.ATTRIBUTE2)||
         trim(r_stg.ATTRIBUTE3)||trim(r_stg.ATTRIBUTE4)||trim(r_stg.ATTRIBUTE5)||trim(r_stg.ATTRIBUTE6)||trim(r_stg.ATTRIBUTE7)||
         trim(r_stg.ATTRIBUTE8)||trim(r_stg.ATTRIBUTE9)||trim(r_stg.ATTRIBUTE10)||trim(r_stg.ATTRIBUTE11)||trim(r_stg.ATTRIBUTE12)||
         trim(r_stg.ATTRIBUTE13)||trim(r_stg.ATTRIBUTE14)||trim(r_stg.ATTRIBUTE15) IS NULL THEN -- FSC 5725 Joy Pinto - 17-Oct-2017
         CONTINUE;
      END IF;
      -- initilise and increment 
      l_stg_count := l_stg_count + 1;
      b_stg_row_valid := TRUE;
      r_tfm := NULL;
      r_error.int_table_key_val1 := r_stg.invoice_number;
      -- determine if new invoice
      IF ( r_stg.invoice_number <> nvl(l_wip_invoice_num, '-1') OR 
           r_stg.vendor_number <> nvl(l_wip_vendor_num, '-1') ) THEN
         -- reset the wip variables
         l_wip_invoice_num := r_stg.invoice_number;
         l_wip_vendor_num := r_stg.vendor_number;
         l_wip_invoice_id := get_next_invoice_id;
         l_default_line_number := 1;
      ELSE
         l_default_line_number := l_default_line_number + 1;
      END IF;

      -- FSC-5552 : Added Checking logic whether multiple ORG Codes are engaged within a Invoice
      validate_organisation( g_sob_id,r_stg,l_val_errors_tab);  
      /***********************************/
      /* Validation and Mapping          */
      /***********************************/
      validate_vendor(r_stg, r_tfm, l_val_errors_tab);
      IF r_tfm.vendor_id IS NOT NULL THEN
         validate_vendor_site(r_stg, r_tfm, l_val_errors_tab);
         validate_invoice_number(r_stg, r_tfm, l_val_errors_tab);
      END IF;
      validate_invoice_type_amount(r_stg, r_tfm, l_val_errors_tab);
      validate_invoice_date(r_stg, r_tfm, l_val_errors_tab);
      validate_tax_code(r_stg, r_tfm, l_val_errors_tab);
      validate_charge_code(r_stg, r_tfm, l_val_errors_tab);
      validate_invoice_line_amount(r_stg, r_tfm, l_val_errors_tab);
      validate_dff_segments(r_stg, 'Invoice', g_source, r_tfm, l_val_errors_tab);

      -- get the next record_id
      SELECT xxap_invoices_record_id_s.NEXTVAL
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
      -- header columns
      r_tfm.INVOICE_ID := l_wip_invoice_id;
      r_tfm.DESCRIPTION := SUBSTR(r_stg.invoice_description, 1, 240);
      r_tfm.SOURCE := g_source;
      r_tfm.INVOICE_RECEIVED_DATE := r_tfm.invoice_date;
      r_tfm.GL_DATE := g_accounting_date; --r_tfm.invoice_date;
      r_tfm.ORG_ID := g_org_id;
      --r_tfm.ACCTS_PAY_CODE_COMBINATION_ID := r_tfm.dist_code_combination_id; Commented by Joy Pinto for Issue  JIRA-3545
      r_tfm.INVOICE_CURRENCY_CODE := nvl(r_tfm.INVOICE_CURRENCY_CODE, g_sob_currency);
      -- line level
      r_tfm.LINE_NUMBER := nvl(r_stg.line_number, l_default_line_number);
      r_tfm.INVOICE_LINE_ID := get_next_invoice_line_id;
      r_tfm.LINE_TYPE_LOOKUP_CODE := 'ITEM';
      r_tfm.LINE_DESCRIPTION := SUBSTR(r_stg.line_description, 1, 240);
      r_tfm.ACCOUNTING_DATE := g_accounting_date; --r_tfm.invoice_date;
      r_tfm.QUANTITY_INVOICED := r_tfm.line_amount;
      r_tfm.UNIT_PRICE := 1;
      r_tfm.TAX_CODE_OVERRIDE_FLAG := 'Y';
      r_tfm.AMOUNT_INCLUDES_TAX_FLAG := 'Y';

      /*************************************/
      /* Insert single row into TFM table  */
      /*************************************/
      BEGIN
         INSERT INTO xxap_invoices_interface_tfm VALUES r_tfm;
      EXCEPTION
         WHEN OTHERS THEN
            r_error.record_id := r_stg.record_id;
            r_error.msg_code := SQLCODE;
            r_error.error_text := SQLERRM;
            raise_error(r_error);
            -- Update the stage table row with error status
            UPDATE xxap_invoices_interface_stg SET status = 'ERROR' WHERE CURRENT OF c_stg;
            l_err_count := l_err_count + 1;
      END;

   END LOOP;

   /*************************************/
   /* Header level validation           */
   /*************************************/
   l_header_err_count := validate_invoice_totals(l_run_id, l_run_phase_id);
   -- update count variables
   l_tfm_count := l_tfm_count - l_header_err_count;
   l_val_err_count := l_val_err_count + l_header_err_count;

   debug_msg('inserted ' || l_tfm_count || ' transform rows with status validated');
   debug_msg('inserted ' || l_val_err_count || ' transform rows with status error');
   debug_msg('raised ' || l_header_err_count || ' header level validation errors');
   debug_msg('updated ' || l_err_count || ' stage rows with status error');

   IF (l_val_err_count > 0) OR (l_err_count > 0) OR (l_header_err_count > 0)THEN
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
   p_submit_validation     IN  VARCHAR2,
   p_apxiimpt_req_id       OUT NUMBER
)  RETURN BOOLEAN
IS
   CURSOR c_tfm IS
      SELECT *
      FROM   xxap_invoices_interface_tfm
      WHERE  run_id = p_run_id
      ORDER  BY invoice_id, line_number
      FOR UPDATE OF status;

   r_tfm                   xxap_invoices_interface_tfm%ROWTYPE;
   l_run_id                NUMBER := p_run_id;
   l_run_phase_id          NUMBER;
   l_total                 NUMBER := 0;
   l_error_count           NUMBER := 0;
   l_tfm_count             NUMBER := 0;
   l_load_count            NUMBER := 0;
   r_error                 dot_int_run_phase_errors%ROWTYPE;
   l_status                VARCHAR2(240);
   l_wip_invoice_id        NUMBER := 0;
   l_apxiimpt_req_id       NUMBER;
   l_apprvl_req_id         NUMBER;
   r_srs_apxiimpt          r_srs_request_type;
   l_load_success_cnt      NUMBER := 0;
   l_batch_id              NUMBER;
BEGIN
   /*******************************/
   /* Initialise Load Phase       */
   /*******************************/
   l_run_phase_id := dot_common_int_pkg.start_run_phase
      ( p_run_id                  => l_run_id,
        p_phase_code              => 'LOAD',
        p_phase_mode              => NULL,
        p_int_table_name          => 'XXAP_INVOICES_INTERFACE_TFM',
        p_int_table_key_col1      => 'INVOICE_NUM',
        p_int_table_key_col_desc1 => 'Invoice Num',
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
   FROM   xxap_invoices_interface_tfm
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
      r_error.int_table_key_val1 := r_tfm.invoice_num;
      BEGIN
         IF r_tfm.invoice_id <> l_wip_invoice_id THEN
            /*******************************/
            /* Insert Header               */
            /*******************************/
            insert_interface_header(r_tfm);
            l_wip_invoice_id := r_tfm.invoice_id;
         END IF;
         /*******************************/
         /* Insert Line                 */
         /*******************************/
         insert_interface_line(r_tfm);
         l_load_count := l_load_count + 1;
      EXCEPTION
         WHEN OTHERS THEN
            r_error.msg_code := SQLCODE;
            r_error.error_text := SQLERRM;
            raise_error(r_error);
            l_error_count := l_error_count + 1;
            UPDATE xxap_invoices_interface_tfm 
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
      /*********************************/
      /* Submit Payables Import        */
      /*********************************/
      l_apxiimpt_req_id := submit_apxiimpt(g_source, NULL, g_int_batch_name);
      debug_msg('Payables Open Interface Import (request_id=' || l_apxiimpt_req_id || ')');
      p_apxiimpt_req_id := l_apxiimpt_req_id;
      /******************************/
      /* Wait for request           */
      /******************************/
      wait_for_request(l_apxiimpt_req_id, 5, r_srs_apxiimpt);

      IF NOT ( r_srs_apxiimpt.srs_dev_phase = 'COMPLETE' AND
               r_srs_apxiimpt.srs_dev_status IN ('NORMAL','WARNING') ) THEN
         log_msg(g_error || 'Payables Open Interface Import failed');
         l_status := 'ERROR';
         l_error_count := l_total; -- effectively all have failed
      ELSE
         -- check that the import program actually created the invoices
         l_load_success_cnt := validate_load(p_run_id, l_run_phase_id);
         IF l_load_success_cnt = l_total THEN
            l_status := 'SUCCESS';
            l_error_count := 0;
         ELSE
            l_status := 'ERROR';
            l_error_count := l_total - l_load_success_cnt;
         END IF;
      END IF;
   END IF;

   /*********************************/
   /* Submit Invoice Validation     */
   /*********************************/
   IF p_submit_validation = 'Y' THEN
      l_batch_id := get_batch_id(g_int_batch_name);
      l_apprvl_req_id := submit_apprvl(l_batch_id, g_sob_id, g_org_id);
      debug_msg('Invoice Validation (request_id=' || l_apprvl_req_id || ')');
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
--      process_invoices
--  PURPOSE
--       Concurrent Program XXAP_INVOICES_INT (DEDJTR Payables Invoice Interface)
--  DESCRIPTION
--       Main program controller
-- --------------------------------------------------------------------------------------------------
PROCEDURE process_invoices
(
   p_errbuff            OUT VARCHAR2,
   p_retcode            OUT NUMBER,
   p_source             IN  VARCHAR2,
   p_file_name          IN  VARCHAR2,
   p_batch_name         IN  VARCHAR2,
   p_gl_date            IN  VARCHAR2,
   p_control_file       IN  VARCHAR2,
   p_submit_validation  IN  VARCHAR2,
   p_debug_flag         IN  VARCHAR2,
   p_int_mode           IN  VARCHAR2,
   p_purge_retention    IN  NUMBER DEFAULT NULL
) IS
   z_procedure_name           CONSTANT VARCHAR2(150) := 'xxap_invoice_interface_pkg.process_invoices';
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
   l_apxiimpt_req_id          NUMBER;
   r_srs_xxintifr             r_srs_request_type;
   l_run_error                NUMBER := 0;
   r_request                  xxint_common_pkg.CONTROL_RECORD_TYPE;
   r_gl_period_status         gl_period_statuses%ROWTYPE;
   l_message                  VARCHAR2(240);
   t_files_tab                t_varchar_tab_type;
   l_run_id                   NUMBER;
   l_run_phase_id             NUMBER;
   l_rep_req_id               NUMBER;
   l_err_req_id               NUMBER;
   l_ack_file_name            VARCHAR2(100);
   e_interface_error          EXCEPTION;
BEGIN
   /******************************************/
   /* Pre-process validation                 */
   /******************************************/
   xxint_common_pkg.g_object_type := 'INVOICES';
   l_req_id := fnd_global.conc_request_id;
   l_appl_id := fnd_global.resp_appl_id;
   l_user_name := fnd_profile.value('USERNAME');
   g_sob_id := fnd_profile.value('GL_SET_OF_BKS_ID');
   g_org_id := fnd_profile.value('ORG_ID');
   g_chart_id := get_chart_of_accounts_id(g_sob_id);
   g_sob_currency := get_sob_currency(g_sob_id);
   g_debug_flag := nvl(p_debug_flag, 'N');
   g_source := SUBSTR(p_source, 1, 80);
   g_accounting_date := fnd_date.canonical_to_date(p_gl_date);
   l_ctl := nvl(p_control_file, g_ctl);
   l_file := nvl(p_file_name, g_source || g_file);
   l_tfm_mode := nvl(p_int_mode, g_int_mode);

   IF g_accounting_date IS NULL THEN
      g_accounting_date := TRUNC(SYSDATE);
   END IF;

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

   debug_msg('g_accounting_date=' || g_accounting_date);
   debug_msg('p_source=' || p_source);
   debug_msg('l_file=' || l_file);
   debug_msg('l_ctl=' || l_ctl);
   debug_msg('l_inbound_directory=' || l_inbound_directory);
   debug_msg('l_outbound_directory=' || l_outbound_directory);
   debug_msg('l_staging_directory=' || l_staging_directory);
   debug_msg('l_archive_directory=' || l_archive_directory);

   query_period_statuses(g_accounting_date, 'MONTH', 200, r_gl_period_status);
   IF (r_gl_period_status.period_name IS NULL OR 
       r_gl_period_status.closing_status != 'O') 
   THEN
      log_msg(g_error || 'Accounting Date ''' ||  TO_CHAR(g_accounting_date, 'DD-MON-YYYY') ||
              ''' is not in an open Payables period');
      p_retcode := 2;
      RETURN;
   END IF;

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
   initialise_dff_cache(200, 'AP_INVOICES', p_source);

   /*****************************/
   /* Process each file         */
   /*****************************/
   FOR i IN 1..t_files_tab.LAST
   LOOP
      l_file := replace(t_files_tab(i), l_inbound_directory || '/');
      l_log  := replace(l_file, 'csv', 'log');
      l_bad  := replace(l_file, 'csv', 'bad');
      g_int_batch_name := nvl(p_batch_name, l_file);

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
         IF NOT load(l_run_id, l_run_phase_id, p_submit_validation, l_apxiimpt_req_id) THEN
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

      /*********************************/
      /* Acknowledgement file          */
      /*********************************/
    --l_ack_file_name := g_source || '_' || to_char(SYSDATE, 'YYYYMMDDHH24MISS') || '_' || l_req_id || '.txt';
      l_ack_file_name := replace(l_file, '.csv') || '_' || l_req_id || '.csv';
      generate_ack_output(l_run_id, g_source, l_ack_file_name, l_outbound_directory);

      /*********************************/
      /* Copy APXIIMPT files           */
      /*********************************/
      copy_conc_request_file(l_apxiimpt_req_id, 'OUTPUT', l_outbound_directory, replace(l_ack_file_name, '.csv', '_out.txt'));
      copy_conc_request_file(l_apxiimpt_req_id, 'LOG', l_outbound_directory, replace(l_ack_file_name, '.csv', '_log.txt'));

   END LOOP;

   /*********************************/
   /* Purge historic data           */
   /*********************************/
   IF nvl(p_purge_retention,-1) > 0 THEN
      debug_msg('Purging transformation table data older than ' || p_purge_retention || ' days');
      xxint_common_pkg.purge_interface_data('XXAP_INVOICES_INTERFACE_TFM', p_purge_retention);
   END IF;

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

      /*********************************/
      /* Acknowledgement file          */
      /*********************************/
    --l_ack_file_name := g_source || '_' || to_char(SYSDATE, 'YYYYMMDDHH24MISS') || '_' || l_req_id || '.csv';
      l_ack_file_name := replace(NVL(l_file, 'ERROR'), '.csv') || '_' || l_req_id || '.csv';
      generate_ack_output(l_run_id, g_source, l_ack_file_name, l_outbound_directory);

      p_retcode := 1;

END process_invoices;

END xxap_invoice_interface_pkg;
/