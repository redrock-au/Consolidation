REM $Header: svn://d02584/consolrepos/branches/AR.00.01/arc/1.0.0/install/sql/XXAR_INVOICES_INTERFACE_STG_DDL.sql 1492 2017-07-05 07:01:42Z svnuser $

CREATE TABLE fmsmgr.xxar_invoices_interface_stg
(
   record_id                 NUMBER,
   run_id                    NUMBER,
   run_phase_id              NUMBER,
   customer_number           VARCHAR2(150),
   customer_site_number      VARCHAR2(150),
   transaction_type_name     VARCHAR2(150),
   trx_number                VARCHAR2(150),
   trx_date                  VARCHAR2(150),
   term_name                 VARCHAR2(150),
   comments                  VARCHAR2(500),
   po_number                 VARCHAR2(150),
   invoice_line_number       VARCHAR2(150),
   description               VARCHAR2(500),
   quantity                  VARCHAR2(150),
   unit_selling_price        VARCHAR2(150),
   amount                    VARCHAR2(150),
   tax_code                  VARCHAR2(150),
   distribution_line_number  VARCHAR2(150),
   distribution_amount       VARCHAR2(150),
   charge_code               VARCHAR2(150),
   header_attribute_context  VARCHAR2(150),
   customer_contact          VARCHAR2(500),    -- mapped to header_attribute1
   customer_email            VARCHAR2(500),    -- mapped to header_attribute8
   internal_contact_name     VARCHAR2(500),    -- mapped to header_attribute2
   line_attribute_context    VARCHAR2(500),
   period_service_from_date  VARCHAR2(150),    -- mapped to attribute14
   period_service_to_date    VARCHAR2(150),    -- mapped to attribute15
   status                    VARCHAR2(60),
   created_by                NUMBER,
   creation_date             DATE,
   last_updated_by           NUMBER,
   last_update_date          DATE
);

CREATE SYNONYM xxar_invoices_interface_stg FOR fmsmgr.xxar_invoices_interface_stg;
