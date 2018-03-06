REM $Header: svn://d02584/consolrepos/branches/AR.02.03/arc/1.0.0/install/sql/XXAR_INVOICES_INTERFACE_TFM_DDL.sql 1451 2017-07-04 23:01:51Z svnuser $

CREATE TABLE fmsmgr.xxar_invoices_interface_tfm
(
   record_id                          NUMBER,
   run_id                             NUMBER,
   run_phase_id                       NUMBER,
   batch_source_name                  VARCHAR2(50),
   description                        VARCHAR2(240),
   trx_number                         VARCHAR2(20),
   trx_date                           DATE,
   gl_date                            DATE,
   line_type                          VARCHAR2(20),
   amount                             NUMBER,
   unit_selling_price                 NUMBER,
   cust_trx_type_name                 VARCHAR2(20),
   cust_trx_type_id                   NUMBER,
   quantity                           NUMBER,
   uom_code                           VARCHAR2(3),
   orig_system_bill_customer_ref      VARCHAR2(240),
   orig_system_bill_address_ref       VARCHAR2(240),
   interface_line_context             VARCHAR2(30),
   interface_line_attribute1          VARCHAR2(30),
   interface_line_attribute2          VARCHAR2(30),
   interface_line_attribute3          VARCHAR2(30),
   primary_salesrep_id                NUMBER,
   printing_option                    VARCHAR2(20),
   term_name                          VARCHAR2(15),
   term_id                            NUMBER,
   conversion_type                    VARCHAR2(30),
   conversion_date                    DATE,
   conversion_rate                    NUMBER,
   currency_code                      VARCHAR2(15),
   tax_code                           VARCHAR2(50),
   set_of_books_id                    NUMBER,
   created_by                         NUMBER,
   creation_date                      DATE,
   last_updated_by                    NUMBER,
   last_update_date                   DATE,
   org_id                             NUMBER,
   header_attribute_category          VARCHAR2(30),
   header_attribute1                  VARCHAR2(150),
   header_attribute2                  VARCHAR2(150),
   header_attribute3                  VARCHAR2(150),
   header_attribute4                  VARCHAR2(150),
   header_attribute5                  VARCHAR2(150),
   header_attribute6                  VARCHAR2(150),
   header_attribute7                  VARCHAR2(150),
   header_attribute8                  VARCHAR2(150),
   header_attribute9                  VARCHAR2(150),
   header_attribute10                 VARCHAR2(150),
   header_attribute11                 VARCHAR2(150),
   header_attribute12                 VARCHAR2(150),
   header_attribute13                 VARCHAR2(150),
   header_attribute14                 VARCHAR2(150),
   header_attribute15                 VARCHAR2(150),
   comments                           VARCHAR2(240),
   purchase_order                     VARCHAR2(50),
   line_number                        NUMBER,
   attribute_category                 VARCHAR2(30),
   attribute1                         VARCHAR2(150),
   attribute2                         VARCHAR2(150),
   attribute3                         VARCHAR2(150),
   attribute4                         VARCHAR2(150),
   attribute5                         VARCHAR2(150),
   attribute6                         VARCHAR2(150),
   attribute7                         VARCHAR2(150),
   attribute8                         VARCHAR2(150),
   attribute9                         VARCHAR2(150),
   attribute10                        VARCHAR2(150),
   attribute11                        VARCHAR2(150),
   attribute12                        VARCHAR2(150),
   attribute13                        VARCHAR2(150),
   attribute14                        VARCHAR2(150),
   attribute15                        VARCHAR2(150),
   distribution_number                NUMBER,
   code_combination_id                NUMBER,
   distribution_amount                NUMBER,
   percent                            NUMBER,
   segment1                           VARCHAR2(25),
   segment2                           VARCHAR2(25),
   segment3                           VARCHAR2(25),
   segment4                           VARCHAR2(25),
   segment5                           VARCHAR2(25),
   segment6                           VARCHAR2(25),
   segment7                           VARCHAR2(25),
   status                             VARCHAR2(60)
);

CREATE SYNONYM xxar_invoices_interface_tfm FOR fmsmgr.xxar_invoices_interface_tfm;
