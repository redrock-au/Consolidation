/* $Header: svn://d02584/consolrepos/branches/AR.01.01/fndc/1.0.0/install/sql/DOT_AP_INVOICES_DW_DDL.sql 2949 2017-11-13 01:09:55Z svnuser $ */

-- Create table
CREATE TABLE APPSSQL.DOT_AP_INVOICES_DW
(
   set_of_books_id           NUMBER(15),
   vendor_name               VARCHAR2(240),
   vendor_id                 NUMBER,
   vendor_number             VARCHAR2(30),
   vendor_site_code          VARCHAR2(15),
   vendor_site_id            NUMBER,
   ap_batch_name             VARCHAR2(50),
   invoice_id                NUMBER(15),
   invoice_num               VARCHAR2(50),
   invoice_date              DATE,
   invoice_type              VARCHAR2(25),
   invoice_amount            NUMBER,
   amount_remaining          NUMBER,
   due_date                  DATE,
   cancelled_date            DATE,
   gl_date                   DATE,
   gl_period                 VARCHAR2(15),
   paid                      VARCHAR2(80),
   aging                     NUMBER,
   invoice_description       VARCHAR2(240),
   corporate_card_flag       VARCHAR2(1),
   expense_employee_id       NUMBER,
   expense_report_line_type  VARCHAR2(11),
   expense_justification     VARCHAR2(240),
   expense_merchant_name     VARCHAR2(80),
   vat_code                  VARCHAR2(15),
   invoice_distribution_id   NUMBER(15),
   distribution_line_number  NUMBER(15),
   line_type_lookup_code     VARCHAR2(25),
   amount                    NUMBER,
   distribution_description  VARCHAR2(240),
   invoice_price_variance    NUMBER,
   po_distribution_id        NUMBER(15),
   dist_code_combination_id  NUMBER(15),
   accounting_entity         VARCHAR2(25),
   accounting_account        VARCHAR2(25),
   accounting_cost_centre    VARCHAR2(25),
   accounting_authority      VARCHAR2(25),
   accounting_project        VARCHAR2(25),
   accounting_output         VARCHAR2(25),
   accounting_identifier     VARCHAR2(25),
   creation_date             DATE NOT NULL,
   header_last_update_date   DATE NOT NULL,
   dist_last_update_date     DATE NOT NULL,
   ae_line_type_code         VARCHAR2(30),
   ae_line_number            NUMBER,
   ae_line_type_description  VARCHAR2(80),
   gl_batch_name             VARCHAR2(100),
   je_header_id              NUMBER(15),
   user_je_source_name       VARCHAR2(25),
   user_je_category_name     VARCHAR2(25),
   actual_flag               VARCHAR2(1),
   je_line_num               NUMBER(15),
   document_url              VARCHAR2(600)
)
TABLESPACE LOCDAT;

ALTER TABLE APPSSQL.DOT_AP_INVOICES_DW STORAGE(MAXEXTENTS UNLIMITED);

-- Create/Recreate indexes 
CREATE INDEX FMSMGR.DOT_AP_INVOICES_DW_N1 ON APPSSQL.DOT_AP_INVOICES_DW (INVOICE_ID)
TABLESPACE LOCIDX;

CREATE INDEX FMSMGR.DOT_AP_INVOICES_DW_N2 ON APPSSQL.DOT_AP_INVOICES_DW (SET_OF_BOOKS_ID, GL_PERIOD)
TABLESPACE LOCIDX;

