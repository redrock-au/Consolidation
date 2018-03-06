-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AP.03.01/arc/1.0.0/install/sql/rram_site_stage_s1.sql 1066 2017-06-21 04:33:20Z svnuser $
-- Purpose:  Table creation script for sequence rram_site_stage_s1
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create sequence fmsmgr.rram_site_stage_s1 start with 20000 increment by 1 nocache;
grant select on fmsmgr.rram_site_stage_s1 to apps;

