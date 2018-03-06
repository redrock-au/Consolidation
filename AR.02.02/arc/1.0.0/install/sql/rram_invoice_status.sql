-- -------------------------------------------------------------------------------------
-- $Header: svn://d02584/consolrepos/branches/AR.02.02/arc/1.0.0/install/sql/rram_invoice_status.sql 1201 2017-06-23 05:20:06Z svnuser $
-- Purpose:  Table creation script for RRAM_INVOICE_STATUS
-- Project:  Arrah (RRAM / Oracle Finance Integration)
-- Date:     Feb 2015
-- -------------------------------------------------------------------------------------
create table fmsmgr.rram_invoice_status
(
    invoice_id            number not null,
    invoice_number        varchar2(30) not null,
    source_system         varchar2(30) not null,
    source_system_ref     varchar2(30) not null,
    invoice_amount        number not null,
    amount_applied        number,
    amount_credited       number,
    amount_adjusted       number,
    amount_discounted     number,
    amount_due_remaining  number not null,
    creation_date         date default sysdate not null,
    created_by            number not null,
    last_update_date      date,
    last_updated_by       number
);

create index fmsmgr.rram_invoice_status_n1 on fmsmgr.rram_invoice_status(source_system_ref, source_system);
create unique index fmsmgr.rram_invoice_status_u1 on fmsmgr.rram_invoice_status(invoice_id);

