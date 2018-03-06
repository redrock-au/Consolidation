-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AP.02.02/arc/1.0.0/install/sql/rram_debtor_audit_s1.sql 1607 2017-07-10 01:20:42Z svnuser $
-- Purpose:  Table creation script for sequence rram_debtor_audit_s1
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create sequence fmsmgr.rram_debtor_audit_s1 start with 20000 increment by 1 nocache;
grant select on fmsmgr.rram_debtor_audit_s1 to apps;

