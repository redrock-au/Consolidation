-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/sql/rram_debtor_audit_s1.sql 1262 2017-06-26 23:43:06Z svnuser $
-- Purpose:  Table creation script for sequence rram_debtor_audit_s1
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create sequence fmsmgr.rram_debtor_audit_s1 start with 20000 increment by 1 nocache;
grant select on fmsmgr.rram_debtor_audit_s1 to apps;

