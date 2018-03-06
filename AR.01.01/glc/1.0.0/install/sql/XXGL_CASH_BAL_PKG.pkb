CREATE OR REPLACE PACKAGE BODY xxgl_cash_bal_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.01.01/glc/1.0.0/install/sql/XXGL_CASH_BAL_PKG.pkb 3173 2017-12-12 05:28:14Z svnuser $ */

/****************************************************************************
**
** CEMLI ID: GL.03.01
**
** Description: Cash Balancing and Authority Allocation Journals
**
** Change History:
**
** Date        Who                  Comments
** 03/05/2017  ARELLAD (RED ROCK)   Initial build.
**
** FSC-5720: The program called RUN AP to GL Post fails to correctly account for Corporate Card invoice transactions
** FSC-5823: The Journal Interface has a journal that has been successfully imported, but is still in the journal interface
** FSC-5899: There is a discrepancy in tax and creditor entry in the cash balancing journal for an AP Credit Note
** FSC-5998: The trade receipts Q entity SAU entries do not reconcile correctly - Receivables Cash Balancing Missing entries
**
****************************************************************************/

-- Types --
TYPE cursor_type IS REF CURSOR;
TYPE sources_varr IS VARRAY(2) OF VARCHAR2(150);
TYPE r_sl_line_type IS RECORD
(
   token_name      VARCHAR2(150),
   token_value     VARCHAR2(150),
   segment1        VARCHAR2(25),
   segment2        VARCHAR2(25),
   segment3        VARCHAR2(25),
   segment4        VARCHAR2(25),
   segment5        VARCHAR2(25),
   segment6        VARCHAR2(25),
   segment7        VARCHAR2(25),
   amount          NUMBER,
   calculate_tax   VARCHAR2(1)
);
TYPE t_sl_tab_type IS TABLE OF r_sl_line_type INDEX BY binary_integer;

/*
TYPE r_alloc_line_type IS RECORD
(
   je_header_id    NUMBER,
   je_line_num     NUMBER,
   rule_num        VARCHAR2(25)
);
TYPE t_alloc_tab_type IS TABLE OF r_alloc_line_type INDEX BY binary_integer;
TYPE r_stage_line_rec_type IS RECORD
(
   record_id     NUMBER,
   amount        NUMBER,
   dr_cr         VARCHAR2(15)
);
TYPE r_je_line_type IS RECORD
(
   source_je_header_id    NUMBER,
   source_je_line_num     NUMBER,
   rule_num               VARCHAR2(30),
   category               VARCHAR2(150),
   account_code           VARCHAR2(340),
   description            gl_je_lines.description%TYPE,
   entered_dr             gl_je_lines.entered_dr%TYPE,
   entered_cr             gl_je_lines.entered_cr%TYPE,
   summary_flag           VARCHAR2(1),
   reference2             VARCHAR2(240),
   reference4             VARCHAR2(240),
   reference21            VARCHAR2(240),
   reference22            VARCHAR2(240),
   reference23            VARCHAR2(240),
   reference24            VARCHAR2(240),
   reference25            VARCHAR2(240)
);

TYPE t_je_lines_type IS TABLE OF r_je_line_type INDEX BY binary_integer;
*/

-- Global --
g_user_id           NUMBER;
g_org_id            NUMBER;
g_sob_id            NUMBER;
g_coa_id            NUMBER;
g_debug_flag        VARCHAR2(1);
g_period_name       gl_je_headers.period_name%TYPE;

-- Constant --
Y                   CONSTANT VARCHAR2(1)   := 'Y';
N                   CONSTANT VARCHAR2(1)   := 'N';
z_error             VARCHAR2(15)           := 'ERROR: ';
z_debug             VARCHAR2(15)           := 'DEBUG: ';
z_wait_time         CONSTANT NUMBER        := 20;
z_actual_flag       CONSTANT VARCHAR2(1)   := 'A';
z_posted            CONSTANT VARCHAR2(1)   := 'P';
z_unposted          CONSTANT VARCHAR2(1)   := 'U';
z_any               CONSTANT VARCHAR2(1)   := '%';
z_acct_del          CONSTANT VARCHAR2(1)   := '-';
z_qs                CONSTANT VARCHAR2(5)   := '="';
z_qe                CONSTANT VARCHAR2(5)   := '",';
z_line              CONSTANT VARCHAR2(10)  := 'LINE';
z_tax               CONSTANT VARCHAR2(10)  := 'TAX';
z_revenue_acct      CONSTANT VARCHAR2(10)  := 'REV';
z_receivable_acct   CONSTANT VARCHAR2(10)  := 'REC';
z_interface_status  CONSTANT VARCHAR2(50)  := 'NEW';
z_currency_code     CONSTANT VARCHAR2(15)  := 'AUD';
z_period_type       CONSTANT VARCHAR2(25)  := 'MONTH';
z_payables_adj      CONSTANT VARCHAR2(150) := 'Payables Adjustment';
z_receivables_adj   CONSTANT VARCHAR2(150) := 'Receivables Adjustments';
z_adjustment        CONSTANT VARCHAR2(150) := 'Adjustment';
z_journal_source    CONSTANT VARCHAR2(150) := 'Cash Balancing';
z_appl              CONSTANT VARCHAR2(10)  := 'GL';
z_appl_id           CONSTANT NUMBER        := 101;
z_source            CONSTANT VARCHAR2(10)  := 'COA';
z_write             CONSTANT VARCHAR2(1)   := 'w';
z_user_tmp          CONSTANT VARCHAR2(30)  := 'USER_TMP_DIR';
z_ctl               CONSTANT VARCHAR2(150) := '$GLC_TOP/bin/XXGLCSHBAL.ctl';
z_space             CONSTANT VARCHAR2(1)   := ' ';

-- SRS --
srs_wait               BOOLEAN;
srs_phase              VARCHAR2(30);
srs_status             VARCHAR2(30);
srs_dev_phase          VARCHAR2(30);
srs_dev_status         VARCHAR2(30);
srs_message            VARCHAR2(240);

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
   IF g_debug_flag = Y THEN
      fnd_file.put_line(fnd_file.log, z_debug || p_debug_text);
   END IF;
END print_debug;

------------------------------------------------------
-- Procedure
--    PURGE_PROCESSED_DATA
-- Purpose
--    Transformation table maintenance to prevent
--    size from growing too big. Default retention
--    period is 12 months.
------------------------------------------------------

PROCEDURE purge_processed_data
IS
   l_date     DATE;
   PRAGMA     autonomous_transaction;
BEGIN
   l_date := ADD_MONTHS(TRUNC(SYSDATE), -24);

   DELETE FROM xxgl_cash_bal_tfm
   WHERE  creation_date < l_date;

   DELETE FROM xxgl_cash_bal_stg
   WHERE  creation_date < l_date;

   COMMIT;
END purge_processed_data;

-------------------------------------------------------
-- Procedure
--    SUBMIT_CASH_BALANCING
-- Purpose
--    Process to auto-submit cash balancing program.
-------------------------------------------------------

PROCEDURE submit_cash_balancing
(
   p_errbuf       OUT VARCHAR2,
   p_retcode      OUT NUMBER,
   p_source       IN  VARCHAR2,
   p_gl_date      IN  VARCHAR2,
   p_gl_period    IN  VARCHAR2
)
IS
   l_errbuff            VARCHAR2(300);
   l_retcode            NUMBER;
   l_set_of_books_id    NUMBER;
   l_effective_date     DATE;
   l_process_errored    NUMBER := 0;
   l_period_name        gl_periods.period_name%TYPE;
   l_period_open        gl_periods.period_name%TYPE;
BEGIN
   IF p_gl_date IS NULL THEN
      fnd_file.put_line(fnd_file.log, 'procedure: submit_cash_balancing');
      fnd_file.put_line(fnd_file.log, z_error || 'parameter p_gl_date must not be null');
      RETURN;
   ELSE
      l_effective_date := TO_DATE(p_gl_date, 'YYYY/MM/DD');
   END IF;

   fnd_profile.get('GL_SET_OF_BKS_ID', l_set_of_books_id);

   IF p_source = 'Cash Balancing' THEN
      l_effective_date := TRUNC(SYSDATE);

      IF p_gl_period IS NULL THEN
         FOR i_p IN (SELECT period_name
                     FROM   gl_period_statuses
                     WHERE  application_id = z_appl_id
                     AND    set_of_books_id = l_set_of_books_id
                     AND    closing_status = 'O'
                     AND    NVL(adjustment_period_flag, N) = N
                     ORDER  BY period_year, quarter_num, period_num)
         LOOP
            l_period_open := i_p.period_name;
         END LOOP;

         IF l_period_open IS NULL THEN
            p_retcode := 1;
            fnd_file.put_line(fnd_file.log, z_error || 'No open period for this set of books');
         END IF;
      ELSE
         l_period_open := p_gl_period;
      END IF;

      BEGIN
         SELECT gp.period_name
         INTO   l_period_name
         FROM   gl_sets_of_books bk,
                gl_periods gp,
                gl_period_types ty
         WHERE  bk.set_of_books_id = l_set_of_books_id
         AND    bk.period_set_name = gp.period_set_name
         AND    gp.period_type = ty.period_type
         AND    NVL(gp.adjustment_period_flag, N) = N
         AND    UPPER(ty.user_period_type) = 'MONTH'
         AND    (gp.period_num, gp.period_year) = (SELECT DECODE(gx.period_num, 1, 12, (gx.period_num -1)),
                                                          DECODE(gx.period_num, 1, (gx.period_year - 1), gx.period_year)
                                                   FROM   gl_periods gx
                                                   WHERE  NVL(gx.adjustment_period_flag, N) = N
                                                   AND    gx.period_type = gp.period_type
                                                   AND    gx.period_name = l_period_open
                                                   AND    gx.period_set_name = gp.period_set_name);
      EXCEPTION
         WHEN no_data_found THEN
            p_retcode := 2;
            fnd_file.put_line(fnd_file.log, z_error || 'Unable to determine prior period');
      END;

      --Test Period JUN-16
      --l_period_name := 'JUN-16';
      IF l_period_name IS NOT NULL THEN
         create_journals(p_errbuff         => l_errbuff,
                         p_retcode         => l_retcode,
                         p_set_of_books_id => l_set_of_books_id,
                         p_effective_date  => fnd_date.date_to_canonical(l_effective_date),
                         p_period_name     => l_period_name,
                         p_source          => p_source,
                         p_je_batch_id     => NULL,
                         p_je_header_id    => NULL,
                         p_force_flag      => Y,
                         p_test_flag       => N,
                         p_debug_flag      => Y);

         l_process_errored := l_process_errored + NVL(l_retcode, 0);
      END IF;
   ELSE
      FOR i_b IN (SELECT DISTINCT
                         je_batch_id,
                         period_name,
                         je_source
                  FROM   gl_je_headers h,
                         gl_je_sources s
                  WHERE  h.je_source = s.je_source_name
                  AND    s.user_je_source_name = p_source
                  AND    h.set_of_books_id = l_set_of_books_id
                  AND    NOT EXISTS (SELECT 'x'
                                     FROM   xxgl_cash_bal_ctl x
                                     WHERE  x.je_header_id = h.je_header_id
                                     AND    x.balancing_status IN ('S', 'W', 'C')))
      LOOP
         create_journals(p_errbuff         => l_errbuff,
                         p_retcode         => l_retcode,
                         p_set_of_books_id => l_set_of_books_id,
                         p_effective_date  => fnd_date.date_to_canonical(l_effective_date),
                         p_period_name     => i_b.period_name,
                         p_source          => i_b.je_source,
                         p_je_batch_id     => i_b.je_batch_id,
                         p_je_header_id    => NULL,
                         p_force_flag      => N,
                         p_test_flag       => N,
                         p_debug_flag      => Y);

         l_process_errored := l_process_errored + NVL(l_retcode, 0);
      END LOOP;
   END IF;

   IF l_process_errored > 0 THEN
      p_retcode := 1;
   END IF;
EXCEPTION
   WHEN others THEN
      RAISE;
END submit_cash_balancing;

------------------------------------------------------
-- Function
--    CALCULATE_TAX (Payables)
-- Purpose
--    Run this simple function to calculate tax and
--    include the tax amount to the line amount.
------------------------------------------------------

FUNCTION calculate_tax 
(
   p_accounting_event_id  IN NUMBER,
   p_tax_code_id          IN NUMBER,
   p_amount               IN NUMBER,
   p_from_tax_line        IN VARCHAR2,
   p_calculate_tax        IN OUT VARCHAR2
)
RETURN NUMBER
IS
   l_tax_rate     NUMBER;
   l_tax_line     NUMBER;
BEGIN
   SELECT (atax.tax_rate / 100)
   INTO   l_tax_rate
   FROM   ap_tax_codes_all atax
   WHERE  atax.org_id = g_org_id
   AND    atax.tax_id = p_tax_code_id;

   IF NVL(p_from_tax_line, N) = N THEN
      SELECT COUNT(1)
      INTO   l_tax_line
      FROM   ap_invoice_distributions_all apd
      WHERE  apd.org_id = g_org_id
      AND    apd.amount <> 0
      AND    apd.line_type_lookup_code = z_tax
      AND    apd.tax_code_id = p_tax_code_id
      AND    apd.accounting_event_id = p_accounting_event_id;

      IF l_tax_line <> 0 THEN
         p_calculate_tax := 'Y';
         RETURN ROUND(p_amount * (l_tax_rate + 1), 2);
      ELSE
         RETURN p_amount;
      END IF;
   ELSE
      p_calculate_tax := 'Y';
      RETURN ROUND(p_amount * l_tax_rate, 2);
   END IF;

EXCEPTION
   WHEN no_data_found THEN
      RETURN p_amount;
END calculate_tax;

---------------------------------------------------------------
-- Function
--    GET_CUSTOMER_TRX_ID
-- Purpose
--    This function derives the latest customer transaction 
--    where the receipt has been applied to.
---------------------------------------------------------------

FUNCTION get_customer_trx_id
(
   p_cash_receipt_id     NUMBER,
   p_posting_control_id  NUMBER
)
RETURN NUMBER
IS
BEGIN
   FOR i IN (SELECT applied_customer_trx_id
             FROM   ar_receivable_applications_all
             WHERE  cash_receipt_id = p_cash_receipt_id
             AND    posting_control_id = p_posting_control_id
             AND    status = 'APP'
             ORDER  BY receivable_application_id DESC)
   LOOP
      IF i.applied_customer_trx_id = -1 OR
         i.applied_customer_trx_id IS NULL THEN
         NULL;
      ELSE
         RETURN i.applied_customer_trx_id;
      END IF;
   END LOOP;

   RETURN NULL;
END get_customer_trx_id;

---------------------------------------------------------------------
-- Procedure
--    GET_DISTRIBUTION_LINES
-- Purpose
--    This procedure apportions the journal line amount against the
--    source subledger distribution line accounts before allocating
--    to the target cash balancing account codes.
---------------------------------------------------------------------

