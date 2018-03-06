/* $Header: svn://d02584/consolrepos/branches/AR.03.02/glc/1.0.0/install/sql/XXGL_CASH_BAL_JOURNALS_V_DDL.sql 1382 2017-07-03 00:49:40Z svnuser $ */

CREATE OR REPLACE VIEW xxgl_cash_bal_journals_v
AS
SELECT DISTINCT
       jeh.name || ' (' || jeh.je_header_id || ')' journal_name,
       jeh.je_source,
       jeh.je_header_id,
       jeh.je_batch_id,
       jeh.set_of_books_id,
       gper.start_date,
       gper.end_date
FROM   gl_je_batches jeb,
       gl_je_headers jeh,
       gl_sets_of_books gsob,
       gl_periods gper,
       gl_period_types gpty
WHERE  jeb.je_batch_id = jeh.je_batch_id
AND    jeh.set_of_books_id = gsob.set_of_books_id
AND    jeh.actual_flag = 'A'
AND    jeh.je_source IN ('Receivables', 'Payables', 'Cash Balancing')
AND    gsob.period_set_name = gper.period_set_name
AND    jeh.period_name = gper.period_name
AND    gper.period_type = gpty.period_type
AND    UPPER(gpty.user_period_type) = 'MONTH'
AND    NVL(gper.adjustment_period_flag, 'N') = 'N';
