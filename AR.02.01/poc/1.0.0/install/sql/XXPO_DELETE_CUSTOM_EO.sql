/*$Header: svn://d02584/consolrepos/branches/AR.02.01/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1385 2017-07-03 00:55:13Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
