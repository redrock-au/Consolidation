REM $Header: svn://d02584/consolrepos/branches/AR.01.02/arc/1.0.0/install/sql/XXAR_INVOICES_INTERFACE_SEQ_DDL.sql 1832 2017-07-18 00:28:00Z svnuser $

CREATE SEQUENCE fmsmgr.xxar_invoices_int_record_id_s START WITH 1000 INCREMENT BY 1 NOCACHE;

CREATE SYNONYM xxar_invoices_int_record_id_s FOR fmsmgr.xxar_invoices_int_record_id_s;

CREATE SEQUENCE fmsmgr.xxar_invoices_int_autonum_s START WITH 11000 INCREMENT BY 1 NOCACHE;

CREATE SYNONYM xxar_invoices_int_autonum_s FOR fmsmgr.xxar_invoices_int_autonum_s;
