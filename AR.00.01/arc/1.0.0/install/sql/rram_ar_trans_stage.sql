-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AR.00.01/arc/1.0.0/install/sql/rram_ar_trans_stage.sql 1492 2017-07-05 07:01:42Z svnuser $
-- Purpose:  Table creation script for RRAM_AR_TRANS_STAGE
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create table fmsmgr.rram_ar_trans_stage
(
    stage_id              number,
    source_system         varchar2(30) not null,
    source_system_ref     varchar2(30) not null,
    account_number        varchar2(30) not null,
    party_site_number     number not null,
    trans_date            date,
    trans_type            varchar2(20) not null,
    currency_code         varchar2(3) not null,
    fee_number            varchar2(30),
    line_number           number not null,
    description           varchar2(240) not null,
    quantity              number not null,
    unit_of_measure       varchar2(10),
    unit_price            number not null,
    extended_amount       number not null,
    tax_code              varchar2(50) not null,
    revenue_account       varchar2(40) not null,
    invoice_number        varchar2(30),
    invoice_id            number,
    creation_date         date default sysdate,
    created_by            number,
    created_by_user       varchar2(20),
    last_update_date      date,
    last_updated_by       number,
    interface_status      varchar2(1) default 'N',
    conc_request_id       number
);

create index fmsmgr.rram_ar_trans_stage_n1 on fmsmgr.rram_ar_trans_stage(source_system_ref, source_system);
create unique index fmsmgr.rram_ar_trans_stage_u1 on fmsmgr.rram_ar_trans_stage(stage_id);

