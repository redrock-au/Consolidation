/* $Header: svn://d02584/consolrepos/branches/AP.02.01/fndc/1.0.0/install/sql/DOT_AP_INVOICES_DW_DML.sql 2810 2017-10-17 03:13:57Z svnuser $ */
PROMPT Updating DOT_AP_INVOICES_DW table with invoice document url

DECLARE
   CURSOR c_doc IS
      SELECT TO_NUMBER(ada.pk1_value) invoice_id,
             adl.file_name document_url
      FROM   fnd_attached_documents ada,
             fnd_documents_tl adl,
             fnd_document_categories_tl adc
      WHERE  ada.entity_name = 'AP_INVOICES'
      AND    ada.document_id = adl.document_id
      AND    ada.category_id = adc.category_id
      AND    adc.user_name = 'Scanned Invoice'
      AND    adl.file_name IS NOT NULL;

   r_doc      c_doc%ROWTYPE;
BEGIN
   OPEN c_doc;
   LOOP
      FETCH c_doc INTO r_doc;
      EXIT WHEN c_doc%NOTFOUND;

      UPDATE appssql.dot_ap_invoices_dw
      SET    document_url = r_doc.document_url
      WHERE  invoice_id = r_doc.invoice_id;

      IF sql%FOUND THEN
         COMMIT;
      END IF;
   END LOOP;
   CLOSE c_doc;
END;
/