PROCEDURE get_distribution_lines
(
   p_rule_id          IN  NUMBER,
   p_source           IN  gl_je_headers.je_source%TYPE,
   p_je_header_id     IN  gl_je_lines.je_header_id%TYPE,
   p_je_line_num      IN  gl_je_lines.je_line_num%TYPE,
   p_je_line_amount   IN  NUMBER,
   p_sl_trx_type      IN  xxgl_cash_bal_rules_all.sl_trx_type%TYPE,
   p_sl_trx_subtype   IN  xxgl_cash_bal_rules_all.sl_trx_subtype%TYPE,
   p_summary_flag     IN  VARCHAR2,
   p_sl_tab           OUT t_sl_tab_type,
   p_message          OUT VARCHAR2
)
IS
   CURSOR c_rule IS
      SELECT r.rule_num,
             r.enter_amount,
             DECODE(r.target_cost_centre, z_any, NULL, r.target_cost_centre) segment3,
             DECODE(r.target_authority, z_any, NULL, r.target_authority) segment4,
             DECODE(r.target_project, z_any, NULL, r.target_project) segment5,
             DECODE(r.target_output, z_any, NULL, r.target_output) segment6,
             DECODE(r.target_identifier, z_any, NULL, r.target_identifier) segment7,
             r.filter_condition_line1 sql_query
      FROM   xxgl_cash_bal_rules_all r
      WHERE  r.rule_id = p_rule_id;

   c_sl_refcur            cursor_type;
   r_rule_x               c_rule%ROWTYPE;
   l_idx                  NUMBER := 0;
   l_segs                 NUMBER;
   l_customer_trx_id      NUMBER;
   l_posting_control_id   NUMBER;
   l_cash_receipt_id      NUMBER;
   l_amount               NUMBER;
   l_line_amount          NUMBER;
   l_diff_amount          NUMBER;
   l_diff_line            NUMBER;
   l_tot_amount           NUMBER := 0;
   l_tot_amount_abs       NUMBER := 0;
   l_cursor_switch        NUMBER := 0;
   l_jel_amount           NUMBER := p_je_line_amount;
   l_jel_amount_abs       NUMBER := ABS(p_je_line_amount);
   l_ccid                 gl_code_combinations.code_combination_id%TYPE;
   l_segments_varr        fnd_flex_ext.SegmentArray;
   l_token_name           VARCHAR2(150);
   l_token_value          VARCHAR2(150);
   l_receipt_number       ar_cash_receipts_all.receipt_number%TYPE;
   l_cc_segment1          VARCHAR2(25);
   l_cc_segment2          VARCHAR2(25);
   l_cc_segment3          VARCHAR2(25);
   l_cc_segment4          VARCHAR2(25);
   l_cc_segment5          VARCHAR2(25);
   l_cc_segment6          VARCHAR2(25);
   l_cc_segment7          VARCHAR2(25);
   l_tax_code_id          NUMBER;
   l_from_tax_line        VARCHAR2(1);
   l_calculate_tax        VARCHAR2(1);
   b_segments             BOOLEAN;
   b_allocate             BOOLEAN;
   b_run_difference       BOOLEAN;

