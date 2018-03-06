/*$Header: svn://d02584/consolrepos/branches/AP.03.01/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1221 2017-06-26 00:29:03Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
