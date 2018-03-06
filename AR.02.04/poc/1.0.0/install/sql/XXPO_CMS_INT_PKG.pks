CREATE OR REPLACE PACKAGE xxpo_cms_int_pkg
AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.04/poc/1.0.0/install/sql/XXPO_CMS_INT_PKG.pks 1154 2017-06-22 23:03:54Z svnuser $*/
/*******************************************************************
**
** CEMLI ID: PO.12.01
**
** Description: Interface program for importing contracts from CMS
**
** Change History:
**
** Date        Who                  Comments
** 12/05/2017  NCHENNURI (RED ROCK) Initial build.
**
*******************************************************************/
-- Interface definition
g_int_code             dot_int_interfaces.int_code%TYPE := 'PO.12.01';
g_int_name             dot_int_interfaces.int_name%TYPE := 'DEDJTR Contract Extract Inbound from CMS';
g_int_mode             VARCHAR2(60)   := 'VALIDATE_TRANSFER';
g_src_code             VARCHAR2(25)  := 'XXPOCMSINT';
g_file                 VARCHAR2(150) := 'DEDJTR_Contract_CMS.txt';
g_ctl                  VARCHAR2(150) := '$POC_TOP/bin/XXPOCMSINT.ctl';
-- Errors and Debug
g_error                VARCHAR2(10)   := 'ERROR: ';
g_error_message_01     VARCHAR2(150)  := '<ERROR-01>Interface $INT_CODE is disabled from the interfaces registry table.';
g_error_message_02     VARCHAR2(150)  := '<ERROR-02>Unable to read file from $INT_DIR.';
g_error_message_03     VARCHAR2(150)  := '<ERROR-03>Unable to load file $INT_FILE.';
g_debug                VARCHAR2(10)   := 'DEBUG: ';

PROCEDURE process_contracts
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_source            IN  VARCHAR2,
   p_file_name         IN  VARCHAR2,
   p_batch_name        IN  VARCHAR2,
   p_control_file      IN  VARCHAR2,
   p_submit_validation IN  VARCHAR2,
   p_debug_flag        IN  VARCHAR2,
   p_int_mode          IN  VARCHAR2
);

END xxpo_cms_int_pkg;
/