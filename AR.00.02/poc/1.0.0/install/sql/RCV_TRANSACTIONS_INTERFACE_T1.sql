rem $Header: svn://d02584/consolrepos/branches/AR.00.02/poc/1.0.0/install/sql/RCV_TRANSACTIONS_INTERFACE_T1.sql 2379 2017-08-31 04:02:33Z svnuser $
rem Baseline version taken prior to DSDBI/DTPLI Consolidation Project
rem Date: 08-May-2017
/****************************************************************************
**
** CEMLI ID: PO.04.02
**
** Description: Package to handle all receiving related OAF Package calls
**              
**
** Change History:
**
** Date        Who                  Comments
** 26/04/2017  Joy Pinto            Added Attribute4 and Attribute5 for import_id and PO attacment.
**
****************************************************************************/
CREATE OR REPLACE TRIGGER APPS.RCV_TRANSACTIONS_INTERFACE_T1
BEFORE DELETE ON rcv_transactions_interface
FOR EACH ROW
DECLARE
   v_a2   rcv_transactions.attribute12%TYPE;
   v_a3   rcv_transactions.attribute13%TYPE;
   v_a5   rcv_transactions.attribute5%TYPE;
   v_a6   rcv_transactions.attribute6%TYPE;
   err_num NUMBER;
   err_msg VARCHAR2(100);
BEGIN
   IF :old.transaction_type IN ('CORRECT', 'RETURN TO RECEIVING', 'RETURN TO VENDOR')
   THEN
      SELECT attribute2,
             attribute3,
             attribute5, -- Redrock Consolidation project 09-May-2017
             attribute6
      INTO   v_a2,
             v_a3,
             v_a5,
             v_a6
      FROM   rcv_transactions
      WHERE  transaction_id = :OLD.parent_transaction_id;

   ELSE
      -- Set RCTI Invoice Number and Date
      v_a2 := rtrim(ltrim(:OLD.PACKING_SLIP));
      v_a3 := rtrim(ltrim(:OLD.WAYBILL_AIRBILL_NUM));
      
      BEGIN
         SELECT import_id,
                po_number_attachment
         INTO   v_a5,
                v_a6
         FROM   xxap_inv_scanned_file
         WHERE  upper(invoice_num) = upper(:OLD.packing_slip)
         AND    vendor_internal_id = :old.vendor_id; 
      EXCEPTION
      WHEN OTHERS THEN
      v_a5 := NULL;
      v_a6 := NULL;
      END ;
      
   END IF;


   -- Update Reciepting tables
   UPDATE rcv_transactions
   SET    attribute2 = v_a2,
          attribute3 = v_a3,
          attribute5 = v_a5 ,
          attribute6 = v_a6
   WHERE  shipment_header_id = :OLD.shipment_header_id;

   UPDATE rcv_shipment_headers
   SET    attribute2 = v_a2,
          attribute3 = v_a3,
          attribute5 = v_a5,
          attribute6 = v_a6,          
          packing_slip = NULL,
          waybill_airbill_num = NULL
   WHERE  shipment_header_id = :OLD.shipment_header_id;

   UPDATE rcv_shipment_lines
   SET    packing_slip = NULL
   WHERE  shipment_header_id = :OLD.shipment_header_id;

EXCEPTION
   WHEN OTHERS THEN
      err_num := SQLCODE;
      err_msg := SUBSTRB(SQLERRM, 1, 100);
      raise_application_error(-20000, err_msg);
END;
/
