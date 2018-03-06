/*$Header: svn://d02584/consolrepos/branches/AR.01.01/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1262 2017-06-26 23:43:06Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
