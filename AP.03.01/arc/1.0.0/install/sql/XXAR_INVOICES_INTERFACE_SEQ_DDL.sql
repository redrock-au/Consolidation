REM $Header: svn://d02584/consolrepos/branches/AP.03.01/arc/1.0.0/install/sql/XXAR_INVOICES_INTERFACE_SEQ_DDL.sql 1818 2017-07-18 00:17:32Z svnuser $

CREATE SEQUENCE fmsmgr.xxar_invoices_int_record_id_s START WITH 1000 INCREMENT BY 1 NOCACHE;

CREATE SYNONYM xxar_invoices_int_record_id_s FOR fmsmgr.xxar_invoices_int_record_id_s;

CREATE SEQUENCE fmsmgr.xxar_invoices_int_autonum_s START WITH 11000 INCREMENT BY 1 NOCACHE;

CREATE SYNONYM xxar_invoices_int_autonum_s FOR fmsmgr.xxar_invoices_int_autonum_s;
