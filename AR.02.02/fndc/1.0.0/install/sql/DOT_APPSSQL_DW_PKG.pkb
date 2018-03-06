CREATE OR REPLACE PACKAGE BODY dot_appssql_dw_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.02/fndc/1.0.0/install/sql/DOT_APPSSQL_DW_PKG.pkb 2801 2017-10-13 04:12:47Z svnuser $ */
/******************************************************************************
**
**  CEMLI ID: INT.10.01
**
**  Description: Create materialized views for the following business objects -
**               Chart of Accounts, AP & AR Invoices, AR Receipts, GL Journals,
**               and GL Balances. MV data are extracted into IBM Cognos Analytics.
**
**  Change History:
**
**  Date          Who           Description
**  11-Nov-2015   Dart          Initial build.
**  05-Apr-2016   Katie H.      Modified refresh_dw and close_process procedures
**  26-May-2017   Dart          Allow creation of multiple parent-child rows, as  
**                              long as it belongs to different hierarchy group.
**                              This helps user to determine overlap in the
**                              account hierarchy setup.
**
******************************************************************************/

gn_request_id           NUMBER;
gd_request_date         DATE;
gn_max_wait             NUMBER        := 60;
gn_retention            NUMBER        := 7;
gv_param_dir            VARCHAR2(150) := 'MVIEW_EMAIL_PARAM_DIR';
gv_param_file           VARCHAR2(150) := 'DOTREFMVC.par';
gd_reset_date           DATE          := TO_DATE('01-JAN-1997', 'DD-MON-YYYY');
gn_dedjtr_book_id       NUMBER        := 1;

TYPE approve_tab_type   IS TABLE OF NUMBER INDEX BY binary_integer;
TYPE invoice_tab_type   IS TABLE OF VARCHAR2(60) INDEX BY binary_integer;
TYPE recipient_tab_type IS TABLE OF VARCHAR2(240) INDEX BY binary_integer;

TYPE flex_value_set_rec_type IS RECORD
(
   row_id                      VARCHAR2(150),
   set_of_books_id             NUMBER,
   application_column_name     VARCHAR2(30),
   segment_name                VARCHAR2(30),
   mview_name                  VARCHAR2(60),
   flex_value_set_id           NUMBER,
   value_last_update_date      DATE,
   hierarchy_last_update_date  DATE,
   insert_flag                 VARCHAR2(1)
);

TYPE flex_value_set_tab_type IS TABLE OF flex_value_set_rec_type INDEX BY binary_integer;
TYPE hierarchy_tab_type IS TABLE OF VARCHAR2(100) INDEX BY binary_integer;

TYPE source_rec_type IS RECORD
(
   source_id     NUMBER,
   line_count    NUMBER
);

TYPE source_tab_type IS TABLE OF source_rec_type INDEX BY binary_integer;

TYPE mvrefresh_req IS TABLE OF NUMBER INDEX BY binary_integer;

TYPE mvrefresh_rec_type IS RECORD
(
   owner         VARCHAR2(30),
   mview_name    VARCHAR2(30)
);

TYPE mvrefresh_tab_type IS TABLE OF mvrefresh_rec_type INDEX BY binary_integer;

--------------------------
FUNCTION get_segment_value
(
   p_segment_num             IN  NUMBER,
   p_code_combination_id     IN  NUMBER,
   p_concatenated_account    IN  VARCHAR2,
   p_reversed_je_header_id   IN  NUMBER,
   p_reversed_je_line_num    IN  NUMBER
)  RETURN VARCHAR2
IS
   lv_segment_value     VARCHAR2(150);
   lv_sql               VARCHAR2(600);
   lv_sep               VARCHAR2(1);
   ln_sep_pos           NUMBER;
   ln_len               NUMBER;
   ln_occur             NUMBER := 0;

   TYPE flex_separator  IS VARRAY(10) OF VARCHAR2(1);
   t_flex_sep           flex_separator := flex_separator('-', '.', '|');

BEGIN
   -- Consolidation Transfers
   IF p_code_combination_id IS NOT NULL AND
      p_segment_num IS NOT NULL THEN
      lv_sql := 'SELECT SEGMENT' || p_segment_num || ' ' ||
                'FROM gl_code_combinations ' ||
                'WHERE code_combination_id = ' ||
                p_code_combination_id;

      EXECUTE IMMEDIATE lv_sql INTO lv_segment_value;
   ELSE
      -- Reversed Consolidation Transfers
      IF p_reversed_je_header_id IS NOT NULL AND
         p_reversed_je_line_num IS NOT NULL THEN
         lv_sql := 'SELECT c.segment' || p_segment_num || ' ' ||
                   'FROM gl_je_lines l, gl_code_combinations c ' ||
                   'WHERE l.je_header_id = ' || p_reversed_je_header_id || ' ' ||
                   'AND l.je_line_num = ' || p_reversed_je_line_num || ' ' ||
                   'AND l.code_combination_id = c.code_combination_id';

         EXECUTE IMMEDIATE lv_sql INTO lv_segment_value;
      END IF;
   END IF;

   -- Spreadsheet Transfers or Manual Entry
   IF TRIM(p_concatenated_account) IS NOT NULL THEN
      ln_len := NVL(LENGTH(p_concatenated_account), 0);
      FOR i IN 1 .. t_flex_sep.COUNT LOOP
         ln_sep_pos := INSTR(p_concatenated_account, t_flex_sep(i), 1, 1);
         IF ln_sep_pos > 0 THEN
            lv_sep := t_flex_sep(i);
            ln_occur := REGEXP_COUNT(p_concatenated_account, lv_sep);
            EXIT;
         END IF;
      END LOOP;

      IF p_segment_num IS NOT NULL AND
         lv_sep IS NOT NULL THEN
         IF p_segment_num = 1 THEN
            lv_segment_value := SUBSTR(p_concatenated_account, 1, INSTR(p_concatenated_account, lv_sep, p_segment_num) - 1);
         ELSIF p_segment_num > 1 THEN
            ln_sep_pos := INSTR(p_concatenated_account, lv_sep, 1, p_segment_num);

            IF ln_sep_pos > 0 THEN
               lv_segment_value := SUBSTR(p_concatenated_account,
                                         (INSTR(p_concatenated_account, lv_sep, 1, p_segment_num - 1) + 1),
                                         (INSTR(p_concatenated_account, lv_sep, 1, p_segment_num) -
                                         (INSTR(p_concatenated_account, lv_sep, 1, p_segment_num - 1) + 1)));
            ELSE
               IF p_segment_num > (ln_occur + 1) THEN
                  NULL;
               ELSE
                  IF ln_len > 0 THEN
                     lv_segment_value := SUBSTR(p_concatenated_account,
                                               (INSTR(p_concatenated_account, lv_sep, 1, p_segment_num - 1) + 1),
                                               ((ln_len + 1) - (INSTR(p_concatenated_account, lv_sep, 1, p_segment_num - 1) + 1)));
                  END IF;
               END IF;
            END IF;
         END IF;
      END IF;
   END IF;

   RETURN lv_segment_value;
END get_segment_value;

------------------------
FUNCTION convert_to_date
(
   p_string   VARCHAR2
)
RETURN DATE
IS
   string_to_date     DATE;
BEGIN
   IF TRIM(p_string) IS NOT NULL THEN
      IF INSTR(TRIM(p_string), '/') > 0 THEN
         string_to_date := TO_DATE(TRIM(p_string), 'DD/MM/RR');
      ELSE
         string_to_date := TO_DATE(TRIM(p_string), 'DD-MON-RR');
      END IF;
   END IF;

   RETURN string_to_date;
EXCEPTION
   WHEN others THEN
      string_to_date := NULL;
      RETURN string_to_date;

END convert_to_date;

-----------------------------
FUNCTION requisition_approver
(
   p_requisition_id   NUMBER,
   p_sequence_num     NUMBER,
   p_action_code      VARCHAR2
)
RETURN VARCHAR2
IS
   ln_seq_num         NUMBER;
   approve_actions    approve_tab_type;
BEGIN
   IF p_action_code = 'APPROVE' THEN
      SELECT MIN(sequence_num)
      INTO   ln_seq_num
      FROM   po_action_history
      WHERE  object_id = p_requisition_id
      AND    object_type_code = 'REQUISITION'
      AND    action_code = 'SUBMIT CHANGE';

      IF p_sequence_num = (ln_seq_num - 1) THEN
         RETURN 'FINAL APPROVER';
      ELSIF p_sequence_num = (ln_seq_num - 2) THEN
         RETURN 'PRE-APPROVER';
      ELSE
         SELECT a.sequence_num
                BULK COLLECT INTO approve_actions
         FROM   po_action_history a
         WHERE  a.object_id = p_requisition_id
         AND    a.object_type_code = 'REQUISITION'
         AND    a.action_code = 'APPROVE'
         AND    NOT EXISTS
                (SELECT 1
                 FROM   po_action_history x
                 WHERE  x.object_id = a.object_id
                 AND    x.object_type_code = a.object_type_code
                 AND    x.action_code = 'SUBMIT CHANGE')
         ORDER  BY sequence_num DESC;

         IF approve_actions.COUNT > 1 THEN
            IF p_sequence_num = approve_actions(1) THEN
               RETURN 'FINAL APPROVER';
            ELSIF p_sequence_num = approve_actions(2) THEN
               RETURN 'PRE-APPROVER';
            END IF;
         ELSIF approve_actions.COUNT = 1 THEN
            RETURN 'FINAL APPROVER';
         END IF;
      END IF;

   ELSIF p_action_code = 'SUBMIT' THEN
      IF p_sequence_num = 0 THEN
         RETURN 'REQUESTOR';
      END IF;

   END IF;

   RETURN NULL;

END requisition_approver;

