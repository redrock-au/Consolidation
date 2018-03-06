create or replace PACKAGE xxar_print_invoices_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.00.02/arc/1.0.0/install/sql/XXAR_PRINT_INVOICES_PKG.pks 1496 2017-07-05 07:15:13Z svnuser $ */
/******************************************************************************
**
**
**  This program is a copy of dot_print_invoices_pkg and modified for CEMLI AR.01.01 
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
   --p_installment_num       IN  NUMBER,
   p_open_only             IN  VARCHAR2,
   --p_tax_reg               IN  VARCHAR2,
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


END xxar_print_invoices_pkg;
/