rem $Header: svn://d02584/consolrepos/branches/AP.01.02/apc/1.0.0/install/sql/DOT_PO_PAY_ON_RECEIPT_REPORT.sql 1081 2017-06-21 05:49:47Z svnuser $
CREATE TABLE "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_REPORT" 
(	
    "SHIPMENT_HEADER_ID"     NUMBER, 
	  "VENDOR_SITE_ID"         NUMBER, 
	  "REQUEST_ID"             NUMBER, 
	  "VENDOR_NUMBER"          VARCHAR2(30 BYTE), 
	  "VENDOR_NAME"            VARCHAR2(240 BYTE), 
	  "INVOICE_NUMBER"         VARCHAR2(50 BYTE), 
	  "INVOICE_DATE"           DATE, 
	  "INVOICE_AMOUNT"         NUMBER, 
	  "DISTRIBUTION_NUM"       NUMBER, 
	  "DISTRIBUTION_AMOUNT"    NUMBER, 
	  "CHARGE_ACCOUNT"         VARCHAR2(240 BYTE), 
	  "TAX_CODE"               VARCHAR2(150 BYTE), 
	  "PO_NUMBER"              VARCHAR2(20 BYTE), 
	  "RECEIPT_NUMBER"         VARCHAR2(30 BYTE), 
	  "ENTERED_BY"             VARCHAR2(100 BYTE), 
	  "PERSIST_FLAG"           VARCHAR2(1 BYTE), 
	  "STATUS"                 VARCHAR2(1 BYTE), 
	  "CREATED_BY"             NUMBER, 
	  "CREATION_DATE"          DATE,
    "IMPORT_ID"               NUMBER,
    "ATTACHMENT_URL"          NUMBER    
) 
SEGMENT CREATION IMMEDIATE 
PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 
NOCOMPRESS LOGGING
STORAGE(INITIAL 516096 NEXT 516096 MINEXTENTS 1 MAXEXTENTS 600
PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
TABLESPACE "LOCDAT" ;

CREATE INDEX "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_REP_N1" ON "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_REPORT" ("SHIPMENT_HEADER_ID", "VENDOR_SITE_ID", "REQUEST_ID") 
PCTFREE 10 INITRANS 2 MAXTRANS 255 
STORAGE(INITIAL 516096 NEXT 516096 MINEXTENTS 1 MAXEXTENTS 2147483645
PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
TABLESPACE "LOCIDX" ;

CREATE INDEX "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_REP_N2" ON "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_REPORT" ("RECEIPT_NUMBER") 
PCTFREE 10 INITRANS 2 MAXTRANS 255 
STORAGE(INITIAL 516096 NEXT 516096 MINEXTENTS 1 MAXEXTENTS 2147483645
PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
TABLESPACE "LOCIDX" ;
