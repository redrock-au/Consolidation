-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AP.02.03/arc/1.0.0/install/sql/rram_debtor_stage_s1.sql 1442 2017-07-04 22:35:02Z svnuser $
-- Purpose:  Table creation script for sequence rram_debtor_stage_s1
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create sequence fmsmgr.rram_debtor_stage_s1 start with 500000 increment by 1 nocache;
grant select on fmsmgr.rram_debtor_stage_s1 to apps;