BEGIN
   OPEN c_rule;
   FETCH c_rule INTO r_rule_x;
   CLOSE c_rule;

   b_run_difference := TRUE;

   IF p_source = 'Receivables' THEN
      IF p_sl_trx_type = 'INV' AND p_sl_trx_subtype = 'INV_REC' THEN
         l_token_name := 'Sales Invoice';
         l_cursor_switch := 1;

         OPEN c_sl_refcur FOR
         SELECT t.trx_number,
                d.code_combination_id,
                NULL tax_code_id,
                NVL(d.amount, 0) + NVL(tax.extended_amount, 0) amount,
                N from_tax_line
         FROM   ra_customer_trx_all t,
                ra_customer_trx_lines_all l,
                ra_cust_trx_line_gl_dist_all d,
                (
                SELECT tl.customer_trx_id,
                       tl.link_to_cust_trx_line_id,
                       tl.extended_amount
                FROM   ra_customer_trx_lines_all tl,
                       ra_cust_trx_line_gl_dist_all td
                WHERE  tl.line_type = z_tax
                AND    tl.customer_trx_line_id = td.customer_trx_line_id
                ) tax
         WHERE  t.org_id = g_org_id
         AND    t.customer_trx_id = d.customer_trx_id
         AND    t.customer_trx_id = l.customer_trx_id
         AND    l.customer_trx_line_id = d.customer_trx_line_id
         AND    l.line_type <> z_tax
         AND    l.customer_trx_id = tax.customer_trx_id(+)
         AND    l.customer_trx_line_id = tax.link_to_cust_trx_line_id(+)
         AND    d.account_class = z_revenue_acct
         AND    EXISTS (SELECT 1
                        FROM   gl_je_lines jel
                        WHERE  jel.je_header_id = p_je_header_id
                        AND    jel.je_line_num = p_je_line_num
                        AND    jel.reference_2 IS NOT NULL
                        AND    TO_NUMBER(jel.reference_1) = d.posting_control_id
                        AND    TO_NUMBER(jel.reference_2) = t.customer_trx_id
                        AND    jel.reference_9 = p_sl_trx_subtype);

      ELSIF p_sl_trx_type = 'INV' AND p_sl_trx_subtype = 'INV_TAX' THEN
         l_token_name := 'Sales Invoice Tax';
         l_cursor_switch := 1;

         OPEN c_sl_refcur FOR
         SELECT th.trx_number,
                (
                SELECT rd.code_combination_id
                FROM   ra_customer_trx_lines_all rl,
                       ra_cust_trx_line_gl_dist_all rd
                WHERE  rl.customer_trx_line_id = rd.customer_trx_line_id
                AND    rl.customer_trx_line_id = tl.link_to_cust_trx_line_id
                ) code_combination_id,
                NULL tax_code_id,
                td.amount,
                N from_tax_line
         FROM   ra_cust_trx_line_gl_dist_all td,
                ra_customer_trx_lines_all tl,
                ra_customer_trx_all th
         WHERE  td.org_id = g_org_id
         AND    td.customer_trx_id = th.customer_trx_id
         AND    td.customer_trx_line_id = tl.customer_trx_line_id
         AND    EXISTS (SELECT 1
                        FROM   gl_je_lines jel
                        WHERE  jel.je_header_id = p_je_header_id
                        AND    jel.je_line_num = p_je_line_num
                        AND    TO_NUMBER(jel.reference_1) = td.posting_control_id
                        AND    TO_NUMBER(jel.reference_3) = td.cust_trx_line_gl_dist_id
                        AND    jel.reference_3 IS NOT NULL
                        AND    jel.reference_9 = p_sl_trx_subtype);

      ELSIF p_sl_trx_type = 'CM' AND p_sl_trx_subtype = 'CM_REC' THEN
         l_token_name := 'Credit Memo';
         l_cursor_switch := 1;

         OPEN c_sl_refcur FOR
         SELECT t.trx_number,
                d.code_combination_id,
                NULL tax_code_id,
                NVL(d.amount, 0) + NVL(tax.extended_amount, 0) amount,
                N from_tax_line
         FROM   ra_customer_trx_all t,
                ra_customer_trx_lines_all l,
                ra_cust_trx_line_gl_dist_all d,
                (
                SELECT tl.customer_trx_id,
                       tl.link_to_cust_trx_line_id,
                       tl.extended_amount
                FROM   ra_customer_trx_lines_all tl,
                       ra_cust_trx_line_gl_dist_all td
                WHERE  tl.line_type = z_tax
                AND    tl.customer_trx_line_id = td.customer_trx_line_id
                ) tax
         WHERE  t.org_id = g_org_id
         AND    t.customer_trx_id = d.customer_trx_id
         AND    t.customer_trx_id = l.customer_trx_id
         AND    l.customer_trx_line_id = d.customer_trx_line_id
         AND    l.line_type <> z_tax
         AND    l.customer_trx_id = tax.customer_trx_id(+)
         AND    l.customer_trx_line_id = tax.link_to_cust_trx_line_id(+)
         AND    d.account_class = z_revenue_acct
         AND    EXISTS (SELECT 1
                        FROM   gl_je_lines jel
                        WHERE  jel.je_header_id = p_je_header_id
                        AND    jel.je_line_num = p_je_line_num
                        AND    TO_NUMBER(jel.reference_1) = d.posting_control_id
                        AND    TO_NUMBER(jel.reference_2) = t.customer_trx_id
                        AND    jel.reference_2 IS NOT NULL
                        AND    jel.reference_9 = p_sl_trx_subtype);

      ELSIF p_sl_trx_type = 'CM' AND p_sl_trx_subtype = 'CM_TAX' THEN
         l_token_name := 'Credit Memo Tax';
         l_cursor_switch := 1;

         OPEN c_sl_refcur FOR
         SELECT th.trx_number,
                (
                SELECT rd.code_combination_id
                FROM   ra_customer_trx_lines_all rl,
                       ra_cust_trx_line_gl_dist_all rd
                WHERE  rl.customer_trx_line_id = rd.customer_trx_line_id
                AND    rl.customer_trx_line_id = tl.link_to_cust_trx_line_id
                ) code_combination_id,
                NULL tax_code_id,
                td.amount,
                N from_tax_line
         FROM   ra_cust_trx_line_gl_dist_all td,
                ra_customer_trx_lines_all tl,
                ra_customer_trx_all th
         WHERE  td.org_id = g_org_id
         AND    td.customer_trx_id = th.customer_trx_id
         AND    td.customer_trx_line_id = tl.customer_trx_line_id
         AND    EXISTS (SELECT 1
                        FROM   gl_je_lines jel
                        WHERE  jel.je_header_id = p_je_header_id
                        AND    jel.je_line_num = p_je_line_num
                        AND    TO_NUMBER(jel.reference_1) = td.posting_control_id
                        AND    TO_NUMBER(jel.reference_3) = td.cust_trx_line_gl_dist_id
                        AND    jel.reference_3 IS NOT NULL
                        AND    jel.reference_9 = p_sl_trx_subtype);

      ELSIF p_sl_trx_type = 'TRADE' AND (p_sl_trx_subtype = 'TRADE_REC' OR
                                         p_sl_trx_subtype = 'TRADE_UNAPP')
      THEN
         l_token_name := 'Trade Receipt';

         BEGIN
            SELECT arc.receipt_number,
                   are.cash_receipt_id,
                   are.posting_control_id,
                   DECODE(p_sl_trx_subtype, 'TRADE_UNAPP', ABS(are.amount_applied), are.amount_applied)
            INTO   l_receipt_number,
                   l_cash_receipt_id,
                   l_posting_control_id,
                   l_line_amount
            FROM   ar_receivable_applications_all are,
                   ar_cash_receipts_all arc,
                   gl_je_lines jel
            WHERE  are.cash_receipt_id = arc.cash_receipt_id
            AND    arc.receipt_number = jel.reference_4
            AND    are.posting_control_id = TO_NUMBER(jel.reference_1)
            AND    are.set_of_books_id = jel.set_of_books_id
            AND    are.receivable_application_id = TO_NUMBER(SUBSTR(jel.reference_2, INSTR(jel.reference_2, 'C') + 1, 15))
            AND    jel.je_header_id = p_je_header_id
            AND    jel.je_line_num = p_je_line_num
            AND    jel.reference_9 = p_sl_trx_subtype;

            l_customer_trx_id := get_customer_trx_id(l_cash_receipt_id, l_posting_control_id);

            OPEN c_sl_refcur FOR
            SELECT l_receipt_number,
                   a.code_combination_id,
                   NULL tax_code_id,
                   SUM((a.distribution_amount / a.invoice_amount) * l_line_amount) amount,
                   N from_tax_line                    
            FROM   (SELECT ll.line_number,
                           ld.code_combination_id,
                           ld.amount + NVL(txl.amount, 0) distribution_amount,
                           (SELECT rec.amount
                            FROM   ra_cust_trx_line_gl_dist_all rec
                            WHERE  rec.account_class = z_receivable_acct
                            AND    rec.customer_trx_id = ll.customer_trx_id) invoice_amount
                    FROM   ra_customer_trx_lines_all ll,
                           ra_cust_trx_line_gl_dist_all ld,
                           (SELECT  tl.customer_trx_id,
                                    tl.link_to_cust_trx_line_id,
                                    td.amount
                            FROM    ra_customer_trx_lines_all tl,
                                    ra_cust_trx_line_gl_dist_all td
                            WHERE   tl.line_type = z_tax
                            AND     tl.customer_trx_id = td.customer_trx_id
                            AND     tl.customer_trx_line_id = td.customer_trx_line_id) txl
                    WHERE  ll.line_type(+) = z_line
                    AND    ll.customer_trx_id = l_customer_trx_id
                    AND    ll.customer_trx_id = ld.customer_trx_id
                    AND    ll.customer_trx_line_id = ld.customer_trx_line_id
                    AND    ll.customer_trx_line_id = txl.link_to_cust_trx_line_id(+)
                    AND    ll.customer_trx_id = txl.customer_trx_id(+)) a
            GROUP BY a.code_combination_id;

            l_cursor_switch := 1;

         EXCEPTION
            WHEN no_data_found THEN
               NULL;
         END;

      -- Added TRADE_CASH FSC-5206 
      ELSIF p_sl_trx_type = 'TRADE' AND p_sl_trx_subtype = 'TRADE_CASH' THEN
         l_token_name := 'Trade Receipt';

         BEGIN
            SELECT arc.receipt_number,
                   arc.cash_receipt_id,
                   arh.posting_control_id,
                   DECODE(arh.status, 'REVERSED', arh.amount * -1, arh.amount)
            INTO   l_receipt_number,
                   l_cash_receipt_id,
                   l_posting_control_id,
                   l_line_amount
            FROM   ar_cash_receipts_all arc,
                   ar_cash_receipt_history_all arh,
                   gl_je_lines jel
            WHERE  arc.cash_receipt_id = arh.cash_receipt_id
            AND    arh.cash_receipt_history_id = TO_NUMBER(SUBSTR(jel.reference_2, INSTR(jel.reference_2, 'C') + 1, 15))
            AND    arh.posting_control_id = TO_NUMBER(jel.reference_1)
            AND    jel.je_header_id = p_je_header_id
            AND    jel.je_line_num = p_je_line_num
            AND    jel.reference_9 = p_sl_trx_subtype;

            l_customer_trx_id := get_customer_trx_id(l_cash_receipt_id, l_posting_control_id);

            OPEN c_sl_refcur FOR
            SELECT l_receipt_number,
                   a.code_combination_id,
                   NULL tax_code_id,
                   SUM((a.distribution_amount / a.invoice_amount) * l_line_amount) amount,
                   N from_tax_line                    
            FROM   (SELECT ll.line_number,
                           ld.code_combination_id,
                           ld.amount + NVL(txl.amount, 0) distribution_amount,
                           (SELECT rec.amount
                            FROM   ra_cust_trx_line_gl_dist_all rec
                            WHERE  rec.account_class = z_receivable_acct
                            AND    rec.customer_trx_id = ll.customer_trx_id) invoice_amount
                    FROM   ra_customer_trx_lines_all ll,
                           ra_cust_trx_line_gl_dist_all ld,
                           (SELECT  tl.customer_trx_id,
                                    tl.link_to_cust_trx_line_id,
                                    td.amount
                            FROM    ra_customer_trx_lines_all tl,
                                    ra_cust_trx_line_gl_dist_all td
                            WHERE   tl.line_type = z_tax
                            AND     tl.customer_trx_id = td.customer_trx_id
                            AND     tl.customer_trx_line_id = td.customer_trx_line_id) txl
                    WHERE  ll.line_type(+) = z_line
                    AND    ll.customer_trx_id = l_customer_trx_id
                    AND    ll.customer_trx_id = ld.customer_trx_id
                    AND    ll.customer_trx_line_id = ld.customer_trx_line_id
                    AND    ll.customer_trx_line_id = txl.link_to_cust_trx_line_id(+)
                    AND    ll.customer_trx_id = txl.customer_trx_id(+)) a
            GROUP BY a.code_combination_id;

            l_cursor_switch := 1;

         EXCEPTION
            WHEN no_data_found THEN
               NULL;
         END;

      ELSIF p_sl_trx_type = 'TRADE' AND p_sl_trx_subtype = 'TRADE_ACC' THEN
         l_token_name := 'Trade Receipt';
         l_cursor_switch := 1;

         OPEN c_sl_refcur FOR
         SELECT arc.receipt_number,
                are.code_combination_id,
                NULL tax_code_id,
                are.amount_applied amount,
                N from_tax_line
         FROM   ar_receivable_applications_all are,
                ar_cash_receipts_all arc,
                gl_je_lines jel
         WHERE  are.status = 'ACC'
         AND    are.cash_receipt_id = arc.cash_receipt_id
         AND    arc.receipt_number = jel.reference_4
         AND    are.posting_control_id = TO_NUMBER(jel.reference_1)
         AND    are.set_of_books_id = jel.set_of_books_id
         AND    jel.je_header_id = p_je_header_id
         AND    jel.je_line_num = p_je_line_num
         AND    jel.reference_9 = p_sl_trx_subtype;

      ELSIF p_sl_trx_type = 'MISC' AND p_sl_trx_subtype = 'MISC_CASH' THEN
         l_token_name := 'Misc Receipt';
         l_cursor_switch := 1;

         OPEN c_sl_refcur FOR
         SELECT arec.receipt_number,
                NVL(mdrev.code_combination_id, mdapp.code_combination_id) code_combination_id,
                NULL tax_code_id,
                /* DR and CR getting switched when sign is manipulated
                DECODE(mdrev.created_from, 'ARP_REVERSE_RECEIPT.REVERSE',
                                           NVL(mdrev.amount, mdapp.amount) * -1,
                                           NVL(mdrev.amount, mdapp.amount) * SIGN(arec.amount)) amount,
                */
                NVL(mdrev.amount, mdapp.amount) amount,
                N from_tax_line
         FROM   ar_cash_receipts_all arec,
                ar_cash_receipt_history_all hist,
                ar_misc_cash_distributions_all mdrev,
                ar_misc_cash_distributions_all mdapp
         WHERE  arec.cash_receipt_id = hist.cash_receipt_id
              --NVL(hist.current_record_flag, 'N') = 'Y'
         AND    arec.org_id = g_org_id
         AND    hist.cash_receipt_id = mdrev.cash_receipt_id(+)
         AND    hist.created_from = mdrev.created_from(+)
         AND    hist.cash_receipt_id = mdapp.cash_receipt_id(+)
         AND    mdapp.created_from <> 'ARP_REVERSE_RECEIPT.REVERSE'
         AND    EXISTS (SELECT 1
                        FROM   gl_je_lines jel
                        WHERE  jel.je_header_id = p_je_header_id
                        AND    jel.je_line_num = p_je_line_num
                        AND    jel.reference_2 IS NOT NULL
                        AND    TO_NUMBER(jel.reference_2) = arec.cash_receipt_id
                        AND    TO_NUMBER(jel.reference_5) = hist.cash_receipt_history_id
                        AND    jel.reference_9 = p_sl_trx_subtype);
         /*  FSC-5728
         SELECT r.receipt_number,
                d.code_combination_id,
                ((d.amount / r.amount) * l_jel_amount) amount
         FROM   ar_cash_receipts_all r,
                ar_misc_cash_distributions_all d
         WHERE  r.cash_receipt_id = d.cash_receipt_id
         AND    d.org_id = g_org_id
         AND    r.cash_receipt_id = (SELECT TO_NUMBER(jel.reference_2)
                                     FROM   gl_je_lines jel
                                     WHERE  jel.je_header_id = p_je_header_id
                                     AND    jel.je_line_num = p_je_line_num
                                     AND    jel.reference_2 IS NOT NULL
                                     AND    jel.reference_9 = p_sl_trx_subtype);
         */
      ELSIF p_sl_trx_type = 'MISC' AND p_sl_trx_subtype = 'MISC_TAX' THEN
         l_token_name := 'Misc Receipt Tax';
         l_cursor_switch := 1;

         OPEN c_sl_refcur FOR
         SELECT arec.receipt_number,
                mdapp.code_combination_id,
                NULL tax_code_id,
                ABS((mdapp.amount / arec.amount) * l_jel_amount) amount,
                N from_tax_line
         FROM   ar_cash_receipts_all arec,
                ar_misc_cash_distributions_all mdapp
         WHERE  arec.cash_receipt_id = mdapp.cash_receipt_id
         AND    EXISTS (SELECT *
                        FROM   gl_je_lines jel
                        WHERE  jel.je_header_id = p_je_header_id
                        AND    jel.je_line_num = p_je_line_num
                        AND    jel.reference_2 IS NOT NULL
                        AND    TO_NUMBER(jel.reference_2) = arec.cash_receipt_id
                        AND    TO_NUMBER(jel.reference_1) = mdapp.posting_control_id
                        AND    jel.reference_9 = p_sl_trx_subtype);
         /* FSC-5728
         SELECT r.receipt_number,
                d.code_combination_id,
                ((d.amount / r.amount) * l_jel_amount) amount
         FROM   ar_cash_receipts_all r,
                ar_misc_cash_distributions_all d
         WHERE  r.cash_receipt_id = d.cash_receipt_id
         AND    d.org_id = g_org_id
         AND    r.cash_receipt_id = (SELECT TO_NUMBER(jel.reference_2)
                                     FROM   gl_je_lines jel
                                     WHERE  jel.je_header_id = p_je_header_id
                                     AND    jel.je_line_num = p_je_line_num
                                     AND    jel.reference_2 IS NOT NULL
                                     AND    jel.reference_9 = p_sl_trx_subtype);
         */
      END IF;

   ELSIF p_source = 'Payables' THEN
      IF p_sl_trx_type = 'INVOICE'  AND p_sl_trx_subtype = 'LIABILITY' THEN
         l_token_name := 'Liability';
         l_cursor_switch := 1;

         OPEN c_sl_refcur FOR
         SELECT apinv.accounting_event_id line,
                apinv.dist_code_combination_id,
                apinv.tax_code_id,
                SUM(DECODE(apinv.cancellation_flag, Y,
                    /* FSC-5899
                    DECODE(SIGN(aptax.tax_rate), 1, ((apinv.amount * (aptax.tax_rate / 100)) + apinv.amount), apinv.amount) * -1,
                    DECODE(SIGN(aptax.tax_rate), 1, ((apinv.amount * (aptax.tax_rate / 100)) + apinv.amount), apinv.amount))) amount
                    */
                    apinv.amount * -1,
                    apinv.amount)) amount,
                N from_tax_line
         FROM   ap_invoice_distributions_all apinv,
                ap_tax_codes_all aptax
         WHERE  apinv.org_id = g_org_id
         AND    apinv.line_type_lookup_code <> z_tax
         AND    apinv.tax_code_id = aptax.tax_id(+)
         AND    apinv.org_id = aptax.org_id(+)
         AND    EXISTS (SELECT 1
                        FROM   ap_ae_headers_all aaha,
                               ap_ae_lines_all aala,
                               gl_je_lines jel
                        WHERE  aala.source_table = 'AP_INVOICES'
                        AND    aala.ae_line_type_code = p_sl_trx_subtype
                        AND    aaha.trial_balance_flag = Y
                        AND    aala.ae_header_id = aaha.ae_header_id
                        AND    aaha.gl_transfer_flag = Y
                        AND    aaha.gl_transfer_run_id IS NOT NULL
                        AND    aaha.accounting_event_id = apinv.accounting_event_id
                        AND    aala.source_id = apinv.invoice_id
                        AND    aala.gl_sl_link_id = jel.gl_sl_link_id
                        AND    aala.code_combination_id = jel.code_combination_id
                        AND    aaha.period_name = jel.period_name
                        AND    jel.je_header_id = p_je_header_id
                        AND    jel.je_line_num = p_je_line_num)
         GROUP  BY apinv.accounting_event_id,
                   apinv.dist_code_combination_id,
                   apinv.tax_code_id;

      ELSIF p_sl_trx_type = 'INVOICE'  AND p_sl_trx_subtype = 'CHARGE' THEN
         l_token_name := 'Liability Adjustment';
         l_cursor_switch := 1;

         OPEN c_sl_refcur FOR
         SELECT apd.accounting_event_id,
                apd.dist_code_combination_id,
                apd.tax_code_id,
                /* FSC-5899
                ABS(SUM(DECODE(SIGN((SELECT COUNT(1)
                                     FROM   ap_invoice_distributions_all apx
                                     WHERE  NVL(apx.amount, 0) <> 0
                                     AND    apx.line_type_lookup_code = z_tax
                                     AND    apx.invoice_id = apd.invoice_id
                                     AND    apx.tax_code_id = apd.tax_code_id
                                     AND    apx.accounting_event_id = apd.accounting_event_id
                                     GROUP  BY apx.invoice_id, apx.tax_code_id)),
                               1, apd.amount * ((apt.tax_rate / 100) + 1),
                               0, apd.amount))) * -1 amount
                */
                ABS(SUM(apd.amount)) * -1 amount,
                N from_tax_line
         FROM   ap_invoice_distributions_all apd,
                ap_tax_codes_all apt,
                ap_accounting_events_all aev
         WHERE  apd.line_type_lookup_code <> z_tax
         AND    apd.tax_code_id = apt.tax_id(+)
         AND    apd.org_id = apt.org_id(+)
         AND    apd.accounting_event_id = aev.accounting_event_id(+)
         AND    'INVOICE ADJUSTMENT' = aev.event_type_code(+)
         AND    EXISTS (SELECT 1
                        FROM   ap_ae_headers_all aaha,
                               ap_ae_lines_all aala,
                               gl_je_lines jel
                        WHERE  aala.source_table = 'AP_INVOICE_DISTRIBUTIONS'
                        AND    aaha.trial_balance_flag = Y
                        AND    aala.ae_header_id = aaha.ae_header_id
                        AND    aaha.gl_transfer_flag = Y
                        AND    aaha.gl_transfer_run_id IS NOT NULL
                        AND    aala.gl_sl_link_id = jel.gl_sl_link_id
                        AND    aala.code_combination_id = jel.code_combination_id
                        AND    jel.code_combination_id = apd.dist_code_combination_id
                        AND    aaha.period_name = jel.period_name
                        AND    aaha.accounting_event_id = apd.accounting_event_id
                        AND    jel.je_header_id = p_je_header_id
                        AND    jel.je_line_num = p_je_line_num)
         GROUP  BY apd.accounting_event_id,
                   apd.dist_code_combination_id,
                   apd.tax_code_id;

      ELSIF p_sl_trx_type = 'INVOICE'  AND p_sl_trx_subtype = 'RECOVERABLE_TAX' THEN
         l_token_name := 'Recoverable Tax';
         l_cursor_switch := 1;

         OPEN c_sl_refcur FOR
         SELECT apinv.invoice_id line,
                apinv.dist_code_combination_id,
                apinv.tax_code_id,
                -- FSC-5899
                -- (ABS(apinv.amount) * (atax.tax_rate / 100)) amount,
                ABS(SUM(apinv.amount)) amount,
                Y from_tax_line
         FROM   ap_invoice_distributions_all apinv,
                ap_tax_codes_all atax
         WHERE  apinv.org_id = g_org_id
         AND    apinv.line_type_lookup_code <> 'TAX'
         AND    apinv.tax_code_id = atax.tax_id
         AND    NVL(atax.tax_rate, 0) > 0
         AND    apinv.org_id = atax.org_id
         AND    EXISTS (SELECT *
                        FROM   ap_ae_headers_all aaha,
                               ap_ae_lines_all aala,
                               gl_je_lines jel,
                               ap_invoice_distributions_all adis
                        WHERE  aala.source_table = 'AP_INVOICE_DISTRIBUTIONS'
                        AND    aala.ae_line_type_code = 'RECOVERABLE TAX'
                        AND    aaha.trial_balance_flag = Y
                        AND    aala.source_id = adis.invoice_distribution_id
                        AND    adis.invoice_id = apinv.invoice_id
                        AND    aala.ae_header_id = aaha.ae_header_id
                        AND    aaha.gl_transfer_flag = Y
                        AND    aaha.gl_transfer_run_id IS NOT NULL
                        AND    aaha.accounting_event_id = apinv.accounting_event_id
                        AND    aala.gl_sl_link_id = jel.gl_sl_link_id
                        AND    aala.code_combination_id = jel.code_combination_id
                        AND    SIGN(NVL(aala.entered_dr, 0) - NVL(aala.entered_cr, 0)) = SIGN(apinv.amount)
                        AND    aaha.period_name = jel.period_name
                        AND    apinv.period_name = jel.period_name
                        AND    jel.je_header_id = p_je_header_id
                        AND    jel.je_line_num = p_je_line_num)
         GROUP  BY apinv.invoice_id,
                   apinv.dist_code_combination_id,
                   apinv.tax_code_id;
         /* FSC-5721
         SELECT '' line,
                apinv.dist_code_combination_id,
                ((SUM(apinv.amount) / l_dist_sum) * l_jel_amount) amount
         FROM   ap_invoice_distributions_all apinv,
                ap_tax_codes_all atax
         WHERE  apinv.org_id = g_org_id
         AND    apinv.line_type_lookup_code <> z_tax
         AND    apinv.tax_code_id = atax.tax_id
         AND    NVL(atax.tax_rate, 0) > 0
         AND    apinv.org_id = atax.org_id
         AND    EXISTS (SELECT 1
                        FROM   ap_ae_headers_all aaha,
                               ap_ae_lines_all aala,
                               gl_je_lines jel,
                               ap_invoice_distributions_all adis
                        WHERE  aala.source_table = 'AP_INVOICE_DISTRIBUTIONS'
                        AND    aala.ae_line_type_code = REPLACE(p_sl_trx_subtype, '_', ' ')
                        AND    aaha.trial_balance_flag = Y
                        AND    aala.source_id = adis.invoice_distribution_id
                        AND    adis.invoice_id = apinv.invoice_id
                        AND    aala.ae_header_id = aaha.ae_header_id
                        AND    aaha.gl_transfer_flag = Y
                        AND    aaha.gl_transfer_run_id IS NOT NULL
                        AND    aaha.accounting_event_id = apinv.accounting_event_id
                        AND    aala.gl_sl_link_id = jel.gl_sl_link_id
                        AND    aala.code_combination_id = jel.code_combination_id
                        AND    NVL(aala.entered_dr, 0) - NVL(aala.entered_cr, 0) <> 0
                        AND    aaha.period_name = jel.period_name
                        AND    apinv.period_name = jel.period_name
                        AND    jel.je_header_id = p_je_header_id
                        AND    jel.je_line_num = p_je_line_num)
         GROUP BY apinv.dist_code_combination_id;
         */

      ELSIF p_sl_trx_type = 'PAYMENT'  AND p_sl_trx_subtype = 'CASH' THEN
         l_token_name := 'Payments';
         l_cursor_switch := 1;

         OPEN c_sl_refcur FOR
         SELECT i.invoice_id line,
                d.dist_code_combination_id,
                d.tax_code_id,
                -- FSC-5899
                -- SUM(((NVL(t.tax_rate, 0) / 100) + 1) * d.amount) amount
                SUM(d.amount) amount,
                N from_tax_line
         FROM   ap_checks_all c,
                ap_invoice_payments_all p,
                ap_invoices_all i,
                ap_invoice_distributions_all d,
                ap_tax_codes_all t
         WHERE  c.check_id = p.check_id
         AND    p.invoice_id = i.invoice_id
         AND    c.vendor_id = i.vendor_id
         AND    c.vendor_site_id = i.vendor_site_id
         AND    i.invoice_id = d.invoice_id
         AND    d.org_id = g_org_id
         AND    d.line_type_lookup_code <> z_tax
         AND    d.tax_code_id = t.tax_id(+)
         AND    EXISTS (SELECT 1
                        FROM   ap_ae_headers_all aaha,
                               ap_ae_lines_all aala,
                               gl_je_lines jel
                        WHERE  aala.source_table = 'AP_CHECKS'
                        AND    aala.source_id = c.check_id
                        AND    aala.ae_line_type_code = p_sl_trx_subtype
                        AND    aala.ae_header_id = aaha.ae_header_id
                        AND    aaha.gl_transfer_flag = Y
                        AND    aaha.trial_balance_flag = Y
                        AND    aaha.gl_transfer_run_id IS NOT NULL
                        AND    aala.gl_sl_link_id = jel.gl_sl_link_id
                        AND    aala.code_combination_id = jel.code_combination_id
                        AND    aaha.period_name = jel.period_name
                        AND    jel.je_header_id = p_je_header_id
                        AND    jel.je_line_num = p_je_line_num)
         GROUP BY i.invoice_id,
                  d.dist_code_combination_id,
                  d.tax_code_id;

      ELSIF p_sl_trx_type = 'PAYMENT'  AND p_sl_trx_subtype = 'CORP_CARD' THEN
         l_token_name := 'Payments: Corp Card';
         l_cursor_switch := 1;

         OPEN c_sl_refcur FOR
         SELECT i.invoice_id line,
                d.dist_code_combination_id,
                d.tax_code_id,
                -- FSC-5899
                -- SUM(((NVL(t.tax_rate, 0) / 100) + 1) * d.amount) amount
                SUM(d.amount) amount,
                N from_tax_line
         FROM   ap_checks_all c,
                ap_invoice_payments_all p,
                ap_invoices_all i,
                ap_invoice_distributions_all d,
                ap_tax_codes_all t,
                ap_expense_report_headers_all e
         WHERE  c.check_id = p.check_id
         AND    p.invoice_id = i.invoice_id
         AND    i.invoice_id = e.vouchno
         AND    i.org_id = e.org_id
         AND    c.vendor_id = i.vendor_id
         AND    c.vendor_site_id = i.vendor_site_id
         AND    i.invoice_id = d.invoice_id
         AND    d.org_id = g_org_id
         AND    d.line_type_lookup_code <> z_tax
         AND    d.tax_code_id = t.tax_id(+)
         AND    EXISTS (SELECT 1
                        FROM   ap_ae_headers_all aaha,
                               ap_ae_lines_all aala,
                               gl_je_lines jel
                        WHERE  aala.source_table = 'AP_CHECKS'
                        AND    aala.source_id = c.check_id
                        AND    aala.ae_line_type_code = 'CASH'
                        AND    aala.ae_header_id = aaha.ae_header_id
                        AND    aaha.gl_transfer_flag = Y
                        AND    aaha.trial_balance_flag = Y
                        AND    aaha.gl_transfer_run_id IS NOT NULL
                        AND    aala.gl_sl_link_id = jel.gl_sl_link_id
                        AND    aala.code_combination_id = jel.code_combination_id
                        AND    aaha.period_name = jel.period_name
                        AND    jel.je_header_id = p_je_header_id
                        AND    jel.je_line_num = p_je_line_num)
         GROUP BY i.invoice_id,
                  d.dist_code_combination_id,
                  d.tax_code_id;
      END IF;
   END IF;

   IF l_cursor_switch = 1 THEN
      LOOP
         FETCH c_sl_refcur 
         INTO  l_token_value, 
               l_ccid, 
               l_tax_code_id, 
               l_amount, 
               l_from_tax_line;
         EXIT WHEN c_sl_refcur%NOTFOUND;

         b_allocate := TRUE;
         l_idx := l_idx + 1;
         l_calculate_tax := 'N';

         IF l_tax_code_id IS NOT NULL THEN
            l_amount := calculate_tax(TO_NUMBER(l_token_value), l_tax_code_id, l_amount, l_from_tax_line, l_calculate_tax);
         ELSE
            l_amount := ROUND(l_amount, 2);
         END IF;

         l_tot_amount := l_tot_amount + l_amount;
         l_tot_amount_abs := l_tot_amount_abs + ABS(l_amount);

         -------------------------------- Corporate Card Transactions --------------------------------

         IF (p_sl_trx_type = 'INVOICE' AND p_sl_trx_subtype = 'CHARGE' AND SIGN(l_amount) = -1) THEN
            BEGIN
               SELECT gcc.segment1,
                      gcc.segment2,
                      gcc.segment3,
                      gcc.segment4,
                      gcc.segment5,
                      gcc.segment6,
                      gcc.segment7
               INTO   p_sl_tab(l_idx).segment1,
                      p_sl_tab(l_idx).segment2,
                      p_sl_tab(l_idx).segment3,
                      p_sl_tab(l_idx).segment4,
                      p_sl_tab(l_idx).segment5,
                      p_sl_tab(l_idx).segment6,
                      p_sl_tab(l_idx).segment7
               FROM   ap_expense_report_headers_all aex,
                      per_assignments_f pas,
                      gl_code_combinations_kfv gcc
               WHERE  aex.vouchno = TO_NUMBER(l_token_value)
               AND    aex.org_id = g_org_id
               AND    aex.employee_id = pas.person_id
               AND    pas.default_code_comb_id = gcc.code_combination_id
               AND    (TRUNC(SYSDATE) BETWEEN pas.effective_start_date AND pas.effective_end_date);

               b_allocate := FALSE;
            EXCEPTION
               WHEN no_data_found THEN
                  NULL;
            END;
         END IF;

         IF (p_sl_trx_type = 'PAYMENT' AND p_sl_trx_subtype = 'CORP_CARD') THEN
            IF r_rule_x.enter_amount = '+' THEN
               l_amount := l_amount * -1;
            END IF;

            print_debug('Enter Amount Rule: ' || r_rule_x.enter_amount);
            print_debug('Amount: ' || l_amount);

            l_cc_segment1 := NULL;
            l_cc_segment2 := NULL;
            l_cc_segment3 := NULL;
            l_cc_segment4 := NULL;
            l_cc_segment5 := NULL;
            l_cc_segment6 := NULL;
            l_cc_segment7 := NULL;

            BEGIN
               SELECT gcc.segment1,
                      gcc.segment2,
                      gcc.segment3,
                      gcc.segment4,
                      gcc.segment5,
                      gcc.segment6,
                      gcc.segment7
               INTO   l_cc_segment1,
                      l_cc_segment2,
                      l_cc_segment3,
                      l_cc_segment4,
                      l_cc_segment5,
                      l_cc_segment6,
                      l_cc_segment7
               FROM   ap_expense_report_headers_all aex,
                      per_assignments_f pas,
                      gl_code_combinations_kfv gcc
               WHERE  aex.vouchno = TO_NUMBER(l_token_value)
               AND    aex.org_id = g_org_id
               AND    aex.employee_id = pas.person_id
               AND    pas.default_code_comb_id = gcc.code_combination_id
               AND    (TRUNC(SYSDATE) BETWEEN pas.effective_start_date AND pas.effective_end_date);

               CASE 
                  WHEN r_rule_x.enter_amount = '-' AND SIGN(l_amount) = 1 THEN
                     b_allocate := FALSE;
                     p_sl_tab(l_idx).segment1 := l_cc_segment1;
                     p_sl_tab(l_idx).segment2 := l_cc_segment2;
                     p_sl_tab(l_idx).segment3 := l_cc_segment3;
                     p_sl_tab(l_idx).segment4 := l_cc_segment4;
                     p_sl_tab(l_idx).segment5 := l_cc_segment5;
                     p_sl_tab(l_idx).segment6 := l_cc_segment6;
                     p_sl_tab(l_idx).segment7 := l_cc_segment7;
                  WHEN r_rule_x.enter_amount = '+' AND SIGN(l_amount) = -1 THEN
                     b_allocate := FALSE;
                     EXECUTE IMMEDIATE r_rule_x.sql_query INTO l_cc_segment7 USING l_amount;
                     p_sl_tab(l_idx).segment1 := l_cc_segment1;
                     p_sl_tab(l_idx).segment2 := l_cc_segment2;
                     p_sl_tab(l_idx).segment3 := l_cc_segment3;
                     p_sl_tab(l_idx).segment4 := l_cc_segment4;
                     p_sl_tab(l_idx).segment5 := l_cc_segment5;
                     p_sl_tab(l_idx).segment6 := l_cc_segment6;
                     p_sl_tab(l_idx).segment7 := l_cc_segment7;
                  WHEN r_rule_x.enter_amount = '-' AND SIGN(l_amount) = -1 THEN
                     NULL;
                  WHEN r_rule_x.enter_amount = '+' AND SIGN(l_amount) = 1 THEN
                     NULL;
               END CASE;
            EXCEPTION
               WHEN no_data_found THEN
                  NULL;
            END;
         END IF;

         /* FSC-5494 Corporate Card Aquittal */

         -------------------------------- Corporate Card Transactions --------------------------------

         IF b_allocate THEN
            b_segments := fnd_flex_ext.get_segments(application_short_name => 'SQLGL',
                                                    key_flex_code => 'GL#',
                                                    structure_number => g_coa_id,
                                                    combination_id => l_ccid,
                                                    n_segments => l_segs,
                                                    segments => l_segments_varr);

            p_sl_tab(l_idx).segment1 := l_segments_varr(1);
            p_sl_tab(l_idx).segment2 := l_segments_varr(2);
            p_sl_tab(l_idx).segment3 := NVL(r_rule_x.segment3, l_segments_varr(3));
            p_sl_tab(l_idx).segment4 := NVL(r_rule_x.segment4, l_segments_varr(4));
            p_sl_tab(l_idx).segment5 := NVL(r_rule_x.segment5, l_segments_varr(5));
            p_sl_tab(l_idx).segment6 := NVL(r_rule_x.segment6, l_segments_varr(6));
            p_sl_tab(l_idx).segment7 := NVL(r_rule_x.segment7, l_segments_varr(7));
         END IF;

         p_sl_tab(l_idx).calculate_tax := l_calculate_tax;
         p_sl_tab(l_idx).amount := l_amount;
         p_sl_tab(l_idx).token_name := l_token_name;

         IF p_summary_flag = N THEN
            p_sl_tab(l_idx).token_value := l_token_value;
         END IF;

         print_debug(p_je_header_id || ':' || p_je_line_num || ' => ' ||
                     p_sl_tab(l_idx).segment1 || '-' ||
                     p_sl_tab(l_idx).segment2 || '-' ||
                     p_sl_tab(l_idx).segment3 || '-' ||
                     p_sl_tab(l_idx).segment4 || '-' ||
                     p_sl_tab(l_idx).segment5 || '-' ||
                     p_sl_tab(l_idx).segment6 || '-' ||
                     p_sl_tab(l_idx).segment7 || ':' ||
                     l_amount);

      END LOOP;

      /* FSC-5899 Rounding off at line level */

      ----------------------------------- <START> -----------------------------------
      IF (p_sl_trx_type = 'INVOICE' AND p_sl_trx_subtype = 'CHARGE') THEN
         NULL;
      ELSE
         l_diff_amount := (l_tot_amount_abs - l_jel_amount_abs);
         print_debug('Rounding difference: ' || l_diff_amount);

         CASE SIGN(l_diff_amount)
              WHEN 1 THEN
                 l_diff_amount := l_diff_amount * SIGN(l_tot_amount);
                 p_sl_tab(l_idx).amount := p_sl_tab(l_idx).amount - l_diff_amount;
              WHEN -1 THEN
                 l_diff_amount := l_diff_amount * SIGN(l_tot_amount);
                 p_sl_tab(l_idx).amount := p_sl_tab(l_idx).amount + l_diff_amount;
              ELSE NULL;
         END CASE;
      END IF;
      ------------------------------------ <END> ------------------------------------

   END IF;

   IF c_sl_refcur%ISOPEN THEN
      CLOSE c_sl_refcur;
   END IF;

