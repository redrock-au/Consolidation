-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/sql/rram_subscription_log.sql 1262 2017-06-26 23:43:06Z svnuser $
-- Purpose:  Table creation script for RRAM_SUBSCRIPTION_LOG
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create table fmsmgr.rram_subscription_log
(
    seq_id                number not null,
    message               varchar2(240),
    tstamp                date
);


