/* $ Header $*/
/****************************************************************************
**
** CEMLI ID: AP.03.01
**
** Description:  Adding new column to the type JIRA 3613 to be used by KOFAX used by XXAP_KOFAX_INTEGRATION_PKG
**              
**
** Change History:
**
** Date         Who                  Comments
** 22/08/2017   Joy Pinto            Initial build.
**
****************************************************************************/

ALTER TYPE APPS.xxap_po_header_info_type ADD ATTRIBUTE  (PO_HEADER_ID NUMBER) CASCADE; 