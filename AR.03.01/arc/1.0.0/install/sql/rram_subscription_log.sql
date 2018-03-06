-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AR.03.01/arc/1.0.0/install/sql/rram_subscription_log.sql 1706 2017-07-12 04:37:42Z svnuser $
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


