/*$Header: svn://d02584/consolrepos/branches/AP.03.01/arc/1.0.0/install/sql/XXAR_OPEN_INVOICES_CONV_STG_DDL.sql 1818 2017-07-18 00:17:32Z svnuser $*/

  CREATE TABLE FMSMGR.XXAR_OPEN_INVOICES_CONV_STG 
   (	RECORD_ID NUMBER, 
	RUN_ID NUMBER, 
	RUN_PHASE_ID NUMBER, 
	DSDBI_CUSTOMER_NAME VARCHAR2(500), 
	DSDBI_CUSTOMER_NUMBER VARCHAR2(500), 
	DSDBI_CUSTOMER_SITE_NUMBER VARCHAR2(500), 
	ORACLE_TRX_TYPE VARCHAR2(500), 
	DSDBI_TRX_NUMBER VARCHAR2(500), 
	TRX_DATE VARCHAR2(500), 
	INV_AMOUNT VARCHAR2(500), 
	DSDBI_CRN VARCHAR2(500), 
	TERM_NAME VARCHAR2(500), 
	DUE_DATE VARCHAR2(500), 
	COMMENTS VARCHAR2(500), 
	PO_NUMBER VARCHAR2(500), 
	CUSTOMER_CONTACT_NAME VARCHAR2(500), 
	INVOICE_EMAIL VARCHAR2(500), 
	INTERNAL_CONTACT_NAME VARCHAR2(500), 
	LINE_NUMBER VARCHAR2(500), 
	LINE_TYPE VARCHAR2(500), 
	LINE_DESCRIPTION VARCHAR2(500), 
	SALES_ORDER VARCHAR2(500), 
	LINE_QUANTITY VARCHAR2(500), 
	UNIT_SELLING_PRICE VARCHAR2(500), 
	LINE_AMOUNT VARCHAR2(500), 
	TAX_CODE VARCHAR2(500), 
	PERIOD_OF_SERVICE_FROM VARCHAR2(500), 
	PERIOD_OF_SERVICE_TO VARCHAR2(500), 
	DIST_LINE_TYPE VARCHAR2(500), 
	DIST_AMOUNT VARCHAR2(500), 
	CHARGE_CODE VARCHAR2(500), 
        RRAM_SOURCE_SYSTEM_REF VARCHAR2(500),
	STATUS VARCHAR2(25), 
	CREATED_BY NUMBER, 
	CREATION_DATE DATE
   );
   
   
   CREATE OR REPLACE SYNONYM APPS.XXAR_OPEN_INVOICES_CONV_STG FOR FMSMGR.XXAR_OPEN_INVOICES_CONV_STG;
   
   
   