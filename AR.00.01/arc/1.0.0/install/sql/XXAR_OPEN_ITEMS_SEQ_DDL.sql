REM $Header: svn://d02584/consolrepos/branches/AR.00.01/arc/1.0.0/install/sql/XXAR_OPEN_ITEMS_SEQ_DDL.sql 1492 2017-07-05 07:01:42Z svnuser $
REM CEMLI ID: AR.02.04

-- Create Sequences

CREATE SEQUENCE fmsmgr.xxar_open_items_record_id_s START WITH 1000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE fmsmgr.xxar_payment_notices_b_s START WITH 1000 INCREMENT BY 1;

-- Create Synonyms

CREATE SYNONYM xxar_open_items_record_id_s FOR fmsmgr.xxar_open_items_record_id_s;
CREATE SYNONYM xxar_payment_notices_b_s FOR fmsmgr.xxar_payment_notices_b_s;

