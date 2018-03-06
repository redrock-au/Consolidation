/*$Header: svn://d02584/consolrepos/branches/AP.01.02/poc/1.0.0/install/sql/XXPO_DELETE_CUSTOM_EO.sql 1368 2017-07-02 23:54:39Z svnuser $*/
begin
   jdr_utils.deletedocument('/oracle/apps/icx/por/schema/server/customizations/site/0/PoRequisitionHeaderEO');
   commit;
end;
/
