-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AR.02.01/arc/1.0.0/install/sql/rram_ar_trans_stage_s1.sql 1385 2017-07-03 00:55:13Z svnuser $
-- Purpose:  Table creation script for sequence rram_ar_trans_stage_s1
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create sequence fmsmgr.rram_ar_trans_stage_s1 start with 20000 increment by 1 nocache;
grant select on fmsmgr.rram_ar_trans_stage_s1 to apps;