EXCEPTION
   WHEN no_data_found THEN
      NULL;
   WHEN others THEN
      p_message := SQLERRM;

END get_distribution_lines;

-----------------------------------------------------------
-- Procedure
--    UPDATE_PROCESS
-- Purpose
--    Update TFM and CTL process tables with the status.
-----------------------------------------------------------

PROCEDURE update_process
(
   p_group_id         NUMBER,
   p_process_status   VARCHAR2
)
IS
   pragma     autonomous_transaction;
BEGIN
   UPDATE xxgl_cash_bal_tfm
   SET    process_status = p_process_status
   WHERE  group_id = p_group_id;

   INSERT INTO xxgl_cash_bal_ctl
   SELECT jeh.je_header_id,
          sou.user_je_source_name,
          cat.user_je_category_name,
          DECODE(p_process_status,
                 'SUCCESS', 'S',
                 'ERROR', 'E'),
          g_user_id,
          SYSDATE,
          g_user_id,
          SYSDATE
   FROM   gl_je_headers jeh,
          gl_je_sources sou,
          gl_je_categories cat,
          (SELECT reference22 source_je_header_id,
                  COUNT(1) line_count
           FROM   xxgl_cash_bal_tfm
           WHERE  group_id = p_group_id
           GROUP  BY reference22) csh
   WHERE  jeh.je_header_id = csh.source_je_header_id
   AND    jeh.je_source = sou.je_source_name
   AND    jeh.je_category = cat.je_category_name;

   COMMIT;
END update_process;

------------------------------------------------------------------
-- Procedure
--    RUN_ALLOCATION
-- Purpose
--    Retrieves the source subledger journals then re-allocates
--    the amount value to the correct account codes based on the
--    GL Cash Balancing mapping rules table.
------------------------------------------------------------------

