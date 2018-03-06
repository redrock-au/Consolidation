/*$Header: svn://d02584/consolrepos/branches/AR.03.02/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1270 2017-06-27 00:16:38Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
