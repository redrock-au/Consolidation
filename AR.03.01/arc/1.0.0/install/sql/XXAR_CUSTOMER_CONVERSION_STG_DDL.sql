/*$Header: svn://d02584/consolrepos/branches/AR.03.01/arc/1.0.0/install/sql/XXAR_CUSTOMER_CONVERSION_STG_DDL.sql 1706 2017-07-12 04:37:42Z svnuser $*/

CREATE TABLE FMSMGR.XXAR_CUSTOMER_CONVERSION_STG 
   (	RECORD_ID NUMBER, 
	RUN_ID NUMBER, 
	RUN_PHASE_ID NUMBER, 
	RECORD_ACTION VARCHAR2(500), 
	CUSTOMER_NAME VARCHAR2(500), 
	ORIG_SYSTEM_CUSTOMER_REF VARCHAR2(500), 
	DSDBI_CUSTOMER_NUM VARCHAR2(500), 
	DTPLI_CUSTOMER_NUM VARCHAR2(500), 
	ABN VARCHAR2(500), 
	CUSTOMER_CLASS_CODE VARCHAR2(500), 
	CUSTOMER_ATTRIBUTE2 VARCHAR2(500), 
	INDUSTRY_TYPE VARCHAR2(500), 
	DSDBI_CUSTOMER_SITE_NUM VARCHAR2(500), 
	DTPLI_CUSTOMER_SITE_NUM VARCHAR2(500), 
	ADDRESS_ATTRIBUTE3 VARCHAR2(500), 
	ORIG_SYSTEM_ADDRESS_REF VARCHAR2(500), 
	SITE_USE_CODE VARCHAR2(500), 
	PRIMARY_SITE_USE_FLAG VARCHAR2(500), 
	LOCATION VARCHAR2(500), 
	ADDRESS1 VARCHAR2(500), 
	ADDRESS2 VARCHAR2(500), 
	ADDRESS3 VARCHAR2(500), 
	ADDRESS4 VARCHAR2(500), 
	CITY VARCHAR2(500), 
	COUNTRY VARCHAR2(500), 
	STATE VARCHAR2(500), 
	POSTAL_CODE VARCHAR2(500), 
	STATUS VARCHAR2(25 ), 
	CREATED_BY NUMBER, 
	CREATION_DATE DATE
   );


CREATE OR REPLACE SYNONYM APPS.XXAR_CUSTOMER_CONVERSION_STG FOR FMSMGR.XXAR_CUSTOMER_CONVERSION_STG;