/* $Header: svn://d02584/consolrepos/branches/AR.00.01/apc/1.0.0/install/sql/XXAP_INV_IMPORT_CREATES_TYPES_DDL.sql 2401 2017-09-04 00:46:57Z svnuser $ */
/****************************************************************************
**
** CEMLI ID: AP.03.01
**
** Description: Types to be used by KOFAX used by XXAP_KOFAX_INTEGRATION_PKG
**              
**
** Change History:
**
** Date         Who                  Comments
** 20/06/2017   Joy Pinto            Initial build.
**
****************************************************************************/

CREATE TYPE APPS.xxap_po_header_info_type AS OBJECT
  (
    po_org_id             NUMBER,
    po_description        VARCHAR2(240),
    requestor_email       VARCHAR2(240),
    preparer_email        VARCHAR2(240),
    buyer_email           VARCHAR2(240),
    po_outstanding_amount NUMBER,
    vendor_site_code      VARCHAR2(15),
    vendor_number         VARCHAR2(30),
    vendor_name           VARCHAR2(240),
    vendor_name_alt       VARCHAR2(320),
    org_short_name        VARCHAR2(150),
    closed_code           VARCHAR2(25),
    attribute_category    VARCHAR2(150),
    attribute1            VARCHAR2(150),
    attribute2            VARCHAR2(150),
    attribute3            VARCHAR2(150),
    attribute4            VARCHAR2(150),
    attribute5            VARCHAR2(150),
    attribute6            VARCHAR2(150),
    attribute7            VARCHAR2(150),
    attribute8            VARCHAR2(150),
    attribute9            VARCHAR2(150),
    attribute10           VARCHAR2(150),
    attribute11           VARCHAR2(150),
    attribute12           VARCHAR2(150),
    attribute13           VARCHAR2(150),
    attribute14           VARCHAR2(150),
    attribute15           VARCHAR2(150)
  );
/  

CREATE TYPE APPS.XXAP_PO_HEADER_INFO_TAB AS TABLE OF XXAP_PO_HEADER_INFO_TYPE;
/
