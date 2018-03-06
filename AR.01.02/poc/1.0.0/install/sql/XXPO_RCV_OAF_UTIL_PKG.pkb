create or replace PACKAGE BODY XXPO_RCV_OAF_UTIL_PKG AS
/* $Header: svn://d02584/consolrepos/branches/AR.01.02/poc/1.0.0/install/sql/XXPO_RCV_OAF_UTIL_PKG.pkb 1274 2017-06-27 01:12:13Z svnuser $*/

/****************************************************************************
**
** CEMLI ID: PO.04.02
**
** Description: Package to handle all receiving related OAF Package calls
**              
**
** Change History:
**
** Date        Who                  Comments
** 26/04/2017   Joy Pinto   Initial build.
**
****************************************************************************/

-------------------------------------------------------
-- FUNCTION
--     GET_LINE_TYPE
-- Purpose
--     Derives the Purchase Order Line Type for a given requisition header Id
--     This function is called from the controller doi.oracle.apps.icx.por.rcv.webui.RcvSrchCOEx
-------------------------------------------------------

FUNCTION get_line_type
(
   p_requisition_header_id   NUMBER
)
RETURN VARCHAR2
IS
   CURSOR c_get_line_type IS
      SELECT INITCAP(CASE WHEN UPPER(plt.purchase_basis) = 'SERVICES' THEN 'Amount' ELSE 'Quantity' END) matching_basis
      FROM   po_line_types plt,
             po_lines_all pla,
             po_line_locations_all plla,
             po_requisition_lines_all prla,
             po_requisition_headers_all prha
      WHERE  plt.line_type_id = pla.line_type_id 
      AND    pla.po_line_id = plla.po_line_id
      AND    plla.LINE_LOCATION_ID = prla.line_location_id
      AND    prla.requisition_header_id = prha.requisition_header_id
      AND    prha.requisition_header_id = p_requisition_header_id;

   l_matching_basis             po_line_types.matching_basis%type;

BEGIN
   -- Derive Line Type
   OPEN  c_get_line_type;
   FETCH c_get_line_type INTO l_matching_basis;
   CLOSE c_get_line_type;
     
   RETURN nvl(l_matching_basis,'Amount');

EXCEPTION
   WHEN OTHERS THEN
      RETURN 'Amount';

END get_line_type;

-------------------------------------------------------
-- FUNCTION
--     GET_DERIVED_VALUE
-- Purpose
--     If the line type is Amount the function derives the Quantity If the line type is Quantity it derives the Amount
--     This function is called from the controller doi.oracle.apps.icx.por.rcv.webui.RcvSrchCOEx
-------------------------------------------------------

FUNCTION get_derived_value
(
   p_requisition_line_id IN  NUMBER,
   p_receipt_quantity    IN  NUMBER,
   p_ordered_quantity    IN  NUMBER
)
RETURN NUMBER
IS
   CURSOR c_derived_value IS
      SELECT INITCAP(CASE WHEN UPPER(plt.purchase_basis) = 'SERVICES' THEN round(p_receipt_quantity/p_ordered_quantity,2) ELSE round(p_receipt_quantity*prla.unit_price,2) END) derived_value
      FROM   po_line_types plt,
             po_lines_all pla,
             po_line_locations_all plla,
             po_requisition_lines_all prla
      WHERE  plt.line_type_id = pla.line_type_id 
      AND    pla.po_line_id = plla.po_line_id
      AND    plla.line_location_id = prla.line_location_id
      AND    prla.requisition_line_id = p_requisition_line_id;

   l_derived_value         NUMBER;

BEGIN
   -- Derive Line Type
   OPEN  c_derived_value;
   FETCH c_derived_value INTO l_derived_value;
   CLOSE c_derived_value;
     
   RETURN nvl(l_derived_value,0);

EXCEPTION
   WHEN OTHERS THEN
      RETURN 0;

END get_derived_value;


-------------------------------------------------------
-- FUNCTION
--     GET_PRIMARY
-- Purpose
--     If the line type is Amount then function returns Invoice Amount 
--     If the line type is Quantity then function returns UnReceipted Qty
--     This function is called from the Invoice Lov doi.oracle.apps.icx.por.rcv.server.doiInvAttachmentListVO
-------------------------------------------------------

