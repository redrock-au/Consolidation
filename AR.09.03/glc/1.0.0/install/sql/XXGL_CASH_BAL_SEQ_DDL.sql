/* $Header: svn://d02584/consolrepos/branches/AR.09.03/glc/1.0.0/install/sql/XXGL_CASH_BAL_SEQ_DDL.sql 1424 2017-07-04 06:57:15Z svnuser $ */

--RULE_ID

CREATE SEQUENCE fmsmgr.xxgl_cash_bal_rule_id_s START WITH 1000 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE SYNONYM xxgl_cash_bal_rule_id_s FOR fmsmgr.xxgl_cash_bal_rule_id_s;

--GROUP_ID

CREATE SEQUENCE fmsmgr.xxgl_cash_bal_group_id_s START WITH 1000 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE SYNONYM xxgl_cash_bal_group_id_s FOR fmsmgr.xxgl_cash_bal_group_id_s;

--RECORD_ID

CREATE SEQUENCE fmsmgr.xxgl_cash_bal_record_id_s START WITH 1000 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE SYNONYM xxgl_cash_bal_record_id_s FOR fmsmgr.xxgl_cash_bal_record_id_s;
