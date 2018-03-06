/*$Header: svn://d02584/consolrepos/branches/AP.03.02/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1472 2017-07-05 00:35:27Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
