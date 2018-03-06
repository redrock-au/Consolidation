create or replace PACKAGE xxar_open_invoices_conv_pkg AS
/*$Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/sql/XXAR_OPEN_INVOICES_CONV_PKG.pks 2443 2017-09-06 00:29:43Z svnuser $*/
/****************************************************************************
**
** CEMLI ID: AR.00.02
**
** Description: This program is for conversion of Open AR Invoices
**              
**
** Change History:
**
** Date        Who                  Comments
** 20/05/2017  KWONDA (RED ROCK)   Initial build.
**
****************************************************************************/

-- Messages --
g_error_message_01     VARCHAR2(150)  := '<ERROR-01>Interface $INT_CODE is disabled from the interfaces registry table.';
g_error_message_02     VARCHAR2(150)  := '<ERROR-02>Unable to read file from $INT_DIR.';
g_error_message_03     VARCHAR2(150)  := '<ERROR-03>Unable to load file $INT_FILE.';
g_error_message_04     VARCHAR2(150)  := '<ERROR-04>Encountered a problem during STAGE phase.';
g_error_message_05     VARCHAR2(150)  := '<ERROR-05>Encountered a problem during TRANSFORM phase.';
g_error_message_06     VARCHAR2(150)  := '<ERROR-06>Encountered a problem during LOAD phase.';
g_error_message_07     VARCHAR2(150)  := '<ERROR-07>Transaction Date ($TRX_DATE) is not a valid date.';
g_error_message_08     VARCHAR2(150)  := '<ERROR-08>Transaction Number $TRX_NUMBER length is more than 20 characters.';
g_error_message_09     VARCHAR2(150)  := '<ERROR-09>Site Number $CUSTOMER_SITE_NUMBER is not found.';
g_error_message_10     VARCHAR2(150)  := '<ERROR-10>Site Number $CUSTOMER_SITE_NUMBER for customer $CUSTOMER_NUMBER is not found.';
g_error_message_11     VARCHAR2(150)  := '<ERROR-11>Transaction type ($TRANSACTION_TYPE_NAME) is not a valid.';
g_error_message_12     VARCHAR2(150)  := '<ERROR-12>Payment Term ($TERM_NAME) is not valid.';
g_error_message_13     VARCHAR2(150)  := '<ERROR-13>Invoice Line Number $INVOICE_LINE_NUMBER is not valid.';
g_error_message_14     VARCHAR2(150)  := '<ERROR-14>Column $COLUMN_NAME must not be null.';
g_error_message_15     VARCHAR2(150)  := '<ERROR-15>Line quantity ($QUANTITY) is not valid.';
g_error_message_16     VARCHAR2(150)  := '<ERROR-16>Line unit selling price ($UNIT_SELLING_PRICE) is not valid.';
g_error_message_17     VARCHAR2(150)  := '<ERROR-17>Unit selling price multiplied by quantity ($AMOUNT) is not equal to line amount.';
g_error_message_18     VARCHAR2(150)  := '<ERROR-18>Line amount ($AMOUNT) is not valid.';
g_error_message_19     VARCHAR2(150)  := '<ERROR-19>Tax code ($TAX_CODE) not in AR tax table.';
g_error_message_20     VARCHAR2(150)  := '<ERROR-20>Distribution Line Number ($DISTRIBUTION_LINE_NUMBER) is not valid.';
g_error_message_21     VARCHAR2(150)  := '<ERROR-21>Distribution amount ($DISTRIBUTION_AMOUNT) is not valid.';
g_error_message_22     VARCHAR2(150)  := '<ERROR-22>Period of Service: From Date ($PERIOD_SERVICE_FROM_DATE) is not valid.';
g_error_message_23     VARCHAR2(150)  := '<ERROR-23>Period of Service: To Date ($PERIOD_SERVICE_TO_DATE) is not valid.';
g_error_message_24     VARCHAR2(150)  := '<ERROR-24>Trx Number ($TRX_NUMBER) already exists.';
g_error_message_25     VARCHAR2(150)  := '<ERROR-25>Duplicate transaction line within the file.';
g_error_message_26     VARCHAR2(150)  := '<ERROR-26>Found more than one customer_site_number for this transaction.';
g_error_message_27     VARCHAR2(150)  := '<ERROR-27>Found more than one trx_date for this transaction.';
g_error_message_28     VARCHAR2(150)  := '<ERROR-28>Found more than one transaction_type_name for this transaction.';
g_error_message_29     VARCHAR2(150)  := '<ERROR-29>Total transaction amount is negative.';
g_error_message_30     VARCHAR2(150)  := '<ERROR-30>GL Date $GL_DATE is not in an open period.';
g_error_message_31     VARCHAR2(150)  := '<ERROR-31>Invoice line amount is not equal to total distribution amount';
g_error_message_32     VARCHAR2(150)  := '<ERROR-32>Error encountered during execution of Autoinvoice program.';
g_error_message_33     VARCHAR2(150)  := '<ERROR-33>Batch Source revenue allocation must be set to AMOUNT.';
g_error_message_34     VARCHAR2(150)  := '<ERROR-34>Copy file to the outbound directory failed.';
g_error_message_35     VARCHAR2(150)  := '<ERROR-35>Found discrepancy on amount value for this line.';
g_error_message_36     VARCHAR2(150)  := '<ERROR-36>Batch Source type must be IMPORTED.';
g_error_message_37     VARCHAR2(150)  := '<ERROR-37>Batch Source is not valid.';
g_error_message_38     VARCHAR2(150)  := '<ERROR-38>Unable to derive chart of accounts code.';
g_error_message_39     VARCHAR2(150)  := '<ERROR-39>The Charge Code $CHARGE_CODE is not mapped properly';
g_error_message_40     VARCHAR2(150)  := '<ERROR-40>The Customer Number $CUSTOMER_NUM is not mapped properly';
g_error_message_41     VARCHAR2(150)  := '<ERROR-41>The Customer Site Number $CUSTOMER_SITE_NUM is not mapped properly';
g_error_message_42     VARCHAR2(150)  := '<ERROR-42>The Tax Code $TAX_CODE is Invalid';
g_error_message_43     VARCHAR2(150)  := '<ERROR-43>Unable to derive orig_sys_bill_customer_ref from Customer Number $CUSTOMER_NUM ';
g_error_message_44     VARCHAR2(150)  := '<ERROR-44>Unable to derive orig_sys_sold_customer_ref from Customer Number $CUSTOMER_NUM ';
g_error_message_45     VARCHAR2(240)  := '<ERROR-45>Unable to derive orig_sys_bill_address_ref from Customer Number $CUSTOMER_NUM and Customer Site Number $CUSTOMER_SITE_NUMBER ';
g_error_message_46     VARCHAR2(240)  := '<ERROR-46>Missing tax code on the line';
g_error_message_47     VARCHAR2(240)  := '<ERROR-47>Invalid value for due Date';
g_error_message_48     VARCHAR2(240)  := '<ERROR-48>Invalid value $INVALID_VALUE for $COLUMN_NAME';
g_error_message_49     VARCHAR2(240)  := '<ERROR-49>Cannot get remit to address for Customer Number $CUSTOMER_NUM';
g_error_message_99     VARCHAR2(150)  := '<ERROR-99>Rejected by Autoinvoice program.';
/*
g_error_message_00     VARCHAR2(150)  := '<ERROR-00>Found discrepancy between TFM record count and data load count. ' ||
                                         'Please check the interface error table for details. ' ||
                                         'Error must be handled from transformation phase to achieve "all-or-nothing" interface run.';
*/


