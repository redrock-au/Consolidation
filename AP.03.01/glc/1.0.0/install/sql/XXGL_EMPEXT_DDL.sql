REM $Header: svn://d02584/consolrepos/branches/AP.03.01/glc/1.0.0/install/sql/XXGL_EMPEXT_DDL.sql 2724 2017-10-09 03:53:46Z svnuser $
CREATE TABLE FMSMGR.XXGL_EMPEXT 
   (	DEFAULT_EFFECTIVE_DATE DATE, 
	PINNO VARCHAR2(240), 
	AMOUNT VARCHAR2(240), 
	CCTR VARCHAR2(240), 
	COL NUMBER
   ); 
   
CREATE SYNONYM XXGL_EMPEXT  FOR  FMSMGR.XXGL_EMPEXT;