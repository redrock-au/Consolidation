REM $Header: svn://d02584/consolrepos/branches/AR.09.03/arc/1.0.0/install/sql/XXAR_OPEN_ITEMS_DISABLE_DML.sql 1059 2017-06-21 03:26:39Z svnuser $
REM CEMLI ID: AR.02.04

BEGIN
   fnd_program.enable_program('DOT_AR_OPEN_ITEMS_EXT', 'ARC', 'N');
   COMMIT;
END;
/
