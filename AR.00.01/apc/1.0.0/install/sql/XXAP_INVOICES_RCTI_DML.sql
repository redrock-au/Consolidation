/* $Header: svn://d02584/consolrepos/branches/AR.00.01/apc/1.0.0/install/sql/XXAP_INVOICES_RCTI_DML.sql 2499 2017-09-08 07:20:44Z svnuser $ */

PROMPT Executing UPDATE AP_INVOICES_ALL.ATTRIBUTE6

BEGIN
   UPDATE ap_invoices_all
   SET    global_attribute1 = attribute6,
          attribute6 = ''
   WHERE  attribute6 IS NOT NULL
   AND    attribute_category NOT IN ('GEMS', 'GEMS', 'FOXBT')
   AND    org_id = 101;

   IF sql%FOUND THEN
      COMMIT;
   END IF;
END;
/
