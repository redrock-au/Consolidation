-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AP.02.01/arc/1.0.0/install/sql/rram_subscription_log_s1.sql 1427 2017-07-04 07:19:13Z svnuser $
-- Purpose:  Creation script for sequence rram_subscription_log_s1
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create sequence fmsmgr.rram_subscription_log_s1 start with 20000 increment by 1 nocache;
grant select on fmsmgr.rram_subscription_log_s1 to apps;
