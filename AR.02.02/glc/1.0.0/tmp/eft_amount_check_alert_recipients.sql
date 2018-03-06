set term off 
set fedback off
set echo off
set verify off
set pagesize 0
set trimspool on
set hea off
spool eft_payment_ammt_check_email_list.lst
select message_text
from fnd_new_messages
where message_name = 'XXGL_PAYMENT_AMT_CHK_MAIL_LIST'
/
spool off
/
exit;