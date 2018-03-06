/* $Header: svn://d02584/consolrepos/branches/AR.02.02/glc/1.0.0/install/sql/XXGL_CASH_BAL_RULES_UPLOAD.sql 3066 2017-11-28 06:24:56Z svnuser $ */

PROMPT Truncate table XXGL_CASH_BAL_RULES_ALL

TRUNCATE TABLE fmsmgr.xxgl_cash_bal_rules_all;

PROMPT Uploading Cash Balancing Rules

INSERT INTO xxgl_cash_bal_rules_all VALUES (1002, 'R040', 1, 'Trade Receipts', 'Receivables', 'TRADE', 'TRADE_REC', 'CSH', '%', '15201', '%', '%', '%', '%', '%', '%', '15206', '%', '%', '%', '%', '%', 'N', 'Y', '+', '', '', '', 'N', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1003, 'R041', 1, 'Trade Receipts', 'Receivables', 'TRADE', 'TRADE_REC', 'CSH', '%', '15201', '%', '%', '%', '%', '%', '%', '15206', '%', '%', '%', '%', '00000007', 'N', 'N', '-', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1004, 'R042', 1, 'Sales Invoices', 'Receivables', 'INV', 'INV_REC', 'CSH', '%', '15201', '%', '%', '%', '%', '%', '%', '15206', '%', '%', '%', '%', '%', 'N', 'Y', '+', '', '', '', 'N', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1005, 'R043', 1, 'Sales Invoices', 'Receivables', 'INV', 'INV_REC', 'CSH', '%', '15201', '%', '%', '%', '%', '%', '%', '15206', '%', '%', '%', '%', '00000007', 'N', 'N', '-', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1006, 'R050', 1, 'Sales Invoices', 'Receivables', 'INV', 'INV_TAX', 'CSH', 'Y', '36821', '%', '%', '%', '%', '%', '%', '36826', '%', '%', '%', '%', '%', 'Y', 'Y', '+', '', '', '', 'N', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1007, 'R051', 1, 'Sales Invoices', 'Receivables', 'INV', 'INV_TAX', 'CSH', 'Y', '36821', '%', '%', '%', '%', '%', '%', '36826', '%', '%', '%', '%', '00000007', 'Y', 'N', '-', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1008, 'R060', 1, 'Trade Receipts', 'Receivables', 'TRADE', 'TRADE_CASH', 'CSH', 'Y', '%', '%', '%', '%', '%', '%', '%', '45001', '%', '%', '%', '%', 'RECEIPTS', 'Y', 'Y', '+', '', '', '', 'N', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1009, 'R061', 1, 'Trade Receipts', 'Receivables', 'TRADE', 'TRADE_CASH', 'CSH', 'Y', '%', '%', '%', '%', '%', '%', '%', '45001', '%', '%', '%', '%', '00000007', 'Y', 'N', '-', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1010, 'R062', 1, 'Misc Receipts', 'Receivables', 'MISC', 'MISC_CASH', 'CSH', 'Y', '%', '%', '%', '%', '%', '%', '%', '45001', '%', '%', '%', '%', 'RECEIPTS', 'Y', 'Y', '+', '', '', '', 'N', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '27274', TO_DATE('2017/10/20 11:14:49', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1011, 'R063', 1, 'Misc Receipts', 'Receivables', 'MISC', 'MISC_CASH', 'CSH', 'Y', '%', '%', '%', '%', '%', '%', '%', '45001', '%', '%', '%', '%', '00000007', 'Y', 'N', '-', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '27274', TO_DATE('2017/10/20 11:14:49', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1012, 'R064', 1, 'Misc Receipts', 'Receivables', 'MISC', 'MISC_TAX', 'CSH', 'Y', '36821', '%', '%', '%', '%', '%', '%', '36826', '%', '%', '%', '%', '%', 'Y', 'Y', '+', '', '', '', 'N', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '27274', TO_DATE('2017/10/20 11:14:49', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1013, 'R065', 1, 'Misc Receipts', 'Receivables', 'MISC', 'MISC_TAX', 'CSH', 'Y', '36821', '%', '%', '%', '%', '%', '%', '36826', '%', '%', '%', '%', '00000007', 'Y', 'N', '-', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '27274', TO_DATE('2017/10/20 11:14:49', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1014, 'P050', 1, 'Purchase Invoices', 'Payables', 'INVOICE', 'LIABILITY', 'CSH', 'Y', '30101', '%', '%', '%', '%', '%', '%', '30106', '%', '%', '%', '%', '%', 'Y', 'Y', '+', '', '', '', 'N', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1015, 'P051', 1, 'Purchase Invoices', 'Payables', 'INVOICE', 'LIABILITY', 'CSH', 'Y', '30101', '%', '%', '%', '%', '%', '%', '30106', '%', '%', '%', '%', '00000007', 'Y', 'N', '-', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1016, 'P052', 1, 'Reconciled Payments', 'Payables', 'PAYMENT', 'CASH', 'CSH', 'Y', '%', '%', '%', '%', '%', '%BANK000', '%', '30106', '%', '%', '%', '%', '00000007', 'Y', 'N', '+', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1017, 'P053', 1, 'Reconciled Payments', 'Payables', 'PAYMENT', 'CASH', 'CSH', 'Y', '%', '%', '%', '%', '%', '%BANK000', '%', '30106', '%', '%', '%', '%', '%', 'Y', 'Y', '-', '', '', '', 'N', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1018, 'P060', 1, 'Purchase Invoices', 'Payables', 'INVOICE', 'RECOVERABLE_TAX', 'CSH', 'Y', '16601', '%', '%', '%', '%', '%', '%', '16606', '%', '%', '%', '%', '%', 'Y', 'Y', '+', '', '', '', 'N', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1019, 'P061', 1, 'Purchase Invoices', 'Payables', 'INVOICE', 'RECOVERABLE_TAX', 'CSH', 'Y', '16601', '%', '%', '%', '%', '%', '%', '16606', '%', '%', '%', '%', '00000007', 'Y', 'N', '-', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1020, 'P070', 1, 'Reconciled Payments', 'Payables', 'PAYMENT', 'CASH', 'CSH', 'Y', '%', '%', '%', '%', '%', '%BANK000', '%', '45001', '%', '%', '%', '%', 'PAYMENTS', 'Y', 'Y', '+', '', '', '', 'N', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1021, 'P071', 1, 'Reconciled Payments', 'Payables', 'PAYMENT', 'CASH', 'CSH', 'Y', '%', '%', '%', '%', '%', '%BANK000', '%', '45001', '%', '%', '%', '%', '00000007', 'Y', 'N', '-', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1023, 'G010', 1, 'Payables Adjustment', 'Cash Balancing', 'CSH_TAX', 'GST_RECOUP', 'GST', '%', '16606', '000', '0000', '0000', '0000', '00000007', '%', '16606', '000', '0000', '0000', '0000', '00000007', 'N', 'N', '-', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1024, 'G011', 1, 'Payables Adjustment', 'Cash Balancing', 'CSH_TAX', 'GST_RECOUP', 'GST', '%', '16606', '%', '%', '%', '%', '%', '%', '16606', '%', '%', '%', '%', '%', 'N', 'N', '-', '', 'SELECT ''Y'' FROM GL_CODE_COMBINATIONS WHERE CODE_COMBINATION_ID = :1 AND SEGMENT7 NOT IN (''00000007'')', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1025, 'G012', 1, 'Receivables Adjustments', 'Cash Balancing', 'CSH_TAX', 'GST_RECOUP', 'GST', '%', '36826', '000', '0000', '0000', '0000', '00000007', '%', '36826', '000', '0000', '0000', '0000', '00000007', 'N', 'N', '-', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1027, 'G013', 1, 'Receivables Adjustments', 'Cash Balancing', 'CSH_TAX', 'GST_RECOUP', 'GST', '%', '36826', '%', '%', '%', '%', '%', '%', '36826', '%', '%', '%', '%', '%', 'N', 'N', '-', '', 'SELECT ''Y'' FROM GL_CODE_COMBINATIONS WHERE CODE_COMBINATION_ID = :1 AND SEGMENT7 NOT IN (''00000007'')', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1028, 'G014', 1, 'Payables Adjustment', 'Cash Balancing', 'CSH_TAX', 'GST_RECOUP', 'GST', '%', '16606', '000', '0000', '0000', '0000', '00000007', '%', '45001', '000', '0000', '0000', '0000', '00000007', 'N', 'N', '+', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1029, 'G015', 1, 'Receivables Adjustments', 'Cash Balancing', 'CSH_TAX', 'GST_RECOUP', 'GST', '%', '36826', '000', '0000', '0000', '0000', '00000007', '%', '45001', '000', '0000', '0000', '0000', '00000007', 'N', 'N', '+', '', '', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1056, 'G016', 1, 'Payables Adjustment', 'Cash Balancing', 'CSH_TAX', 'GST_RECOUP', 'GST', '%', '16606', '%', '%', '%', '%', '%', '%', '45001', '%', '%', '%', '%', 'PAYMENTS', 'N', 'N', '+', '', 'SELECT ''Y'' FROM GL_CODE_COMBINATIONS WHERE CODE_COMBINATION_ID = :1 AND SEGMENT7 NOT IN (''00000007'')', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1057, 'G017', 1, 'Receivables Adjustments', 'Cash Balancing', 'CSH_TAX', 'GST_RECOUP', 'GST', '%', '36826', '%', '%', '%', '%', '%', '%', '45001', '%', '%', '%', '%', 'RECEIPTS', 'N', 'N', '+', '', 'SELECT ''Y'' FROM GL_CODE_COMBINATIONS WHERE CODE_COMBINATION_ID = :1 AND SEGMENT7 NOT IN (''00000007'')', '', 'Y', 'APPLY', 101, '-1', TO_DATE('2017/06/16 15:38:03', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1058, 'R031', 1, 'Credit Memos', 'Receivables', 'CM', 'CM_TAX', 'CSH', 'Y', '36821', '%', '%', '%', '%', '%', '%', '36826', '%', '%', '%', '%', '00000007', 'Y', 'N', '+', '', '', '', 'Y', 'APPLY', 101, '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1059, 'R021', 1, 'Credit Memos', 'Receivables', 'CM', 'CM_REC', 'CSH', '%', '15201', '%', '%', '%', '%', '%', '%', '15206', '%', '%', '%', '%', '00000007', 'N', 'N', '+', '', '', '', 'Y', 'APPLY', 101, '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1060, 'R030', 1, 'Credit Memos', 'Receivables', 'CM', 'CM_TAX', 'CSH', 'Y', '36821', '%', '%', '%', '%', '%', '%', '36826', '%', '%', '%', '%', '%', 'Y', 'Y', '-', '', '', '', 'N', 'APPLY', 101, '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1061, 'R020', 1, 'Credit Memos', 'Receivables', 'CM', 'CM_REC', 'CSH', '%', '15201', '%', '%', '%', '%', '%', '%', '15206', '%', '%', '%', '%', '%', 'N', 'Y', '-', '', '', '', 'N', 'APPLY', 101, '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/10/19 13:53:01', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1062, 'R066', 1, 'Misc Receipts', 'Receivables', 'MISC', 'MISC_TAX', 'CSH', 'Y', '16601', '%', '%', '%', '%', '%', '%', '16606', '%', '%', '%', '%', '%', 'Y', 'Y', '+', '', '', '', 'N', 'APPLY', 101, '27274', TO_DATE('2017/10/20 10:28:04', 'YYYY/MM/DD HH24:MI:SS'), '27274', TO_DATE('2017/10/20 11:14:49', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1063, 'R067', 1, 'Misc Receipts', 'Receivables', 'MISC', 'MISC_TAX', 'CSH', 'Y', '16601', '%', '%', '%', '%', '%', '%', '16606', '%', '%', '%', '%', '00000007', 'Y', 'N', '-', '', '', '', 'Y', 'APPLY', 101, '27274', TO_DATE('2017/10/20 10:28:04', 'YYYY/MM/DD HH24:MI:SS'), '27274', TO_DATE('2017/10/20 11:14:49', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1064, 'P054', 1, 'Reconciled Payments', 'Payables', 'PAYMENT', 'CORP_CARD', 'CSH', 'Y', '%', '%', '%', '%', '%', '%BANK%', '%', '30106', '000', '0000', '0000', '0000', '00000007', 'Y', 'Y', '-', '', '', '', 'N', 'APPLY', 101, '-1', TO_DATE('2017/11/01 15:29:00', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/11/01 15:29:00', 'YYYY/MM/DD HH24:MI:SS')); 
INSERT INTO xxgl_cash_bal_rules_all VALUES (1066, 'P055', 1, 'Reconciled Payments', 'Payables', 'PAYMENT', 'CORP_CARD', 'CSH', 'Y', '%', '%', '%', '%', '%', '%BANK%', '%', '45001', '000', '0000', '0000', '0000', '00000007', 'Y', 'Y', '+', '', 'SELECT DECODE(SIGN(:1), -1, ''PAYMENTS'', ''00000007'') FROM DUAL', '', 'N', 'APPLY', 101, '-1', TO_DATE('2017/11/01 15:29:00', 'YYYY/MM/DD HH24:MI:SS'), '1003', TO_DATE('2017/11/01 15:29:00', 'YYYY/MM/DD HH24:MI:SS')); 

COMMIT;

PROMPT Recreating table sequence xxgl_cash_bal_rule_id_s

DROP SEQUENCE fmsmgr.xxgl_cash_bal_rule_id_s;

CREATE SEQUENCE fmsmgr.xxgl_cash_bal_rule_id_s START WITH 1067 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE SYNONYM xxgl_cash_bal_rule_id_s FOR fmsmgr.xxgl_cash_bal_rule_id_s;

ALTER TRIGGER xxgl_cash_bal_rules_t1 COMPILE;
