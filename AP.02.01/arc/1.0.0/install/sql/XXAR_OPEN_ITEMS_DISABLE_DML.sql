REM $Header: svn://d02584/consolrepos/branches/AP.02.01/arc/1.0.0/install/sql/XXAR_OPEN_ITEMS_DISABLE_DML.sql 1427 2017-07-04 07:19:13Z svnuser $
REM CEMLI ID: AR.02.04

BEGIN
   fnd_program.enable_program('DOT_AR_OPEN_ITEMS_EXT', 'ARC', 'N');
   COMMIT;
END;
/
