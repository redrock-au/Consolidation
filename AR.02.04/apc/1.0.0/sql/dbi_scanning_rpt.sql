SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON
SET LINESIZE 300
TTITLE 'DEDJTR Scanning Report'			
COLUMN FILE_IMPORT_ID HEADING 'Import ID' FORMAT 9999999999
COLUMN RECEIVED_FROM_KOFAX HEADING 'Date Received from KOFAX' FORMAT A30
COLUMN PO_NUMBER HEADING 'PO Number' FORMAT A30
COLUMN INVOICE_NUM HEADING 'Invoice Number' FORMAT A30
COLUMN INVOICE_DATE HEADING 'Invoice Date' FORMAT A30
COLUMN INVOICE_RECEIVED_DATE HEADING 'Invoice Received in Dept' FORMAT A30
COLUMN REQ_PREP_NAME HEADING 'Preparer Name' FORMAT A30
COLUMN IP5_INV_RECEIVED_STATUS HEADING 'IP5 Receiving Status' FORMAT A30
COLUMN IP5_INV_RECEIVED_DATE HEADING 'IP5 Receiving Date' FORMAT A30
select  
import_id File_import_id,creation_date received_from_kofax,(select segment1 from po_headers_all pha where pha.po_header_id =xis.po_header_id) PO_NUMBER,
Invoice_num,Invoice_date,Invoice_received_date,REQ_PREP_NAME,PO_ATTACHMENT_COMPLETE IP5_Inv_received_status,
decode(PO_ATTACHMENT_COMPLETE, 'Y',last_update_date,null) IP5_Inv_received_date
from 
XXAP_INV_SCANNED_FILE XIS
where po_header_id is not null
/
SET FEEDBACK ON
SET VERIFY ON