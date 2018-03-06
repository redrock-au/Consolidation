-- $Header: svn://d02584/consolrepos/branches/AR.02.03/arc/1.0.0/install/sql/RRAM_install_apps.sql 1451 2017-07-04 23:01:51Z svnuser $
create or replace synonym apps.rram_ar_trans_stage for fmsmgr.rram_ar_trans_stage;
create or replace synonym apps.rram_debtor_stage for fmsmgr.rram_debtor_stage;
create or replace synonym apps.rram_site_stage for fmsmgr.rram_site_stage;
create or replace synonym apps.rram_debtor_audit for fmsmgr.rram_debtor_audit;
create or replace synonym apps.rram_invoice_status for fmsmgr.rram_invoice_status;
create or replace synonym apps.rram_interface_errors for fmsmgr.rram_interface_errors;
create or replace synonym apps.rram_subscription_log for fmsmgr.rram_subscription_log;
create or replace synonym apps.rram_debtor_stage_s1 for fmsmgr.rram_debtor_stage_s1;
create or replace synonym apps.rram_site_stage_s1 for fmsmgr.rram_site_stage_s1;
create or replace synonym apps.rram_ar_trans_stage_s1 for fmsmgr.rram_ar_trans_stage_s1;
create or replace synonym apps.rram_debtor_audit_s1 for fmsmgr.rram_debtor_audit_s1;
create or replace synonym apps.rram_interface_errors_s1 for fmsmgr.rram_interface_errors_s1;
create or replace synonym apps.rram_subscription_log_s1 for fmsmgr.rram_subscription_log_s1;
@RRAM_DEBTOR_PKS.pls
show errors
@RRAM_DEBTOR_SITE_PKS.pls
show errors
@RRAM_DEBTOR_PKB.pls
show errors
@RRAM_DEBTOR_SITE_PKB.pls
show errors
@RRAM_AR_TRANS_PKS.pls
show errors
@RRAM_AR_TRANS_PKB.pls
show errors
@ARC_EVENT_PKS.pls
show errors
@ARC_EVENT_PKB.pls
show errors
