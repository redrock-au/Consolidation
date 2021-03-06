create or replace PACKAGE BODY XXAR_CHECKDIGIT_UTIL_PKG AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.02/arc/1.0.0/install/sql/XXAR_CHECKDIGIT_UTIL_PKG.pkb 1357 2017-07-02 23:22:03Z svnuser $ */
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


/*---------------------------------------------------------------------------
  Function Name : get_customer_refno
  Purpose       : generate the customer reference number as the concatenated
                  invoice number and the calculated check digit consisting of 8
                  digit. this function will handle up to maximum 7 lenght of
                  invoice.
  Assumptions  : This function assumes that all DOT Invoice Numbers are numeric.
-----------------------------------------------------------------------------*/
FUNCTION get_customer_refno (p_invoice_number  VARCHAR2)
RETURN VARCHAR2
IS

l_crn_length      NUMBER := 8;
l_customer_refno  VARCHAR2(10);
l_check_digit     VARCHAR2(10);


BEGIN

  IF p_invoice_number IS NOT NULL THEN
     l_check_digit := get_cd_mod11_westpac(p_invoice_number);
     l_customer_refno := LPAD(p_invoice_number||TO_CHAR (l_check_digit),l_crn_length,'0');
  END IF;

  RETURN l_customer_refno;

END get_customer_refno;


/*---------------------------------------------------------------------------
  Function Name : get_check_digit - MODULUS 11 -- Using Customer Transacion ID
  Purpose       : same as get_check_digit with p_invoice_number 
                  But we've added this function as per DEDJTR_MD.050_AR.03.01 CRN Generator_V1.1
-----------------------------------------------------------------------------*/

FUNCTION get_check_digit (p_customer_trx_id  NUMBER)
RETURN VARCHAR2
IS

l_check_digit     VARCHAR2(10);

BEGIN

  IF p_customer_trx_id IS NOT NULL THEN
     l_check_digit := get_cd_mod11_westpac(TO_CHAR(p_customer_trx_id));
  END IF;

  RETURN l_check_digit;

END get_check_digit;

/*---------------------------------------------------------------------------
  Function Name : get_check_digit - MODULUS 11
  Purpose       : same logic as get_customer_refno only that it return only the
				  check digit generated.
  Assumptions  : This function assumes that all DOT Invoice Numbers are numeric.
-----------------------------------------------------------------------------*/

FUNCTION get_check_digit (p_invoice_number  VARCHAR2)
RETURN VARCHAR2
IS

l_check_digit     VARCHAR2(10);

BEGIN

  IF p_invoice_number IS NOT NULL THEN
     l_check_digit := get_cd_mod11_westpac(p_invoice_number);
  END IF;

  RETURN l_check_digit;

END get_check_digit;

/*---------------------------------------------------------------------------
  Function Name : get_check_digit_mod97
  Purpose       : return check digit generated from combination of billpay code
                  and invoice number
  Assumptions  : This function assumes that all DOT Invoice Numbers are numeric.
-----------------------------------------------------------------------------*/
FUNCTION get_check_digit_mod97 (p_billpay         IN VARCHAR2
                               ,p_invoice_number  IN VARCHAR2)
RETURN VARCHAR2
IS

l_check_digit  VARCHAR2(10);

BEGIN

  l_check_digit :=  get_cd_mod97_westpac(p_billpay,p_invoice_number);

  RETURN  LPAD(TO_CHAR(l_check_digit),2,'0');

END get_check_digit_mod97;

/*---------------------------------------------------------------------------
  Function Name : get_cd_mod11_westpac
  Purpose       : generate the check digit using modulus11
  Westpac Specs : WESTPAC MOD11V16E
-----------------------------------------------------------------------------*/

FUNCTION get_cd_mod11_westpac(p_invoice_number VARCHAR2)
RETURN VARCHAR2
IS

c_modulus CONSTANT NUMBER := 11;

type weightslist IS varray(8) OF NUMBER;
weights weightslist := weightslist(7,   9,   10,   5,   8,   4,   2);

weightedsum    NUMBER := 0;
l_index        NUMBER := 0;
i              NUMBER;
l_pos          NUMBER := 0;
l_mult         NUMBER := 0;
l_sum          NUMBER := 0;
l_div          NUMBER;
l_remainder    NUMBER := 0;
l_check_digit  NUMBER;
l_final_cd     NUMBER;


