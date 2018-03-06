/*$Header: svn://d02584/consolrepos/branches/AR.03.01/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1706 2017-07-12 04:37:42Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
