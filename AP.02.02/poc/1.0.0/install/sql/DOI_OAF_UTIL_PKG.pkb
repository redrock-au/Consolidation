create or replace package body doi_oaf_util_pkg as
/* $Header: svn://d02584/consolrepos/branches/AP.02.02/poc/1.0.0/install/sql/DOI_OAF_UTIL_PKG.pkb 2999 2017-11-17 04:36:48Z svnuser $ */
/* doi_oaf_util_pkg.pkb 1.3 30/01/2015 */

   -- ----------------------------------------------------------------
   -- Procedure : debug
   -- ----------------------------------------------------------------
   procedure debug(
         p_debug_msg  in varchar2,
         p_class_name in varchar2 default null)
   is
      pragma autonomous_transaction;
   begin
      insert into doi_oaf_debug
      (
         debug_id,
         debug_date,
         class_name,
         debug_msg
       )
      values
      (
         doi_oaf_debug_s.nextval,
         sysdate,
         substr(p_class_name,1,500),
         substr(p_debug_msg,1,500)
      );
      commit;
   end;

   -- ----------------------------------------------------------------
   -- Function : get_cms_number
   -- ----------------------------------------------------------------
 /*  function get_cms_number(p_req_header_id in number) return varchar2
   is
      l_cms_number      po_requisition_headers_all.attribute3%type;
   begin
      select attribute3
        into l_cms_number
        from po_requisition_headers_all
       where requisition_header_id = p_req_header_id;

      return l_cms_number;
   exception
      when no_data_found then
         return null;
      when others then
         return sqlerrm;
   end get_cms_number;
   */


   -- ----------------------------------------------------------------
   -- Function : get_cms_number
   -- For PTDA Project - RR Mel Cruzado 01FEB2012
   -- did not change the parameter name so the  doi.oracle.apps.util
   -- call need not to be changed
   -- ----------------------------------------------------------------
   function get_cms_number(p_req_header_id in number) return varchar2
   is
      l_cms_number      po_headers_all.attribute3%type;
   begin
      select attribute3
        into l_cms_number
        from po_headers_all
       where po_header_id = p_req_header_id;

      return l_cms_number;
   exception
      when no_data_found then
         return null;
      when others then
         return sqlerrm;
   end get_cms_number;



/*================================================================
 FUNCTION : is_invoice_num_exist
 For ERS Project - RR Mel Cruzado 30Jan2015
 Validate Unique Invoice Number at Vendor, Vendor Site and Org Id combination
 OAF Function Called in doi.oracle.apps.icx.por.rcv.webui.RcvInfoCO
==================================================================*/
FUNCTION is_invoice_unique (p_po_header_id   IN NUMBER,
                            p_org_id         IN NUMBER,
                            p_vendor_id      IN NUMBER,
                            p_vendor_site_id IN NUMBER,
                            p_invoice_num    IN VARCHAR2
                           )
RETURN VARCHAR2
IS

  l_invoice_ctr  NUMBER :=0;
  l_result       VARCHAR2(240);
  l_error_msg    VARCHAR2(240);

BEGIN

   SELECT count(*)
   INTO   l_invoice_ctr
   FROM   ap_invoices_all
   WHERE  org_id         = p_org_id
   AND    vendor_id      = p_vendor_id
   AND    vendor_site_id = p_vendor_site_id
   AND    invoice_num    = p_invoice_num;

 IF l_invoice_ctr > 0 THEN
   l_error_msg := 'Invoice Number '||p_invoice_num||' already exists for this vendor and vendor site...';
 END IF;

 RETURN l_error_msg;

END is_invoice_unique;


/*================================================================
 FUNCTION : is_invoice_date_valid
 For ERS Project - RR Mel Cruzado 30Jan2015
 Receipting Page : Invoice Date Format Validation
 OAF Function Called in doi.oracle.apps.icx.por.rcv.webui.RcvInfoCO
==================================================================*/
FUNCTION is_invoice_date_valid (p_invoice_date    IN VARCHAR2 )
RETURN VARCHAR2
IS

  l_date_format  VARCHAR2(240);
  l_error_msg    VARCHAR2(240);

BEGIN

 IF  LENGTH(p_invoice_date) < 11 THEN
  l_date_format := 'INVALID';
 ELSE
   SELECT decode(p_invoice_date,to_date(p_invoice_date,'DD-MON-YYYY'),'VALID','INVALID')
   INTO   l_date_format
   FROM   dual;
 END IF;
 IF l_date_format = 'INVALID' THEN
   l_error_msg := 'Invalid date format.';
 END IF;

 RETURN l_error_msg;

