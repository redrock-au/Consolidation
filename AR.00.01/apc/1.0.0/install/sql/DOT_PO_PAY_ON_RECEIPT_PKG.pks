create or replace PACKAGE dot_po_pay_on_receipt_pkg
AS
/**************************************************************************************
**
**  $Header: svn://d02584/consolrepos/branches/AR.00.01/apc/1.0.0/install/sql/DOT_PO_PAY_ON_RECEIPT_PKG.pks 1492 2017-07-05 07:01:42Z svnuser $
**
**  Purpose: Remediate custom ERS process DOI_PO_ERS_AUTOINVOICE_PKG. Please refer to 
**           notes below for the detailed improvements and fixes. Since none of routines
**           from the old version can be re-used, business agree that overhaul is 
**           necessary.
**
**  Author: Dart Arellano UXC Red Rock Consulting
**
**  Date: 14-July-2015
**
**  History  : Refer to Source Control
**
**************************************************************************************/

/*  Release Notes:
**
** 	New features and fixes	                   Description
** -----------------------------------------   -----------------------------------------------------
** 	1. Use a custom tracking table for Pay     Advantages:
** 	   On Receipt Invoices.                    1. Able to quickly identify new 
**                                                transactions (receive, correct or RTV).
** 	                                           2. Able to summarise receipt line transactions
**                                                to arrive with net value before creating 
**                                                invoice distribution line.
** 	                                           3. Able to accurately validate receipt transactions
**                                                against PO.
**  2. Remove command that truncates the       This is a coding issue from the old version.
**     interface rejection messages.
**  3. Fix and improve data selectivity        Add data grouping at Receipt level instead of
**                                             transaction line level. Fixes the issue with invoice
**                                             distribution item and tax lines doubling up.
**  4. Fix duplicate invoice number issue	     Invoice Number is unique at vendor level by org_id
** 	                                           AP.AP_INVOICES_U2 unique constraint 
** 	                                           (VENDOR_ID, INVOICE_NUM and ORG_ID)
**  5. Cancelled Invoice Exception Handler     Add exception handler for cancelled invoices for 
**                                             receipt correction resulting to Credit Memo.
**  6. Optimise process execution	             1. Remove repeating validations.
** 	                                           2. Tune the SQL queries to speed-up data collection.
** 	                                           3. Remove un-used SQL query that parses tree walking
**                                                (time consuming).
**                                             4. Remove unnecessary calculations:
**                                                * PO Distribution remaining quantity against 
**                                                  receiving transaction (program trying to work
**                                                  out INVOICED to PENDING to validate correction
**                                                  entries)
**                                                * Tax Calculation
**                                                * Multi-currency conversion
**  7. Error Report Persistent Flag	           Include a report flag that can be updated by user 
**                                             using a script. Script will update and remove persistent
**                                             errors from the report.
**  8. Accounting Date	                       Include Accounting Date parameter 
**                                             (default value is system date).
**  9. Payables Open/Close Period Validation   Include accounting date validation against Open/Close
**                                             Period.
** 10. Process History                         Permanently store information of processed ERS receipts
**                                             in a custom table. Useful for exception analysis.
** -----------------------------------------   -----------------------------------------------------
*/

/*
TYPE report_line_rec_type IS RECORD
(
   vendor_number          po_vendors.segment1%TYPE,
   vendor_name            po_vendors.vendor_name%TYPE,
   invoice_number         ap_invoices_all.invoice_num%TYPE,
   invoice_date           DATE,
   invoice_amount         NUMBER,
   distribution_num       NUMBER,
   distribution_amount    NUMBER,
   charge_account         VARCHAR2(240),
   tax_code               VARCHAR2(150),
   po_number              po_headers_all.segment1%TYPE,
   receipt_number         rcv_shipment_headers.receipt_num%TYPE,
   entered_by             fnd_user.user_name%TYPE
);
*/

SUBTYPE report_line_rec_type IS dot_po_pay_on_receipt_report%ROWTYPE;
TYPE report_line_tab_type IS TABLE OF report_line_rec_type INDEX BY binary_integer;

TYPE errors_tab_type IS TABLE OF VARCHAR2(600) INDEX BY binary_integer;

PROCEDURE run_pay_on_receipt
(
   p_errbuf            OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_receipt_num       IN  VARCHAR2,
   p_aging_period      IN  NUMBER,
   p_run_import        IN  VARCHAR2,
   p_validate_batch    IN  VARCHAR2,
   p_gl_date           IN  VARCHAR2
);

PROCEDURE check_invoice_num
(
   p_invoice_num         IN   VARCHAR2,
   p_vendor_id           IN   NUMBER,
   p_adjust_invoice      IN   BOOLEAN,
   p_from_invoice_id     OUT  NUMBER,
   p_approval_status     OUT  VARCHAR2,
   p_count               OUT  NUMBER
);

PROCEDURE create_invoice_interface
(
   p_invoice_num         IN  VARCHAR2,
   p_invoice_date        IN  VARCHAR2,
   p_shipment_header_id  IN  NUMBER,
   p_vendor_id           IN  NUMBER,
   p_vendor_site_id      IN  NUMBER,
   p_adjust_invoice      IN  BOOLEAN,
   p_report_out          OUT report_line_tab_type,
   p_error_out           OUT errors_tab_type,
   p_status              OUT VARCHAR2
);

END dot_po_pay_on_receipt_pkg;
/