PROCEDURE run_allocation
(
   p_request_id       IN  NUMBER,
   p_group_id         IN  NUMBER,
   p_rule_id          IN  NUMBER,
   p_je_header_id     IN  NUMBER,
   p_je_period_name   IN  VARCHAR2,
   p_source           IN  VARCHAR2,
   p_record_count     OUT NUMBER,
   p_error_count      OUT NUMBER
)
IS
   CURSOR c_jel IS
      SELECT 1 rec_type,
             jel.je_header_id,
             jel.je_line_num,
             jel.effective_date,
             jel.period_name,
             jeh.name journal_name,
             jeb.name batch_name,
             cat.user_je_category_name,
             jeh.currency_code,
             DECODE(rul.target_entity, z_any, gcc.segment1, rul.target_entity) segment1,
             DECODE(rul.target_account, z_any, gcc.segment2, rul.target_account) segment2,
             DECODE(rul.target_cost_centre, z_any, gcc.segment3, rul.target_cost_centre) segment3,
             DECODE(rul.target_authority, z_any, gcc.segment4, rul.target_authority) segment4,
             DECODE(rul.target_project, z_any, gcc.segment5, rul.target_project) segment5,
             DECODE(rul.target_output, z_any, gcc.segment6, rul.target_output) segment6,
             DECODE(rul.target_identifier, z_any, gcc.segment7, rul.target_identifier) segment7,
             jel.code_combination_id,
             jel.description,
             jel.reference_5 gst_recoup,
             rul.rule_id,
             rul.rule_num,
             rul.allocation_type rule_type,
             rul.sl_trx_type,
             rul.sl_trx_subtype,
             rul.entity_offset_flag,
             rul.default_value_flag,
             rul.summary_flag,
             rul.enter_amount,
             rul.filter_condition_line1,
             rul.filter_condition_line2,
             (NVL(jel.entered_dr, 0) + NVL(jel.entered_cr, 0)) amount,
             CASE WHEN rul.sl_trx_subtype = 'CORP_CARD' AND rul.enter_amount = '+' THEN 'DR'
                  WHEN rul.sl_trx_subtype = 'CORP_CARD' AND rul.enter_amount = '-' THEN 'CR'
                  WHEN rul.sl_trx_subtype = 'INV_REC' THEN 'DR'
                  WHEN rul.sl_trx_subtype = 'CM_REC' THEN 'DR'
                  WHEN rul.sl_trx_subtype = 'TRADE_REC' THEN 'CR'
                  WHEN rul.sl_trx_subtype = 'TRADE_CASH' THEN 'DR'
                  WHEN rul.sl_trx_subtype = 'MISC_CASH' THEN 'DR'
                  WHEN rul.sl_trx_subtype = 'LIABILITY' THEN 'CR'
                  -- Reconciled Payments
                  WHEN rul.sl_trx_subtype = 'CASH' THEN 'CR'
                  -- Remain unclassified
                  /*
                  WHEN rul.sl_trx_subtype = 'TRADE_UNAPP' THEN 'CR'
                  WHEN rul.sl_trx_subtype = 'RECOVERABLE_TAX' THEN 'DR'
                  WHEN rul.sl_trx_subtype = 'INV_TAX' THEN 'CR'
                  WHEN rul.sl_trx_subtype = 'CM_TAX' THEN 'DR'
                  WHEN rul.sl_trx_subtype = 'MISC_TAX' THEN 'CR'
                  */
                  ELSE CASE WHEN NVL(jel.entered_dr, 0) > 0 THEN 'DR'
                            WHEN NVL(jel.entered_cr, 0) > 0 THEN 'CR'
                       END
             END dr_cr
      FROM   gl_je_lines jel,
             gl_je_headers jeh,
             gl_je_batches jeb,
             gl_sets_of_books gsb,
             gl_code_combinations gcc,
             gl_je_sources src,
             gl_je_categories cat,
             xxgl_cash_bal_rules_all rul
      WHERE  jel.je_header_id = jeh.je_header_id
      AND    jeh.je_batch_id = jeb.je_batch_id
      AND    jeh.period_name = p_je_period_name --g_period_name
      AND    jeh.actual_flag = z_actual_flag
      AND    jel.code_combination_id = gcc.code_combination_id
      AND    jeh.set_of_books_id = gsb.set_of_books_id
      AND    jeh.je_header_id = p_je_header_id
      AND    jeh.je_source = src.je_source_name
      AND    jeh.je_category = cat.je_category_name
      AND    jeh.set_of_books_id = rul.set_of_books_id
      AND    jeh.reversed_je_header_id IS NULL -- added 2017/07/11
      AND    src.user_je_source_name = rul.journal_source
      AND    cat.user_je_category_name = rul.journal_category
      AND    rul.rule_id = p_rule_id
      AND    gcc.segment1 LIKE DECODE(rul.source_entity, z_any, gcc.segment1, rul.source_entity)
      AND    gcc.segment2 LIKE DECODE(rul.source_account, z_any, gcc.segment2, rul.source_account)
      AND    gcc.segment3 LIKE DECODE(rul.source_cost_centre, z_any, gcc.segment3, rul.source_cost_centre)
      AND    gcc.segment4 LIKE DECODE(rul.source_authority, z_any, gcc.segment4, rul.source_authority)
      AND    gcc.segment5 LIKE DECODE(rul.source_project, z_any, gcc.segment5, rul.source_project)
      AND    gcc.segment6 LIKE DECODE(rul.source_output, z_any, gcc.segment6, rul.source_output)
      AND    gcc.segment7 LIKE DECODE(rul.source_identifier, z_any, gcc.segment7, rul.source_identifier)
      AND    ((rul.sl_trx_subtype <> 'CORP_CARD' AND (NVL(jel.entered_dr, 0) - NVL(jel.entered_cr, 0)) <> 0) 
             OR 
              (rul.sl_trx_subtype = 'CORP_CARD' AND (NVL(jel.entered_dr, 0) - NVL(jel.entered_cr, 0)) = 0))
      AND    rul.org_id = g_org_id
      UNION ALL
      -- FSC-5721
      SELECT 2 rec_type,
             jel.je_header_id,
             jel.je_line_num,
             jel.effective_date,
             jel.period_name,
             jeh.name journal_name,
             jeb.name batch_name,
             cat.user_je_category_name,
             jeh.currency_code,
             DECODE(rul.target_entity, z_any, gcc.segment1, rul.target_entity) segment1,
             DECODE(rul.target_account, z_any, gcc.segment2, rul.target_account) segment2,
             DECODE(rul.target_cost_centre, z_any, gcc.segment3, rul.target_cost_centre) segment3,
             DECODE(rul.target_authority, z_any, gcc.segment4, rul.target_authority) segment4,
             DECODE(rul.target_project, z_any, gcc.segment5, rul.target_project) segment5,
             DECODE(rul.target_output, z_any, gcc.segment6, rul.target_output) segment6,
             DECODE(rul.target_identifier, z_any, gcc.segment7, rul.target_identifier) segment7,
             jel.code_combination_id,
             jel.description,
             jel.reference_5 gst_recoup,
             rul.rule_id,
             rul.rule_num,
             rul.allocation_type rule_type,
             'INVOICE' sl_trx_type,
             'CHARGE' sl_trx_subtype,
             rul.entity_offset_flag,
             rul.default_value_flag,
             rul.summary_flag,
             rul.enter_amount,
             rul.filter_condition_line1,
             rul.filter_condition_line2,
             (NVL(jel.entered_dr, 0) + NVL(jel.entered_cr, 0)) amount,
             CASE WHEN NVL(jel.entered_dr, 0) > 0 THEN 'DR'
                  WHEN NVL(jel.entered_cr, 0) > 0 THEN 'CR'
             END dr_cr
      FROM   gl_je_lines jel,
             gl_je_headers jeh,
             gl_je_batches jeb,
             ap_ae_headers_all aeh,
             ap_ae_lines_all ael,
             ap_invoice_distributions_all apd,
             ap_invoices_all api,
             gl_sets_of_books gsb,
             gl_code_combinations gcc,
             gl_je_sources src,
             gl_je_categories cat,
             xxgl_cash_bal_rules_all rul
      WHERE  jeh.je_header_id = p_je_header_id
      AND    jeh.period_name = p_je_period_name
      AND    jeh.je_header_id = jel.je_header_id
      AND    jeh.je_batch_id = jeb.je_batch_id
      AND    jeh.set_of_books_id = gsb.set_of_books_id
      AND    jeh.je_source = src.je_source_name
      AND    jeh.je_category = cat.je_category_name
      AND    rul.rule_id = p_rule_id
      AND    jeh.reversed_je_header_id IS NULL
      AND    jeh.set_of_books_id = rul.set_of_books_id
      AND    src.user_je_source_name = rul.journal_source
      AND    cat.user_je_category_name = rul.journal_category
      AND    api.accts_pay_code_combination_id = gcc.code_combination_id
      AND    jel.gl_sl_link_id = ael.gl_sl_link_id
      AND    ael.source_table = 'AP_INVOICE_DISTRIBUTIONS'
      AND    ael.ae_line_type_code = 'CHARGE'
      AND    ael.ae_header_id = aeh.ae_header_id
      AND    ael.source_id = apd.invoice_distribution_id
      AND    apd.invoice_id = api.invoice_id
      AND    aeh.accounting_event_id = apd.accounting_event_id
      AND    aeh.period_name = jel.period_name
      AND    aeh.trial_balance_flag = Y
      AND    aeh.gl_transfer_flag = Y
      AND    aeh.gl_transfer_run_id IS NOT NULL
      AND    gcc.segment1 LIKE DECODE(rul.source_entity, z_any, gcc.segment1, rul.source_entity)
      AND    gcc.segment2 LIKE DECODE(rul.source_account, z_any, gcc.segment2, rul.source_account)
      AND    gcc.segment3 LIKE DECODE(rul.source_cost_centre, z_any, gcc.segment3, rul.source_cost_centre)
      AND    gcc.segment4 LIKE DECODE(rul.source_authority, z_any, gcc.segment4, rul.source_authority)
      AND    gcc.segment5 LIKE DECODE(rul.source_project, z_any, gcc.segment5, rul.source_project)
      AND    gcc.segment6 LIKE DECODE(rul.source_output, z_any, gcc.segment6, rul.source_output)
      AND    gcc.segment7 LIKE DECODE(rul.source_identifier, z_any, gcc.segment7, rul.source_identifier)
      AND    (NVL(jel.entered_dr, 0) - NVL(jel.entered_cr, 0)) <> 0
      AND    rul.org_id = g_org_id
      ORDER  BY 1, 3;

   t_sl_tab             t_sl_tab_type;
   r_jel                c_jel%ROWTYPE;
   l_message            VARCHAR2(600);
   l_error_count        NUMBER := 0;
   l_gst_flag           VARCHAR2(1);
   l_alloc_count        NUMBER := 0;
   l_dr                 NUMBER;
   l_cr                 NUMBER;
   l_dr_tot             NUMBER;
   l_cr_tot             NUMBER;
   l_new_amount         NUMBER;
   l_sql                VARCHAR2(32767);
   l_gst_recoup_batch   VARCHAR2(150) := 'GST RECOUP for';
   l_segment1           VARCHAR2(25);
   l_segment2           VARCHAR2(25);
   l_segment3           VARCHAR2(25);
   l_segment4           VARCHAR2(25);
   l_segment5           VARCHAR2(25);
   l_segment6           VARCHAR2(25);
   l_segment7           VARCHAR2(25);
   l_rec_type           NUMBER;
   l_record_ids         VARCHAR2(1000);
BEGIN
   OPEN c_jel;
   LOOP
      FETCH c_jel INTO r_jel;
      EXIT WHEN c_jel%NOTFOUND;

      IF l_rec_type IS NULL THEN
         l_rec_type := r_jel.rec_type;
      ELSE
         IF l_rec_type <> r_jel.rec_type THEN
            EXIT;
         END IF;
      END IF;

      /* Debug */
      print_debug('run_allocation=' || r_jel.je_header_id || '-' || r_jel.je_line_num || '-' || r_jel.rule_num);
      print_debug('sl_trx_type=' || r_jel.sl_trx_type || ' sl_trx_subtype=' || r_jel.sl_trx_subtype);

      l_message := NULL;
      l_gst_flag := NULL;
      t_sl_tab.DELETE;

      /* Stage Phase */
      IF r_jel.rule_type = 'CSH' THEN
         get_distribution_lines(r_jel.rule_id,
                                p_source,
                                r_jel.je_header_id,
                                r_jel.je_line_num,
                                r_jel.amount,
                                r_jel.sl_trx_type,
                                r_jel.sl_trx_subtype,
                                r_jel.summary_flag,
                                t_sl_tab,
                                l_message);

         /* Debug */
         print_debug('sl_distribution_lines=' || t_sl_tab.COUNT);

         IF t_sl_tab.COUNT > 0 AND l_message IS NULL THEN
            l_record_ids := NULL;
            l_new_amount := NULL;
            l_dr_tot := 0;
            l_cr_tot := 0;

            FOR i IN 1 .. t_sl_tab.COUNT LOOP
               l_alloc_count := l_alloc_count + 1;
               l_dr := NULL;
               l_cr := NULL;
               CASE
                  WHEN r_jel.enter_amount = '+' AND r_jel.dr_cr = 'DR' AND SIGN(t_sl_tab(i).amount) = 1 THEN
                     l_dr := t_sl_tab(i).amount;
                  WHEN r_jel.enter_amount = '+' AND r_jel.dr_cr = 'CR' AND SIGN(t_sl_tab(i).amount) = 1 THEN
                     l_cr := t_sl_tab(i).amount;
                  WHEN r_jel.enter_amount = '-' AND r_jel.dr_cr = 'DR' AND SIGN(t_sl_tab(i).amount) = 1 THEN
                     l_cr := t_sl_tab(i).amount;
                  WHEN r_jel.enter_amount = '-' AND r_jel.dr_cr = 'CR' AND SIGN(t_sl_tab(i).amount) = 1 THEN
                     l_dr := t_sl_tab(i).amount;
                  WHEN r_jel.enter_amount = '+' AND r_jel.dr_cr = 'DR' AND SIGN(t_sl_tab(i).amount) = 0 THEN
                     l_dr := t_sl_tab(i).amount;
                  WHEN r_jel.enter_amount = '+' AND r_jel.dr_cr = 'CR' AND SIGN(t_sl_tab(i).amount) = 0 THEN
                     l_cr := t_sl_tab(i).amount;
                  WHEN r_jel.enter_amount = '-' AND r_jel.dr_cr = 'DR' AND SIGN(t_sl_tab(i).amount) = 0 THEN
                     l_cr := t_sl_tab(i).amount;
                  WHEN r_jel.enter_amount = '-' AND r_jel.dr_cr = 'CR' AND SIGN(t_sl_tab(i).amount) = 0 THEN
                     l_dr := t_sl_tab(i).amount;
                  WHEN r_jel.enter_amount = '+' AND r_jel.dr_cr = 'DR' AND SIGN(t_sl_tab(i).amount) = -1 THEN
                     l_cr := ABS(t_sl_tab(i).amount);
                  WHEN r_jel.enter_amount = '+' AND r_jel.dr_cr = 'CR' AND SIGN(t_sl_tab(i).amount) = -1 THEN
                     l_dr := ABS(t_sl_tab(i).amount);
                  WHEN r_jel.enter_amount = '-' AND r_jel.dr_cr = 'DR' AND SIGN(t_sl_tab(i).amount) = -1 THEN
                     l_dr := ABS(t_sl_tab(i).amount);
                  WHEN r_jel.enter_amount = '-' AND r_jel.dr_cr = 'CR' AND SIGN(t_sl_tab(i).amount) = -1 THEN
                     l_cr := ABS(t_sl_tab(i).amount);
                  ELSE
                     print_debug('Line entry not created due to null or zero amount value');
                     CONTINUE;
               END CASE;

               IF r_jel.entity_offset_flag = Y THEN
                  l_segment1 := t_sl_tab(i).segment1;
               ELSE
                  l_segment1 := r_jel.segment1;
               END IF;

               l_segment2 := r_jel.segment2;

               IF r_jel.default_value_flag = Y THEN
                  l_segment3 := t_sl_tab(i).segment3;
                  l_segment4 := t_sl_tab(i).segment4;
                  l_segment5 := t_sl_tab(i).segment5;
                  l_segment6 := t_sl_tab(i).segment6;
                  l_segment7 := t_sl_tab(i).segment7;
               ELSE
                  l_segment3 := r_jel.segment3;
                  l_segment4 := r_jel.segment4;
                  l_segment5 := r_jel.segment5;
                  l_segment6 := r_jel.segment6;
                  l_segment7 := r_jel.segment7;
               END IF;

               INSERT INTO xxgl_cash_bal_stg
               VALUES(xxgl_cash_bal_record_id_s.NEXTVAL,
                      p_request_id,
                      p_group_id,
                      r_jel.batch_name,
                      r_jel.je_header_id,
                      r_jel.je_line_num,
                      r_jel.rule_id,
                      r_jel.rule_num,
                      p_source,
                      r_jel.sl_trx_type,
                      r_jel.sl_trx_subtype,
                      t_sl_tab(i).token_name,
                      t_sl_tab(i).token_value,
                      l_segment1,
                      l_segment2,
                      l_segment3,
                      l_segment4,
                      l_segment5,
                      l_segment6,
                      l_segment7,
                      l_dr,
                      l_cr,
                      r_jel.summary_flag,
                      SYSDATE,
                      g_user_id);

               l_dr_tot := l_dr_tot + NVL(l_dr, 0);
               l_cr_tot := l_cr_tot + NVL(l_cr, 0);

               IF l_record_ids IS NOT NULL THEN
                  l_record_ids := l_record_ids || ', ';
               END IF;

               l_record_ids := l_record_ids || xxgl_cash_bal_record_id_s.CURRVAL;

            END LOOP;
         ELSE
            IF l_message IS NOT NULL THEN
               l_error_count := l_error_count + 1;
               fnd_file.put_line(fnd_file.log, z_error ||
                                 l_message || ' (' ||
                                 r_jel.je_header_id || '-' ||
                                 r_jel.je_line_num || '-' ||
                                 r_jel.rule_num || ')');
            END IF;
         END IF;

      ELSIF r_jel.rule_type = 'GST' THEN
         BEGIN
            IF r_jel.filter_condition_line1 IS NOT NULL THEN
               l_sql := r_jel.filter_condition_line1;
               EXECUTE IMMEDIATE l_sql INTO l_gst_flag USING r_jel.code_combination_id;
            END IF;

            l_alloc_count := l_alloc_count + 1;
            l_dr := NULL;
            l_cr := NULL;

            CASE
               WHEN r_jel.enter_amount = '+' AND r_jel.dr_cr = 'DR' THEN
                  l_dr := r_jel.amount;
               WHEN r_jel.enter_amount = '+' AND r_jel.dr_cr = 'CR' THEN
                  l_cr := r_jel.amount;
               WHEN r_jel.enter_amount = '-' AND r_jel.dr_cr = 'DR' THEN
                  l_cr := r_jel.amount;
               WHEN r_jel.enter_amount = '-' AND r_jel.dr_cr = 'CR' THEN
                  l_dr := r_jel.amount;
            END CASE;

            INSERT INTO xxgl_cash_bal_stg
            VALUES (xxgl_cash_bal_record_id_s.NEXTVAL,
                    p_request_id,
                    p_group_id,
                    (l_gst_recoup_batch || ' ' || p_je_period_name),
                    r_jel.je_header_id,
                    r_jel.je_line_num,
                    r_jel.rule_id,
                    r_jel.rule_num,
                    p_source,
                    r_jel.sl_trx_type,
                    r_jel.sl_trx_subtype,
                    (l_gst_recoup_batch || ' ' || p_je_period_name || ' ' || r_jel.description),
                    NULL,
                    r_jel.segment1,
                    r_jel.segment2,
                    r_jel.segment3,
                    r_jel.segment4,
                    r_jel.segment5,
                    r_jel.segment6,
                    r_jel.segment7,
                    l_dr,
                    l_cr,
                    r_jel.summary_flag,
                    SYSDATE,
                    g_user_id);
         EXCEPTION
            WHEN no_data_found THEN
               print_debug('Filter Condition: ' || l_sql);
            WHEN others THEN
               l_error_count := l_error_count + 1;
               fnd_file.put_line(fnd_file.log, z_error || SQLERRM || ' (' ||
                                 r_jel.je_header_id || '-' ||
                                 r_jel.je_line_num || '-' ||
                                 r_jel.rule_num || ')');
         END;
      END IF;

      <<next_record>>
      NULL; -- Skip

   END LOOP;
   CLOSE c_jel;

   p_record_count := l_alloc_count;
   p_error_count := l_error_count;

