-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AR.02.02/arc/1.0.0/install/sql/rram_site_stage.sql 1201 2017-06-23 05:20:06Z svnuser $
-- Purpose:  Table creation script for RRAM_SITE_STAGE
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create table fmsmgr.rram_site_stage
(
    stage_id              number,
    source_system         varchar2(30) not null,
    source_system_ref     varchar2(30) not null,
    address_line1         varchar2(240) not null,
    address_line2         varchar2(240),
    address_line3         varchar2(240),
    city                  varchar2(60),
    state                 varchar2(30),
    postcode              varchar2(15),
    country               varchar2(30),
    abn                   varchar2(30),
    account_number        varchar2(30) not null,
    party_site_number     number,
    creation_date         date default sysdate,
    created_by            number,
    created_by_user       varchar2(20),
    last_update_date      date,
    last_updated_by       number,
    interface_status      varchar2(1) default 'N',
    conc_request_id       number
);

create index fmsmgr.rram_site_stage_n1 on fmsmgr.rram_site_stage(source_system_ref, source_system);
create unique index fmsmgr.rram_site_stage_u1 on fmsmgr.rram_site_stage(stage_id);

