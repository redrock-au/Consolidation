/*$Header: svn://d02584/consolrepos/branches/AP.01.01/apc/1.0.0/install/sql/XXAP_KOFAX_INV_STG.sql 2674 2017-10-05 01:02:16Z svnuser $ */
--DROP TABLE FMSMGR.XXAP_KOFAX_INV_STG 
CREATE TABLE FMSMGR.XXAP_KOFAX_INV_STG 
(	
   DOCUMENT_ID NUMBER NOT NULL,
   IMPORT_STATUS VARCHAR2(240 BYTE) NOT NULL,
   CREATION_DATE DATE NOT NULL,
   CREATED_BY NUMBER,
   LAST_UPDATE_DATE DATE NOT NULL,
   LAST_UPDATED_BY NUMBER, 
   LAST_UPDATE_LOGIN NUMBER,
   PO_HEADER_ID VARCHAR2(10 BYTE),
   PO_NUMBER VARCHAR2(255 BYTE),
   INVOICE_ID NUMBER,
   INVOICE_NUM VARCHAR2(255 BYTE),
   INVOICE_DATE DATE,
   INVOICE_RECEIVED_DATE DATE, 
   INVOICE_AMOUNT_EXC_GST VARCHAR2(40),
   GST_AMOUNT VARCHAR2(40),
   INVOICE_AMOUNT_INC_GST VARCHAR2(40),
   GST_CODE VARCHAR2(240 BYTE),
   CURRENCY VARCHAR2(240 BYTE), 
   ORG_ID NUMBER, 
   VENDOR_INTERNAL_ID NUMBER, 
   VENDOR_SITE_ID NUMBER, 
   VENDOR_SITE_CODE VARCHAR2(15 BYTE), 
   SUPPLIER_NUM VARCHAR2(30 BYTE), 
   ABN_NUMBER VARCHAR2(20 BYTE), 
   IMAGE_URL VARCHAR2(255 BYTE) NOT NULL, 
   INVOICE_IMPORTED VARCHAR2(10),
   ERROR_CODE  VARCHAR2(10),
   ERROR_MESSAGE VARCHAR2(2000),
   CONSTRAINT DOCUMENT_ID_PK PRIMARY KEY (DOCUMENT_ID)
   );

CREATE OR REPLACE SYNONYM APPS.XXAP_KOFAX_INV_STG FOR FMSMGR.XXAP_KOFAX_INV_STG; 
   
