/* $Header: svn://d02584/consolrepos/branches/AR.01.01/fndc/1.0.0/install/sql/DOT_AP_INVOICES_W_DDL.sql 2949 2017-11-13 01:09:55Z svnuser $ */
PROMPT Recreating DOT_AP_INVOICES_W view

CREATE OR REPLACE VIEW DOT_AP_INVOICES_W 
AS
SELECT gsb.set_of_books_id,
       pv.vendor_name,
       pv.vendor_id,
       pv.segment1 vendor_number,
       pvs.vendor_site_code,
       pvs.vendor_site_id,
       ab.batch_name ap_batch_name,
       ai.invoice_id,
       ai.invoice_num,
       ai.invoice_date,
       ai.invoice_type_lookup_code invoice_type,
       DECODE(exph.report_header_id, NULL, ai.invoice_amount, exph.total) invoice_amount,
       aps.amount_remaining,
       (SELECT  MAX(apsx.due_date)
        FROM    ap_payment_schedules_all apsx
        WHERE   apsx.invoice_id = ai.invoice_id
        AND     ( (apsx.amount_remaining > 0 AND
                   apsx.payment_num = (SELECT MIN(apsxb.payment_num)
                                       FROM   ap_payment_schedules_all apsxb
                                       WHERE  apsxb.invoice_id = apsx.invoice_id
                                       AND    apsxb.amount_remaining > 0)) OR
                  (apsx.amount_remaining = 0 AND
                   apsx.payment_num = (SELECT MAX(apsxb.payment_num)
                                       FROM   ap_payment_schedules_all apsxb
                                       WHERE  apsxb.invoice_id = apsx.invoice_id
                                       AND    apsxb.amount_remaining = 0)) )) due_date,
       ai.cancelled_date,
       ai.gl_date,
       gpr.period_name gl_period,
       alc.displayed_field paid,
       DECODE(ai.cancelled_date,
              NULL, DECODE(alc.displayed_field, 'Yes', pay.payment_days_overdue,
                           DECODE(SIGN(NVL(aps.amount_remaining, 0)), 1,
                                  DECODE(SIGN(TRUNC(SYSDATE) - TRUNC(aps.due_date)), 1, TRUNC(SYSDATE) - TRUNC(aps.due_date))))) aging,
       ai.description invoice_description,
       --DECODE(aid.credit_card_trx_id, NULL, NULL, 'Y') corporate_card_flag,
       CASE WHEN EXISTS (SELECT 1
                         FROM   ap_expense_report_lines_all expl
                         WHERE  expl.report_header_id = exph.report_header_id
                         AND    expl.credit_card_trx_id = aid.credit_card_trx_id)
            THEN 'Y'
            ELSE 'N'
       END corporate_card_flag,
       exph.employee_id expense_employee_id,
       CASE WHEN exph.report_header_id IS NOT NULL AND aid.credit_card_trx_id IS NOT NULL THEN
                 'Credit Card'
            WHEN exph.report_header_id IS NOT NULL AND aid.credit_card_trx_id IS NULL AND
                 aid.line_type_lookup_code <> 'TAX' THEN
                 'Personal'
       END expense_report_line_type,
       aid.justification,
       aid.merchant_name,
       NVL(atc.NAME, aid.vat_code) vat_code,
       aid.invoice_distribution_id,
       aid.distribution_line_number,
       aid.line_type_lookup_code,
       aid.amount,
       aid.description distribution_description,
       aid.invoice_price_variance,
       aid.po_distribution_id,
       aid.dist_code_combination_id,
       gcc.segment1 accounting_entity,
       gcc.segment2 accounting_account,
       gcc.segment3 accounting_cost_centre,
       gcc.segment4 accounting_authority,
       gcc.segment5 accounting_project,
       gcc.segment6 accounting_output,
       gcc.segment7 accounting_identifier,
       CASE WHEN exph.report_header_id IS NULL
            THEN aid.creation_date
            ELSE  exph.creation_date
       END creation_date,
       ai.last_update_date header_last_update_date,
       aid.last_update_date dist_last_update_date,
       aala.ae_line_type_code,
       aala.ae_line_number,
       (SELECT fae.meaning
        FROM   fnd_lookup_values fae
        WHERE  fae.lookup_type = 'AE LINE TYPE'
        AND    fae.lookup_code = aala.ae_line_type_code) ae_line_type_description,
       b.NAME gl_batch_name,
       l.je_header_id je_header_id,
       h.je_source user_je_source_name,
       h.je_category user_je_category_name,
       h.actual_flag,
       l.je_line_num je_line_num,
       att.document_url
