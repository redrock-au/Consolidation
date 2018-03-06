/* $Header: svn://d02584/consolrepos/branches/AR.00.01/glc/1.0.0/install/sql/XXGL_CASH_BAL_CTL_DDL.sql 1492 2017-07-05 07:01:42Z svnuser $ */

CREATE TABLE fmsmgr.xxgl_cash_bal_ctl
(
   je_header_id         NUMBER(15),
   je_source            VARCHAR2(25),
   je_category          VARCHAR2(25),
   balancing_status     VARCHAR2(1), -- E=Error S=Success W=Warning C=Conversion
   created_by           NUMBER,
   creation_date        DATE,
   last_updated_by      NUMBER,
   last_update_date     DATE
);

CREATE OR REPLACE SYNONYM xxgl_cash_bal_ctl FOR fmsmgr.xxgl_cash_bal_ctl;

CREATE INDEX fmsmgr.xxgl_cash_bal_ctl_n1 ON fmsmgr.xxgl_cash_bal_ctl (je_header_id);

CREATE INDEX fmsmgr.xxgl_cash_bal_ctl_n2 ON fmsmgr.xxgl_cash_bal_ctl (balancing_status);
