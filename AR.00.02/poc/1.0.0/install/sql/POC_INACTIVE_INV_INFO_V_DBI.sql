/*$Header: svn://d02584/consolrepos/branches/AR.00.02/poc/1.0.0/install/sql/POC_INACTIVE_INV_INFO_V_DBI.sql 1496 2017-07-05 07:15:13Z svnuser $*/
CREATE OR REPLACE VIEW 
apps.poc_inactive_inv_info_v_dbi 
(
   document_id
) 
AS 
SELECT import_id document_id
FROM   xxap_inv_scanned_file xisf
WHERE  nvl(active_flag,'Y') = 'N'
AND    nvl(deleted_in_kofax,'N') = 'N';

 GRANT SELECT ON apps.poc_inactive_inv_info_v_dbi TO KOFAX;

 CREATE OR REPLACE SYNONYM KOFAX.poc_inactive_inv_info_v_dbi  FOR apps.poc_inactive_inv_info_v_dbi ;
/