EXCEPTION
   WHEN others THEN
      p_record_count := 0;
      p_error_count := 1;
      fnd_file.put_line(fnd_file.log, z_error || 'run_allocation');
      fnd_file.put_line(fnd_file.log, z_error || SQLERRM);

END run_allocation;

-------------------------------------------------------
-- Procedure
--    CREATE_JOURNALS
-- Purpose
--    Main calling program that runs the allocation,
--    validation and GL Import processes.
-------------------------------------------------------

PROCEDURE create_journals
(
   p_errbuff            OUT VARCHAR2,
   p_retcode            OUT NUMBER,
   p_set_of_books_id    IN  NUMBER,
   p_effective_date     IN  VARCHAR2,
   p_period_name        IN  VARCHAR2,
   p_source             IN  VARCHAR2,
   p_je_batch_id        IN  NUMBER,
   p_je_header_id       IN  NUMBER,
   p_force_flag         IN  VARCHAR2,
   p_test_flag          IN  VARCHAR2,
   p_debug_flag         IN  VARCHAR2
)
IS
   CURSOR c_rule (p_run_status VARCHAR2) IS
      SELECT rule_id,
             rule_num,
             allocation_type,
             journal_source,
             journal_category
      FROM   xxgl_cash_bal_rules_all
      WHERE  org_id = g_org_id
      AND    journal_source = p_source
      AND    status = p_run_status;

   CURSOR c_batch IS
      SELECT j.je_header_id,
             j.je_source,
             j.je_category,
             j.status
      FROM   gl_je_headers j,
             gl_je_sources s
      WHERE  j.period_name = p_period_name
      AND    j.set_of_books_id = p_set_of_books_id
      AND    j.je_source = s.je_source_name
      AND    s.user_je_source_name = p_source
      AND    (p_je_batch_id IS NULL OR
             (p_je_batch_id IS NOT NULL AND p_je_batch_id = j.je_batch_id))
      AND    (p_je_header_id IS NULL OR
             (p_je_header_id IS NOT NULL AND p_je_header_id = j.je_header_id));

   r_rule                 c_rule%ROWTYPE;
   r_batch                c_batch%ROWTYPE;
   l_effective_date       DATE;
   l_accounting_date      DATE;
   l_request_id           NUMBER;
   l_group_id             NUMBER;
   l_record_count         NUMBER;
   l_error_count          NUMBER;
   l_stg_record_count     NUMBER := 0;
   l_stg_error_count      NUMBER := 0;
   l_tfm_error_count      NUMBER := 0;
   l_import_request_id    NUMBER;
   l_exists_count         NUMBER;
   l_control_run_id       NUMBER;
   l_control_source       gl_je_sources.je_source_name%TYPE;
   l_closing_status       gl_period_statuses.closing_status%TYPE;
   l_run_status           VARCHAR2(25);
   l_process_status       VARCHAR2(25);
   e_posted_journal       EXCEPTION;

   -- SRS --
   srs_wait               BOOLEAN;
   srs_phase              VARCHAR2(30);
   srs_status             VARCHAR2(30);
   srs_dev_phase          VARCHAR2(30);
   srs_dev_status         VARCHAR2(30);
   srs_message            VARCHAR2(240);

BEGIN
   fnd_profile.get('USER_ID', g_user_id);
   fnd_profile.get('ORG_ID', g_org_id);

   l_request_id := fnd_global.conc_request_id;
   l_run_status := 'APPLY';
   l_effective_date := fnd_date.canonical_to_date(p_effective_date);
   l_accounting_date := NVL(l_effective_date, TRUNC(SYSDATE));
   g_sob_id := p_set_of_books_id;
   g_debug_flag := NVL(p_debug_flag, N);

   -- Clean-up
   purge_processed_data;

   IF NVL(p_debug_flag, N) = N THEN
      fnd_file.put_line(fnd_file.log, 'Debug is disabled.');
   END IF;

   /* Debug */
   print_debug('=======================================================');
   print_debug('batch_id=' || NVL(TO_CHAR(p_je_batch_id), 'ALL'));
   print_debug('journal_source=' || p_source);
   print_debug('accounting_date=' || l_accounting_date);
   print_debug('set_of_books_id=' || g_sob_id);
   print_debug('request_id=' || l_request_id);
   print_debug('run_status=' || l_run_status);

   BEGIN
      SELECT gper.period_name,
             gper.closing_status
      INTO   g_period_name,
             l_closing_status
      FROM   gl_sets_of_books gsob,
             gl_period_statuses gper,
             gl_period_types gtyp
      WHERE  gsob.set_of_books_id = p_set_of_books_id
      AND    gsob.set_of_books_id = gper.set_of_books_id
      AND    NVL(gper.adjustment_period_flag, N) = N
      AND    gper.period_type = gtyp.period_type
      AND    UPPER(gtyp.user_period_type) = z_period_type
      AND    gper.application_id = z_appl_id
      AND    (l_accounting_date BETWEEN gper.start_date AND gper.end_date);
   EXCEPTION
      WHEN no_data_found THEN
         fnd_file.put_line(fnd_file.log, z_error || 'Unable to determine period for accounting date ' || l_accounting_date || '.');
         p_retcode := 2;
         RETURN;
   END;

   IF NVL(p_test_flag, N) = Y THEN
      l_run_status := 'TEST';
   ELSE
      IF NVL(p_force_flag, N) = N THEN
         IF l_closing_status NOT IN ('F', 'O') THEN
            fnd_file.put_line(fnd_file.log, z_error || 'Accounting Date is not in an open period.');
            p_retcode := 2;
            RETURN;
         END IF;
      END IF;
   END IF;

   /* Debug */
   print_debug('posting_period_name=' || g_period_name);
   print_debug('journal_period_name=' || p_period_name);

   SELECT user_je_source_name
   INTO   l_control_source
   FROM   gl_je_sources
   WHERE  user_je_source_name = z_journal_source;

   /* Debug */
   print_debug('control_source=' || l_control_source);

   SELECT chart_of_accounts_id
   INTO   g_coa_id
   FROM   gl_sets_of_books
   WHERE  set_of_books_id = p_set_of_books_id;

   /* Debug */
   print_debug('coa_id=' || g_coa_id);

   SELECT xxgl_cash_bal_group_id_s.NEXTVAL
   INTO   l_group_id
   FROM   dual;

   /* Debug */
   print_debug('group_id=' || l_group_id);
   print_debug('=======================================================');

   ------------
   -- Stage  --
   ------------
   OPEN c_batch;
   LOOP
      FETCH c_batch INTO r_batch;
      EXIT WHEN c_batch%NOTFOUND;

      print_debug(r_batch.je_header_id);

      BEGIN
         SELECT COUNT(1)
         INTO   l_exists_count
         FROM   xxgl_cash_bal_ctl ctl
         WHERE  ctl.je_header_id = r_batch.je_header_id
         AND    ctl.balancing_status IN ('S', 'W', 'C');

         IF (l_exists_count > 0 OR r_batch.status = z_posted) AND
            (NVL(p_force_flag, N) = N) THEN
            RAISE e_posted_journal;
         END IF;

         OPEN c_rule(l_run_status);
         LOOP
            FETCH c_rule INTO r_rule;
            EXIT WHEN c_rule%NOTFOUND;

            print_debug(r_batch.je_header_id || '-' || r_rule.rule_num);

            run_allocation(p_request_id => l_request_id,
                           p_group_id => l_group_id,
                           p_rule_id => r_rule.rule_id,
                           p_je_header_id => r_batch.je_header_id,
                           p_je_period_name => p_period_name,
                           p_source => r_rule.journal_source,
                           p_record_count => l_record_count,
                           p_error_count => l_error_count);

            l_stg_record_count := l_stg_record_count + l_record_count;
            l_stg_error_count := l_stg_error_count + l_error_count;

         END LOOP;
         CLOSE c_rule;

      EXCEPTION
         WHEN e_posted_journal THEN
            NULL;
      END;
   END LOOP;
   CLOSE c_batch;

   IF l_stg_record_count > 0 THEN
      COMMIT;
   ELSE
      IF l_run_status = 'TEST' THEN
         print_debug('Unable to find a rule with status of TEST.');
      ELSE
         print_debug('Unable to find any rule that can be associated with this journal batch.');
      END IF;
      RETURN;
   END IF;

   ----------------
   -- Transform  --
   ----------------
   validate_interface_lines(l_request_id, l_group_id, l_accounting_date, l_tfm_error_count);

   IF l_run_status = 'APPLY' THEN
      -----------
      -- Load  --
      -----------
      IF l_tfm_error_count = 0 THEN
         gl_journal_import_pkg.populate_interface_control(user_je_source_name => l_control_source,
                                                          group_id => l_group_id,
                                                          set_of_books_id => p_set_of_books_id,
                                                          interface_run_id => l_control_run_id,
                                                          -- FSC-5823 arellad 2017/11/09
                                                          -- processed_data_action => gl_journal_import_pkg.SAVE_DATA);
                                                          processed_data_action => gl_journal_import_pkg.DELETE_DATA);

         l_import_request_id := fnd_request.submit_request(application => 'SQLGL',
                                                           program => 'GLLEZL',
                                                           description => NULL,
                                                           start_time => NULL,
                                                           sub_request => FALSE,
                                                           argument1 => l_control_run_id,
                                                           argument2 => p_set_of_books_id,
                                                           argument3 => N,
                                                           argument4 => NULL,
                                                           argument5 => NULL,
                                                           argument6 => N,
                                                           argument7 => N);

         /* Debug */
         print_debug('control_run_id=' || l_control_run_id);
         print_debug('import_request_id=' || l_import_request_id);

         -- Commit Submit Request
         COMMIT;

         srs_wait := fnd_concurrent.wait_for_request(l_import_request_id,
                                                     z_wait_time,
                                                     0,
                                                     srs_phase,
                                                     srs_status,
                                                     srs_dev_phase,
                                                     srs_dev_status,
                                                     srs_message);

         IF NOT srs_dev_phase = 'COMPLETE' THEN
            l_process_status := 'ERROR';
            p_retcode := 2;
         ELSE
            IF srs_dev_status = 'NORMAL' THEN
               l_process_status := 'SUCCESS';
            ELSE
               l_process_status := 'ERROR';
               p_retcode := 2;
            END IF;
         END IF;

         update_process(l_group_id, l_process_status);
      ELSE
         fnd_file.put_line(fnd_file.log, z_error || 'Errors found during transformation');
         print_debug('tfm_error_count=' || l_tfm_error_count);
         p_retcode := 2;
      END IF;

   ELSIF l_run_status = 'TEST' THEN
      -----------------
      -- TEST report --
      -----------------
      run_test_report(l_request_id, l_accounting_date);
   END IF;

EXCEPTION
   WHEN others THEN
      RAISE;

END create_journals;

-------------------------------------------------------
-- Procedure
--    VALIDATE_INTERFACE_LINES
-- Purpose
--    Validate and transfer staging data to TFM and
--    GL_INTERFACE table.
-------------------------------------------------------

PROCEDURE validate_interface_lines
(
   p_request_id       IN  NUMBER,
   p_group_id         IN  NUMBER,
   p_accounting_date  IN  DATE,
   p_error_count      OUT NUMBER
)
IS
   CURSOR c_stg IS
      SELECT sl_source,
             source_batch,
             source_je_header_id,
             /*
             DECODE(sl_source, 'Payables', '0',
                               'Receivables', DECODE(summary_flag, N, source_je_line_num, 0),
                               source_je_line_num) source_je_line_num,
             */
             DECODE(summary_flag, N, source_je_line_num, 0) source_je_line_num,
             DECODE(summary_flag, N, 1, 2) order_by,
             CASE
                WHEN sl_source = 'Receivables' THEN
                   DECODE(summary_flag, N,
                          LTRIM(token_name || ' ') || token_value || ' (' || source_je_header_id || '-' || source_je_line_num || '-' || rule_num || ')',
                          token_name || ' (' || source_je_header_id || '-0-' || rule_num || ')')
                WHEN sl_source = 'Payables' THEN
                   token_name || ' (' || source_je_header_id || '-' || rule_num || ')'
                ELSE
                   token_name || ' (' || rule_num || ')'
             END description,
             rule_num,
             segment1,
             segment2,
             segment3,
             segment4,
             segment5,
             segment6,
             segment7,
             segment1 || z_acct_del ||
             segment2 || z_acct_del ||
             segment3 || z_acct_del ||
             segment4 || z_acct_del ||
             segment5 || z_acct_del ||
             segment6 || z_acct_del ||
             segment7 account_code,
             SUM(entered_dr) entered_dr,
             SUM(entered_cr) entered_cr
      FROM   xxgl_cash_bal_stg
      WHERE  request_id = p_request_id
      AND    group_id = p_group_id
      GROUP  BY
             DECODE(sl_trx_subtype, 'CORP_CARD', record_id, 0),
             sl_source,
             source_batch,
             source_je_header_id,
             /*
             DECODE(sl_source, 'Payables', '0',
                               'Receivables', DECODE(summary_flag, N, source_je_line_num, 0),
                               source_je_line_num),
             */
             DECODE(summary_flag, N, source_je_line_num, 0),
             DECODE(summary_flag, N, 1, 2),
             CASE
                WHEN sl_source = 'Receivables' THEN
                   DECODE(summary_flag, N,
                          LTRIM(token_name || ' ') || token_value || ' (' || source_je_header_id || '-' || source_je_line_num || '-' || rule_num || ')',
                          token_name || ' (' || source_je_header_id || '-0-' || rule_num || ')')
                WHEN sl_source = 'Payables' THEN
                   token_name || ' (' || source_je_header_id || '-' || rule_num || ')'
                ELSE
                   token_name || ' (' || rule_num || ')'
             END,
             rule_num,
             segment1,
             segment2,
             segment3,
             segment4,
             segment5,
             segment6,
             segment7
     ORDER BY 1, 2, DECODE(summary_flag, N, 1, 2);

   CURSOR c_tfm IS
      SELECT tfm.ROWID row_id,
             tfm.*
      FROM   xxgl_cash_bal_tfm tfm
      WHERE  request_id = p_request_id
      AND    group_id = p_group_id;

   l_dr                NUMBER;
   l_cr                NUMBER;
   l_amount            NUMBER;
   l_ccid              NUMBER;
   l_error_count       NUMBER := 0;
   l_validated_count   NUMBER := 0;
   l_status            VARCHAR2(30);
   l_batch_name        VARCHAR2(150);
   l_category          xxgl_cash_bal_tfm.user_je_category_name%TYPE;
   l_message           VARCHAR2(340);
   r_stg               c_stg%ROWTYPE;
   r_tfm               c_tfm%ROWTYPE;
   PRAGMA              autonomous_transaction;
