/*$Header: svn://d02584/consolrepos/branches/AR.01.02/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1274 2017-06-27 01:12:13Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