END is_invoice_date_valid;


/*================================================================
 FUNCTION : get_po_shipment_info
 For ERS Project - RR Mel Cruzado 30Jan2015
 Used by DoiReceiveItemsTxnVO additional attributes
 OAF Function Called in doi.oracle.apps.util to retrieve calculated values
==================================================================*/
 FUNCTION get_po_shipment_info(p_attribute_name       IN VARCHAR2,
                               p_line_location_id     IN NUMBER,
                               p_receipt_quantity     IN NUMBER
                               )
 RETURN VARCHAR2
 IS

 CURSOR c_po_line_dtls (p_line_location_id  IN NUMBER)
 IS
  SELECT poh.pay_on_code,
         NVL(poll.price_override, pol.unit_price) po_line_unit_price,
         poll.line_location_id,
         DECODE(poll.taxable_flag, 'Y', poll.tax_code_id, NULL) tax_code_id
  FROM   po_headers_all poh ,
         po_lines_all pol ,
         po_line_locations_all poll ,
         po_distributions_all pod
  WHERE poll.line_location_id =  p_line_location_id -- 340658
  AND    poh.po_header_id    = pol.po_header_id
  AND    poh.po_header_id     = pod.po_header_id
  AND    poh.po_header_id     = poll.po_header_id
  AND    pol.po_line_id       = poll.po_line_id
  AND    pod.line_location_id = poll.line_location_id;


   l_po_pay_on_code        po_headers_all.pay_on_code%TYPE;
   l_po_line_unit_price    po_lines_all.unit_price%TYPE;
   l_po_line_tax_name      ap_tax_codes_all.name%TYPE;
   l_po_line_tax_rate      ap_tax_codes_all.tax_rate%TYPE;
   l_line_amt_excl_tax     po_lines_all.unit_price%TYPE;
   l_line_amt_incl_tax     po_lines_all.unit_price%TYPE;

   l_value                 VARCHAR2(240);

 BEGIN

 IF (p_line_location_id IS NOT NULL) THEN

  FOR rec IN c_po_line_dtls (p_line_location_id)
  LOOP
     l_po_pay_on_code      := rec.pay_on_code;
     l_po_line_unit_price  := rec.po_line_unit_price;


    IF rec.tax_code_id IS NOT NULL THEN

      BEGIN
       SELECT  aptax.name po_line_tax_name,
               aptax.tax_rate po_line_tax_rate
       INTO    l_po_line_tax_name,
               l_po_line_tax_rate
       FROM    ap_tax_codes aptax
       WHERE aptax.tax_id = rec.tax_code_id;

       EXCEPTION
         WHEN NO_DATA_FOUND THEN
           l_po_line_tax_name := NULL;
           l_po_line_tax_rate := NULL;
        WHEN OTHERS THEN
           l_po_line_tax_name := NULL;
           l_po_line_tax_rate := NULL;
       END;

    END IF;

    IF  l_po_line_tax_rate > 0 THEN
       l_po_line_tax_rate  := l_po_line_tax_rate/100;
    ELSE
       l_po_line_tax_rate    := l_po_line_tax_rate;
    END IF;

  END LOOP;

  l_line_amt_excl_tax  := l_po_line_unit_price * p_receipt_quantity;
  l_line_amt_incl_tax  := l_line_amt_excl_tax + (l_line_amt_excl_tax * l_po_line_tax_rate);

 END IF;



 IF p_attribute_name = 'PayOnCode' THEN
  -- RETURN l_po_pay_on_code;
  --  l_value := 'This is mel';
   l_value := l_po_pay_on_code;
 ELSIF   p_attribute_name = 'PoLineUnitPrice' THEN
    l_value := l_po_line_unit_price;
 ELSIF   p_attribute_name = 'LineAmtExclTax' THEN
    l_value := l_line_amt_excl_tax;
 ELSIF   p_attribute_name = 'LineAmtInclTax' THEN
    l_value := TO_CHAR(ROUND(l_line_amt_incl_tax, 2));  -- Jira defect FSC-4060
 ELSIF   p_attribute_name = 'PoLineTaxName' THEN
     l_value := l_po_line_tax_name;
 ELSIF   p_attribute_name = 'PoLineTaxRate' THEN
     l_value := l_po_line_tax_rate;
 END IF;

 RETURN l_value;

END get_po_shipment_info;

end doi_oaf_util_pkg;
/
