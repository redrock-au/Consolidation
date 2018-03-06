/* $Header: svn://d02584/consolrepos/branches/AR.03.02/glc/1.0.0/install/sql/XXGL_CASH_BAL_STG_DDL.sql 1830 2017-07-18 00:26:50Z svnuser $ */

CREATE TABLE fmsmgr.xxgl_cash_bal_stg
(
   record_id             NUMBER,
   request_id            NUMBER,
   group_id              NUMBER,
   source_batch          VARCHAR2(100),
   source_je_header_id   NUMBER,
   source_je_line_num    NUMBER,
   rule_id               NUMBER,
   rule_num              VARCHAR2(60),
   sl_source             VARCHAR2(150),
   sl_trx_type           VARCHAR2(150),
   sl_trx_subtype        VARCHAR2(150),
   token_name            VARCHAR2(150),
   token_value           VARCHAR2(150),
   segment1              VARCHAR2(25),
   segment2              VARCHAR2(25),
   segment3              VARCHAR2(25),
   segment4              VARCHAR2(25),
   segment5              VARCHAR2(25),
   segment6              VARCHAR2(25),
   segment7              VARCHAR2(25),
   entered_dr            NUMBER,
   entered_cr            NUMBER,
   summary_flag          VARCHAR2(1),
   creation_date         DATE,
   created_by            NUMBER
);

CREATE OR REPLACE SYNONYM xxgl_cash_bal_stg FOR fmsmgr.xxgl_cash_bal_stg;

CREATE INDEX fmsmgr.xxgl_cash_bal_stg_n1 ON fmsmgr.xxgl_cash_bal_stg (request_id);

CREATE INDEX fmsmgr.xxgl_cash_bal_stg_n2 ON fmsmgr.xxgl_cash_bal_stg (source_je_header_id);

CREATE INDEX fmsmgr.xxgl_cash_bal_stg_n3 ON fmsmgr.xxgl_cash_bal_stg (source_je_line_num);

CREATE INDEX fmsmgr.xxgl_cash_bal_stg_n4 ON fmsmgr.xxgl_cash_bal_stg (group_id);

CREATE UNIQUE INDEX fmsmgr.xxgl_cash_bal_stg_u1 ON fmsmgr.xxgl_cash_bal_stg (record_id);
