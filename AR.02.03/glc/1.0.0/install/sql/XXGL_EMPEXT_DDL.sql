REM $Header: svn://d02584/consolrepos/branches/AR.02.03/glc/1.0.0/install/sql/XXGL_EMPEXT_DDL.sql 2798 2017-10-12 05:12:11Z svnuser $
CREATE TABLE FMSMGR.XXGL_EMPEXT 
   (	DEFAULT_EFFECTIVE_DATE DATE, 
	PINNO VARCHAR2(240), 
	AMOUNT VARCHAR2(240), 
	CCTR VARCHAR2(240), 
	COL NUMBER
   ); 
   
CREATE SYNONYM XXGL_EMPEXT  FOR  FMSMGR.XXGL_EMPEXT;