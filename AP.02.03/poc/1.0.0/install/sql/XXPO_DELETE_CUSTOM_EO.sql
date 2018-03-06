/*$Header: svn://d02584/consolrepos/branches/AP.02.03/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1442 2017-07-04 22:35:02Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
