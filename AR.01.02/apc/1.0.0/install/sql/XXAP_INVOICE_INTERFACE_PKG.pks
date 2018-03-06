CREATE OR REPLACE PACKAGE xxap_invoice_interface_pkg
AS
/* $Header: svn://d02584/consolrepos/branches/AR.01.02/apc/1.0.0/install/sql/XXAP_INVOICE_INTERFACE_PKG.pks 2365 2017-08-30 05:13:46Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: AP.02.01
**
** Description: Interface program for importing Payables 
**              invoices from various feeder systems. 
**
** Change History:
**
** Date        Who                  Comments
** 27/04/2017  SRYAN (RED ROCK)     Initial build.
**
*******************************************************************/
-- Interface definition
g_int_code             dot_int_interfaces.int_code%TYPE := 'AP.02.01';
g_int_name             dot_int_interfaces.int_name%TYPE := 'DEDJTR Payables Invoice Interface';
g_int_mode             VARCHAR2(60)   := 'VALIDATE_TRANSFER';
g_src_code             VARCHAR2(25)  := 'XXAPINVINT'; -- 'XXGL_PAY_ACCR_INT';
g_file                 VARCHAR2(150) := '*.csv';
g_ctl                  VARCHAR2(150) := '$APC_TOP/bin/XXAPINVINT.ctl';
-- Errors and Debug
g_error                VARCHAR2(10)   := 'ERROR: ';
g_error_message_01     VARCHAR2(150)  := '<ERROR-01>Interface $INT_CODE is disabled from the interfaces registry table.';
g_error_message_02     VARCHAR2(150)  := '<ERROR-02>Unable to read file from $INT_DIR.';
g_error_message_03     VARCHAR2(150)  := '<ERROR-03>Unable to load file $INT_FILE.';
g_debug                VARCHAR2(10)   := 'DEBUG: ';

PROCEDURE process_invoices
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_source            IN  VARCHAR2,
   p_file_name         IN  VARCHAR2,
   p_batch_name        IN  VARCHAR2,
   p_gl_date           IN  VARCHAR2,
   p_control_file      IN  VARCHAR2,
   p_submit_validation IN  VARCHAR2,
   p_debug_flag        IN  VARCHAR2,
   p_int_mode          IN  VARCHAR2,
   p_purge_retention   IN  NUMBER DEFAULT NULL
);

END xxap_invoice_interface_pkg;
/
