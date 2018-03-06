CREATE OR REPLACE PACKAGE xxap_supplier_conv_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.03.01/apc/1.0.0/install/sql/XXAP_SUPPLIER_CONV_PKG.pks 1610 2017-07-10 01:53:55Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: PO.00.01
**
** Description: Conversion program for importing Suppliers, Sites and
**              Site Contacts from DSDBI. 
**
** Change History:
**
** Date        Who                  Comments
** 24/05/2017  sryan                Initial build.
**
*******************************************************************/
-- Interface definition
g_int_code             dot_int_interfaces.int_code%TYPE := 'PO.00.01';
g_int_name             dot_int_interfaces.int_name%TYPE := 'DEDJTR Supplier Conversion';
g_int_mode             VARCHAR2(60)   := 'VALIDATE_TRANSFER';
g_src_code             VARCHAR2(25)  := 'XXAPSPCONV';
g_file                 VARCHAR2(150) := '*.csv';
g_ctl                  VARCHAR2(150) := '$APC_TOP/bin/XXAPSUPCONV.ctl';
-- Errors and Debug
g_error                VARCHAR2(10)   := 'ERROR: ';
g_error_message_01     VARCHAR2(150)  := '<ERROR-01>Interface $INT_CODE is disabled from the interfaces registry table.';
g_error_message_02     VARCHAR2(150)  := '<ERROR-02>Unable to read file from $INT_DIR.';
g_error_message_03     VARCHAR2(150)  := '<ERROR-03>Unable to load file $INT_FILE.';
g_debug                VARCHAR2(10)   := 'DEBUG: ';
-- Other
g_rec_type_new         CONSTANT VARCHAR2(3) := 'NEW';
g_rec_type_site_only   CONSTANT VARCHAR2(9) := 'SITE_ONLY';
g_rec_type_map         CONSTANT VARCHAR2(3) := 'MAP';

PROCEDURE process_suppliers
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_source            IN  VARCHAR2,
   p_file_name         IN  VARCHAR2,
   p_control_file      IN  VARCHAR2,
   p_submit_import     IN  VARCHAR2,
   p_debug_flag        IN  VARCHAR2,
   p_int_mode          IN  VARCHAR2
);

PROCEDURE post_conversion_update
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_debug_flag        IN  VARCHAR2 DEFAULT 'Y'
);

END xxap_supplier_conv_pkg;
/
