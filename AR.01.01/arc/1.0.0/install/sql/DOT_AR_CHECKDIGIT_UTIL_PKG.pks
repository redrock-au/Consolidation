create or replace PACKAGE DOT_AR_CHECKDIGIT_UTIL_PKG AS
/* $Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/sql/DOT_AR_CHECKDIGIT_UTIL_PKG.pks 1192 2017-06-23 03:37:19Z sryan $ */
/****************************************************************************
 ***
 ** Package     : DOT_AR_CHECKDIGIT_UTIL_PKG
 **
 ** File        : dot_ar_checkdigit_util_pkg.pks
 **
 ** Purpose     : To be used by all DOT Invoice Printing Reports to generate
 **               check digit for all DOT invoices and produce the customer reference
 **               number required in the invoice print.
 ** Assumptions : This package assumes that all DOT Invoice Numbers are numeric.
 **
 ** Modification History:
 **   Version     When       Who                 What
 **   ---------  ----------  ---------------   ---------------------------------
 **   1.0        29-NOV-11   Mel Cruzado (RR)  Original Development
 **   1.1        11-JAN-12   Mel Cruzado (RR)  Added get_check_digit function
 **   1.2        12-JAN-12   Mel Cruzado (RR)  Added get_check_digit_mod97 function
 **                                            provision for Australia Post Check Digit
 **                                            requirement - based on sample by
 **                                            Daniel Slusarek (Westpac)
 **   1.3        19-JAN-12   Mel Cruzado (RR)  Added get_cd_mod11_westpac to
 **                                            Use Westpac MOD11V16E Check Digit Specs for
 **                                            MODULUS 11
 **   1.4        27-JAN-12   Mel Cruzado (RR)  Added get_cd_mod97_westpac to
 **                                            Use Westpac MOD97V01(W17M971F0)
 **                                            Check Digit Specs for
 **                                            MODULUS 97
 **
 ** MOD11V16(E) - WHERE SUFFIX E DENOTES HOW TO TREAT CHECK DIGITS OF 10 AND 11
 **               10 AUTHID CURRENT_USER IS RETURNED AS 0 ;  11 IS RETURNED AS 1
 *****************************************************************************/

FUNCTION get_customer_refno (p_invoice_number  VARCHAR2)
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

END DOT_AR_CHECKDIGIT_UTIL_PKG;
