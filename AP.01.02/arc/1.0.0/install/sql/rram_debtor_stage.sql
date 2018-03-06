-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AP.01.02/arc/1.0.0/install/sql/rram_debtor_stage.sql 1081 2017-06-21 05:49:47Z svnuser $
-- Purpose:  Table creation script for RRAM_DEBTOR_STAGE
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create table fmsmgr.rram_debtor_stage
(
    stage_id              number,
    source_system         varchar2(30) not null,
    source_system_ref     varchar2(30) not null,
    organization_name     varchar2(240) not null,
    profile_class         varchar2(30),
    address_line1         varchar2(240) not null,
    address_line2         varchar2(240),
    address_line3         varchar2(240),
    city                  varchar2(60),
    state                 varchar2(30),
    postcode              varchar2(15),
    country               varchar2(30),
    abn                   varchar2(30),
    cust_account_id       number,
    account_number        varchar2(30),
    party_site_number     number,
    creation_date         date default sysdate,
    created_by            number,
    created_by_user       varchar2(20),
    last_update_date      date,
    last_updated_by       number,
    interface_status      varchar2(1) default 'N',
    conc_request_id       number
);

create index fmsmgr.rram_debtor_stage_n1 on fmsmgr.rram_debtor_stage(source_system_ref, source_system);
create unique index fmsmgr.rram_debtor_stage_u1 on fmsmgr.rram_debtor_stage(stage_id);

