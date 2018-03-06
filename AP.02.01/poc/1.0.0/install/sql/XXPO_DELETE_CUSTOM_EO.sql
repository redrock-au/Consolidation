/*$Header: svn://d02584/consolrepos/branches/AP.02.01/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1427 2017-07-04 07:19:13Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
