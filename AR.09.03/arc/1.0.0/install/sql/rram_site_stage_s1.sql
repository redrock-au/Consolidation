-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AR.09.03/arc/1.0.0/install/sql/rram_site_stage_s1.sql 128 2017-04-07 01:44:52Z sryan $
-- Purpose:  Table creation script for sequence rram_site_stage_s1
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create sequence fmsmgr.rram_site_stage_s1 start with 20000 increment by 1 nocache;
grant select on fmsmgr.rram_site_stage_s1 to apps;

