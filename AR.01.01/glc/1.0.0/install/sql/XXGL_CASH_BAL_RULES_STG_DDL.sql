/* $Header: svn://d02584/consolrepos/branches/AR.01.01/glc/1.0.0/install/sql/XXGL_CASH_BAL_RULES_STG_DDL.sql 1379 2017-07-03 00:43:56Z svnuser $ */

CREATE TABLE fmsmgr.xxgl_cash_bal_rules_stg
(
   rule_num                        VARCHAR2(500),
   set_of_books_id                 VARCHAR2(500),
   journal_category                VARCHAR2(500),
   journal_source                  VARCHAR2(500),
   sl_trx_type                     VARCHAR2(500),
   sl_trx_subtype                  VARCHAR2(500),
   allocation_type                 VARCHAR2(500),
   source_entity                   VARCHAR2(500),
   source_account                  VARCHAR2(500),
   source_cost_centre              VARCHAR2(500),
   source_authority                VARCHAR2(500),
   source_project                  VARCHAR2(500),
   source_output                   VARCHAR2(500),
   source_identifier               VARCHAR2(500),
   target_entity                   VARCHAR2(500),
   target_account                  VARCHAR2(500),
   target_cost_centre              VARCHAR2(500),
   target_authority                VARCHAR2(500),
   target_project                  VARCHAR2(500),
   target_output                   VARCHAR2(500),
   target_identifier               VARCHAR2(500),
   entity_offset_flag              VARCHAR2(500),
   default_value_flag              VARCHAR2(500),
   enter_amount                    VARCHAR2(500),
   filter_condition_line1          VARCHAR2(4000),
   filter_condition_line2          VARCHAR2(4000),
   summary_flag                    VARCHAR2(500),
   status                          VARCHAR2(500),
   org_id                          VARCHAR2(500)
);

CREATE OR REPLACE SYNONYM xxgl_cash_bal_rules_stg FOR fmsmgr.xxgl_cash_bal_rules_stg;