l_customer_refno    VARCHAR2(10);
l_invoice           VARCHAR2(10);
l_reversed_invoice  VARCHAR2(10);

BEGIN

 --check the length of the invoice to process
  IF LENGTH(p_invoice_number) < (weights.COUNT)
    THEN
      l_invoice := LPAD(p_invoice_number,(weights.COUNT) , '0');
  ELSE
      l_invoice :=p_invoice_number;
  END IF;

  --DBMS_OUTPUT.PUT_LINE('l_invoice ===>' || l_invoice);
  IF l_invoice IS NOT NULL  THEN


    FOR l_index IN 1 .. weights.COUNT
    LOOP
      i := to_number(SUBSTR(l_invoice,   l_index,   1));
      l_pos := l_pos + 1;
      l_mult := i *weights(l_pos);
      l_sum := l_sum + l_mult;
    END LOOP;


    --total result is summed as calculated, divide total by 11
    l_remainder := MOD(l_sum,   c_modulus);

    --remainder would need to be subtracted from the modulus value to get the check digit
   IF l_remainder != 0 THEN
    l_check_digit := c_modulus -l_remainder;
   ELSE
      l_check_digit := l_remainder ;
   END IF;

    --USING WESTPAC SUFFIX E
    IF l_check_digit = 10 THEN
       l_final_cd := 0;
    ELSIF l_check_digit = 11 THEN
       l_final_cd := 1;
    ELSE
       l_final_cd := l_check_digit;
    END IF;

  END IF;

  RETURN  to_char(l_final_cd);

END get_cd_mod11_westpac;

/*---------------------------------------------------------------------------
  Function Name : get_cd_mod97_westpac
  Purpose       : generate the check digit using modulus97
  Westpac Specs : WESTPAC MOD97V01(W17M971F0)
-----------------------------------------------------------------------------*/
FUNCTION get_cd_mod97_westpac(p_billpay        IN VARCHAR2,
                              p_invoice_number IN VARCHAR2)
RETURN VARCHAR2
IS

c_modulus        CONSTANT NUMBER := 97;
l_check_digit    NUMBER;


TYPE weightslist IS varray(20) OF NUMBER;
--weights weightslist := weightslist(20,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1);
weights weightslist := weightslist(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20);

weightedsum   NUMBER := 0;
l_index       NUMBER := 0;
i             NUMBER;
l_pos         NUMBER := 0;
l_mult        NUMBER := 0;
l_sum         NUMBER := 0;
l_div         NUMBER;
l_remainder   NUMBER := 0;

l_invoice     VARCHAR2(20);
l_reversed_invoice VARCHAR2(20);

BEGIN

  --check the length of the invoice to process
  IF LENGTH(p_invoice_number) <(weights.COUNT) THEN
    l_invoice := lpad(p_invoice_number,  (weights.COUNT),   '0');
  ELSE
    l_invoice := p_invoice_number;
  END IF;

  l_invoice := p_billpay || SUBSTR(l_invoice,   LENGTH(p_billpay) + 1,   LENGTH(l_invoice));
  --DBMS_OUTPUT.PUT_LINE('l_invoice ===>' || l_invoice);


  IF l_invoice IS NOT NULL THEN

    FOR l_index IN 1 .. weights.COUNT
    LOOP
      i := to_number(SUBSTR(l_invoice,   l_index,   1));
      l_pos := l_pos + 1;
      l_mult := i *weights(l_pos);
      l_sum := l_sum + l_mult;
    END LOOP;

    --total result is summed as calculated, divide total by 97
    l_remainder := MOD(l_sum,   c_modulus);

    --3Apr2012 Mel Cruzado
    --set check digit to 97 when remainder is 0
    IF  l_remainder = 0 THEN
        l_check_digit := c_modulus;
    ELSE
        l_check_digit := l_remainder;
    END IF;

  END IF;

  RETURN LPAD(TO_CHAR(l_check_digit),2,'0');
EXCEPTION WHEN OTHERS THEN  -- AR.01.01 added to handle when non numberic CRN is provided
  RETURN NULL;
END get_cd_mod97_westpac;

END XXAR_CHECKDIGIT_UTIL_PKG;
/