/* $Header: svn://d02584/consolrepos/branches/AP.02.02/fndc/1.0.0/install/sql/DOT_AP_INVOICES_DW_ALTER.sql 2999 2017-11-17 04:36:48Z svnuser $ */

PROMPT ALTER TABLE APPSSQL.DOT_AP_INVOICES_DW

ALTER TABLE APPSSQL.DOT_AP_INVOICES_DW
ADD (DOCUMENT_URL VARCHAR2(600));
