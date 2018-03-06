/*$Header: svn://d02584/consolrepos/branches/AR.00.02/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1496 2017-07-05 07:15:13Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
