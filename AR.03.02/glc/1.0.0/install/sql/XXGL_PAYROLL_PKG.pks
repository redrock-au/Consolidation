create or replace package xxgl_payroll_pkg
as
/* $Header: svn://d02584/consolrepos/branches/AR.03.02/glc/1.0.0/install/sql/XXGL_PAYROLL_PKG.pks 1270 2017-06-27 00:16:38Z svnuser $ */
-- Interface definition
g_int_code             dot_int_interfaces.int_code%TYPE := 'GL.02.01';
g_int_name             dot_int_interfaces.int_name%TYPE := 'DEDJTR CHRIS Payroll Accrual Interface';
g_int_mode             VARCHAR2(60)   := 'VALIDATE_TRANSFER';
g_int_trans_mode       VARCHAR2(60)   := 'TRANSFER';
g_src_code             VARCHAR2(25)  := 'XXCHRPAYAC'; -- 'XXGL_PAY_ACCR_INT';
g_file                 VARCHAR2(150) := 'payroll*.dedjtr*.txt';
g_ctl                  VARCHAR2(150) := '$GLC_TOP/bin/XXGLPAYACCR.ctl';
-- Errors and Debug
g_error                VARCHAR2(10)   := 'ERROR: ';
g_error_message_01     VARCHAR2(150)  := '<ERROR-01>Interface $INT_CODE is disabled from the interfaces registry table.';
g_error_message_02     VARCHAR2(150)  := '<ERROR-02>Unable to read file from $INT_DIR.';
g_error_message_03     VARCHAR2(150)  := '<ERROR-03>Unable to load file $INT_FILE.';
g_debug                VARCHAR2(10)   := 'DEBUG: ';

PROCEDURE process_journal
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_sob_id            IN  NUMBER,
   p_rule_lookup_type  IN  VARCHAR2,
   p_source            IN  VARCHAR2,
   p_file_name         IN  VARCHAR2,
   p_accrual_option    IN  VARCHAR2,
   p_control_file      IN  VARCHAR2,
   p_debug_flag        IN  VARCHAR2,
   p_int_mode          IN  VARCHAR2
);

end xxgl_payroll_pkg;
/