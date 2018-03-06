/*$Header: svn://d02584/consolrepos/branches/AR.09.03/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1424 2017-07-04 06:57:15Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
