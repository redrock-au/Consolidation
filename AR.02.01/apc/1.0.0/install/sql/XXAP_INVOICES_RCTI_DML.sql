/* $Header: svn://d02584/consolrepos/branches/AR.02.01/apc/1.0.0/install/sql/XXAP_INVOICES_RCTI_DML.sql 2981 2017-11-14 08:13:57Z svnuser $ */

PROMPT Executing UPDATE AP_INVOICES_ALL.ATTRIBUTE6

BEGIN
   UPDATE ap_invoices_all
   SET    global_attribute1 = attribute6,
          attribute6 = NULL
   WHERE  attribute6 IS NOT NULL
   AND    attribute_category NOT IN ('GMS', 'GEMS', 'FOXBT')
   AND    org_id = 101;

   IF sql%FOUND THEN
      COMMIT;
   END IF;
END;
/
