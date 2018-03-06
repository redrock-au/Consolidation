CREATE OR REPLACE PACKAGE xxpo_poreq_conv_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.03.01/poc/1.0.0/install/sql/XXPO_POREQ_CONV_PKG.pks 2136 2017-08-17 04:06:27Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: PO.00.03
**
** Description: Conversion program for importing Open Purchase Order Requsitions
**              from DSDBI. 
**
** Change History:
**
** Date        Who                  Comments
** 19/06/2017  sryan                Initial build.
**
*******************************************************************/
-- Interface definition
g_int_code             dot_int_interfaces.int_code%TYPE := 'PO.00.03';
g_int_name             dot_int_interfaces.int_name%TYPE := 'DEDJTR Purchase Order Conversion';
g_int_mode             VARCHAR2(60)   := 'VALIDATE_TRANSFER';
g_src_code             VARCHAR2(25)  := 'XXPOPOCONV';
g_file                 VARCHAR2(150) := '*.csv';
g_ctl                  VARCHAR2(150) := '$POC_TOP/bin/XXPOPOCONV.ctl';
-- Errors and Debug
g_error                VARCHAR2(10)   := 'ERROR: ';
g_error_message_01     VARCHAR2(150)  := '<ERROR-01>Interface $INT_CODE is disabled from the interfaces registry table.';
g_error_message_02     VARCHAR2(150)  := '<ERROR-02>Unable to read file from $INT_DIR.';
g_error_message_03     VARCHAR2(150)  := '<ERROR-03>Unable to load file $INT_FILE.';
g_debug                VARCHAR2(10)   := 'DEBUG: ';

PROCEDURE process_reqs
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

PROCEDURE retry_poreq_wf_approval_cp
(
   p_errbuff            OUT VARCHAR2,
   p_retcode            OUT NUMBER,
   p_item_type          IN  VARCHAR2,
   p_activity           IN  VARCHAR2,
   p_user_id            IN  NUMBER DEFAULT NULL
);

PROCEDURE approve_requisitions_cp
(
   p_errbuff            OUT VARCHAR2,
   p_retcode            OUT NUMBER
);

END xxpo_poreq_conv_pkg;
/