FUNCTION get_primary
(
   p_po_header_id        IN  NUMBER,
   p_invoice_amount    IN  NUMBER
)
RETURN NUMBER
IS
   CURSOR c_get_line_type IS
      SELECT INITCAP(CASE WHEN UPPER(plt.purchase_basis) = 'SERVICES' THEN 'Amount' ELSE 'Quantity' END) matching_basis
      FROM   po_line_types plt,
             po_lines_all pla
      WHERE  plt.line_type_id = pla.line_type_id 
      AND    pla.po_header_id = p_po_header_id;
      
   CURSOR c_get_primary IS
      SELECT round(p_invoice_amount/prla.unit_price,2) primary_value
      FROM   po_requisition_lines_all prla,
             po_lines_all pla,
             po_line_locations_all plla
      WHERE  pla.po_line_id = plla.po_line_id
      AND    plla.line_location_id = prla.line_location_id
      AND    pla.po_header_id = p_po_header_id;     

   l_matching_basis             po_line_types.matching_basis%type;
   l_primary_value              NUMBER;

BEGIN
   -- Derive Line Type
   OPEN  c_get_line_type;
   FETCH c_get_line_type INTO l_matching_basis;
   CLOSE c_get_line_type;
     
   IF nvl(l_matching_basis,'Amount') = 'Amount' THEN
      return p_invoice_amount;
   ELSE
      -- Derive value
      OPEN  c_get_primary;
      FETCH c_get_primary INTO l_primary_value;
      CLOSE c_get_primary;   
      RETURN l_primary_value;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      RETURN 0;

END get_primary;

-------------------------------------------------------
-- FUNCTION
--     GET_SECONDARY
-- Purpose
--     If the line type is Amount then function returns UnReceipted Qty
--     If the line type is Quantity then function returns Invoice Amount 
--     This function is called from the Invoice Lov doi.oracle.apps.icx.por.rcv.server.doiInvAttachmentListVO
-------------------------------------------------------

FUNCTION get_secondary
(
   p_po_header_id        IN  NUMBER,
   p_invoice_amount    IN  NUMBER
)
RETURN NUMBER
IS
   CURSOR c_get_line_type IS
      SELECT INITCAP(CASE WHEN UPPER(plt.purchase_basis) = 'SERVICES' THEN 'Amount' ELSE 'Quantity' END) matching_basis
      FROM   po_line_types plt,
             po_lines_all pla
      WHERE  plt.line_type_id = pla.line_type_id 
      AND    pla.po_header_id = p_po_header_id;
      
   CURSOR c_get_secondary_amt IS
      SELECT --sum(POD.AMOUNT_ORDERED - NVL(POD.AMOUNT_CANCELLED, 0) - NVL(POD.AMOUNT_DELIVERED, 0))/sum(nvl(POD.AMOUNT_ORDERED,0) - NVL(POD.AMOUNT_CANCELLED, 0)) secondary_value
             round(p_invoice_amount/sum(nvl(POD.quantity_ordered,0) - NVL(POD.quantity_cancelled,0)),2) secondary_value
      FROM   po_requisition_lines_all prla,
             po_lines_all pla,
             po_line_locations_all plla,
             po_distributions_all pod
      WHERE  pla.po_line_id = plla.po_line_id
      AND    plla.line_location_id = prla.line_location_id
      AND    pod.po_header_id = pla.po_header_id
      AND    pla.po_header_id = p_po_header_id;     
      
   /*CURSOR c_get_qty IS      
      SELECT nvl((nvl(prla.quantity,0) - nvl(prla.quantity_cancelled, 0) - nvl(prla.quantity_delivered, 0))*prla.unit_price,0) secondary_value
      FROM   po_requisition_lines_all prla,
             po_lines_all pla,
             po_line_locations_all plla
      WHERE  pla.po_line_id = plla.po_line_id
      AND    plla.line_location_id = prla.line_location_id
      AND    pla.po_header_id = p_po_header_id;  */       

   l_matching_basis             po_line_types.matching_basis%type;
   l_secondary_value              NUMBER;

BEGIN
   -- Derive Line Type
   OPEN  c_get_line_type;
   FETCH c_get_line_type INTO l_matching_basis;
   CLOSE c_get_line_type;
     
   IF nvl(l_matching_basis,'Amount') = 'Amount' THEN
   
      OPEN   c_get_secondary_amt;
      FETCH  c_get_secondary_amt INTO l_secondary_value;
      CLOSE  c_get_secondary_amt;   
      
      RETURN l_secondary_value;
      
   ELSE
      RETURN p_invoice_amount;  
     /*
      OPEN   c_get_qty;
      FETCH  c_get_qty INTO l_secondary_value;
      CLOSE  c_get_qty;  
      */
      
      RETURN round(l_secondary_value,2);      

   END IF;

EXCEPTION
   WHEN OTHERS THEN
      RETURN 0;

END get_secondary;

END XXPO_RCV_OAF_UTIL_PKG;
/

