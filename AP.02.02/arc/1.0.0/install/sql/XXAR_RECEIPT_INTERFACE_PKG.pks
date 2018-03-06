CREATE OR REPLACE PACKAGE xxar_receipt_interface_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.02.02/arc/1.0.0/install/sql/XXAR_RECEIPT_INTERFACE_PKG.pks 1607 2017-07-10 01:20:42Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: AR.02.03
**
** Description: Interface program for importing Receivables 
**              receipts from various feeder systems. 
**
** Change History:
**
** Date        Who                  Comments
** 05/05/2017  sryan (RED ROCK)     Initial build.
**
*******************************************************************/
-- Interface definition
g_int_code             dot_int_interfaces.int_code%TYPE := 'AR.02.03';
g_int_name             dot_int_interfaces.int_name%TYPE := 'DEDJTR AR Receipts Inbound Interface';
g_int_mode             VARCHAR2(60)   := 'VALIDATE_TRANSFER';
g_src_code             VARCHAR2(25)  := 'XXARRECINT';
g_file                 VARCHAR2(150) := '*.csv';
g_ctl                  VARCHAR2(150) := '$ARC_TOP/bin/XXARRECINT.ctl';
-- Errors and Debug
g_error                VARCHAR2(10)   := 'ERROR: ';
g_error_message_01     VARCHAR2(150)  := '<ERROR-01>Interface $INT_CODE is disabled from the interfaces registry table.';
g_error_message_02     VARCHAR2(150)  := '<ERROR-02>Unable to read file from $INT_DIR.';
g_error_message_03     VARCHAR2(150)  := '<ERROR-03>Unable to load file $INT_FILE.';
g_debug                VARCHAR2(10)   := 'DEBUG: ';

PROCEDURE process_receipts
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_source            IN  VARCHAR2,
   p_gl_date           IN  VARCHAR2,
   p_receipt_class_id  IN  VARCHAR2,
   p_file_name         IN  VARCHAR2,
   p_control_file      IN  VARCHAR2,
   p_debug_flag        IN  VARCHAR2,
   p_int_mode          IN  VARCHAR2,
   p_purge_retention   IN  NUMBER DEFAULT NULL
);

END xxar_receipt_interface_pkg;
/
