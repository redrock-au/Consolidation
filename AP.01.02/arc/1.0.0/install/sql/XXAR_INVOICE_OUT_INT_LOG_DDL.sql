REM $Header: svn://d02584/consolrepos/branches/AP.01.02/arc/1.0.0/install/sql/XXAR_INVOICE_OUT_INT_LOG_DDL.sql 1081 2017-06-21 05:49:47Z svnuser $

CREATE TABLE fmsmgr.xxar_invoice_out_int_log 
(
   request_id         NUMBER, 
   transaction_source VARCHAR2(100), 
   transaction_type   VARCHAR2(100), 
   last_outbound_date DATE, 
   status             VARCHAR2(100),
   message            VARCHAR2(500),
   created_by         NUMBER, 
   creation_date      DATE,
   last_updated_by    NUMBER, 
   last_update_Date   DATE
);

CREATE SYNONYM xxar_invoice_out_int_log FOR  fmsmgr.xxar_invoice_out_int_log;
