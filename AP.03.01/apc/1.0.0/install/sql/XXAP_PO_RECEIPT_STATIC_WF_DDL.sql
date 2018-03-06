/* $Header: svn://d02584/consolrepos/branches/AP.03.01/apc/1.0.0/install/sql/XXAP_PO_RECEIPT_STATIC_WF_DDL.sql 3021 2017-11-21 01:54:56Z dart $ */
/****************************************************************************
**
** CEMLI ID: AP.03.01
**
** Description: Static table used as temporary storage for invoice
**              information.
**
** Change History:
**
** Date         Who             Comments
** 20/11/2017   Dart            Bug fix for FSC-5956
**
****************************************************************************/

CREATE TABLE fmsmgr.xxap_po_receipt_static_wf
(
   invoice_num           VARCHAR2(150),
   po_number             VARCHAR2(150),
   import_date           DATE,
   attachment_url        VARCHAR2(250),
   preparer_id           NUMBER,
   days_old_parameter    NUMBER,
   wf_item_key           VARCHAR2(60),
   created_by            NUMBER,
   creation_date         DATE
);

CREATE OR REPLACE SYNONYM xxap_po_receipt_static_wf FOR fmsmgr.xxap_po_receipt_static_wf;

CREATE INDEX fmsmgr.xxap_po_receipt_static_wf_n1 ON fmsmgr.xxap_po_receipt_static_wf (wf_item_key);
