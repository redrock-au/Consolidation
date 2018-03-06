create or replace PACKAGE XXPO_RCV_OAF_UTIL_PKG AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.01/poc/1.0.0/install/sql/XXPO_RCV_OAF_UTIL_PKG.pks 1385 2017-07-03 00:55:13Z svnuser $ */
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
** 26/04/2017  Joy Pinto            Initial build.
**
****************************************************************************/

FUNCTION get_line_type
(
   p_requisition_header_id IN  NUMBER
)
RETURN VARCHAR2;

FUNCTION get_derived_value
(
   p_requisition_line_id IN  NUMBER,
   p_receipt_quantity    IN  NUMBER,
   p_ordered_quantity    IN  NUMBER
)
RETURN NUMBER;

FUNCTION get_primary
(
   p_po_header_id        IN  NUMBER,
   p_invoice_amount    IN  NUMBER
)
RETURN NUMBER;

FUNCTION get_secondary
(
   p_po_header_id        IN  NUMBER,
   p_invoice_amount    IN  NUMBER
)
RETURN NUMBER;

END XXPO_RCV_OAF_UTIL_PKG;
/

