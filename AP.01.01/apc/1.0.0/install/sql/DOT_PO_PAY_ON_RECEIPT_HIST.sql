rem $Header: svn://d02584/consolrepos/branches/AP.01.01/apc/1.0.0/install/sql/DOT_PO_PAY_ON_RECEIPT_HIST.sql 1074 2017-06-21 05:34:42Z svnuser $
CREATE TABLE "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_HIST"
(	
    "RECEIPT_NUM"             VARCHAR2(30 BYTE), 
	  "SHIPMENT_HEADER_ID"      NUMBER, 
	  "VENDOR_SITE_ID"          NUMBER, 
	  "SHIPMENT_LINE_ID"        NUMBER, 
	  "TRANSACTION_ID"          NUMBER, 
	  "STATUS"                  VARCHAR2(150 BYTE), 
	  "INVOICE_NUM"             VARCHAR2(150 BYTE), 
	  "INVOICE_DATE"            VARCHAR2(150 BYTE), 
	  "REQUEST_ID"              NUMBER, 
	  "CREATED_BY"              NUMBER, 
	  "CREATION_DATE"           DATE, 
	  "LAST_UPDATE_DATE"        DATE, 
	  "LAST_UPDATED_BY"         NUMBER,
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

CREATE INDEX "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_HIST_N1" ON "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_HIST" ("TRANSACTION_ID") 
PCTFREE 10 INITRANS 2 MAXTRANS 255 
STORAGE(INITIAL 516096 NEXT 516096 MINEXTENTS 1 MAXEXTENTS 2147483645
PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
TABLESPACE "LOCIDX" ;

CREATE INDEX "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_HIST_N2" ON "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_HIST" ("INVOICE_NUM") 
PCTFREE 10 INITRANS 2 MAXTRANS 255 
STORAGE(INITIAL 516096 NEXT 516096 MINEXTENTS 1 MAXEXTENTS 2147483645
PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
TABLESPACE "LOCIDX" ;

CREATE INDEX "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_HIST_N3" ON "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_HIST" ("REQUEST_ID") 
PCTFREE 10 INITRANS 2 MAXTRANS 255 
STORAGE(INITIAL 516096 NEXT 516096 MINEXTENTS 1 MAXEXTENTS 2147483645
PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
TABLESPACE "LOCIDX" ;

CREATE INDEX "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_HIST_N4" ON "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_HIST" ("RECEIPT_NUM") 
PCTFREE 10 INITRANS 2 MAXTRANS 255 
STORAGE(INITIAL 516096 NEXT 516096 MINEXTENTS 1 MAXEXTENTS 2147483645
PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
TABLESPACE "LOCIDX" ;

CREATE INDEX "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_HIST_N5" ON "FMSMGR"."DOT_PO_PAY_ON_RECEIPT_HIST" ("SHIPMENT_HEADER_ID") 
PCTFREE 10 INITRANS 2 MAXTRANS 255 
STORAGE(INITIAL 516096 NEXT 516096 MINEXTENTS 1 MAXEXTENTS 2147483645
PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
TABLESPACE "LOCIDX" ;
