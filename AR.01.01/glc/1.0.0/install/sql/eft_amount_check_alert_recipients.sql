rem $Header: svn://d02584/consolrepos/branches/AR.01.01/glc/1.0.0/install/sql/eft_amount_check_alert_recipients.sql 3173 2017-12-12 05:28:14Z svnuser $
rem Repackage FSC-5796 arellanod 2017/11/30 03

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