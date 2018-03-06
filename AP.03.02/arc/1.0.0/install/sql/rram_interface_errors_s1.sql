-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AP.03.02/arc/1.0.0/install/sql/rram_interface_errors_s1.sql 1071 2017-06-21 05:16:54Z svnuser $
-- Purpose:  Table creation script for sequence rram_interface_errors_s1
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create sequence fmsmgr.rram_interface_errors_s1 start with 20000 increment by 1 nocache;
grant select on fmsmgr.rram_interface_errors_s1 to apps;
