REM $Header: svn://d02584/consolrepos/branches/AP.01.01/glc/1.0.0/install/sql/XXGL_PAYDATES_DDL.sql 2674 2017-10-05 01:02:16Z svnuser $
CREATE TABLE FMSMGR.XXGL_PAYDATES 
   (	DATE1 DATE, 
	DATE2 DATE, 
	DATE3 DATE
   );
   
CREATE SYNONYM XXGL_PAYDATES  FOR  FMSMGR.XXGL_PAYDATES;
   
   