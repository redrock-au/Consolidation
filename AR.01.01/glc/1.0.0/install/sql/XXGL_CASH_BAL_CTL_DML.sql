/* $Header: svn://d02584/consolrepos/branches/AR.01.01/glc/1.0.0/install/sql/XXGL_CASH_BAL_CTL_DML.sql 1379 2017-07-03 00:43:56Z svnuser $ */

DECLARE
   l_ctl_count   NUMBER;
BEGIN
   SELECT COUNT(1)
   INTO   l_ctl_count
   FROM   xxgl_cash_bal_ctl;

   IF l_ctl_count = 0 THEN
      INSERT INTO xxgl_cash_bal_ctl
      SELECT h.je_header_id,
             s.user_je_source_name,
             c.user_je_category_name,
             'C',
             -1,
             SYSDATE,
             -1,
             SYSDATE
      FROM   gl_je_headers h,
             gl_je_sources s,
             gl_je_categories c
      WHERE  h.je_source = s.je_source_name
      AND    s.user_je_source_name IN ('Receivables', 'Payables', 'Cash Balancing')
      AND    h.status = 'P'
      AND    h.je_category = c.je_category_name;

      IF sql%FOUND THEN
         COMMIT;
      END IF;
   END IF;
EXCEPTION
   WHEN others THEN
      NULL;
END;
/
