rem $Header: svn://d02584/consolrepos/branches/AR.01.01/fndc/1.0.0/admin/sql/dot_common_int_alter_ddl.sql 1262 2017-06-26 23:43:06Z svnuser $
rem Script to add the new phase mode TRANSFER
rem Creation Date: 19-May-2017
ALTER TABLE FMSMGR.DOT_INT_RUN_PHASES DROP CONSTRAINT DOT_INT_RUN_PHASES_CHK1;
ALTER TABLE FMSMGR.DOT_INT_RUN_PHASES ADD CONSTRAINT DOT_INT_RUN_PHASES_CHK1 CHECK (PHASE_MODE IN ('VALIDATE','VALIDATE_TRANSFER','TRANSFER'));