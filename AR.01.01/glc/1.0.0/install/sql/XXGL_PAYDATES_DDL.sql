REM $Header: svn://d02584/consolrepos/branches/AR.01.01/glc/1.0.0/install/sql/XXGL_PAYDATES_DDL.sql 2949 2017-11-13 01:09:55Z svnuser $
CREATE TABLE FMSMGR.XXGL_PAYDATES 
   (	DATE1 DATE, 
	DATE2 DATE, 
	DATE3 DATE
   );
   
CREATE SYNONYM XXGL_PAYDATES  FOR  FMSMGR.XXGL_PAYDATES;
   
   