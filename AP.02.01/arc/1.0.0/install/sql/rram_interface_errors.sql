-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AP.02.01/arc/1.0.0/install/sql/rram_interface_errors.sql 1427 2017-07-04 07:19:13Z svnuser $
-- Purpose:  Table creation script for RRAM_INTERFACE_ERRORS
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create table fmsmgr.rram_interface_errors
(
    error_id              number,
    stage_id              number not null,
    interface_type        varchar2(30) not null,
    api_error             varchar2(240),
    error_message         varchar2(240),
    timestamp             date not null,
    conc_request_id       number
);

create unique index fmsmgr.rram_interface_errors_pk on fmsmgr.rram_interface_errors(error_id);
create index fmsmgr.rram_interface_errors_n1 on fmsmgr.rram_interface_errors(interface_type, stage_id);
create index fmsmgr.rram_interface_errors_n2 on fmsmgr.rram_interface_errors(conc_request_id);

