REM $Header: svn://d02584/consolrepos/branches/AP.02.02/glc/1.0.0/install/sql/XXGL_EMPRPT_DDL.sql 2999 2017-11-17 04:36:48Z svnuser $
CREATE TABLE FMSMGR.XXGL_EMPRPT 
   (	CCTR VARCHAR2(240), 
	N_EMPLOYEES NUMBER, 
	PINNO VARCHAR2(240), 
	PAY1 NUMBER, 
	PAY2 NUMBER, 
	PAY3 NUMBER, 
	ACCRUAL_AMT NUMBER, 
	OTHER_AMOUNT NUMBER, 
	TOTAL_AMOUNT NUMBER
   ); 
   
CREATE SYNONYM XXGL_EMPRPT  FOR  FMSMGR.XXGL_EMPRPT;