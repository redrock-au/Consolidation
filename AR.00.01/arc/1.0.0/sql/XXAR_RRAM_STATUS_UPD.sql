rem $Header: svn://d02584/consolrepos/branches/AR.00.01/arc/1.0.0/sql/XXAR_RRAM_STATUS_UPD.sql 2401 2017-09-04 00:46:57Z svnuser $
SET SERVEROUTPUT ON SIZE 1000000

PROMPT 
PROMPT ** RRAM Post-conversion Invoice Status population **
PROMPT

DECLARE
   CURSOR c_trx IS
      SELECT rct.customer_trx_id
           , rct.trx_number
           , nvl(tfm.rram_source_system_ref, 'Missing') AS rram_source_system_ref
           , arps.amount_due_original
           , arps.amount_applied
           , arps.amount_credited
           , arps.amount_adjusted
           , arps.amount_due_remaining
           , rct.creation_date
           , rct.created_by
       FROM ra_customer_trx rct
          , ar_payment_schedules_all arps
   	    , ra_cust_trx_types rctt
          , xxar_open_invoices_conv_tfm tfm
          , fnd_user fu
      WHERE arps.customer_trx_id = rct.customer_trx_id
        AND rctt.cust_trx_type_id = rct.cust_trx_type_id
        AND arps.status = 'OP'
        AND rctt.name like '%-RRAM-Invoice'
        AND tfm.dsdbi_trx_number(+) = rct.trx_number
        AND tfm.line_type(+) = 'LINE'
        AND fu.user_id = rct.created_by
        AND fu.user_name = 'CONVERSION'
        AND tfm.line_number(+) = '1';

   CURSOR c_inv_status(p_inv_id IN NUMBER) IS
      SELECT * 
        FROM rram_invoice_status 
       WHERE invoice_id = p_inv_id 
         FOR UPDATE OF source_system_ref;
   
   r_inv_status         c_inv_status%ROWTYPE;
   l_user_id            NUMBER := fnd_profile.value('USER_ID');
   l_insert_count       NUMBER := 0;
   l_update_count       NUMBER := 0;
BEGIN
   FOR r_trx IN c_trx
   LOOP
      OPEN c_inv_status(r_trx.customer_trx_id);
      FETCH c_inv_status INTO r_inv_status;
      IF c_inv_status%FOUND THEN
         UPDATE rram_invoice_status
            SET invoice_number = r_trx.trx_number,
                source_system = 'RRAM',
                source_system_ref = r_trx.rram_source_system_ref,
                invoice_amount = r_trx.amount_due_original,
                amount_applied = r_trx.amount_applied,
                amount_credited = r_trx.amount_credited,
                amount_adjusted = r_trx.amount_adjusted,
                amount_due_remaining = r_trx.amount_due_remaining,
                last_update_date = SYSDATE,
                last_updated_by = l_user_id
          WHERE CURRENT OF c_inv_status;
         IF SQL%ROWCOUNT = 1 THEN
            l_update_count := l_update_count + 1; 
            dbms_output.put_line('Updated [invoice_number=' || r_trx.trx_number 
               || '],[source_system_ref=' || r_trx.rram_source_system_ref 
               || '],[amount_due_remaining=' || r_trx.amount_due_remaining || ']');
         ELSE
            dbms_output.put_line('Updated for invoice_number ' || r_trx.trx_number || ' unsuccessful'); 
         END IF;
      ELSE
         INSERT INTO rram_invoice_status
         (
            invoice_id,
            invoice_number,
            source_system,
            source_system_ref,
            invoice_amount,
            amount_applied,
            amount_credited,
            amount_adjusted,
            amount_due_remaining,
            creation_date,
            created_by,
            last_update_date,
            last_updated_by
         )
         VALUES
         (
            r_trx.customer_trx_id,
            r_trx.trx_number,
            'RRAM',
            r_trx.rram_source_system_ref,
            r_trx.amount_due_original,
            r_trx.amount_applied,
            r_trx.amount_credited,
            r_trx.amount_adjusted,
            r_trx.amount_due_remaining,
            SYSDATE,
            l_user_id,
            SYSDATE,
            l_user_id
         );
         l_insert_count := l_insert_count + 1; 
         dbms_output.put_line('Inserted [invoice_number=' || r_trx.trx_number 
            || '],[source_system_ref=' || r_trx.rram_source_system_ref 
            || '],[amount_due_remaining=' || r_trx.amount_due_remaining || ']');
      END IF;
      CLOSE c_inv_status;
   END LOOP;
   dbms_output.put_line('---------------------------------------------------------------------------------------- ');
   dbms_output.put_line('Inserted Count: ' || l_insert_count);
   dbms_output.put_line('Updated Count: ' || l_update_count);
END;
/

SET LINESIZE 88
SET PAGESIZE 120
SET HEADING ON
SET FEEDBACK ON
COL invoice_number FORMAT A20
COL source_system_ref FORMAT A20
TTITLE CENTER '** Audit of missing RRAM References **' SKIP 2
SELECT invoice_id, invoice_number, source_system_ref, invoice_amount, amount_due_remaining
  FROM rram_invoice_status
  WHERE source_system_ref = 'Missing'  
  ORDER BY invoice_id
/

