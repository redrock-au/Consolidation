-- $Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/sql/RRAM_dropall.sql 1262 2017-06-26 23:43:06Z svnuser $
-- packages
drop package rram_debtor_site_pkg;
drop package rram_debtor_pkg; 
drop package rram_ar_trans_pkg;
drop package arc_event_pkg;

-- synonyms
drop synonym apps.rram_debtor_stage;
drop synonym apps.rram_debtor_stage_s1;
drop synonym apps.rram_site_stage;
drop synonym apps.rram_site_stage_s1;
drop synonym apps.rram_ar_trans_stage;
drop synonym apps.rram_ar_trans_stage_s1;
drop synonym apps.rram_debtor_audit;
drop synonym apps.rram_debtor_audit_s1;
drop synonym apps.rram_interface_errors;
drop synonym apps.rram_interface_errors_s1;
drop synonym apps.rram_invoice_status;
drop synonym apps.rram_subscription_log;
drop synonym apps.rram_subscription_log_s1;

-- sequences
drop sequence fmsmgr.rram_debtor_stage_s1;
drop sequence fmsmgr.rram_site_stage_s1;
drop sequence fmsmgr.rram_ar_trans_stage_s1;
drop sequence fmsmgr.rram_debtor_audit_s1;
drop sequence fmsmgr.rram_interface_errors_s1;
drop sequence fmsmgr.rram_subscription_log_s1;

-- tables
drop table fmsmgr.rram_debtor_stage;
drop table fmsmgr.rram_site_stage;
drop table fmsmgr.rram_ar_trans_stage;
drop table fmsmgr.rram_debtor_audit;
drop table fmsmgr.rram_interface_errors;
drop table fmsmgr.rram_invoice_status;
drop table fmsmgr.rram_subscription_log;


