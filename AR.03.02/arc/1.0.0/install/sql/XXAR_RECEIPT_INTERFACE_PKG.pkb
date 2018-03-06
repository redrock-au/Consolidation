CREATE OR REPLACE PACKAGE BODY xxar_receipt_interface_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.03.02/arc/1.0.0/install/sql/XXAR_RECEIPT_INTERFACE_PKG.pkb 1830 2017-07-18 00:26:50Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: AR.02.03
**
** Description: Interface program for importing Receivables 
**              receipts from various feeder systems. 
**
** Change History:
**
** Date        Who                  Comments
** 05/05/2017  SRYAN (RED ROCK)     Initial build.
**
*******************************************************************/
g_debug_flag                  VARCHAR2(1) := 'N';
g_int_batch_name              dot_int_runs.src_batch_name%TYPE;
g_sob_id                      NUMBER;
g_sob_currency                fnd_currencies.currency_code%TYPE;
g_org_id                      NUMBER;
g_chart_id                    NUMBER;
g_source                      fnd_lookup_values.lookup_code%TYPE;
g_gl_date                     DATE;
g_receipt_class_id            NUMBER;
e_invalid_date                EXCEPTION;
e_no_files_found              EXCEPTION;

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
TYPE t_number_tab_type  IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
TYPE t_validation_errors_type IS TABLE OF VARCHAR2(240);

-- Cache Entry Types
TYPE r_pay_method_cache_entry_type IS RECORD
(
   ar_receipt_methods_rec  ar_receipt_methods%ROWTYPE,
   val_errors              t_validation_errors_type
);

TYPE r_activity_cache_entry_type IS RECORD
(
   ar_receivables_trx_rec  ar_receivables_trx%ROWTYPE,
   val_errors              t_validation_errors_type
);

TYPE r_receipt_cache_entry_type  IS RECORD
(
   cash_receipt_id      NUMBER,
   max_record_id        NUMBER,
   total_amt_applied    NUMBER
);

-- Cache Types
TYPE t_dff_defn_cache_type    IS TABLE OF fnd_descr_flex_column_usages%ROWTYPE INDEX BY VARCHAR2(30);
TYPE t_receipt_info_cache_type IS TABLE OF t_dff_defn_cache_type INDEX BY VARCHAR2(30);
TYPE t_pay_methods_cache_type IS TABLE OF r_pay_method_cache_entry_type INDEX BY VARCHAR2(30);
TYPE t_activity_cache_type    IS TABLE OF r_activity_cache_entry_type INDEX BY VARCHAR2(50);
TYPE t_receipt_cache_type     IS TABLE OF r_receipt_cache_entry_type INDEX BY VARCHAR2(30);
TYPE t_recall_pay_method_cache_type IS TABLE OF fnd_lookup_values%ROWTYPE INDEX BY VARCHAR2(30);

-- Caches 
g_receipt_info_cache          t_receipt_info_cache_type;
g_pay_method_cache            t_pay_methods_cache_type;
g_activity_cache              t_activity_cache_type;
g_trx_balance_cache           t_number_tab_type;
g_receipt_cache               t_receipt_cache_type;
g_recall_pay_method_cache     t_recall_pay_method_cache_type;

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
--      transform_to_date
--  PURPOSE
--      Transforms a varchar of a given format to a date.
--  RETURNS
--      Date, or  raises e_invalid_date 
-- --------------------------------------------------------------------------------------------------
FUNCTION transform_to_date
(
   p_date_value            VARCHAR2,
   p_date_format_str       VARCHAR2
) RETURN DATE
IS
   l_date                  DATE;
BEGIN
   l_date := TO_DATE(p_date_value, p_date_format_str);
   RETURN l_date;
EXCEPTION
   WHEN OTHERS THEN
      RAISE e_invalid_date;
END transform_to_date;

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
--      query_payment_notice
--  PURPOSE
--      Queries a paymnent notice from the CRN.
--  RETURNS
--      Payment Notice record
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_payment_notice
(
   p_crn                   VARCHAR2,
   p_payment_notice_rec    IN OUT NOCOPY xxar_payment_status_v%ROWTYPE
)
IS
   l_payment_notice_rec    xxar_payment_status_v%ROWTYPE;
BEGIN
   SELECT crn_id
   INTO   l_payment_notice_rec.crn_id
   FROM   xxar_payment_status_v
   WHERE  crn_number = p_crn
   AND    open_item_status = 'New';
   p_payment_notice_rec := l_payment_notice_rec;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_payment_notice_rec.crn_id := NULL;
END query_payment_notice;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_receipt_by_crn
--  PURPOSE
--      Queries a receipt by CRN (Attribute14)
--  RETURNS
--      Transaction and Customer identifiers
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_receipt_by_crn
(
   p_crn                      IN VARCHAR2,
   p_cash_receipt_rec         IN OUT NOCOPY ar_cash_receipts%ROWTYPE
) IS
   CURSOR c_receipt(p_crn IN VARCHAR2) IS
      SELECT *
      FROM   ar_cash_receipts
      WHERE  attribute14 = p_crn
      ORDER BY cash_receipt_id DESC;

   r_receipt                  c_receipt%ROWTYPE;
BEGIN
   OPEN c_receipt(p_crn);
   FETCH c_receipt INTO r_receipt;
   IF c_receipt%FOUND THEN
      p_cash_receipt_rec.cash_receipt_id := r_receipt.cash_receipt_id;
      p_cash_receipt_rec.receipt_number := r_receipt.receipt_number;
      p_cash_receipt_rec.pay_from_customer := r_receipt.pay_from_customer;
      p_cash_receipt_rec.customer_site_use_id := r_receipt.customer_site_use_id;
   ELSE
      p_cash_receipt_rec.cash_receipt_id := NULL;
      p_cash_receipt_rec.receipt_number := NULL;
      p_cash_receipt_rec.pay_from_customer := NULL;
      p_cash_receipt_rec.customer_site_use_id := NULL;
   END IF;
   CLOSE c_receipt;
END query_receipt_by_crn;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_trx_by_crn
--  PURPOSE
--      Queries a transaction by CRN (Attribute7)
--  RETURNS
--      Transaction and Customer identifiers, Amount due on the transaction
--      If more than one transaction exists, the most recent invoice is selected.
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_trx_by_crn
(
   p_crn                      IN VARCHAR2,
   p_customer_trx_rec         IN OUT NOCOPY ra_customer_trx%ROWTYPE,
   p_amount_due_remaining     OUT NUMBER,
   p_trx_rec_ccid             OUT NUMBER
) IS
   CURSOR c_trx(p_crn IN VARCHAR2) IS
      SELECT rct.customer_trx_id,
             rct.trx_number, 
             rct.bill_to_customer_id, 
             rct.bill_to_site_use_id,
             aps.amount_due_remaining,
             rctd.code_combination_id
      FROM   ra_customer_trx rct,
             ra_cust_trx_line_gl_dist rctd,
             ar_payment_schedules aps
      WHERE  aps.customer_trx_id = rct.customer_trx_id
      AND    rct.attribute7 = p_crn
      AND    rctd.customer_trx_id = rct.customer_trx_id
      AND    rctd.account_class = 'REC'
      ORDER BY rct.customer_trx_id DESC;

   r_trx                      c_trx%ROWTYPE;
BEGIN
   OPEN c_trx(p_crn);
   FETCH c_trx INTO r_trx;
   IF c_trx%FOUND THEN
      p_customer_trx_rec.customer_trx_id := r_trx.customer_trx_id; 
      p_customer_trx_rec.trx_number := r_trx.trx_number; 
      p_customer_trx_rec.bill_to_customer_id := r_trx.bill_to_customer_id;
      p_customer_trx_rec.bill_to_site_use_id := r_trx.bill_to_site_use_id;
      p_amount_due_remaining := r_trx.amount_due_remaining;
      p_trx_rec_ccid := r_trx.code_combination_id;
   ELSE
      p_customer_trx_rec.customer_trx_id := NULL; 
      p_customer_trx_rec.trx_number := NULL; 
      p_customer_trx_rec.bill_to_customer_id := NULL;
      p_customer_trx_rec.bill_to_site_use_id := NULL;
      p_amount_due_remaining := NULL;
      p_trx_rec_ccid := NULL;
   END IF;
   CLOSE c_trx;
END query_trx_by_crn;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_trx_by_number
--  PURPOSE
--      Queries a transaction by invoice number
--  RETURNS
--      Transaction record, amount due remaining and receivables distribution code coombination
--      If more than one transaction exists, the most recent invoice is selected.
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_trx_by_number
(
   p_invoice_number           IN VARCHAR2,
   p_customer_trx_rec         IN OUT NOCOPY ra_customer_trx%ROWTYPE,
   p_amount_due_remaining     OUT NUMBER,
   p_trx_rec_ccid             OUT NUMBER
) IS
   CURSOR c_trx(p_number IN VARCHAR2) IS
      SELECT rct.customer_trx_id,
             rct.trx_number, 
             rct.bill_to_customer_id, 
             rct.bill_to_site_use_id,
             aps.amount_due_remaining,
             rctd.code_combination_id
      FROM   ra_customer_trx rct,
             ra_cust_trx_line_gl_dist rctd,
             ar_payment_schedules aps
      WHERE  aps.customer_trx_id = rct.customer_trx_id
      AND    rct.trx_number = p_number
      AND    rctd.customer_trx_id = rct.customer_trx_id
      AND    rctd.account_class = 'REC'
      ORDER BY rct.customer_trx_id DESC;

   r_trx                      c_trx%ROWTYPE;
