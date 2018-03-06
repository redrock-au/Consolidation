/* $Header: svn://d02584/consolrepos/branches/AR.00.01/glc/1.0.0/install/sql/XXGL_CASH_BAL_TFM_DDL.sql 1492 2017-07-05 07:01:42Z svnuser $ */

CREATE TABLE fmsmgr.xxgl_cash_bal_tfm
(
  request_id               NUMBER,
  group_id                 NUMBER(15),
  status                   VARCHAR2(50),
  set_of_books_id          NUMBER(15),
  user_je_source_name      VARCHAR2(25),
  user_je_category_name    VARCHAR2(25),
  accounting_date          DATE,
  currency_code            VARCHAR2(15),
  date_created             DATE,
  created_by               NUMBER(15),
  actual_flag              VARCHAR2(1),
  segment1                 VARCHAR2(25),
  segment2                 VARCHAR2(25),
  segment3                 VARCHAR2(25),
  segment4                 VARCHAR2(25),
  segment5                 VARCHAR2(25),
  segment6                 VARCHAR2(25),
  segment7                 VARCHAR2(25),
  entered_dr               NUMBER,
  entered_cr               NUMBER,
  reference2               VARCHAR2(240),
  reference4               VARCHAR2(240),
  reference10              VARCHAR2(240),
  reference21              VARCHAR2(240),
  reference22              VARCHAR2(240),
  reference23              VARCHAR2(240),
  reference24              VARCHAR2(240),
  reference25              VARCHAR2(240),
  summary_flag             VARCHAR2(1),
  process_status           VARCHAR2(25),
  error_message            VARCHAR2(1000),
  creation_date            DATE,
  last_updated_by          NUMBER,
  last_update_date         DATE
);

CREATE OR REPLACE SYNONYM xxgl_cash_bal_tfm FOR fmsmgr.xxgl_cash_bal_tfm;

CREATE INDEX fmsmgr.xxgl_cash_bal_tfm_n1 ON fmsmgr.xxgl_cash_bal_tfm (request_id);

CREATE INDEX fmsmgr.xxgl_cash_bal_tfm_n2 ON fmsmgr.xxgl_cash_bal_tfm (group_id);

