REM $Header: svn://d02584/consolrepos/branches/AR.02.04/arc/1.0.0/install/sql/XXAR_OPEN_ITEMS_STG_DDL.sql 238 2017-05-01 06:15:09Z dart $
REM CEMLI ID: AR.02.04

-- Create Table

CREATE TABLE fmsmgr.xxar_open_items_stg
(
   record_id           NUMBER,
   run_id              NUMBER,
   run_phase_id        NUMBER,
   crn_number          VARCHAR2(150),
   orig_amt1           VARCHAR2(150),
   orig_amt2           VARCHAR2(150),
   orig_amt3           VARCHAR2(150),
   orig_amt4           VARCHAR2(150),
   status              VARCHAR2(25),
   created_by          NUMBER,
   creation_date       DATE
);

-- Create Synonym

CREATE SYNONYM xxar_open_items_stg FOR fmsmgr.xxar_open_items_stg;
