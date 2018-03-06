CREATE OR REPLACE PACKAGE XXAP_KOFAX_INTEGRATION_PKG AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.03/apc/1.0.0/install/sql/XXAP_KOFAX_INTEGRATION_PKG.pks 2246 2017-08-22 07:34:56Z svnuser $ */
/****************************************************************************
**
** CEMLI ID: AP.03.01
**
** Description: Package to handle the online validations from Kofax
**              
**
** Change History:
**
** Date         Who                  Comments
** 06/06/2017   Joy Pinto            Initial build.
**
****************************************************************************/

FUNCTION get_dup_ap_inv(
    p_invoice_num       IN VARCHAR2,
    p_vendor_number     IN VARCHAR2,
    p_vendor_site_code  IN VARCHAR2,
    p_org_id            IN NUMBER) 
RETURN VARCHAR2;

FUNCTION get_possible_dup_ap_inv(
    p_invoice_date      IN DATE,
    p_invoice_amount    IN NUMBER,
    p_vendor_number     IN VARCHAR2,
    p_vendor_site_code  IN VARCHAR2,
    p_org_id            IN NUMBER) 
RETURN VARCHAR2;

FUNCTION deactivate_invoice(
   p_document_id        IN NUMBER)
RETURN VARCHAR2;   

FUNCTION get_po_header_info(
    p_po_number IN VARCHAR2,
    p_org_id    IN NUMBER) 
RETURN xxap_po_header_info_tab PIPELINED;
  
   
END XXAP_KOFAX_INTEGRATION_PKG;
/

