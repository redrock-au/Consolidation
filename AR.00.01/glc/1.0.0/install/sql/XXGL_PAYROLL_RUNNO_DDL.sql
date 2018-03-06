rem $Header: svn://d02584/consolrepos/branches/AR.00.01/glc/1.0.0/install/sql/XXGL_PAYROLL_RUNNO_DDL.sql 2401 2017-09-04 00:46:57Z svnuser $

CREATE TABLE fmsmgr.xxgl_payroll_run_numbers
(
   payroll_runno      NUMBER,
   payaccr_runno      NUMBER,
   set_of_books_id    NUMBER,
   accounting_date    DATE,
   creation_date      DATE,
   created_by         NUMBER,
   last_update_date   DATE,
   last_updated_by    NUMBER
);

CREATE SYNONYM xxgl_payroll_run_numbers FOR fmsmgr.xxgl_payroll_run_numbers;

DECLARE
   l_recs    NUMBER;
BEGIN
   SELECT COUNT(1)
   INTO   l_recs
   FROM   xxgl_payroll_run_numbers;

   IF l_recs = 0 THEN
      INSERT INTO xxgl_payroll_run_numbers
      SELECT run_id,
             run_id,
             book_id,
             accounting_date,
             SYSDATE,
             -1,
             SYSDATE,
             -1       
      FROM   fmsmgr.remus_runs
      WHERE  (book_id, run_id) IN (SELECT BOOK_ID, MAX(run_id)
                                   FROM   fmsmgr.remus_runs
                                   GROUP  BY book_id);

      IF sql%ROWCOUNT > 0 THEN
         COMMIT;
      END IF;
   END IF;
END;
/

