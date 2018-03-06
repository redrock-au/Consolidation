create or replace PACKAGE XXAR_CHECKDIGIT_UTIL_PKG AS
/* $Header: svn://d02584/consolrepos/branches/AP.03.01/arc/1.0.0/install/sql/XXAR_CHECKDIGIT_UTIL_PKG.pks 1285 2017-06-27 01:36:28Z svnuser $ */
/******************************************************************************
**
**
**  This program is a copy of DOT_CHECKDIGIT_UTIL_PKG and modified for CEMLI AR.01.01 
**  comments and history is not removed to understand what changes were made earlier
**  Purse: This program has been created to address the requirements of AR.01.01 
**
**  $Date: $
**
**  $Revision: $
**
**  Histroy  : Refer to Source Control
**    Date          Author                  Description
**    -----------   --------------------    ---------------------------------------------------
**    20-Jun-2017   Rao Chennuri (Red Rock) Modified above mentioned package as per the requirements.
**
******************************************************************************/

FUNCTION get_customer_refno (p_invoice_number  VARCHAR2)
RETURN VARCHAR2;

--Added on 15-JUN-2017
FUNCTION get_check_digit (p_customer_trx_id  NUMBER)
RETURN VARCHAR2;

FUNCTION get_check_digit (p_invoice_number  VARCHAR2)
RETURN VARCHAR2;

FUNCTION get_check_digit_mod97 (p_billpay         IN VARCHAR2
                               ,p_invoice_number  IN VARCHAR2)
RETURN VARCHAR2;

FUNCTION get_cd_mod11_westpac(p_invoice_number VARCHAR2)
RETURN VARCHAR2;

FUNCTION get_cd_mod97_westpac (p_billpay         IN VARCHAR2
                             ,p_invoice_number  IN VARCHAR2)
RETURN VARCHAR2;

END XXAR_CHECKDIGIT_UTIL_PKG;
/