CREATE OR REPLACE PACKAGE xxar_open_items_interface_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.02/arc/1.0.0/install/sql/XXAR_OPEN_ITEMS_INTERFACE_PKG.pks 1849 2017-07-18 02:20:57Z svnuser $ */

/****************************************************************************
**
** CEMLI ID: AR.02.04
**
** Description: Data import program for Open Items coming from an external
**              system.
**
** Change History:
**
** Date        Who                  Comments
** 18/04/2017  ARELLAD (RED ROCK)   Initial build.
**
****************************************************************************/

-- Defaults and Messages
g_error_message_01     VARCHAR2(150)  := '<ERROR-01>Interface $INT_CODE is disabled from the interfaces registry table.';
g_error_message_02     VARCHAR2(150)  := '<ERROR-02>Unable to read file from $INT_DIR.';
g_error_message_03     VARCHAR2(150)  := '<ERROR-03>Unable to load file $INT_FILE.';
g_error_message_04     VARCHAR2(150)  := '<ERROR-04>CRN must not be null or length must be 11 digits.';
g_error_message_05     VARCHAR2(150)  := '<ERROR-05>Found duplicate CRN within the file.';
g_error_message_06     VARCHAR2(150)  := '<ERROR-06>Found duplicate CRN Number that is still active.';
g_error_message_07     VARCHAR2(150)  := '<ERROR-07>Unable to perform character to number conversion on $COL_VAL field';
g_appl_short_name      VARCHAR2(10)   := 'AR';
g_debug                VARCHAR2(30)   := 'DEBUG: ';
g_error                VARCHAR2(30)   := 'ERROR: ';
g_source_directory     VARCHAR2(30)   := 'OPENITEMS';
g_staging_directory    VARCHAR2(30)   := 'WORKING';
g_int_mode             VARCHAR2(60)   := 'VALIDATE_TRANSFER';
z_src_code             VARCHAR2(30)   := '3PS';
z_stage                VARCHAR2(30)   := 'STAGE';
z_transform            VARCHAR2(30)   := 'TRANSFORM';
z_load                 VARCHAR2(30)   := 'LOAD';
z_int_code             dot_int_interfaces.int_code%TYPE := 'AR.02.04';
z_int_name             dot_int_interfaces.int_name%TYPE := 'DEDJTR AR Open Items Load and Archive';
g_file                 VARCHAR2(150)  := '*OPEN_ITEMS*.txt';
g_ctl                  VARCHAR2(150)  := '$ARC_TOP/bin/XXARITEMSIMP.ctl';
g_reset_tfm_sql        VARCHAR2(1000) := 'TRUNCATE TABLE FMSMGR.XXAR_OPEN_ITEMS_TFM';
g_procedure_name       VARCHAR2(150) := 'xxar_open_items_interface_pkg.open_items_import';
g_debug_flag           VARCHAR2(1) := 'N';

PROCEDURE open_items_import
(
   p_errbuff          OUT  VARCHAR2,
   p_retcode          OUT  NUMBER,
   p_source           IN   VARCHAR2,
   p_file_name        IN   VARCHAR2,
   p_control_file     IN   VARCHAR2,
   p_archive_flag     IN   VARCHAR2,
   p_debug_flag       IN   VARCHAR2,
   p_int_mode         IN   VARCHAR2
);

PROCEDURE open_items_extract
(
   p_errbuff   OUT VARCHAR2,
   p_retcode   OUT NUMBER,
   p_source    IN  VARCHAR2
);

END xxar_open_items_interface_pkg;
/