BEGIN
   /* Debug */
   print_debug('load_interface_lines');

   OPEN c_stg;
   LOOP
      FETCH c_stg INTO r_stg;
      EXIT WHEN c_stg%NOTFOUND;

      l_batch_name := 'Sourced from ' || r_stg.source_batch;
      l_validated_count := l_validated_count + 1;
      l_status := 'VALIDATED';
      l_message := NULL;
      l_ccid := fnd_flex_ext.get_ccid(application_short_name => 'SQLGL',
                                      key_flex_code => 'GL#',
                                      structure_number => g_coa_id,
                                      validation_date => NULL,
                                      concatenated_segments => r_stg.account_code);
      /*
      PS 10/07: Account combination validation
      Should fire only during GL Import
      IF l_ccid = 0 THEN
         l_error_count := l_error_count + 1;
         l_status := 'ERROR';
         l_message := 'Invalid account combination';
         fnd_file.put_line(fnd_file.log, z_error ||
                                         l_message || ' (' ||
                                         r_stg.source_je_header_id || '-' ||
                                         r_stg.source_je_line_num || '-' ||
                                         r_stg.rule_num || ')');
      END IF;
      */

      CASE r_stg.sl_source
         WHEN 'Receivables' THEN l_category := z_receivables_adj;
         WHEN 'Payables' THEN l_category := z_payables_adj;
         WHEN 'Cash Balancing' THEN l_category := z_adjustment;
      END CASE;

      INSERT INTO xxgl_cash_bal_tfm
      VALUES (p_request_id,
              p_group_id,
              z_interface_status,
              g_sob_id,
              z_journal_source,
              l_category,
              p_accounting_date,
              z_currency_code,
              SYSDATE,
              g_user_id,
              z_actual_flag,
              r_stg.segment1,
              r_stg.segment2,
              r_stg.segment3,
              r_stg.segment4,
              r_stg.segment5,
              r_stg.segment6,
              r_stg.segment7,
              r_stg.entered_dr,
              r_stg.entered_cr,
              l_batch_name,                          --reference2
              NULL,                                  --reference4
              r_stg.description,                     --reference10
              r_stg.rule_num,                        --reference21
              r_stg.source_je_header_id,             --reference22
              r_stg.source_je_line_num,              --reference23
              p_group_id,                            --reference24
              NULL,                                  --reference25
              NULL,                                  --summary_flag
              l_status,
              l_message,
              SYSDATE,
              g_user_id,
              SYSDATE);

   END LOOP;
   CLOSE c_stg;

   IF l_validated_count > 0 THEN
      COMMIT;
   END IF;

   p_error_count := NVL(l_error_count, 0);

   IF l_error_count > 0 THEN
      RETURN;
   END IF;

   OPEN c_tfm;
   LOOP
      FETCH c_tfm INTO r_tfm;
      EXIT WHEN c_tfm%NOTFOUND;

      l_dr := NULL;
      l_cr := NULL;

      IF NVL(r_tfm.entered_dr, 0) > 0 AND
         NVL(r_tfm.entered_cr, 0) > 0 THEN
         l_amount := (r_tfm.entered_dr - r_tfm.entered_cr);

         IF SIGN(l_amount) = 1 THEN
            l_dr := l_amount;
         ELSE
            l_cr := ABS(l_amount);
         END IF;
      ELSE
         l_dr := r_tfm.entered_dr;
         l_cr := r_tfm.entered_cr;
      END IF;

      INSERT INTO gl_interface
             (group_id,
              status,
              set_of_books_id,
              user_je_source_name,
              user_je_category_name,
              accounting_date,
              currency_code,
              date_created,
              created_by,
              actual_flag,
              segment1,
              segment2,
              segment3,
              segment4,
              segment5,
              segment6,
              segment7,
              entered_dr,
              entered_cr,
              reference2,
              reference4,
              reference10,
              reference21,
              reference22,
              reference23,
              reference24,
              reference25)
      VALUES (r_tfm.group_id,
              r_tfm.status,
              r_tfm.set_of_books_id,
              r_tfm.user_je_source_name,
              r_tfm.user_je_category_name,
              r_tfm.accounting_date,
              r_tfm.currency_code,
              r_tfm.date_created,
              r_tfm.created_by,
              r_tfm.actual_flag,
              r_tfm.segment1,
              r_tfm.segment2,
              r_tfm.segment3,
              r_tfm.segment4,
              r_tfm.segment5,
              r_tfm.segment6,
              r_tfm.segment7,
              l_dr,
              l_cr,
              r_tfm.reference2,
              r_tfm.reference4,
              r_tfm.reference10,
              r_tfm.reference21,
              r_tfm.reference22,
              r_tfm.reference23,
              r_tfm.reference24,
              r_tfm.reference25);

      UPDATE xxgl_cash_bal_tfm
      SET    process_status = 'INTERFACED'
      WHERE  ROWID = r_tfm.row_id;

   END LOOP;
   CLOSE c_tfm;

   IF l_validated_count > 0 THEN
      COMMIT;
   END IF;

EXCEPTION
   WHEN others THEN
      l_error_count := l_error_count + 1;
      p_error_count := l_error_count;
      fnd_file.put_line(fnd_file.log, z_error || SQLERRM);

END validate_interface_lines;

-----------------------------------------------------------
-- Procedure
--     DOWNLOAD_RULES
-- Purpose
--     Download allocation mapping rules table to
--     csv file. Users can modify rules and then upload
--     back to TEST or APPLY status. Setting to APPLY
--     status puts the rule in effect.
-----------------------------------------------------------

PROCEDURE download_rules
(
   p_errbuff     OUT VARCHAR2,
   p_retcode     OUT NUMBER,
   p_path        IN  VARCHAR2,
   p_filename    IN  VARCHAR2,
   p_debug_flag  IN  VARCHAR2
)
IS
   CURSOR c_rhead IS
      SELECT DECODE(column_name,
                    'ENTITY_OFFSET_FLAG', 'USE_OFFSET_SEGMENT1',
                    'DEFAULT_VALUE_FLAG', 'USE_EXP_REV_ACCOUNT',
                    'ALLOCATION_TYPE', 'RULE_TYPE', column_name) column_name
      FROM   all_tab_columns
      WHERE  table_name = 'XXGL_CASH_BAL_RULES_ALL'
      AND    column_name NOT IN ('RULE_ID',
                                 'DERIVE_AMOUNT',
                                 'CREATED_BY',
                                 'CREATION_DATE',
                                 'LAST_UPDATED_BY',
                                 'LAST_UPDATE_DATE')
      ORDER  BY column_id;

   CURSOR c_rules (p_org_id  NUMBER) IS
      SELECT z_qs || rule_num || z_qe ||
             z_qs || set_of_books_id || z_qe ||
             z_qs || journal_category || z_qe ||
             z_qs || journal_source || z_qe ||
             z_qs || sl_trx_type || z_qe ||
             z_qs || sl_trx_subtype || z_qe ||
             z_qs || allocation_type || z_qe ||
             z_qs || source_entity || z_qe ||
             z_qs || source_account || z_qe ||
             z_qs || source_cost_centre || z_qe ||
             z_qs || source_authority || z_qe ||
             z_qs || source_project || z_qe ||
             z_qs || source_output || z_qe ||
             z_qs || source_identifier || z_qe ||
             z_qs || target_entity || z_qe ||
             z_qs || target_account || z_qe ||
             z_qs || target_cost_centre || z_qe ||
             z_qs || target_authority || z_qe ||
             z_qs || target_project || z_qe ||
             z_qs || target_output || z_qe ||
             z_qs || target_identifier || z_qe ||
             z_qs || entity_offset_flag || z_qe ||
             z_qs || default_value_flag || z_qe ||
             z_qs || enter_amount || z_qe ||
           --z_qs || filter_condition_line1 || z_qe ||
           --z_qs || filter_condition_line2 || z_qe ||
             z_qs || summary_flag || z_qe ||
             z_qs || status || z_qe ||
             z_qs || org_id || '"' rule_line
      FROM   xxgl_cash_bal_rules_all
      WHERE  org_id = p_org_id
      AND    status <> 'DELETE';

   f_handle          utl_file.file_type;
   f_copy            INTEGER;
   l_column          VARCHAR2(35);
   l_stg_dir         VARCHAR2(150) := '/usr/tmp';
   l_out_dir         VARCHAR2(150);
 --l_in_out          VARCHAR2(25) := 'OUTBOUND';
 --l_message         VARCHAR2(150);
   l_file            VARCHAR2(150) := p_filename;
   l_text            VARCHAR2(10000);
   l_org_id          NUMBER;

BEGIN
   xxint_common_pkg.g_object_type := 'SEGMENTS';
   fnd_profile.get('ORG_ID', l_org_id);

   /*
   l_out_dir := xxint_common_pkg.interface_path(p_application => z_appl,
                                                p_source => z_source,
                                                p_in_out => l_in_out,
                                                p_archive => Y,
                                                p_message => l_message);

   fnd_file.put_line(fnd_file.log, z_debug || l_out_dir);

   IF l_message IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log, z_error || l_message);
      p_retcode := 2;
      RETURN;
   END IF;
   */

   l_out_dir := p_path;
   print_debug(l_out_dir);

   OPEN c_rhead;
   LOOP
      FETCH c_rhead INTO l_column;
      EXIT WHEN c_rhead%NOTFOUND;

      IF l_text IS NOT NULL THEN
         l_text := l_text || ',';
      END IF;
      l_text := l_text || l_column;

   END LOOP;
   CLOSE c_rhead;

   l_file := l_file; -- || '.' || TO_CHAR(SYSDATE, 'YYYYHH24MISS');

   f_handle := utl_file.fopen(l_stg_dir, l_file, z_write);
   utl_file.put_line(f_handle, l_text);
   fnd_file.put_line(fnd_file.output, l_text);

   FOR r IN c_rules(l_org_id) LOOP
      l_text := r.rule_line;
      utl_file.put_line(f_handle, l_text);
      fnd_file.put_line(fnd_file.output, l_text);
   END LOOP;

   utl_file.fclose(f_handle);

   f_copy := xxint_common_pkg.file_copy(p_from_path => l_stg_dir || '/' || l_file,
                                        p_to_path => l_out_dir || '/' || l_file);

   IF f_copy = 1 THEN
      utl_file.fremove(z_user_tmp, l_file);
   ELSE
      fnd_file.put_line(fnd_file.log, z_error || 'Unable to move file to outbound directory.');
      p_retcode := 2;
   END IF;

EXCEPTION
   WHEN others THEN
      IF utl_file.is_open(f_handle) THEN
         utl_file.fclose(f_handle);
      END IF;
      RAISE;

END download_rules;

----------------------------------------------------------
-- Procedure
--     UPLOAD_RULES
-- Purpose
--     Upload new and/or modified allocation mapping
--     rules. Users can test new rules, as well as apply
--     changes to an existing rule.
----------------------------------------------------------

PROCEDURE upload_rules
(
   p_errbuff     OUT VARCHAR2,
   p_retcode     OUT NUMBER,
   p_path        IN  VARCHAR2,
   p_filename    IN  VARCHAR2,
   p_debug_flag  IN  VARCHAR2
)
IS
   CURSOR c_stg IS
      SELECT DECODE(SIGN(INSTR(rule_num, z_qs)), 1, SUBSTR(REPLACE(rule_num, z_qs), 1, LENGTH(REPLACE(rule_num, z_qs)) - 1), rule_num) rule_num,
             DECODE(SIGN(INSTR(set_of_books_id, z_qs)), 1, SUBSTR(REPLACE(set_of_books_id, z_qs), 1, LENGTH(REPLACE(set_of_books_id, z_qs)) - 1), set_of_books_id) set_of_books_id,
             DECODE(SIGN(INSTR(journal_category, z_qs)), 1, SUBSTR(REPLACE(journal_category, z_qs), 1, LENGTH(REPLACE(journal_category, z_qs)) - 1), journal_category) journal_category,
             DECODE(SIGN(INSTR(journal_source, z_qs)), 1, SUBSTR(REPLACE(journal_source, z_qs), 1, LENGTH(REPLACE(journal_source, z_qs)) - 1), journal_source) journal_source,
             DECODE(SIGN(INSTR(sl_trx_type, z_qs)), 1, SUBSTR(REPLACE(sl_trx_type, z_qs), 1, LENGTH(REPLACE(sl_trx_type, z_qs)) - 1), sl_trx_type) sl_trx_type,
             DECODE(SIGN(INSTR(sl_trx_subtype, z_qs)), 1, SUBSTR(REPLACE(sl_trx_subtype, z_qs), 1, LENGTH(REPLACE(sl_trx_subtype, z_qs)) - 1), sl_trx_subtype) sl_trx_subtype,
             DECODE(SIGN(INSTR(allocation_type, z_qs)), 1, SUBSTR(REPLACE(allocation_type, z_qs), 1, LENGTH(REPLACE(allocation_type, z_qs)) - 1), allocation_type) allocation_type,
             DECODE(SIGN(INSTR(source_entity, z_qs)), 1, SUBSTR(REPLACE(source_entity, z_qs), 1, LENGTH(REPLACE(source_entity, z_qs)) - 1), source_entity) source_entity,
             DECODE(SIGN(INSTR(source_account, z_qs)), 1, SUBSTR(REPLACE(source_account, z_qs), 1, LENGTH(REPLACE(source_account, z_qs)) - 1), source_account) source_account,
             DECODE(SIGN(INSTR(source_cost_centre, z_qs)), 1, SUBSTR(REPLACE(source_cost_centre, z_qs), 1, LENGTH(REPLACE(source_cost_centre, z_qs)) - 1), source_cost_centre) source_cost_centre,
             DECODE(SIGN(INSTR(source_authority, z_qs)), 1, SUBSTR(REPLACE(source_authority, z_qs), 1, LENGTH(REPLACE(source_authority, z_qs)) - 1), source_authority) source_authority,
             DECODE(SIGN(INSTR(source_project, z_qs)), 1, SUBSTR(REPLACE(source_project, z_qs), 1, LENGTH(REPLACE(source_project, z_qs)) - 1), source_project) source_project,
             DECODE(SIGN(INSTR(source_output, z_qs)), 1, SUBSTR(REPLACE(source_output, z_qs), 1, LENGTH(REPLACE(source_output, z_qs)) - 1), source_output) source_output,
             DECODE(SIGN(INSTR(source_identifier, z_qs)), 1, SUBSTR(REPLACE(source_identifier, z_qs), 1, LENGTH(REPLACE(source_identifier, z_qs)) - 1), source_identifier) source_identifier,
             DECODE(SIGN(INSTR(target_entity, z_qs)), 1, SUBSTR(REPLACE(target_entity, z_qs), 1, LENGTH(REPLACE(target_entity, z_qs)) - 1), target_entity) target_entity,
             DECODE(SIGN(INSTR(target_account, z_qs)), 1, SUBSTR(REPLACE(target_account, z_qs), 1, LENGTH(REPLACE(target_account, z_qs)) - 1), target_account) target_account,
             DECODE(SIGN(INSTR(target_cost_centre, z_qs)), 1, SUBSTR(REPLACE(target_cost_centre, z_qs), 1, LENGTH(REPLACE(target_cost_centre, z_qs)) - 1), target_cost_centre) target_cost_centre,
             DECODE(SIGN(INSTR(target_authority, z_qs)), 1, SUBSTR(REPLACE(target_authority, z_qs), 1, LENGTH(REPLACE(target_authority, z_qs)) - 1), target_authority) target_authority,
             DECODE(SIGN(INSTR(target_project, z_qs)), 1, SUBSTR(REPLACE(target_project, z_qs), 1, LENGTH(REPLACE(target_project, z_qs)) - 1), target_project) target_project,
             DECODE(SIGN(INSTR(target_output, z_qs)), 1, SUBSTR(REPLACE(target_output, z_qs), 1, LENGTH(REPLACE(target_output, z_qs)) - 1), target_output) target_output,
             DECODE(SIGN(INSTR(target_identifier, z_qs)), 1, SUBSTR(REPLACE(target_identifier, z_qs), 1, LENGTH(REPLACE(target_identifier, z_qs)) - 1), target_identifier) target_identifier,
             DECODE(SIGN(INSTR(entity_offset_flag, z_qs)), 1, SUBSTR(REPLACE(entity_offset_flag, z_qs), 1, LENGTH(REPLACE(entity_offset_flag, z_qs)) - 1), entity_offset_flag) entity_offset_flag,
             DECODE(SIGN(INSTR(default_value_flag, z_qs)), 1, SUBSTR(REPLACE(default_value_flag, z_qs), 1, LENGTH(REPLACE(default_value_flag, z_qs)) - 1), default_value_flag) default_value_flag,
             DECODE(SIGN(INSTR(enter_amount, z_qs)), 1, SUBSTR(REPLACE(enter_amount, z_qs), 1, LENGTH(REPLACE(enter_amount, z_qs)) - 1), enter_amount) enter_amount,
           --DECODE(SIGN(INSTR(filter_condition_line1, z_qs)), 1, SUBSTR(REPLACE(filter_condition_line1, z_qs), 1, LENGTH(REPLACE(filter_condition_line1, z_qs)) - 1), filter_condition_line1) filter_condition_line1,
           --DECODE(SIGN(INSTR(filter_condition_line2, z_qs)), 1, SUBSTR(REPLACE(filter_condition_line2, z_qs), 1, LENGTH(REPLACE(filter_condition_line2, z_qs)) - 1), filter_condition_line2) filter_condition_line2,
             DECODE(SIGN(INSTR(summary_flag, z_qs)), 1, SUBSTR(REPLACE(summary_flag, z_qs), 1, LENGTH(REPLACE(summary_flag, z_qs)) - 1), summary_flag) summary_flag,
             DECODE(SIGN(INSTR(status, z_qs)), 1, SUBSTR(REPLACE(status, z_qs), 1, LENGTH(REPLACE(status, z_qs)) - 1), status) status,
             DECODE(SIGN(INSTR(org_id, z_qs)), 1, SUBSTR(REPLACE(org_id, z_qs), 1, LENGTH(REPLACE(org_id, z_qs)) - 1), org_id) org_id
      FROM   xxgl_cash_bal_rules_stg;

   r_stg                c_stg%ROWTYPE;
   l_stg_dir            VARCHAR2(150) := '/usr/tmp';
   l_in_dir             VARCHAR2(150);
   l_out_dir            VARCHAR2(150);
   l_arc_dir            VARCHAR2(150);
   l_message            VARCHAR2(150);
   l_user_id            NUMBER;
   l_org_id             NUMBER;
   l_request_id         NUMBER;
   l_record_count       NUMBER := 0;
   l_error_count        NUMBER := 0;
   l_status             xxgl_cash_bal_rules_all.status%TYPE;
   l_bad                VARCHAR2(150);
   l_log                VARCHAR2(150);
   e_directory_error    EXCEPTION;
   run_merge            BOOLEAN;

