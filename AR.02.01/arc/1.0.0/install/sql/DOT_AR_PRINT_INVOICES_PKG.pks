create or replace PACKAGE dot_ar_print_invoices_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.01/arc/1.0.0/install/sql/DOT_AR_PRINT_INVOICES_PKG.pks 1005 2017-06-20 23:55:31Z svnuser $ */
/******************************************************************************
**
**  Purpose: Enhance existing Invoice Print Selected Invoices customisation
**           (ARCINVBIP.rdf including templates) to address following issues:
**           (1) Report output has excessive in-between spaces before and after the
**               body region because both header and footer objects are all hooked
**               together in a subtemplate.
**           (2) Unable to control report footer (payment options) to display on
**               first page only regardless of page count.
**           (3) Hidden payment option leaves lull spaces make the report look
**               aesthetically poor.
**           (4) Multiple templates combined in one template added layer of complexity
**               for the user. Hence, minor or simple modification of layout requires
**               developer skills.
**           (5) Testing is tedious because all templates were combined in one. Regardless
**               whether only one particular template was modified all transaction types
**               have to be tested to ensure others remain intact.
**           (6) Unable to send output directly to printer.
**           (7) Unable to print in DUPLEX mode (printing front and back of page). No
**               mechanism to send instructions to printer - Print on front page for every
**               transaction (multiple invoices in one PDF file).
**           (8) No capability to email document as attachment.
**
**  Author: Dart Arellano UXC Red Rock Consulting
**
**  $Date: $
**
**  $Revision: $
**
**  Histroy  : Refer to Source Control
**
******************************************************************************/

PROCEDURE dispatch_invoices
(
   p_errbuff               OUT VARCHAR2,
   p_retcode               OUT NUMBER,
   p_order_by              IN  VARCHAR2,
   p_trx_class             IN  VARCHAR2,
   p_cust_trx_type_id      IN  NUMBER,
   p_trx_number_low        IN  VARCHAR2,
   p_trx_number_high       IN  VARCHAR2,
   p_date_low              IN  VARCHAR2,
   p_date_high             IN  VARCHAR2,
   p_customer_class_code   IN  VARCHAR2,
   p_customer_id           IN  NUMBER,
   p_installment_num       IN  NUMBER,
   p_open_only             IN  VARCHAR2,
   p_tax_reg               IN  VARCHAR2,
   p_new_trx_only          IN  VARCHAR2,
   p_batch_id              IN  VARCHAR2,
   p_printer_name          IN  VARCHAR2,
   p_print_command_line    IN  VARCHAR2,
   p_email_function        IN  VARCHAR2
);

PROCEDURE send_to_email
(
   p_errbuff               OUT VARCHAR2,
   p_retcode               OUT NUMBER,
   p_sub_request_id        IN  NUMBER
);

FUNCTION check_invoice_range 
(
   p_start_inv   VARCHAR2,
   p_end_inv     VARCHAR2,
   p_check_inv   VARCHAR2
)
RETURN BOOLEAN;


END dot_ar_print_invoices_pkg;
