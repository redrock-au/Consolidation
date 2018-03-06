REM $Header: svn://d02584/consolrepos/branches/AP.02.02/arc/1.0.0/install/sql/XXAR_OPEN_ITEMS_TFM_DDL.sql 1607 2017-07-10 01:20:42Z svnuser $
REM CEMLI ID: AR.02.04

-- Create Table

CREATE TABLE fmsmgr.xxar_open_items_tfm
(
   record_id           NUMBER,
   run_id              NUMBER,
   run_phase_id        NUMBER,
   crn_number          VARCHAR2(12),
   orig_amt1           NUMBER,
   orig_amt2           NUMBER,
   orig_amt3           NUMBER,
   orig_amt4           NUMBER,
   status              VARCHAR2(25),
   object_version_id   NUMBER,
   created_by          NUMBER,
   creation_date       DATE
);

-- Create Synonym

CREATE SYNONYM xxar_open_items_tfm FOR fmsmgr.xxar_open_items_tfm;
