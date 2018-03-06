set term off 
set fedback off
set echo off
set verify off
set pagesize 1000
set hea off
column PAYMENT_BATCH format a60
column AMOUNT format a150
set linesize 360
spool eft_payment_ammt_check.lst
SELECT MESSAGE_TEXT
FROM FND_NEW_MESSAGES
WHERE message_name ='XXGL_PAYMENT_AMT_CHK_ALERT_MSG'
/
SELECT 'Payment Batch Name :'||CHECKRUN_NAME PAYMENT_BATCH,
       'Selected Amount    :'||to_char(SUM(NVL(check_amount,0)),'999,999,999,999,999,999.99') AMOUNT
FROM ap_selected_invoice_checks_all
WHERE CHECKRUN_NAME = '&1'
GROUP BY CHECKRUN_NAME
/
spool off
/
exit;