FROM   ap_batches_all ab,
       ap_invoices_all ai,
       ap_invoice_distributions_all aid,
       (SELECT aps.invoice_id,
               aps.payment_num,
               aps.due_date,
               aps.amount_remaining
        FROM   ap_payment_schedules_all aps
        WHERE  NVL(payment_status_flag, 'N') = 'N'
        AND    aps.due_date IS NOT NULL
        AND    aps.amount_remaining <> 0
        AND    aps.due_date = (SELECT MIN(apsx.due_date)
                               FROM   ap_payment_schedules_all apsx
                               WHERE  apsx.due_date IS NOT NULL
                               AND    apsx.payment_status_flag = aps.payment_status_flag
                               AND    apsx.invoice_id = aps.invoice_id
                               AND    apsx.amount_remaining <> 0)) aps,
       (SELECT aip.invoice_id,
               MAX(aca.check_date) payment_date,
               MAX(aps.payment_num) payment_num,
               MAX(aps.due_date) payment_due_date,
               SUM(DECODE(SIGN(TRUNC(aca.check_date - aps.due_date)), 1, TRUNC(aca.check_date - aps.due_date))) payment_days_overdue
        FROM   ap_invoice_payments_all aip,
               ap_checks_all aca,
               ap_payment_schedules_all aps
        WHERE  aps.invoice_id = aip.invoice_id
        AND    aps.payment_num = aip.payment_num
        AND    aip.check_id = aca.check_id
        GROUP  BY aip.invoice_id) pay,
       ap_expense_report_headers_all exph,
       ap_lookup_codes alc,
       po_vendors pv,
       po_vendor_sites_all pvs,
       gl_code_combinations gcc,
       ap_tax_codes_all atc,
       ap_ae_headers_all aaha,
       ap_ae_lines_all aala,
       gl_je_batches b,
       gl_je_headers h,
       gl_je_lines l,
       gl_sets_of_books gsb,
       gl_periods gpr,
       (SELECT period_set_name,
               period_year - 7 period_year_low,
               period_year period_year_high
        FROM   gl_periods
        WHERE  NVL(adjustment_period_flag, 'N') = 'N'
        AND    PERIOD_TYPE <> 'Year'
        AND    TRUNC(SYSDATE) BETWEEN start_date AND end_date) gpx,
       (SELECT TO_NUMBER(ada.pk1_value) invoice_id,
               adl.file_name document_url
        FROM   fnd_attached_documents ada,
               fnd_documents_tl adl,
               fnd_document_categories_tl adc
        WHERE  ada.entity_name = 'AP_INVOICES'
        AND    ada.document_id = adl.document_id
        AND    ada.category_id = adc.category_id
        AND    adc.user_name = 'Scanned Invoice'
        AND    adl.file_name IS NOT NULL) att
WHERE  ab.batch_id = ai.batch_id
AND    ai.invoice_id = aid.invoice_id
AND    ai.vendor_id = pv.vendor_id
AND    ai.vendor_site_id = pvs.vendor_site_id
AND    ai.invoice_id = aps.invoice_id(+)
AND    ai.invoice_id = pay.invoice_id(+)
AND    ai.payment_status_flag = alc.lookup_code(+)
AND    ai.invoice_num = exph.invoice_num(+)
AND    ai.org_id = exph.org_id(+)
AND    ai.invoice_id = att.invoice_id(+)
AND    'INVOICE PAYMENT STATUS' = alc.lookup_type(+)
AND    pv.vendor_id = pvs.vendor_id
AND    aid.dist_code_combination_id = gcc.code_combination_id
AND    aid.tax_code_id = atc.tax_id(+)
AND    ai.set_of_books_id = gsb.set_of_books_id
AND    aala.source_table = 'AP_INVOICE_DISTRIBUTIONS'
AND    aala.source_id = aid.invoice_distribution_id
AND    aala.ae_line_type_code <> 'IPV' -- causing duplicate on same line
AND    aala.ae_header_id = aaha.ae_header_id
AND    aaha.gl_transfer_flag = 'Y'
AND    aaha.gl_transfer_run_id IS NOT NULL
AND    aaha.trial_balance_flag = 'Y'
AND    aala.gl_sl_link_id = l.gl_sl_link_id
AND    aala.code_combination_id = l.code_combination_id
AND    aaha.period_name = l.period_name
AND    l.je_header_id = h.je_header_id
AND    b.je_batch_id = h.je_batch_id
AND    gsb.period_set_name = gpr.period_set_name
AND    (l.effective_date BETWEEN gpr.start_date AND gpr.end_date)
AND    NVL(gpr.adjustment_period_flag, 'N') = 'N'
AND    gpr.period_type <> 'Year'
AND    gpr.period_set_name = gpx.period_set_name
AND    (gpr.period_year BETWEEN gpx.period_year_low AND gpx.period_year_high);