--------------------------
FUNCTION po_exclude_filter
(
   p_po_header_id   NUMBER
)
RETURN VARCHAR2
IS
   CURSOR c_po IS
      SELECT pod.po_header_id
      FROM   ap_invoice_distributions_all aid,
             po_distributions_all pod,
             gl_sets_of_books gsb,
             gl_periods gpe,
            (SELECT (period_year - gn_retention) period_year,
                    period_set_name
             FROM   gl_periods
             WHERE  TRUNC(SYSDATE) BETWEEN start_date AND end_date
             AND    NVL(adjustment_period_flag, 'N') = 'N'
             AND    period_type = '1') gpr
      WHERE  pod.po_header_id = p_po_header_id
      AND    aid.po_distribution_id = pod.po_distribution_id
      AND    aid.set_of_books_id = gsb.set_of_books_id
      AND    gsb.period_set_name = gpe.period_set_name
      AND    gsb.period_set_name = gpr.period_set_name
      AND    aid.period_name = gpe.period_name
      AND    gpe.period_year < gpr.period_year
      UNION
      SELECT pohx.po_header_id
      FROM   po_headers_all pohx,
             po_distributions_all podx,
             gl_sets_of_books gsb,
             gl_periods gpe,
            (SELECT (period_year - gn_retention) period_year,
                    period_set_name
             FROM   gl_periods
             WHERE  TRUNC(SYSDATE) BETWEEN start_date AND end_date
             AND    NVL(adjustment_period_flag, 'N') = 'N'
             AND    period_type = '1') gpr
      WHERE  pohx.po_header_id = p_po_header_id
      AND    pohx.po_header_id = podx.po_header_id
      AND   (pohx.closed_code IN ('CLOSED' , 'FINALLY CLOSED') OR
                 (SELECT NVL(SUM(pols.quantity * pols.unit_price), 0)
                  FROM   po_lines_all pols
                  WHERE  pols.po_header_id = pohx.po_header_id
                  AND    NVL(pols.cancel_flag, 'N') = 'N') = 0)
      AND    podx.set_of_books_id = gsb.set_of_books_id
      AND    gsb.period_set_name = gpe.period_set_name
      AND    gsb.period_set_name = gpr.period_set_name
      AND    podx.gl_encumbered_period_name = gpe.period_name
      AND    gpe.period_year < gpr.period_year;

   ln_po_header_id   NUMBER;
BEGIN
   OPEN c_po;
   FETCH c_po INTO ln_po_header_id;
   IF c_po%FOUND THEN
      RETURN 'Y';
   END IF;
   RETURN 'N';

END po_exclude_filter;

--------------------------
FUNCTION get_payable_aging
(
   p_invoice_id         NUMBER,
   p_amount_remaining   NUMBER,
   p_paid               VARCHAR2,
   p_due_date           DATE,
   p_cancel_date        DATE
)
RETURN NUMBER
IS
   CURSOR c_pay IS
      SELECT TRUNC(MAX(c.check_date)) check_date
      FROM   ap_checks_all c,
            (SELECT p.*
             FROM   ap_invoice_payments_all p,
                    ap_invoices_all i
             WHERE  p.invoice_id = p_invoice_id
             AND    p.invoice_id = i.invoice_id
             AND    NVL(p.reversal_flag, 'N') = 'N'
             AND    i.cancelled_date IS NULL
             AND    NOT EXISTS (SELECT 1
                                FROM   ap_invoice_payments_all r
                                WHERE  r.invoice_id = p.invoice_id
                                AND    r.reversal_inv_pmt_id = p.invoice_payment_id)) p
      WHERE  c.check_id = p.check_id;

   payment_date       DATE;
   system_date        DATE := TRUNC(SYSDATE);
   due_date           DATE := TRUNC(p_due_date);
   amount_remaining   NUMBER := p_amount_remaining;
   aging              NUMBER;
BEGIN
   IF p_cancel_date IS NULL THEN
      IF p_paid = 'Yes' THEN
         OPEN c_pay;
         FETCH c_pay INTO payment_date;
         IF c_pay%FOUND THEN
            IF due_date IS NOT NULL THEN
               IF payment_date > due_date THEN
                  aging := (payment_date - due_date);
               END IF;
            END IF;
         END IF;
      ELSE
         IF NVL(amount_remaining, 0) <> 0 THEN
            IF system_date > due_date THEN
               aging := (system_date - due_date);
            END IF;
         END IF;
      END IF;
   END IF;

   RETURN aging;

END get_payable_aging;

------------------------
FUNCTION get_invoice_num
(
   p_po_distribution_id   NUMBER
)
RETURN VARCHAR2
IS
   t_invoices     invoice_tab_type;
BEGIN
   SELECT DISTINCT aia.invoice_num
          BULK COLLECT INTO t_invoices
   FROM   ap_invoices_all aia,
          ap_invoice_distributions_all aid
   WHERE  aia.invoice_id = aid.invoice_id
   AND    aid.po_distribution_id = p_po_distribution_id;

   IF t_invoices.COUNT = 0 THEN
      RETURN NULL;

   ELSIF t_invoices.COUNT = 1 THEN
      RETURN t_invoices(1);

   ELSIF t_invoices.COUNT > 1 THEN
      RETURN 'Multiple';

   END IF;

END get_invoice_num;

------------------------
FUNCTION get_site_use_id
(
   p_cash_receipt_id    NUMBER,
   p_customer_id        NUMBER,
   p_org_id             NUMBER
)
RETURN NUMBER
IS
   CURSOR c_su IS
      SELECT su.site_use_id
      FROM   hz_cust_acct_sites_all si,
             hz_cust_site_uses_all su
      WHERE  si.cust_account_id = p_customer_id
      AND    si.org_id = p_org_id
      AND    si.cust_acct_site_id = su.cust_acct_site_id
      AND    su.status = 'A'
      AND    su.site_use_code = 'BILL_TO'
      ORDER  BY DECODE(primary_flag, 'Y', 1, 2);

   ln_site_use_id    NUMBER;
BEGIN
   BEGIN
      SELECT rcta.bill_to_site_use_id
      INTO   ln_site_use_id
      FROM   ar_receivable_applications_all araa,
             ra_customer_trx_all rcta
      WHERE  araa.cash_receipt_id = p_cash_receipt_id
      AND    araa.applied_customer_trx_id = rcta.customer_trx_id
      AND    araa.status = 'APP'
      AND    araa.receivable_application_id = (SELECT MAX(arap.receivable_application_id)
                                               FROM   ar_receivable_applications_all arap
                                               WHERE  arap.cash_receipt_id = araa.cash_receipt_id
                                               AND    arap.status = araa.status);
   EXCEPTION
      WHEN no_data_found THEN
         NULL;
   END;

   IF ln_site_use_id IS NULL THEN
      OPEN c_su;
      FETCH c_su INTO ln_site_use_id;
      CLOSE c_su;
   END IF;

   RETURN ln_site_use_id;

END get_site_use_id;

------------------------
FUNCTION get_site_use_id
(
   p_customer_id        NUMBER,
   p_site_use_id        NUMBER,
   p_org_id             NUMBER,
   p_version            NUMBER
)
RETURN NUMBER
IS
   CURSOR c_su IS
      SELECT su.site_use_id,
             su.primary_flag
      FROM   hz_cust_acct_sites_all si,
             hz_cust_site_uses_all su
      WHERE  si.cust_account_id = p_customer_id
      AND    si.org_id = p_org_id
      AND    si.cust_acct_site_id = su.cust_acct_site_id
    --AND    su.status = 'A'
      AND    su.site_use_code = 'BILL_TO'
      ORDER  BY DECODE(su.status, 'A', 1, 2);

   ln_site_use_id      NUMBER;
   ln_site_use_id_p    NUMBER;
   lv_use              VARCHAR2(1);
   lv_primary_flag     VARCHAR2(10);
BEGIN
   OPEN c_su;
   LOOP
      FETCH c_su INTO ln_site_use_id, lv_primary_flag;
      EXIT WHEN c_su%NOTFOUND;

      IF ln_site_use_id = p_site_use_id THEN
         lv_use := 'Y';
         EXIT;
      END IF;

      IF lv_primary_flag = 'Y' THEN
         ln_site_use_id_p := ln_site_use_id;
      END IF;
   END LOOP;

   IF lv_use = 'Y' THEN
      RETURN ln_site_use_id;
   ELSE
      IF ln_site_use_id_p IS NOT NULL THEN
         RETURN ln_site_use_id_p;
      ELSE
         RETURN ln_site_use_id;
      END IF;
   END IF;

END get_site_use_id;

--------------------------
PROCEDURE purge_mview_jobs
IS
   PRAGMA    AUTONOMOUS_TRANSACTION;
BEGIN
   DELETE FROM dot_refresh_mview_jobs
   WHERE  request_date < ADD_MONTHS(TRUNC(SYSDATE), -3);

   COMMIT;
END purge_mview_jobs;

------------------------
FUNCTION current_refresh
(
   p_mview_name   VARCHAR2
)
RETURN BOOLEAN
IS
   lv_sql       VARCHAR2(1000);
   ln_refresh   NUMBER;
