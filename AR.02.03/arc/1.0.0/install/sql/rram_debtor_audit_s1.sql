-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AR.02.03/arc/1.0.0/install/sql/rram_debtor_audit_s1.sql 1451 2017-07-04 23:01:51Z svnuser $
-- Purpose:  Table creation script for sequence rram_debtor_audit_s1
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create sequence fmsmgr.rram_debtor_audit_s1 start with 20000 increment by 1 nocache;
grant select on fmsmgr.rram_debtor_audit_s1 to apps;

