/*$Header: svn://d02584/consolrepos/branches/AR.02.01/arc/1.0.0/install/sql/XXAR_CUSTOMER_CONVERSION_TFM_DDL.sql 1566 2017-07-07 00:37:07Z svnuser $*/

CREATE TABLE FMSMGR.XXAR_CUSTOMER_CONVERSION_TFM 
   (	RECORD_ID NUMBER, 
	RUN_ID NUMBER, 
	RUN_PHASE_ID NUMBER, 
	RECORD_ACTION VARCHAR2(6), 
	CUSTOMER_NAME VARCHAR2(360), 
	ORIG_SYSTEM_CUSTOMER_REF VARCHAR2(240), 
	DSDBI_CUSTOMER_NUM VARCHAR2(30), 
	DTPLI_CUSTOMER_NUM VARCHAR2(30), 
	ABN VARCHAR2(50), 
	CUSTOMER_CLASS_CODE VARCHAR2(30), 
	CUSTOMER_ATTRIBUTE2 VARCHAR2(150), 
	INDUSTRY_TYPE VARCHAR2(30), 
	DSDBI_CUSTOMER_SITE_NUM VARCHAR2(30), 
	DTPLI_CUSTOMER_SITE_NUM VARCHAR2(30), 
	ADDRESS_ATTRIBUTE3 VARCHAR2(150), 
	ORIG_SYSTEM_ADDRESS_REF VARCHAR2(240), 
	SITE_USE_CODE VARCHAR2(30), 
	PRIMARY_SITE_USE_FLAG VARCHAR2(1), 
	LOCATION VARCHAR2(40), 
	ADDRESS1 VARCHAR2(240), 
	ADDRESS2 VARCHAR2(240), 
	ADDRESS3 VARCHAR2(240), 
	ADDRESS4 VARCHAR2(240), 
	CITY VARCHAR2(60), 
	COUNTRY VARCHAR2(60), 
	STATE VARCHAR2(60), 
	POSTAL_CODE VARCHAR2(60), 
	STATUS VARCHAR2(25), 
	CREATED_BY NUMBER, 
	CREATION_DATE DATE
   );

CREATE OR REPLACE SYNONYM APPS.XXAR_CUSTOMER_CONVERSION_TFM FOR FMSMGR.XXAR_CUSTOMER_CONVERSION_TFM;