BEGIN
   xxint_common_pkg.g_object_type := 'SEGMENTS';
   fnd_profile.get('ORG_ID', l_org_id);
   fnd_profile.get('USER_ID', l_user_id);

   IF INSTR(p_filename, '.csv') = 0 THEN
      fnd_file.put_line(fnd_file.log, z_error || 'File must be in csv format <filename.csv>');
      p_retcode := 2;
      RETURN;
   END IF;

   /*
   l_in_dir := xxint_common_pkg.interface_path(p_application => z_appl,
                                               p_source => z_source,
                                               p_in_out => 'OUTBOUND',
                                               p_archive => Y,
                                               p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE e_directory_error;
   END IF;

   l_out_dir := xxint_common_pkg.interface_path(p_application => z_appl,
                                                p_source => z_source,
                                                p_in_out => 'OUTBOUND',
                                                p_archive => Y,
                                                p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE e_directory_error;
   END IF;

   l_arc_dir := xxint_common_pkg.interface_path(p_application => z_appl,
                                                p_source => z_source,
                                                p_archive => Y,
                                                p_message => l_message);

   IF l_message IS NOT NULL THEN
      RAISE e_directory_error;
   END IF;
   */

   l_in_dir := p_path;
   l_out_dir := p_path;

   l_stg_dir := xxint_common_pkg.interface_path(p_application => z_appl,
                                                p_source => z_source,
                                                p_in_out => 'WORKING',
                                                p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE e_directory_error;
   END IF;

   fnd_file.put_line(fnd_file.log, z_debug || 'org_id=' || l_org_id);
   fnd_file.put_line(fnd_file.log, z_debug || 'user_id=' || l_user_id);
   fnd_file.put_line(fnd_file.log, z_debug || 'filename=' || p_filename);
   fnd_file.put_line(fnd_file.log, z_debug || 'inbound=' || l_in_dir);
   fnd_file.put_line(fnd_file.log, z_debug || 'outbound=' || l_out_dir);
   fnd_file.put_line(fnd_file.log, z_debug || 'archive=' || l_arc_dir);
   fnd_file.put_line(fnd_file.log, z_debug || 'staging=' || l_stg_dir);

   l_log := REPLACE(p_filename, '.csv', '.log');
   l_bad := REPLACE(p_filename, '.csv', '.bad');

   l_request_id := fnd_request.submit_request(application => 'FNDC',
                                              program     => 'XXINTSQLLDR',
                                              description => NULL,
                                              start_time  => NULL,
                                              sub_request => FALSE,
                                              argument1   => l_in_dir,
                                              argument2   => l_out_dir,
                                              argument3   => l_stg_dir,
                                              argument4   => l_arc_dir,
                                              argument5   => p_filename,
                                              argument6   => l_log,
                                              argument7   => l_bad,
                                              argument8   => z_ctl);
   COMMIT;

   srs_wait := fnd_concurrent.wait_for_request(l_request_id,
                                               5,
                                               0,
                                               srs_phase,
                                               srs_status,
                                               srs_dev_phase,
                                               srs_dev_status,
                                               srs_message);

   IF NOT (srs_dev_phase = 'COMPLETE' AND
          (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
      fnd_file.put_line(fnd_file.log, z_error || 'File not found or access on directory denied');
      p_retcode := 2;
      RETURN;
   ELSE
      SELECT COUNT(1)
      INTO   l_record_count
      FROM   xxgl_cash_bal_rules_stg;

      IF l_record_count > 0 THEN
         run_merge := TRUE;
      ELSE
         p_retcode := 1;
         fnd_file.put_line(fnd_file.log, z_debug || 'File is empty');
      END IF;
   END IF;

   IF run_merge THEN
      l_record_count := 0;
      l_error_count := 0;

      OPEN c_stg;
      LOOP
         FETCH c_stg INTO r_stg;
         EXIT WHEN c_stg%NOTFOUND;

         l_status := r_stg.status;

         IF r_stg.status NOT IN ('APPLY', 'TEST', 'DELETE') THEN
            fnd_file.put_line(fnd_file.log, z_error || r_stg.rule_num || ' - valid statuses are ''APPLY'', ''TEST'', ''DELETE''');
            l_status := 'ERROR';
         END IF;

         IF r_stg.set_of_books_id IS NULL THEN
            fnd_file.put_line(fnd_file.log, z_error || r_stg.rule_num || ' - Set of books ID is null');
            l_status := 'ERROR';
         END IF;

         IF r_stg.org_id <> TO_CHAR(l_org_id) THEN
            fnd_file.put_line(fnd_file.log, z_error || r_stg.rule_num || ' - expecting ORG_ID ' || l_org_id || '.');
            l_status := 'ERROR';
         END IF;

         IF r_stg.allocation_type NOT IN ('CSH', 'GST') THEN
            fnd_file.put_line(fnd_file.log, z_error || r_stg.rule_num || ' - rule type must be CSH or GST');
            l_status := 'ERROR';
         END IF;

         IF r_stg.summary_flag NOT IN (Y, N) THEN
            fnd_file.put_line(fnd_file.log, z_error || r_stg.rule_num || ' - use Y or N for summary');
            l_status := 'ERROR';
         END IF;

         IF r_stg.journal_source NOT IN ('Receivables', 'Payables', 'Cash Balancing') THEN
            fnd_file.put_line(fnd_file.log, z_error || r_stg.rule_num || ' - valid journal sources are ''Receivables'', ''Payables'', ''Cash Balancing''.');
            l_status := 'ERROR';
         END IF;

         l_record_count := l_record_count + 1;

         IF l_status = 'ERROR' THEN
            l_error_count := l_error_count + 1;
         END IF;

         BEGIN
            MERGE INTO xxgl_cash_bal_rules_all r
            USING DUAL ON (r.rule_num = r_stg.rule_num)
            WHEN MATCHED THEN
               UPDATE SET r.journal_source = r_stg.journal_source,
                          r.sl_trx_type = r_stg.sl_trx_type,
                          r.sl_trx_subtype = r_stg.sl_trx_subtype,
                          r.allocation_type = r_stg.allocation_type,
                          r.source_entity = r_stg.source_entity,
                          r.source_account = r_stg.source_account,
                          r.source_cost_centre = r_stg.source_cost_centre,
                          r.source_authority = r_stg. source_authority,
                          r.source_project = r_stg.source_project,
                          r.source_output = r_stg.source_output,
                          r.source_identifier = r_stg.source_identifier,
                          r.target_entity = r_stg.target_entity,
                          r.target_account = r_stg.target_account,
                          r.target_cost_centre = r_stg.target_cost_centre,
                          r.target_authority = r_stg.target_authority,
                          r.target_project = r_stg.target_project,
                          r.target_output = r_stg.target_output,
                          r.target_identifier = r_stg.target_identifier,
                          r.entity_offset_flag = r_stg.entity_offset_flag,
                          r.default_value_flag = r_stg.default_value_flag,
                          r.enter_amount = r_stg.enter_amount,
                        --r.filter_condition_line1 = r_stg.filter_condition_line1,
                        --r.filter_condition_line2 = r_stg.filter_condition_line2,
                          r.summary_flag = r_stg.summary_flag,
                          r.status = l_status,
                          r.last_updated_by = l_user_id,
                          r.last_update_date = SYSDATE
            WHEN NOT MATCHED THEN
               INSERT (rule_num,
                       set_of_books_id,
                       journal_category,
                       journal_source,
                       sl_trx_type,
                       sl_trx_subtype,
                       allocation_type,
                       source_entity,
                       source_account,
                       source_cost_centre,
                       source_authority,
                       source_project,
                       source_output,
                       source_identifier,
                       target_entity,
                       target_account,
                       target_cost_centre,
                       target_authority,
                       target_project,
                       target_output,
                       target_identifier,
                       entity_offset_flag,
                       default_value_flag,
                       enter_amount,
                     --filter_condition_line1,
                     --filter_condition_line2,
                       summary_flag,
                       status,
                       org_id,
                       created_by,
                       creation_date,
                       last_updated_by,
                       last_update_date)
               VALUES (r_stg.rule_num,
                       r_stg.set_of_books_id,
                       r_stg.journal_category,
                       r_stg.journal_source,
                       r_stg.sl_trx_type,
                       r_stg.sl_trx_subtype,
                       r_stg.allocation_type,
                       r_stg.source_entity,
                       r_stg.source_account,
                       r_stg.source_cost_centre,
                       r_stg.source_authority,
                       r_stg.source_project,
                       r_stg.source_output,
                       r_stg.source_identifier,
                       r_stg.target_entity,
                       r_stg.target_account,
                       r_stg.target_cost_centre,
                       r_stg.target_authority,
                       r_stg.target_project,
                       r_stg.target_output,
                       r_stg.target_identifier,
                       r_stg.entity_offset_flag,
                       r_stg.default_value_flag,
                       r_stg.enter_amount,
                     --r_stg.filter_condition_line1,
                     --r_stg.filter_condition_line2,
                       r_stg.summary_flag,
                       l_status,
                       r_stg.org_id,
                       l_user_id,
                       SYSDATE,
                       l_user_id,
                       SYSDATE);
         EXCEPTION
            WHEN others THEN
               l_error_count := l_error_count + 1;
               fnd_file.put_line(fnd_file.log, z_error || r_stg.rule_num || ' ' || SQLERRM);
         END;
      END LOOP;

      fnd_file.put_line(fnd_file.log, 'Processed Records: ' || l_record_count);
      fnd_file.put_line(fnd_file.log, 'Errored Records:   ' || l_error_count);

   END IF;

   IF l_error_count > 0 THEN
      p_retcode := 2;
   END IF;

EXCEPTION
   WHEN e_directory_error THEN
      fnd_file.put_line(fnd_file.log, z_error || l_message);
      p_retcode := 2;
   WHEN others THEN
      RAISE;
END upload_rules;

--------------------------------------------------
-- Procedure
--     RUN_TEST_REPORT
-- Purpose
--     Report output for TEST mapping rules.
--------------------------------------------------

PROCEDURE run_test_report
(
   p_request_id       NUMBER,
   p_accounting_date  DATE
)
IS
   CURSOR c_jheader IS
      SELECT 'Source:             ' || user_je_source_name je_source,
             'Batch Name:         ' || reference2 batch_name,
             'Journal Entry Name: ' || (user_je_category_name || ' ' || currency_code) journal_entry_name,
             'Category:           ' || user_je_category_name je_category,
             'Currency:           ' || currency_code currency,
             COUNT(1) je_line_count
      FROM   xxgl_cash_bal_tfm
      WHERE  request_id = p_request_id
      GROUP  BY
             user_je_source_name,
             reference2,
             user_je_category_name,
             user_je_category_name,
             currency_code;

   CURSOR c_jlines IS
      SELECT ROWID tfm_rowid,
             RPAD(segment1 || z_acct_del ||
                  segment2 || z_acct_del ||
                  segment3 || z_acct_del ||
                  segment4 || z_acct_del ||
                  segment5 || z_acct_del ||
                  segment6 || z_acct_del ||
                  segment7, 40) || ' ' ||
             RPAD(SUBSTR(reference10, 1, 50), 50, ' ') || ' ' ||
             LPAD(NVL(TO_CHAR(entered_dr, 'fm999,999,999,999.00'), ' '), 20, ' ')  || ' ' ||
             LPAD(NVL(TO_CHAR(entered_cr, 'fm999,999,999,999.00'), ' '), 20, ' ') print_line,
             entered_dr,
             entered_cr
      FROM   xxgl_cash_bal_tfm
      WHERE  request_id = p_request_id;

   r_jheader         c_jheader%ROWTYPE;
   l_print_line      VARCHAR2(600);
   l_line_num        NUMBER := 0;
   l_dr_total        NUMBER := 0;
   l_cr_total        NUMBER := 0;
   l_heading1        VARCHAR2(600) := 'Line #  Accounting Flexfield                     Line Description                                                 Debits              Credits';
   l_footer1         VARCHAR2(600) := 'Total';
   l_separator       VARCHAR2(600) := '------  ---------------------------------------  -------------------------------------------------  --------------------  -------------------';

BEGIN
   OPEN c_jheader;
   FETCH c_jheader INTO r_jheader;
   CLOSE c_jheader;

   fnd_file.put_line(fnd_file.output, z_space);
   fnd_file.put_line(fnd_file.output, z_space || 'Request ID:         ' || p_request_id);
   fnd_file.put_line(fnd_file.output, z_space || 'Run Date:           ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
   fnd_file.put_line(fnd_file.output, z_space);
   fnd_file.put_line(fnd_file.output, z_space || r_jheader.je_source);
   fnd_file.put_line(fnd_file.output, z_space || r_jheader.batch_name);
   fnd_file.put_line(fnd_file.output, z_space || r_jheader.journal_entry_name);
   fnd_file.put_line(fnd_file.output, z_space || r_jheader.je_category);
   fnd_file.put_line(fnd_file.output, z_space || 'Accounting Date:    ' || p_accounting_date);
   fnd_file.put_line(fnd_file.output, z_space);
   fnd_file.put_line(fnd_file.output, z_space);
   fnd_file.put_line(fnd_file.output, z_space || l_heading1);
   fnd_file.put_line(fnd_file.output, z_space || l_separator);

   FOR j IN c_jlines LOOP
      l_line_num := l_line_num + 1;
      l_print_line := RPAD(TO_CHAR(l_line_num), 8,  ' ') || j.print_line;
      fnd_file.put_line(fnd_file.output, z_space || l_print_line);
      l_dr_total := l_dr_total + NVL(j.entered_dr, 0);
      l_cr_total := l_cr_total + NVL(j.entered_cr, 0);
   END LOOP;

   l_footer1 := RPAD('Total: ', 100, ' ') ||
                LPAD(NVL(TO_CHAR(l_dr_total, 'fm999,999,999,999.00'), ' '), 20, ' ')  || ' ' ||
                LPAD(NVL(TO_CHAR(l_cr_total, 'fm999,999,999,999.00'), ' '), 20, ' ');

   fnd_file.put_line(fnd_file.output, z_space || l_separator);
   fnd_file.put_line(fnd_file.output, z_space);
   fnd_file.put_line(fnd_file.output, z_space || l_footer1);

END run_test_report;

END xxgl_cash_bal_pkg;
/