BEGIN
   OPEN c_trx(p_invoice_number);
   FETCH c_trx INTO r_trx;
   IF c_trx%FOUND THEN
      p_customer_trx_rec.customer_trx_id := r_trx.customer_trx_id; 
      p_customer_trx_rec.trx_number := r_trx.trx_number; 
      p_customer_trx_rec.bill_to_customer_id := r_trx.bill_to_customer_id;
      p_customer_trx_rec.bill_to_site_use_id := r_trx.bill_to_site_use_id;
      p_amount_due_remaining := r_trx.amount_due_remaining;
      p_trx_rec_ccid := r_trx.code_combination_id;
   ELSE
      p_customer_trx_rec.customer_trx_id := NULL; 
      p_customer_trx_rec.trx_number := NULL; 
      p_customer_trx_rec.bill_to_customer_id := NULL;
      p_customer_trx_rec.bill_to_site_use_id := NULL;
      p_amount_due_remaining := NULL;
      p_trx_rec_ccid := NULL;
   END IF;
   CLOSE c_trx;
END query_trx_by_number;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_receivable_activity
--  PURPOSE
--      Queries a receivable activity from AR_RECEIVABLES_TRX and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_receivable_activity
(
   p_activity_name            IN VARCHAR2 DEFAULT NULL,
   p_crn_id                   IN VARCHAR2 DEFAULT NULL,
   p_ar_receivables_trx_rec   IN OUT NOCOPY ar_receivables_trx%ROWTYPE
) IS
   lr_ar_receivables_trx_rec  ar_receivables_trx%ROWTYPE;
BEGIN
   IF p_activity_name IS NULL AND p_crn_id IS NULL THEN
      RAISE NO_DATA_FOUND;
   END IF;
   --
   SELECT *
   INTO   lr_ar_receivables_trx_rec
   FROM   ar_receivables_trx 
   WHERE  ( p_activity_name IS NOT NULL AND 
            p_crn_id IS NULL AND 
            name = p_activity_name )
   OR     ( p_crn_id IS NOT NULL AND 
            p_activity_name IS NULL AND 
            attribute2 = p_crn_id );
   p_ar_receivables_trx_rec := lr_ar_receivables_trx_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_ar_receivables_trx_rec.receivables_trx_id := NULL;
   WHEN TOO_MANY_ROWS THEN
      log_msg('Too many definitions of receivable activity exist for either name ' 
         || p_activity_name || ', or CRN Id ' || p_crn_id);
      RAISE;
END query_receivable_activity;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_bank_account
--  PURPOSE
--      Queries a bank account from AP_BANK_ACCOUNTS and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_bank_account
(
   p_bank_account_num         IN VARCHAR2,
   p_account_type             IN VARCHAR,
   p_ap_bank_accounts_rec     IN OUT NOCOPY ap_bank_accounts%ROWTYPE
) IS
   lr_ap_bank_accounts_rec    ap_bank_accounts%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_ap_bank_accounts_rec
   FROM   ap_bank_accounts 
   WHERE  bank_account_num = p_bank_account_num
   AND    account_type = p_account_type;
   p_ap_bank_accounts_rec := lr_ap_bank_accounts_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_ap_bank_accounts_rec.bank_account_id := NULL;
END query_bank_account;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_recall_pay_method_code
--  PURPOSE
--      Queries the mapping of Recall payment method codes and trans types
--      This is maintained in lookup type XXAR_RECALL_PAYMENT_METHODS_ID, where
--        1) Description = Payment Method Code
--        2) Tag = Trans Type (optional, used to distinguish between Quickvoice and Quickweb)
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_recall_pay_method_code
(
   p_pay_method_code          IN VARCHAR2,
   p_trans_type               IN VARCHAR2,
   p_fnd_lookup_rec           IN OUT NOCOPY fnd_lookup_values%ROWTYPE
) IS
   l_fnd_lookup_rec           fnd_lookup_values%ROWTYPE;
BEGIN
   SELECT *
   INTO   l_fnd_lookup_rec
   FROM   fnd_lookup_values
   WHERE  lookup_type = 'XXAR_RECALL_PAYMENT_METHODS_ID'
   AND    description = p_pay_method_code
   AND    ( tag IS NULL OR tag = nvl(p_trans_type, tag) )
   AND    enabled_flag = 'Y'
   AND    SYSDATE BETWEEN nvl(start_date_active, SYSDATE - 1) AND nvl(end_date_active, SYSDATE + 1);
   p_fnd_lookup_rec := l_fnd_lookup_rec;
EXCEPTION
   WHEN TOO_MANY_ROWS THEN
      -- this indicates more than one definition exists
      RAISE_APPLICATION_ERROR(-20000, 'Multiple definitions exist in XXAR_RECALL_PAYMENT_METHODS_ID ' || 
         'for Recall payment method code ' || p_pay_method_code);
   WHEN NO_DATA_FOUND THEN
      p_fnd_lookup_rec.lookup_code := NULL;
END query_recall_pay_method_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_receipt_method
--  PURPOSE
--      Queries a receipt method from AR_RECEIPT_METHODS and returns the row
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_receipt_method
(
   p_receipt_method           IN VARCHAR2,
   p_ar_receipt_methods_rec   IN OUT NOCOPY ar_receipt_methods%ROWTYPE
) IS
   lr_ar_receipt_methods_rec  ar_receipt_methods%ROWTYPE;
