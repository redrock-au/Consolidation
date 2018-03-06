-- -----------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AP.02.01/arc/1.0.0/install/sql/create_rram_user.sql 2241 2017-08-22 06:05:14Z svnuser $
-- Purpose:  Creates the RRAM database user
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -----------------------------------------------------
create user rram identified by rram;
grant create session, resource to rram;
grant insert, update, select on fmsmgr.rram_debtor_stage to rram;
grant insert, update, select on fmsmgr.rram_site_stage to rram;
grant insert, update, select on fmsmgr.rram_ar_trans_stage to rram;
grant select on fmsmgr.rram_interface_errors to rram;
grant select on fmsmgr.rram_invoice_status to rram;
grant execute on apps.rram_debtor_pkg to rram;
grant execute on apps.rram_debtor_site_pkg to rram;
grant execute on apps.rram_ar_trans_pkg to rram;
create or replace synonym rram.rram_ar_trans_stage for fmsmgr.rram_ar_trans_stage;
create or replace synonym rram.rram_debtor_stage for fmsmgr.rram_debtor_stage;
create or replace synonym rram.rram_site_stage for fmsmgr.rram_site_stage;
create or replace synonym rram.rram_invoice_status for fmsmgr.rram_invoice_status;
create or replace synonym rram.rram_interface_errors for fmsmgr.rram_interface_errors;
create or replace synonym rram.rram_debtor_pkg for apps.rram_debtor_pkg;
create or replace synonym rram.rram_debtor_site_pkg for apps.rram_debtor_site_pkg;
create or replace synonym rram.rram_ar_trans_pkg for apps.rram_ar_trans_pkg;
