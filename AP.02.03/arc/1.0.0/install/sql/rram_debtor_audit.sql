-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AP.02.03/arc/1.0.0/install/sql/rram_debtor_audit.sql 1442 2017-07-04 22:35:02Z svnuser $
-- Purpose:  Table creation script for RRAM_DEBTOR_AUDIT
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create table fmsmgr.rram_debtor_audit
(
    audit_id              number not null,
    stage_id              number not null,
    interface_type        varchar2(30) not null,
    conc_request_id       number not null,
    action                varchar2(1) not null, -- (N=New; U=Update)
    tca_record            varchar2(30),
    field_name            varchar2(30),
    orig_value            varchar2(240),
    new_value             varchar2(240)
);

create unique index fmsmgr.rram_debtor_audit_u1 on fmsmgr.rram_debtor_audit(audit_id);
create index fmsmgr.rram_debtor_audit_n1 on fmsmgr.rram_debtor_audit(interface_type, stage_id);
create index fmsmgr.rram_debtor_audit_n2 on fmsmgr.rram_debtor_audit(conc_request_id);

