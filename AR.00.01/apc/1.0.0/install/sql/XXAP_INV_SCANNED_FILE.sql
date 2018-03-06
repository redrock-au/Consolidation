/*$Header: svn://d02584/consolrepos/branches/AR.00.01/apc/1.0.0/install/sql/XXAP_INV_SCANNED_FILE.sql 1492 2017-07-05 07:01:42Z svnuser $*/
  
CREATE TABLE FMSMGR.XXAP_INV_SCANNED_FILE 
(	
   IMPORT_ID NUMBER, 
   IMPORT_STATUS VARCHAR2(240 BYTE), 
   ATTRIBUTE1 VARCHAR2(240 BYTE), 
   ATTRIBUTE2 VARCHAR2(240 BYTE), 
   ATTRIBUTE3 VARCHAR2(240 BYTE), 
   ATTRIBUTE4 VARCHAR2(240 BYTE), 
   ATTRIBUTE5 VARCHAR2(240 BYTE), 
   ATTRIBUTE6 VARCHAR2(240 BYTE), 
   ATTRIBUTE7 VARCHAR2(240 BYTE), 
   ATTRIBUTE8 VARCHAR2(240 BYTE), 
   ATTRIBUTE9 VARCHAR2(240 BYTE), 
   ATTRIBUTE10 VARCHAR2(240 BYTE), 
   ATTRIBUTE11 VARCHAR2(240 BYTE), 
   ATTRIBUTE12 VARCHAR2(240 BYTE), 
   ATTRIBUTE13 VARCHAR2(240 BYTE), 
   ATTRIBUTE14 VARCHAR2(240 BYTE), 
   ATTRIBUTE15 VARCHAR2(240 BYTE), 
   CREATION_DATE DATE, 
   LAST_UPDATE_DATE DATE, 
   LAST_UPDATED_BY NUMBER, 
   CREATED_BY NUMBER, 
   PAYLOAD_ID NUMBER,
   PO_HEADER_ID VARCHAR2(10 BYTE), 
   PO_NUMBER_ATTACHMENT VARCHAR2(255 BYTE), 
   PO_NUMBER VARCHAR2(255 BYTE),
   REQUISITION_NUMBER VARCHAR2(255 BYTE), 
   REQUISITION_ID NUMBER, 
   INVOICE_ID VARCHAR2(10 BYTE), 
   INVOICE_ID_ATTACHMENT VARCHAR2(255 BYTE), 
   INVOICE_NUM VARCHAR2(255 BYTE), 
   INVOICE_DATE DATE, 
   INVOICE_RECEIVED_DATE DATE, 
   INVOICE_AMOUNT_EXC_GST NUMBER, 
   GST_AMOUNT NUMBER, 
   INVOICE_AMOUNT_INC_GST NUMBER, 
   GST_CODE VARCHAR2(240 BYTE), 
   CURRENCY VARCHAR2(240 BYTE), 
   PO_ATTACHMENT_COMPLETE VARCHAR2(5 BYTE), 
   REQ_PREP_NAME VARCHAR2(240 BYTE), 
   EMAIL_SENT_COUNT NUMBER, 
   EMAIL_SENT_DATE DATE, 	
   PREPARER_ID NUMBER, 
   ORG_ID NUMBER, 
   VENDOR_INTERNAL_ID NUMBER, 
   VENDOR_SITE_ID NUMBER, 
   VENDOR_SITE_CODE VARCHAR2(15 BYTE), 
   SUPPLIER_NUM VARCHAR2(30 BYTE), 
   ABN_NUMBER VARCHAR2(20 BYTE), 
   IMAGE_URL VARCHAR2(255 BYTE), 
   ACTIVE_FLAG VARCHAR2(10 BYTE),
   ITEM_TYPE VARCHAR2(100 BYTE), 
   ITEM_KEY VARCHAR2(100 BYTE),
   DELETED_IN_KOFAX VARCHAR2(10 BYTE),
   CONSTRAINT IMPORT_ID_PK PRIMARY KEY (IMPORT_ID)
);

CREATE OR REPLACE SYNONYM APPS.XXAP_INV_SCANNED_FILE FOR FMSMGR.XXAP_INV_SCANNED_FILE; 
   /
   