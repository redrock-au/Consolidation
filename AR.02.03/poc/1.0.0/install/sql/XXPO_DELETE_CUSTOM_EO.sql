/*$Header: svn://d02584/consolrepos/branches/AR.02.03/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1100 2017-06-21 06:55:27Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
