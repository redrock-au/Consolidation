/*$Header: svn://d02584/consolrepos/branches/AR.09.03/apc/1.0.0/install/sql/KOFAX_POST_INSTALL_STEPS.sql 1424 2017-07-04 06:57:15Z svnuser $*/
CREATE USER KOFAX IDENTIFIED BY &Kofax_password DEFAULT TABLESPACE LOCDAT TEMPORARY TABLESPACE TEMP;
GRANT CONNECT,CREATE SESSION TO KOFAX;
GRANT SELECT,INSERT ON FMSMGR.XXAP_KOFAX_INV_STG TO KOFAX;
CREATE OR REPLACE SYNONYM KOFAX.XXAP_KOFAX_INV_STG FOR FMSMGR.XXAP_KOFAX_INV_STG;
CREATE SYNONYM KOFAX.XXAP_KOFAX_INTEGRATION_PKG FOR APPS.XXAP_KOFAX_INTEGRATION_PKG;
GRANT EXECUTE ON APPS.XXAP_PO_HEADER_INFO_TYPE TO KOFAX;
GRANT EXECUTE ON APPS.XXAP_PO_HEADER_INFO_TAB TO KOFAX;
GRANT EXECUTE ON APPS.XXAP_KOFAX_INTEGRATION_PKG TO KOFAX ;
GRANT ALL ON FMSMGR.XXAP_INV_SCANNED_FILE TO APPS WITH GRANT OPTION;