BEGIN
   lv_sql := 'SELECT 1 FROM V$MVREFRESH ' ||
             'WHERE currmvowner = ''APPSSQL'' ' ||
             'AND currmvname = ''' || p_mview_name || '''';

   EXECUTE IMMEDIATE lv_sql INTO ln_refresh;

   IF ln_refresh = 1 THEN
      RETURN TRUE;
   END IF;

   RETURN FALSE;
EXCEPTION
   WHEN no_data_found THEN
      RETURN FALSE;
END current_refresh;

------------------------------
PROCEDURE update_control_table
(
   p_request_id    NUMBER,
   p_request_date  DATE,
   p_stage         NUMBER
)
IS
   PRAGMA          AUTONOMOUS_TRANSACTION;
   dummy           NUMBER;
BEGIN

   FND_FILE.PUT_LINE(FND_FILE.LOG,'update_control_table procedure @ '||to_char(sysdate,'DD-MON-YYYY HH24:MI:SS')||', p_request_id: '||p_request_id||', p_stage: '||p_stage); --Added by Katie H. on 04-Apr-2016

   IF p_stage = 0 THEN
      BEGIN
         SELECT request_id
         INTO   dummy
         FROM   appssql.dot_refresh_mviews_control
         WHERE  request_id = p_request_id;
      EXCEPTION
         WHEN no_data_found THEN
            INSERT INTO appssql.dot_refresh_mviews_control
            VALUES (p_request_id,
                    p_request_date,
                    'PENDING',
                    'PENDING',
                    'PENDING',
                    NULL,
                    SYSDATE,
                    NULL,
                    'DW');
      END;

   ELSIF p_stage = 1 THEN
      UPDATE appssql.dot_refresh_mviews_control
      SET    stage_1 = 'PROCESSING'
      WHERE  request_id = p_request_id;

   ELSIF p_stage = 2 THEN
      UPDATE appssql.dot_refresh_mviews_control
      SET    stage_1 = 'COMPLETED',
             stage_2 = 'PROCESSING'
      WHERE  request_id = p_request_id
      AND    stage_1 IN ('PROCESSING', 'PENDING');

   ELSIF p_stage = 3 THEN
      UPDATE appssql.dot_refresh_mviews_control
      SET    stage_2 = 'COMPLETED',
             stage_3 = 'PROCESSING'
      WHERE  request_id = p_request_id;

   ELSIF p_stage = 100 THEN
      UPDATE appssql.dot_refresh_mviews_control
      SET    stage_3 = 'COMPLETED',
             status  = 'COMPLETED',
             actual_completion_date = SYSDATE
      WHERE  request_id = p_request_id;

   ELSIF p_stage = -1 THEN
      UPDATE appssql.dot_refresh_mviews_control
      SET    status = 'ERROR',
             actual_completion_date = SYSDATE
      WHERE  request_id = p_request_id;

   END IF;

   COMMIT;
END update_control_table;

--------------------
PROCEDURE refresh_dw
(
   p_errbuff         OUT VARCHAR2,
   p_retcode         OUT NUMBER,
   p_include_coa     IN  VARCHAR2,
   p_full_refresh    IN  VARCHAR2,
   p_immediate_flag  IN  VARCHAR2
)
IS
   CURSOR c_coa IS
      SELECT gsob.set_of_books_id,
             fseg.application_column_name,
             fseg.segment_name,
             DECODE(fseg.segment_name,
                    'Account',       'APPSSQL.DOT_GL_COA_ACCOUNT_DW',
                    'Authority',     'APPSSQL.DOT_GL_COA_AUTHORITY_DW',
                    'Cost Centre',   'APPSSQL.DOT_GL_COA_COST_CENTRE_DW',
                    'Division',      'APPSSQL.DOT_GL_COA_COST_CENTRE_DW',
                    'Identifier',    'APPSSQL.DOT_GL_COA_IDENTIFIER_DW',
                    'Related Party', 'APPSSQL.DOT_GL_COA_IDENTIFIER_DW',
                    'Organisation',  'APPSSQL.DOT_GL_COA_ORGANISATION_DW',
                    'Entity',        'APPSSQL.DOT_GL_COA_ORGANISATION_DW',
                    'Output',        'APPSSQL.DOT_GL_COA_OUTPUT_DW',
                    'Project',       'APPSSQL.DOT_GL_COA_PROJECT_DW')
                    mview_name,
             fseg.flex_value_set_id,
             (SELECT MAX(val.last_update_date)
              FROM   fnd_flex_values val
              WHERE  val.flex_value_set_id = fseg.flex_value_set_id) value_date,
             -- arellanod 26/05/2017
             --DECODE(NVL(p_immediate_flag, 'N'), 'Y', gd_reset_date,
                   (SELECT MAX(hier.last_update_date)
                    FROM   fnd_flex_value_norm_hierarchy hier
                    WHERE  hier.flex_value_set_id = fseg.flex_value_set_id)
             --       ) 
             hierarchy_date
      FROM   fnd_id_flex_structures fstr,
             fnd_id_flex_segments_vl fseg,
             gl_sets_of_books gsob
      WHERE  fstr.application_id = fseg.application_id
      AND    fstr.id_flex_code = fseg.id_flex_code
      AND    fstr.id_flex_num = fseg.id_flex_num
      AND    fstr.id_flex_code = 'GL#'
      AND    fstr.id_flex_num = gsob.chart_of_accounts_id
      ORDER  BY 1, 2;

   CURSOR c_flex_values
   (
      p_flex_value_set_id  NUMBER,
      p_set_of_books_id    NUMBER
   )
   IS SELECT fl.segment_name,
             hi.flex_value_set_id,
             hi.flex_value_set_name,
             hi.flex_value_id,
             hi.flex_value,
             hi.flex_value_meaning,
             hi.description,
             hi.enabled_flag,
             LEVEL level_in_hierarchy,
             hi.parent_flex_value_id,
             hi.creation_date,
             hi.last_update_date
      FROM   dot_fnd_flex_hierarchy_v hi,
             gl_sets_of_books gs,
             fnd_id_flex_segments_vl fl
      WHERE  gs.chart_of_accounts_id = fl.id_flex_num
      AND    fl.flex_value_set_id = hi.flex_value_set_id
      AND    hi.flex_value_set_id = p_flex_value_set_id
      AND    gs.set_of_books_id = p_set_of_books_id
             START WITH hi.parent_flex_value IS NULL
             CONNECT BY PRIOR hi.flex_value_id = hi.parent_flex_value_id;

   c_req                   NUMBER := 0;
   idx                     NUMBER := 0;
   ctl_row_id              VARCHAR2(150);
   ctl_value_date          DATE;
   ctl_hierarchy_date      DATE;
   dummy                   VARCHAR2(1);

   r_coa                   c_coa%ROWTYPE;
   r_flex_value            c_flex_values%ROWTYPE;
   t_flex_value_set        flex_value_set_tab_type;
   t_hierarchy             hierarchy_tab_type;
   t_mvrefresh             mvrefresh_tab_type;
   t_mvrefresh_req         mvrefresh_req;
   l_include_coa           VARCHAR2(1) := p_include_coa;
   l_req_data              VARCHAR2(10); -- request data
   l_sql                   VARCHAR2(32767);
   l_sqlerrm               VARCHAR2(600);
   l_log                   VARCHAR2(600);
   l_list                  VARCHAR2(4000);
   l_stage_1_status        VARCHAR2(25);
   l_stage_1               NUMBER := 0;
   l_mv_req                NUMBER := 0;
   l_close                 NUMBER;
   l_rel_req_id            NUMBER;
   l_wait                  NUMBER := 0;
   l_error                 NUMBER := 0;

   delay_process           BOOLEAN := TRUE;

BEGIN
   gn_request_id := FND_GLOBAL.CONC_REQUEST_ID;

   SELECT request_date
   INTO   gd_request_date
   FROM   fnd_concurrent_requests
   WHERE  request_id = gn_request_id;

   purge_mview_jobs;

   --Moved by Katie H. on 05-Apr-2016
   l_req_data := FND_CONC_GLOBAL.REQUEST_DATA;

   --Added by Katie H. on 04-Apr-2016 for debugging
   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Debug: l_req_data: ' ||l_req_data);

   --Added by Katie H. on 05-Apr-2016, to avoid re-run stage 1 after the program restarted
   IF (l_req_data IS NULL) THEN

       IF NVL(p_immediate_flag, 'N') = 'N' THEN
          update_control_table(gn_request_id, gd_request_date, 0);
       END IF;

       IF l_include_coa = 'Y' THEN

          -- Negate call to FND_CONC_GLOBAL.REQUEST_DATA
          l_include_coa := 'N';

          BEGIN
             SELECT MAX(request_id)
             INTO   l_rel_req_id
             FROM   appssql.dot_refresh_mviews_control
             WHERE  TRUNC(actual_start_date) = TRUNC(SYSDATE)
             AND    stage_1 IN ('PENDING', 'PROCESSING', 'COMPLETED')
             AND    request_id <> gn_request_id;

             IF l_rel_req_id IS NOT NULL THEN
                l_stage_1 := 1;

                WHILE delay_process LOOP
                   l_stage_1_status := NULL;

                   -- Not expecting no_data_found
                   SELECT stage_1
                   INTO   l_stage_1_status
                   FROM   appssql.dot_refresh_mviews_control
                   WHERE  request_id = l_rel_req_id;

                   IF l_stage_1_status = 'COMPLETED' THEN
                      delay_process := FALSE;
                   ELSE
                      l_wait := l_wait + 1;
                      IF l_wait < gn_max_wait THEN
                         dbms_lock.sleep(60);
                      ELSE
                         delay_process := FALSE;
                      END IF;
                   END IF;
                END LOOP;
             END IF;

          EXCEPTION
             WHEN no_data_found THEN
                NULL;
          END;

          /***************/
          /* Stage #1    */
          /***************/
          FND_FILE.PUT_LINE(FND_FILE.LOG, 'Processing STAGE #1 @ '||to_char(sysdate,'DD-MON-YYYY HH24:MI:SS')); --Added by Katie H. on 04-Apr-2016
          IF NVL(p_immediate_flag, 'N') = 'N' THEN
             update_control_table(gn_request_id, NULL, 1);
          END IF;

          IF l_stage_1 = 1 THEN
             GOTO refresh_chart;
          END IF;

          --------------------------------------
          -- (1) Rebuild segment hierarchies  --
          --------------------------------------
          OPEN c_coa;
          LOOP
             FETCH c_coa INTO r_coa;
             EXIT WHEN c_coa%NOTFOUND;

             ctl_row_id := NULL;
             ctl_value_date := NULL;
             ctl_hierarchy_date := NULL;

             BEGIN
                SELECT ROWID,
                       value_last_update_date,
                       hierarchy_last_update_date
                INTO   ctl_row_id,
                       ctl_value_date,
                       ctl_hierarchy_date
                FROM   dot_gl_coa_segments_ctl
                WHERE  set_of_books_id = r_coa.set_of_books_id
                AND    flex_value_set_id = r_coa.flex_value_set_id;

                IF r_coa.value_date <> ctl_value_date OR
                   (r_coa.hierarchy_date IS NOT NULL AND r_coa.hierarchy_date <> ctl_hierarchy_date)
                THEN
                   idx := idx + 1;
                   t_flex_value_set(idx).row_id := ctl_row_id;
                   t_flex_value_set(idx).set_of_books_id := r_coa.set_of_books_id;
                   t_flex_value_set(idx).application_column_name := r_coa.application_column_name;
                   t_flex_value_set(idx).segment_name := r_coa.segment_name;
                   t_flex_value_set(idx).mview_name := r_coa.mview_name;
                   t_flex_value_set(idx).flex_value_set_id := r_coa.flex_value_set_id;
                   t_flex_value_set(idx).value_last_update_date := r_coa.value_date;
                   t_flex_value_set(idx).hierarchy_last_update_date := r_coa.hierarchy_date;
                   t_flex_value_set(idx).insert_flag := 'N';
                END IF;

             EXCEPTION
                WHEN no_data_found THEN
                   idx := idx + 1;
                   t_flex_value_set(idx).set_of_books_id := r_coa.set_of_books_id;
                   t_flex_value_set(idx).application_column_name := r_coa.application_column_name;
                   t_flex_value_set(idx).segment_name := r_coa.segment_name;
                   t_flex_value_set(idx).mview_name := r_coa.mview_name;
                   t_flex_value_set(idx).flex_value_set_id := r_coa.flex_value_set_id;
                   t_flex_value_set(idx).value_last_update_date := r_coa.value_date;
                   t_flex_value_set(idx).hierarchy_last_update_date := r_coa.hierarchy_date;
                   t_flex_value_set(idx).insert_flag := 'Y';
             END;
          END LOOP;
          CLOSE c_coa;

          IF t_flex_value_set.COUNT > 0 THEN
             FND_FILE.PUT_LINE(FND_FILE.LOG, 'Start rebuild GL Chart of Accounts hierarchy');

             t_hierarchy.DELETE;

             SELECT table_name BULK COLLECT
             INTO   t_hierarchy
             FROM   all_tables
             WHERE  owner = 'FMSMGR'
             AND    table_name LIKE 'DOT_GL_COA_SEGMENT_L%_B'
             ORDER  BY table_name;

             FOR i IN 1 .. t_flex_value_set.COUNT LOOP
                DELETE FROM dot_gl_coa_segments
                WHERE  flex_value_set_id = t_flex_value_set(i).flex_value_set_id;

                FOR j IN 1 .. t_hierarchy.COUNT LOOP
                   l_sql := 'DELETE FROM ' || t_hierarchy(j) || ' WHERE flex_value_set_id = ' || t_flex_value_set(i).flex_value_set_id;
                   EXECUTE IMMEDIATE l_sql;
                END LOOP;

                COMMIT;

                FND_FILE.PUT_LINE(FND_FILE.LOG, 'Set of Books ID: ' || t_flex_value_set(i).set_of_books_id);

                OPEN c_flex_values (t_flex_value_set(i).flex_value_set_id, t_flex_value_set(i).set_of_books_id);
                LOOP
                   FETCH c_flex_values INTO r_flex_value;
                   EXIT WHEN c_flex_values%NOTFOUND;

                   BEGIN
                      SELECT 'x'
                      INTO   dummy
                      FROM   dot_gl_coa_segments
                      WHERE  flex_value_id = r_flex_value.flex_value_id
                      -- arellanod 2017/05/08
                      AND    level_in_hierarchy = r_flex_value.level_in_hierarchy
                      AND    NVL(parent_flex_value_id, -1) = NVL(r_flex_value.parent_flex_value_id, -1);
                   EXCEPTION
                      WHEN no_data_found THEN
                         INSERT INTO dot_gl_coa_segments
                         VALUES r_flex_value;
                      WHEN too_many_rows THEN
                         NULL;
                   END;
                END LOOP;
                CLOSE c_flex_values;

                COMMIT;

                FOR j IN 1 .. t_hierarchy.COUNT LOOP
                   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Update table ' || t_hierarchy(j) || ' (' || t_flex_value_set(i).flex_value_set_id || ')');

                   l_sql := 'INSERT INTO DOT_GL_COA_SEGMENT_L' || j || '_B ' ||
                            'SELECT ' ||
                            'SEGMENT_NAME, ' ||
                            'FLEX_VALUE_SET_ID, ' ||
                            'FLEX_VALUE_SET_NAME, ' ||
                            'FLEX_VALUE_ID, ' ||
                            'FLEX_VALUE, ' ||
                            'FLEX_VALUE_MEANING, ' ||
                            'DESCRIPTION, ' ||
                            'ENABLED_FLAG, ' ||
                            'LEVEL_IN_HIERARCHY, ' ||
                            'PARENT_FLEX_VALUE_ID, ' ||
                            'CREATION_DATE, ' ||
                            'LAST_UPDATE_DATE ' ||
                            'FROM dot_gl_coa_segments  ' ||
                            'WHERE level_in_hierarchy = ' || j || ' ' ||
                            'AND flex_value_set_id = ' || t_flex_value_set(i).flex_value_set_id;

                   EXECUTE IMMEDIATE l_sql;
                END LOOP;

                COMMIT;

                IF t_flex_value_set(i).insert_flag = 'Y' THEN
                   INSERT INTO dot_gl_coa_segments_ctl
                   VALUES (t_flex_value_set(i).set_of_books_id,
                           t_flex_value_set(i).application_column_name,
                           t_flex_value_set(i).segment_name,
                           t_flex_value_set(i).flex_value_set_id,
                           t_flex_value_set(i).value_last_update_date,
                           t_flex_value_set(i).hierarchy_last_update_date,
                           SYSDATE);
                ELSE
                   UPDATE dot_gl_coa_segments_ctl
                   SET    value_last_update_date = t_flex_value_set(i).value_last_update_date,
                          hierarchy_last_update_date = t_flex_value_set(i).hierarchy_last_update_date,
                          last_refresh_date = SYSDATE
                   WHERE  ROWID = t_flex_value_set(i).row_id;
                END IF;

                COMMIT;

             END LOOP;

             FND_FILE.PUT_LINE(FND_FILE.LOG, 'Rebuild chart of accounts successful.');
          END IF;

          <<refresh_chart>>
          ------------------------------------
          -- (2) Refresh chart of accounts  --
          ------------------------------------
          BEGIN
             FOR gl_coa IN (SELECT owner || '.' || mview_name mview
                            FROM   dba_mviews
                            WHERE  owner = 'APPSSQL'
                            AND    mview_name LIKE 'DOT%DW'
                            AND    INSTR(mview_name, 'GL_COA') > 0
                            AND    (  compile_state = 'NEEDS_COMPILE'
                                      OR
                                      staleness IN ('NEEDS_COMPILE', 'STALE')
                                   ))
             LOOP
                IF l_list IS NOT NULL THEN
                   l_list := l_list || ', ';
                END IF;
                l_list := l_list || gl_coa.mview;
                FND_FILE.PUT_LINE(FND_FILE.LOG, gl_coa.mview);
             END LOOP;

             IF l_list IS NOT NULL THEN
                DBMS_MVIEW.REFRESH(list => l_list);
             END IF;

          EXCEPTION
             WHEN others THEN
                l_error := l_error + 1;
                l_sqlerrm := SQLERRM;
                FND_FILE.PUT_LINE(FND_FILE.LOG, l_sqlerrm);
          END;

       END IF;
   END IF;

   IF NVL(p_immediate_flag, 'N') = 'Y' THEN
      RETURN;
   END IF;

   /***************/
   /* Stage #2    */
   /***************/
   -- arellanod
   -- DBA_JOBS are easily broken leads to not implementing MView
   -- refresh by Refresh Group (REP_GROUP_DW) - considered unreliable.

   --Commented by Katie H. on 05-Apr-2016, moved to the top
   --l_req_data := FND_CONC_GLOBAL.REQUEST_DATA;    
   IF (l_req_data IS NOT NULL) THEN
      l_mv_req := TO_NUMBER(l_req_data);
      l_mv_req := l_mv_req + 1;
      IF (l_mv_req > t_mvrefresh.COUNT) THEN
         --Moved by Katie H. on 05-Apr-2016, recommended by Dart
         /***************/
         /* Stage #3    */
         /***************/
         FND_FILE.PUT_LINE(FND_FILE.LOG, 'Processing STAGE #3 @ '||to_char(sysdate,'DD-MON-YYYY HH24:MI:SS')); --Added by Katie H. on 04-Apr-2016
         l_close := FND_REQUEST.SUBMIT_REQUEST(application => 'FNDC',
                                               program     => 'DOTREFMVCX',
                                               description => '',
                                               start_time  => NULL,
                                               sub_request => FALSE,
                                               argument1   => gn_request_id);
         COMMIT;
         --end 05-Apr-2016
         p_errbuff := 'Refresh completed';
         p_retcode := 0;
         IF l_error > 0 THEN
            p_retcode := 2;
         END IF;
         RETURN;
      END IF;
   ELSE
      --Moved by Katie H. on 05-Apr-2016
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Processing STAGE #2 @ '||to_char(sysdate,'DD-MON-YYYY HH24:MI:SS')); --Added by Katie H. on 04-Apr-2016
      update_control_table(gn_request_id, NULL, 2);
      l_mv_req := 1;
   END IF;

   SELECT owner,
          mview_name
          BULK COLLECT
   INTO   t_mvrefresh
   FROM   (SELECT owner,
                  mview_name
           FROM   dba_mviews
           WHERE  owner = 'APPSSQL'
           AND    mview_name LIKE 'DOT%DW'
           AND    INSTR(mview_name, 'GL_COA') = 0  -- arellanod 28/07/2015
           AND    (  compile_state = 'NEEDS_COMPILE'
                     OR
                     staleness IN ('NEEDS_COMPILE', 'STALE')
                  )
           UNION ALL
           SELECT 'APPSSQL',
                  mview_table_name
           FROM   dot_refresh_table_types);

   FOR r_mv IN 1 .. t_mvrefresh.COUNT LOOP
      c_req := c_req + 1;
      l_log := 'Refresh ' || t_mvrefresh(r_mv).mview_name;

      t_mvrefresh_req(c_req) := FND_REQUEST.SUBMIT_REQUEST(application => 'FNDC',
                                                           program     => 'DOTREFMVEC',
                                                           description => l_log,
                                                           start_time  => NULL,
                                                           sub_request => TRUE,
                                                           argument1   => gn_request_id,
                                                           argument2   => t_mvrefresh(r_mv).mview_name,
                                                           argument3   => NVL(p_full_refresh, 'N'),
                                                           argument4   => 'N');

      l_log := 'Sub-request ' || t_mvrefresh_req(c_req) || ' ' || l_log || ' Full Refresh (Y/N) = ' || NVL(p_full_refresh, 'N');
      FND_FILE.PUT_LINE(FND_FILE.LOG, l_log ||' @ '||to_char(sysdate,'DD-MON-YYYY HH24:MI:SS'));
   END LOOP;

   FND_CONC_GLOBAL.SET_REQ_GLOBALS(conc_status  => 'PAUSED',
                                   request_data => TO_CHAR(l_mv_req)) ;
   /***************/
   /* Stage #3    */
   /***************/
   --Commented by Katie H. on 05-Apr-2016, moved to the top, recommended by Dart
   /*FND_FILE.PUT_LINE(FND_FILE.LOG, 'Processing STAGE #3 @ '||to_char(sysdate,'DD-MON-YYYY HH24:MI:SS')); --Added by Katie H. on 04-Apr-2016
   l_close := FND_REQUEST.SUBMIT_REQUEST(application => 'FNDC',
                                         program     => 'DOTREFMVCX',
                                         description => '',
                                         start_time  => NULL,
                                         sub_request => FALSE,
                                         argument1   => gn_request_id);

   COMMIT;
   */

   RETURN;

EXCEPTION
   WHEN others THEN
      p_retcode := 2;
      update_control_table(gn_request_id, gd_request_date, -1);
      l_sqlerrm := SQLERRM;
      FND_FILE.PUT_LINE(FND_FILE.LOG, l_sqlerrm);
END refresh_dw;

---------------------------
PROCEDURE refresh_gl_mviews
(
   p_errbuff         OUT VARCHAR2,
   p_retcode         OUT NUMBER,
   p_rebuild         IN  VARCHAR2
)
IS
   lv_errbuff        VARCHAR2(600);
   ln_retcode        NUMBER;
BEGIN

   IF NVL(p_rebuild, 'N') = 'Y' THEN
      UPDATE dot_gl_coa_segments_ctl
      SET    value_last_update_date = gd_reset_date,
             hierarchy_last_update_date = gd_reset_date
      WHERE  set_of_books_id = gn_dedjtr_book_id;

      IF sql%FOUND THEN
         COMMIT;
      END IF;
   END IF;

   refresh_dw(p_errbuff => lv_errbuff,
              p_retcode => ln_retcode,
              p_include_coa => 'Y',
              p_full_refresh => 'N',
              p_immediate_flag => 'Y');

   IF ln_retcode IS NULL THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Refresh GL Chart of Accounts completed.');
   ELSE
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Refresh GL Chart of Accounts failed.');
      p_retcode := 2;
   END IF;

   update_mview(p_errbuff => lv_errbuff,
                p_retcode => ln_retcode,
                p_request_id => NULL,
                p_mview_name => 'DOT_GL_JOURNALS_DW',
                p_full_refresh => 'N',
                p_immediate_flag => 'Y');

   IF ln_retcode IS NULL THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Refresh GL Journals completed.');
   ELSE
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Refresh GL Journals failed.');
      p_retcode := 2;
   END IF;

   update_mview(p_errbuff => lv_errbuff,
                p_retcode => ln_retcode,
                p_request_id => NULL,
                p_mview_name => 'DOT_GL_BALANCES_DW',
                p_full_refresh => 'N',
                p_immediate_flag => 'Y');

   IF ln_retcode IS NULL THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Refresh GL Balances completed.');
   ELSE
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Refresh GL Balances failed.');
      p_retcode := 2;
   END IF;

   COMMIT;
END refresh_gl_mviews;

------------------------------
PROCEDURE update_ar_link_to_gl
(
   p_source    source_tab_type
)
IS
   -- utilize index
   CURSOR c_rec (p_cash_receipt_id  NUMBER) IS
      SELECT cr.cash_receipt_id,
             cr.set_of_books_id,
             gpe.period_name,
             COUNT(1) history_count
      FROM   ar_cash_receipts_all cr,
             ar_cash_receipt_history_all crh,
             gl_sets_of_books gsb,
             gl_periods gpe
      WHERE  cr.cash_receipt_id = p_cash_receipt_id
      AND    cr.cash_receipt_id = crh.cash_receipt_id
      AND    cr.set_of_books_id = gsb.set_of_books_id
      AND    gsb.period_set_name = gpe.period_set_name
      -- arellanod 05/11/2015 --AND crh.gl_posted_date BETWEEN gpe.start_date AND gpe.end_date
      AND    crh.gl_date BETWEEN gpe.start_date AND gpe.end_date
      GROUP  BY
             cr.cash_receipt_id,
             cr.set_of_books_id,
             gpe.period_name;

   r_rec         c_rec%ROWTYPE;
   l_sql         VARCHAR2(1000);

   PRAGMA        AUTONOMOUS_TRANSACTION;

BEGIN
   l_sql := 'TRUNCATE TABLE FMSMGR.DOT_AR_RECEIPTS_TO_GL';
   EXECUTE IMMEDIATE l_sql;

   IF p_source.COUNT > 0 THEN
      FOR s IN 1 .. p_source.COUNT LOOP
         OPEN c_rec (p_source(s).source_id);
         LOOP
            FETCH c_rec INTO r_rec;
            EXIT WHEN c_rec%NOTFOUND;

            INSERT INTO dot_ar_receipts_to_gl
            SELECT TO_NUMBER(DECODE(INSTR(jel.reference_2, 'C'),
                             0, jel.reference_2,
                             SUBSTR(jel.reference_2, 1, INSTR(jel.reference_2, 'C') - 1)))
                             cash_receipt_id,
                   jel.code_combination_id,
                   jel.reference_3 line_id,
                   jel.reference_4 receipt_number,
                   jel.reference_8 receipt_type,
                   jel.effective_date gl_date,
                   jel.period_name gl_period,
                   jeb.name gl_batch_name,
                   jeh.je_source user_je_source_name,
                   jeh.je_category user_je_category_name,
                   jeh.actual_flag,
                   jel.je_header_id,
                   jel.je_line_num
            FROM   gl_je_lines jel,
                   gl_je_headers jeh,
                   gl_je_batches jeb,
                   gl_sets_of_books gsb
            WHERE  jel.reference_10 IN ('AR_CASH_RECEIPT_HISTORY', 'AR_MISC_CASH_DISTRIBUTIONS')
            AND    jel.je_header_id = jeh.je_header_id
            AND    jeh.je_batch_id = jeb.je_batch_id
            AND    jeh.status = 'P'
            AND    jeh.je_source = 'Receivables'
            AND    jeh.je_category IN ('Trade Receipts', 'Misc Receipts')
            AND    jeh.set_of_books_id = gsb.set_of_books_id
            AND    jeh.set_of_books_id = r_rec.set_of_books_id    -- utilizes index
            AND    jeh.period_name = r_rec.period_name            -- utilizes index
            AND    TO_NUMBER(DECODE(INSTR(jel.reference_2, 'C'),
                             0, jel.reference_2,
                             SUBSTR(jel.reference_2, 1, INSTR(jel.reference_2, 'C') - 1))) = r_rec.cash_receipt_id;
         END LOOP;
         CLOSE c_rec;
      END LOOP;
   END IF;

   COMMIT;

END update_ar_link_to_gl;

--------------------------
PROCEDURE update_mview_job
(
   p_request_id        NUMBER,
   p_request_date      DATE,
   p_mview_name        VARCHAR2,
   p_status            VARCHAR2,
   p_sub_request_id    NUMBER,
   p_error_message     VARCHAR2
)
IS
   l_mview      NUMBER;
   l_type       VARCHAR2(60) := 'TABLE';
BEGIN
   UPDATE dot_refresh_mview_jobs
   SET    sub_request_status = p_status,
          refresh_end_date = SYSDATE,
          error_message = p_error_message
   WHERE  request_id = p_request_id
   AND    sub_request_id = p_sub_request_id
   AND    mview_name = p_mview_name;

   IF sql%ROWCOUNT = 0 THEN
      SELECT COUNT(1)
      INTO   l_mview
      FROM   dba_mviews
      WHERE  mview_name = p_mview_name;

      IF l_mview > 0 THEN
         l_type := 'MVIEW';
      END IF;

      INSERT INTO dot_refresh_mview_jobs
      VALUES (p_request_id,
              p_request_date,
              p_mview_name,
              l_type,
              p_sub_request_id,
              p_status,
              SYSDATE,
              NULL,
              NULL);
   END IF;
END update_mview_job;

----------------------
PROCEDURE update_mview
(
   p_errbuff         OUT  VARCHAR2,
   p_retcode         OUT  NUMBER,
   p_request_id      IN   NUMBER,
   p_mview_name      IN   VARCHAR2,
   p_full_refresh    IN   VARCHAR2,
   p_immediate_flag  IN   VARCHAR2
)
IS
   CURSOR c_xper IS
      SELECT b.set_of_books_id,
             p.period_set_name,
             p.period_name,
             p.period_year
      FROM   gl_sets_of_books b,
             gl_periods p,
            (SELECT per.period_set_name,
                    per.period_year - 7 period_year
             FROM   gl_periods per
             WHERE  per.period_type <> 'Year'
             AND    NVL(per.adjustment_period_flag, 'N') = 'N'
             AND    TRUNC(SYSDATE) BETWEEN per.start_date AND per.end_date) x
      WHERE  b.period_set_name = p.period_set_name
      AND    p.period_set_name = x.period_set_name
      AND    p.period_year < x.period_year
      AND    p.period_year > (x.period_year -3)
      AND    p.period_type <> 'Year'
      AND    NVL(p.adjustment_period_flag, 'N') = 'N';

   r_xper                  c_xper%ROWTYPE;

   t_source                source_tab_type;
   l_last_update_date      DATE;
   l_last_request_date     DATE;
   l_day                   VARCHAR2(15);
   l_mview                 VARCHAR2(80);
   l_sub_request_id        NUMBER;
   l_sqlerrm               VARCHAR2(600);
   l_sql                   VARCHAR2(1000);

BEGIN
   l_sub_request_id := FND_GLOBAL.CONC_REQUEST_ID;

   IF p_mview_name IS NULL THEN
      RETURN;
   END IF;

   BEGIN
      SELECT MAX(TRUNC(request_date))
      INTO   l_last_update_date
      FROM   appssql.dot_refresh_mviews_control
      WHERE  mview = 'DW'
      AND    request_id <> p_request_id;
   EXCEPTION
      WHEN no_data_found THEN NULL;
   END;

   BEGIN
      SELECT MAX(TRUNC(request_date))
      INTO   l_last_request_date
      FROM   dot_refresh_mview_jobs
      WHERE  mview_name = p_mview_name
      AND    sub_request_status = 'S';
   EXCEPTION
      WHEN no_data_found THEN NULL;
   END;

   IF l_last_request_date IS NOT NULL AND
      l_last_update_date IS NOT NULL THEN
      l_last_update_date := LEAST(l_last_request_date, l_last_update_date);
   ELSIF l_last_update_date IS NULL THEN
      l_last_update_date := l_last_request_date;
   END IF;

   IF l_last_update_date IS NULL THEN
      l_day := TO_CHAR(SYSDATE, 'DAY');

      IF l_day = 'MONDAY' THEN
         l_last_update_date := TRUNC(SYSDATE - 3);
      ELSE
         l_last_update_date := TRUNC(SYSDATE - 1);
      END IF;
   END IF;

   t_source.DELETE;

   -- <Start>
   IF NVL(p_immediate_flag, 'N') = 'N' THEN
      update_mview_job(p_request_id, SYSDATE, p_mview_name, 'N', l_sub_request_id, NULL);
   END IF;

   IF p_mview_name = 'DOT_AP_INVOICES_DW' THEN
      IF p_full_refresh = 'Y' THEN
         l_sql := 'TRUNCATE TABLE APPSSQL.DOT_AP_INVOICES_DW';
         EXECUTE IMMEDIATE l_sql;

         l_sql := 'INSERT INTO APPSSQL.DOT_AP_INVOICES_DW SELECT * FROM DOT_AP_INVOICES_W';
         EXECUTE IMMEDIATE l_sql;
      ELSE
         SELECT aid.invoice_id, COUNT(1)
                BULK COLLECT INTO t_source
         FROM   ap_invoice_distributions_all aid,
                ap_invoices_all aia
         WHERE  aia.invoice_id = aid.invoice_id
         AND    GREATEST(aid.last_update_date, aia.last_update_date) >= l_last_update_date
         GROUP  BY aid.invoice_id;

         IF t_source.COUNT > 0 THEN
            FOR t IN 1 .. t_source.COUNT LOOP
               DELETE FROM appssql.dot_ap_invoices_dw
               WHERE  invoice_id = t_source(t).source_id;

               INSERT INTO appssql.dot_ap_invoices_dw
               SELECT *
               FROM   dot_ap_invoices_w
               WHERE  invoice_id = t_source(t).source_id;
            END LOOP;
         END IF;

         FOR r_xper IN c_xper LOOP
            DELETE FROM appssql.dot_ap_invoices_dw
            WHERE  set_of_books_id = r_xper.set_of_books_id
            AND    gl_period = r_xper.period_name;
         END LOOP;
      END IF;

   ELSIF p_mview_name = 'DOT_GL_JOURNALS_DW' THEN
      IF p_full_refresh = 'Y' THEN
         l_sql := 'TRUNCATE TABLE APPSSQL.DOT_GL_JOURNALS_DW';
         EXECUTE IMMEDIATE l_sql;

         l_sql := 'INSERT INTO APPSSQL.DOT_GL_JOURNALS_DW SELECT * FROM DOT_GL_JOURNALS_W';
         EXECUTE IMMEDIATE l_sql;
      ELSE
         SELECT jeh.je_header_id, COUNT(1)
                BULK COLLECT INTO t_source
         FROM   gl_je_headers jeh,
                gl_je_lines jel
         WHERE  jeh.je_header_id = jel.je_header_id
         AND    jeh.status = 'P'
         AND    GREATEST(jeh.last_update_date, jel.last_update_date) >= l_last_update_date
         GROUP  BY jeh.je_header_id;

         IF t_source.COUNT > 0 THEN
            FOR t IN 1 .. t_source.COUNT LOOP
               DELETE FROM appssql.dot_gl_journals_dw
               WHERE  je_header_id = t_source(t).source_id;

               INSERT INTO appssql.dot_gl_journals_dw
               SELECT *
               FROM   dot_gl_journals_w
               WHERE  je_header_id = t_source(t).source_id;
            END LOOP;
         END IF;

         FOR r_xper IN c_xper LOOP
            DELETE FROM appssql.dot_gl_journals_dw
            WHERE  set_of_books_id = r_xper.set_of_books_id
            AND    period_name = r_xper.period_name;
         END LOOP;
      END IF;

   ELSIF p_mview_name = 'DOT_AR_RECEIPTS_DW' THEN
      IF p_full_refresh = 'Y' THEN
         FND_FILE.PUT_LINE(FND_FILE.LOG, 'Full refresh is not applicable to DOT_AR_RECEIPTS_DW. Re-run build table script instead of full refresh. Please contact your system administrator.');
      ELSE
         SELECT  acr.cash_receipt_id, COUNT(1)
                 BULK COLLECT INTO t_source
         FROM    ar_cash_receipts_all acr,
                 ar_cash_receipt_history_all ach,
                 ar_misc_cash_distributions_all amc
         WHERE   acr.cash_receipt_id = amc.cash_receipt_id(+)
         AND     acr.cash_receipt_id = ach.cash_receipt_id
         AND     GREATEST(acr.last_update_date, ach.last_update_date, NVL(amc.last_update_date, acr.last_update_date)) >= l_last_update_date
         GROUP   BY acr.cash_receipt_id;

         IF t_source.COUNT > 0 THEN
            update_ar_link_to_gl(t_source);

            FOR t IN 1 .. t_source.COUNT LOOP
               DELETE FROM appssql.dot_ar_receipts_dw
               WHERE  receipt_id = t_source(t).source_id;

               INSERT INTO appssql.dot_ar_receipts_dw
               SELECT *
               FROM   dot_ar_receipts_w
               WHERE  receipt_id = t_source(t).source_id;
            END LOOP;
         END IF;

         FOR r_xper IN c_xper LOOP
            DELETE FROM appssql.dot_ar_receipts_dw
            WHERE  set_of_books_id = r_xper.set_of_books_id
            AND    gl_period = r_xper.period_name;
         END LOOP;
      END IF;

   ELSIF p_mview_name = 'DOT_PO_RECEIPTS_DW' THEN
      IF p_full_refresh = 'Y' THEN
         l_sql := 'TRUNCATE TABLE APPSSQL.DOT_PO_RECEIPTS_DW';
         EXECUTE IMMEDIATE l_sql;

         l_sql := 'INSERT INTO APPSSQL.DOT_PO_RECEIPTS_DW SELECT * FROM DOT_PO_RECEIPTS_W';
         EXECUTE IMMEDIATE l_sql;
      ELSE
         SELECT rsh.shipment_header_id, COUNT(1)
                BULK COLLECT INTO t_source
         FROM   rcv_shipment_headers rsh,
                rcv_shipment_lines rsl,
                rcv_transactions rct
         WHERE  rsh.shipment_header_id = rsl.shipment_header_id
         AND    rct.shipment_header_id = rsh.shipment_header_id
         AND    rct.shipment_line_id = rsl.shipment_line_id
         AND    GREATEST(rsh.last_update_date, rsl.last_update_date, rct.last_update_date) >= l_last_update_date
         GROUP  BY rsh.shipment_header_id;

         IF t_source.COUNT > 0 THEN
            FOR t IN 1 .. t_source.COUNT LOOP
               DELETE FROM appssql.dot_po_receipts_dw
               WHERE  shipment_header_id = t_source(t).source_id;

               INSERT INTO appssql.dot_po_receipts_dw
               SELECT *
               FROM   dot_po_receipts_w
               WHERE  shipment_header_id = t_source(t).source_id;
            END LOOP;
         END IF;

         DELETE FROM appssql.dot_po_receipts_dw
         WHERE  po_header_id IN (
            SELECT pod.po_header_id
            FROM   ap_invoice_distributions_all aid,
                   po_distributions_all pod,
                   gl_sets_of_books gsb,
                   gl_periods gpe,
                  (SELECT (period_year - 7) period_year,
                          period_set_name
                   FROM   gl_periods
                   WHERE  TRUNC(SYSDATE) BETWEEN start_date AND end_date
                   AND    NVL(adjustment_period_flag, 'N') = 'N'
                   AND    period_type <> 'Year') gpr
            WHERE  aid.po_distribution_id = pod.po_distribution_id
            AND    aid.set_of_books_id = gsb.set_of_books_id
            AND    gsb.period_set_name = gpe.period_set_name
            AND    gsb.period_set_name = gpr.period_set_name
            AND    aid.period_name = gpe.period_name
            AND    gpe.period_year < gpr.period_year
            UNION
            SELECT pohx.po_header_id
            FROM   po_headers_all pohx,
                   po_distributions_all podx,
                   gl_sets_of_books gsb,
                   gl_periods gpe,
                  (SELECT (period_year - 7) period_year,
                          period_set_name
                   FROM   gl_periods
                   WHERE  TRUNC(SYSDATE) BETWEEN start_date AND end_date
                   AND    NVL(adjustment_period_flag, 'N') = 'N'
                   AND    period_type <> 'Year') gpr
            WHERE  pohx.po_header_id = podx.po_header_id
            AND   (
                     pohx.closed_code IN ('CLOSED' , 'FINALLY CLOSED')
                     OR
                    (SELECT NVL(SUM(pols.quantity * pols.unit_price), 0)
                     FROM   po_lines_all pols
                     WHERE  pols.po_header_id = pohx.po_header_id
                     AND    NVL(pols.cancel_flag, 'N') = 'N') = 0
                  )
            AND    podx.set_of_books_id = gsb.set_of_books_id
            AND    gsb.period_set_name = gpe.period_set_name
            AND    gsb.period_set_name = gpr.period_set_name
            AND    podx.gl_encumbered_period_name = gpe.period_name
            AND    gpe.period_year < gpr.period_year
            );
      END IF;

   ELSIF p_mview_name = 'DOT_AP_PAYMENTS_DW' THEN
      IF p_full_refresh = 'Y' THEN
         l_sql := 'TRUNCATE TABLE APPSSQL.DOT_AP_PAYMENTS_DW';
         EXECUTE IMMEDIATE l_sql;

         l_sql := 'INSERT INTO APPSSQL.DOT_AP_PAYMENTS_DW SELECT * FROM DOT_AP_PAYMENT_W';
         EXECUTE IMMEDIATE l_sql;
      ELSE
         SELECT aca.check_id, COUNT(1)
                BULK COLLECT INTO t_source
         FROM   ap_checks_all aca,
                ap_invoice_payments_all aip
         WHERE  aca.check_id = aip.check_id
         AND    GREATEST(aca.last_update_date, aip.last_update_date) >= l_last_update_date
         GROUP  BY aca.check_id;

         IF t_source.COUNT > 0 THEN
            FOR t IN 1 .. t_source.COUNT LOOP
               DELETE FROM appssql.dot_ap_payments_dw
               WHERE  check_id = t_source(t).source_id;

               INSERT INTO appssql.dot_ap_payments_dw
               SELECT *
               FROM   dot_ap_payments_w
               WHERE  check_id = t_source(t).source_id;
            END LOOP;
         END IF;

         FOR r_xper IN c_xper LOOP
            DELETE FROM appssql.dot_ap_payments_dw
            WHERE  set_of_books_id = r_xper.set_of_books_id
            AND    gl_period = r_xper.period_name;
         END LOOP;

         -- AP Invoices dependent
         -- May still encounter row rejections but
         -- count should be negligible.
         DELETE FROM appssql.dot_ap_payments_dw aipa
         WHERE NOT EXISTS
            (SELECT 'x'
             FROM   appssql.dot_ap_invoices_dw apin
             WHERE  apin.invoice_id = aipa.invoice_id);

      END IF;

   ELSIF p_mview_name = 'DOT_FA_ASSET_INVOICES_DW' THEN
      IF p_full_refresh = 'Y' THEN
         l_sql := 'TRUNCATE TABLE APPSSQL.DOT_FA_ASSET_INVOICES_DW';
         EXECUTE IMMEDIATE l_sql;

         l_sql := 'INSERT INTO APPSSQL.DOT_FA_ASSET_INVOICES_DW SELECT * FROM DOT_FA_ASSET_INVOICES_W';
         EXECUTE IMMEDIATE l_sql;
      ELSE
         SELECT fai.asset_invoice_id, COUNT(1)
                BULK COLLECT INTO t_source
         FROM   fa_asset_invoices fai,
                ap_invoice_distributions_all aid
         WHERE  fai.invoice_id = aid.invoice_id
         AND    GREATEST(fai.last_update_date, aid.last_update_date) >= l_last_update_date
         GROUP  BY fai.asset_invoice_id;

         IF t_source.COUNT > 0 THEN
            FOR t IN 1 .. t_source.COUNT LOOP
               DELETE FROM appssql.dot_fa_asset_invoices_dw
               WHERE  asset_invoice_id = t_source(t).source_id;

               INSERT INTO appssql.dot_fa_asset_invoices_dw
               SELECT *
               FROM   dot_fa_asset_invoices_w
               WHERE  asset_invoice_id = t_source(t).source_id;
            END LOOP;
         END IF;

         DELETE FROM appssql.dot_fa_asset_invoices_dw
         WHERE  po_distribution_id IN (
            SELECT pod.po_distribution_id
            FROM   ap_invoice_distributions_all aid,
                   po_distributions_all pod,
                   gl_sets_of_books gsb,
                   gl_periods gpe,
                  (SELECT (period_year - 7) period_year,
                          period_set_name
                   FROM   gl_periods
                   WHERE  TRUNC(SYSDATE) BETWEEN start_date AND end_date
                   AND    NVL(adjustment_period_flag, 'N') = 'N'
                   AND    period_type <> 'Year') gpr
            WHERE  aid.po_distribution_id = pod.po_distribution_id
            AND    aid.set_of_books_id = gsb.set_of_books_id
            AND    gsb.period_set_name = gpe.period_set_name
            AND    gsb.period_set_name = gpr.period_set_name
            AND    aid.period_name = gpe.period_name
            AND    gpe.period_year < gpr.period_year
            UNION
            SELECT podx.po_distribution_id
            FROM   po_headers_all pohx,
                   po_distributions_all podx,
                   gl_sets_of_books gsb,
                   gl_periods gpe,
                  (SELECT (period_year - 7) period_year,
                          period_set_name
                   FROM   gl_periods
                   WHERE  TRUNC(SYSDATE) BETWEEN start_date AND end_date
                   AND    NVL(adjustment_period_flag, 'N') = 'N'
                   AND    period_type <> 'Year') gpr
            WHERE  pohx.po_header_id = podx.po_header_id
            AND   (
                     pohx.closed_code IN ('CLOSED' , 'FINALLY CLOSED')
                     OR
                    (SELECT NVL(SUM(pols.quantity * pols.unit_price), 0)
                     FROM   po_lines_all pols
                     WHERE  pols.po_header_id = pohx.po_header_id
                     AND    NVL(pols.cancel_flag, 'N') = 'N') = 0
                  )
            AND    podx.set_of_books_id = gsb.set_of_books_id
            AND    gsb.period_set_name = gpe.period_set_name
            AND    gsb.period_set_name = gpr.period_set_name
            AND    podx.gl_encumbered_period_name = gpe.period_name
            AND    gpe.period_year < gpr.period_year
            );

         DELETE FROM appssql.dot_fa_asset_invoices_dw
         WHERE  invoice_distribution_id IN (
            SELECT aid.invoice_distribution_id
            FROM   ap_invoice_distributions_all aid,
                   gl_sets_of_books gsb,
                   gl_periods gpe,
                  (SELECT period_set_name,
                          period_year - 7 period_year_low,
                          period_year period_year_high
                   FROM   gl_periods
                   WHERE  NVL(adjustment_period_flag, 'N') = 'N'
                   AND    period_type <> 'Year'
                   AND    TRUNC(SYSDATE) BETWEEN start_date AND end_date) gpr
            WHERE  aid.set_of_books_id = gsb.set_of_books_id
            AND    gsb.period_set_name = gpe.period_set_name
            AND    aid.accounting_date BETWEEN gpe.start_date AND gpe.end_date
            AND    gpe.period_type <> 'Year'
            AND    gsb.period_set_name = gpr.period_set_name
            AND    gpe.period_year < gpr.period_year_low);

      END IF;

   ELSE
      -- parallelism in the MView definition
      l_mview := 'APPSSQL.' || p_mview_name;
      DBMS_MVIEW.REFRESH(l_mview);

   END IF;

   -- <End>
   IF NVL(p_immediate_flag, 'N') = 'N' THEN
      update_mview_job(p_request_id, SYSDATE, p_mview_name, 'S', l_sub_request_id, NULL);
   END IF;
   COMMIT;

EXCEPTION
   WHEN others THEN
      l_sqlerrm := p_mview_name || ' (' || SQLERRM || ')';
      update_mview_job(p_request_id, SYSDATE, p_mview_name, 'E', l_sub_request_id, l_sqlerrm);
      FND_FILE.PUT_LINE(FND_FILE.LOG, l_sqlerrm);

END update_mview;

-----------------------
PROCEDURE close_process
(
   p_errbuff      OUT  VARCHAR2,
   p_retcode      OUT  NUMBER,
   p_request_id   IN   NUMBER
)
IS
   CURSOR c_stats IS
      SELECT 'Sub Request ID  MVIEW Name                       Hrs  Mins' stats
      FROM   dual
      UNION  ALL
      SELECT '--------------  -------------------------------  ---  ----' stats
      FROM   dual
      UNION ALL
      SELECT RPAD(TO_CHAR(sub_request_id), 15, ' ') || ' ' ||
             RPAD(mview_name, 32, ' ') || ' ' ||
             TRIM(TO_CHAR(TRUNC(((86400 * (refresh_end_date - refresh_start_date)) / 60) / 60) - 24 * (TRUNC((((86400 * (refresh_end_date - refresh_start_date)) / 60) / 60) / 24)), '00')) || '   ' ||
             TRIM(TO_CHAR(TRUNC((86400 * (refresh_end_date - refresh_start_date)) / 60) - 60 * (TRUNC(((86400 * (refresh_end_date - refresh_start_date)) / 60) / 60)), '00')) stats
      FROM   dot_refresh_mview_jobs
      WHERE  request_id = p_request_id;

   l_wait                 NUMBER;
   l_duration             NUMBER;
   l_hours                VARCHAR2(10);
   l_minutes              VARCHAR2(10);

   -- SRS
   srs_wait               BOOLEAN;
   srs_phase              VARCHAR2(30);
   srs_status             VARCHAR2(30);
   srs_dev_phase          VARCHAR2(30);
   srs_dev_status         VARCHAR2(30);
   srs_message            VARCHAR2(240);
   error_message          VARCHAR2(600);
BEGIN
   -------------------------------------------------------
   -- Pause program for 5 minutes.                      --
   -- Maximum allowable wait time to get all requests   --
   -- committed in DOT_REFRESH_MVIEW_JOBS table.        --
   -------------------------------------------------------
   dbms_lock.sleep(300);

   LOOP
      l_wait := 0;

      FOR i IN (SELECT r.request_id,
                       r.phase_code
                FROM   dot_refresh_mview_jobs j,
                       fnd_concurrent_requests r
                WHERE  j.request_id = p_request_id
                AND    j.sub_request_id = r.request_id)
      LOOP
         IF i.phase_code <> 'C' THEN
            l_wait := l_wait + 1;
            srs_wait := fnd_concurrent.wait_for_request(i.request_id,
                                                        60,
                                                        0,
                                                        srs_phase,
                                                        srs_status,
                                                        srs_dev_phase,
                                                        srs_dev_status,
                                                        srs_message);
         END IF;
      END LOOP;

      IF l_wait = 0 THEN
         EXIT;
      END IF;
   END LOOP;

   FND_FILE.PUT_LINE(FND_FILE.LOG, 'Processing STAGE #3 @ '||to_char(sysdate,'DD-MON-YYYY HH24:MI:SS')); --Added by Katie H. on 04-Apr-2016
   update_control_table(p_request_id, NULL, 3);

   -- Simple statistics report
   SELECT SYSDATE - actual_start_date
   INTO   l_duration
   FROM   fnd_concurrent_requests
   WHERE  request_id = p_request_id;

   FOR r_stat IN c_stats LOOP
      FND_FILE.PUT_LINE(FND_FILE.LOG, r_stat.stats);
   END LOOP;

   BEGIN
      SELECT TRIM(TO_CHAR(TRUNC(((86400 * (l_duration)) / 60) / 60) - 24 * (TRUNC((((86400 * (l_duration)) / 60) / 60) / 24)), '00')),
             TRIM(TO_CHAR(TRUNC((86400 * (l_duration)) / 60) - 60 * (TRUNC(((86400 * (l_duration)) / 60) / 60)), '00'))
      INTO   l_hours,
             l_minutes
      FROM   dual;

      FND_FILE.NEW_LINE(FND_FILE.LOG);
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'Refresh Materialized Views Completed (' || l_hours || ' hrs ' || l_minutes || ' mins)');

   EXCEPTION
      WHEN others THEN NULL;
   END;

   update_control_table(p_request_id, NULL, 100);

EXCEPTION
   WHEN others THEN
      p_retcode := 2;
      error_message := SQLERRM;
      FND_FILE.PUT_LINE(FND_FILE.LOG, error_message);

      update_control_table(p_request_id, NULL, -1);

END close_process;

----------------------
PROCEDURE notify_users
(
   p_scope           IN  VARCHAR2,
   p_manual_mv_1     IN  VARCHAR2,
   p_manual_mv_2     IN  VARCHAR2,
   p_request_id      IN  NUMBER,
   p_program_id      IN  NUMBER,
   p_status          OUT VARCHAR2,
   p_error_message   OUT VARCHAR2
)
IS
   CURSOR c_host IS
      SELECT machine,
             osuser
      FROM   v$session
      WHERE  status = 'ACTIVE'
      AND    process IS NULL;

   CURSOR c_db IS
      SELECT instance_name,
             host_name
      FROM   v$instance;

   t_mviews         mview_tab_type;
   l_message        VARCHAR2(32000);
   l_line_buff      VARCHAR2(32000);
   l_manual_mv_1    VARCHAR2(600) := p_manual_mv_1;
   l_manual_mv_2    VARCHAR2(600) := p_manual_mv_2;
   l_request_date   DATE;
   l_report_row     NUMBER := 0;
   l_mview_name     VARCHAR2(150);
   l_staleness      VARCHAR2(150);
   l_stale_since    VARCHAR2(50);
   l_compile_state  VARCHAR2(150);

   -- EMAIL Properties
   c                utl_smtp.connection;
   l_host           VARCHAR2(150);
   l_sender         VARCHAR2(150);
   l_instance_name  VARCHAR2(150);
   l_host_name      VARCHAR2(150);
   l_header         VARCHAR2(640);
   l_subject        VARCHAR2(640);
   l_boundary       VARCHAR2(32) := sys_guid();
   t_recipient      recipient_tab_type;
   l_r_ctr          NUMBER := 0;

   -- Email Parameter File
   f_handle         UTL_FILE.FILE_TYPE;
   f_exists         BOOLEAN;
   f_len            NUMBER;
   f_bsize          NUMBER;

BEGIN

   IF p_request_id IS NOT NULL THEN
      BEGIN
         SELECT rp.user_concurrent_program_name,
                rq.request_date
         INTO   l_subject,
                l_request_date
         FROM   fnd_concurrent_programs_tl rp,
                fnd_concurrent_requests rq
         WHERE  rp.concurrent_program_id = rq.concurrent_program_id
         AND    rq.request_id = p_request_id;

      EXCEPTION
         WHEN no_data_found THEN
            SELECT rp.user_concurrent_program_name,
                   SYSDATE
            INTO   l_subject,
                   l_request_date
            FROM   fnd_concurrent_programs_tl rp
            WHERE  rp.concurrent_program_id = p_program_id;
      END;
   ELSE
      IF p_program_id IS NOT NULL THEN
         BEGIN
            SELECT rp.user_concurrent_program_name,
                   SYSDATE
            INTO   l_subject,
                   l_request_date
            FROM   fnd_concurrent_programs_tl rp
            WHERE  rp.concurrent_program_id = p_program_id;
         EXCEPTION
            WHEN no_data_found THEN
               NULL;
         END;
      END IF;
   END IF;

   IF p_request_id IS NOT NULL THEN
      l_subject := 'Request ID: ' || p_request_id || ' ' || l_subject;
   END IF;

   UTL_FILE.FGETATTR(gv_param_dir,
                     gv_param_file,
                     f_exists,
                     f_len,
                     f_bsize);

   IF f_exists THEN
      -- server
      OPEN c_db;
      FETCH c_db INTO l_instance_name, l_host_name;
      CLOSE c_db;

      OPEN c_host;
      FETCH c_host INTO l_host, l_sender;
      IF c_host%FOUND THEN
         f_handle := UTL_FILE.FOPEN(gv_param_dir, gv_param_file, 'r');
         LOOP
            BEGIN
               UTL_FILE.GET_LINE(f_handle, l_line_buff);
               IF SUBSTR(l_line_buff, 1, 2) = '$1' THEN
                  LOOP
                     l_r_ctr := l_r_ctr + 1;
                     IF INSTR(l_line_buff, '<', 1, l_r_ctr) > 0 AND
                        INSTR(l_line_buff, '>', 1, l_r_ctr) > 0 THEN
                        t_recipient(l_r_ctr) := SUBSTR(l_line_buff, INSTR(l_line_buff, '<', 1, l_r_ctr) + 1,
                                                                    INSTR(l_line_buff, '>', 1, l_r_ctr) - (INSTR(l_line_buff, '<', 1, l_r_ctr) + 1));
                        IF l_header IS NOT NULL THEN
                           l_header := l_header || ',';
                        END IF;
                        l_header := l_header || SUBSTR(l_line_buff, INSTR(l_line_buff, '<', 1, l_r_ctr),
                                                                    INSTR(l_line_buff, '>', 1, l_r_ctr) - (INSTR(l_line_buff, '<', 1, l_r_ctr) - 1));
                     ELSE
                        EXIT;
                     END IF;
                  END LOOP;
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  IF UTL_FILE.IS_OPEN(f_handle) THEN
                     UTL_FILE.FCLOSE(f_handle);
                  END IF;
                  EXIT;
            END;
         END LOOP;
      END IF;
      CLOSE c_host;
   ELSE
      p_status := 'E';
      p_error_message := 'Unable to find email notification parameter file or parameter directory';
      RETURN;
   END IF;

   IF t_recipient.COUNT > 0 AND
      l_host IS NOT NULL AND
      l_sender IS NOT NULL THEN
      BEGIN
         SELECT a.mview_name,
                a.staleness,
                a.stale_since,
                a.compile_state
                BULK COLLECT INTO t_mviews
         FROM  (SELECT mview_name,
                       staleness,
                       stale_since,
                       compile_state
                FROM   dba_mviews
                WHERE  owner = 'APPSSQL'
                AND    NVL(compile_state, 'XXXX') <> 'VALID'
                AND    ( (NVL(p_scope, 'XXXX') = 'ALL') OR
                         (NVL(p_scope, 'XXXX') = 'XXXX' AND mview_name LIKE 'DOT_GL%DW') )
                UNION
                SELECT table_name mview_name,
                       'NEEDS_COMPILE' staleness,
                       l_request_date stale_since,
                       l_manual_mv_1 compile_state
                FROM   all_tables
                WHERE  owner = 'APPSSQL'
                AND    table_name = 'DOT_AP_INVOICES_DW'
                AND    NVL(l_manual_mv_1, 'XXXX') <> 'XXXX'
                UNION
                SELECT table_name mview_name,
                       'NEEDS_COMPILE' staleness,
                       l_request_date stale_since,
                       l_manual_mv_2 compile_state
                FROM   all_tables
                WHERE  owner = 'APPSSQL'
                AND    table_name = 'DOT_PO_RECEIPTS_DW'
                AND    NVL(l_manual_mv_2, 'XXXX') <> 'XXXX') a;

         IF t_mviews.COUNT > 0 THEN
            l_message := '<br>' ||
                         '<font face="ARIAL" size="2">' ||
                         'Please be informed: Concurrent Request ID ' || p_request_id || ' failed to refresh the following Materialized Views<br><br>' ||
                         '</font>' ||
                         '<table width="80%" class="x1h" cellpadding="1" cellspacing="0" summary="APPSSQL Materialized Views" border="0">' ||
                         '<tr><th class="x1r x4m" scope="col" width="20%" align="LEFT" valign="baseline"><font face="ARIAL" size="2"><span class="x24">MView Name</span></font></th>' ||
                         '    <th class="x1r x4m" scope="col" width="15%" align="LEFT" valign="baseline"><font face="ARIAL" size="2"><span class="x24">Staleness</span></font></th>' ||
                         '    <th class="x1r x4m" scope="col" width="15%" align="LEFT" valign="baseline"><font face="ARIAL" size="2"><span class="x24">Stale Since</span></font></th>' ||
                         '    <th class="x1r x4m" scope="col" width="20%" align="LEFT" valign="baseline"><font face="ARIAL" size="2"><span class="x24">Compile State/Error</span></font></th>' ||
                         '</tr>';

            FOR i IN 1 .. t_mviews.COUNT LOOP
               l_mview_name := t_mviews(i).mview_name;
               l_staleness := t_mviews(i).staleness;
               l_stale_since := TO_CHAR(t_mviews(i).stale_since, 'DD/MM/YYYY HH24:MI:SS');
               l_compile_state := t_mviews(i).compile_state;

               IF NOT current_refresh(t_mviews(i).mview_name) THEN
                  l_report_row := l_report_row + 1;
                  l_message := l_message || '<tr>';
                  l_message := l_message || '<td align="LEFT" valign="top"><font face="ARIAL" size="2">' || NVL(l_mview_name, '&nbsp') || '</font></td>';
                  l_message := l_message || '<td align="LEFT" valign="top"><font face="ARIAL" size="2">' || NVL(l_staleness, '&nbsp') || '</font></td>';
                  l_message := l_message || '<td align="LEFT" valign="top"><font face="ARIAL" size="2">' || NVL(l_stale_since, '&nbsp') || '</font></td>';
                  l_message := l_message || '<td align="LEFT" valign="top"><font face="ARIAL" size="2">' || NVL(l_compile_state, '&nbsp') || '</font></td>';
                  l_message := l_message || '</tr>';
               END IF;

            END LOOP;
            l_message := l_message || '</table>';

            IF l_report_row > 0 THEN
               -----------------------------------
               -- (1) Create SMTP Instance      --
               -----------------------------------
               c := utl_smtp.open_connection(l_host);   -- smtp connection
               utl_smtp.helo(c, l_host);                -- host
               utl_smtp.mail(c, l_sender);              -- sender
               FOR i IN 1 .. t_recipient.COUNT LOOP
                  utl_smtp.rcpt(c, t_recipient(i));     -- recipient(s)
               END LOOP;
               -----------------------------------
               -- (2) Open data                 --
               -----------------------------------
               utl_smtp.open_data(c);
               -----------------------------------
               -- (3) Set header                --
               -----------------------------------
               utl_smtp.write_data(c, 'From: ' || l_instance_name || ' No-reply <' || l_sender || '>' || utl_tcp.crlf);
               utl_smtp.write_data(c, 'To: ' || l_header || utl_tcp.crlf);
               utl_smtp.write_data(c, 'Subject: ' || l_subject || utl_tcp.crlf);
               --------------------------------------------
               -- (4) Set message to multipart/mixed     --
               --------------------------------------------
               utl_smtp.write_data(c, 'MIME-Version: 1.0' || utl_tcp.crlf);
               utl_smtp.write_data(c, 'Content-Type: multipart/mixed; ' || utl_tcp.crlf);
               utl_smtp.write_data(c, ' boundary= "' || l_boundary || '"' || utl_tcp.crlf);
               utl_smtp.write_data(c, utl_tcp.crlf);
               -----------------------------------
               -- (5) Include message body      --
               -----------------------------------
               utl_smtp.write_data(c, '--' || l_boundary || utl_tcp.crlf);
               utl_smtp.write_data(c, 'Content-Type: text/html;' || utl_tcp.crlf);
               utl_smtp.write_data(c, ' charset=US-ASCII' || utl_tcp.crlf);
               utl_smtp.write_data(c, utl_tcp.crlf);
               utl_smtp.write_data(c, l_message || utl_tcp.crlf);
               utl_smtp.write_data(c, utl_tcp.crlf);
               ----------------------------------
               -- (6) Close data               --
               ----------------------------------
               utl_smtp.write_data(c, '--' || l_boundary || '--' || utl_tcp.crlf );
               utl_smtp.write_data(c, utl_tcp.crlf || '.' || utl_tcp.crlf );
               utl_smtp.close_data(c);
               utl_smtp.quit(c);

               COMMIT;
            END IF;
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            NULL;
      END;
   END IF;

   p_status := 'S';

EXCEPTION
   WHEN no_data_found THEN
      NULL;
   WHEN others THEN
      p_error_message := SQLERRM;

END notify_users;


END dot_appssql_dw_pkg;
/