PROCEDURE run_import
(
   p_errbuff            OUT  VARCHAR2,
   p_retcode            OUT  NUMBER,
   p_source             IN   VARCHAR2,
   p_file_name          IN   VARCHAR2,
   p_control_file       IN   VARCHAR2,
   p_gl_date            IN   VARCHAR2,
   p_debug_flag         IN   VARCHAR2,
   p_int_mode           IN   VARCHAR2
);

PROCEDURE initialize
(
   p_file               IN VARCHAR2,
   p_run_id             IN OUT NUMBER,
   p_run_stage_id       IN OUT NUMBER,
   p_run_transform_id   IN OUT NUMBER,
   p_run_load_id        IN OUT NUMBER
);

FUNCTION stage
(
   p_run_id         IN  NUMBER,
   p_run_phase_id   IN  NUMBER,
   p_source         IN  VARCHAR2,
   p_file           IN  VARCHAR2,
   p_ctl            IN  VARCHAR2,
   p_file_error     OUT VARCHAR2
)
RETURN BOOLEAN;

FUNCTION transform
(
   p_run_id         IN  NUMBER,
   p_run_phase_id   IN  NUMBER,
   p_source         IN  VARCHAR2,
   p_file           IN  VARCHAR2,
   p_stage_phase    IN  BOOLEAN
)
RETURN BOOLEAN;

FUNCTION load
(
   p_run_id            IN  NUMBER,
   p_run_phase_id      IN  NUMBER,
   p_file              IN  VARCHAR2,
   p_transform_phase   IN  BOOLEAN,
   p_request_id        OUT NUMBER
)
RETURN BOOLEAN;

END xxar_open_invoices_conv_pkg;
/