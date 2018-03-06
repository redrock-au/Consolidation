REM $Header: svn://d02584/consolrepos/branches/AR.00.01/arc/1.0.0/install/sql/XXAR_PAYMENT_NOTICES_B_DDL.sql 1492 2017-07-05 07:01:42Z svnuser $
REM CEMLI ID: AR.02.04

-- CreatE Table

CREATE TABLE fmsmgr.xxar_payment_notices_b
(
   crn_id              NUMBER,
   source              VARCHAR2(80),
   crn_number          VARCHAR2(12) NOT NULL,
   orig_amt1           NUMBER,
   orig_amt2           NUMBER,
   orig_amt3           NUMBER,
   orig_amt4           NUMBER,
   object_version_id   NUMBER NOT NULL,
   source_file         VARCHAR2(150),
   created_by          NUMBER NOT NULL,
   creation_date       DATE NOT NULL,
   archive_flag        VARCHAR2(1),
   archive_date        DATE,
   last_updated_by     NUMBER NOT NULL,
   last_update_date    DATE NOT NULL
);

-- Create Synonym

CREATE SYNONYM xxar_payment_notices_b FOR fmsmgr.xxar_payment_notices_b;

-- Create Indexes

CREATE INDEX fmsmgr.xxar_payment_notices_b_n1 ON fmsmgr.xxar_payment_notices_b (crn_number);
CREATE INDEX fmsmgr.xxar_payment_notices_b_n2 ON fmsmgr.xxar_payment_notices_b (source);
CREATE INDEX fmsmgr.xxar_payment_notices_b_n3 ON fmsmgr.xxar_payment_notices_b (crn_id);

-- Create Index on AR_CASH_RECEIPTS_ALL Table

CREATE INDEX fmsmgr.xxar_cash_receipts_all_n1 ON ar_cash_receipts_all (TO_NUMBER(attribute14))
TABLESPACE locdat
PCTFREE    10 
INITRANS   11 
MAXTRANS   255 
STORAGE   (INITIAL    16K
           NEXT       1M 
           MINEXTENTS 1 
           MAXEXTENTS UNLIMITED);

-- Create Trigger

CREATE OR REPLACE TRIGGER xxar_payment_notices_b_t1
BEFORE INSERT ON xxar_payment_notices_b
FOR EACH ROW
BEGIN
   :new.crn_id := xxar_payment_notices_b_s.NEXTVAL;
   :new.archive_flag := 'N';
END;
/
