REM $Header: svn://d02584/consolrepos/branches/AR.01.01/glc/1.0.0/install/sql/XXGL_EMPRPT_DDL.sql 2949 2017-11-13 01:09:55Z svnuser $
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