BEGIN
   SELECT *
   INTO   lr_ar_receipt_methods_rec
   FROM   ar_receipt_methods 
   WHERE  name = p_receipt_method;
   p_ar_receipt_methods_rec := lr_ar_receipt_methods_rec; 
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_ar_receipt_methods_rec.receipt_method_id := NULL;
END query_receipt_method;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      map_bank_account
--  PURPOSE
--      Determines the bank account to use on the receipt
--  DESCRIPTION
--      The bank account is selected from the list of accounts associated the the receipt method.
--      The Receipt Method Account's Organization DFF (Attribute1) is compared with one of two accounts, either:
--        1) A transaction's receivables distribution account for Standard receipt types; or
--        2) A receivable activity's activity gl account for Miscellaneous receipts types
--      The bank account is selected where the Attribute1 value matches the SEGMENT1 
--      value of the reference gl account.
--      If no bank account is found, the receipt API will default the primary bank account of the receipt method
--      If more than one bank account matches, then an error is raised.
-- --------------------------------------------------------------------------------------------------
PROCEDURE map_bank_account
(
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   l_bank_account_id       NUMBER;
   l_reference_ccid        NUMBER := nvl(p_tfm_rec.trx_receivables_ccid, p_tfm_rec.activity_gl_ccid);
BEGIN
   IF l_reference_ccid IS NULL THEN
      debug_msg('no reference gl account exists to select the bank account');
      RETURN;
   END IF;
   --
   SELECT aba.bank_account_id
   INTO   l_bank_account_id
   FROM   ap_bank_accounts aba,
          ar_receipt_method_accounts arma,
          gl_code_combinations ref
   WHERE  arma.bank_account_id = aba.bank_account_id
   AND    arma.receipt_method_id = p_tfm_rec.receipt_method_id
   AND    ref.code_combination_id = l_reference_ccid
   AND    ref.segment1 = arma.attribute1
   AND    aba.account_type = 'INTERNAL'
   AND    SYSDATE BETWEEN arma.start_date AND nvl(arma.end_date, SYSDATE + 1);
   --
   p_tfm_rec.remit_bank_account_id := l_bank_account_id;
   debug_msg('mapped bank account id ' || p_tfm_rec.remit_bank_account_id);
EXCEPTION
   WHEN TOO_MANY_ROWS THEN
      append_error(p_errors_tab, 'Cannot determine bank account.  Multiple bank accounts exist ' 
         || 'with Organisation DFF value matching Organization of code combination id' || l_reference_ccid);
   WHEN NO_DATA_FOUND THEN
      -- The receipt API will default the bank account if one is not specified
      -- just log the fact that we couldn't find a matching bank account 
      debug_msg('no bank account found matching segment1 of ccid ''' 
         || nvl(p_tfm_rec.trx_receivables_ccid, p_tfm_rec.activity_gl_ccid) || '''');
END map_bank_account;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      check_dff
--  PURPOSE
--      Validates a single descriptive flexfield value against the cached DFF rules
--  DESCRIPTION
--      Currently is limited to checking mandatory fields.
-- --------------------------------------------------------------------------------------------------
PROCEDURE check_dff
(
   p_value                 IN VARCHAR2,
   p_attribute_column      IN VARCHAR2,
   p_context               IN VARCHAR2,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   z_global_context        VARCHAR2(30) := 'Global Data Elements'; 
   l_attribute_column      VARCHAR2(30) := UPPER(p_attribute_column);
BEGIN
   IF ( g_receipt_info_cache.EXISTS(p_context) AND g_receipt_info_cache(p_context).EXISTS(l_attribute_column) ) THEN
      IF g_receipt_info_cache(p_context)(l_attribute_column).required_flag = 'Y' AND p_value IS NULL THEN
         append_error(p_errors_tab, 'Mandatory field ' || l_attribute_column || ' (' 
               || g_receipt_info_cache(p_context)(l_attribute_column).end_user_column_name || ') has not been provided');
      END IF;
   ELSIF ( g_receipt_info_cache.EXISTS(z_global_context) AND g_receipt_info_cache(z_global_context).EXISTS(l_attribute_column) ) THEN
      IF g_receipt_info_cache(z_global_context)(l_attribute_column).required_flag = 'Y' AND p_value IS NULL THEN
         append_error(p_errors_tab, 'Mandatory field ' || l_attribute_column || ' (' 
               || g_receipt_info_cache(z_global_context)(l_attribute_column).end_user_column_name || ') has not been provided');
      END IF;
   ELSIF ( ( NOT g_receipt_info_cache.EXISTS(p_context) OR NOT g_receipt_info_cache(p_context).EXISTS(l_attribute_column) ) AND 
           ( NOT g_receipt_info_cache.EXISTS(z_global_context) OR NOT g_receipt_info_cache(z_global_context).EXISTS(l_attribute_column) ) )   THEN 
      IF p_value IS NOT NULL THEN
         append_error(p_errors_tab, l_attribute_column || ' value has been provided (' || p_value 
               || ') but the Descriptive Flexfield for this column has not been defined');
      END IF;
   END IF;
END check_dff;

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
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   check_dff(p_tfm_rec.attribute1, 'ATTRIBUTE1', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute2, 'ATTRIBUTE2', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute3, 'ATTRIBUTE3', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute4, 'ATTRIBUTE4', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute5, 'ATTRIBUTE5', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute6, 'ATTRIBUTE6', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute7, 'ATTRIBUTE7', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute8, 'ATTRIBUTE8', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute9, 'ATTRIBUTE9', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute10, 'ATTRIBUTE10', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute11, 'ATTRIBUTE11', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute12, 'ATTRIBUTE12', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute13, 'ATTRIBUTE13', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute14, 'ATTRIBUTE14', p_tfm_rec.receipt_method_id, p_errors_tab);
   check_dff(p_tfm_rec.attribute15, 'ATTRIBUTE15', p_tfm_rec.receipt_method_id, p_errors_tab);
END validate_dff_segments;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_receivable_activity
--  PURPOSE
--      Validates receivable activities.
--  DESCRIPTION
--      First searches the activity cache to see if it has been queried before.
--      If not in the cache, the function queries the database for it
--      Tax Code is then validated:
--        1) Must exist in AR_RECEIVABLES_TRX
--        2) Must be active
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_receivable_activity
(
   p_activity              IN VARCHAR2,
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           ar_receivables_trx%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   -- first check whether the receivable activity was supplied.
   -- it is not required if the receipt type is standard 
   IF p_tfm_rec.receipt_type = 'Standard' THEN
      RETURN;
   ELSIF p_activity IS NULL THEN
      append_error(p_errors_tab, 'Receivable Activity not supplied');
      RETURN;
   END IF;
   -- look into the cache first and query the database only if it is not there
   IF NOT g_activity_cache.EXISTS(p_activity) THEN
      query_receivable_activity(p_activity, NULL, lr_entity_rec);
      -- must exist
      IF lr_entity_rec.receivables_trx_id IS NULL THEN
         append_error(lt_val_errors_tab, 'Receivable Activity ''' || p_activity || ''' does not exist');
      -- must be active
      ELSIF ( lr_entity_rec.status <> 'A' OR 
              nvl(lr_entity_rec.start_date_active, SYSDATE - 1) > SYSDATE OR
              nvl(lr_entity_rec.end_date_active, SYSDATE + 1) < SYSDATE ) THEN 
         append_error(lt_val_errors_tab, 'Receivable Activity ''' || p_activity || ''' is not active');
      END IF;
      -- insert new entry into cache
      g_activity_cache(p_activity).ar_receivables_trx_rec := lr_entity_rec;
      g_activity_cache(p_activity).val_errors := lt_val_errors_tab;
   END IF;
   -- set the output params to the cached values
   p_tfm_rec.receivables_trx_id := g_activity_cache(p_activity).ar_receivables_trx_rec.receivables_trx_id;
   p_tfm_rec.activity_gl_ccid := g_activity_cache(p_activity).ar_receivables_trx_rec.code_combination_id;
   append_error_tab(p_errors_tab, g_activity_cache(p_activity).val_errors);
END validate_receivable_activity;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_crn
--  PURPOSE
--      Validates CRN.
--  DESCRIPTION
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_crn
(
   p_crn                   IN VARCHAR2,
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_customer_trx_rec        ra_customer_trx%ROWTYPE;
   lr_cash_receipt_rec        ar_cash_receipts%ROWTYPE;
   lr_ar_receivables_trx_rec  ar_receivables_trx%ROWTYPE;
   lr_payment_notice_rec      xxar_payment_status_v%ROWTYPE;
   l_amount_due_remaining     NUMBER;
   l_trx_rec_ccid             NUMBER;
BEGIN
   debug_msg('validating crn ' || p_crn);
   IF p_tfm_rec.trx_receivables_ccid IS NOT NULL THEN
      -- If the receipt is already associated with an invoice, then the CRN is ignored.
      RETURN;
   ELSIF p_crn IS NULL THEN
      -- CRN is mandatory if invoice number was not provided
      append_error(p_errors_tab, 'CRN not supplied');
      RETURN;
   END IF;
   /*
   -- Search Transaction by CRN
   */
   query_trx_by_crn(p_crn, lr_customer_trx_rec, l_amount_due_remaining, l_trx_rec_ccid);
   IF lr_customer_trx_rec.customer_trx_id IS NOT NULL THEN
      -- transaction exists for the CRN; map customer ids
      debug_msg('found transaction ' || lr_customer_trx_rec.trx_number);
      p_tfm_rec.customer_id := lr_customer_trx_rec.bill_to_customer_id;
      p_tfm_rec.customer_site_use_id := lr_customer_trx_rec.bill_to_site_use_id;
      p_tfm_rec.trx_receivables_ccid := l_trx_rec_ccid;
      -- initialise the transaction balance cache with the outstanding amount
      g_trx_balance_cache(lr_customer_trx_rec.customer_trx_id) := l_amount_due_remaining;
      -- if the receipt amount is less than or equal to the transaction amount then 
      -- the receipt can be applied to the transaction.  otherwise the amount will go on account
      IF l_amount_due_remaining > 0 THEN
         p_tfm_rec.customer_trx_id := lr_customer_trx_rec.customer_trx_id;
         debug_msg('receipt marked for application');
      END IF;
   ELSE
      IF g_source = 'RECALL' THEN
         -- For RECALL files the first 3 digits of the CRN may match the CRN Identifier DFF on a Receivable Activity
         -- If so, use this receivable activity on the miscellaneous receipt that will now be created.
         -- Otherwise create the Misc receipt using the Unidentified Receipts activity
         p_tfm_rec.receipt_type := 'Miscellaneous';
         query_receivable_activity(NULL, SUBSTR(p_crn, 1, 3), lr_ar_receivables_trx_rec);
         IF lr_ar_receivables_trx_rec.receivables_trx_id IS NOT NULL AND 
            ( lr_ar_receivables_trx_rec.status = 'A' AND 
              nvl(lr_ar_receivables_trx_rec.start_date_active, SYSDATE - 1) < SYSDATE AND
              nvl(lr_ar_receivables_trx_rec.end_date_active, SYSDATE + 1) > SYSDATE ) 
         THEN 
            p_tfm_rec.receivables_trx_id := lr_ar_receivables_trx_rec.receivables_trx_id;
            p_tfm_rec.activity_gl_ccid := lr_ar_receivables_trx_rec.code_combination_id;
         ELSE
            validate_receivable_activity('Unidentified Receipts', p_tfm_rec, p_errors_tab);
         END IF;
      END IF;
   END IF;
   /*
   -- Determine whether the CRN is a valid payment notice
   */
   query_payment_notice(p_crn, lr_payment_notice_rec);
   IF lr_payment_notice_rec.crn_id IS NOT NULL THEN
      p_tfm_rec.payment_notice_flag := 'Y';
      p_tfm_rec.attribute14 := lr_payment_notice_rec.crn_id;
   ELSE
      p_tfm_rec.payment_notice_flag := 'N';
   END IF;
   /*
   -- Validation
   */
   IF lr_customer_trx_rec.customer_trx_id IS NOT NULL AND p_tfm_rec.payment_notice_flag = 'Y' THEN
      IF g_source = 'RECALL' THEN
         -- For REcall, if CRN is both an invoice and a payment notice then a Standard On-Account receipt should be created
         p_tfm_rec.receipt_type := 'Standard';
         p_tfm_rec.receivables_trx_id := NULL;
         p_tfm_rec.activity_gl_ccid := NULL;
         p_tfm_rec.customer_trx_id := NULL;
      ELSE
         -- For POS and generic sources, an error should be flagged
         append_error(p_errors_tab, 'CRN exists as an Invoice and a Payment Notice');
      END IF;
   END IF;

   -- DFF mapping
   p_tfm_rec.attribute13 := p_crn;
END validate_crn;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_invoice_number
--  PURPOSE
--      Validates invoice number.
--  DESCRIPTION
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_invoice_number
(
   p_stg_rec               IN OUT NOCOPY xxar_receipts_interface_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_customer_trx_rec        ra_customer_trx%ROWTYPE;
   l_amount_due_remaining     NUMBER;
   l_trx_rec_ccid             NUMBER;
BEGIN
   debug_msg('validating invoice number ' || p_stg_rec.invoice_number);
   IF p_stg_rec.invoice_number IS NULL THEN
      RETURN;
   ELSIF p_stg_rec.receipt_type = 'Miscellaneous' THEN
      append_error(p_errors_tab, 'Invoice number not allowed if receipt type is Miscellaneous');
      RETURN;
   END IF;
   query_trx_by_number(p_stg_rec.invoice_number, lr_customer_trx_rec, l_amount_due_remaining, l_trx_rec_ccid);
   -- Must exist
   IF lr_customer_trx_rec.customer_trx_id IS NULL THEN
      append_error(p_errors_tab, 'Invoice number ''' || p_stg_rec.invoice_number || ''' does not exist');
      RETURN;
   END IF;
   -- transaction exists; map customer ids
   debug_msg('found transaction ' || lr_customer_trx_rec.trx_number);
   p_tfm_rec.customer_id := lr_customer_trx_rec.bill_to_customer_id;
   p_tfm_rec.customer_site_use_id := lr_customer_trx_rec.bill_to_site_use_id;
   p_tfm_rec.trx_receivables_ccid := l_trx_rec_ccid;
   -- initialise the transaction balance cache with the outstanding amount
   g_trx_balance_cache(lr_customer_trx_rec.customer_trx_id) := l_amount_due_remaining;
   -- if the receipt amount is less than or equal to the transaction amount then 
   -- the receipt can be applied to the transaction.  otherwise the amount will go on account
   IF l_amount_due_remaining > 0 THEN
      p_tfm_rec.customer_trx_id := lr_customer_trx_rec.customer_trx_id;
      debug_msg('receipt marked for application');
   END IF;
END validate_invoice_number;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_payer_name
--  PURPOSE
--      Validates payer names.
--  DESCRIPTION
--        1) Must be provided for Miscellaneous Receipts
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_payer_name
(
   p_stg_rec               IN OUT NOCOPY xxar_receipts_interface_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.receipt_type = 'Miscellaneous' THEN
      IF p_stg_rec.payer_name IS NULL THEN
         append_error(p_errors_tab, 'Payer name must be supplied if receipt type is Miscellaneous');
      ELSE
        p_tfm_rec.misc_payment_source := p_stg_rec.payer_name;
      END IF;
   END IF;
END validate_payer_name;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_processing_date
--  PURPOSE
--      Validates processing dates.
--  DESCRIPTION
--      1) Must have a value
--      2) Must be of the format DD-MON-YYYY
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_processing_date
(
   p_processing_date       IN VARCHAR2,
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   z_date_format              CONSTANT VARCHAR2(11) := 'DDMMYYYY';
BEGIN
   IF p_processing_date IS NOT NULL THEN
      -- validate format
      BEGIN
         p_tfm_rec.receipt_date := TO_DATE(p_processing_date, 'FX'||z_date_format);
      EXCEPTION
         WHEN OTHERS THEN
            append_error(p_errors_tab, 'Processing Date ''' || p_processing_date 
               || ''' is not in the required format ''' || z_date_format || '''');
            RETURN;
      END;
   ELSE
      append_error(p_errors_tab, 'Processing Date not supplied');
   END IF;
END validate_processing_date;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_receipt_date
--  PURPOSE
--      Validates receipt dates.
--  DESCRIPTION
--      1) Must have a value
--      2) Must be of the format DD-MON-YYYY
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_receipt_date
(
   p_stg_rec               IN OUT NOCOPY xxar_receipts_interface_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   z_date_format              CONSTANT VARCHAR2(11) := 'DD-MON-YYYY';
BEGIN
   IF p_stg_rec.receipt_date IS NOT NULL THEN
      -- validate format
      BEGIN
         p_tfm_rec.receipt_date := TO_DATE(p_stg_rec.receipt_date, 'FX'||z_date_format);
      EXCEPTION
         WHEN OTHERS THEN
            append_error(p_errors_tab, 'Receipt Date ''' || p_stg_rec.receipt_date 
               || ''' is not in the required format ''' || z_date_format || '''');
            RETURN;
      END;
   ELSE
      append_error(p_errors_tab, 'Receipt date not supplied');
   END IF;
END validate_receipt_date;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_receipt_amount
--  PURPOSE
--      Validates receipt amounts.
--  DESCRIPTION
--        1) Must be provided
--        2) Must be a number
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_receipt_amount
(
   p_rec_amount            IN VARCHAR2,
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_rec_amount IS NULL THEN
      append_error(p_errors_tab, 'Receipt amount not supplied');
   ELSIF NOT is_number(p_rec_amount) THEN
      append_error(p_errors_tab, 'Receipt amount ''' || p_rec_amount || '''  is not a number');
   ELSE
      IF g_source = 'RECALL' THEN
         -- Recall amounts are provided in cents
         p_tfm_rec.receipt_amount := p_rec_amount / 100;
      ELSE
         p_tfm_rec.receipt_amount := p_rec_amount;
      END IF;
   END IF;
END validate_receipt_amount;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_receipt_number
--  PURPOSE
--      Validates receipt numbers.
--  DESCRIPTION
--        1) Must be provided
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_receipt_number
(
   p_receipt_number        IN VARCHAR2,
   p_source                IN VARCHAR2,
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   debug_msg('validating receipt number '||p_receipt_number);
   IF p_receipt_number IS NULL THEN
      append_error(p_errors_tab, 'Receipt number not supplied');
   ELSE
      p_tfm_rec.receipt_number := trim(p_receipt_number);
   END IF;
END validate_receipt_number;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_payment_method
--  PURPOSE
--      Validates payment methods.
--  DESCRIPTION
--      First searches the payment method cache to see if it has been queried before.
--      If not in the cache, the function queries the database for it
--      Payment Method is then validated:
--        1) Must exist in AR_RECEIPT_METHODS
--        2) Must be active
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_payment_method
(
   p_payment_method        IN VARCHAR2,
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_receipt_class_id      IN NUMBER,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           ar_receipt_methods%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
BEGIN
   -- first check whether the payment method was supplied
   IF p_payment_method IS NULL THEN
      append_error(p_errors_tab, 'Payment method not supplied');
      RETURN;
   END IF;
   -- look into the cache first and query the database only if it is not there
   IF NOT g_pay_method_cache.EXISTS(p_payment_method) THEN
      query_receipt_method(p_payment_method, lr_entity_rec);
      -- must exist
      IF lr_entity_rec.receipt_method_id IS NULL THEN
         append_error(lt_val_errors_tab, 'Payment method''' || p_payment_method || ''' does not exist');
      -- must be active
      ELSIF ( lr_entity_rec.start_date > SYSDATE OR
              nvl(lr_entity_rec.end_date, SYSDATE + 1) < SYSDATE 
            ) THEN 
         append_error(lt_val_errors_tab, 'Payment method ''' || p_payment_method || ''' is not active');
      -- must be associated with the provided receipt class
      ELSIF lr_entity_rec.receipt_class_id <> p_receipt_class_id THEN
         append_error(lt_val_errors_tab, 'Payment method ''' || p_payment_method || ''' is not associated' ||
            ' with receipt class id ' || p_receipt_class_id);
      END IF;
      -- insert new entry into cache
      g_pay_method_cache(p_payment_method).ar_receipt_methods_rec := lr_entity_rec;
      g_pay_method_cache(p_payment_method).val_errors := lt_val_errors_tab;
   END IF;
   -- set the output params to the cached values
   p_tfm_rec.receipt_method_id := g_pay_method_cache(p_payment_method).ar_receipt_methods_rec.receipt_method_id;
   -- if a context sensitive descriptive flexfield exists for this receipt method, then populate attribute_category
   IF g_receipt_info_cache.EXISTS(p_tfm_rec.receipt_method_id) THEN
      p_tfm_rec.attribute_category := TO_CHAR(g_pay_method_cache(p_payment_method).ar_receipt_methods_rec.receipt_method_id);
   END IF;
   append_error_tab(p_errors_tab, g_pay_method_cache(p_payment_method).val_errors);
END validate_payment_method;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_pay_method_code
--  PURPOSE
--      Validates payment method codes for Recall files.
--  DESCRIPTION
--      Payment method code is mapped to an Oracle payment method
--      Payment Method is then validated:
--        1) Must exist in AR_RECEIPT_METHODS
--        2) Must be active
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_pay_method_code
(
   p_pay_method_code       IN VARCHAR2,
   p_trans_type            IN VARCHAR2,
   p_receipt_class_id      IN NUMBER,
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   lr_entity_rec           ar_receipt_methods%ROWTYPE;
   lt_val_errors_tab       t_validation_errors_type := t_validation_errors_type();
   l_payment_method        ar_receipt_methods.name%TYPE;
   l_idx                   VARCHAR2(30); -- index for cache
   lr_fnd_lookup_rec       fnd_lookup_values%ROWTYPE;
BEGIN
   -- first check whether the payment method code was supplied
   IF p_pay_method_code IS NULL THEN
      append_error(p_errors_tab, 'Payment method code not supplied');
      RETURN;
   END IF;
   -- look into the cache first and query the database only if it is not there
   l_idx := p_pay_method_code || p_trans_type;
   IF NOT g_recall_pay_method_cache.EXISTS(l_idx) THEN
      -- lookup payment method code
      query_recall_pay_method_code(p_pay_method_code, p_trans_type, lr_fnd_lookup_rec);
      IF lr_fnd_lookup_rec.lookup_code IS NOT NULL THEN
         debug_msg('fetched recall payment method ' || l_idx || ' in lookup');
         -- insert new entry into cache
         g_recall_pay_method_cache(l_idx) := lr_fnd_lookup_rec;
         l_payment_method := lr_fnd_lookup_rec.meaning;
      ELSE
         append_error(lt_val_errors_tab, 'Payment method code ''' || l_idx || ''' does not exist');
         RETURN;
      END IF;
   ELSE
      debug_msg('found recall payment method ' || l_idx || ' in cache');
      l_payment_method := g_recall_pay_method_cache(l_idx).meaning;
   END IF;
   validate_payment_method(l_payment_method, p_tfm_rec, p_receipt_class_id, p_errors_tab);
END validate_pay_method_code;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_receipt_type
--  PURPOSE
--      Validates receipt types.
--  DESCRIPTION
--      Receipt Type must be either Standard or Miscellaneous
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_receipt_type
(
   p_stg_rec               IN OUT NOCOPY xxar_receipts_interface_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_stg_rec.receipt_type IS NULL THEN
      append_error(p_errors_tab, 'Receipt Type not supplied');
   ELSIF p_stg_rec.receipt_type NOT IN ('Standard', 'Miscellaneous') THEN
      append_error(p_errors_tab, 'Receipt Type ' || p_stg_rec.receipt_type || ' is not valid');
   ELSIF p_stg_rec.receipt_type = 'Standard' AND nvl(p_tfm_rec.payment_notice_flag, 'N') = 'Y' THEN
      append_error(p_errors_tab, 'Invalid receipt type. CRN is associated with a Payment Notice');
   ELSIF p_stg_rec.receipt_type = 'Miscellaneous' AND p_tfm_rec.trx_receivables_ccid IS NOT NULL THEN
      append_error(p_errors_tab, 'Invalid receipt type. CRN is associated with an Invoice');
   ELSE
      p_tfm_rec.receipt_type := p_stg_rec.receipt_type;
   END IF;
END validate_receipt_type;

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
--      submit_xxarrecintack
--  PURPOSE
--       Submits the interface acknowledgement report XXARRECINTACK (DEDJTR AR Receipts Inbound Interface Report)
--  RETURNS
--       Concurrent Request Id of the submitted request
-- --------------------------------------------------------------------------------------------------
FUNCTION submit_xxarrecintack
(
   p_source             IN VARCHAR2,
   p_run_id             IN NUMBER
) RETURN NUMBER
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_request_id        NUMBER;
BEGIN
   l_request_id := fnd_request.submit_request
      ( application => 'ARC',
        program     => 'XXARRECINTACK',
        description => NULL,
        start_time  => NULL,
        sub_request => FALSE,
        argument1   => p_source, -- Source
        argument2   => NULL,     -- File Name
        argument3   => NULL,     -- Receipt Date From
        argument4   => NULL,     -- Receipt Date To
        argument5   => NULL,     -- Payment Method
        argument6   => p_run_id );  -- Run Id
   COMMIT;
   RETURN l_request_id;
END submit_xxarrecintack;

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
--      log_receipt_info_cache
--  PURPOSE
--      Outputs the Receipt Info DFF cache to the concurrent log file.
--  DESCRIPTION
--      Purely just a helper for the developer to use if debugging
-- --------------------------------------------------------------------------------------------------
PROCEDURE log_receipt_info_cache
IS
   l_idx          VARCHAR2(30);
   l_idx2         VARCHAR2(30);
BEGIN
   debug_msg('Receipt Info Descriptive Flexfield Cache');
   l_idx := g_receipt_info_cache.FIRST;
   WHILE (l_idx IS NOT NULL)
   LOOP
      debug_msg('Context: ' || l_idx);
      debug_msg('   Column    |E|D|R'); -- (E)nabled|(D)isplayed|(R)equired
      l_idx2 := g_receipt_info_cache(l_idx).FIRST;
      WHILE (l_idx2 IS NOT NULL)
      LOOP
         debug_msg('   '|| g_receipt_info_cache(l_idx)(l_idx2).application_column_name || '|' || 
            g_receipt_info_cache(l_idx)(l_idx2).enabled_flag || '|' || 
            g_receipt_info_cache(l_idx)(l_idx2).display_flag || '|' || 
            g_receipt_info_cache(l_idx)(l_idx2).required_flag
         );
         l_idx2 := g_receipt_info_cache(l_idx).NEXT(l_idx2);
      END LOOP;
      l_idx := g_receipt_info_cache.NEXT(l_idx);
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      debug_msg(SQLERRM);
END log_receipt_info_cache;

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
   p_flexfield_name        IN VARCHAR2
) IS
   TYPE lt_dff_col_usage_tab_type IS TABLE OF fnd_descr_flex_column_usages%ROWTYPE INDEX BY BINARY_INTEGER;
   lr_dff_col_usage_tab    lt_dff_col_usage_tab_type;
BEGIN
   SELECT * BULK COLLECT
   INTO   lr_dff_col_usage_tab
   FROM   fnd_descr_flex_column_usages
   WHERE  application_id = p_flex_appl_id
   AND    descriptive_flexfield_name = p_flexfield_name
   AND    enabled_flag = 'Y'
   ORDER BY column_seq_num;
   --
   IF lr_dff_col_usage_tab.COUNT > 0 THEN
      FOR i IN lr_dff_col_usage_tab.FIRST..lr_dff_col_usage_tab.LAST
      LOOP
         g_receipt_info_cache(lr_dff_col_usage_tab(i).descriptive_flex_context_code)(lr_dff_col_usage_tab(i).application_column_name) := lr_dff_col_usage_tab(i);
      END LOOP;
   END IF;
END initialise_dff_cache;

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
         'AR',
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
--      update_tfm_statuses
--  PURPOSE
--      Updates the transform tables with status based on the existence of errors
-- --------------------------------------------------------------------------------------------------
PROCEDURE update_tfm_statuses
(
   p_run_id              IN   NUMBER,
   p_run_phase_id        IN   NUMBER,
   p_status              IN   VARCHAR2
) IS
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   UPDATE xxar_receipts_interface_tfm
   SET status = p_status,
       run_phase_id = p_run_phase_id
   WHERE run_id = p_run_id
   AND record_id IN 
      ( SELECT record_id 
        FROM dot_int_run_phase_errors 
        WHERE run_id = p_run_id 
        AND run_phase_id = p_run_phase_id );
   debug_msg('updated ' || SQL%ROWCOUNT || ' transform rows to ' || p_status || ' status');
   COMMIT;
END update_tfm_statuses;

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
   l_stg_table          VARCHAR2(30);
BEGIN
   IF g_source = 'RECALL' THEN
      UPDATE xxar_recall_interface_hdr_stg
      SET    run_id = p_run_id,
             run_phase_id = p_run_phase_id,
             status = p_status,
             created_by = l_user_id
      WHERE  run_id || run_phase_id IS NULL;
      --
      UPDATE xxar_recall_interface_stg
      SET    run_id = p_run_id,
             run_phase_id = p_run_phase_id,
             status = p_status,
             created_by = l_user_id
      WHERE  run_id || run_phase_id IS NULL;
   ELSE
      UPDATE xxar_receipts_interface_stg
      SET    run_id = p_run_id,
             run_phase_id = p_run_phase_id,
             status = p_status,
             created_by = l_user_id
      WHERE  run_id || run_phase_id IS NULL;
   END IF;
   p_row_count := SQL%ROWCOUNT;
END update_stage_run_ids;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      apply_receipt_wrapper
--  PURPOSE
--      Wrapper for the standard receipt application API
--  DESCRIPTION
--       Returns API error (if raised) in P_API_MSG 
-- --------------------------------------------------------------------------------------------------
PROCEDURE apply_receipt_wrapper
(
   p_tfm_rec             IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_apply_on_account    IN BOOLEAN,
   p_api_msg             OUT VARCHAR2
) IS
    l_return_status        VARCHAR2(10);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(300);
    l_apply_amount         NUMBER := 0;
    l_onaccount_amount     NUMBER := 0;
    l_rec_amt_remaining    NUMBER;
BEGIN
   debug_msg('Receipt Amount ' || p_tfm_rec.receipt_amount);
   debug_msg('Amount already applied ' || g_receipt_cache(p_tfm_rec.receipt_number).total_amt_applied);
   l_rec_amt_remaining := p_tfm_rec.receipt_amount - g_receipt_cache(p_tfm_rec.receipt_number).total_amt_applied;
   --
   -- Determine the amounts to apply to the transaction and to on-account
   --
   IF p_tfm_rec.customer_trx_id IS NOT NULL THEN
      debug_msg('Invoice id ' || p_tfm_rec.customer_trx_id || ', amount remaining ' || g_trx_balance_cache(p_tfm_rec.customer_trx_id));
      IF g_trx_balance_cache(p_tfm_rec.customer_trx_id) > 0 THEN
         IF l_rec_amt_remaining <= g_trx_balance_cache(p_tfm_rec.customer_trx_id) THEN
            l_apply_amount := l_rec_amt_remaining;
            l_onaccount_amount := 0;
         ELSE
            l_apply_amount := g_trx_balance_cache(p_tfm_rec.customer_trx_id);
            -- only apply the remainder if told to
            IF p_apply_on_account THEN
               l_onaccount_amount := l_rec_amt_remaining - l_apply_amount;
            ELSE
               debug_msg('Will not be applying remainder on account');
               l_onaccount_amount := 0;
            END IF;
         END IF;
      END IF;
   ELSIF p_tfm_rec.customer_site_use_id IS NOT NULL THEN
      l_apply_amount := 0;
      l_onaccount_amount := l_rec_amt_remaining;
   END IF;
   --
   -- Apply an amount to a transaction
   --
   IF l_apply_amount > 0 THEN
      debug_msg('Applying ' || to_char(l_apply_amount) || ' to customer_trx_id ' || p_tfm_rec.customer_trx_id);
      ar_receipt_api_pub.apply(
         p_api_version             => 1.0,
         p_init_msg_list           => FND_API.G_TRUE,
         p_commit                  => FND_API.G_FALSE,
         p_validation_level        => FND_API.G_VALID_LEVEL_FULL,
         x_return_status           => l_return_status,
         x_msg_count               => l_msg_count,
         x_msg_data                => l_msg_data,
         p_cash_receipt_id         => p_tfm_rec.cash_receipt_id,
         p_customer_trx_id         => p_tfm_rec.customer_trx_id,
         p_amount_applied          => l_apply_amount,
         p_apply_date              => SYSDATE,
         p_apply_gl_date           => g_gl_date
      );
      IF l_return_status = 'S' THEN
         -- reduce the outstanding balance of this transaction in the transaction balance cache 
         g_trx_balance_cache(p_tfm_rec.customer_trx_id) := 
            g_trx_balance_cache(p_tfm_rec.customer_trx_id) - l_apply_amount;
         -- maintain the running total of amount applied to this receipt
         g_receipt_cache(p_tfm_rec.receipt_number).total_amt_applied := 
            g_receipt_cache(p_tfm_rec.receipt_number).total_amt_applied + l_apply_amount;
      END IF;
      debug_msg('API:');
      debug_msg('x_return_status = ' || l_return_status);
      debug_msg('x_msg_count = ' || l_msg_count);
      debug_msg('x_msg_data = ' || l_msg_data);
      p_api_msg := l_msg_data;
      IF l_msg_count > 0 THEN
         FOR i IN 1..l_msg_count
         LOOP
            IF i > 1 THEN
               p_api_msg := p_api_msg || ' - ';
            END IF;
            p_api_msg := p_api_msg || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),1,255);
         END LOOP;
      END IF;
   END IF;
   --
   -- Apply an amount on account
   --
   IF l_onaccount_amount > 0 THEN
      debug_msg('Applying ' || to_char(l_onaccount_amount) || ' on account');
      ar_receipt_api_pub.apply_on_account(
         p_api_version             => 1.0,
         p_init_msg_list           => FND_API.G_TRUE,
         p_commit                  => FND_API.G_FALSE,
         p_validation_level        => FND_API.G_VALID_LEVEL_FULL,
         x_return_status           => l_return_status,
         x_msg_count               => l_msg_count,
         x_msg_data                => l_msg_data,
         p_cash_receipt_id         => p_tfm_rec.cash_receipt_id,
         p_amount_applied          => l_onaccount_amount,
         p_apply_date              => SYSDATE,
         p_apply_gl_date           => g_gl_date
      );
      IF l_return_status = 'S' THEN
         -- maintain the running total of amount applied to this receipt
         g_receipt_cache(p_tfm_rec.receipt_number).total_amt_applied := 
            g_receipt_cache(p_tfm_rec.receipt_number).total_amt_applied + l_onaccount_amount;
      END IF;
      debug_msg('API:');
      debug_msg('x_return_status = ' || l_return_status);
      debug_msg('x_msg_count = ' || l_msg_count);
      debug_msg('x_msg_data = ' || l_msg_data);
      p_api_msg := l_msg_data;
      IF l_msg_count > 0 THEN
         FOR i IN 1..l_msg_count
         LOOP
            IF i > 1 THEN
               p_api_msg := p_api_msg || ' - ';
            END IF;
            p_api_msg := p_api_msg || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),1,255);
         END LOOP;
      END IF;
   END IF;

END apply_receipt_wrapper; 

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      create_receipt_wrapper
--  PURPOSE
--      Wrapper for the standard receipt creation APIs
--  DESCRIPTION
--       Returns API error (if raised) in P_API_MSG 
-- --------------------------------------------------------------------------------------------------
PROCEDURE create_receipt_wrapper
(
   p_tfm_rec             IN OUT NOCOPY xxar_receipts_interface_tfm%ROWTYPE,
   p_api_msg             OUT VARCHAR2
) IS
    l_cr_id                NUMBER;
    l_attribute_rec_type   ar_receipt_api_pub.attribute_rec_type;
    l_return_status        VARCHAR2(10);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(300);
BEGIN
   -- Descriptive Flexfields
   l_attribute_rec_type.attribute_category := p_tfm_rec.attribute_category;
   l_attribute_rec_type.attribute1 := p_tfm_rec.attribute1;
   l_attribute_rec_type.attribute2 := p_tfm_rec.attribute2;
   l_attribute_rec_type.attribute3 := p_tfm_rec.attribute3;
   l_attribute_rec_type.attribute4 := p_tfm_rec.attribute4;
   l_attribute_rec_type.attribute5 := p_tfm_rec.attribute5;
   l_attribute_rec_type.attribute6 := p_tfm_rec.attribute6;
   l_attribute_rec_type.attribute7 := p_tfm_rec.attribute7;
   l_attribute_rec_type.attribute8 := p_tfm_rec.attribute8;
   l_attribute_rec_type.attribute9 := p_tfm_rec.attribute9;
   l_attribute_rec_type.attribute10 := p_tfm_rec.attribute10;
   l_attribute_rec_type.attribute11 := p_tfm_rec.attribute11;
   l_attribute_rec_type.attribute12 := p_tfm_rec.attribute12;
   l_attribute_rec_type.attribute13 := p_tfm_rec.attribute13;
   l_attribute_rec_type.attribute14 := p_tfm_rec.attribute14;
   l_attribute_rec_type.attribute15 := p_tfm_rec.attribute15;
   
   /* Debugging */
   /*
   debug_msg('p_tfm_rec.receipt_type='||p_tfm_rec.receipt_type);
   debug_msg('p_tfm_rec.currency_code='||p_tfm_rec.currency_code);
   debug_msg('p_tfm_rec.receipt_amount='||p_tfm_rec.receipt_amount);
   debug_msg('p_tfm_rec.remit_bank_account_id='||p_tfm_rec.remit_bank_account_id);
   debug_msg('p_tfm_rec.receipt_number='||p_tfm_rec.receipt_number);
   debug_msg('p_tfm_rec.receipt_date='||p_tfm_rec.receipt_date);
   debug_msg('p_tfm_rec.gl_date='||p_tfm_rec.gl_date);
   debug_msg('p_tfm_rec.receivables_trx_id='||p_tfm_rec.receivables_trx_id);
   debug_msg('p_tfm_rec.misc_payment_source='||p_tfm_rec.misc_payment_source);
   debug_msg('p_tfm_rec.customer_id='||p_tfm_rec.customer_id);
   debug_msg('p_tfm_rec.customer_site_use_id='||p_tfm_rec.customer_site_use_id);
   debug_msg('p_tfm_rec.receipt_method_id='||p_tfm_rec.receipt_method_id);
   debug_msg('p_tfm_rec.comments='||p_tfm_rec.comments);
   */

   IF p_tfm_rec.receipt_type = 'Standard' THEN
      debug_msg('calling ar_receipt_api_pub.create_cash');
      ar_receipt_api_pub.create_cash(
         p_api_version                 => 1.0,
         p_init_msg_list               => FND_API.G_TRUE,
         p_commit                      => FND_API.G_FALSE,
         p_validation_level            => FND_API.G_VALID_LEVEL_FULL,
         x_return_status               => l_return_status,
         x_msg_count                   => l_msg_count,
         x_msg_data                    => l_msg_data,
         p_currency_code               => p_tfm_rec.currency_code,
         p_amount                      => p_tfm_rec.receipt_amount,
         p_remittance_bank_account_id  => p_tfm_rec.remit_bank_account_id,
         p_receipt_number              => p_tfm_rec.receipt_number,
         p_receipt_date                => p_tfm_rec.receipt_date,
         p_gl_date                     => p_tfm_rec.gl_date,
         p_customer_id                 => p_tfm_rec.customer_id,
         p_customer_site_use_id        => p_tfm_rec.customer_site_use_id,
         p_receipt_method_id           => p_tfm_rec.receipt_method_id,
         p_attribute_rec               => l_attribute_rec_type,
         p_comments                    => p_tfm_rec.comments,
         p_cr_id                       => l_cr_id
      );

   ELSIF p_tfm_rec.receipt_type = 'Miscellaneous' THEN
      debug_msg('calling ar_receipt_api_pub.create_misc');
      ar_receipt_api_pub.create_misc(
         p_api_version                 => 1.0,
         p_init_msg_list               => FND_API.G_TRUE,
         p_commit                      => FND_API.G_FALSE,
         p_validation_level            => FND_API.G_VALID_LEVEL_FULL,
         x_return_status               => l_return_status,
         x_msg_count                   => l_msg_count,
         x_msg_data                    => l_msg_data,
         p_currency_code               => p_tfm_rec.currency_code,
         p_amount                      => p_tfm_rec.receipt_amount,
         p_receipt_number              => p_tfm_rec.receipt_number,
         p_receipt_date                => p_tfm_rec.receipt_date,
         p_gl_date                     => p_tfm_rec.gl_date,
         p_receivables_trx_id          => p_tfm_rec.receivables_trx_id,
         p_misc_payment_source         => p_tfm_rec.misc_payment_source,
         p_remittance_bank_account_id  => p_tfm_rec.remit_bank_account_id,
         p_receipt_method_id           => p_tfm_rec.receipt_method_id,
         p_attribute_record            => l_attribute_rec_type,
         p_comments                    => p_tfm_rec.comments,
         p_misc_receipt_id             => l_cr_id
      ); 
   END IF;

   debug_msg('API: l_cr_id = ' || l_cr_id);
   debug_msg('x_return_status = ' || l_return_status);
   debug_msg('x_msg_count = ' || l_msg_count);
   debug_msg('x_msg_data = ' || l_msg_data);
   p_api_msg := l_msg_data;
   p_tfm_rec.cash_receipt_id := l_cr_id;
   
   IF l_msg_count > 0 THEN
      FOR i IN 1..l_msg_count
      LOOP
         IF i > 1 THEN
            p_api_msg := p_api_msg || ' - ';
         END IF;
         p_api_msg := p_api_msg || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),1,255);
      END LOOP;
   END IF;
END create_receipt_wrapper;

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
--      transform_recall
--  PURPOSE
--       Transforms RECALL data from Staging tables to the Transform table.
--  DESCRIPTION
--       Updates the Stage row status to PROCESSED or ERROR as it goes
--  RETURNS
--       True if successful, otherwise False
-- --------------------------------------------------------------------------------------------------
FUNCTION transform_recall
(
   p_run_id        IN   NUMBER,
   p_run_phase_id  OUT  NUMBER,
   p_file_name     IN   VARCHAR2,
   p_int_mode      IN   VARCHAR2
) RETURN BOOLEAN
IS
   CURSOR c_stg(p_run_id IN NUMBER) IS
      SELECT s.*, h.processing_date
      FROM   xxar_recall_interface_stg s,
             xxar_recall_interface_hdr_stg h 
      WHERE  s.run_id = p_run_id
      AND    h.run_id = s.run_id  
      FOR UPDATE OF s.status;

   r_stg                   c_stg%ROWTYPE;
   r_tfm                   xxar_receipts_interface_tfm%ROWTYPE;
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
        p_int_table_name          => 'XXAR_RECALL_INTERFACE_STG',
        p_int_table_key_col1      => 'RECEIPT_NUMBER_1',
        p_int_table_key_col_desc1 => 'Receipt Number',
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
   FROM   xxar_recall_interface_stg
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
      r_error.int_table_key_val1 := r_stg.receipt_number_1;

      /***********************************/
      /* Validation and Mapping          */
      /***********************************/
      validate_processing_date(r_stg.processing_date, r_tfm, l_val_errors_tab);
      validate_receipt_amount(r_stg.receipt_amount, r_tfm, l_val_errors_tab);
      validate_crn(r_stg.crn, r_tfm, l_val_errors_tab);
      validate_pay_method_code(r_stg.payment_method_code, r_stg.trans_type, g_receipt_class_id, r_tfm, l_val_errors_tab);
      map_bank_account(r_tfm, l_val_errors_tab);
      -- Receipt number depends on the payment method
      IF r_stg.payment_method_code = 'JB' THEN
         validate_receipt_number(r_stg.receipt_number_1, g_source, r_tfm, l_val_errors_tab);
      ELSE
         validate_receipt_number(r_stg.receipt_number_2, g_source, r_tfm, l_val_errors_tab);
      END IF;
      -- DFFs
      r_tfm.ATTRIBUTE7 := p_file_name;
      r_tfm.ATTRIBUTE8 := r_stg.voucher;
      validate_dff_segments(r_tfm, l_val_errors_tab);

      -- get the next record_id
      SELECT xxar_receipts_record_id_s.NEXTVAL
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
      -- interface columns
      r_tfm.SOURCE := r_stg.source;
      -- receipt api fields
      r_tfm.RECEIPT_TYPE := nvl(r_tfm.RECEIPT_TYPE, 'Standard'); -- receipt type may have ben set by validate_crn()
      r_tfm.CURRENCY_CODE := g_sob_currency;
      r_tfm.GL_DATE := g_gl_date;
      
      /*************************************/
      /* Insert single row into TFM table  */
      /*************************************/
      BEGIN
         INSERT INTO xxar_receipts_interface_tfm VALUES r_tfm;
      EXCEPTION
         WHEN OTHERS THEN
            r_error.record_id := r_stg.record_id;
            r_error.msg_code := SQLCODE;
            r_error.error_text := SQLERRM;
            raise_error(r_error);
            -- Update the stage table row with error status
            UPDATE xxar_receipts_interface_stg SET status = 'ERROR' WHERE CURRENT OF c_stg;
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
END transform_recall;

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
      FROM   xxar_receipts_interface_stg
      WHERE  run_id = p_run_id
      FOR UPDATE OF status;

   r_stg                   c_stg%ROWTYPE;
   r_tfm                   xxar_receipts_interface_tfm%ROWTYPE;
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
        p_int_table_name          => 'XXAR_RECEIPTS_INTERFACE_STG',
        p_int_table_key_col1      => 'RECEIPT_NUMBER',
        p_int_table_key_col_desc1 => 'Receipt Number',
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
   FROM   xxar_receipts_interface_stg
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
      r_error.int_table_key_val1 := r_stg.receipt_number;

      /***********************************/
      /* Validation and Mapping          */
      /***********************************/
      validate_payment_method(r_stg.payment_method, r_tfm, g_receipt_class_id, l_val_errors_tab);
      validate_receipt_number(r_stg.receipt_number, g_source, r_tfm, l_val_errors_tab);
      validate_receipt_amount(r_stg.receipt_amount, r_tfm, l_val_errors_tab);
      validate_receipt_date(r_stg, r_tfm, l_val_errors_tab);
      validate_payer_name(r_stg, r_tfm, l_val_errors_tab);
      validate_invoice_number(r_stg, r_tfm, l_val_errors_tab);
      /*
      -- Validate CRN
      -- This procedure depends on the prior execution of the following validations
      --    1) validate_invoice_number
      */
      validate_crn(r_stg.crn, r_tfm, l_val_errors_tab);
      /*
      -- Validate receipt type
      -- This procedure depends on the prior execution of the following validations
      --    1) validate_crn
      --    2) validate_invoice_number
      */
      validate_receipt_type(r_stg, r_tfm, l_val_errors_tab);
      /*
      -- Validate receivable activity
      -- This procedure depends on the prior execution of the following validations
      --    1) validate_receipt_type
      */
      IF ( r_tfm.trx_receivables_ccid IS NULL AND 
           r_tfm.payment_notice_flag = 'N' AND
           r_tfm.receipt_type = 'Standard' )
      THEN
         -- If CRN was not found as an invoice or payment notice, override this receipt,
         -- making it Miscellaneous with an activity of Unidentified Receipts
         r_tfm.receipt_type := 'Miscellaneous';
         validate_receivable_activity('Unidentified Receipts', r_tfm, l_val_errors_tab);
      ELSE
         validate_receivable_activity(r_stg.receivable_activity, r_tfm, l_val_errors_tab);
      END IF;
      /*
      -- Map the bank account 
      -- This procedure depends on the prior execution of the following validations
      --    1) validate_crn
      --    2) validate_invoice_number
      --    3) validate_payment_method
      */
      map_bank_account(r_tfm, l_val_errors_tab);

      /*
      -- Flexfields
      */
      r_tfm.ATTRIBUTE7 := p_file_name;
      IF r_stg.payment_method = 'CHEQUE' THEN
         r_tfm.ATTRIBUTE1 := r_stg.cheque_number;
         r_tfm.ATTRIBUTE2 := r_stg.cheque_date;
         r_tfm.ATTRIBUTE3 := r_stg.drawer_name;
         r_tfm.ATTRIBUTE4 := r_stg.bsb_number;
         r_tfm.ATTRIBUTE5 := r_stg.bank_name;
      ELSIF r_stg.payment_method = 'CASH' THEN
         r_tfm.ATTRIBUTE1 := r_stg.cash_ref;
      ELSIF r_stg.payment_method = 'CHEQUE' THEN
         r_tfm.ATTRIBUTE1 := r_stg.cheque_number;
      ELSIF r_stg.payment_method = 'CREDITCARD' THEN
         r_tfm.ATTRIBUTE1 := r_stg.credit_card_ref;
      ELSIF r_stg.payment_method = 'Electronic' THEN
         r_tfm.ATTRIBUTE1 := r_stg.eft_ref;
      ELSIF r_stg.payment_method = 'BPAY' THEN
         r_tfm.ATTRIBUTE1 := r_stg.bpay_ref;
      ELSIF r_stg.payment_method = 'AUSPOST' THEN
         r_tfm.ATTRIBUTE1 := r_stg.auspost_ref;
      ELSIF r_stg.payment_method = 'WEB' THEN
         r_tfm.ATTRIBUTE1 := r_stg.quickweb_ref;
      ELSIF r_stg.payment_method = 'DIRECT DEBIT' THEN
         r_tfm.ATTRIBUTE1 := r_stg.direct_debit_ref;
      ELSIF r_stg.payment_method = 'IVR' THEN
         r_tfm.ATTRIBUTE1 := r_stg.ivr_ref;
      END IF;
      -- Now validate DFF values
      validate_dff_segments(r_tfm, l_val_errors_tab);
      
      -- get the next record_id
      SELECT xxar_receipts_record_id_s.NEXTVAL
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
      -- interface columns
      r_tfm.SOURCE := r_stg.source;
      -- receipt api fields
      r_tfm.CURRENCY_CODE := g_sob_currency;
      r_tfm.COMMENTS := r_stg.receipt_comment;
      r_tfm.GL_DATE := g_gl_date;
      
      /*************************************/
      /* Insert single row into TFM table  */
      /*************************************/
      BEGIN
         INSERT INTO xxar_receipts_interface_tfm VALUES r_tfm;
      EXCEPTION
         WHEN OTHERS THEN
            r_error.record_id := r_stg.record_id;
            r_error.msg_code := SQLCODE;
            r_error.error_text := SQLERRM;
            raise_error(r_error);
            -- Update the stage table row with error status
            UPDATE xxar_receipts_interface_stg SET status = 'ERROR' WHERE CURRENT OF c_stg;
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
--       Loads data from the Transform table to the Receipts API.
--  DESCRIPTION
--       Updates the Transform row status to PROCESSED or ERROR as it goes
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
      FROM   xxar_receipts_interface_tfm
      WHERE  run_id = p_run_id
      ORDER  BY record_id
      FOR UPDATE OF status;

   CURSOR c_maxrec IS
      SELECT receipt_number, 
             MAX(record_id) as max_record_id,
             COUNT(record_id) as line_count
      FROM   xxar_receipts_interface_tfm
      WHERE  run_id = p_run_id
--      AND    customer_trx_id IS NOT NULL
      GROUP  BY receipt_number;

   r_tfm                   xxar_receipts_interface_tfm%ROWTYPE;
   l_run_id                NUMBER := p_run_id;
   l_run_phase_id          NUMBER;
   l_total                 NUMBER := 0;
   l_error_count           NUMBER := 0;
   l_tfm_count             NUMBER := 0;
   l_load_count            NUMBER := 0;
   r_error                 dot_int_run_phase_errors%ROWTYPE;
   l_overall_status        VARCHAR2(240) := 'SUCCESS';
   l_api_msg               dot_int_run_phase_errors.error_text%TYPE;
   b_apply_remainder_on_account  BOOLEAN := TRUE;
BEGIN
   /*******************************/
   /* Initialise Load Phase       */
   /*******************************/
   l_run_phase_id := dot_common_int_pkg.start_run_phase
      ( p_run_id                  => l_run_id,
        p_phase_code              => 'LOAD',
        p_phase_mode              => NULL,
        p_int_table_name          => 'XXAR_RECEIPTS_INTERFACE_TFM',
        p_int_table_key_col1      => 'RECEIPT_NUMBER',
        p_int_table_key_col_desc1 => 'Receipt Number',
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
   FROM   xxar_receipts_interface_tfm
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

   -- Determine the last record_id for each receipt number.
   -- Application on account will only occur when all receipt lines have been applied.
   -- This is used to process multiple invoices per receipt number
   -- Using the max(record_id) is a convenient way to determine when the last instance of a receipt is reached
   FOR r_maxrec IN c_maxrec
   LOOP
      debug_msg('c_maxrec['||c_maxrec%rowcount||']');
      g_receipt_cache(r_maxrec.receipt_number).max_record_id := r_maxrec.max_record_id;
      g_receipt_cache(r_maxrec.receipt_number).total_amt_applied := 0;
      debug_msg('receipt ' || r_maxrec.receipt_number || ' appears ' || r_maxrec.line_count || ' times in the file');
   END LOOP;

   -- Now process each receipt in turn
   OPEN c_tfm;
   LOOP
      FETCH c_tfm INTO r_tfm;
      debug_msg('c_tfm['||c_tfm%rowcount||']');
      EXIT WHEN c_tfm%NOTFOUND;
      l_tfm_count := l_tfm_count + 1;
      r_error.record_id := r_tfm.record_id;
      r_error.int_table_key_val1 := r_tfm.receipt_number;
      BEGIN
         /*******************************/
         /* Call Create Receipt         */
         /*******************************/
         IF g_receipt_cache(r_tfm.receipt_number).cash_receipt_id IS NULL THEN
            debug_msg('Creating receipt for ' || r_tfm.receipt_number);
            create_receipt_wrapper(r_tfm, l_api_msg);
            IF l_api_msg IS NOT NULL THEN
               r_error.error_text := l_api_msg;
               raise_error(r_error);
               l_error_count := l_error_count + 1;
               l_overall_status := 'ERROR';
               CONTINUE;
            ELSE
               -- Store the new cash_receipt_id in the cash receipt cache
               g_receipt_cache(r_tfm.receipt_number).cash_receipt_id := r_tfm.cash_receipt_id;
            END IF;
         ELSE
            debug_msg('Receipt ' || r_tfm.receipt_number || ' already created - reusing');
            r_tfm.cash_receipt_id := g_receipt_cache(r_tfm.receipt_number).cash_receipt_id;
         END IF;
         --
         -- If the customer site is known, then apply the receipt - either to a transaction
         -- or on account
         IF r_tfm.receipt_type = 'Standard' AND r_tfm.customer_site_use_id IS NOT NULL THEN
            IF r_tfm.record_id < g_receipt_cache(r_tfm.receipt_number).max_record_id
            THEN
               b_apply_remainder_on_account := FALSE;
            ELSE
               b_apply_remainder_on_account := TRUE;
            END IF;
            /*******************************/
            /* Call Apply Receipt          */
            /*******************************/
            apply_receipt_wrapper(r_tfm, b_apply_remainder_on_account, l_api_msg);

            IF l_api_msg IS NOT NULL THEN
               r_error.error_text := l_api_msg;
               raise_error(r_error);
               l_error_count := l_error_count + 1;
               l_overall_status := 'ERROR';
            ELSE
               l_load_count := l_load_count + 1;
               UPDATE xxar_receipts_interface_tfm 
               SET status = 'SUCCESS'
               WHERE CURRENT OF c_tfm;
            END IF;
         ELSE
            -- receipt remains unidentified
            l_load_count := l_load_count + 1;
            UPDATE xxar_receipts_interface_tfm 
            SET status = 'SUCCESS'
            WHERE CURRENT OF c_tfm;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            r_error.msg_code := SQLCODE;
            r_error.error_text := SQLERRM;
            raise_error(r_error);
            log_msg(r_error.error_text);
            l_error_count := l_error_count + 1;
            l_overall_status := 'ERROR';
      END;
   END LOOP;

   debug_msg('created ' || l_load_count || ' receipts using API');
   debug_msg('updated ' || l_error_count || ' transform rows to error status');

   /*******************/
   /* End run phase   */
   /*******************/
   dot_common_int_pkg.end_run_phase
      ( p_run_phase_id  => l_run_phase_id,
        p_status        => l_overall_status,
        p_error_count   => l_error_count,
        p_success_count => l_load_count);

   IF l_overall_status = 'ERROR' THEN
      RETURN FALSE;
   END IF;
   RETURN TRUE;
   
END load;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      process_receipts
--  PURPOSE
--       Concurrent Program XXAR_RECEIPTS_INT (DEDJTR Receipts Inbound Interface)
--  DESCRIPTION
--       Main program controller
-- --------------------------------------------------------------------------------------------------
PROCEDURE process_receipts
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_source            IN  VARCHAR2,
   p_gl_date           IN  VARCHAR2,
   p_receipt_class_id  IN  VARCHAR2,
   p_file_name         IN  VARCHAR2,
   p_control_file      IN  VARCHAR2,
   p_debug_flag        IN  VARCHAR2,
   p_int_mode          IN  VARCHAR2,
   p_purge_retention   IN  NUMBER DEFAULT NULL
) IS
   z_procedure_name           CONSTANT VARCHAR2(150) := 'xxar_receipt_interface_pkg.process_receipts';
   z_app                      CONSTANT VARCHAR2(2) :=  'AR';
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
   l_xxarrecintack_req_id     NUMBER;
   r_srs_xxintifr             r_srs_request_type;
   r_srs_xxarrecintack        r_srs_request_type;
   l_run_error                NUMBER := 0;
   r_request                  xxint_common_pkg.CONTROL_RECORD_TYPE;
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
   xxint_common_pkg.g_object_type := 'RECEIPTS';
   g_debug_flag := nvl(p_debug_flag, 'N');
   l_req_id := fnd_global.conc_request_id;
   l_appl_id := fnd_global.resp_appl_id;
   l_user_name := fnd_profile.value('USERNAME');
   g_sob_id := fnd_profile.value('GL_SET_OF_BKS_ID');
   g_org_id := fnd_profile.value('ORG_ID');
   g_chart_id := get_chart_of_accounts_id(g_sob_id);
   g_sob_currency := get_sob_currency(g_sob_id);
   g_source := SUBSTR(p_source, 1, 30);
   g_receipt_class_id := p_receipt_class_id;
   l_ctl := nvl(p_control_file, g_ctl);
   l_file := nvl(p_file_name, g_file);
   l_tfm_mode := nvl(p_int_mode, g_int_mode);

   debug_msg('p_gl_date='||p_gl_date);
   g_gl_date := transform_to_date(p_gl_date, 'YYYY/MM/DD HH24:MI:SS');
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

   IF l_run_error > 0 THEN
      RAISE e_interface_error;
   ELSIF t_files_tab.COUNT = 0 THEN
      RAISE e_no_files_found;
   END IF;

   /*****************************/
   /* Initialise DFF cache      */
   /*****************************/
   initialise_dff_cache(222, 'AR_CASH_RECEIPTS');
   -- Uncomment log_receipt_info_cache below if you need the DFF cache to be logged to the concurrent log
   -- log_receipt_info_cache;

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
      IF g_source = 'RECALL' THEN
         IF NOT transform_recall(l_run_id, l_run_phase_id, l_file, l_tfm_mode) THEN
            COMMIT;
            RAISE e_interface_error;
         END IF;
      ELSE
         IF NOT transform(l_run_id, l_run_phase_id, l_file, l_tfm_mode) THEN
            COMMIT;
            RAISE e_interface_error;
         END IF;
      END IF;

      COMMIT;

      /******************************************/
      /* Load                                   */
      /******************************************/
      debug_msg('interface framework (int_mode=' || l_tfm_mode || ')');
      IF l_tfm_mode = g_int_mode THEN
         IF NOT load(l_run_id, l_run_phase_id) THEN
            ROLLBACK;
            update_tfm_statuses(l_run_id, l_run_phase_id, 'ERROR');
            RAISE e_interface_error;
         END IF;
      END IF;
      
      COMMIT;

      /*********************************/
      /* Interface report              */
      /*********************************/
      l_rep_req_id := dot_common_int_pkg.launch_run_report
         ( p_run_id      => l_run_id,
           p_notify_user => l_user_name);

      debug_msg('interface framework completion report (request_id=' || l_rep_req_id || ')');
      
      /************************************************/
      /* DEDJTR AR Receipts Inbound Interface Report  */
      /************************************************/
      l_xxarrecintack_req_id := submit_xxarrecintack(g_source, l_run_id);
      debug_msg('interface acknowledgement report (request_id=' || l_xxarrecintack_req_id || ')');

      /******************************/
      /* Wait for request           */
      /******************************/
      wait_for_request(l_xxarrecintack_req_id, 5, r_srs_xxarrecintack);

      /*********************************/
      /* Copy XXARRECINTACK file       */
      /*********************************/
      l_ack_file_name := l_file || '_' || l_xxarrecintack_req_id || '.out';
      copy_conc_request_file(l_xxarrecintack_req_id, 'OUTPUT', l_outbound_directory, l_ack_file_name);

   END LOOP;
   
   /*********************************/
   /* Purge historic data           */
   /*********************************/
   IF nvl(p_purge_retention,-1) > 0 THEN
      debug_msg('Purging transformation table data older than ' || p_purge_retention || ' days');
      xxint_common_pkg.purge_interface_data('XXAR_RECEIPTS_INTERFACE_TFM', p_purge_retention);
      xxint_common_pkg.purge_interface_data('XXAR_RECEIPTS_INTERFACE_STG', p_purge_retention);
      xxint_common_pkg.purge_interface_data('XXAR_RECALL_INTERFACE_STG', p_purge_retention);
      xxint_common_pkg.purge_interface_data('XXAR_RECALL_INTERFACE_HDR_STG', p_purge_retention);
   END IF;

EXCEPTION
   WHEN e_no_files_found THEN
      p_retcode := 1;
      p_errbuff := 'No data files exist in the inbound directory';
      debug_msg(p_errbuff);

   WHEN e_interface_error THEN
      /************************************************/
      /* DEDJTR AR Receipts Inbound Interface Report  */
      /************************************************/
      l_xxarrecintack_req_id := submit_xxarrecintack(g_source, l_run_id);
      debug_msg('interface acknowledgement report (request_id=' || l_xxarrecintack_req_id || ')');

      /******************************/
      /* Wait for request           */
      /******************************/
      wait_for_request(l_xxarrecintack_req_id, 5, r_srs_xxarrecintack);

      /*********************************/
      /* Copy XXARRECINTACK file       */
      /*********************************/
      l_ack_file_name := l_file || '_' || l_xxarrecintack_req_id || '.out';
      copy_conc_request_file(l_xxarrecintack_req_id, 'OUTPUT', l_outbound_directory, l_ack_file_name);

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

   WHEN e_invalid_date THEN
      p_retcode := 2;
      p_errbuff := 'Invalid date submitted';
END process_receipts;

END xxar_receipt_interface_pkg;
/
