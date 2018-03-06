/* $Header: svn://d02584/consolrepos/branches/AR.00.02/glc/1.0.0/install/sql/XXGL_CASH_BAL_RULES_ALL_DDL.sql 1496 2017-07-05 07:15:13Z svnuser $ */

CREATE TABLE fmsmgr.xxgl_cash_bal_rules_all
(
   rule_id                  NUMBER NOT NULL,
   rule_num                 VARCHAR2(10) NOT NULL,
   set_of_books_id          NUMBER,
   journal_category         VARCHAR2(150),
   journal_source           VARCHAR2(150),
   sl_trx_type              VARCHAR2(150),
   sl_trx_subtype           VARCHAR2(150),
   allocation_type          VARCHAR2(3),
   source_entity            VARCHAR2(25),
   source_account           VARCHAR2(25),
   source_cost_centre       VARCHAR2(25),
   source_authority         VARCHAR2(25),
   source_project           VARCHAR2(25),
   source_output            VARCHAR2(25),
   source_identifier        VARCHAR2(25),
   target_entity            VARCHAR2(25),
   target_account           VARCHAR2(25),
   target_cost_centre       VARCHAR2(25),
   target_authority         VARCHAR2(25),
   target_project           VARCHAR2(25),
   target_output            VARCHAR2(25),
   target_identifier        VARCHAR2(25),
   entity_offset_flag       VARCHAR2(1),   -- Use offset Segment1
   default_value_flag       VARCHAR2(1),   -- Use the revenue or expense account as default
   enter_amount             VARCHAR2(1),
   derive_amount            VARCHAR2(60),
   filter_condition_line1   VARCHAR2(4000),
   filter_condition_line2   VARCHAR2(4000),
   summary_flag             VARCHAR2(1),
   status                   VARCHAR2(15),  -- 'TEST', 'APPLY', 'DELETE'
   org_id                   NUMBER,
   created_by               NUMBER,
   creation_date            DATE,
   last_updated_by          NUMBER,
   last_update_date         DATE
);

CREATE OR REPLACE SYNONYM xxgl_cash_bal_rules_all FOR fmsmgr.xxgl_cash_bal_rules_all;

CREATE UNIQUE INDEX fmsmgr.xxgl_cash_bal_rules_u1 ON fmsmgr.xxgl_cash_bal_rules_all (rule_num);

CREATE OR REPLACE TRIGGER xxgl_cash_bal_rules_t1
BEFORE INSERT ON xxgl_cash_bal_rules_all
FOR EACH ROW
BEGIN
   IF :NEW.rule_id IS NULL THEN
      :NEW.rule_id := xxgl_cash_bal_rule_id_s.NEXTVAL;
   END IF;

   IF :NEW.summary_flag IS NULL THEN
      :NEW.summary_flag := 'N';
   END IF;

   IF :NEW.status IS NULL THEN
      :NEW.status := 'TEST';
   END IF;
END;
/
