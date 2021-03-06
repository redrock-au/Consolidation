CREATE OR REPLACE PACKAGE xxap_payment_out_int_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.02.03/apc/1.0.0/install/sql/XXAP_PAYMENT_OUT_INT_PKG.pks 257 2017-05-02 01:59:52Z sryan $ */
/*******************************************************************
**
** CEMLI ID: AP.02.03
**
** Description: Interface program for Payment Outbound Interface 
**
** Change History:
**
** Date        Who                  Comments
** 02/05/2017  SRYAN (RED ROCK)     Initial build.
**
*******************************************************************/
g_error                VARCHAR2(10)   := 'ERROR: ';
g_debug                VARCHAR2(10)   := 'DEBUG: ';

PROCEDURE extract_payments
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_source            IN  VARCHAR2,
   p_file_name         IN  VARCHAR2 DEFAULT NULL,
   p_selection_code    IN  VARCHAR2,
   p_since_date        IN  VARCHAR2 DEFAULT NULL,
   p_debug_flag        IN  VARCHAR2
);
END xxap_payment_out_int_pkg;
/

