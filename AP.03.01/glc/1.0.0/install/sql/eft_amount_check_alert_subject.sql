rem $Header: svn://d02584/consolrepos/branches/AP.03.01/glc/1.0.0/install/sql/eft_amount_check_alert_subject.sql 3093 2017-11-30 03:03:04Z svnuser $
rem Repackage FSC-5796 arellanod 2017/11/30 03

set term off 
set fedback off
set echo off
set verify off
set pagesize 0
set trimspool on
set hea off
spool eft_payment_ammt_check_email_subject.lst
select message_text
from fnd_new_messages
where message_name = 'XXGL_PAYMENT_AMT_CHK_SUBJECT'
/
spool off
/
exit;